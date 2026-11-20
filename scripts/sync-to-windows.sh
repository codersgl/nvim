#!/usr/bin/env bash
# =============================================================================
# sync-to-windows.sh —— 把 WSL 侧 nvim 配置同步到 Windows（WSL 为主，单向覆盖）
# =============================================================================
#
# 方向：WSL  ->  Windows   （单向；Windows 侧的任何改动都会被覆盖）
#
# 同步内容：
#   1) ~/.config/nvim  ->  %LOCALAPPDATA%\nvim
#      （nvim 在 Windows 上的 stdpath("config") 就是这里）
#   2) ~/.config/nvim/neovide/config.toml  ->  %APPDATA%\neovide\config.toml
#
# 行为：
#   * 同步前把 Windows 侧现有配置备份到 %LOCALAPPDATA%\nvim.bak-<时间戳>
#   * 用 rsync --delete 让 Windows 侧与 WSL 完全一致（清掉双方都没用的残留）
#   * 文本文件保留 LF 行尾（与 WSL 完全一致；Windows 的 Neovim 读 LF 没有问题）
#     想转成 Windows 习惯的 CRLF 就加 --crlf
#   * 可选在 Windows 侧建一个 git 仓库留档（--git），方便回滚/看 diff
#
# 用法：
#   scripts/sync-to-windows.sh              # 正常同步（LF 行尾）
#   scripts/sync-to-windows.sh --dry-run    # 只看会改什么，不动文件
#   scripts/sync-to-windows.sh --crlf       # 同步后把文本转成 CRLF
#                                           #（之后若要再同步，请一直带 --crlf，
#                                           #  否则会被 LF 覆盖回去）
#   scripts/sync-to-windows.sh --git        # 同步后顺手在 Windows 侧 git 提交留档
#
# 注意 1：Windows 上的 nvim 版本可能与 WSL 不同（本机 WSL v0.12.4 / Windows
#         v0.11.5）。配置本身跨版本可用，但首次在 Windows 启动时会按
#         lazy-lock.json 拉取/对齐插件，可能需要等一会儿。
#
# 注意 2（插件版本会各自漂移）：lazy.nvim 在安装/更新插件后会重写它自己那份
#         lazy-lock.json，而且它默认按分支最新提交安装，并不强制回到锁文件里
#         的提交。所以：
#           * 同步过去的那份锁文件只决定 Windows 首次装插件时的起点；
#           * Windows 装完后可能把锁文件改成更新的提交（本机就有 2 个插件这样）；
#           * 之后两端就各记各的版本。
#         想让 Windows 严格回到 WSL 锁定的版本，在 Windows 侧执行：
#           nvim --headless "+Lazy! restore" +qa!
#         （前提是那些旧提交在远端还能取到；本机有一个插件已被上游 rebase，
#           旧提交在远端取不到了，只能保持各自版本。）
#         本机的处理办法：把 Windows 实际装的提交写回 WSL 的 lazy-lock.json，
#         让两端记录一致，而不是让 Windows 回退到取不到的旧提交。
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------- 参数解析 --
DRY_RUN=0
CRLF=0
DO_GIT=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --crlf)    CRLF=1 ;;
    --git)     DO_GIT=1 ;;
    -h|--help) sed -n '2,44p' "$0"; exit 0 ;;
    *) echo "未知参数: $arg（-h 看用法）" >&2; exit 2 ;;
  esac
done

# ------------------------------------------------------------ 定位两端路径 --
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # WSL 侧 nvim 配置根目录

# Windows 用户目录：优先问 Windows 自己，问不到就按挂载目录猜
WINUSER="$(cd /mnt/c 2>/dev/null && cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)"
if [[ -z "$WINUSER" ]]; then
  # 兜底：/mnt/c/Users 下第一个看起来像真实用户的目录
  WINUSER="$(ls /mnt/c/Users 2>/dev/null | grep -vE '^(All Users|Default|Default User|DefaultAppPool|Public|desktop\.ini|AppData|GLCache|WsiAccount)$' | head -1)"
fi
[[ -n "$WINUSER" ]] || { echo "❌ 定位不到 Windows 用户名" >&2; exit 1; }

WIN_HOME="/mnt/c/Users/$WINUSER"
DST="$WIN_HOME/AppData/Local/nvim"
NEOVIDE_DST="$WIN_HOME/AppData/Roaming/neovide"

echo "源        : $SRC"
echo "Windows 用户: $WINUSER"
echo "目标      : $DST"
[[ $DRY_RUN -eq 1 ]] && echo "模式      : DRY-RUN（不会改动任何文件）"

[[ -d "$WIN_HOME" ]] || { echo "❌ 找不到 Windows 用户目录: $WIN_HOME" >&2; exit 1; }
[[ -d "$DST" ]] || { echo "⚠️  Windows 侧还没有 $DST，将新建" >&2; }

