//
//  Theme.swift
//  FaceShy
//
//  统一的颜色 / 字体 / 圆角规范。所有颜色均为动态颜色（Dynamic Color），
//  自动跟随系统浅色、深色模式切换，无需手动监听。
//

import UIKit

// MARK: - UIColor Helpers

extension UIColor {

    /// 用 16 进制值创建颜色，例如 UIColor(rgb: 0x5B4BE8)
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(rgb & 0xFF) / 255.0,
                  alpha: alpha)
    }

    /// 浅色 / 深色两套色值，自动切换
    static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        }
    }
}

// MARK: - Theme

enum Theme {

    // 品牌色：隐颜紫
    static let brand = UIColor.adaptive(light: 0x5B4BE8, dark: 0x9B8CFF)
    static let brandSoft = UIColor.adaptive(light: 0xEDEAFF, dark: 0x24203C)
    static let danger = UIColor.adaptive(light: 0xF0453C, dark: 0xFF6B60)
    static let success = UIColor.adaptive(light: 0x1EA362, dark: 0x3ED08A)

    // 背景层级
    static let background = UIColor.adaptive(light: 0xF4F4F9, dark: 0x0D0E13)
    static let surface = UIColor.adaptive(light: 0xFFFFFF, dark: 0x171922)
    static let surfaceAlt = UIColor.adaptive(light: 0xEDEDF4, dark: 0x21242F)
    static let canvasBackdrop = UIColor.adaptive(light: 0xE6E6EE, dark: 0x08090C)

    // 文字
    static let textPrimary = UIColor.adaptive(light: 0x15161C, dark: 0xF2F3F7)
    static let textSecondary = UIColor.adaptive(light: 0x6B6E7C, dark: 0x9AA0B0)
    static let textTertiary = UIColor.adaptive(light: 0x9A9DAB, dark: 0x6E7382)

    static let separator = UIColor.adaptive(light: 0xE3E3EC, dark: 0x2B2E3A)

    // MARK: 字体

    /// 圆润风格字体（emoji / 标题使用，观感更友好）
    static func roundedFont(_ size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func font(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }

    // MARK: 全局外观

    static func applyGlobalAppearance() {
        let navBar = UINavigationBarAppearance()
        navBar.configureWithOpaqueBackground()
        navBar.backgroundColor = Theme.surface
        navBar.shadowColor = Theme.separator
        navBar.titleTextAttributes = [.foregroundColor: Theme.textPrimary]
        navBar.largeTitleTextAttributes = [.foregroundColor: Theme.textPrimary]

        let proxy = UINavigationBar.appearance()
        proxy.standardAppearance = navBar
        proxy.compactAppearance = navBar
        proxy.scrollEdgeAppearance = navBar
    }
}
