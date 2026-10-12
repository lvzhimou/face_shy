# 隐颜 FaceShy · iOS 本地 AI 照片人脸遮挡 App

> 对标 Facemoji，用 **Apple Vision 端侧 AI** 离线识别人脸，一键给照片上的人脸贴 emoji 遮挡。
> **全部图片只在本机处理，不上传任何服务器。**

- 语言 / 框架：Swift 5 · UIKit（纯代码，无 Storyboard）· Apple Vision · CoreImage 渲染 · Photos / AVFoundation
- 最低版本：iOS 16.0，仅 iPhone、仅竖屏
- 依赖：**零第三方依赖**，不需要 CocoaPods / SPM

---

## 一、快速开始（macOS + Xcode）

```bash
# 1. 把整个 FaceShy 文件夹拷到 Mac 上，双击打开工程
open FaceShy.xcodeproj

# 2. 命令行编译（可选，验证工程是否正常）
xcodebuild -project FaceShy.xcodeproj -scheme FaceShy \
           -sdk iphonesimulator -configuration Debug build

# 3. 用 Xcode 运行
# 顶部 Scheme 选 FaceShy → 选一台 iPhone 模拟器（如 iPhone 15）→ ⌘R
```

### 真机运行需要改两处

| 位置 | 改什么 | 说明 |
| --- | --- | --- |
| Target → Signing & Capabilities | ✅ Automatically manage signing，选你的 Apple ID Team | 免费个人账号即可 |
| Target → General → Bundle Identifier | `com.faceshy.app` → 改成你自己的（如 `com.你的名字.faceshy`） | Bundle ID 必须全球唯一 |

> 免费 Apple ID 签名的 App 有效期 7 天，到期重新 ⌘R 即可。

### 模拟器注意事项

- **模拟器没有相机**：点「拍照导入」会弹出友好提示，请用「从相册选择照片」。
- 模拟器相册默认是空的，先把图片拖进模拟器（把图片拖到模拟器窗口即可保存到相册）。
- Vision 人脸识别在模拟器上可以正常跑（x86/arm 模拟器都支持）。

### 关于 App 图标

`FaceShy/Resources/Assets.xcassets/AppIcon.appiconset/` 目前是空壳（可正常编译运行，仅缺图标）。
上架前放一张 1024×1024 PNG 进去即可。

---

## 二、如何拿到 IPA（自签安装到手机）

> ⚠️ **重要前提：iOS 应用无法在 Windows / Linux 上编译。**
> UIKit、Vision、Swift 的 iOS SDK 只存在于 Apple 的 Xcode 工具链里，没有 Windows 版替代方案。
> 产出 IPA 必须经过 macOS。下面给出两条最省事的路线。

### 路线 A：GitHub Actions 云端 macOS 构建（推荐，不需要自己有 Mac）

**本地仓库已经初始化好并完成首次提交**（43 个文件），你只需要推上去。

**第 1 步 · 建一个空仓库**
打开 https://github.com/new ，仓库名随意（例如 `face_shy`），Public / Private 都行。
⚠️ **不要**勾选 `Add a README file` / `.gitignore` / `License`，否则推送时会有冲突。

**第 2 步 · 推送**
```bash
cd FaceShy
./push_to_github.sh 你的GitHub用户名            # 仓库名默认 face_shy
./push_to_github.sh 你的GitHub用户名 face_shy   # 指定仓库名
```
脚本会自动补齐提交、配置 remote、推送，并在失败时给出针对性排查指引。
首次推送会弹出 GitHub 登录（浏览器授权即可）；如果它改成让你输入账号密码，
**密码处填 Personal Access Token**（https://github.com/settings/tokens → Generate new token (classic) → 勾选 `repo`）。

也可以不用脚本，手动三条命令：
```bash
git remote add origin https://github.com/你的用户名/face_shy.git
git branch -M main
git push -u origin main
```

**第 3 步 · 等构建**
推送本身就会触发构建（无需手动点）。打开 `https://github.com/你的用户名/face_shy/actions`，
2~4 分钟后出现绿色 ✔。若想手动触发：**Actions** → 「构建未签名 IPA」→ **Run workflow**
（可顺便自定义 Bundle Identifier 与构建号）。

**第 4 步 · 下载 IPA**
点进那条运行记录 → 页面底部 **Artifacts** → 下载 `FaceShy-unsigned-ipa` → 解压得到 `FaceShy-unsigned.ipa`。

> **额度**：仓库设为 **Public** 时 GitHub 的 macOS 构建完全免费且不限量；**Private** 也可用
> （免费账号每月 2000 分钟额度，macOS 按 10 倍计费，约够跑 60 次构建）。
> 私有仓库的 Artifacts 需要登录 GitHub 才能下载。

