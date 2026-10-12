//
//  SelectedItemBar.swift
//  FaceShy
//
//  选中某个贴纸 / 水印后出现的操作条：图层上下移、透明度、删除
//

import UIKit

final class SelectedItemBar: UIView {

    enum Action {
        case layerUp
        case layerDown
        case opacity
        case delete
    }

    var onAction: ((Action) -> Void)?

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = Theme.surfaceAlt

        titleLabel.font = Theme.font(12, weight: .semibold)
        titleLabel.textColor = Theme.textSecondary
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            UIView(),
            makeButton(symbol: "arrow.up.square", title: "上移", action: .layerUp),
            makeButton(symbol: "arrow.down.square", title: "下移", action: .layerDown),
            makeButton(symbol: "circle.lefthalf.filled", title: "透明", action: .opacity),
            makeButton(symbol: "trash", title: "删除", action: .delete, tint: Theme.danger)
        ])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center

        addSubviews(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 78)
        ])
    }

    func update(title: String) {
        titleLabel.text = title
    }

    private func makeButton(symbol: String,
                            title: String,
                            action: Action,
                            tint: UIColor = Theme.textPrimary) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol) ?? UIImage(systemName: "circle")
        configuration.imagePlacement = .top
        configuration.imagePadding = 2
        configuration.baseForegroundColor = tint
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)

        var titleAttributes = AttributeContainer()
        titleAttributes.font = Theme.font(10, weight: .medium)
        configuration.attributedTitle = AttributedString(title, attributes: titleAttributes)

        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { [weak self] _ in
            self?.onAction?(action)
        }, for: .touchUpInside)
        return button
    }
}
