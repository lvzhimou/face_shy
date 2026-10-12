//
//  EmojiPickerViewController.swift
//  FaceShy
//
//  表情面板：系统 emoji + 我的贴纸（自定义表情包）
//
//  - 点选系统 emoji -> 回调给编辑器替换贴纸
//  - 「我的贴纸」页签可上传新贴纸（保存到沙盒）、长按删除
//

import UIKit

final class EmojiPickerViewController: UIViewController {

    /// 选中内容后的回调
    var onPick: ((ItemContent) -> Void)?

    private enum Mode: Int {
        case system = 0
        case custom = 1
    }

    private enum Section {
        static let main = 0
    }

    private let segmentedControl = UISegmentedControl(items: ["系统表情", "我的贴纸"])
    private let hintLabel = UILabel()
    private var collectionView: UICollectionView!

    private let store = CustomStickerStore.shared
    private lazy var photoPicker = PhotoPicker()

    private var mode: Mode = .system
    private var customStickers: [String] = []

    private let columnCount: CGFloat = 6
    private let cellSpacing: CGFloat = 8
    private let sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 28, right: 16)

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
        titleLabel.text = "选择表情"
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

        segmentedControl.selectedSegmentIndex = Mode.system.rawValue
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        hintLabel.font = Theme.font(12)
        hintLabel.textColor = Theme.textSecondary
        hintLabel.numberOfLines = 0
        hintLabel.text = "点选后会替换选中的贴纸；若没有选中，则替换全部人脸贴纸。"

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

    // MARK: - Data

    private func reloadCustomStickers() {
        customStickers = store.stickerFileNames()
        collectionView.reloadData()
    }

    @objc private func segmentChanged() {
        mode = Mode(rawValue: segmentedControl.selectedSegmentIndex) ?? .system
        hintLabel.text = mode == .system
            ? "点选后会替换选中的贴纸；若没有选中，则替换全部人脸贴纸。"
            : "这些是你上传的贴纸，保存在本机沙盒。长按可删除。"
        collectionView.reloadData()
    }

    /// 自定义贴纸数量 + 1（多一个「上传」入口）
    private var customItemCount: Int {
        customStickers.count + 1
    }

    // MARK: - 上传 / 删除

    private func addCustomSticker() {
        photoPicker.present(from: self) { [weak self] image in
            guard let self = self, let image = image else { return }
            do {
                let fileName = try self.store.addSticker(from: image)
                self.reloadCustomStickers()
                self.onPick?(.customSticker(fileName: fileName))
                self.dismiss(animated: true)
            } catch {
                self.presentAlert(title: "添加失败", message: error.localizedDescription)
            }
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, mode == .custom else { return }
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

// MARK: - UICollectionViewDataSource

extension EmojiPickerViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch mode {
        case .system: return EmojiCatalog.faceEmojis.count
        case .custom: return customItemCount
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseIdentifier,
                                                      for: indexPath) as! EmojiCell

        switch mode {
        case .system:
            cell.configure(emoji: EmojiCatalog.faceEmojis[indexPath.item])

        case .custom:
            if indexPath.item == 0 {
                cell.configureUpload()
            } else {
                let fileName = customStickers[indexPath.item - 1]
                cell.configure(image: store.image(named: fileName))
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

        switch mode {
        case .system:
            onPick?(.emoji(EmojiCatalog.faceEmojis[indexPath.item]))
            dismiss(animated: true)

        case .custom:
            if indexPath.item == 0 {
                addCustomSticker()
            } else {
                let fileName = customStickers[indexPath.item - 1]
                onPick?(.customSticker(fileName: fileName))
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
