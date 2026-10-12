//
//  EmojiCatalog.swift
//  FaceShy
//
//  内置 emoji 表情库（全部为系统 emoji 字符，无需任何网络或资源文件）。
//

import Foundation

enum EmojiCatalog {

    /// 遮脸常用表情（随机表情 & 表情面板默认分组）
    static let faceEmojis: [String] = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🙂",
        "😉", "😊", "😍", "🥰", "😘", "😜", "🤪", "😝",
        "🤗", "🤭", "🤫", "🤔", "😎", "🥳", "😏", "😌",
        "😴", "🤤", "😪", "😇", "🥴", "😵", "🤠", "🤡",
        "👻", "💀", "👽", "🤖", "🎃", "😺", "🐶", "🐱",
        "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
        "🍎", "🍊", "🍋", "🍉", "🍇", "🍓", "🌸", "🌈",
        "⭐️", "💖", "💯", "🔥", "🎈", "🎁", "🍄", "🌻"
    ]

    /// 记录上一次随机到的首个表情，避免「一键随机」时没有变化
    private static var lastEmoji: String?

    /// 生成一组随机表情（数量 = 需要遮挡的人脸数）
    static func randomSet(count: Int) -> [String] {
        guard count > 0 else { return [] }

        if count == 1 {
            var candidate = faceEmojis.randomElement() ?? "😀"
            var guardCount = 0
            while candidate == lastEmoji && faceEmojis.count > 1 && guardCount < 20 {
                candidate = faceEmojis.randomElement() ?? "😀"
                guardCount += 1
            }
            lastEmoji = candidate
            return [candidate]
        }

        var pool = faceEmojis.shuffled()
        if let last = lastEmoji, pool.count > 1, pool.first == last {
            pool.swapAt(0, 1)
        }
        let result = (0..<count).map { pool[$0 % pool.count] }
        lastEmoji = result.first
        return result
    }
}
