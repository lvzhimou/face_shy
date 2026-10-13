//
//  EditableItemView.swift
//  FaceShy
//
//  画布上的可交互元素视图：emoji 贴纸 / 自定义贴纸。
//
//  手势：
//  - 单指拖动  -> UIPanGestureRecognizer（平移 center）
//  - 双指捏合  -> UIPinchGestureRecognizer（缩放）
//  - 双指旋转  -> UIRotationGestureRecognizer（旋转，可与捏合同时进行）
//  - 单击      -> 选中该元素，左上角出现「删除」，左下角出现「换表情」
//
//  为了在缩放时 emoji 依然清晰，缩放不是通过 transform 实现，
//  而是直接改变 bounds 并同步放大字号；transform 只用于旋转。
//  这样在导出渲染时可以直接复用 baseSize * scale 的几何数据。
//

import UIKit

protocol EditableItemViewDelegate: AnyObject {
    func editableItemViewDidBeginEditing(_ itemView: EditableItemView)
    func editableItemView(_ itemView: EditableItemView,
                          didUpdateGeometry center: CGPoint,
                          scale: CGFloat,
                          rotation: CGFloat)
    /// 点击左上角 ✕
    func editableItemViewDidRequestDelete(_ itemView: EditableItemView)
    /// 点击左下角人脸图标，请求更换表情
    func editableItemViewDidRequestReplace(_ itemView: EditableItemView)
}

final class EditableItemView: UIView {

    weak var delegate: EditableItemViewDelegate?

    let itemID: UUID
    private(set) var content: ItemContent
    private(set) var baseSize: CGSize
    private(set) var scaleFactor: CGFloat = 1
    private(set) var rotationAngle: CGFloat = 0
    private(set) var opacityValue: CGFloat = 1

    static let minScale: CGFloat = 0.2
    static let maxScale: CGFloat = 8

    /// 圆形操作按钮直径（= 可视直径，同时保证 ≥36pt 的可点区域）
    private let buttonSide: CGFloat = 36
    /// 命中区域向外扩展的边距：让双指缩放 / 旋转可以在表情外侧起手，
    /// 否则手指落在 bounds 外时手势根本不会开始（表现为「无法缩放旋转」）
    private let hitAreaMargin: CGFloat = 44

    private var contentView: UIView?
    private var textLabel: UILabel?
    private let deleteButton = UIButton(type: .custom)
    private let replaceButton = UIButton(type: .custom)

    private var panStartCenter: CGPoint = .zero
    private var pinchStartScale: CGFloat = 1
    private var rotationStartAngle: CGFloat = 0

    /// 是否处于选中（编辑）状态
    var isEditingItem: Bool = false {
        didSet { updateChrome() }
    }

    // MARK: - Init

