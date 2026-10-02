#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  PC-on-iPhone · 无签名编译脚本（Unsigned Build）
#
#  用途：不需要任何证书 / 描述文件，只验证「代码能否编译通过」并产出
#  可审计的未签名 .ipa。适合开发阶段快速验证，或证书尚未就绪时。
#
#  产出：build/export/PC-on-iPhone-unsigned.ipa（未签名，无法直接安装）
#
#  安装说明：iOS 只接受签名 App。要装到设备上，请用 AltStore / Sideloadly
#  等工具，它们会用你自己的 Apple ID 重新签名后再安装（免费 Apple ID 有
#  7 天有效期限制）。
# ─────────────────────────────────────────────────────────────

set -o pipefail
shopt -s nullglob

step() { printf '\n──── %s ────\n' "$1"; }
ok()   { printf '[OK] %s\n' "$1"; }
warn() { printf '[警告] %s\n' "$1"; }
die()  { printf '\n[失败] %s\n' "$1" >&2; exit 1; }

REPO_DIR="$PWD"
TMP="${RUNNER_TEMP:-/tmp}"
BUILD_DIR="$REPO_DIR/build"
SCHEME="PC-on-iPhone"
XCODE_ARCHIVE="$TMP/PC-on-iPhone-unsigned.xcarchive"

# ══════════════════════════════════════════════════════════════
# 0. 选择 Xcode
# ══════════════════════════════════════════════════════════════
step "0/4 选择 Xcode"