# ------------------------------------------------------------------ 备份 --
if [[ $DRY_RUN -eq 0 && -d "$DST" ]]; then
  STAMP="$(date +%Y%m%d-%H%M%S)"
  BAK="$WIN_HOME/AppData/Local/nvim.bak-$STAMP"
  echo
  echo "==> 备份 Windows 现有配置 -> $BAK"
  # Windows 侧 nvim 的 stdpath("data") 配置里可能是 %LOCALAPPDATA%\nvim-data
  # 这类外部目录，但历史版本/手工移入时 lua 也可能堆在这里。备份时排除已装的
  # lua 插件，避免把 nvim-data（几百 MB）整个复制一份。
  rsync -a --exclude='lua' "$DST/" "$BAK/"
fi

# ------------------------------------------------------------ rsync 同步 --
# 排除：.git（Windows 侧独立留档）、生成物、日志、测试缓存和 WSL 专属内容
EXCLUDES=(
  --exclude=.git/
  --exclude=nvim.log
  --exclude='*.log'
  --exclude=.dsh-test/
  --exclude=.npm-cache/
  --exclude=.tests
  --exclude=debug
  --exclude=.repro
  --exclude=data/
  --exclude=doc/tags
  --exclude=.agents/
  --exclude=.aws/
  --exclude=.codex/
  --exclude=scripts/
  --exclude=vscode/
)

RSYNC_ARGS=(-a --delete --human-readable "${EXCLUDES[@]}")
[[ $DRY_RUN -eq 1 ]] && RSYNC_ARGS+=(--dry-run --itemize-changes)
[[ $DRY_RUN -eq 0 ]] && RSYNC_ARGS+=(--info=stats1)

mkdir -p "$DST"
echo
echo "==> 同步 nvim 配置 ($SRC -> $DST)"
rsync "${RSYNC_ARGS[@]}" "$SRC/" "$DST/"

# neovide 配置：文件本身已是同一份，保持同步以防以后只在一边改
if [[ -f "$SRC/neovide/config.toml" ]]; then
  mkdir -p "$NEOVIDE_DST"
  echo
  echo "==> 同步 neovide 配置 -> $NEOVIDE_DST/config.toml"
  if [[ $DRY_RUN -eq 1 ]]; then
    if diff -q "$SRC/neovide/config.toml" "$NEOVIDE_DST/config.toml" >/dev/null 2>&1; then
      echo "    （无变化）"
    else
      echo "    会更新 config.toml"
    fi
  else
    cp -a "$SRC/neovide/config.toml" "$NEOVIDE_DST/config.toml"
  fi
fi

# ------------------------------------------------------------ 行尾转换 ---
# 只对文本类文件做 LF -> CRLF，已有 CRLF 的跳过（避免变成 CRCRLF）
if [[ $CRLF -eq 1 && $DRY_RUN -eq 0 ]]; then
  echo
  echo "==> 行尾转换 LF -> CRLF"
  converted=0
  while IFS= read -r -d '' f; do
    if file --brief "$f" 2>/dev/null | grep -q 'CRLF'; then
      continue
    fi
    if file --brief --mime "$f" 2>/dev/null | grep -q 'charset=binary'; then
      continue
    fi
    sed -i 's/$/\r/' "$f"
    converted=$((converted + 1))
  done < <(find "$DST" -type f \
             \( -name '*.lua' -o -name '*.json' -o -name '*.toml' \
                -o -name '*.md' -o -name '*.txt' -o -name '.gitignore' \) -print0)
  echo "    已转换 $converted 个文件"
fi

# ------------------------------------------------- 可选：Windows 侧 git 留档 --
if [[ $DO_GIT -eq 1 && $DRY_RUN -eq 0 ]]; then
  echo
  echo "==> 在 Windows 侧 git 提交留档"
  if [[ ! -d "$DST/.git" ]]; then
    git -C "$DST" init -q
    git -C "$DST" symbolic-ref HEAD refs/heads/windows-sync
  fi
  git -C "$DST" add -A
  if git -C "$DST" diff --cached --quiet; then
    echo "    无改动，跳过提交"
  else
    git -C "$DST" -c user.name="wsl-sync" -c user.email="wsl-sync@local" \
      commit -q -m "sync from WSL $(date +%Y-%m-%d\ %H:%M:%S)"
    echo "    已提交: $(git -C "$DST" log --oneline -1)"
  fi
fi

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "✅ DRY-RUN 结束（未改动任何文件）"
else
  echo "✅ 同步完成。Windows 侧 nvim 下次启动即生效。"
  echo "   提示：Windows nvim 首次启动会按 lazy-lock.json 对齐插件，稍等即可。"
fi
