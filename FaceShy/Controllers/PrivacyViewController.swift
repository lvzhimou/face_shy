//
//  PrivacyViewController.swift
//  FaceShy
//
//  隐私说明页：向用户明确说明图片只在本地处理
//

import UIKit

final class PrivacyViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "隐私说明"
        view.backgroundColor = Theme.background
        navigationItem.largeTitleDisplayMode = .never
        buildUI()
    }

    private func buildUI() {
        view.addSubviews(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        scrollView.addSubviews(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        contentStack.addArrangedSubview(makeBanner())
        contentStack.addArrangedSubview(makeCard(title: "照片不会离开你的手机",
                                                 body: "隐颜使用 Apple 的 Vision 框架在设备本地完成人脸识别，图片数据只在 iPhone 内存中处理，全程不联网，不会上传到任何服务器，也不会写入任何云端账号。"))
        contentStack.addArrangedSubview(makeCard(title: "我们不收集你的照片",
                                                 body: "本 App 没有服务器、没有账号体系、没有埋点统计。你可以开启飞行模式后正常使用全部功能。"))
        contentStack.addArrangedSubview(makeCard(title: "相册权限只用于你主动选择的照片",
                                                 body: "选图使用 iOS 系统相册选择器（PHPicker），它由系统在独立进程中运行 —— 因此隐颜不需要、也无法读取你的相册列表。保存时只申请「添加照片」权限。"))
        contentStack.addArrangedSubview(makeCard(title: "自定义表情包只存在本机",
                                                 body: "你上传的表情包保存在 App 沙盒目录中（Application Support/CustomStickers），只在设备本地读写。可在「设置 - 清除本地自定义表情包」中一键删除。"))
        contentStack.addArrangedSubview(makeCard(title: "相机权限只在你点「拍照」时申请",
                                                 body: "用于实时拍摄需要遮挡的照片，拍完的照片同样只在本地处理，不会自动上传。"))
    }

    private func makeBanner() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "100% 本地处理"
        title.font = Theme.roundedFont(20, weight: .bold)
        title.textColor = .white

        let subtitle = UILabel()
        subtitle.text = "隐私优先 · 离线可用"
        subtitle.font = Theme.font(13)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.85)

        let textStack = UIStackView(arrangedSubviews: [title, subtitle])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [icon, textStack])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center

        let banner = UIView()
        banner.backgroundColor = Theme.brand
        banner.roundCorners(radius: 20)
        banner.addSubviews(row)
        row.pinEdges(to: banner, insets: UIEdgeInsets(top: 22, left: 20, bottom: 22, right: 20))

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 34),
            icon.heightAnchor.constraint(equalToConstant: 34)
        ])
        return banner
    }

    private func makeCard(title: String, body: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = Theme.font(15, weight: .semibold)
        titleLabel.textColor = Theme.textPrimary
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = Theme.font(13)
        bodyLabel.textColor = Theme.textSecondary
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 8

        let card = UIView()
        card.backgroundColor = Theme.surface
        card.roundCorners(radius: 18)
        card.addSubviews(stack)
        stack.pinEdges(to: card, insets: UIEdgeInsets(top: 16, left: 18, bottom: 18, right: 18))
        return card
    }
}
