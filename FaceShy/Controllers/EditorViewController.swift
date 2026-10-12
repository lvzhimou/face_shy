//
//  EditorViewController.swift
//  FaceShy
//
//  编辑页：人脸识别 -> 自动贴 emoji -> 手势调整 -> 水印 -> 保存
//
//  数据流：
//  Vision 检测结果（归一化坐标）
//      -> canvasRect() 换算到画布坐标系
//      -> 创建 EditorItem（模型）
//      -> EditableItemView（视图）承载手势
//      -> EditorRenderer 用模型数据在原始分辨率下重绘导出
//

import UIKit

final class EditorViewController: UIViewController {

    // MARK: - Dependencies

    private let sourceImage: UIImage
    private let faceDetector = FaceDetector()
    private let stickerStore = CustomStickerStore.shared
    private lazy var photoPicker = PhotoPicker()

    // MARK: - State

    /// 全部元素模型（顺序不代表图层顺序，图层顺序以视图层级为准）
    private var items: [EditorItem] = []
    private var itemViews: [UUID: EditableItemView] = [:]
    private var selectedItemID: UUID?

    private var didRunInitialDetection = false
    private var lastCanvasSize: CGSize = .zero

    // MARK: - Views

    private let canvasView = CanvasView()
    private let selectedBar = SelectedItemBar()
    private let toolbar = EditorToolbarView()

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
        detectFacesAndPlaceStickers(isInitial: true)
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
        // 选中操作条以浮层形式压在画布上方，避免挤压照片导致元素位置重算
        selectedBar.isHidden = true
        selectedBar.roundCorners(radius: 16)

        // 覆盖 Home Indicator 区域的背景
        let bottomFiller = UIView()
        bottomFiller.backgroundColor = Theme.surface

        view.addSubviews(canvasView, toolbar, selectedBar, bottomFiller)

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

            selectedBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            selectedBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            selectedBar.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -10),
            selectedBar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func bindCallbacks() {
        toolbar.onAction = { [weak self] action in
            self?.handleToolbarAction(action)
        }
        selectedBar.onAction = { [weak self] action in
            self?.handleSelectedBarAction(action)
        }
        canvasView.onTapEmptyArea = { [weak self] in
            self?.deselect()
        }
    }

    // MARK: - 人脸识别

    private func detectFacesAndPlaceStickers(isInitial: Bool) {
        HUD.shared.show("本地 AI 正在识别人脸…", in: view)

        faceDetector.detectFaces(in: sourceImage) { [weak self] result in
            guard let self = self else { return }
            HUD.shared.hide()

            switch result {
            case .success(let faces):
                guard !faces.isEmpty else {
                    self.presentNoFaceAlert()
                    return
                }
                self.placeStickers(for: faces)

            case .failure(let error):
                self.presentAlert(title: "识别失败",
                                  message: error.errorDescription ?? "请稍后重试")
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
            addItem(item, select: false)
        }

        Toast.show("识别到 \(faces.count) 张人脸，已自动贴上表情", in: view)
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
            message: "可能是光线较暗、侧脸，或面部被头发 / 口罩遮挡。你可以换一张照片，也可以用「手动加贴纸」自己把表情拖到脸上。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "重试识别", style: .default) { [weak self] _ in
            self?.detectFacesAndPlaceStickers(isInitial: false)
        })
        alert.addAction(UIAlertAction(title: "手动加贴纸", style: .default) { [weak self] _ in
            self?.addManualSticker()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - 元素管理

    private func addItem(_ item: EditorItem, select shouldSelect: Bool) {
        items.append(item)

        let itemView = EditableItemView(item: item)
        itemView.delegate = self
        canvasView.photoContainer.addSubview(itemView)
        itemViews[item.id] = itemView

        if shouldSelect {
            selectItem(id: item.id)
        } else {
            itemView.isEditingItem = false
        }
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
        guard let item = items.first(where: { $0.id == id }) else { return }
        selectedItemID = id
        itemViews.forEach { $0.value.isEditingItem = ($0.key == id) }
        selectedBar.update(title: item.displayName)
        selectedBar.isHidden = false
    }

    private func deselect() {
        selectedItemID = nil
        itemViews.forEach { $0.value.isEditingItem = false }
        selectedBar.isHidden = true
    }

    private func deleteSelectedItem() {
        guard let id = selectedItemID else { return }
        itemViews[id]?.removeFromSuperview()
        itemViews.removeValue(forKey: id)
        items.removeAll { $0.id == id }
        deselect()
        Toast.show("已删除", in: view)
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
            presentEmojiPicker()
        case .uploadCustomSticker:
            uploadCustomSticker()
        case .addTextWatermark:
            presentTextWatermark()
        case .addImageWatermark:
            pickImageWatermark()
        case .addManualSticker:
            addManualSticker()
        }
    }

    /// 一键随机更换全部人脸贴纸
    private func randomizeFaceStickers() {
        let faceItems = items.filter { $0.role == .faceSticker }
        guard !faceItems.isEmpty else {
            Toast.show("还没有人脸贴纸，可用「手动加贴纸」添加", in: view)
            return
        }

        let emojis = EmojiCatalog.randomSet(count: faceItems.count)
        for (index, item) in faceItems.enumerated() {
            let content = ItemContent.emoji(emojis[index % emojis.count])
            item.content = content
            itemViews[item.id]?.updateContent(content)
        }

        if let id = selectedItemID, let item = items.first(where: { $0.id == id }) {
            selectedBar.update(title: item.displayName)
        }
        Toast.show("已随机更换 \(faceItems.count) 个表情", in: view)
    }

    private func presentEmojiPicker() {
        let picker = EmojiPickerViewController()
        picker.onPick = { [weak self] content in
            self?.applyStickerContent(content)
        }
        present(picker, animated: true)
    }

    /// 选中了贴纸就只换它，否则替换全部人脸贴纸
    private func applyStickerContent(_ content: ItemContent) {
        if let id = selectedItemID,
           let item = items.first(where: { $0.id == id }),
           item.isSticker {
            item.content = content
            itemViews[id]?.updateContent(content)
            selectedBar.update(title: item.displayName)
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
        addItem(item, select: true)
        Toast.show("拖动贴纸移到脸上，双指可缩放旋转", in: view)
    }

    private func uploadCustomSticker() {
        photoPicker.present(from: self) { [weak self] image in
            guard let self = self, let image = image else { return }
            do {
                let fileName = try self.stickerStore.addSticker(from: image)
                self.addManualSticker(content: .customSticker(fileName: fileName))
                Toast.show("已加入画布，并保存到「我的贴纸」", in: self.view)
            } catch {
                self.presentAlert(title: "保存失败", message: error.localizedDescription)
            }
        }
    }

    // MARK: - 水印

    private func presentTextWatermark() {
        let controller = TextWatermarkViewController()
        controller.onConfirm = { [weak self] text, color, fontSize in
            self?.addTextWatermark(text: text, color: color, fontSize: fontSize)
        }
        present(controller, animated: true)
    }

    private func addTextWatermark(text: String, color: UIColor, fontSize: CGFloat) {
        let canvasSize = canvasView.canvasSize
        guard canvasSize.width > 0 else { return }

        let maxWidth = canvasSize.width * 0.82
        let attributed = NSAttributedString(string: text,
                                            attributes: [.font: Theme.roundedFont(fontSize, weight: .bold)])
        let measured = attributed.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                               options: [.usesLineFragmentOrigin, .usesFontLeading],
                                               context: nil).size

        let baseSize = CGSize(width: min(ceil(measured.width) + 24, maxWidth),
                              height: ceil(measured.height) + 16)

        let item = EditorItem(content: .textWatermark(text: text, color: color, fontSize: fontSize),
                              role: .free,
                              center: CGPoint(x: canvasSize.width / 2,
                                              y: canvasSize.height - baseSize.height / 2 - 28),
                              baseSize: baseSize)
        addItem(item, select: true)
    }

    private func pickImageWatermark() {
        photoPicker.present(from: self) { [weak self] image in
            guard let self = self, let image = image else { return }
            self.addImageWatermark(image)
        }
    }

    private func addImageWatermark(_ image: UIImage) {
        let canvasSize = canvasView.canvasSize
        guard canvasSize.width > 0 else { return }

        let maxSide = min(canvasSize.width * 0.6, 260)
        let ratio = image.size.width / max(image.size.height, 1)
        let baseSize: CGSize = ratio >= 1
            ? CGSize(width: maxSide, height: maxSide / ratio)
            : CGSize(width: maxSide * ratio, height: maxSide)

        let item = EditorItem(content: .imageWatermark(image),
                              role: .free,
                              center: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                              baseSize: baseSize)
        addItem(item, select: true)
        Toast.show("双指缩放旋转，单指拖动调整水印位置", in: view)
    }

    // MARK: - 选中操作条

    private func handleSelectedBarAction(_ action: SelectedItemBar.Action) {
        guard let id = selectedItemID,
              let itemView = itemViews[id],
              let container = itemView.superview else { return }

        switch action {
        case .layerUp:
            let subviews = container.subviews
            if let index = subviews.firstIndex(of: itemView), index < subviews.count - 1 {
                container.exchangeSubview(at: index, withSubviewAt: index + 1)
            }

        case .layerDown:
            // index 0 是照片本身，元素最低只能到 index 1
            let subviews = container.subviews
            if let index = subviews.firstIndex(of: itemView), index > 1 {
                container.exchangeSubview(at: index, withSubviewAt: index - 1)
            }

        case .opacity:
            let sheet = OpacitySheetViewController(current: itemView.opacityValue)
            sheet.onConfirm = { [weak self] value in
                itemView.setOpacity(value)
                self?.items.first(where: { $0.id == id })?.opacity = value
            }
            present(sheet, animated: true)

        case .delete:
            deleteSelectedItem()
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
        selectItem(id: itemView.itemID)
        deleteSelectedItem()
    }
}
