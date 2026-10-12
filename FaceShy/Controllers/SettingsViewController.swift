//
//  SettingsViewController.swift
//  FaceShy
//
//  设置页：清除本地自定义表情包 / 隐私说明 / 版本信息
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
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 54

        view.addSubviews(tableView)
        tableView.pinEdges(to: view)

        let footer = makeFooter()
        tableView.tableFooterView = footer
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    private func makeFooter() -> UIView {
        let label = UILabel()
        label.text = "隐颜 FaceShy 不会收集、上传任何照片与人脸数据。\n所有 AI 运算都在你的 iPhone 本地完成。"
        label.font = Theme.font(12)
        label.textColor = Theme.textTertiary
        label.numberOfLines = 0
        label.textAlignment = .center

        let container = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 90))
        container.addSubviews(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 20)
        ])
        return container
    }

    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.textProperties.font = Theme.font(15)
        configuration.textProperties.color = Theme.textPrimary

        var accessory: UITableViewCell.AccessoryType = .disclosureIndicator

        switch Row(rawValue: indexPath.row)! {
        case .clearStickers:
            configuration.text = "清除本地自定义表情包"
            configuration.image = UIImage(systemName: "trash")
            configuration.imageProperties.tintColor = Theme.danger
            configuration.secondaryText = "当前 \(store.stickerCount) 张"
            configuration.secondaryTextProperties.font = Theme.font(12)
            configuration.secondaryTextProperties.color = Theme.textSecondary
        case .privacy:
            configuration.text = "隐私说明"
            configuration.image = UIImage(systemName: "lock.shield")
            configuration.imageProperties.tintColor = Theme.brand
        case .version:
            configuration.text = "版本信息"
            configuration.image = UIImage(systemName: "info.circle")
            configuration.imageProperties.tintColor = Theme.textSecondary
            configuration.secondaryText = appVersion()
            configuration.secondaryTextProperties.font = Theme.font(12)
            configuration.secondaryTextProperties.color = Theme.textSecondary
            accessory = .none
        }

        cell.contentConfiguration = configuration
        cell.accessoryType = accessory
        cell.backgroundColor = Theme.surface
        let background = UIView()
        background.backgroundColor = Theme.surfaceAlt
        cell.selectedBackgroundView = background
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Row(rawValue: indexPath.row)! {
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
