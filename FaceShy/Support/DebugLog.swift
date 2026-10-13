//
//  DebugLog.swift
//  FaceShy
//
//  极轻量的操作日志，用于真机排障：
//
//  - 控制台（Xcode / Console.app）能看到带时间戳的记录
//  - 顶部下滑通知中心右侧可临时展开（仅 DEBUG 编译生效）
//
//  定位不到问题时可以在手机上直接看最后几步走到了哪里，
//  不用连电脑抓日志。Release 包只有控制台输出，无任何界面痕迹。
//

import UIKit

enum DebugLog {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static var lines: [String] = []

    /// 记一步操作（同时打印到控制台）
    static func step(_ text: String) {
        let line = "[\(formatter.string(from: Date()))] \(text)"
        lines.append(line)
        print("FaceShy " + line)
        if lines.count > 120 { lines.removeFirst(lines.count - 120) }
    }

    /// 把整个会话的操作日志拼成一段文本（分享 / 复制用）
    static func transcript() -> String {
        lines.isEmpty ? "（暂无记录）" : lines.joined(separator: "\n")
    }
}

#if DEBUG

// MARK: - 真机排障面板（仅 DEBUG）

extension UIViewController {

    /// 在导航栏右上角挂一个「日志」入口，点开可看本次会话的操作轨迹
    func installDebugLogButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ladybug"), for: .normal)
        button.tintColor = Theme.textTertiary
        button.addTarget(self, action: #selector(showDebugLog), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 34, height: 34)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
    }

    @objc private func showDebugLog() {
        let textView = UITextView()
        textView.text = DebugLog.transcript()
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        textView.backgroundColor = Theme.background
        textView.textColor = Theme.textPrimary
        textView.contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let controller = UIViewController()
        controller.view.backgroundColor = Theme.background
        controller.view.addSubviews(textView)
        textView.pinEdges(to: controller.view)
        controller.title = "操作日志"

        let navigation = UINavigationController(rootViewController: controller)
        present(navigation, animated: true)
    }
}

#endif
