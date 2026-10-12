//
//  CanvasView.swift
//  FaceShy
//
//  编辑画布：负责按原图比例等比展示照片，并作为贴纸 / 水印的容器。
//
//  坐标体系：
//  photoContainer 的 bounds 就是「画布坐标系」，
//  所有 EditorItem 的 center / baseSize 都相对于它，原点在照片左上角。
//

import UIKit

final class CanvasView: UIView {

    /// 贴纸的父视图（clipsToBounds = true，超出照片的部分会被裁掉）
    let photoContainer = UIView()

    /// 本地 AI 识别中的扫描特效层
    let scanOverlay = ScanOverlayView()

    /// 点击空白处（用于取消选中当前元素）
    var onTapEmptyArea: (() -> Void)?

    private let imageView = UIImageView()
    private var displayedImageSize: CGSize = .zero

    /// 画布尺寸（point），导出换算时使用
    var canvasSize: CGSize { photoContainer.bounds.size }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.canvasBackdrop
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = Theme.canvasBackdrop
        setup()
    }

    private func setup() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        photoContainer.clipsToBounds = true
        photoContainer.backgroundColor = .black
        photoContainer.layer.shadowColor = UIColor.black.cgColor
        photoContainer.layer.shadowOpacity = 0.18
        photoContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        photoContainer.layer.shadowRadius = 12

        addSubview(photoContainer)
        photoContainer.addSubview(imageView)
        photoContainer.addSubview(scanOverlay)
        scanOverlay.isHidden = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    /// 设置要编辑的照片
    func setImage(_ image: UIImage) {
        imageView.image = image
        displayedImageSize = image.size
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard displayedImageSize.width > 0, displayedImageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }

        // 等比缩放到画布内（contain）
        let ratio = min(bounds.width / displayedImageSize.width,
                        bounds.height / displayedImageSize.height)
        let fitted = CGSize(width: floor(displayedImageSize.width * ratio),
                            height: floor(displayedImageSize.height * ratio))

        photoContainer.bounds = CGRect(origin: .zero, size: fitted)
        photoContainer.center = CGPoint(x: bounds.midX, y: bounds.midY)

        if imageView.frame != photoContainer.bounds {
            imageView.frame = photoContainer.bounds
        }
        scanOverlay.frame = photoContainer.bounds
    }

    /// 开始 / 停止扫描特效
    func startScanAnimation() {
        scanOverlay.startScanning()
    }

    func stopScanAnimation() {
        scanOverlay.stopScanning()
    }

    /// 画布尺寸变化时（例如旋转 / 分屏），按比例同步已有元素的位置与大小
    func rescaleItems(from oldSize: CGSize) {
        guard oldSize.width > 0, oldSize.height > 0 else { return }
        let newSize = canvasSize
        guard newSize.width > 0 else { return }

        let ratioX = newSize.width / oldSize.width
        let ratioY = newSize.height / oldSize.height
        let ratio = min(ratioX, ratioY)

        photoContainer.subviews.compactMap { $0 as? EditableItemView }.forEach { itemView in
            itemView.rescale(by: CGPoint(x: ratioX, y: ratioY), uniformScale: ratio)
        }
    }

    // MARK: - 空白点击

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onTapEmptyArea?()
    }
}

extension CanvasView: UIGestureRecognizerDelegate {

    /// 只有点到空白处（而非贴纸）时才取消选中
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view
        while let current = view {
            if current is EditableItemView { return false }
            if current === self { break }
            view = current.superview
        }
        return true
    }
}
