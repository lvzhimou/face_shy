//
//  PhotoLibraryService.swift
//  FaceShy
//
//  相册保存 + 相册选图。
//
//  隐私说明：
//  - 选图使用 PHPickerViewController（进程外运行），**不需要相册读取权限**
//  - 保存只申请「仅添加」权限（.addOnly），**不读取用户相册内容**
//  因此本 App 无法访问除用户主动选择的照片以外的任何相册内容。
//

import UIKit
import Photos
import PhotosUI

enum PhotoLibraryError: LocalizedError {
    case permissionDenied
    case saveFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有相册保存权限。请到「设置 - 隐颜 - 照片」中允许「添加照片」后重试。"
        case .saveFailed(let reason):
            return "保存失败：\(reason)"
        case .unknown:
            return "保存失败，请稍后重试。"
        }
    }
}

enum PhotoLibraryService {

    /// 保存图片到系统相册（仅申请 .addOnly 权限）
    static func save(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        requestAddOnlyAuthorization { granted in
            guard granted else {
                DispatchQueue.main.async { completion(.failure(PhotoLibraryError.permissionDenied)) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        let reason = error?.localizedDescription ?? "未知错误"
                        completion(.failure(PhotoLibraryError.saveFailed(reason)))
                    }
                }
            })
        }
    }

    private static func requestAddOnlyAuthorization(_ completion: @escaping (Bool) -> Void) {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                completion(status == .authorized || status == .limited)
            }
        default:
            completion(false)
        }
    }
}

// MARK: - 相册选图（无需权限）

final class PhotoPicker: NSObject {

    typealias Completion = (UIImage?) -> Void

    private var completion: Completion?

    /// present 之后由调用方持有（建议存成属性，保证生命周期）
    func present(from presenter: UIViewController, completion: @escaping Completion) {
        self.completion = completion

        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        presenter.present(picker, animated: true)
    }
}

extension PhotoPicker: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // 等关闭动画彻底结束再回调：调用方通常会紧接着 present 下一个页面，
        // 若此时上一个转场还没结束，UIKit 会丢弃新的 present。
        picker.dismiss(animated: true) { [weak self] in
            self?.handle(results)
        }
    }

    private func handle(_ results: [PHPickerResult]) {
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            finish(with: nil)
            return
        }

        // 加载原图（失败时退回缩略图，保证成功率）
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            if let image = object as? UIImage {
                DispatchQueue.main.async { self?.finish(with: image) }
            } else {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    let image = data.flatMap { UIImage(data: $0) }
                    DispatchQueue.main.async { self?.finish(with: image) }
                }
            }
        }
    }

    private func finish(with image: UIImage?) {
        let callback = completion
        completion = nil
        callback?(image)
    }
}
