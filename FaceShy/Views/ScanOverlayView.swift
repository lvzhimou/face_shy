//
//  ScanOverlayView.swift
//  FaceShy
//
//  「本地 AI 识别中」的扫描特效：
//  - 半透明暗色蒙版 + 一条往复扫动的渐变光带 + 四角取景框
//  - 全部由 Core Animation 驱动，不占用主线程 CPU
//  - 只覆盖在照片区域（photoContainer）上
//

import UIKit

final class ScanOverlayView: UIView {

    // MARK: - Layers

    private let dimLayer = CALayer()
    private let beamLayer = CAGradientLayer()
    private let gridLayer = CAShapeLayer()
    private let cornerLayer = CAShapeLayer()

    private var beamAnimKey = "scanBeam.position.y"

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
        backgroundColor = .clear

        // 1. 暗色蒙版
        dimLayer.backgroundColor = UIColor.black.withAlphaComponent(0.18).cgColor
        layer.addSublayer(dimLayer)

        // 2. 网格（很淡，营造「扫描仪」质感）
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.08).cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 1
        layer.addSublayer(gridLayer)

        // 3. 扫描光带（绿色渐变，从透明到亮再到透明）
        beamLayer.colors = [
            Theme.success.withAlphaComponent(0).cgColor,
            Theme.success.withAlphaComponent(0.16).cgColor,
            Theme.success.withAlphaComponent(0.42).cgColor,
            Theme.success.withAlphaComponent(0.16).cgColor,
            Theme.success.withAlphaComponent(0).cgColor
        ]
        beamLayer.startPoint = CGPoint(x: 0.5, y: 0)
        beamLayer.endPoint = CGPoint(x: 0.5, y: 1)
        beamLayer.locations = [0, 0.35, 0.5, 0.65, 1]
        layer.addSublayer(beamLayer)

        // 4. 四角取景框
        cornerLayer.strokeColor = Theme.success.cgColor
        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.lineWidth = 3
        cornerLayer.lineCap = .round
        layer.addSublayer(cornerLayer)
    }

    // MARK: - 布局

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        dimLayer.frame = bounds
        gridLayer.frame = bounds
        gridLayer.path = Self.gridPath(in: bounds, step: 36).cgPath
        cornerLayer.path = Self.cornerPath(in: bounds.insetBy(dx: 10, dy: 10), length: 26).cgPath

        let beamHeight = max(bounds.height * 0.16, 40)
        beamLayer.frame = CGRect(x: 0, y: -beamHeight, width: bounds.width, height: beamHeight)

        CATransaction.commit()

        restartBeamAnimation()
    }

    /// 光带往复扫动
    private func restartBeamAnimation() {
        beamLayer.removeAnimation(forKey: beamAnimKey)
        guard bounds.height > 60 else { return }

        let travel = bounds.height + beamLayer.bounds.height
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = -beamLayer.bounds.height / 2
        animation.toValue = bounds.height + beamLayer.bounds.height / 2
        animation.duration = max(travel / 320, 0.8)
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        beamLayer.add(animation, forKey: beamAnimKey)
    }

    // MARK: - 开关

    func startScanning() {
        isHidden = false
        alpha = 0
        UIView.animate(withDuration: 0.22) { self.alpha = 1 }
        setNeedsLayout()
    }

    func stopScanning() {
        guard !isHidden else { return }
        UIView.animate(withDuration: 0.25,
                       animations: { self.alpha = 0 },
                       completion: { _ in
                           self.isHidden = true
                           self.beamLayer.removeAnimation(forKey: self.beamAnimKey)
                       })
    }

    // MARK: - 路径

    private static func gridPath(in rect: CGRect, step: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width > step, rect.height > step else { return path }

        var y = rect.minY + step
        while y < rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += step
        }
        var x = rect.minX + step
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        return path
    }

    private static func cornerPath(in rect: CGRect, length: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()

        // 左上
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        // 右上
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        // 右下
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        // 左下
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}
