//
//  EditableItemView.swift
//  FaceShy
//
//  画布上的可交互元素视图：emoji 贴纸 / 自定义贴纸 / 文字水印 / 图片水印。
//
//  手势：
//  - 单指拖动  -> UIPanGestureRecognizer（平移 center）
//  - 双指捏合  -> UIPinchGestureRecognizer（缩放）
//  - 双指旋转  -> UIRotationGestureRecognizer（旋转，可与捏合同时进行）
//  - 单击      -> 选中该元素，显示边框与删除按钮
//
//  为了在缩放时文字依然清晰，缩放不是通过 transform 实现，
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
    func editableItemViewDidRequestDelete(_ itemView: EditableItemView)
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

    private var contentView: UIView?
    private var textLabel: UILabel?
    private let deleteButton = UIButton(type: .custom)

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
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        layer.borderColor = Theme.brand.cgColor

        setupDeleteButton()
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

        case .customSticker(let fileName):
            let imageView = UIImageView(image: CustomStickerStore.shared.image(named: fileName))
            imageView.contentMode = .scaleAspectFit
            view = imageView

        case .imageWatermark(let image):
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            view = imageView

        case .textWatermark(let text, let color, _):
            let label = UILabel()
            label.text = text
            label.textColor = color
            label.textAlignment = .center
            label.numberOfLines = 0
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.4
            label.baselineAdjustment = .alignCenters
            textLabel = label
            view = label
        }

        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.isUserInteractionEnabled = false
        insertSubview(view, at: 0)
        contentView = view

        applyContentAppearance()
    }

    /// 更换内容（随机表情 / 手动选择表情时调用）
    func updateContent(_ newContent: ItemContent) {
        content = newContent
        rebuildContent()
    }

    /// 缩放变化时同步字号，保证文字清晰不模糊
    private func applyContentAppearance() {
        switch content {
        case .emoji:
            let side = min(baseSize.width, baseSize.height) * scaleFactor
            textLabel?.font = UIFont.systemFont(ofSize: max(side * 0.94, 6))

        case .textWatermark(_, _, let fontSize):
            textLabel?.font = Theme.roundedFont(max(fontSize * scaleFactor, 4), weight: .bold)

        default:
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

        applyContentAppearance()
        setNeedsLayout()

        if notify {
            delegate?.editableItemView(self,
                                       didUpdateGeometry: self.center,
                                       scale: scaleFactor,
                                       rotation: rotationAngle)
        }
    }

    func setScale(_ value: CGFloat) {
        apply(center: center, scale: value, rotation: rotationAngle, opacity: opacityValue, notify: true)
    }

    func setRotation(_ value: CGFloat) {
        apply(center: center, scale: scaleFactor, rotation: value, opacity: opacityValue, notify: true)
    }

    func setOpacity(_ value: CGFloat) {
        apply(center: center, scale: scaleFactor, rotation: rotationAngle, opacity: value, notify: false)
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
        // 删除按钮固定在右上角，跟随元素尺寸
        let side: CGFloat = 26
        deleteButton.frame = CGRect(x: bounds.width - side + 4,
                                    y: -side + 4,
                                    width: side,
                                    height: side)
        // 选中高亮（圆角阴影描边）
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 6).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateChrome()
    }

    // MARK: - 选中外观

    private func setupDeleteButton() {
        deleteButton.backgroundColor = Theme.danger
        deleteButton.layer.cornerRadius = 13
        deleteButton.layer.borderWidth = 1.5
        deleteButton.layer.borderColor = UIColor.white.cgColor
        deleteButton.layer.shadowColor = UIColor.black.cgColor
        deleteButton.layer.shadowOpacity = 0.25
        deleteButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        deleteButton.layer.shadowRadius = 2

        let cross = UIImage(systemName: "xmark",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        deleteButton.setImage(cross, for: .normal)
        deleteButton.addTarget(self, action: #selector(handleDeleteButton), for: .touchUpInside)
        addSubview(deleteButton)
    }

    private func updateChrome() {
        layer.borderWidth = isEditingItem ? 2 : 0
        layer.borderColor = Theme.brand.resolvedColor(with: traitCollection).cgColor
        deleteButton.isHidden = !isEditingItem
        layer.shadowColor = isEditingItem ? Theme.brand.resolvedColor(with: traitCollection).cgColor : nil
        layer.shadowOpacity = isEditingItem ? 0.35 : 0
        layer.shadowRadius = 8
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
}
