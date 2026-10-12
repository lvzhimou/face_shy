//
//  AppSettings.swift
//  FaceShy
//
//  轻量本地设置（UserDefaults）。不收集任何用户数据。
//

import Foundation

enum AppSettings {

    private enum Key {
        static let compressOnExport = "faceshy.setting.compressOnExport"
        static let didShowPrivacyTip = "faceshy.setting.didShowPrivacyTip"
    }

    /// 导出时是否压缩（默认高清不压缩，符合需求文档）
    static var compressOnExport: Bool {
        get { UserDefaults.standard.bool(forKey: Key.compressOnExport) }
        set { UserDefaults.standard.set(newValue, forKey: Key.compressOnExport) }
    }

    static var didShowPrivacyTip: Bool {
        get { UserDefaults.standard.bool(forKey: Key.didShowPrivacyTip) }
        set { UserDefaults.standard.set(newValue, forKey: Key.didShowPrivacyTip) }
    }
}
