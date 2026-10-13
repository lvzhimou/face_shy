//
//  StickerCatalog.swift
//  FaceShy
//
//  内置表情目录，分三类：
//  - emoji：系统 emoji，只保留「脸部占满整个字形」的表情，
//    已剔除手势 / 物品 / 内脏 / 全身人物等遮不住脸的（💯 类、👍 类等）
//  - 女生 / 男生：内置 Q版人物头像表情（bundle StickerPacks/Girls | Boys），
//    用于自动贴表情时按识别到的性别匹配
//
//  全部资源随 App 打包，本地读取，无网络。
//

import UIKit

/// 表情面板的三大页签
enum StickerSection: Int, CaseIterable {
    case emoji = 0
    case girl = 1
    case boy = 2

    var title: String {
        switch self {
        case .emoji: return "表情"
        case .girl: return "女生"
        case .boy: return "男生"
        }
    }

    var gender: AvatarGender? {
        switch self {
        case .emoji: return nil
        case .girl: return .girl
        case .boy: return .boy
        }
    }
}

enum StickerCatalog {

    // MARK: - emoji（全部为脸部特写，可完整遮脸）

    static let emojis: [String] = [
        // 经典脸
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣",
        "🥲", "🥹", "😊", "😇", "🙂", "🙃", "😉", "😌",
        "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛",
        "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸",
        "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕",
        "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭",
        // 强情绪脸
        "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶",
        "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭",
        "🤫", "🤥", "😶", "😐", "😑", "😬", "🙄", "😯",
        "😦", "😧", "😮", "😲", "🥱", "😴", "🤤", "😪",
        "😵", "🤐", "🥴", "🤢", "🤮", "🤧", "😷", "🤒",
        "🤕", "🤑", "🤠", "🤡", "😈", "👿", "👻", "💀",
        // 拟人脸（脸部占比大）
        "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓",
        "👴", "👵", "🤖", "👽", "🎃",
        // 动物脸（脸部占满字形）
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼",
        "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🙈",
        "🙉", "🙊", "🐔", "🐧", "🐦", "🐤", "🦆", "🦉",
        "🦄", "🐬", "🐳"
    ]

    // MARK: - 内置 Q版人物表情（bundle 资源）

    static let girlStickers: [String] = (1...50).map { String(format: "girl_%02d", $0) }
    static let boyStickers: [String] = (1...50).map { String(format: "boy_%02d", $0) }

    /// 读取内置 Q版表情（bundle StickerPacks/Girls | Boys 目录）
    static func avatarImage(named fileName: String, gender: AvatarGender) -> UIImage? {
        let folder = gender == .girl ? "Girls" : "Boys"
        guard let url = Bundle.main.url(forResource: fileName,
                                        withExtension: "png",
                                        subdirectory: folder) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func stickers(for gender: AvatarGender) -> [String] {
        gender == .girl ? girlStickers : boyStickers
    }

    // MARK: - 随机

    /// 记录上一次随机结果，避免「一键随机」时没有变化
    private static var lastRandomValue: String?

    /// 随机一个 emoji（带防重复）
    static func randomEmoji() -> String {
        var candidate = emojis.randomElement() ?? "😀"
        var guardCount = 0
        while candidate == lastRandomValue && emojis.count > 1 && guardCount < 20 {
            candidate = emojis.randomElement() ?? "😀"
            guardCount += 1
        }
        lastRandomValue = candidate
        return candidate
    }

    /// 随机一个内置 Q版表情（带防重复）
    static func randomAvatar(gender: AvatarGender) -> String {
        let pool = stickers(for: gender)
        var candidate = pool.randomElement() ?? (pool.first ?? "girl_01")
        var guardCount = 0
        while candidate == lastRandomValue && pool.count > 1 && guardCount < 20 {
            candidate = pool.randomElement() ?? (pool.first ?? "girl_01")
            guardCount += 1
        }
        lastRandomValue = candidate
        return candidate
    }
}