    init(item: EditorItem) {
        self.itemID = item.id
        self.content = item.content
        self.baseSize = item.baseSize
        super.init(frame: CGRect(origin: .zero, size: item.baseSize))

        backgroundColor = .clear
        clipsToBounds = false
        isUserInteractionEnabled = true
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.borderColor = Theme.success.cgColor

        setupActionButtons()
        rebuildContent()
        setupGestures()

        apply(center: item.center,
              scale: item.scale,
              rotation: item.rotation,
              opacity: item.opacity,
              notify: false)
        isEditingItem = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 内容构建

    private func rebuildContent() {
        contentView?.removeFromSuperview()
        contentView = nil
        textLabel = nil

        let view: UIView
        switch content {
        case .emoji(let value):
            let label = UILabel()
            label.text = value
            label.textAlignment = .center
            label.numberOfLines = 1
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.2
            label.baselineAdjustment = .alignCenters
            textLabel = label
            view = label

        case .avatar(let fileName, let gender):
            let imageView = UIImageView(image: StickerCatalog.avatarImage(named: fileName, gender: gender))
            imageView.contentMode = .scaleAspectFit
            view = imageView

        case .customSticker(let fileName):
            let imageView = UIImageView(image: CustomStickerStore.shared.image(named: fileName))
            imageView.contentMode = .scaleAspectFit
            view = imageView
        }

        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.isUserInteractionEnabled = false
        insertSubview(view, at: 0)
        contentView = view

        applyContentAppearance()
    }

    /// 更换内容（换表情 / 选择自定义贴纸时调用）
    func updateContent(_ newContent: ItemContent, animated: Bool = true) {
        content = newContent
        rebuildContent()
        if animated { playContentPop() }
    }

    /// 内容切换时的轻微弹跳，让「换表情」更有反馈
    private func playContentPop() {
        guard let contentView = contentView else { return }
        contentView.transform = CGAffineTransform(scaleX: 0.72, y: 0.72)
        contentView.alpha = 0.2
        UIView.animate(withDuration: 0.34,
                       delay: 0,
                       usingSpringWithDamping: 0.62,
                       initialSpringVelocity: 0.8,
                       options: [.allowUserInteraction]) {
            contentView.transform = .identity
            contentView.alpha = 1
        }
    }

    /// 贴纸刚被放下时的入场动画
    func playAppearAnimation() {
        playContentPop()
    }

    /// 缩放变化时同步字号，保证 emoji 清晰不模糊
    private func applyContentAppearance() {
        switch content {
        case .emoji:
            let side = min(baseSize.width, baseSize.height) * scaleFactor
            textLabel?.font = UIFont.systemFont(ofSize: max(side * 0.94, 6))

        case .avatar, .customSticker:
            break
        }
    }

    // MARK: - 几何

    private func apply(center: CGPoint,
                       scale: CGFloat,
                       rotation: CGFloat,
                       opacity: CGFloat,
                       notify: Bool) {
        self.center = center
        scaleFactor = min(max(scale, EditableItemView.minScale), EditableItemView.maxScale)
        rotationAngle = rotation
        opacityValue = min(max(opacity, 0.1), 1)

        bounds = CGRect(x: 0, y: 0,
                        width: baseSize.width * scaleFactor,
                        height: baseSize.height * scaleFactor)
        transform = CGAffineTransform(rotationAngle: rotationAngle)
        contentView?.alpha = opacityValue

        // 关键：按钮几何必须与 bounds/transform 同帧更新。
        // 只依赖 layoutSubviews 会在捏合时滞后一帧，
        // 按钮和图标就会跟着缩放/旋转短暂变形（用户可见的「icon 变形」）。
        syncActionButtonsGeometry()

        applyContentAppearance()

        if notify {
            delegate?.editableItemView(self,
                                       didUpdateGeometry: self.center,
                                       scale: scaleFactor,
                                       rotation: rotationAngle)
        }
    }

    /// 立即把两个圆形按钮摆到角上，且保持屏幕上的大小与角度恒定。
    /// 用 center + bounds 定位（不经过 transform 换算的 frame），
    /// 再用「父旋转的精确反向旋转」抵消父视图的旋转，
    /// 无论元素怎么缩放旋转，按钮在屏幕上始终是 36pt 正圆、图标不变形。
    private func syncActionButtonsGeometry() {
        let side = buttonSide
        let offset: CGFloat = 4
        let counterRotation = CGAffineTransform(rotationAngle: -rotationAngle)

        deleteButton.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        deleteButton.center = CGPoint(x: -side / 2 - offset,
                                      y: -side / 2 - offset)
        deleteButton.transform = counterRotation

        replaceButton.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        replaceButton.center = CGPoint(x: -side / 2 - offset,
                                       y: bounds.height - side / 2 + offset)
        replaceButton.transform = counterRotation
    }

    func setScale(_ value: CGFloat) {
        apply(center: center, scale: value, rotation: rotationAngle, opacity: opacityValue, notify: true)
    }

    func setRotation(_ value: CGFloat) {
        apply(center: center, scale: scaleFactor, rotation: value, opacity: opacityValue, notify: true)
    }

    /// 把元素放进指定区域（画布缩放时同步）
    func clampCenterToSuperview() {
        guard let container = superview else { return }
        let bounds = container.bounds
        center = CGPoint(x: min(max(center.x, 0), bounds.width),
                         y: min(max(center.y, 0), bounds.height))
        delegate?.editableItemView(self,
                                   didUpdateGeometry: center,
                                   scale: scaleFactor,
                                   rotation: rotationAngle)
    }

    /// 画布尺寸变化时按比例同步（分屏 / 旋转兜底）
    func rescale(by pointRatio: CGPoint, uniformScale: CGFloat) {
        center = CGPoint(x: center.x * pointRatio.x, y: center.y * pointRatio.y)
        apply(center: center,
              scale: scaleFactor * uniformScale,
              rotation: rotationAngle,
              opacity: opacityValue,
              notify: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // 兜底：任何触发布局的路径（旋转 / 分屏 / 画布变化）都重新对齐按钮
        syncActionButtonsGeometry()

        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateChrome()
    }

    /// 两个圆形按钮画在 bounds 之外，默认情况下 UIKit 不会把触摸派发给
    /// 超出父视图范围的子视图，会导致按钮「看得见点不动」。
    /// 这里把命中区域扩展到：按钮所在矩形 + bounds 四周一大圈，
    /// 后者同时解决「双指缩放 / 旋转时手指落在表情外，手势无法开始」的问题。
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if super.point(inside: point, with: event) { return true }
        if isEditingItem,
           deleteButton.frame.contains(point) || replaceButton.frame.contains(point) {
            return true
        }
        return bounds.insetBy(dx: -hitAreaMargin, dy: -hitAreaMargin).contains(point)
    }

    // MARK: - 选中外观

    private func setupActionButtons() {
        configureCircleButton(deleteButton,
                              symbol: "xmark",
                              symbolPointSize: 13,
                              tint: Theme.danger)
        deleteButton.addTarget(self, action: #selector(handleDeleteButton), for: .touchUpInside)

        configureCircleButton(replaceButton,
                              symbol: "face.smiling",
                              symbolPointSize: 16,
                              tint: Theme.brand)
        replaceButton.addTarget(self, action: #selector(handleReplaceButton), for: .touchUpInside)

        addSubview(deleteButton)
        addSubview(replaceButton)
    }

    /// 统一主风格的圆形操作按钮：白底 + 语义色图标 + 白色描边 + 柔和投影
    private func configureCircleButton(_ button: UIButton,
                                       symbol: String,
                                       symbolPointSize: CGFloat,
                                       tint: UIColor) {
        button.backgroundColor = .white
        button.layer.cornerRadius = buttonSide / 2
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.28
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.clipsToBounds = false

        let configuration = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .bold)
        let image = UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
        // 图标始终等比显示，绝不拉伸变形
        button.imageView?.contentMode = .scaleAspectFit
    }

    private func updateChrome() {
        let isEditing = isEditingItem
        layer.borderWidth = isEditing ? 2 : 0
        layer.borderColor = Theme.success.resolvedColor(with: traitCollection).cgColor
        deleteButton.isHidden = !isEditing
        replaceButton.isHidden = !isEditing
        layer.shadowColor = isEditing ? Theme.success.resolvedColor(with: traitCollection).cgColor : nil
        layer.shadowOpacity = isEditing ? 0.3 : 0
        layer.shadowRadius = 10
        layer.shadowOffset = .zero
    }

    // MARK: - 手势

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))

