//
//  OpacitySheetViewController.swift
//  FaceShy
//
//  透明度调节面板（选中贴纸 / 水印后使用）
//

import UIKit

final class OpacitySheetViewController: UIViewController {

    var onConfirm: ((CGFloat) -> Void)?

    private let slider = UISlider()
    private let valueLabel = UILabel()
    private let previewBox = UIView()
    private var currentValue: CGFloat

    init(current: CGFloat) {
        self.currentValue = min(max(current, 0.1), 1)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupSheet()
        buildUI()
    }

    private func setupSheet() {
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom { _ in 240 }]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 22
        }
    }

    private func buildUI() {
        let titleLabel = UILabel()
        titleLabel.text = "不透明度"
        titleLabel.font = Theme.font(16, weight: .bold)
        titleLabel.textColor = Theme.textPrimary

        valueLabel.font = Theme.font(14, weight: .semibold)
        valueLabel.textColor = Theme.brand

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), valueLabel])
        header.axis = .horizontal
        header.alignment = .center

        slider.minimumValue = 0.1
        slider.maximumValue = 1.0
        slider.value = Float(currentValue)
        slider.minimumTrackTintColor = Theme.brand
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        previewBox.backgroundColor = Theme.brand
        previewBox.roundCorners(radius: 12)
        previewBox.heightAnchor.constraint(equalToConstant: 54).isActive = true
        previewBox.alpha = currentValue

        var configuration = UIButton.Configuration.filled()
        configuration.title = "完成"
        configuration.baseBackgroundColor = Theme.brand
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        let doneButton = UIButton(configuration: configuration)
        doneButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [header, previewBox, slider, doneButton])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(18, after: previewBox)

        view.addSubviews(stack)
        stack.pinEdges(to: view, insets: UIEdgeInsets(top: 22, left: 20, bottom: 24, right: 20))

        updateValueLabel()
    }

    @objc private func sliderChanged() {
        currentValue = CGFloat(slider.value)
        previewBox.alpha = currentValue
        updateValueLabel()
        onConfirm?(currentValue)
    }

    private func updateValueLabel() {
        valueLabel.text = "\(Int((currentValue * 100).rounded()))%"
    }
}
