//
//  StickerCutoutViewController.swift
//  FaceShy
//
//  自定义贴纸「抠图预览」页：
//  - 上传照片后先本地自动抠图（主体 / 人物头部）
//  - 可在 原图 / 抠图 之间切换对比
//  - 可用滑杆微调边缘羽化，实时刷新
//  - 最终由用户选择「保存抠图」或「保存原图」，都只写本机沙盒
//

import UIKit

final class StickerCutoutViewController: UIViewController {

    /// 保存完成回调（fileName = 沙盒里的贴纸文件名）
    var onSave: ((String) -> Void)?

    // MARK: - State

    private let sourceImage: UIImage
    private var cutoutResult: UIImage?
    private var pendingWorkItem: DispatchWorkItem?

    /// 当前展示的是原图还是抠图
    private var showCutout = true {
        didSet { updatePreview() }
    }

    // MARK: - UI

    private let previewView = UIView()
    private let previewImageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let featherLabel = UILabel()
    private let featherSlider = UISlider()
    private let modeControl = UISegmentedControl(items: ["原图", "抠图"])
    private let saveCutoutButton = UIButton(type: .system)
    private let saveOriginalButton = UIButton(type: .system)
    private let hintLabel = UILabel()

    private let checkerboard = CAShapeLayer()

    // MARK: - Init

    init(image: UIImage) {
        self.sourceImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        setupSheet()
        setupUI()
        startCutout(feather: currentFeather)
    }

    deinit {
        pendingWorkItem?.cancel()
    }