        [pan, pinch, rotate, tap].forEach {
            $0.delegate = self
            addGestureRecognizer($0)
        }
    }

    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        delegate?.editableItemViewDidBeginEditing(self)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let container = superview else { return }

        switch gesture.state {
        case .began:
            delegate?.editableItemViewDidBeginEditing(self)
            panStartCenter = center
        case .changed:
            let translation = gesture.translation(in: container)
            let target = CGPoint(x: panStartCenter.x + translation.x,
                                 y: panStartCenter.y + translation.y)
            center = CGPoint(x: min(max(target.x, 0), container.bounds.width),
                             y: min(max(target.y, 0), container.bounds.height))
            notifyGeometryChanged()
        case .ended, .cancelled, .failed:
            clampCenterToSuperview()
        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            delegate?.editableItemViewDidBeginEditing(self)
            pinchStartScale = scaleFactor
        case .changed:
            apply(center: center,
                  scale: pinchStartScale * gesture.scale,
                  rotation: rotationAngle,
                  opacity: opacityValue,
                  notify: true)
        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            delegate?.editableItemViewDidBeginEditing(self)
            rotationStartAngle = rotationAngle
        case .changed:
            apply(center: center,
                  scale: scaleFactor,
                  rotation: rotationStartAngle + gesture.rotation,
                  opacity: opacityValue,
                  notify: true)
        default:
            break
        }
    }

    @objc private func handleDeleteButton() {
        delegate?.editableItemViewDidRequestDelete(self)
    }

    @objc private func handleReplaceButton() {
        delegate?.editableItemViewDidRequestReplace(self)
    }

    private func notifyGeometryChanged() {
        delegate?.editableItemView(self,
                                   didUpdateGeometry: center,
                                   scale: scaleFactor,
                                   rotation: rotationAngle)
    }
}

extension EditableItemView: UIGestureRecognizerDelegate {

    /// 允许「捏合 + 旋转 + 拖动」同时生效
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    /// 落在 ✕ / 人脸按钮上的触摸交给按钮自己处理，
    /// 否则父视图的 tap 手势会把按钮的点击吞掉
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIButton)
    }
}