> 不想用 GitHub 也行：任何支持 macOS 的云构建服务都可以（Codemagic 免费 500 分钟/月、Appcircle、Bitrise），
> 把 `build_ipa.sh` 配成构建脚本即可。

### 路线 B：找一台 Mac 跑一条命令

```bash
cd FaceShy
chmod +x build_ipa.sh
./build_ipa.sh                      # 产物：build/FaceShy-unsigned.ipa
BUNDLE_ID=com.你的名字.faceshy ./build_ipa.sh   # 想换 Bundle ID 时
```

脚本做的事：`xcodebuild` 以 `CODE_SIGNING_ALLOWED=NO` 编译 Release + arm64 →
把 `.app` 放进 `Payload/` → 打包成符合 iOS 规范的未签名 IPA → 打印安装指引。

### 拿到 IPA 之后：自签安装

| 工具 | 运行位置 | 说明 |
| --- | --- | --- |
| **Sideloadly** | Windows / macOS 电脑 | 最省事。选 IPA → 填 Apple ID → Start，自动签名并装到 iPhone |
| **AltStore / SideStore** | iPhone | 把 IPA 存到手机「文件」，用 App 内导入安装 |
| **轻松签 / ESign / 全能签** | iPhone | 导入 IPA，用免费证书签名后直接安装 |
| **爱思助手** | Windows | 需先自签再安装，不能直接装未签名包 |

**免费 Apple ID 的限制**：签名有效期 7 天，到期重新签一次；同时最多 3 个自签 App。
有 99 美元开发者账号则有效期 1 年。

**安装后第一次打开会提示"不受信任的开发者"**，到
设置 → 通用 → VPN与设备管理 → 开发者App → 选中你的 Apple ID → **信任**，即可正常打开。
（设备需为 iOS 16.0 及以上。）

### 自签前建议先校验 IPA

```bash
python3 tools/pack_ipa.py --verify build/FaceShy-unsigned.ipa
```

会检查：`Payload/` 结构、`Info.plist` 关键字段、可执行文件是否存在、**是否为 arm64**
（不是 arm64 真机装不上）、可执行权限位、签名状态。CI 里也跑了这一步。

### 如果你已经拿到一个 `.app` 想自己打包

```bash
python3 tools/pack_ipa.py /path/to/FaceShy.app -o dist/FaceShy-unsigned.ipa
```
跨平台可用（Windows 也能跑）。但**打包首选 macOS**：Windows 文件系统不保存 Unix 权限位，
可能丢失可执行权限，脚本会给出警告。

---

## 三、项目结构

```
FaceShy/
├── FaceShy.xcodeproj/                  # 可直接打开的 Xcode 工程
│   ├── project.pbxproj                 # 由 tools/generate_xcodeproj.py 生成
│   └── xcshareddata/xcschemes/FaceShy.xcscheme
├── build_ipa.sh                        # ★ 一键构建未签名 IPA（macOS）
├── push_to_github.sh                   # ★ 一键推送到 GitHub，自动触发云端构建
├── .github/workflows/build-ipa.yml     # ★ 云端 macOS 构建，产出 IPA 产物
├── tools/pack_ipa.py                   # ★ IPA 打包 / 校验工具（跨平台）
├── project.yml                         # XcodeGen 备用方案（可选）
├── tools/generate_xcodeproj.py         # 工程文件生成器（新增源文件后重跑即可刷新）
└── FaceShy/
    ├── App/                            # 应用入口
    │   ├── AppDelegate.swift           #   全局外观配置
    │   ├── SceneDelegate.swift         #   窗口 & 根控制器
    │   └── AppNavigationController.swift  # 竖屏锁定 + 状态栏样式
    ├── Models/                         # 数据模型（纯数据，无 UI）
    │   ├── EditorItem.swift            #   ★ 画布元素模型（位置/缩放/旋转/透明度）
    │   ├── EmojiCatalog.swift          #   内置 64 个遮脸 emoji
    │   └── AppSettings.swift           #   UserDefaults 轻量设置
    ├── Services/                       # 业务能力（可独立测试）
    │   ├── FaceDetector.swift          #   ★ Vision 本地人脸识别
    │   ├── EditorRenderer.swift        #   ★ 原分辨率合成导出
    │   ├── CustomStickerStore.swift    #   自定义贴纸沙盒存储
    │   ├── PhotoLibraryService.swift   #   相册保存 + PHPicker 选图
    │   └── CameraService.swift         #   相机拍照（权限申请）
    ├── Views/                          # 复用视图
    │   ├── CanvasView.swift            #   ★ 编辑画布（等比展示 + 元素容器）
    │   ├── EditableItemView.swift      #   ★ 拖动/缩放/旋转手势元素视图
    │   ├── EditorToolbarView.swift     #   底部工具栏
    │   └── SelectedItemBar.swift       #   选中元素操作条（图层/透明度/删除）
    ├── Controllers/                    # 页面
    │   ├── HomeViewController.swift        # 首页
    │   ├── EditorViewController.swift      # ★ 编辑页（核心编排）
    │   ├── EmojiPickerViewController.swift # 表情面板 + 我的贴纸
    │   ├── TextWatermarkViewController.swift # 文字水印面板
    │   ├── OpacitySheetViewController.swift  # 透明度面板
    │   ├── SettingsViewController.swift      # 设置
    │   └── PrivacyViewController.swift       # 隐私说明
    ├── Support/                        # 基础设施
    │   ├── Theme.swift                 # 颜色 / 字体 / 深浅色适配
    │   ├── UIView+Layout.swift         # 布局与提示工具
    │   ├── UIImage+Extensions.swift    # 图片缩放 / 方向修正
    │   └── HUD.swift                   # 加载指示器 + Toast
    └── Resources/
        ├── Info.plist                  # 权限文案、Scene 配置、竖屏锁定
        └── Assets.xcassets             # AppIcon + AccentColor
```