pick_xcode() {
  local stable=() any=()
  for app in /Applications/Xcode_2[6-9]*.app /Applications/Xcode_2[6-9].app; do
    [ -d "$app" ] || continue
    any+=("$app")
    case "$(basename "$app")" in
      *beta*|*Beta*|*RC*|*rc*) ;;
      *) stable+=("$app") ;;
    esac
  done
  if [ ${#stable[@]} -gt 0 ]; then
    printf '%s\n' "${stable[@]}" | sort -V | tail -1
  elif [ ${#any[@]} -gt 0 ]; then
    printf '%s\n' "${any[@]}" | sort -V | tail -1
  fi
}

XCODE_APP="$(pick_xcode)"
if [ -z "$XCODE_APP" ]; then
  die "runner 上没有找到 Xcode 26+（当前镜像可能不是 xcode-27 / macos-26）"
fi
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
echo "  使用 Xcode：$(basename "$XCODE_APP")"
xcodebuild -version || die "找不到 xcodebuild"

SDK_VER=$(xcodebuild -version -sdk iphoneos ProductVersion 2>/dev/null | head -1 || true)
echo "  iOS SDK 版本：${SDK_VER:-未知}"
ok "Xcode 就绪"

# ══════════════════════════════════════════════════════════════
# 1. 编译 Archive（全部禁用签名）
# ══════════════════════════════════════════════════════════════
step "1/4 编译（xcodebuild archive，禁用签名）"

rm -rf "$XCODE_ARCHIVE"

xcodebuild archive \
  -project PC-on-iPhone.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$XCODE_ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  CODE_SIGN_STYLE=Manual \
  PROVISIONING_PROFILE_SPECIFIER="" \
  > "$TMP/archive.log" 2>&1
ARCHIVE_EXIT=$?

if [ "$ARCHIVE_EXIT" -ne 0 ]; then
  echo "════════ 编译错误摘要（error: 行）════════"
  grep -E "error:|error :|❌|fatal error" "$TMP/archive.log" | head -40 || echo "（未匹配到 error: 行，见下方末尾输出）"
  echo "════════ 编译日志末尾 120 行 ════════"
  tail -120 "$TMP/archive.log"
  echo "════════ 日志结束 ════════"

  # 把日志回传到仓库的 build-logs 分支，方便远程排查（artifact 下载受限时很有用）
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "→ 正在把日志回传到 build-logs 分支…"
    LOGDIR="$TMP/logpush"
    rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"
    cp "$TMP/archive.log" "$LOGDIR/" 2>/dev/null || true
    (
      cd "$LOGDIR" || exit 0
      git init -q -b build-logs
      git config user.email "actions@github.com"
      git config user.name "GitHub Actions"
      git add -A
      git commit -q -m "build log $(date -u +%Y%m%d-%H%M%S) run=${GITHUB_RUN_ID:-local}"
      git remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
      git push -f origin build-logs >/dev/null 2>&1 && echo "  ✓ 日志已推送到 build-logs 分支" || echo "  ✗ 日志回传失败"
    )
  fi

  die "编译失败（完整日志见 build-logs 产物）"
fi

APP_PATH="$XCODE_ARCHIVE/Products/Applications/$SCHEME.app"
[ -d "$APP_PATH" ] || die "编译成功但找不到 .app（$APP_PATH）"
ok "编译通过：$(basename "$APP_PATH")"
echo "  可执行文件：$(ls -lh "$APP_PATH/$SCHEME" 2>/dev/null | awk '{print $5}' || echo '未知')"

# ══════════════════════════════════════════════════════════════
# 2. 组装未签名 IPA（IPA 本质是特定目录结构的 zip）
# ══════════════════════════════════════════════════════════════
step "2/4 组装未签名 IPA"

rm -rf "$BUILD_DIR/export" "$TMP/ipa-build"
mkdir -p "$BUILD_DIR/export" "$TMP/ipa-build/Payload"

cp -R "$APP_PATH" "$TMP/ipa-build/Payload/"
# 清掉可能存在的旧签名残留，确保是干净的未签名包
rm -rf "$TMP/ipa-build/Payload/$SCHEME.app/_CodeSignature" 2>/dev/null || true

IPA="$BUILD_DIR/export/PC-on-iPhone-unsigned.ipa"
( cd "$TMP/ipa-build" && zip -qry "$IPA" Payload )
[ -f "$IPA" ] || die "打包 IPA 失败"

ls -lh "$IPA"
ok "已生成未签名 IPA"

# ══════════════════════════════════════════════════════════════
# 3. 包内信息自检（便于核对产物是否正常）
# ══════════════════════════════════════════════════════════════
step "3/4 产物自检"

PLIST="$APP_PATH/Info.plist"
if [ -f "$PLIST" ]; then
  BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST" 2>/dev/null || echo '?')
  MIN_OS=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST" 2>/dev/null || echo '?')
  VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || echo '?')
  echo "  Bundle ID      : $BUNDLE_ID"
  echo "  最低系统版本   : iOS $MIN_OS"
  echo "  App 版本       : $VERSION"
  ARCHS=$(lipo -info "$APP_PATH/$SCHEME" 2>/dev/null | sed 's/.*: //' || echo '?')
  echo "  架构           : $ARCHS"
fi
ok "自检完成"

# ══════════════════════════════════════════════════════════════
# 4. 发布到 Release（仅 v* 标签触发；作为预发布）
# ══════════════════════════════════════════════════════════════
if printf '%s' "${GITHUB_REF_NAME:-}" | grep -qE '^v[0-9]'; then
  step "4/4 发布未签名 IPA 到 Release"

  if [ -z "${GITHUB_TOKEN:-}" ]; then
    warn "GITHUB_TOKEN 为空，跳过发布（不影响编译结果）"
  else
    TAG="$GITHUB_REF_NAME"
    REPO_API="https://api.github.com/repos/${GITHUB_REPOSITORY}"
    GH_AUTH="Authorization: Bearer ${GITHUB_TOKEN}"

    RELEASE_ID=$(curl -s -H "$GH_AUTH" "$REPO_API/releases/tags/$TAG" | jq -r '.id // empty' 2>/dev/null || true)
    if [ -z "$RELEASE_ID" ]; then
      BODY=$(cat <<JSON
{"tag_name":"$TAG","name":"PC-on-iPhone $TAG (未签名)","prerelease":true,"draft":false,"body":"## PC-on-iPhone $TAG — 未签名构建\n\n本次产物为 **未签名 IPA**，用于验证代码可编译性。\n\n- 最低支持 **iOS 16.0**\n- 功能：SSH 终端（连接 PC / 服务器执行命令）\n\n### 如何安装\n未签名 App 无法直接安装。请使用 **AltStore / Sideloadly** 等工具，它们会用你自己的 Apple ID 重新签名后安装（免费 Apple ID 签发的有效期 7 天，需定期重签）。"}
JSON
)
      RELEASE_ID=$(curl -s -X POST -H "$GH_AUTH" -H "Content-Type: application/json" -d "$BODY" "$REPO_API/releases" | jq -r '.id // empty' 2>/dev/null || true)
      [ -n "$RELEASE_ID" ] && ok "Release 已创建（id=$RELEASE_ID）" || warn "创建 Release 失败，跳过发布"
    fi

    if [ -n "$RELEASE_ID" ]; then
      ASSET_NAME=$(basename "$IPA")
      OLD_ID=$(curl -s -H "$GH_AUTH" "$REPO_API/releases/$RELEASE_ID/assets?per_page=100" \
        | jq -r --arg n "$ASSET_NAME" '.[] | select(.name == $n) | .id' 2>/dev/null || true)
      [ -n "$OLD_ID" ] && curl -s -X DELETE -H "$GH_AUTH" "$REPO_API/releases/assets/$OLD_ID" >/dev/null

      URL=$(curl -s -X POST -H "$GH_AUTH" -H "Content-Type: application/octet-stream" \
        --data-binary @"$IPA" \
        "https://uploads.github.com/repos/${GITHUB_REPOSITORY}/releases/$RELEASE_ID/assets?name=$ASSET_NAME" \
        | jq -r '.browser_download_url // empty' 2>/dev/null || true)
      [ -n "$URL" ] && ok "已发布：$URL" || warn "上传失败"
    fi
  fi
else
  echo "非 v* 标签触发，跳过 Release 发布"
fi

printf '\n════════ 完成 ════════\n'
echo "产物：$IPA（未签名）"
