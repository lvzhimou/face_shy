//
//  EmojiCatalog.swift
//  FaceShy
//
//  内置 emoji 表情库（全部为系统 emoji 字符，无需任何网络或资源文件）。
//  按「基础脸 / 高级脸 1 / 高级脸 2 / 高级脸 3」四个分组组织，共 200 个，
//  全部以「遮脸」为选型标准：优先 emoji 字形大、五官居中、覆盖面积大的表情。
//

import Foundation

enum EmojiCategory: Int, CaseIterable {
    case basic = 0
    case advanced1 = 1
    case advanced2 = 2
    case advanced3 = 3

    /// 分组标题（表情面板页签）
    var title: String {
        switch self {
        case .basic: return "基础脸"
        case .advanced1: return "高级脸 1"
        case .advanced2: return "高级脸 2"
        case .advanced3: return "高级脸 3"
        }
    }
}

enum EmojiCatalog {

    // MARK: - 分组定义

    /// 基础脸：最常用、最百搭的遮脸表情
    static let basic: [String] = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣",
        "🥲", "🥹", "😊", "😇", "🙂", "🙃", "😉", "😌",
        "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛",
        "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸",
        "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕",
        "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭"
    ]

    /// 高级脸 1：委屈 / 难过 / 惊讶 / 生气等强情绪（参考截图里的流泪脸系列）
    static let advanced1: [String] = [
        "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶",
        "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭",
        "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯",
        "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪",
        "😵", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒",
        "🤕", "🤑", "🤠", "🤡", "😈", "👿", "👻", "💀"
    ]

    /// 高级脸 2：人物形象 / 手势 / 配件（适合整体遮盖，风格更强）
    static let advanced2: [String] = [
        "🙏", "🤝", "👏", "🙌", "👐", "🤲", "🫶", "✌️",
        "🤞", "🫰", "🤙", "👍", "👎", "👌", "🤌", "🤏",
        "👀", "👁️", "👄", "🫦", "🧠", "🫀", "👣", "🦶",
        "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓",
        "👴", "👵", "👮", "🕵️", "💃", "🕺", "🧘", "🏃",
        "🦸", "🦹", "🧙", "🧚", "🧛", "🧜", "🧝", "🧞",
        "🧟", "🤖", "👽", "🎃", "👼", "🎅", "🤶", "🧑‍🎤"
    ]

    /// 高级脸 3：动物与卡通形象（适合整体遮盖，趣味性强）
    static let advanced3: [String] = [
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼",
        "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈",
        "🙉", "🙊", "🐔", "🐧", "🐦", "🐤", "🦆", "🦉",
        "🦄", "🐝", "🦋", "🐌", "🐞", "🐢", "🐍", "🐙",
        "🦀", "🐠", "🐬", "🐳", "🌸", "🌻", "🌹", "🍀",
        "🌈", "⭐️", "🌙", "☁️", "🔥", "💖", "💜", "🧡"
    ]

    // MARK: - 汇总

    /// 全部分组（顺序即面板页签顺序）
    static let categories: [(category: EmojiCategory, emojis: [String])] = [
        (.basic, basic),
        (.advanced1, advanced1),
        (.advanced2, advanced2),
        (.advanced3, advanced3)
    ]

    /// 全部表情合集（随机表情时使用）
    static let allEmojis: [String] = categories.flatMap { $0.emojis }

    /// 某一分组的表情
    static func emojis(in category: EmojiCategory) -> [String] {
        switch category {
        case .basic: return basic
        case .advanced1: return advanced1
        case .advanced2: return advanced2
        case .advanced3: return advanced3
        }
    }

    // MARK: - 随机

    /// 记录上一次随机到的首个表情，避免「一键随机」时没有变化
    private static var lastEmoji: String?

    /// 生成一组随机表情（数量 = 需要遮挡的人脸数）
    static func randomSet(count: Int) -> [String] {
        guard count > 0 else { return [] }
        let pool = allEmojis

        if count == 1 {
            var candidate = pool.randomElement() ?? "😀"
            var guardCount = 0
            while candidate == lastEmoji && pool.count > 1 && guardCount < 20 {
                candidate = pool.randomElement() ?? "😀"
                guardCount += 1
            }
            lastEmoji = candidate
            return [candidate]
        }

        var shuffled = pool.shuffled()
        if let last = lastEmoji, shuffled.count > 1, shuffled.first == last {
            shuffled.swapAt(0, 1)
        }
        let result = (0..<count).map { shuffled[$0 % shuffled.count] }
        lastEmoji = result.first
        return result
    }
}
