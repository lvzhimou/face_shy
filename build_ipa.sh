#!/usr/bin/env bash
#
# 隐颜 FaceShy — 一键构建「未签名 IPA」（用于自签工具安装）
#
# 用法（必须在 macOS 上运行）：
#   ./build_ipa.sh                          # 默认 Release，输出 build/FaceShy-unsigned.ipa
#   BUNDLE_ID=com.你的名字.faceshy ./build_ipa.sh
#   CONFIGURATION=Debug ./build_ipa.sh
#
# 产物可直接丢给 Sideloadly / AltStore / 轻松签 / ESign / 爱思助手 做自签安装。
#

set -euo pipefail

PROJECT_NAME="FaceShy"
SCHEME_NAME="FaceShy"
CONFIGURATION="${CONFIGURATION:-Release}"
BUNDLE_ID="${BUNDLE_ID:-com.faceshy.app}"
# 用时间戳当构建号，便于覆盖安装（同一 bundle id 换构建号即可升级）
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DIR="$BUILD_DIR/DerivedData"
STAGE_DIR="$BUILD_DIR/ipa"
IPA_NAME="${PROJECT_NAME}-unsigned.ipa"

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; NC=$'\033[0m'

die() { echo "${RED}❌ $*${NC}" >&2; exit 1; }
info() { echo "${BLUE}▶︎${NC} $*"; }
ok() { echo "${GREEN}✅${NC} $*"; }
warn() { echo "${YELLOW}⚠️ ${NC} $*"; }

# ---------------------------------------------------------------- 0. 环境检查
if [[ "$(uname -s)" != "Darwin" ]]; then
  die "iOS 应用只能在 macOS 上编译（当前系统：$(uname -s)）。
   Windows / Linux 没有 iOS SDK，无法产出 IPA。
   请改用云端 macOS 构建：见 .github/workflows/build-ipa.yml（GitHub 免费额度即可）"
fi

command -v xcodebuild >/dev/null 2>&1 || die "未找到 xcodebuild，请先安装 Xcode（App Store 搜索 Xcode）"
command -v zip >/dev/null 2>&1 || die "未找到 zip 命令"

XCODE_VER="$(xcodebuild -version 2>/dev/null | head -1 || true)"
[[ -n "$XCODE_VER" ]] || die "xcodebuild 不可用，请先执行：sudo xcode-select -s /Applications/Xcode.app"

echo "${BOLD}隐颜 FaceShy · 未签名 IPA 构建${NC}"
echo "  $(printf '%s' "$XCODE_VER")"
echo "  配置：$CONFIGURATION    Bundle ID：$BUNDLE_ID    构建号：$BUILD_NUMBER"
echo

# ---------------------------------------------------------------- 1. 清理
info "清理旧的构建产物…"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ---------------------------------------------------------------- 2. 编译
info "开始编译（首次编译约 1~3 分钟）…"
set +e
xcodebuild \
  -project "$ROOT_DIR/$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME_NAME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DIR" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  build
BUILD_STATUS=$?
set -e

if [[ $BUILD_STATUS -ne 0 ]]; then
  die "编译失败。可在 Xcode 里打开工程看具体报错，或用下面的命令看完整日志：
   xcodebuild -project $PROJECT_NAME.xcodeproj -scheme $SCHEME_NAME -sdk iphoneos build 2>&1 | tail -80"
fi

# ---------------------------------------------------------------- 3. 定位 .app
APP_PATH="$DERIVED_DIR/Build/Products/${CONFIGURATION}-iphoneos/${PROJECT_NAME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find "$DERIVED_DIR/Build/Products" -maxdepth 2 -name "${PROJECT_NAME}.app" -type d 2>/dev/null | head -1)"
fi
[[ -d "$APP_PATH" ]] || die "编译成功但找不到 $PROJECT_NAME.app，请检查工程配置"
ok "已生成 App：$(basename "$APP_PATH")"

# ---------------------------------------------------------------- 4. 打包成 IPA
# iOS 安装包规范：zip 内必须是 Payload/xxx.app
info "打包为 IPA…"
mkdir -p "$STAGE_DIR/Payload"
cp -R "$APP_PATH" "$STAGE_DIR/Payload/"

# 清掉会在真机上引起问题的残留（未签名包不需要签名目录）
rm -rf "$STAGE_DIR/Payload/${PROJECT_NAME}.app/_CodeSignature" 2>/dev/null || true
rm -f  "$STAGE_DIR/Payload/${PROJECT_NAME}.app/embedded.mobileprovision" 2>/dev/null || true

pushd "$STAGE_DIR" >/dev/null
zip -qry "$BUILD_DIR/$IPA_NAME" Payload
popd >/dev/null

IPA_PATH="$BUILD_DIR/$IPA_NAME"
[[ -f "$IPA_PATH" ]] || die "IPA 打包失败"

# ---------------------------------------------------------------- 5. 结果
SIZE="$(du -h "$IPA_PATH" | cut -f1)"
EXEC_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist" 2>/dev/null || echo "$PROJECT_NAME")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Info.plist" 2>/dev/null || echo "-")"

echo
echo "${GREEN}${BOLD}🎉 构建完成${NC}"
echo "  文件：$IPA_PATH"
echo "  大小：$SIZE    版本：$VERSION    可执行文件：$EXEC_NAME    架构：arm64"
echo
echo "${BOLD}接下来怎么装到手机上（未签名包必须自签）${NC}"
echo "  · Sideloadly（电脑端，Win/Mac 都能用）：选 IPA → 填 Apple ID → Start，自动签名并安装"
echo "  · AltStore / SideStore：把 IPA 拷到手机，用 App 内导入安装"
echo "  · 轻松签 / ESign / 全能签：手机上导入 IPA，用免费证书签名后安装"
echo "  · 爱思助手：先自签再安装（不能直接装未签名包）"
echo
echo "  ${YELLOW}注意${NC}：免费 Apple ID 签名的 App 有效期 7 天，到期重新签一次即可；"
echo "        每个免费账号同时最多 3 个自签 App。"
echo
warn "如果安装后闪退：优先检查 IPA 是否为 arm64（本脚本已强制 arm64），以及设备 iOS 是否 ≥ 16.0"
