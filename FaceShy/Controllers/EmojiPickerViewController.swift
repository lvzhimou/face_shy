//
//  EmojiPickerViewController.swift
//  FaceShy
//
//  表情面板（4 个页签）：
//  - 「表情」：系统 emoji（已筛选为可遮脸的）
//  - 「女生」/「男生」：内置 Q版人物头像表情
//  - 「我的贴纸」：上传自定义贴纸（自动抠图，保存到沙盒）、长按删除
//
//  点选后通过 onPick 回调给编辑器替换贴纸内容。
//

import UIKit

final class EmojiPickerViewController: UIViewController {

    /// 选中内容后的回调
    var onPick: ((ItemContent) -> Void)?

    /// 是否是从「换表情」入口进来的（只影响提示文案）
    var isReplacingItem = false

    // MARK: - State

    private let segmentedControl = UISegmentedControl()
    private let hintLabel = UILabel()
    private var collectionView: UICollectionView!

    private let store = CustomStickerStore.shared

    private var customStickers: [String] = []

    private let columnCount: CGFloat = 6
    private let cellSpacing: CGFloat = 8
    private let sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 28, right: 16)

    /// 当前选中的页签
    private var currentSection: PickerSection {
        PickerSection(rawValue: max(0, segmentedControl.selectedSegmentIndex)) ?? .emoji
    }

    private var isCustomMode: Bool { currentSection == .custom }

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupSheet()
        setupUI()
        reloadCustomStickers()
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

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = isReplacingItem ? "更换表情" : "选择表情"
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

        // 分组页签：表情 / 女生 / 男生 / 我的贴纸
        for (index, section) in PickerSection.allCases.enumerated() {
            segmentedControl.insertSegment(withTitle: section.title, at: index, animated: false)
        }
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentedControl.setTitleTextAttributes(
            [.font: Theme.font(13, weight: .medium)], for: .normal)
        segmentedControl.setTitleTextAttributes(
            [.font: Theme.font(13, weight: .semibold)], for: .selected)

        hintLabel.font = Theme.font(12)
        hintLabel.textColor = Theme.textSecondary
        hintLabel.numberOfLines = 0
        hintLabel.text = defaultHint

        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = cellSpacing
        flowLayout.minimumLineSpacing = cellSpacing
        flowLayout.sectionInset = sectionInset

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseIdentifier)
        collectionView.alwaysBounceVertical = true

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)

        let stack = UIStackView(arrangedSubviews: [header, segmentedControl, hintLabel, collectionView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(14, after: header)

        view.addSubviews(stack)
        stack.pinEdges(to: view, insets: UIEdgeInsets(top: 18, left: 16, bottom: 0, right: 16))
    }

    private var defaultHint: String {
        if isReplacingItem {
            return "点一下就能把当前贴纸换成这个表情。"
        }
        return "点选后会替换选中的贴纸；若没有选中，则替换全部人脸贴纸。"
    }

    // MARK: - Data

    private func reloadCustomStickers() {
        customStickers = store.stickerFileNames()
        collectionView.reloadData()
    }

    @objc private func segmentChanged() {
        hintLabel.text = isCustomMode
            ? "这些是你上传的贴纸，保存在本机沙盒。长按可删除。上传时会先本地自动抠图。"
            : (currentSection == .emoji ? defaultHint : "Q版人物表情，自动贴表情时会按识别到的性别匹配。")
        collectionView.setContentOffset(.zero, animated: false)
        collectionView.reloadData()
    }

    /// 自定义贴纸数量 + 1（多一个「上传」入口）
    private var customItemCount: Int {
        customStickers.count + 1
    }

    // MARK: - 上传（走抠图流程）/ 删除

    private func addCustomSticker() {
        StickerUploadFlow.start(from: self) { [weak self] fileName in
            guard let self = self else { return }
            self.reloadCustomStickers()
            self.onPick?(.customSticker(fileName: fileName))
            self.dismiss(animated: true)
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, isCustomMode else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              indexPath.item > 0,
              indexPath.item - 1 < customStickers.count else { return }

        let fileName = customStickers[indexPath.item - 1]
        let alert = UIAlertController(title: "删除这张贴纸？",
                                      message: "删除后无法恢复（不影响已添加到照片上的贴纸）。",
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.store.deleteSticker(named: fileName)
            self.reloadCustomStickers()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = collectionView
            popover.sourceRect = collectionView.cellForItem(at: indexPath)?.frame ?? .zero
        }
        present(alert, animated: true)
    }
}

// MARK: - 面板页签

private enum PickerSection: Int, CaseIterable {
    case emoji = 0
    case girl = 1
    case boy = 2
    case custom = 3

    var title: String {
        switch self {
        case .emoji: return "表情"
        case .girl: return "女生"
        case .boy: return "男生"
        case .custom: return "我的贴纸"
        }
    }
}

// MARK: - UICollectionViewDataSource

extension EmojiPickerViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch currentSection {
        case .emoji: return StickerCatalog.emojis.count
        case .girl: return StickerCatalog.girlStickers.count
        case .boy: return StickerCatalog.boyStickers.count
        case .custom: return customItemCount
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseIdentifier,
                                                      for: indexPath) as! EmojiCell

        switch currentSection {
        case .emoji:
            cell.configure(emoji: StickerCatalog.emojis[indexPath.item])
        case .girl:
            cell.configure(image: StickerCatalog.avatarImage(named: StickerCatalog.girlStickers[indexPath.item],
                                                             gender: .girl))
        case .boy:
            cell.configure(image: StickerCatalog.avatarImage(named: StickerCatalog.boyStickers[indexPath.item],
                                                             gender: .boy))
        case .custom:
            if indexPath.item == 0 {
                cell.configureUpload()
            } else {
                cell.configure(image: store.image(named: customStickers[indexPath.item - 1]))
            }
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EmojiPickerViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let available = collectionView.bounds.width
            - sectionInset.left - sectionInset.right
            - (columnCount - 1) * cellSpacing
        let side = max(floor(available / columnCount), 36)
        return CGSize(width: side, height: side)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)

        switch currentSection {
        case .emoji:
            onPick?(.emoji(StickerCatalog.emojis[indexPath.item]))
            dismiss(animated: true)

        case .girl:
            let name = StickerCatalog.girlStickers[indexPath.item]
            onPick?(.avatar(fileName: name, gender: .girl))
            dismiss(animated: true)

        case .boy:
            let name = StickerCatalog.boyStickers[indexPath.item]
            onPick?(.avatar(fileName: name, gender: .boy))
            dismiss(animated: true)

        case .custom:
            if indexPath.item == 0 {
                addCustomSticker()
            } else {
                onPick?(.customSticker(fileName: customStickers[indexPath.item - 1]))
                dismiss(animated: true)
            }
        }
    }
}

