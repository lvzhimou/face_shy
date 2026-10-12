//
//  UIImage+Extensions.swift
//  FaceShy
//
//  图片尺寸 / 缩放工具。所有处理都在本机内存中完成，不涉及网络。
//

import UIKit

extension UIImage {

    /// 图片的真实像素尺寸（已考虑 EXIF 旋转方向）
    var pixelSize: CGSize {
        if let cgImage = cgImage {
            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)
            switch imageOrientation {
            case .left, .right, .leftMirrored, .rightMirrored:
                return CGSize(width: height, height: width)
            default:
                return CGSize(width: width, height: height)
            }
        }
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    /// 按最长边等比缩放（只缩不放）
    func resized(maxDimension: CGFloat) -> UIImage {
        let current = pixelSize
        let longest = max(current.width, current.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let ratio = maxDimension / longest
        let targetSize = CGSize(width: floor(current.width * ratio), height: floor(current.height * ratio))
        return resized(to: targetSize)
    }

    /// 重绘到指定像素尺寸（同时把方向烘焙成 .up，避免后续坐标错乱）
    func resized(to targetSize: CGSize) -> UIImage {
        guard targetSize.width > 0, targetSize.height > 0 else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// 修正方向为 .up（内部处理人脸前调用，保证坐标一致）
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let target = pixelSize
        return resized(to: target)
    }

    /// 纯色图片（用于按钮底色等）
    static func solid(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
