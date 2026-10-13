//
//  HomeViewController.swift
//  FaceShy
//
//  首页：品牌头部 + 渐变主视觉卡 + 双入口卡 + 功能磁贴 + 使用步骤
//
//  视觉风格对齐参考稿（主流社交 / 游戏 App 首页）：
//  - 大圆角卡片 + 柔和渐变底
//  - 图标磁贴 + 下方小字标签的功能格
//  - 分区留白、弱化分隔线
//  配色沿用项目原有色板（隐颜紫为绝对主色）。
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
        navigationItem.rightBarButtonItem = makeSettingsBarItem()
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        scrollView.alwaysBounceVertical = true
        view.addSubviews(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.alignment = .fill
        scrollView.addSubviews(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        contentStack.addArrangedSubview(makeHeader())
        contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews.last!)

        contentStack.addArrangedSubview(makeHeroBanner())
        contentStack.setCustomSpacing(14, after: contentStack.arrangedSubviews.last!)

        contentStack.addArrangedSubview(makeEntryRow())
        contentStack.setCustomSpacing(14, after: contentStack.arrangedSubviews.last!)

        contentStack.addArrangedSubview(makeFeatureTiles())
        contentStack.setCustomSpacing(14, after: contentStack.arrangedSubviews.last!)

        contentStack.addArrangedSubview(makeStepsCard())
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last!)

        contentStack.addArrangedSubview(makePrivacyFooter())
    }

    /// 右上角圆形设置按钮
    private func makeSettingsBarItem() -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        button.tintColor = Theme.textSecondary
        button.backgroundColor = Theme.surface
        button.layer.cornerRadius = 19
        button.layer.cornerCurve = .continuous
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 38).isActive = true
        button.heightAnchor.constraint(equalToConstant: 38).isActive = true
        return UIBarButtonItem(customView: button)
    }

    // MARK: - 头部

    private func makeHeader() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "theatermasks.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let iconBackground = UIView()
        iconBackground.backgroundColor = Theme.brand
        iconBackground.roundCorners(radius: 18)
        iconBackground.layer.shadowColor = Theme.brand.cgColor
        iconBackground.layer.shadowOpacity = 0.35
        iconBackground.layer.shadowRadius = 12
        iconBackground.layer.shadowOffset = CGSize(width: 0, height: 5)
        iconBackground.addSubviews(icon)

        let title = UILabel()
        title.text = "隐颜 FaceShy"
        title.font = Theme.roundedFont(26, weight: .bold)
        title.textColor = Theme.textPrimary

        let subtitle = UILabel()
        subtitle.text = "本地 AI 遮脸，一键给照片贴上表情"
        subtitle.font = Theme.font(13)
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
            iconBackground.widthAnchor.constraint(equalToConstant: 56),
            iconBackground.heightAnchor.constraint(equalToConstant: 56),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor)
        ])
        return row
    }

    // MARK: - 主视觉卡（渐变横幅）

    private func makeHeroBanner() -> UIView {
        let card = GradientCardView(light: (0x6C5CF0, 0x4B3ED8),
                                    dark: (0x7B6CFF, 0x5446E0))
        card.roundCorners(radius: 24)

        let pill = makeCapsule(text: "🔒 全程本机运行 · 不上传照片")

        let title = UILabel()
        title.text = "给照片一键\n戴上表情面具"
        title.font = Theme.roundedFont(25, weight: .bold)
        title.textColor = .white
        title.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.text = "本地 AI 识别人脸 · 200+ 表情随心换"
        subtitle.font = Theme.font(13, weight: .medium)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.85)

        let textStack = UIStackView(arrangedSubviews: [pill, title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 12
        textStack.alignment = .leading
        textStack.setCustomSpacing(14, after: title)

        // 右侧装饰大 emoji，稍微旋转营造「贴纸」感
        let mask = UILabel()
        mask.text = "🎭"
        mask.font = .systemFont(ofSize: 88)
        mask.alpha = 0.9
        mask.transform = CGAffineTransform(rotationAngle: .pi / 9)
        mask.translatesAutoresizingMaskIntoConstraints = false
        mask.isUserInteractionEnabled = false

        card.addSubviews(textStack, mask)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -92),

            mask.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            mask.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: 6)
        ])
        return card
    }

    /// 白色半透明胶囊小标签
    private func makeCapsule(text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = Theme.font(11, weight: .semibold)
        label.textColor = .white

        let capsule = UIView()
        capsule.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        capsule.layer.cornerRadius = 13
        capsule.clipsToBounds = true
        capsule.addSubviews(label)
        label.pinEdges(to: capsule, insets: UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12))
        return capsule
    }

    // MARK: - 双入口卡

    private func makeEntryRow() -> UIView {
        let row = UIStackView(arrangedSubviews: [
            makeEntryCard(light: (0xEDEAFF, 0xDCD4FB),
                          dark: (0x2C2652, 0x211D40),
                          symbol: "photo.on.rectangle.angled",
                          title: "相册选图",
                          subtitle: "多人合照一次搞定",
                          badge: "GO",
                          accent: Theme.brand,
                          selector: #selector(pickFromLibrary)),
            makeEntryCard(light: (0xE0F5EA, 0xC9EED9),
                          dark: (0x1D352B, 0x16281F),
                          symbol: "camera.fill",
                          title: "拍照导入",
                          subtitle: CameraService.isCameraAvailable ? "拍完立刻遮脸" : "请用相册选图",
                          badge: nil,
                          accent: Theme.success,
                          selector: #selector(takePhoto))
        ])
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        return row
    }

    private func makeEntryCard(light: (UInt32, UInt32),
                               dark: (UInt32, UInt32),
                               symbol: String,
                               title: String,
                               subtitle: String,
                               badge: String?,
                               accent: UIColor,
                               selector: Selector) -> UIControl {
        let container = UIControl()
        let card = GradientCardView(light: light, dark: dark)
        card.roundCorners(radius: 22)
        container.addSubviews(card)
        card.pinEdges(to: container)

        container.addTarget(self, action: #selector(entryCardTapped), for: .touchUpInside)
        container.addTarget(self, action: selector, for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        icon.tintColor = accent
        icon.contentMode = .center

        let iconTile = UIView()
        iconTile.backgroundColor = UIColor.white.withAlphaComponent(0.62)
        iconTile.roundCorners(radius: 14)
        iconTile.addSubviews(icon)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.roundedFont(17, weight: .bold)
        titleLabel.textColor = Theme.textPrimary

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = Theme.font(12)
        subtitleLabel.textColor = Theme.textSecondary
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconTile, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.setCustomSpacing(10, after: iconTile)
        stack.setCustomSpacing(2, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubviews(stack)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 148),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),

            iconTile.widthAnchor.constraint(equalToConstant: 42),
            iconTile.heightAnchor.constraint(equalToConstant: 42),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor)
        ])

        if let badge = badge {
            let badgeLabel = UILabel()
            badgeLabel.text = badge
            badgeLabel.font = Theme.roundedFont(14, weight: .bold)
            badgeLabel.textColor = accent

            let badgeView = UIView()
            badgeView.backgroundColor = UIColor.white.withAlphaComponent(0.78)
            badgeView.roundCorners(radius: 14)
            badgeView.addSubviews(badgeLabel)
            badgeLabel.pinEdges(to: badgeView, insets: UIEdgeInsets(top: 5, left: 14, bottom: 5, right: 14))
            badgeView.translatesAutoresizingMaskIntoConstraints = false

            container.addSubviews(badgeView)
            NSLayoutConstraint.activate([
                badgeView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                badgeView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
            ])
        }
        return container
    }

    // MARK: - 功能磁贴

    private func makeFeatureTiles() -> UIView {
        let row = UIStackView(arrangedSubviews: [
            makeFeatureTile(symbol: "face.smiling", title: "本地识别"),
            makeFeatureTile(symbol: "person.fill.viewfinder", title: "自动抠图"),
            makeFeatureTile(symbol: "theatermasks", title: "海量表情"),
            makeFeatureTile(symbol: "lock.shield", title: "仅存本机")
        ])
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    private func makeFeatureTile(symbol: String, title: String) -> UIView {
        let tile = UIView()
        tile.backgroundColor = Theme.surface
        tile.roundCorners(radius: 20)

        let icon = UIImageView(image: UIImage(systemName: symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)))
        icon.tintColor = Theme.brand
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = Theme.font(12, weight: .medium)
        label.textColor = Theme.textSecondary
        label.textAlignment = .center

        tile.addSubviews(icon, label)
        NSLayoutConstraint.activate([
            tile.heightAnchor.constraint(equalToConstant: 84),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.topAnchor.constraint(equalTo: tile.topAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),
            label.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: tile.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: tile.trailingAnchor, constant: -4)
        ])
        return tile
    }

    // MARK: - 使用步骤

    private func makeStepsCard() -> UIView {
        let title = UILabel()
        title.text = "使用步骤"
        title.font = Theme.font(13, weight: .semibold)
        title.textColor = Theme.textTertiary

        let steps = [
            "选图或拍照导入",
            "本地 AI 自动识别人脸并贴上表情",
            "拖动 / 双指缩放旋转微调",
            "一键保存到相册"
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        for (index, text) in steps.enumerated() {
            let number = UILabel()
            number.text = "\(index + 1)"
            number.font = Theme.roundedFont(12, weight: .bold)
            number.textColor = Theme.brand
            number.textAlignment = .center
            number.backgroundColor = Theme.brandSoft
            number.layer.cornerRadius = 11
            number.clipsToBounds = true
            number.translatesAutoresizingMaskIntoConstraints = false

            let label = UILabel()
            label.text = text
            label.font = Theme.font(13)
            label.textColor = Theme.textPrimary
            label.numberOfLines = 0

            let row = UIView()
            row.addSubviews(number, label)
            NSLayoutConstraint.activate([
                row.heightAnchor.constraint(equalToConstant: 22),
                number.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                number.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                number.widthAnchor.constraint(equalToConstant: 22),
                number.heightAnchor.constraint(equalToConstant: 22),
                label.leadingAnchor.constraint(equalTo: number.trailingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                label.centerYAnchor.constraint(equalTo: row.centerYAnchor)
            ])
            stack.addArrangedSubview(row)
        }

        let card = UIView()
        card.backgroundColor = Theme.surface
        card.roundCorners(radius: 22)

        let vertical = UIStackView(arrangedSubviews: [title, stack])
        vertical.axis = .vertical
        vertical.spacing = 14
        card.addSubviews(vertical)
        vertical.pinEdges(to: card, insets: UIEdgeInsets(top: 18, left: 20, bottom: 20, right: 20))
        return card
    }

    // MARK: - 底部隐私说明

    private func makePrivacyFooter() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = Theme.textTertiary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "所有照片仅保存在本机，不会上传网络"
        label.font = Theme.font(12)
        label.textColor = Theme.textTertiary
        label.textAlignment = .center

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14)
        ])
        return row
    }

    // MARK: - Actions

    @objc private func entryCardTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

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