// MARK: - Cell

final class EmojiCell: UICollectionViewCell {

    static let reuseIdentifier = "EmojiCell"

    private let emojiLabel = UILabel()
    private let imageView = UIImageView()
    private let plusIcon = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = Theme.surface
        contentView.roundCorners(radius: 12)

        emojiLabel.font = UIFont.systemFont(ofSize: 30)
        emojiLabel.textAlignment = .center
        emojiLabel.adjustsFontSizeToFitWidth = true
        emojiLabel.minimumScaleFactor = 0.4

        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true

        plusIcon.image = UIImage(systemName: "plus")
        plusIcon.tintColor = Theme.brand
        plusIcon.contentMode = .scaleAspectFit
        plusIcon.isHidden = true

        contentView.addSubviews(emojiLabel, imageView, plusIcon)
        emojiLabel.pinEdges(to: contentView, insets: UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6))
        imageView.pinEdges(to: contentView, insets: UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5))
        NSLayoutConstraint.activate([
            plusIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            plusIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            plusIcon.widthAnchor.constraint(equalToConstant: 22),
            plusIcon.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? Theme.surfaceAlt : Theme.surface
        }
    }

    func configure(emoji: String) {
        contentView.backgroundColor = Theme.surface
        emojiLabel.isHidden = false
        emojiLabel.text = emoji
        imageView.isHidden = true
        imageView.image = nil
        plusIcon.isHidden = true
    }

    func configure(image: UIImage?) {
        contentView.backgroundColor = Theme.surface
        emojiLabel.isHidden = true
        emojiLabel.text = nil
        plusIcon.isHidden = true
        imageView.isHidden = false
        imageView.image = image
    }

    func configureUpload() {
        emojiLabel.isHidden = true
        emojiLabel.text = nil
        imageView.isHidden = true
        imageView.image = nil
        plusIcon.isHidden = false
        contentView.backgroundColor = Theme.brandSoft
    }
}
