#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
README 中裸 UTM 的替换（第二轮）。

第一轮遗漏的原因：判断「后接字母数字则跳过」时用了 str.isalnum()，
而该函数对日文假名、韩文谚文返回 True，导致 `UTMは`、`UTM은` 被误判为
标识符的一部分而跳过。

本轮修正：只有后接 ASCII 字母/数字/下划线时才视为标识符并跳过。

严格保留：
  - URL（含 utmapp/ 组织、getutm.app 等域名）
  - "UTM SE" 专有名词（真实存在的另一个项目）
  - Markdown 链接定义 [1]: https://...
  - 代码块与行内代码

用法：python3 scripts/rename-utm-in-readme.py [--dry-run]
"""
import os
import re
import sys
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DRY_RUN = "--dry-run" in sys.argv
NEW_NAME = "PC on iPhone"

# 必须保留：URL 与专有名词
KEEP_RE = re.compile(
    r"utmapp"
    r"|getutm\.app"
    r"|github\.com/[\w./-]+"
    r"|https?://\S+"
    r"|UTM SE"
    r"|UTM-SE"
)

# 标识符判定：仅 ASCII 字母数字下划线
ASCII_WORD = re.compile(r"[A-Za-z0-9_]")


def replace_bare_utm(text):
    """替换未被保护的裸 UTM，返回 (新文本, 替换数)"""
    spans = [(m.start(), m.end()) for m in KEEP_RE.finditer(text)]
    protected = lambda p: any(s <= p < e for s, e in spans)

    out = []
    i = 0
    hits = 0
    while i < len(text):
        if text.startswith("UTM", i) and not protected(i):
            before = text[i - 1] if i > 0 else ""
            after = text[i + 3] if i + 3 < len(text) else ""
            # 仅当紧邻 ASCII 词字符时才认为是标识符的一部分
            if ASCII_WORD.match(before or "") or ASCII_WORD.match(after or ""):
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


def process_md(text):
    """跳过代码块与行内代码，其余部分替换"""
    parts = re.split(r"(```.*?```|`[^`\n]*`)", text, flags=re.S)
    total = 0
    for idx in range(0, len(parts), 2):
        parts[idx], h = replace_bare_utm(parts[idx])
        total += h
    return "".join(parts), total


def main():
    files = sorted(glob.glob(os.path.join(ROOT, "README*.md")))
    total_files = 0
    total_hits = 0

    for path in files:
        name = os.path.basename(path)
        try:
            with open(path, encoding="utf-8") as f:
                original = f.read()
        except (UnicodeDecodeError, OSError):
            continue

        if "UTM" not in original:
            continue

        new, hits = process_md(original)
        if hits and new != original:
            total_files += 1
            total_hits += hits
            print(f"  {hits:3d} 处  {name}")
            if not DRY_RUN:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(new)

    mode = "DRY RUN" if DRY_RUN else "已写入"
    print(f"\n[{mode}] 修改 {total_files} 个文件，共 {total_hits} 处")


if __name__ == "__main__":
    main()
