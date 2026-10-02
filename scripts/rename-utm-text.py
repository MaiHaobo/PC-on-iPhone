#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 UTM 用户可见文本中的 "UTM" 替换为 "PC on iPhone"。

严格安全边界 —— 只动「人读的话」，不碰「机器认的符号」：
  改写：.md 文档正文、.strings 引号内的用户可见文案
  保留：URL / 包地址 / 许可证 / 代码标识符 / .utm 扩展名 / URL Scheme

用法：python3 scripts/rename-utm-text.py [--dry-run]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY_RUN = "--dry-run" in sys.argv
NEW_NAME = "PC on iPhone"

# 绝不触碰的文件（依赖定义、许可证、工程文件）
SKIP_FILES = {
    "LICENSE",
    "DEPENDENCIES.md",          # 依赖总览，含大量真实包名
    "CodeSigning.xcconfig.sample",
}
SKIP_DIRS = {".git", ".github"}
SKIP_EXT = {".pbxproj", ".xcscheme", ".entitlements", ".xcconfig", ".json", ".svg"}

# 这些 UTM 词形一律保留（是真实存在的上游标识，改了会破坏语义/法律声明）
KEEP_PATTERNS = [
    r"utmapp",                      # GitHub 组织名
    r"osy",                         # 作者
    r"github\.com/[\w./-]+",        # 任何 URL
    r"UTM-SE", r"UTM SE",           # 另一个项目名
    r"UTMQemu\w*", r"UTMApple\w*", r"UTMLegacy\w*", r"UTMSpice\w*",
    r"UTMScripting\w*", r"UTMVirtual\w*", r"UTMRegistry\w*", r"UTMConfig\w*",
    r"UTMRemote\w*", r"UTMSnapshot\w*", r"UTMSWTPM", r"UTMUSB\w*",
    r"UTMHelper\w*", r"UTMPipe\w*", r"UTMProcess", r"UTMPasteboard",
    r"UTMKeyboardShortcuts", r"UTMExtensions", r"UTMLogging\w*",
    r"UTMJailbreak", r"UTMQemuImage", r"UTMSerial\w*", r"UTMData",
    r"UTMQemuVirtualMachine", r"UTMQemuConstants", r"UTMPatches",
    r"kUTMConfig\w*", r"UTMRelease\w*", r"UTMDonate\w*", r"UTMApp\b",
    r"UTMSettingsView", r"UTMSingleWindowView", r"UTMExternalScene\w*",
    r"UTMDownload\w*", r"UTMPending\w*", r"UTMDataExtension",
    r"\bUTM\.xcodeproj", r"\bUTM\.app",
    r"utmctl", r"utm-release", r"utm-review", r"utm-submit", r"utm-test",
    r"\.utm\b", r"utm://", r"utm-", r"UTM_",
]

KEEP_RE = re.compile("|".join(KEEP_PATTERNS))


def protected_spans(text):
    """返回所有必须保留的区间 [(start, end), ...]"""
    return [(m.start(), m.end()) for m in KEEP_RE.finditer(text)]


def is_protected(pos, spans):
    return any(s <= pos < e for s, e in spans)


def replace_utm(text):
    """替换未被保护的裸 UTM """
    spans = protected_spans(text)
    out = []
    i = 0
    hits = 0
    while i < len(text):
        if text.startswith("UTM", i) and not is_protected(i, spans):
            # 其后紧跟字母/数字时，说明是某个标识符的一部分，跳过
            after = text[i + 3 : i + 4]
            before = text[i - 1 : i] if i > 0 else ""
            if after.isalnum() or after == "_" or before.isalnum() or before == "_":
                out.append(text[i])
                i += 1
                continue
            out.append(NEW_NAME)
            i += 3
            hits += 1
        else:
            out.append(text[i])
            i += 1
    return "".join(out), hits


def process_strings(text):
    """只改 .strings 中「= 」右侧引号内的用户可见文案，动注释则跳过"""
    out_lines = []
    hits = 0
    for line in text.split("\n"):
        stripped = line.lstrip()
        if stripped.startswith("/*") or stripped.startswith("//"):
            out_lines.append(line)          # 注释整行保留
            continue
        m = re.match(r'^(\s*"[^"]*"\s*=\s*)(".*";?)\s*$', line)
        if m and "UTM" in m.group(2):
            new_val, h = replace_utm(m.group(2))
            out_lines.append(m.group(1) + new_val)
            hits += h
        else:
            out_lines.append(line)
    return "\n".join(out_lines), hits


def process_md(text):
    """Markdown 正文替换；代码块与行内代码保留"""
    parts = re.split(r"(```.*?```|`[^`\n]*`)", text, flags=re.S)
    total = 0
    for idx in range(0, len(parts), 2):     # 偶数位是正文
        parts[idx], h = replace_utm(parts[idx])
        total += h
    return "".join(parts), total


def main():
    total_files = 0
    total_hits = 0
    changed = []

    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            ext = os.path.splitext(fn)[1]
            if ext not in (".md", ".strings"):
                continue
            if fn in SKIP_FILES:
                continue
            path = os.path.join(dirpath, fn)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    original = f.read()
            except (UnicodeDecodeError, OSError):
                continue

            if "UTM" not in original:
                continue

            if ext == ".strings":
                new, hits = process_strings(original)
            else:
                new, hits = process_md(original)

            if hits and new != original:
                total_files += 1
                total_hits += hits
                rel = os.path.relpath(path, ROOT)
                changed.append((rel, hits))
                if not DRY_RUN:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(new)

    mode = "DRY RUN" if DRY_RUN else "已写入"
    print(f"[{mode}] 修改 {total_files} 个文件，共 {total_hits} 处")
    print()
    for rel, hits in sorted(changed):
        print(f"  {hits:4d} 处  {rel}")


if __name__ == "__main__":
    main()
