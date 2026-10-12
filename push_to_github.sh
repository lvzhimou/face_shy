#!/usr/bin/env bash
#
# 把 FaceShy 推送到你的 GitHub 仓库（推完 Actions 会自动开始编译 IPA）
#
# 用法（在 FaceShy 目录下，用 Git Bash / macOS 终端）：
#   ./push_to_github.sh 你的GitHub用户名                 # 仓库名默认 face_shy
#   ./push_to_github.sh 你的GitHub用户名 face_shy        # 指定仓库名
#   ./push_to_github.sh https://github.com/xxx/face_shy.git   # 直接给完整地址
#   ./push_to_github.sh --device 你的GitHub用户名         # 先用「设备码」登录再推送（浏览器登录不顺时用）
#
# 前提：先在 GitHub 网页上建好一个空仓库（不要勾选 README / .gitignore / License）
#

set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
info() { echo "${BLUE}▶︎${NC} $*"; }
ok() { echo "${GREEN}✅${NC} $*"; }
warn() { echo "${YELLOW}⚠️ ${NC} $*"; }
die() { echo "${RED}❌ $*${NC}" >&2; exit 1; }

# ---------------------------------------------------------------- 0. 环境检查
cd "$(dirname "${BASH_SOURCE[0]}")"
[[ -d "FaceShy.xcodeproj" ]] || die "请在 FaceShy 项目目录下运行本脚本"
command -v git >/dev/null 2>&1 || die "未找到 git，请先安装 Git"

# 判断是否处于真实终端：
#  · 是 -> 允许 git 弹登录（浏览器 / 账号密码 / 设备码）
#  · 否 -> 禁用一切弹窗，宁可快速失败也不要卡死进程（例如被 IDE、脚本、CI 调用时）
if [[ -t 0 ]]; then
  INTERACTIVE=1
  export GIT_TERMINAL_PROMPT=1
else
  INTERACTIVE=0
  export GIT_TERMINAL_PROMPT=0
  export GCM_INTERACTIVE=never
fi

# ---------------------------------------------------------------- 1. 解析参数
USE_DEVICE=0
if [[ "${1:-}" == "--device" ]]; then
  USE_DEVICE=1
  shift
fi