26 个 Swift 文件，约 3600 行，按「模型 / 服务 / 视图 / 控制器」分层，UI 与业务解耦。

---

## 四、核心实现说明

### 1. 人脸识别（FaceDetector.swift）

```swift
let request = VNDetectFaceRectanglesRequest()
let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])
try handler.perform([request])
```

- 仅在设备端运行，**不联网、不上传**。
- 超过 1600px 的大图先等比缩小再识别，速度更快，坐标仍是归一化的所以结果不受影响。
- 同时拿到 `roll`（头部倾斜角），贴纸会跟着脸一起倾斜。
- 识别结果按人脸面积从大到小排序，主脸优先分到第一个表情。
- 在后台串行队列执行，回调切回主线程，不阻塞 UI。

### 2. Vision 坐标系 → 视图坐标系（易错点，已处理）

Vision 的 `boundingBox` 是**归一化坐标、原点在左下角**；UIKit 原点在左上角。转换公式：

```swift
x = bb.minX * W
y = (1 - bb.maxY) * H      // 关键：Y 轴翻转
w = bb.width  * W
h = bb.height * H
```

贴纸尺寸在原始人脸框基础上**外扩 16%**，确保能盖住发际线、耳侧；倾斜角取 `-roll`。

### 3. 手势交互（EditableItemView.swift）

| 手势 | 识别器 | 作用 |
| --- | --- | --- |
| 单指拖动 | `UIPanGestureRecognizer`（1 指） | 移动中心点，自动限制在照片范围内 |
| 双指捏合 | `UIPinchGestureRecognizer` | 缩放（0.2× ~ 8×） |
| 双指旋转 | `UIRotationGestureRecognizer` | 旋转 |
| 单击 | `UITapGestureRecognizer` | 选中，显示边框与删除按钮 |

通过 `gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)` 返回 `true`，**捏合 + 旋转可以同时进行**，单指拖动也不会和它们打架。

> 缩放细节：为了文字清晰，缩放不是用 `transform` 拉伸，而是直接改 `bounds` 并同步字号，`transform` 只负责旋转。这样 emoji 放大 5 倍依然锐利，同时导出渲染可以直接复用 `baseSize × scale` 的几何数据。

### 4. 导出合成（EditorRenderer.swift）

编辑时元素坐标基于「画布 point」，导出时基于「原图像素」，两者相差一个系数：

```swift
let scale = outputSize.width / canvasSize.width   // 画布 → 像素
cgContext.translateBy(x: center.x * scale, y: center.y * scale)
cgContext.rotate(by: rotation)
cgContext.setAlpha(opacity)
// 在该变换下绘制 emoji / 图片 / 文字
```

因为预览视图和导出渲染使用**完全相同的中心点 / 缩放 / 旋转 / 透明度**，所以导出结果与编辑界面像素级一致（所见即所得）。
输出尺寸保留原图比例，最长边超过 4096px 时才等比收敛，防止内存溢出。

### 5. 隐私设计（贯穿全局）

