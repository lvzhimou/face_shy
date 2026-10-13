//
//  GradientCardView.swift
//  FaceShy
//
//  渐变卡片：浅色 / 深色两套渐变色值，跟随系统外观自动切换。
//  用于首页主视觉卡与入口卡，替代单调的纯色底，
//  对齐参考稿里「大圆角 + 柔和渐变底」的卡片质感。
//
//  ⚠️ 本视图是**纯装饰**视图：它会被当作子视图叠在别的容器之上，
//  因此必须关闭自身交互，否则默认的 isUserInteractionEnabled = true
//  会把点击事件吃掉，外层容器的 .touchUpInside 永远不触发
//  （表现为「按钮点了没反应」）。入口按钮请用 EntryCardButton，
//  它自带渐变层，不再是「按钮里再塞一个装饰视图」的结构。
//

import UIKit

final class GradientCardView: UIView {

    private let gradient = CAGradientLayer()
    private let lightColors: [UIColor]
    private let darkColors: [UIColor]

    /// - Parameters:
    ///   - light: 浅色模式的 (起始色, 结束色)
    ///   - dark: 深色模式的 (起始色, 结束色)
    init(light: (UInt32, UInt32), dark: (UInt32, UInt32)) {
        self.lightColors = [UIColor(rgb: light.0), UIColor(rgb: light.1)]
        self.darkColors = [UIColor(rgb: dark.0), UIColor(rgb: dark.1)]
        super.init(frame: .zero)

        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        clipsToBounds = true
        makeDecorative()
        resolveColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 递归关闭整棵子树的交互（纯装饰层专用）
    func makeDecorative() {
        isUserInteractionEnabled = false
        subviews.forEach { $0.isUserInteractionEnabled = false }
    }

    private func resolveColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let palette = isDark ? darkColors : lightColors
        gradient.colors = palette
            .map { $0.resolvedColor(with: traitCollection) }
            .map { $0.cgColor }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            resolveColors()
        }
    }
}
