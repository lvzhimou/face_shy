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

# ---------------------------------------------------------------- 1.5 前置校验
# 先验证 project.pbxproj 是否合法，再调用 xcodebuild。
# 原因：pbxproj 解析失败时 xcodebuild 只会打印
#   "JSON text did not start with array or object"
# 和 "The project is damaged and cannot be opened due to a parse error"，
# 完全看不出真正错在哪一行，极难排查。这里先给出精确位置。
PBXPROJ="$ROOT_DIR/$PROJECT_NAME.xcodeproj/project.pbxproj"
if [[ -f "$PBXPROJ" ]]; then
  PY=""
  for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then PY="$cand"; break; fi
  done
  if [[ -n "$PY" && -f "$ROOT_DIR/tools/validate_pbxproj.py" ]]; then
    info "校验 project.pbxproj 语法…"
    if ! "$PY" "$ROOT_DIR/tools/validate_pbxproj.py" "$PBXPROJ"; then
      die "project.pbxproj 校验不通过（原因见上）。
   修复方式：运行  python3 tools/generate_xcodeproj.py  重新生成工程文件。"
    fi
  else
    warn "跳过 pbxproj 校验（需要 python3 与 tools/validate_pbxproj.py）"
  fi

  # 用 Ruby 的 xcodeproj（CocoaPods 同款）做二次交叉验证，最接近 Xcode 的真实行为
  if command -v ruby >/dev/null 2>&1 && ruby -e 'require "xcodeproj"' >/dev/null 2>&1; then
    info "用 xcodeproj 库交叉验证（模拟 Xcode 读取）…"
    if ! ruby -e "require 'xcodeproj'; p=Xcodeproj::Project.open('$ROOT_DIR/$PROJECT_NAME.xcodeproj'); puts \"   目标: #{p.targets.map(&:name).join(', ')}\""; then
      die "Xcode 工程无法被 xcodeproj 解析。请运行 python3 tools/generate_xcodeproj.py 重新生成。"
    fi
  fi

  # 让 xcodebuild 自己确认能识别工程（快速失败，避免白等编译）
  info "确认 xcodebuild 能识别工程…"
  if ! xcodebuild -project "$ROOT_DIR/$PROJECT_NAME.xcodeproj" -list >/dev/null 2>&1; then
    echo "--- xcodebuild -list 的原始输出 ---"
    xcodebuild -project "$ROOT_DIR/$PROJECT_NAME.xcodeproj" -list 2>&1 | tail -20 || true
    die "xcodebuild 无法读取该工程（见上方原始输出）"
  fi
  ok "工程文件校验通过"
fi

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
