#!/usr/bin/env bash
#
# 把 FaceShy 推送到你的 GitHub 仓库（推完 Actions 会自动开始编译 IPA）
#
# 用法（在 FaceShy 目录下，用 Git Bash / macOS 终端 / Linux 终端）：
#   ./push_to_github.sh 你的GitHub用户名                 # 仓库名默认 face_shy
#   ./push_to_github.sh 你的GitHub用户名 face_shy        # 指定仓库名
#   ./push_to_github.sh https://github.com/xxx/face_shy.git   # 直接给完整地址
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

[[ $# -ge 1 ]] || die "用法：
   ./push_to_github.sh 你的GitHub用户名 [仓库名]
   ./push_to_github.sh https://github.com/你的用户名/仓库名.git"

# ---------------------------------------------------------------- 1. 解析参数
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
# Git for Windows 默认 credential.helper=helper-selector，会先弹一个「选择凭证助手」的菜单，
# 这里直接指定 Git Credential Manager，推送时用浏览器登录 GitHub，比手动生成 PAT 省事。
CURRENT_HELPER="$(git config --get credential.helper || true)"
if [[ -z "$CURRENT_HELPER" || "$CURRENT_HELPER" == "helper-selector" ]]; then
  if command -v git-credential-manager >/dev/null 2>&1; then
    git config credential.helper manager
    info "已为本仓库启用 Git Credential Manager（省去手动生成 token）"
  fi
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
if [[ -t 0 ]]; then
  echo "  ${YELLOW}首次推送会弹出 GitHub 登录（浏览器授权即可）；若改成让你输入用户名/密码，密码处填 Personal Access Token${NC}"
fi
echo
set +e
if [[ -t 0 ]]; then
  git push -u origin main
  PUSH_STATUS=$?
else
  # 非交互环境（脚本 / CI / 被其他程序调用）：禁用一切弹窗，宁可快速失败也不要卡死
  info "当前不是交互式终端，已禁用凭证弹窗，避免进程卡住"
  GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git -c credential.helper= push -u origin main
  PUSH_STATUS=$?
fi
set -e

if [[ $PUSH_STATUS -ne 0 ]]; then
  echo
  die "推送失败。请对照下面的原因处理：

  ① 提示 could not read Username / Authentication failed / 403 / 卡住不动
     → 需要登录授权，两种方式任选：
        · 方式一（推荐）：用「Git Bash」运行本脚本，会自动打开浏览器登录 GitHub；
          若你是在 IDE 内置终端里运行，换成 Git Bash 再试一次。
        · 方式二：用 Personal Access Token（在非交互环境里最快）
            1. 打开 https://github.com/settings/tokens → Generate new token (classic)
            2. 勾选 scope：repo （只勾这个就够了）
            3. 生成后复制 token（形如 ghp_xxxxxxxx）
            4. 重新执行本脚本，若提示输入账号密码：
                 用户名：你的 GitHub 用户名
                 密码  ：粘贴 token（不是登录密码）

  ② 提示 Repository not found
     → 仓库还没建。先到 https://github.com/new 建一个空仓库：
       仓库名填 ${REPO_SLUG##*/}，Public / Private 都行，
       ⚠️ 不要勾选 Add a README / .gitignore / License（否则会有冲突）
       建好后重新执行本脚本。

  ③ 网络超时 / Could not resolve host / Failed to connect
     → GitHub 连接不稳定，多试几次；也可以先清掉代理再试：
         git config --global --unset http.proxy
         git config --global --unset https.proxy"
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
