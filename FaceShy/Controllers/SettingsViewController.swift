//
//  SettingsViewController.swift
//  FaceShy
//
//  设置页：清除本地自定义表情包 / 隐私说明 / 版本信息
//
//  视觉风格对齐参考稿（主流 App 设置页）：
//  - 三级色小节标题（「表情包 / 隐私 / 关于」）
//  - 行内图标放在圆角小磁贴里，着色与功能语义一致
//  - 行高加大（58pt）、圆角分组卡片、弱化分隔线
//

import UIKit

final class SettingsViewController: UIViewController {

    private enum Row: Int, CaseIterable {
        case clearStickers
        case privacy
        case version
    }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let store = CustomStickerStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = Theme.background
        navigationItem.largeTitleDisplayMode = .never

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SettingsRowCell.self, forCellReuseIdentifier: SettingsRowCell.reuseIdentifier)
        tableView.rowHeight = 58

        view.addSubviews(tableView)
        tableView.pinEdges(to: view)

        tableView.tableFooterView = makeFooter()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    // MARK: - 数据描述

    private func row(at indexPath: IndexPath) -> Row {
        Row.allCases[indexPath.section]
    }

    private func describe(_ row: Row) -> (symbol: String,
                                          tint: UIColor,
                                          title: String,
                                          detail: String?,
                                          showsChevron: Bool) {
        switch row {
        case .clearStickers:
            return ("trash",
                    Theme.danger,
                    "清除本地自定义表情包",
                    store.stickerCount > 0 ? "\(store.stickerCount) 张" : nil,
                    true)
        case .privacy:
            return ("lock.shield",
                    Theme.brand,
                    "隐私说明",
                    nil,
                    true)
        case .version:
            return ("info.circle",
                    Theme.textSecondary,
                    "版本信息",
                    appVersion(),
                    false)
        }
    }

    // MARK: - 页脚

    private func makeFooter() -> UIView {
        let label = UILabel()
        label.text = "隐颜 FaceShy 不会收集、上传任何照片与人脸数据。\n所有 AI 运算都在你的 iPhone 本地完成。"
        label.font = Theme.font(12)
        label.textColor = Theme.textTertiary
        label.numberOfLines = 0
        label.textAlignment = .center

        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 96))
        container.addSubviews(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 22)
        ])
        return container
    }

    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    // MARK: - 动作

    private func clearCustomStickers() {
        let count = store.stickerCount
        guard count > 0 else {
            presentAlert(title: "还没有自定义贴纸", message: "去编辑页用「自定义贴纸」上传几张吧。")
            return
        }

        let alert = UIAlertController(title: "清除本地自定义表情包？",
                                      message: "将删除沙盒内 \(count) 张自定义贴纸，共 \(store.diskUsage / 1024) KB。此操作不可恢复。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let removed = self.store.deleteAll()
            self.tableView.reloadData()
            Toast.show("已清除 \(removed) 张自定义贴纸", in: self.view)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        Row.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsRowCell.reuseIdentifier,
                                                 for: indexPath) as! SettingsRowCell
        let info = describe(row(at: indexPath))
        cell.configure(symbol: info.symbol,
                       tint: info.tint,
                       title: info.title,
                       detail: info.detail,
                       showsChevron: info.showsChevron)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let titles = ["表情包", "隐私", "关于"]
        let label = UILabel()
        label.text = "  " + titles[section]
        label.font = Theme.font(13, weight: .semibold)
        label.textColor = Theme.textTertiary
        return label
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 32 : 30
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        12
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        UIView()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch row(at: indexPath) {
        case .clearStickers:
            clearCustomStickers()
        case .privacy:
            navigationController?.pushViewController(PrivacyViewController(), animated: true)
        case .version:
            presentAlert(title: "隐颜 FaceShy",
                         message: "版本 \(appVersion())\n本地 AI 人脸遮挡照片编辑器\n\n技术栈：Swift · UIKit · Apple Vision",
                         actionTitle: "好的")
        }
    }
}

// MARK: - 自定义行（图标磁贴 + 标题 + 详情 + 箭头）

final class SettingsRowCell: UITableViewCell {

    static let reuseIdentifier = "SettingsRowCell"

    private let tileView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevronView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = Theme.surface
        contentView.backgroundColor = .clear
        selectionStyle = .default

        tileView.roundCorners(radius: 10)

        titleLabel.font = Theme.font(15, weight: .medium)
        titleLabel.textColor = Theme.textPrimary

        detailLabel.font = Theme.font(13)
        detailLabel.textColor = Theme.textSecondary
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        detailLabel.setContentHuggingPriority(.required, for: .horizontal)

        chevronView.image = UIImage(systemName: "chevron.right",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        chevronView.tintColor = Theme.textTertiary
        chevronView.contentMode = .scaleAspectFit

        contentView.addSubviews(tileView, titleLabel, detailLabel, chevronView)
        tileView.addSubviews(iconView)

        NSLayoutConstraint.activate([
            tileView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            tileView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            tileView.widthAnchor.constraint(equalToConstant: 32),
            tileView.heightAnchor.constraint(equalToConstant: 32),

            iconView.centerXAnchor.constraint(equalTo: tileView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tileView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: tileView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -8),

            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 12),
            chevronView.heightAnchor.constraint(equalToConstant: 12),

            detailLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -8),
            detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? Theme.surfaceAlt : .clear
        }
    }

    func configure(symbol: String, tint: UIColor, title: String, detail: String?, showsChevron: Bool) {
        iconView.image = UIImage(systemName: symbol,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        iconView.tintColor = tint
        tileView.backgroundColor = tint.withAlphaComponent(0.14)
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = (detail == nil)
        chevronView.isHidden = !showsChevron
    }
}
