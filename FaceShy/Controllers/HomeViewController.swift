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
        #if DEBUG
        installDebugLogButton()
        DebugLog.step("首页加载完成")
        #endif
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
        let title = UILabel()
        title.text = "隐颜 FaceShy"
        title.font = Theme.roundedFont(26, weight: .bold)
        title.textColor = Theme.textPrimary

        let subtitle = UILabel()
        subtitle.text = "本地 AI 遮脸，一键给照片贴上表情"
        subtitle.font = Theme.font(13)
        subtitle.textColor = Theme.textSecondary
        subtitle.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [title, subtitle])
        row.axis = .vertical
        row.spacing = 4
        return row
    }

    // MARK: - 主视觉卡（渐变横幅）

    /// 纯展示卡：不开交互，避免与下面真正的入口按钮抢「可点」的视觉语义
    private func makeHeroBanner() -> UIView {
        let card = HeroBannerView()
        card.roundCorners(radius: 24)
        card.isUserInteractionEnabled = false

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

        // 右侧放 App 图标（带白描边的圆角卡，融入品牌），稍微旋转营造「贴纸」感
        let logoContainer = UIView()
        logoContainer.isUserInteractionEnabled = false
        logoContainer.translatesAutoresizingMaskIntoConstraints = false

        let logoView = UIImageView(image: UIImage(named: "AppLogo"))
        logoView.contentMode = .scaleAspectFill
        logoView.clipsToBounds = true
        logoView.layer.cornerRadius = 20
        logoView.layer.cornerCurve = .continuous
        logoView.layer.borderWidth = 3
        logoView.layer.borderColor = UIColor.white.cgColor
        logoView.isUserInteractionEnabled = false
        logoView.translatesAutoresizingMaskIntoConstraints = false

        logoContainer.addSubview(logoView)
        logoContainer.transform = CGAffineTransform(rotationAngle: .pi / 14)

        card.addSubviews(textStack, logoContainer)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -96),

            logoContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            logoContainer.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 78),
            logoView.heightAnchor.constraint(equalToConstant: 78),
            logoView.topAnchor.constraint(equalTo: logoContainer.topAnchor),
            logoView.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor),
            logoView.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor),
            logoView.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor)
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

    // MARK: - 双入口卡（首页唯一可点的功能按钮，视觉上要一眼看出来）

    private func makeEntryRow() -> UIView {
        let row = UIStackView(arrangedSubviews: [
            makeEntryButton(title: "相册选图",
                            subtitle: "人脸一键遮挡",
                            symbol: "photo.on.rectangle.angled",
                            selector: #selector(pickFromLibrary)),
            makeEntryButton(title: "拍照导入",
                            subtitle: CameraService.isCameraAvailable ? "拍完立刻遮脸" : "请用相册选图",
                            symbol: "camera.fill",
                            selector: #selector(takePhoto))
        ])
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        return row
    }

    /// 实心品牌色主按钮卡：整块可点，带阴影 + 右侧箭头，明确传达「这里能点」
    private func makeEntryButton(title: String,
                                 subtitle: String,
                                 symbol: String,
                                 selector: Selector) -> UIButton {
        let button = EntryCardButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: selector, for: .touchUpInside)
        button.addTarget(self, action: #selector(entryCardTapped), for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)))
        icon.tintColor = .white
        icon.contentMode = .center
        icon.isUserInteractionEnabled = false

        let iconTile = UIView()
        iconTile.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        iconTile.roundCorners(radius: 14)
        iconTile.isUserInteractionEnabled = false
        iconTile.addSubviews(icon)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.roundedFont(18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.isUserInteractionEnabled = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = Theme.font(12, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isUserInteractionEnabled = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.alignment = .leading
        textStack.isUserInteractionEnabled = false

        // 整卡内边距 16：图标 + 文案，垂直居中
        let content = UIStackView(arrangedSubviews: [iconTile, textStack])
        content.axis = .horizontal
        content.spacing = 10
        content.alignment = .center
        content.isUserInteractionEnabled = false
        content.translatesAutoresizingMaskIntoConstraints = false

        button.addSubviews(content)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 118),

            content.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12),
            content.centerYAnchor.constraint(equalTo: button.centerYAnchor),

            iconTile.widthAnchor.constraint(equalToConstant: 42),
            iconTile.heightAnchor.constraint(equalToConstant: 42),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            icon.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor)
        ])
        return button
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
        // 只是说明性磁贴，不是按钮 —— 明确关闭交互，避免「整页都能点」的错觉
        tile.isUserInteractionEnabled = false

        let icon = UIImageView(image: UIImage(systemName: symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)))
        icon.tintColor = Theme.brand
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.isUserInteractionEnabled = false

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
        DebugLog.step("首页 → 相册选图")
        photoPicker.present(from: self) { [weak self] image in
            guard let self = self else { return }
            guard let image = image else {
                DebugLog.step("相册选图：用户取消 / 未取到图片")
                return
            }
            DebugLog.step("相册选图：取到图片 \(Int(image.size.width))x\(Int(image.size.height))")
            self.openEditor(with: image)
        }
    }

    @objc private func takePhoto() {
        DebugLog.step("首页 → 拍照导入（相机可用：\(CameraService.isCameraAvailable)）")
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

// MARK: - 主视觉卡

/// 首页顶部品牌主视觉背景：斜向品牌渐变。
/// 纯装饰（isUserInteractionEnabled = false），不参与任何点击。
private final class HeroBannerView: UIView {

    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1.15, y: 1)
        gradient.colors = [
            UIColor(rgb: 0x6C5CF0).cgColor,
            UIColor(rgb: 0x4B3ED8).cgColor
        ]
        layer.insertSublayer(gradient, at: 0)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }
}

// MARK: - 入口主按钮

/// 首页双入口按钮：实心品牌渐变 + 阴影 + 按压回弹，
/// 自带渐变层而不是「按钮里再塞一个装饰视图」，从根上杜绝点击被吞的问题。
final class EntryCardButton: UIButton {

    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.colors = [
            UIColor.adaptive(light: 0x6C5CF0, dark: 0x7B6CFF).cgColor,
            UIColor.adaptive(light: 0x4B3ED8, dark: 0x4E3FD8).cgColor
        ]
        layer.insertSublayer(gradient, at: 0)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.adaptive(light: 0x4B3ED8, dark: 0x000000).cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)
        clipsToBounds = false
        layer.masksToBounds = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.cornerRadius = layer.cornerRadius
        CATransaction.commit()
    }

    /// 只有本按钮参与命中测试；子视图（图标 / 文案 / 箭头）全部不拦事件
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        return bounds.contains(point) ? self : nil
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.14, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                    : .identity
                self.alpha = self.isHighlighted ? 0.92 : 1
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        gradient.colors = [
            UIColor.adaptive(light: 0x6C5CF0, dark: 0x7B6CFF).resolvedColor(with: traitCollection).cgColor,
            UIColor.adaptive(light: 0x4B3ED8, dark: 0x4E3FD8).resolvedColor(with: traitCollection).cgColor
        ]
        layer.shadowColor = UIColor.adaptive(light: 0x4B3ED8, dark: 0x000000)
            .resolvedColor(with: traitCollection).cgColor
    }
}

// MARK: - 相机回调

extension HomeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        DebugLog.step("相机：拍完回调")
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        openEditor(with: image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        DebugLog.step("相机：用户取消")
        picker.dismiss(animated: true)
    }
}