[[ $# -ge 1 ]] || die "用法：
   ./push_to_github.sh 你的GitHub用户名 [仓库名]
   ./push_to_github.sh https://github.com/你的用户名/仓库名.git
   ./push_to_github.sh --device 你的GitHub用户名"

if [[ "$1" == http* ]]; then
  REMOTE_URL="$1"
  [[ "$REMOTE_URL" == *.git ]] || REMOTE_URL="$REMOTE_URL.git"
  REPO_SLUG="$(echo "$REMOTE_URL" | sed -e 's#.*github.com/##' -e 's#\.git$##')"
else
  GITHUB_USER="$1"
  REPO_NAME="${2:-face_shy}"
  REMOTE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
  REPO_SLUG="${GITHUB_USER}/${REPO_NAME}"
fi

echo "${BOLD}推送 FaceShy 到 GitHub${NC}"
echo "  目标仓库：$REPO_SLUG"
echo "  remote  ：$REMOTE_URL"
echo

# ---------------------------------------------------------------- 2. 确保有提交
if [[ ! -d .git ]]; then
  info "初始化本地仓库…"
  git init -b main >/dev/null
fi
git config user.name  >/dev/null 2>&1 || git config user.name  "FaceShy Dev"
git config user.email >/dev/null 2>&1 || git config user.email "dev@faceshy.local"

if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  info "创建首次提交…"
  git add -A
  git commit -q -m "隐颜 FaceShy: 本地 AI 人脸 emoji 遮挡 iOS App"
fi

if [[ -n "$(git status --porcelain)" ]]; then
  warn "检测到未提交的改动，一并提交"
  git add -A
  git commit -q -m "更新：$(date '+%Y-%m-%d %H:%M')"
fi
ok "本地提交就绪：$(git log --oneline -1)"

# ---------------------------------------------------------------- 3. 配置登录方式
# Git for Windows 默认 credential.helper=helper-selector，会先弹一个「选择凭证助手」的菜单；
# 这里直接指定 Git Credential Manager，推送时用浏览器登录 GitHub，比手动生成 PAT 省事。
CURRENT_HELPER="$(git config --get credential.helper || true)"
if [[ -z "$CURRENT_HELPER" || "$CURRENT_HELPER" == "helper-selector" ]]; then
  if command -v git-credential-manager >/dev/null 2>&1; then
    git config credential.helper manager
    info "已为本仓库启用 Git Credential Manager（省去手动生成 token）"
  fi
fi

# 可选：设备码登录（无需浏览器回调，适合浏览器登录不顺畅的环境）
if [[ $USE_DEVICE -eq 1 ]]; then
  command -v git-credential-manager >/dev/null 2>&1 || die "未找到 Git Credential Manager，无法使用设备码登录"
  [[ $INTERACTIVE -eq 1 ]] || die "设备码登录需要在真实终端里运行（它要打印验证码并等待你输入）"
  echo
  info "开始设备码登录，请按下面提示在浏览器里输入验证码："
  echo
  git credential-manager github login --device || die "设备码登录未完成"
  echo
  ok "登录成功"
  git credential-manager github list 2>/dev/null || true
  echo
fi

# ---------------------------------------------------------------- 4. 配置 remote
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
  info "已更新 origin 地址"
else
  git remote add origin "$REMOTE_URL"
  info "已添加 origin"
fi

# ---------------------------------------------------------------- 5. 推送
info "推送到 GitHub…"
if [[ $INTERACTIVE -eq 1 ]]; then
  echo "  ${YELLOW}首次推送会弹出 GitHub 登录（浏览器授权即可）；若改成让你输入用户名/密码，密码处填 Personal Access Token${NC}"
fi
echo

set +e
if [[ $INTERACTIVE -eq 1 ]]; then
  PUSH_OUTPUT="$(git push -u origin main 2>&1)"
  PUSH_STATUS=$?
else
  info "当前不是交互式终端，已禁用凭证弹窗，避免进程卡住"
  PUSH_OUTPUT="$(git -c credential.helper= push -u origin main 2>&1)"
  PUSH_STATUS=$?
fi
set -e
echo "$PUSH_OUTPUT"

if [[ $PUSH_STATUS -ne 0 ]]; then
  echo
  # 针对性识别最常见的两类失败
  if echo "$PUSH_OUTPUT" | grep -qi "workflow"; then
    die "推送被拒：授权里缺少 workflow 权限（因为仓库包含 .github/workflows/build-ipa.yml）。

  两个解决办法，任选其一：
  A. 换用 Personal Access Token（推荐，一次搞定）
     1. https://github.com/settings/tokens → Generate new token (classic)
     2. 勾选 scope：repo + workflow（两个都要勾）
     3. 重新执行本脚本，提示输入账号密码时：用户名填 GitHub 用户名，密码处粘贴 token

  B. 不改授权，改用网页创建 workflow
     1. 在 GitHub 上：Add file → Create new file，文件名填
          .github/workflows/build-ipa.yml
        内容直接复制本地 FaceShy/.github/workflows/build-ipa.yml
     2. 本地执行下面两行后再重新跑本脚本：
          git rm -r --cached .github
          echo '.github/' >> .git/info/exclude"
  fi

  if echo "$PUSH_OUTPUT" | grep -qiE "could not read Username|Authentication failed|403|terminal prompts disabled|not a terminal"; then
    die "推送失败：需要先登录 GitHub。三种方式任选：

  A. 设备码登录（最省事，不需要创建 token）
     在 Git Bash 里执行：
         ./push_to_github.sh --device ${REPO_SLUG%%/*}
     它会打印一个形如 XXXX-XXXX 的验证码，你用已登录的浏览器打开
         https://github.com/login/device
     输入验证码授权即可，然后会自动继续推送。

  B. 浏览器登录
     确认是在「Git Bash」里运行（不是 IDE 内置终端），首次推送会自动打开浏览器让你授权。
     若没弹出，先清掉旧的登录态再试：
         git config --unset credential.helper
         git credential-manager github logout

  C. Personal Access Token
     1. https://github.com/settings/tokens → Generate new token (classic)
     2. 勾选 repo + workflow
     3. 重新执行本脚本，提示输入账号密码时：密码处粘贴 token（不是登录密码）"
  fi

  if echo "$PUSH_OUTPUT" | grep -qiE "Repository not found|does not exist"; then
    die "推送失败：仓库不存在。

  请先到 https://github.com/new 建一个空仓库：
    · 仓库名填 ${REPO_SLUG##*/}
    · Public / Private 都行（Public 的 macOS 构建额度无限免费）
    · ⚠️ 不要勾选 Add a README / .gitignore / License
  建好后重新执行本脚本。"
  fi

  if echo "$PUSH_OUTPUT" | grep -qiE "Could not resolve host|Failed to connect|timed out|Connection refused"; then
    die "推送失败：网络问题（GitHub 直连不稳定）。

  处理建议：
    · 直接重跑本脚本，多试几次
    · 若之前给 git 配过代理，先清掉：
        git config --global --unset http.proxy
        git config --global --unset https.proxy
    · 若你的网络需要代理，则配上车代理端口：
        git config --global http.proxy http://127.0.0.1:端口号"
  fi

  die "推送失败，请把上面 git 的完整报错发给我，我按报错具体处理。"
fi

ok "推送成功"
echo
echo "${GREEN}${BOLD}接下来${NC}"
echo "  1. 打开 https://github.com/$REPO_SLUG/actions"
echo "     推送已经触发构建，等 2~4 分钟会出现一条绿色的 ✔"
echo "  2. 点进那条运行记录，页面底部 Artifacts 下载 ${BOLD}FaceShy-unsigned-ipa${NC}"
echo "  3. 解压得到 FaceShy-unsigned.ipa，丢给 Sideloadly / 轻松签 自签安装"
echo
echo "${YELLOW}提示${NC}：如果仓库设为 Public，macOS 构建额度完全免费且不限量；"
echo "      Private 也能用（免费账号每月 2000 分钟额度，macOS 按 10 倍计费，约可跑 60 次）。"
