//
//  HomeViewController.swift
//  FaceShy
//
//  首页：从相册选图 / 相机拍照两个入口 + 隐私说明 + 设置入口
//

import UIKit

final class HomeViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private lazy var photoPicker = PhotoPicker()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        scrollView.alwaysBounceVertical = true
        view.addSubviews(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        scrollView.addSubviews(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        contentStack.addArrangedSubview(makeHeader())
        contentStack.setCustomSpacing(22, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(makePrivacyCard())
        contentStack.setCustomSpacing(22, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(makeEntryButton(
            symbol: "photo.on.rectangle.angled",
            title: "从相册选择照片",
            subtitle: "支持多人合照，自动识别全部人脸",
            filled: true,
            selector: #selector(pickFromLibrary)
        ))
        contentStack.addArrangedSubview(makeEntryButton(
            symbol: "camera.fill",
            title: "拍照导入",
            subtitle: CameraService.isCameraAvailable ? "实时拍摄，拍完立刻遮脸" : "模拟器不支持相机，请用相册选图",
            filled: false,
            selector: #selector(takePhoto)
        ))
        contentStack.setCustomSpacing(26, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(makeStepsCard())
    }

    private func makeHeader() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "face.smiling"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let iconBackground = UIView()
        iconBackground.backgroundColor = Theme.brand
        iconBackground.roundCorners(radius: 20)
        iconBackground.addSubviews(icon)

        let title = UILabel()
        title.text = "隐颜 FaceShy"
        title.font = Theme.roundedFont(28, weight: .bold)
        title.textColor = Theme.textPrimary

        let subtitle = UILabel()
        subtitle.text = "本地 AI 遮脸，一键给照片人脸贴上 emoji"
        subtitle.font = Theme.font(14)
        subtitle.textColor = Theme.textSecondary
        subtitle.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [iconBackground, textStack])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center

        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 64),
            iconBackground.heightAnchor.constraint(equalToConstant: 64),
            icon.widthAnchor.constraint(equalToConstant: 34),
            icon.heightAnchor.constraint(equalToConstant: 34),
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor)
        ])
        return row
    }

    private func makePrivacyCard() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = Theme.brand
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = "本地 AI 识别人脸\n所有照片仅保存在本机，不会上传网络"
        label.font = Theme.font(13, weight: .medium)
        label.textColor = Theme.textPrimary
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        let card = UIView()
        card.backgroundColor = Theme.brandSoft
        card.roundCorners(radius: 16)
        card.addSubviews(row)
        row.pinEdges(to: card, insets: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22)
        ])
        return card
    }

    private func makeEntryButton(symbol: String,
                                 title: String,
                                 subtitle: String,
                                 filled: Bool,
                                 selector: Selector) -> UIControl {
        let container = UIControl()
        container.backgroundColor = filled ? Theme.brand : Theme.surface
        container.roundCorners(radius: 20)
        container.addTarget(self, action: selector, for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = filled ? .white : Theme.brand
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.font(17, weight: .semibold)
        titleLabel.textColor = filled ? .white : Theme.textPrimary

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = Theme.font(12)
        subtitleLabel.textColor = filled ? UIColor.white.withAlphaComponent(0.85) : Theme.textSecondary
        subtitleLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.isUserInteractionEnabled = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = filled ? UIColor.white.withAlphaComponent(0.8) : Theme.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, textStack, chevron])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.isUserInteractionEnabled = false

        container.addSubviews(row)
        row.pinEdges(to: container, insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 18))

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            chevron.widthAnchor.constraint(equalToConstant: 12)
        ])
        return container
    }

    private func makeStepsCard() -> UIView {
        let title = UILabel()
        title.text = "使用步骤"
        title.font = Theme.font(13, weight: .semibold)
        title.textColor = Theme.textSecondary

        let steps = [
            "1. 选图或拍照导入",
            "2. 本地 AI 自动识别人脸并贴上 emoji",
            "3. 拖动 / 双指缩放旋转微调表情",
            "4. 可加水印，保存到相册"
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8

        steps.forEach { text in
            let label = UILabel()
            label.text = text
            label.font = Theme.font(13)
            label.textColor = Theme.textPrimary
            label.numberOfLines = 0
            stack.addArrangedSubview(label)
        }

        let card = UIView()
        card.backgroundColor = Theme.surface
        card.roundCorners(radius: 18)

        let vertical = UIStackView(arrangedSubviews: [title, stack])
        vertical.axis = .vertical
        vertical.spacing = 10
        card.addSubviews(vertical)
        vertical.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 18, bottom: 18, right: 18))
        return card
    }

    // MARK: - Actions

    @objc private func pickFromLibrary() {
        photoPicker.present(from: self) { [weak self] image in
            guard let self = self else { return }
            guard let image = image else { return }
            self.openEditor(with: image)
        }
    }

    @objc private func takePhoto() {
        CameraService.presentCamera(from: self, delegate: self)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    private func openEditor(with image: UIImage) {
        let editor = EditorViewController(image: image)
        let navigation = AppNavigationController(rootViewController: editor)
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
    }
}

// MARK: - 相机回调

extension HomeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        openEditor(with: image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
