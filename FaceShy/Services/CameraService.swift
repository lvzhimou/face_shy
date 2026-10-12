//
//  CameraService.swift
//  FaceShy
//
//  相机拍照导入。
//
//  - 仅在用户主动点击「拍照」时才申请相机权限（NSCameraUsageDescription）
//  - 不录音、不申请麦克风，拍照后仅把 UIImage 交给编辑器
//

import UIKit
import AVFoundation

enum CameraService {

    /// 当前设备是否支持相机（模拟器不支持）
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// 申请权限并弹出相机
    static func presentCamera(from presenter: UIViewController,
                              delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
        guard isCameraAvailable else {
            let alert = UIAlertController(title: "当前设备不支持拍照",
                                          message: "模拟器没有相机，请在真机上体验拍照功能，或直接从相册选择照片。",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default))
            presenter.present(alert, animated: true)
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera(from: presenter, delegate: delegate)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera(from: presenter, delegate: delegate)
                    } else {
                        presentDeniedAlert(from: presenter)
                    }
                }
            }
        default:
            presentDeniedAlert(from: presenter)
        }
    }

    private static func showCamera(from presenter: UIViewController,
                                   delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.allowsEditing = false
        picker.delegate = delegate
        presenter.present(picker, animated: true)
    }

    private static func presentDeniedAlert(from presenter: UIViewController) {
        let alert = UIAlertController(title: "无法使用相机",
                                      message: "请在「设置 - 隐私与安全性 - 相机」中允许隐颜访问相机。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        presenter.present(alert, animated: true)
    }
}
