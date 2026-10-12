#!/usr/bin/env bash
# 构建“训练课单圈重置修复 + 配置缓存”版 fr970 PRG，输出到独立目录 bin/lapfix/，
# 不覆盖原构建产物 bin/RunDash970-fr970.prg（需要回退时直接装回它即可）。
#
#   scripts/build-lapfix.sh              正式版（EVENT_LOG = false：运行时不输出任何日志）
#                                          -> bin/lapfix/RunDash970-fr970-lapfix.prg
#   scripts/build-lapfix.sh --eventlog   诊断版（仅用于验证回调是否送达/是否重复/快照时序；
#                                          在临时副本里把 EVENT_LOG 置 true，仓库源码不改）
#                                          -> bin/lapfix/RunDash970-fr970-lapfix-eventlog.prg
#
# 开发者密钥：优先 $RUNDASH_KEY，其次 .secrets/developer_key.der，其次 ~/.connectiq/developer_key.der。
# 只把路径传给 monkeyc，不读取、不打印、不复制密钥内容。
# 本脚本不会安装到手表、不会发布、不会推送。
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

MODE=formal
case "${1:-}" in
  "") ;;
  --eventlog) MODE=eventlog ;;
  *) echo "用法: $0 [--eventlog]" >&2; exit 2 ;;
esac

KEY="${RUNDASH_KEY:-$ROOT/.secrets/developer_key.der}"
[[ -f "$KEY" ]] || KEY="$HOME/.connectiq/developer_key.der"
if [[ ! -f "$KEY" ]]; then
  echo "找不到开发者密钥。请设置 RUNDASH_KEY，或放到 .secrets/developer_key.der" >&2
  exit 2
fi

# macOS 的 /usr/bin/java 只是占位 stub：没有可用 Java 时，尝试 Homebrew 的 openjdk@17。
if ! java -version >/dev/null 2>&1; then
  for J in /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
           /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
    if [[ -x "$J/bin/java" ]]; then
      export JAVA_HOME="$J"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
fi
if ! java -version >/dev/null 2>&1; then
  echo "找不到可用的 Java（monkeyc 需要）。请安装 JDK 17 或设置 JAVA_HOME" >&2
  exit 2
fi

OUT_DIR="$ROOT/bin/lapfix"
mkdir -p "$OUT_DIR"
BUILD_LOG="$(mktemp -t rundash-lapfix-build.XXXXXX)"
TMP_DIR=""
cleanup() {
  rm -f "$BUILD_LOG"
  [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
  return 0
}
trap cleanup EXIT

if [[ "$MODE" == "formal" ]]; then
  PRG="$OUT_DIR/RunDash970-fr970-lapfix.prg"
  JUNGLE="$ROOT/monkey.jungle"
  # 正式版必须保持 EVENT_LOG = false
  if ! grep -Eq 'hidden var EVENT_LOG = false;' source/RunDash970View.mc; then
    echo "source/RunDash970View.mc 里 EVENT_LOG 不是 false：正式构建要求默认关闭" >&2
    exit 2
  fi
else
  PRG="$OUT_DIR/RunDash970-fr970-lapfix-eventlog.prg"
  TMP_DIR="$(mktemp -d -t rundash-lapfix-eventlog.XXXXXX)"
  mkdir -p "$TMP_DIR/source"
  cp source/*.mc "$TMP_DIR/source/"
  # 只在临时副本里置开关；先确认源码里恰好有一处 EVENT_LOG = false，替换后恰好有一处 = true
  if [[ "$(grep -c 'hidden var EVENT_LOG = false;' "$TMP_DIR/source/RunDash970View.mc")" != "1" ]]; then
    echo "找不到唯一的 'hidden var EVENT_LOG = false;'，无法生成诊断版" >&2
    exit 2
  fi
  sed 's/hidden var EVENT_LOG = false;/hidden var EVENT_LOG = true;/' \
    "$TMP_DIR/source/RunDash970View.mc" > "$TMP_DIR/View.tmp"
  mv "$TMP_DIR/View.tmp" "$TMP_DIR/source/RunDash970View.mc"
  if [[ "$(grep -c 'hidden var EVENT_LOG = true;' "$TMP_DIR/source/RunDash970View.mc")" != "1" ]]; then
    echo "诊断版开关替换失败" >&2
    exit 2
  fi
  JUNGLE="$TMP_DIR/diag.jungle"
  {
    echo "project.manifest = $ROOT/manifest.xml"
    echo "base.sourcePath = $TMP_DIR/source"
    echo "base.resourcePath = $ROOT/resources;$ROOT/resources-zhs"
  } > "$JUNGLE"
fi

echo "==> 构建 fr970 (${MODE}) -> ${PRG#$ROOT/}"
if ! monkeyc -d fr970 -f "$JUNGLE" -o "$PRG" -y "$KEY" -w > "$BUILD_LOG" 2>&1; then
  cat "$BUILD_LOG" >&2
  echo "构建失败" >&2
  exit 1
fi
cat "$BUILD_LOG"
WARN_COUNT="$(grep -c '^WARNING' "$BUILD_LOG" || true)"
if grep -q '^ERROR' "$BUILD_LOG"; then
  echo "构建日志含 ERROR" >&2
  exit 1
fi
[[ -f "$PRG" ]] || { echo "未生成 $PRG" >&2; exit 1; }

SHA="$(shasum -a 256 "$PRG" | awk '{print $1}')"
SIZE="$(stat -f %z "$PRG" 2>/dev/null || stat -c %s "$PRG")"
ORIG="$ROOT/bin/RunDash970-fr970.prg"
ORIG_SHA="(不存在)"
[[ -f "$ORIG" ]] && ORIG_SHA="$(shasum -a 256 "$ORIG" | awk '{print $1}')"
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
DIRTY="$(git status --porcelain -- source 2>/dev/null | wc -l | tr -d ' ')"

{
  echo "mode:            ${MODE}"
  echo "built_at:        $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "git_head:        ${HEAD_SHA} (source/ has ${DIRTY} uncommitted changed file(s))"
  echo "device:          fr970"
  echo "prg:             ${PRG#$ROOT/}"
  echo "prg_sha256:      ${SHA}"
  echo "prg_size_bytes:  ${SIZE}"
  echo "warnings:        ${WARN_COUNT}"
  echo "orig_prg_sha256: ${ORIG_SHA}   (bin/RunDash970-fr970.prg; this script never modifies it)"
} > "$OUT_DIR/BUILD_INFO-${MODE}.txt"

echo "==> 完成"
echo "    产物:     ${PRG#$ROOT/}"
echo "    SHA-256:  ${SHA}"
echo "    大小:     ${SIZE} bytes   编译警告: ${WARN_COUNT}"
echo "    原产物:   bin/RunDash970-fr970.prg 未改动 (SHA-256 ${ORIG_SHA})"
echo "    说明:     已写入 bin/lapfix/BUILD_INFO-${MODE}.txt。本脚本不会安装到手表、不会发布、不会推送。"
