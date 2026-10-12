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
        // 1. 准备送给 Vision 的 CGImage 与方向
        let prepared: (cgImage: CGImage, orientation: CGImagePropertyOrientation)

        if max(image.pixelSize.width, image.pixelSize.height) > detectionMaxDimension {
            // 缩小并重绘 -> 方向已烘焙为 .up
            let small = image.resized(maxDimension: detectionMaxDimension)
            guard let cgImage = small.cgImage else { return .failure(.invalidImage) }
            prepared = (cgImage, .up)
        } else {
            guard let cgImage = image.cgImage else { return .failure(.invalidImage) }
            prepared = (cgImage, CGImagePropertyOrientation(image.imageOrientation))
        }

        // 2. 构造请求（只返回人脸矩形框，速度最快）
        let request = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(cgImage: prepared.cgImage,
                                            orientation: prepared.orientation,
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
                         yaw: CGFloat(observation.yaw?.doubleValue ?? 0))
        }

        // 3. 按面积从大到小排序，主脸优先（随机表情时主脸拿第一个）
        let sorted = faces.sorted {
            $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height
        }
        return .success(sorted)
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
