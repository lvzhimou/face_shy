//
//  CustomStickerStore.swift
//  FaceShy
//
//  用户自定义表情包的本地存储。
//
//  - 保存在 App 沙盒 Application Support/CustomStickers 目录
//  - 上传的图片会先压缩到最长边 512px，避免超大图导致内存溢出
//  - 只写本机磁盘，不做任何上传
//

import UIKit

final class CustomStickerStore {

    static let shared = CustomStickerStore()

    /// 自定义贴纸单边最大像素（防止内存溢出）
    private let maxStickerDimension: CGFloat = 512

    private let fileManager = FileManager.default

    private lazy var directory: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("CustomStickers", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private init() {}

    // MARK: - 读取

    /// 已保存的贴纸文件名（按创建时间倒序，最新的排前面）
    func stickerFileNames() -> [String] {
        guard let urls = try? fileManager.contentsOfDirectory(at: directory,
                                                             includingPropertiesForKeys: [.creationDateKey],
                                                             options: [.skipsHiddenFiles]) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return l > r
            }
            .map { $0.lastPathComponent }
    }

    /// 贴纸数量
    var stickerCount: Int { stickerFileNames().count }

    /// 拼出完整路径
    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// 读取贴纸图片
    func image(named fileName: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: fileName)) else { return nil }
        return UIImage(data: data)
    }

    /// 占用磁盘空间（字节）
    var diskUsage: Int64 {
        stickerFileNames().reduce(0) { partial, name in
            let attributes = try? fileManager.attributesOfItem(atPath: url(for: name).path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            return partial + size
        }
    }

    // MARK: - 写入

    /// 保存一张自定义贴纸，返回沙盒文件名
    @discardableResult
    func addSticker(from image: UIImage) throws -> String {
        // 压缩尺寸 + 磨平方向
        let compressed = image.resized(maxDimension: maxStickerDimension).normalizedOrientation()

        guard let data = compressed.jpegData(compressionQuality: 0.92) else {
            throw StickerStoreError.encodeFailed
        }

        let fileName = "sticker_\(UUID().uuidString).jpg"
        try data.write(to: url(for: fileName), options: .atomic)
        return fileName
    }

    // MARK: - 删除

    func deleteSticker(named fileName: String) {
        try? fileManager.removeItem(at: url(for: fileName))
    }

    /// 清空全部自定义贴纸（设置页「清除本地自定义表情包」）
    @discardableResult
    func deleteAll() -> Int {
        let names = stickerFileNames()
        names.forEach { deleteSticker(named: $0) }
        return names.count
    }
}

enum StickerStoreError: LocalizedError {
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .encodeFailed: return "这张图片无法保存为贴纸，请换一张试试"
        }
    }
}
