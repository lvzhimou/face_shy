//
//  EditorViewController.swift
//  FaceShy
//
//  编辑页：扫描特效 -> 人脸识别 -> 自动贴 emoji -> 手势调整 -> 保存
//
//  数据流：
//  Vision 检测结果（归一化坐标）
//      -> canvasRect() 换算到画布坐标系
//      -> 创建 EditorItem（模型）
//      -> EditableItemView（视图）承载手势与「删除 / 换表情」按钮
//      -> EditorRenderer 用模型数据在原始分辨率下重绘导出
//

import UIKit

final class EditorViewController: UIViewController {

    // MARK: - Dependencies

    private let sourceImage: UIImage
    private let faceDetector = FaceDetector()

    // MARK: - State

    /// 全部元素模型（顺序不代表图层顺序，图层顺序以视图层级为准）
    private var items: [EditorItem] = []
    private var itemViews: [UUID: EditableItemView] = [:]
    private var selectedItemID: UUID?

    private var didRunInitialDetection = false
    private var lastCanvasSize: CGSize = .zero

    /// 扫描特效的最短展示时长，太快会一闪而过看不出效果
    private let minimumScanDuration: CFTimeInterval = 1.5

    // MARK: - Views

    private let canvasView = CanvasView()
    private let toolbar = EditorToolbarView()
    private let statusPill = UILabel()

    // MARK: - Init

