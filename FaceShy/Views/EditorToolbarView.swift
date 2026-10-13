//
//  EditorToolbarView.swift
//  FaceShy
//
//  编辑页底部工具栏：随机表情 / 表情库 / 上传贴纸 / 手动加贴纸
//

import UIKit

final class EditorToolbarView: UIView {

    enum Action {
        case randomEmoji
        case openEmojiPicker
        case uploadCustomSticker
        case addManualSticker
    }

    var onAction: ((Action) -> Void)?

    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = Theme.surface
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: -3)
        layer.shadowRadius = 10

        // 四个功能在底部「居中 + 平均对齐」：去掉横向滚动，
        // 用 fillEqually 让每个按钮等宽铺满整行
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually

        addSubviews(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])

        addTool(symbol: "shuffle", title: "随机表情", action: .randomEmoji)
        addTool(symbol: "face.smiling", title: "表情库", action: .openEmojiPicker)
        addTool(symbol: "photo.on.rectangle.angled", title: "自定义贴纸", action: .uploadCustomSticker)
        addTool(symbol: "plus.circle", title: "手动加贴纸", action: .addManualSticker)
    }

    private func addTool(symbol: String, title: String, action: Action) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol) ?? UIImage(systemName: "circle")
        configuration.imagePlacement = .top
        configuration.imagePadding = 5
        configuration.baseForegroundColor = Theme.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)

        var titleAttributes = AttributeContainer()
        titleAttributes.font = Theme.font(11, weight: .medium)
        configuration.attributedTitle = AttributedString(title, attributes: titleAttributes)

        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { [weak self] _ in
            button.playTapFeedback()
            self?.onAction?(action)
        }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 58).isActive = true
        stackView.addArrangedSubview(button)
    }
}