| 能力 | 实现 | 权限 |
| --- | --- | --- |
| 相册选图 | `PHPickerViewController`（**进程外**运行） | ❌ 不需要相册读取权限 |
| 保存图片 | `PHAssetChangeRequest` | ✅ 仅 `.addOnly`（仅添加） |
| 相机 | `AVCaptureDevice.requestAccess(.video)` | ✅ 点击拍照时才申请 |
| 人脸识别 | Apple Vision（端侧） | ❌ 无 |
| 自定义贴纸 | 沙盒 `Application Support/CustomStickers` | ❌ 无 |

App 内**没有任何网络请求代码**，可开飞行模式全功能使用。

---

## 五、PRD 功能对照

| PRD 需求 | 实现位置 | 状态 |
| --- | --- | --- |
| 相册选图 / 相机拍照导入 | HomeViewController + PhotoPicker / CameraService | ✅ |
| Vision 离线人脸识别 | FaceDetector.swift | ✅ |
| 多人脸自动贴 emoji | EditorViewController.placeStickers | ✅ |
| 单指拖动 / 双指缩放 / 双指旋转 | EditableItemView.swift | ✅ |
| 随机表情按钮 | toolbar → randomizeFaceStickers | ✅ |
| 自选表情面板 | EmojiPickerViewController（系统 emoji 64 个） | ✅ |
| 上传自定义表情包（存沙盒） | CustomStickerStore + 表情面板「我的贴纸」 | ✅ |
| 自定义贴纸预览 / 删除 | 长按贴纸 → 删除；设置页可一键清空 | ✅ |
| 文字水印（文字 / 颜色 / 字号） | TextWatermarkViewController | ✅ |
| 图片水印（相册选图） | EditorViewController.pickImageWatermark | ✅ |
| 水印拖动 / 缩放 / 旋转 / 多水印 | 同为 EditableItemView | ✅ |
| 水印与贴纸图层上下叠加 | SelectedItemBar「上移 / 下移」 | ✅ |
| 选中并删除水印 | 删除按钮 / 操作条删除 | ✅ |
| 导出保存到相册，保留原图比例 | EditorRenderer + PhotoLibraryService | ✅ |
| 可选压缩开关（默认高清） | 保存时的画质选择 + AppSettings 记忆 | ✅ |
| 设置页：清除自定义贴纸 | SettingsViewController | ✅ |
| 设置页：隐私说明 | PrivacyViewController | ✅ |
| 设置页：版本信息 | SettingsViewController | ✅ |
| 深色 / 浅色适配 | Theme.swift 全动态颜色 | ✅ |
| 识别失败友好提示 | presentNoFaceAlert（可重试 / 手动加贴纸） | ✅ |
| 超大贴纸自动压缩防崩溃 | CustomStickerStore 压到最长边 512px | ✅ |
| 权限被拒友好提示 | CameraService / PhotoLibraryService 引导去设置 | ✅ |

**额外补充的小功能**：元素透明度调节、"手动加贴纸"（识别失败兜底）、重试识别、图层上移下移、删除按钮，以及首页的三步使用引导。

---

## 六、修改代码后如何刷新工程

工程文件（`project.pbxproj`）是由脚本生成的，如果你新增或删除了 `.swift` 文件：

```bash
cd FaceShy
python3 tools/generate_xcodeproj.py
```

脚本会自动扫描 `FaceShy/` 目录下所有源文件并重写工程文件。
（也可以改用 XcodeGen：`brew install xcodegen && xcodegen generate`，配置见 `project.yml`。）

---

## 七、已知限制与后续可扩展方向

**限制**

1. Vision 人脸识别在**光线暗、大侧脸、面部被遮挡**时成功率会下降 —— 已做弹窗提示 + 「手动加贴纸」兜底，这是算法固有边界。
2. 工程未包含单元测试与 UI 测试。
3. AppIcon 为空壳，上架前需要补图。
4. 仅支持 iPhone 竖屏（按 PRD 要求），未适配 iPad 与横屏。
5. **编译必须在 macOS 上完成**（本机为 Windows，无法直接产出 IPA）。

**可扩展方向**

- 用 `VNDetectFaceLandmarksRequest` 拿到五官关键点，把 emoji 精确对齐到眼睛/面部轮廓。
- 增加「撤销 / 重做」栈（`EditorItem` 已是值语义的独立对象，易于快照）。
- 贴纸支持「跟随人脸分组」，人脸移动时贴纸联动。
- 接入 `VNDetectHumanRectanglesRequest` 支持身体遮挡。
- 增加「批量处理相册照片」与 Share Extension（从其他 App 直接分享进隐颜）。
- 支持 Live Photo / 视频逐帧遮挡。
