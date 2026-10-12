//
//  UIView+Layout.swift
//  FaceShy
//
//  轻量布局工具方法，减少 Auto Layout 样板代码。
//

import UIKit

extension UIView {

    /// 批量添加子视图并关闭 autoresizing 转换
    func addSubviews(_ views: UIView...) {
        views.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    /// 让当前视图四边贴合父视图
    func pinEdges(to other: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom)
        ])
    }

    /// 圆角
    func roundCorners(radius: CGFloat) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }

    /// 统一卡片阴影（配合 surface 背景色使用）
    func applyCardStyle(radius: CGFloat = 18) {
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.45 : 0.08
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 16
    }

    /// 点击时轻微缩放反馈
    func playTapFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.08, animations: {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }, completion: { _ in
            UIView.animate(withDuration: 0.12) { self.transform = .identity }
        })
    }
}

extension UIViewController {

    /// 统一的错误提示
    func presentAlert(title: String, message: String?, actionTitle: String = "好的") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: actionTitle, style: .default))
        present(alert, animated: true)
    }
}
