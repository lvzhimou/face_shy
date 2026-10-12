//
//  StickerCutoutService.swift
//  FaceShy
//
//  自定义贴纸自动抠图：把照片里的主体（以人物 / 头部为主）从背景中分离出来。
//
//  技术方案：
//  - iOS 17+：Vision `VNGenerateForegroundInstanceMaskRequest` 做前景实例分割，
//    全程本地运行，不上传任何数据。
//  - iOS 16 及以下：该 API 不可用，直接返回原图（调用方负责降级提示）。
//
//  后处理：
//  - 羽化：对 mask 的 alpha 通道做可调半径的盒式模糊，让边缘更柔和
//  - 收边：按 mask 有效区域自动裁掉四周空白，让贴纸以「主体」为中心
//

import UIKit
import Vision
import CoreImage

enum StickerCutoutError: LocalizedError {
    case unsupportedOS
    case noSubject
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "自动抠图需要 iOS 17 或更高版本"
        case .noSubject:
            return "没有从照片里识别出清晰的主体，试试换一张主体更突出的照片"
        case .processingFailed:
            return "抠图处理出现问题，请重试"
        }
    }
}

final class StickerCutoutService {

    static let shared = StickerCutoutService()

    private init() {}

    /// 当前设备是否支持自动抠图
    static var isSupported: Bool {
        if #available(iOS 17.0, *) { return true }
        return false
    }

    // MARK: - 抠图主流程

    /// 抠图结果
    struct Result {
        /// 抠好（带透明通道）的图
        let image: UIImage
        /// 原图（已磨平方向、压缩尺寸）
        let original: UIImage
    }

    /// 对一张照片执行自动抠图
    /// - Parameters:
    ///   - image: 原始照片
    ///   - feather: 边缘羽化半径（0 ~ maxFeather，单位约为像素的千分之比例）
    ///   - completion: 主线程回调
    func cutout(image: UIImage,
                feather: CGFloat = 2,
                completion: @escaping (Result?) -> Void) {
        guard Self.isSupported else {
            completion(nil)
            return
        }

        // 抠图运算量与边长平方成正比，先压到 1024px 以内保证速度与内存
        let prepared = image.resized(maxDimension: 1024).normalizedOrientation()
        guard let cgImage = prepared.cgImage else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.performCutout(cgImage: cgImage, feather: feather)
            DispatchQueue.main.async {
                if let masked = output {
                    completion(Result(image: masked, original: prepared))
                } else {
                    completion(nil)
                }
            }
        }
    }

    /// 最大羽化档位（UI 滑杆上限）
    static let maxFeather: CGFloat = 12

    @available(iOS 17.0, *)
    private func performCutout(cgImage: CGImage, feather: CGFloat) -> UIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)

        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNInstanceMaskObservation else {
                return nil
            }

            // 拿到带 alpha 的前景蒙版图（已与原图合成）
            // croppedToInstancesExtent=false：输出与输入同尺寸，方便后续统一羽化再收边
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: false
            )
            guard let masked = Self.uiImage(from: buffer) else { return nil }

            // 应用羽化 + 收边
            let processed = applyFeather(to: masked, feather: feather)
            guard let cropped = cropToSubject(processed) else { return nil }
            return cropped
        } catch {
            return nil
        }
    }

    // MARK: - 羽化

    /// 对 alpha 通道做盒式模糊（半径 = feather 像素），同时保持颜色不越界
    private func applyFeather(to image: UIImage, feather: CGFloat) -> UIImage {
        guard feather > 0.5,
              let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        // 1. 把位图读进可操作的像素数组
        let drawOK = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawOK else { return image }

        // 2. 分离 alpha，做盒式模糊
        var alpha = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            alpha[i] = pixels[i * 4 + 3]
        }
        let blurred = Self.boxBlur(alpha, width: width, height: height, radius: Int(feather.rounded()))

        // 3. 写回 alpha；RGB 是预乘的，钳到不超过新 alpha，避免边缘出现彩色光晕
        for i in 0..<(width * height) {
            let a = blurred[i]
            let base = i * 4
            pixels[base] = min(pixels[base], a)
            pixels[base + 1] = min(pixels[base + 1], a)
            pixels[base + 2] = min(pixels[base + 2], a)
            pixels[base + 3] = a
        }

        // 4. 重新生成图片
        let output = pixels.withUnsafeMutableBytes { raw -> CGImage? in
            CGContext(data: raw.baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                .makeImage()
        }
        guard let result = output else { return image }
        return UIImage(cgImage: result, scale: image.scale, orientation: .up)
    }

    /// 盒式模糊（边界做 clamp，直接按窗口内实际像素取平均，保证边缘不变暗）
    private static func boxBlur(_ input: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0, width > 1, height > 1 else { return input }

        var temp = [Int](repeating: 0, count: width * height)
        var output = [UInt8](repeating: 0, count: width * height)

        // 横向
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                let lo = max(0, x - radius)
                let hi = min(width - 1, x + radius)
                var sum = 0
                for xx in lo...hi { sum += Int(input[row + xx]) }
                temp[row + x] = sum / (hi - lo + 1)
            }
        }
        // 纵向
        for y in 0..<height {
            let lo = max(0, y - radius)
            let hi = min(height - 1, y + radius)
            for x in 0..<width {
                var sum = 0
                for yy in lo...hi { sum += temp[yy * width + x] }
                output[y * width + x] = UInt8(max(0, min(255, sum / (hi - lo + 1))))
            }
        }
        return output
    }

    // MARK: - 收边

    /// 按 alpha > 8 的有效区域裁剪，四周留 4% 呼吸边
    private func cropToSubject(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        let drawOK = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawOK else { return image }

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width * 4
            for x in 0..<width {
                if pixels[row + x * 4 + 3] > 8 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX > minX, maxY > minY else { return image }

        let padX = Int(CGFloat(width) * 0.04)
        let padY = Int(CGFloat(height) * 0.04)
        let cropX = max(0, minX - padX)
        let cropY = max(0, minY - padY)
        let cropW = min(width - cropX, maxX - minX + 1 + padX * 2)
        let cropH = min(height - cropY, maxY - minY + 1 + padY * 2)
        guard cropW > 4, cropH > 4,
              let cropped = cgImage.cropping(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH)) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    // MARK: - 工具

    private static func uiImage(from buffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
