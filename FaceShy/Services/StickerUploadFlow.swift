//
//  StickerUploadFlow.swift
//  FaceShy
//
//  自定义贴纸上传流程（编辑器工具栏与表情面板共用）：
//
//    相册选图  ->  本地自动抠图 + 预览调整  ->  保存到沙盒  ->  回调文件名
//
//  全程本机完成，不联网、不上传。
//

import UIKit

enum StickerUploadFlow {

    /// 相册选择器需要被持有到选择完成，否则会被提前释放
    private static var activePicker: PhotoPicker?

    /// 启动上传流程
    /// - Parameters:
    ///   - presenter: 从哪个控制器弹出来
    ///   - completion: 保存成功后回调沙盒文件名（主线程）
    static func start(from presenter: UIViewController,
                      completion: @escaping (String) -> Void) {
        let picker = PhotoPicker()
        activePicker = picker

        picker.present(from: presenter) { image in
            activePicker = nil
            guard let image = image else { return }

            let cutoutController = StickerCutoutViewController(image: image)
            cutoutController.onSave = { fileName in
                completion(fileName)
            }
            presenter.present(cutoutController, animated: true)
        }
    }
}
