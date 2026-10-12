//
//  TextWatermarkViewController.swift
//  FaceShy
//
//  文字水印编辑面板：输入文字、选择颜色、调整字号
//

import UIKit

final class TextWatermarkViewController: UIViewController {

    /// 点击「添加水印」后回调
    var onConfirm: ((String, UIColor, CGFloat) -> Void)?

    private let textField = UITextField()
    private let previewLabel = UILabel()
    private let colorStack = UIStackView()
    private let fontSizeSlider = UISlider()
    private let fontSizeValueLabel = UILabel()
    private let confirmButton = UIButton(type: .system)

    private var selectedColor: UIColor = .white

    /// 预设颜色（白 / 黑 / 品牌紫 / 红 / 黄 / 蓝 / 绿）
    private let palette: [UIColor] = [
        .white,
        UIColor(rgb: 0x111111),
        UIColor(rgb: 0x5B4BE8),
        UIColor(rgb: 0xF0453C),
        UIColor(rgb: 0xFFC531),
        UIColor(rgb: 0x2E9BF0),
        UIColor(rgb: 0x1EA362)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupSheet()
        buildUI()
        updatePreview()
    }

    private func setupSheet() {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 22
        }
    }

    // MARK: - UI

    private func buildUI() {
        let titleLabel = UILabel()
        titleLabel.text = "文字水印"
        titleLabel.font = Theme.font(18, weight: .bold)
        titleLabel.textColor = Theme.textPrimary

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = Theme.textTertiary
        closeButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), closeButton])
        header.axis = .horizontal
        header.alignment = .center

        // 输入框
        textField.placeholder = "输入水印文字，例如 @隐颜"
        textField.font = Theme.font(15)
        textField.textColor = Theme.textPrimary
        textField.backgroundColor = Theme.surface
        textField.roundCorners(radius: 12)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.rightViewMode = .always
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.delegate = self
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        textField.heightAnchor.constraint(equalToConstant: 46).isActive = true

        // 颜色选择
        let colorTitle = makeSectionTitle("颜色")
        colorStack.axis = .horizontal
        colorStack.spacing = 10
        colorStack.alignment = .center
        palette.enumerated().forEach { index, color in
            let button = ColorSwatchButton(color: color)
            button.tag = index
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            button.isChosen = (color == selectedColor)
            colorStack.addArrangedSubview(button)
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        }
        colorStack.addArrangedSubview(UIView())

        // 字号
        let fontTitle = makeSectionTitle("字号")
        fontSizeValueLabel.font = Theme.font(13, weight: .semibold)
        fontSizeValueLabel.textColor = Theme.textSecondary
        fontSizeValueLabel.textAlignment = .right

        let fontHeader = UIStackView(arrangedSubviews: [fontTitle, UIView(), fontSizeValueLabel])
        fontHeader.axis = .horizontal

        fontSizeSlider.minimumValue = 12
        fontSizeSlider.maximumValue = 72
        fontSizeSlider.value = 30
        fontSizeSlider.minimumTrackTintColor = Theme.brand
        fontSizeSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        // 预览
        previewLabel.textAlignment = .center
        previewLabel.numberOfLines = 0
        previewLabel.backgroundColor = Theme.canvasBackdrop
        previewLabel.roundCorners(radius: 14)
        previewLabel.layer.masksToBounds = true
        previewLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 84).isActive = true

        // 确认按钮
        var configuration = UIButton.Configuration.filled()
        configuration.title = "添加水印"
        configuration.baseBackgroundColor = Theme.brand
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        confirmButton.configuration = configuration
        confirmButton.addAction(UIAction { [weak self] _ in
            self?.confirm()
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            header, textField, colorTitle, colorStack, fontHeader, fontSizeSlider, previewLabel, confirmButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(6, after: colorTitle)
        stack.setCustomSpacing(6, after: fontHeader)

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubviews(scrollView)
        scrollView.addSubviews(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = Theme.font(13, weight: .semibold)
        label.textColor = Theme.textSecondary
        return label
    }

    // MARK: - Actions

    @objc private func textChanged() {
        updatePreview()
    }

    @objc private func sliderChanged() {
        updatePreview()
    }

    @objc private func colorTapped(_ sender: ColorSwatchButton) {
        guard sender.tag < palette.count else { return }
        selectedColor = palette[sender.tag]
        colorStack.arrangedSubviews
            .compactMap { $0 as? ColorSwatchButton }
            .forEach { $0.isChosen = ($0 === sender) }
        updatePreview()
    }

    private func updatePreview() {
        let text = textField.text ?? ""
        let fontSize = CGFloat(fontSizeSlider.value)
        fontSizeValueLabel.text = "\(Int(fontSize))"

        if text.isEmpty {
            previewLabel.attributedText = NSAttributedString(
                string: "水印预览",
                attributes: [.font: Theme.roundedFont(fontSize, weight: .bold),
                             .foregroundColor: Theme.textTertiary]
            )
        } else {
            previewLabel.attributedText = NSAttributedString(
                string: text,
                attributes: [.font: Theme.roundedFont(fontSize, weight: .bold),
                             .foregroundColor: selectedColor]
            )
        }
        confirmButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        confirmButton.alpha = confirmButton.isEnabled ? 1 : 0.5
    }

    private func confirm() {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let fontSize = CGFloat(fontSizeSlider.value)
        dismiss(animated: true) { [weak self] in
            self?.onConfirm?(text, self?.selectedColor ?? .white, fontSize)
        }
    }
}

// MARK: - UITextFieldDelegate

extension TextWatermarkViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - 颜色圆点

final class ColorSwatchButton: UIControl {

    private let color: UIColor
    private let checkView = UIImageView()

    var isChosen: Bool = false {
        didSet { updateAppearance() }
    }

    init(color: UIColor) {
        self.color = color
        super.init(frame: .zero)

        backgroundColor = color
        roundCorners(radius: 16)
        layer.borderWidth = 1
        layer.borderColor = Theme.separator.cgColor

        checkView.image = UIImage(systemName: "checkmark")?
            .withTintColor(color.rgbLuminance > 0.6 ? .black : .white, renderingMode: .alwaysOriginal)
        checkView.contentMode = .scaleAspectFit
        checkView.isHidden = true
        addSubviews(checkView)
        NSLayoutConstraint.activate([
            checkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 15),
            checkView.heightAnchor.constraint(equalToConstant: 15)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAppearance() {
        checkView.isHidden = !isChosen
        layer.borderWidth = isChosen ? 3 : 1
        layer.borderColor = isChosen ? Theme.brand.cgColor : Theme.separator.cgColor
    }
}

extension UIColor {
    /// 亮度（0~1），用于判断该用黑色还是白色前景
    var rgbLuminance: CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.299 * red + 0.587 * green + 0.114 * blue
    }
}