    init(image: UIImage) {
        self.sourceImage = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupNavigationBar()
        setupLayout()
        bindCallbacks()

        canvasView.setImage(sourceImage)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunInitialDetection else { return }
        didRunInitialDetection = true
        view.layoutIfNeeded()
        detectFacesAndPlaceStickers()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let currentSize = canvasView.canvasSize
        // 只有画布宽度变化（真正的布局变化，例如分屏）才需要同步元素几何
        if lastCanvasSize != .zero,
           abs(lastCanvasSize.width - currentSize.width) > 0.5 {
            canvasView.rescaleItems(from: lastCanvasSize)
        }
        lastCanvasSize = currentSize
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        canvasView.stopScanAnimation()
        HUD.shared.hide()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationItem.title = "编辑"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "关闭",
            style: .plain,
            target: self,
            action: #selector(closeEditor)
        )
        let saveItem = UIBarButtonItem(
            title: "保存",
            style: .done,
            target: self,
            action: #selector(handleSave)
        )
        saveItem.setTitleTextAttributes([.font: Theme.font(17, weight: .semibold)], for: .normal)
        navigationItem.rightBarButtonItem = saveItem
    }

    private func setupLayout() {
        // 覆盖 Home Indicator 区域的背景
        let bottomFiller = UIView()
        bottomFiller.backgroundColor = Theme.surface

        statusPill.font = Theme.font(12, weight: .medium)
        statusPill.textColor = Theme.textSecondary
        statusPill.backgroundColor = Theme.surface
        statusPill.textAlignment = .center
        statusPill.layer.cornerRadius = 12
        statusPill.layer.cornerCurve = .continuous
        statusPill.clipsToBounds = true
        statusPill.isHidden = true

        view.addSubviews(canvasView, statusPill, toolbar, bottomFiller)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 62),

            bottomFiller.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFiller.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFiller.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            bottomFiller.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),

            statusPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusPill.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -10),
            statusPill.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    private func bindCallbacks() {
        toolbar.onAction = { [weak self] action in
            self?.handleToolbarAction(action)
        }
        canvasView.onTapEmptyArea = { [weak self] in
            self?.deselect()
        }
    }

    // MARK: - 人脸识别（带扫描特效）

    private func detectFacesAndPlaceStickers() {
        canvasView.startScanAnimation()
        HUD.shared.show("本地 AI 正在扫描照片…", in: view)
        updateStatusPill("正在本地扫描人脸…")

        let beginTime = CACurrentMediaTime()

        faceDetector.detectFaces(in: sourceImage) { [weak self] result in
            guard let self = self else { return }

            // 识别通常只要几百毫秒，强制让扫描动画至少跑够时长，特效才看得出来
            let elapsed = CACurrentMediaTime() - beginTime
            let remaining = max(0, self.minimumScanDuration - elapsed)

            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                self.canvasView.stopScanAnimation()
                HUD.shared.hide()

                switch result {
                case .success(let faces):
                    guard !faces.isEmpty else {
                        self.updateStatusPill(nil)
                        self.presentNoFaceAlert()
                        return
                    }
                    self.placeStickers(for: faces)

                case .failure(let error):
                    self.updateStatusPill(nil)
                    self.presentAlert(title: "识别失败",
                                      message: error.errorDescription ?? "请稍后重试")
                }
            }
        }
    }

    /// 把人脸矩形换算成画布坐标，并自动生成 emoji 贴纸
    private func placeStickers(for faces: [DetectedFace]) {
        let canvasSize = canvasView.canvasSize
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }

        // 重新识别时先清掉旧的人脸贴纸
        removeItems(where: { $0.role == .faceSticker })

        let emojis = EmojiCatalog.randomSet(count: faces.count)

        for (index, face) in faces.enumerated() {
            let rect = canvasRect(for: face.boundingBox, in: canvasSize)
            // 外扩一点，保证表情能完整盖住脸部（含发际线、耳侧）
            let expanded = rect.insetBy(dx: -rect.width * 0.16, dy: -rect.height * 0.16)

            let item = EditorItem(content: .emoji(emojis[index % emojis.count]),
                                  role: .faceSticker,
                                  center: CGPoint(x: expanded.midX, y: expanded.midY),
                                  baseSize: expanded.size,
                                  rotation: -face.roll)

            // 逐个落下，形成轻微的错位节奏感
            if let view = addItem(item, select: false, animated: true) {
                view.alpha = 0
                view.playAppearAnimation()
                UIView.animate(withDuration: 0.2,
                               delay: Double(index) * 0.06,
                               options: [.allowUserInteraction]) {
                    view.alpha = 1
                }
            }
        }

        updateStatusPill("识别到 \(faces.count) 张人脸")
        Toast.show("已自动贴上 \(faces.count) 个表情，点击可更换", in: view)
    }

    /// Vision 归一化坐标（原点左下）-> 画布坐标（原点左上）
    private func canvasRect(for normalizedRect: CGRect, in canvasSize: CGSize) -> CGRect {
        let width = normalizedRect.width * canvasSize.width
        let height = normalizedRect.height * canvasSize.height
        let x = normalizedRect.minX * canvasSize.width
        let y = (1 - normalizedRect.maxY) * canvasSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func presentNoFaceAlert() {
        let alert = UIAlertController(
            title: "没有识别到人脸",
            message: "可能是光线较暗、侧脸，或面部被头发 / 口罩遮挡。你可以重新扫描，也可以用「手动加贴纸」自己把表情拖到脸上。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "重新扫描", style: .default) { [weak self] _ in
            self?.detectFacesAndPlaceStickers()
        })
        alert.addAction(UIAlertAction(title: "手动加贴纸", style: .default) { [weak self] _ in
            self?.addManualSticker()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func updateStatusPill(_ text: String?) {
        guard let text = text, !text.isEmpty else {
            statusPill.isHidden = true
            return
        }
        statusPill.text = "  \(text)  "
        statusPill.isHidden = false
    }

    // MARK: - 元素管理

    @discardableResult
    private func addItem(_ item: EditorItem, select shouldSelect: Bool, animated: Bool = false) -> EditableItemView? {
        items.append(item)

        let itemView = EditableItemView(item: item)
        itemView.delegate = self
        canvasView.photoContainer.addSubview(itemView)
        // 扫描特效层始终压在贴纸之上（识别期间贴纸不会出现，保持层级稳定）
        canvasView.photoContainer.bringSubviewToFront(canvasView.scanOverlay)
        itemViews[item.id] = itemView

        if shouldSelect {
            selectItem(id: item.id)
        } else {
            itemView.isEditingItem = false
        }
        return itemView
    }

    private func removeItems(where predicate: (EditorItem) -> Bool) {
        let targets = items.filter(predicate)
        for item in targets {
            itemViews[item.id]?.removeFromSuperview()
            itemViews.removeValue(forKey: item.id)
        }
        items.removeAll(where: predicate)
        if let selected = selectedItemID, !items.contains(where: { $0.id == selected }) {
            deselect()
        }
    }

    private func selectItem(id: UUID) {
        selectedItemID = id
        itemViews.forEach { $0.value.isEditingItem = ($0.key == id) }
    }

    private func deselect() {
        selectedItemID = nil
        itemViews.forEach { $0.value.isEditingItem = false }
    }

    private func deleteItem(id: UUID) {
        itemViews[id]?.removeFromSuperview()
        itemViews.removeValue(forKey: id)
        items.removeAll { $0.id == id }
        if selectedItemID == id { deselect() }
    }

    /// 按当前图层顺序（视图层级）返回元素模型，用于导出绘制
    private func itemsInLayerOrder() -> [EditorItem] {
        canvasView.photoContainer.subviews
            .compactMap { $0 as? EditableItemView }
            .compactMap { itemView in items.first(where: { $0.id == itemView.itemID }) }
    }

    // MARK: - 工具栏

    private func handleToolbarAction(_ action: EditorToolbarView.Action) {
        switch action {
        case .randomEmoji:
            randomizeFaceStickers()
        case .openEmojiPicker:
            presentEmojiPicker(isReplacing: false)
        case .uploadCustomSticker:
            uploadCustomSticker()
        case .addManualSticker:
            addManualSticker()
        }
    }

    /// 一键随机更换全部表情（人脸贴纸优先，没有则换全部）
    private func randomizeFaceStickers() {
        let targets = items.filter { $0.role == .faceSticker }.isEmpty
            ? items
            : items.filter { $0.role == .faceSticker }

        guard !targets.isEmpty else {
            Toast.show("还没有贴纸，可用「手动加贴纸」添加一个", in: view)
            return
        }

        let emojis = EmojiCatalog.randomSet(count: targets.count)
        for (index, item) in targets.enumerated() {
            let content = ItemContent.emoji(emojis[index % emojis.count])
            item.content = content
            itemViews[item.id]?.updateContent(content)
        }
        Toast.show("已随机更换 \(targets.count) 个表情", in: view)
    }

    /// - Parameter isReplacing: 是否由「换表情」入口触发（只换当前选中的那个）
    private func presentEmojiPicker(isReplacing: Bool) {
        let picker = EmojiPickerViewController()
        picker.isReplacingItem = isReplacing
        picker.onPick = { [weak self] content in
            guard let self = self else { return }
            // 换表情入口：只替换当前选中的贴纸
            if isReplacing, let id = self.selectedItemID {
                self.applyContent(content, toItemID: id)
            } else {
                self.applyStickerContent(content)
            }
        }
        present(picker, animated: true)
    }

    /// 把内容应用到指定贴纸
    private func applyContent(_ content: ItemContent, toItemID id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        item.content = content
        itemViews[id]?.updateContent(content)
        selectItem(id: id)
    }

    /// 选中了贴纸就只换它，否则替换全部人脸贴纸
    private func applyStickerContent(_ content: ItemContent) {
        if let id = selectedItemID, items.contains(where: { $0.id == id }) {
            applyContent(content, toItemID: id)
            return
        }

        let faceItems = items.filter { $0.role == .faceSticker }
        guard !faceItems.isEmpty else {
            addManualSticker(content: content)
            return
        }

        for item in faceItems {
            item.content = content
            itemViews[item.id]?.updateContent(content)
        }
        Toast.show("已更换全部人脸贴纸", in: view)
    }

    /// 手动添加一个贴纸（用于识别失败或想额外贴纸的情况）
    private func addManualSticker(content: ItemContent = .emoji("😀")) {
        let canvasSize = canvasView.canvasSize
        guard canvasSize.width > 0 else { return }

        let side = min(canvasSize.width, canvasSize.height) * 0.28
        let item = EditorItem(content: content,
                              role: .free,
                              center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                              baseSize: CGSize(width: side, height: side))
        if let view = addItem(item, select: true, animated: true) {
            view.playAppearAnimation()
        }
        Toast.show("拖动贴纸移到脸上，双指可缩放旋转", in: view)
    }

    /// 上传自定义贴纸：先本地自动抠图，用户选择保存抠图或原图
    private func uploadCustomSticker() {
        StickerUploadFlow.start(from: self) { [weak self] fileName in
            guard let self = self else { return }
            self.addManualSticker(content: .customSticker(fileName: fileName))
            Toast.show("已加入画布，并保存到「我的贴纸」", in: self.view)
        }
    }

    // MARK: - 保存 / 导出

    @objc private func closeEditor() {
        dismiss(animated: true)
    }

    @objc private func handleSave() {
        deselect()

        let sheet = UIAlertController(title: "保存到相册",
                                      message: "选择导出画质，默认高清不压缩",
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "高清原图（不压缩）", style: .default) { [weak self] _ in
            self?.exportImage(compress: false)
        })
        sheet.addAction(UIAlertAction(title: "压缩图片（便于分享）", style: .default) { [weak self] _ in
            self?.exportImage(compress: true)
        })
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
            popover.sourceView = view
        }
        present(sheet, animated: true)
    }

    private func exportImage(compress: Bool) {
        let canvasSize = canvasView.canvasSize
        guard canvasSize.width > 0 else { return }

        let orderedItems = itemsInLayerOrder()
        HUD.shared.show("正在生成图片…", in: view)

        // 让 HUD 先渲染出来，再进行重绘合成
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard var output = EditorRenderer.render(image: self.sourceImage,
                                                     items: orderedItems,
                                                     canvasSize: canvasSize) else {
                HUD.shared.hide()
                self.presentAlert(title: "导出失败", message: "图片处理出现问题，请重试")
                return
            }

            if compress {
                output = output.resized(maxDimension: 2048)
                if let data = output.jpegData(compressionQuality: 0.82),
                   let recompressed = UIImage(data: data) {
                    output = recompressed
                }
            }

            PhotoLibraryService.save(output) { result in
                HUD.shared.hide()
                switch result {
                case .success:
                    AppSettings.compressOnExport = compress
                    Toast.show("已保存到相册", in: self.view)
                case .failure(let error):
                    self.presentAlert(title: "保存失败", message: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - EditableItemViewDelegate

extension EditorViewController: EditableItemViewDelegate {

    func editableItemViewDidBeginEditing(_ itemView: EditableItemView) {
        selectItem(id: itemView.itemID)
    }

    func editableItemView(_ itemView: EditableItemView,
                          didUpdateGeometry center: CGPoint,
                          scale: CGFloat,
                          rotation: CGFloat) {
        guard let item = items.first(where: { $0.id == itemView.itemID }) else { return }
        item.center = center
        item.scale = scale
        item.rotation = rotation
    }

    func editableItemViewDidRequestDelete(_ itemView: EditableItemView) {
        deleteItem(id: itemView.itemID)
        Toast.show("已删除", in: view)
    }

    func editableItemViewDidRequestReplace(_ itemView: EditableItemView) {
        selectItem(id: itemView.itemID)
        presentEmojiPicker(isReplacing: true)
    }
}