    private func setupSheet() {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large(), .medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 22
        }
    }

    private var currentFeather: CGFloat {
        CGFloat(featherSlider.value)
    }

    // MARK: - UI 搭建

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "抠图预览"
        titleLabel.font = Theme.font(18, weight: .bold)
        titleLabel.textColor = Theme.textPrimary

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = Theme.textTertiary
        closeButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), closeButton])
        header.axis = .horizontal
        header.alignment = .center

        // 预览区（棋盘格背景，用于展示透明区域）
        previewView.backgroundColor = .clear
        previewView.layer.addSublayer(checkerboard)
        previewView.roundCorners(radius: 16)
        previewView.clipsToBounds = true
        previewView.layer.borderColor = Theme.separator.resolvedColor(with: traitCollection).cgColor
        previewView.layer.borderWidth = 1

        previewImageView.contentMode = .scaleAspectFit
        previewImageView.image = sourceImage

        activityIndicator.hidesWhenStopped = true

        // 模式切换
        modeControl.selectedSegmentIndex = 1
        modeControl.setTitleTextAttributes([.font: Theme.font(13, weight: .medium)], for: .normal)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        // 羽化滑杆
        featherLabel.text = "边缘羽化"
        featherLabel.font = Theme.font(14, weight: .medium)
        featherLabel.textColor = Theme.textSecondary

        featherSlider.minimumValue = 0
        featherSlider.maximumValue = Float(StickerCutoutService.maxFeather)
        featherSlider.value = 2
        featherSlider.tintColor = Theme.brand
        featherSlider.addTarget(self, action: #selector(featherChanged), for: .valueChanged)

        // 按钮
        configureButton(saveCutoutButton,
                        title: "保存抠图",
                        filled: true)
        saveCutoutButton.addAction(UIAction { [weak self] _ in
            self?.save(cutout: true)
        }, for: .touchUpInside)

        configureButton(saveOriginalButton,
                        title: "保存原图",
                        filled: false)
        saveOriginalButton.addAction(UIAction { [weak self] _ in
            self?.save(cutout: false)
        }, for: .touchUpInside)

        hintLabel.font = Theme.font(12)
        hintLabel.textColor = Theme.textTertiary
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center

        let buttonRow = UIStackView(arrangedSubviews: [saveOriginalButton, saveCutoutButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12
        buttonRow.distribution = .fillEqually

        let controls = UIStackView(arrangedSubviews: [modeControl, featherLabel, featherSlider])
        controls.axis = .vertical
        controls.spacing = 10

        let stack = UIStackView(arrangedSubviews: [header, previewView, controls, buttonRow, hintLabel])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(16, after: header)
        stack.setCustomSpacing(18, after: previewView)

        view.addSubviews(stack, previewImageView, activityIndicator)

        let side: CGFloat = 16
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -side),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            previewView.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.86),

            previewImageView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            previewImageView.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            previewImageView.widthAnchor.constraint(lessThanOrEqualTo: previewView.widthAnchor, constant: -16),
            previewImageView.heightAnchor.constraint(lessThanOrEqualTo: previewView.heightAnchor, constant: -16),

            activityIndicator.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),

            featherSlider.heightAnchor.constraint(equalToConstant: 30)
        ])

        updateForOSsupport()
    }

    private func configureButton(_ button: UIButton, title: String, filled: Bool) {
        var configuration = UIButton.Configuration.filled()
        var titleAttributes = AttributeContainer()
        titleAttributes.font = Theme.font(16, weight: .semibold)
        configuration.attributedTitle = AttributedString(title, attributes: titleAttributes)
        if filled {
            configuration.baseBackgroundColor = Theme.brand
            configuration.baseForegroundColor = .white
        } else {
            configuration.baseBackgroundColor = Theme.surfaceAlt
            configuration.baseForegroundColor = Theme.textPrimary
        }
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 10, bottom: 13, trailing: 10)
        button.configuration = configuration
    }

    /// iOS 16 及以下不支持 Vision 前景分割，隐藏抠图相关控件
    private func updateForOSsupport() {
        guard StickerCutoutService.isSupported else {
            modeControl.isHidden = true
            featherSlider.isHidden = true
            featherLabel.isHidden = true
            saveCutoutButton.isHidden = true
            hintLabel.text = "当前系统版本不支持自动抠图（需要 iOS 17+），将保存原图。"
            showCutout = false
            return
        }
        hintLabel.text = "抠图在本机完成，不会上传照片。保存后可在「我的贴纸」中重复使用。"
    }

    // MARK: - 棋盘格背景

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        checkerboard.frame = previewView.bounds
        checkerboard.path = Self.checkerboardPath(in: previewView.bounds, cell: 12).cgPath
        checkerboard.fillColor = Theme.surfaceAlt.resolvedColor(with: traitCollection).cgColor
        checkerboard.zPosition = -1
    }

    private static func checkerboardPath(in rect: CGRect, cell: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width > 0, rect.height > 0 else { return path }
        var y = rect.minY
        var indexY = 0
        while y < rect.maxY {
            var x = rect.minX
            var indexX = 0
            while x < rect.maxX {
                if (indexX + indexY) % 2 == 0 {
                    path.append(UIBezierPath(rect: CGRect(x: x, y: y,
                                                          width: min(cell, rect.maxX - x),
                                                          height: min(cell, rect.maxY - y))))
                }
                x += cell
                indexX += 1
            }
            y += cell
            indexY += 1
        }
        return path
    }

    // MARK: - 抠图

    @objc private func modeChanged() {
        showCutout = modeControl.selectedSegmentIndex == 1
    }

    @objc private func featherChanged() {
        guard StickerCutoutService.isSupported else { return }
        // 滑杆拖动做防抖，停止 250ms 后再重新抠图
        pendingWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.startCutout(feather: self.currentFeather)
        }
        pendingWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func startCutout(feather: CGFloat) {
        guard StickerCutoutService.isSupported else { return }

        activityIndicator.startAnimating()
        previewImageView.alpha = 0.4

        StickerCutoutService.shared.cutout(image: sourceImage, feather: feather) { [weak self] result in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            self.previewImageView.alpha = 1

            guard let result = result else {
                // 没识别到主体：退回原图并禁用抠图按钮
                self.cutoutResult = nil
                self.saveCutoutButton.isEnabled = false
                self.saveCutoutButton.alpha = 0.4
                self.showCutout = false
                self.hintLabel.text = "没有识别到清晰的主体，已切换到原图。可以直接保存原图。"
                return
            }

            self.cutoutResult = result.image
            self.saveCutoutButton.isEnabled = true
            self.saveCutoutButton.alpha = 1
            self.updatePreview()
        }
    }

    private func updatePreview() {
        let image = (showCutout ? cutoutResult : nil) ?? sourceImage
        previewImageView.image = image
    }

    // MARK: - 保存

    private func save(cutout: Bool) {
        let image = (cutout ? cutoutResult : nil) ?? sourceImage
        HUD.shared.show("正在保存…", in: view)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let fileName = try CustomStickerStore.shared.addSticker(from: image)
                DispatchQueue.main.async {
                    HUD.shared.hide()
                    // 先把自己收起来，再回调，避免和上层弹窗的 dismiss 撞在一起
                    self.dismiss(animated: true) {
                        self.onSave?(fileName)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    HUD.shared.hide()
                    self.presentAlert(title: "保存失败", message: error.localizedDescription)
                }
            }
        }
    }
}
