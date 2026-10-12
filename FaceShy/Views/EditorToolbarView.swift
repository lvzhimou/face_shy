//
//  EditorToolbarView.swift
//  FaceShy
//
//  编辑页底部工具栏：随机表情 / 表情库 / 上传贴纸 / 文字水印 / 图片水印 / 手动加贴纸
//

import UIKit

final class EditorToolbarView: UIView {

    enum Action {
        case randomEmoji
        case openEmojiPicker
        case uploadCustomSticker
        case addTextWatermark
        case addImageWatermark
        case addManualSticker
    }

    var onAction: ((Action) -> Void)?

    private let scrollView = UIScrollView()
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

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 2
        stackView.distribution = .fill

        addSubviews(scrollView)
        scrollView.addSubviews(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        addTool(symbol: "shuffle", title: "随机表情", action: .randomEmoji)
        addTool(symbol: "face.smiling", title: "表情库", action: .openEmojiPicker)
        addTool(symbol: "photo.on.rectangle.angled", title: "自定义贴纸", action: .uploadCustomSticker)
        addTool(symbol: "textformat", title: "文字水印", action: .addTextWatermark)
        addTool(symbol: "photo", title: "图片水印", action: .addImageWatermark)
        addTool(symbol: "plus.circle", title: "手动加贴纸", action: .addManualSticker)
    }

    private func addTool(symbol: String, title: String, action: Action) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol) ?? UIImage(systemName: "circle")
        configuration.imagePlacement = .top
        configuration.imagePadding = 5
        configuration.baseForegroundColor = Theme.textPrimary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)

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
