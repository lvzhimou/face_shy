//
//  FaceDetector.swift
//  FaceShy
//
//  核心：Apple Vision 本地离线人脸识别。
//
//  - 使用 VNDetectFaceRectanglesRequest，全部运算在设备端完成
//  - 不上传任何图片、不访问网络
//  - 大图会先等比缩小到 1600px 再识别，兼顾速度与精度
//

import UIKit
import Vision
import ImageIO

/// 识别到的一张人脸
struct DetectedFace {
    /// Vision 归一化坐标（原点 = 图片左下角，宽高 0~1）
    let boundingBox: CGRect
    /// 头部倾斜角度（弧度）
    let roll: CGFloat
    /// 左右偏转角度（弧度）
    let yaw: CGFloat
    /// 性别猜测（用于匹配女生 / 男生 Q版表情；没把握时为 unknown）
    let gender: FaceGenderGuess
}

/// 性别猜测结果
enum FaceGenderGuess {
    case girl
    case boy
    case unknown
}

enum FaceDetectionError: LocalizedError {
    case invalidImage
    case detectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法读取这张图片，请换一张试试"
        case .detectionFailed(let reason): return "人脸识别失败：\(reason)"
        }
    }
}

final class FaceDetector {

    /// 触发识别的最大边长（缩小后识别更快，结果坐标不受影响）
    private let detectionMaxDimension: CGFloat = 1600

    private let queue = DispatchQueue(label: "com.faceshy.face-detection", qos: .userInitiated)

    /// 异步识别人脸，回调在主线程
    func detectFaces(in image: UIImage, completion: @escaping (Result<[DetectedFace], FaceDetectionError>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let result = self.performDetection(on: image)
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Private

    private func performDetection(on image: UIImage) -> Result<[DetectedFace], FaceDetectionError> {
        // 1. 准备送给 Vision 的 CGImage：先磨平方向再缩放，
        //    保证后续「按 boundingBox 裁人脸区域」的像素坐标完全对齐
        let upright = image.normalizedOrientation()
        let prepared = upright.resized(maxDimension: detectionMaxDimension)
        guard let cgImage = prepared.cgImage else { return .failure(.invalidImage) }

        // 2. 构造请求（只返回人脸矩形框，速度最快）
        let request = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage,
                                            orientation: .up,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failure(.detectionFailed(error.localizedDescription))
        }

        guard let observations = request.results, !observations.isEmpty else {
            return .success([])
        }

        let faces = observations.map { observation -> DetectedFace in
            DetectedFace(boundingBox: observation.boundingBox,
                         roll: CGFloat(observation.roll?.doubleValue ?? 0),
                         yaw: CGFloat(observation.yaw?.doubleValue ?? 0),
                         gender: guessGender(in: cgImage, faceRect: observation.boundingBox))
        }

        // 3. 按面积从大到小排序，主脸优先（随机表情时主脸拿第一个）
        let sorted = faces.sorted {
            $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height
        }
        return .success(sorted)
    }

    // MARK: - 性别猜测（本地离线）

    /// 对人脸区域跑一次系统自带图像分类（VNClassifyImageRequest，设备端推理），
    /// 从分类词表里找 woman / man / girl / boy 等概念。
    /// 没有可信信号时返回 unknown，调用方回退到 emoji。
    /// 注意：\"woman\" 包含 \"man\" 子串、\"female\" 包含 \"male\" 子串，
    /// 所以女生分支必须放在前面先判断。
    private func guessGender(in cgImage: CGImage, faceRect: CGRect) -> FaceGenderGuess {
        // 外扩一点，把发型 / 耳朵等特征带上
        let w = faceRect.width * CGFloat(cgImage.width)
        let h = faceRect.height * CGFloat(cgImage.height)
        let x = faceRect.minX * CGFloat(cgImage.width)
        let y = (1 - faceRect.maxY) * CGFloat(cgImage.height)
        let raw = CGRect(x: x, y: y, width: w, height: h)
            .insetBy(dx: -w * 0.2, dy: -h * 0.2)
        let clamped = raw.intersection(CGRect(x: 0, y: 0,
                                              width: CGFloat(cgImage.width),
                                              height: CGFloat(cgImage.height)))
        guard !clamped.isNull, clamped.width > 24, clamped.height > 24,
              let faceCrop = cgImage.cropping(to: clamped) else { return .unknown }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: faceCrop, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return .unknown
        }
        guard let observations = request.results else { return .unknown }

        var girlScore: Float = 0
        var boyScore: Float = 0
        for observation in observations.prefix(100) {
            let identifier = observation.identifier.lowercased()
            let confidence = observation.confidence
            if identifier.contains("woman") || identifier.contains("girl") || identifier.contains("female") {
                girlScore = max(girlScore, confidence)
            } else if identifier.contains("man") || identifier.contains("boy") || identifier.contains("male") || identifier.contains("beard") {
                boyScore = max(boyScore, confidence)
            }
        }

        let threshold: Float = 0.05
        if girlScore > threshold && girlScore >= boyScore { return .girl }
        if boyScore > threshold && boyScore > girlScore { return .boy }
        return .unknown
    }
}

// MARK: - UIImage.Orientation -> CGImagePropertyOrientation

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
