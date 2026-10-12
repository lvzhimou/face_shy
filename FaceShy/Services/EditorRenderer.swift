//
//  EditorRenderer.swift
//  FaceShy
//
//  导出渲染：把「照片 + 全部贴纸 / 水印」按原始分辨率合成成一张图片。
//
//  几何一致性：编辑画布上的 canvasSize 与导出画布通过同一个缩放系数 k 换算，
//  元素的位置 / 缩放 / 旋转 / 透明度完全复用模型数据，保证所见即所得。
//

import UIKit

enum EditorRenderer {

    /// 导出图片的最大像素（超大图会等比缩小到该值，避免内存溢出）
    static let maxExportDimension: CGFloat = 4096

    /// 合成最终图片
    /// - Parameters:
    ///   - image: 原图
    ///   - items: 按图层顺序从下到上排列的元素
    ///   - canvasSize: 编辑时画布的 point 尺寸（即显示照片的那块区域大小）
    static func render(image: UIImage, items: [EditorItem], canvasSize: CGSize) -> UIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let basePixels = cappedPixelSize(for: image)
        guard basePixels.width > 0, basePixels.height > 0 else { return nil }

        // 画布 -> 输出像素 的换算系数
        let scale = basePixels.width / canvasSize.width
        // 输出高度按画布比例推导（而不是直接用原图高度），
        // 这样元素几何与编辑界面 100% 一致，图像本身的形变 < 0.5%，肉眼不可见
        let outputSize = CGSize(width: basePixels.width,
                                height: ceil(canvasSize.height * scale))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 底图（保持原始比例铺满输出画布）
            image.draw(in: CGRect(origin: .zero, size: outputSize))

            // 2. 逐层绘制元素
            for item in items {
                draw(item: item, scale: scale, in: cgContext)
            }
        }
    }

    // MARK: - Private

    /// 输出像素尺寸：保留原图比例，超大图等比收敛
    static func cappedPixelSize(for image: UIImage) -> CGSize {
        let pixel = image.pixelSize
        let longest = max(pixel.width, pixel.height)
        guard longest > 0 else { return pixel }
        guard longest > maxExportDimension else {
            return CGSize(width: floor(pixel.width), height: floor(pixel.height))
        }
        let ratio = maxExportDimension / longest
        return CGSize(width: floor(pixel.width * ratio), height: floor(pixel.height * ratio))
    }

    private static func draw(item: EditorItem, scale: CGFloat, in cgContext: CGContext) {
        let itemScale = item.scale * scale
        let width = item.baseSize.width * itemScale
        let height = item.baseSize.height * itemScale
        guard width > 0, height > 0 else { return }

        cgContext.saveGState()
        defer { cgContext.restoreGState() }

        // 与 UIView 的 transform 完全一致的变换顺序
        cgContext.translateBy(x: item.center.x * scale, y: item.center.y * scale)
        cgContext.rotate(by: item.rotation)
        cgContext.setAlpha(item.opacity)

        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        switch item.content {
        case .emoji(let value):
            drawEmoji(value, in: rect)

        case .customSticker(let fileName):
            if let sticker = CustomStickerStore.shared.image(named: fileName) {
                sticker.draw(in: aspectFitRect(content: sticker.size, in: rect))
            }

        case .imageWatermark(let watermarkImage):
            watermarkImage.draw(in: aspectFitRect(content: watermarkImage.size, in: rect))

        case .textWatermark(let text, let color, let fontSize):
            drawText(text,
                     color: color,
                     fontSize: fontSize * itemScale,
                     in: rect)
        }
    }

    private static func drawEmoji(_ emoji: String, in rect: CGRect) {
        guard rect.width > 1, rect.height > 1 else { return }
        let fontSize = min(rect.width, rect.height) * 0.94
        let attributed = NSAttributedString(string: emoji,
                                            attributes: [.font: UIFont.systemFont(ofSize: fontSize)])
        let textSize = attributed.size()
        attributed.draw(at: CGPoint(x: rect.midX - textSize.width / 2,
                                    y: rect.midY - textSize.height / 2))
    }

    private static func drawText(_ text: String, color: UIColor, fontSize: CGFloat, in rect: CGRect) {
        guard !text.isEmpty, rect.width > 1 else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attributed = NSAttributedString(string: text, attributes: [
            .font: Theme.roundedFont(fontSize, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ])

        let bounds = attributed.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                                             context: nil)
        attributed.draw(in: CGRect(x: rect.minX,
                                   y: rect.midY - bounds.height / 2,
                                   width: rect.width,
                                   height: ceil(bounds.height)))
    }

    /// 内容等比缩放后居中于指定矩形
    static func aspectFitRect(content: CGSize, in rect: CGRect) -> CGRect {
        guard content.width > 0, content.height > 0 else { return rect }
        let ratio = min(rect.width / content.width, rect.height / content.height)
        let size = CGSize(width: content.width * ratio, height: content.height * ratio)
        return CGRect(x: rect.midX - size.width / 2,
                      y: rect.midY - size.height / 2,
                      width: size.width,
                      height: size.height)
    }
}
