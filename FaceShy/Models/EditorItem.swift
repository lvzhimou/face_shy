//
//  EditorItem.swift
//  FaceShy
//
//  画布上的一个可编辑元素（emoji 贴纸 / 自定义贴纸）。
//
//  几何模型说明：
//  - baseSize：元素「未缩放」时在画布上的尺寸（画布坐标系 = point）
//  - scale   ：用户双指捏合后的缩放倍数
//  - rotation：用户双指旋转后的弧度
//  - center  ：元素中心点（画布坐标系）
//  实时预览视图与最终导出渲染使用完全相同的这 4 个参数，
//  因此「所见即所得」，导出结果与编辑界面像素级一致。
//

import UIKit

/// 元素的角色：人脸贴纸会参与「随机表情」，自由贴纸不会
enum ItemRole {
    case faceSticker
    case free
}

/// 元素内容
enum ItemContent {
    /// 系统 emoji
    case emoji(String)
    /// 用户上传的自定义贴纸（沙盒文件名，可能为带透明通道的抠图 PNG）
    case customSticker(fileName: String)
}

final class EditorItem {

    let id = UUID()

    var content: ItemContent
    var role: ItemRole

    /// 中心点（画布坐标系，原点在照片左上角）
    var center: CGPoint
    /// 缩放倍数
    var scale: CGFloat
    /// 旋转弧度
    var rotation: CGFloat
    /// 不透明度（预留字段，当前界面不暴露调节入口）
    var opacity: CGFloat
    /// 未缩放的基准尺寸
    var baseSize: CGSize

    init(content: ItemContent,
         role: ItemRole,
         center: CGPoint,
         baseSize: CGSize,
         scale: CGFloat = 1,
         rotation: CGFloat = 0,
         opacity: CGFloat = 1) {
        self.content = content
        self.role = role
        self.center = center
        self.baseSize = baseSize
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
    }

    /// 元素名称（用于提示文案展示）
    var displayName: String {
        switch content {
        case .emoji: return "表情贴纸"
        case .customSticker: return "自定义贴纸"
        }
    }

    /// 是否是可以替换表情的类型（当前所有元素都是）
    var isSticker: Bool {
        switch content {
        case .emoji, .customSticker: return true
        }
    }
}
