//
//  HUD.swift
//  FaceShy
//
//  轻量加载指示器 + Toast 提示（人脸识别、导出图片时使用）
//

import UIKit

final class HUD {

    static let shared = HUD()

    private var container: UIView?
    private var spinner: UIActivityIndicatorView?
    private var label: UILabel?

    private init() {}

    func show(_ text: String, in view: UIView) {
        hide()
        let box = UIView()
        box.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(rgb: 0x1C1F29, alpha: 0.96)
                : UIColor(rgb: 0xFFFFFF, alpha: 0.98)
        }
        box.applyCardStyle(radius: 16)

        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = Theme.brand
        indicator.startAnimating()

        let title = UILabel()
        title.text = text
        title.font = Theme.font(14, weight: .medium)
        title.textColor = Theme.textPrimary
        title.numberOfLines = 2
        title.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [indicator, title])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center

        box.addSubviews(stack)
        view.addSubviews(box)

        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            box.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            box.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -20)
        ])

        box.alpha = 0
        UIView.animate(withDuration: 0.15) { box.alpha = 1 }

        container = box
        spinner = indicator
        self.label = title
    }

    func updateText(_ text: String) {
        label?.text = text
    }

    func hide() {
        spinner?.stopAnimating()
        container?.removeFromSuperview()
        container = nil
        spinner = nil
        label = nil
    }
}

enum Toast {

    static func show(_ text: String, in view: UIView, duration: TimeInterval = 1.8) {
        let label = UILabel()
        label.text = text
        label.font = Theme.font(14, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center

        let box = UIView()
        box.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.78)
        box.roundCorners(radius: 14)
        box.addSubviews(label)

        view.addSubviews(box)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10),
            box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            box.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110),
            box.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -60)
        ])

        box.alpha = 0
        box.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(withDuration: 0.22) {
            box.alpha = 1
            box.transform = .identity
        }
        UIView.animate(withDuration: 0.22, delay: duration, options: []) {
            box.alpha = 0
        } completion: { _ in
            box.removeFromSuperview()
        }
    }
}
