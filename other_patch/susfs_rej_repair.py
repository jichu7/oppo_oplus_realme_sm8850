#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SUSFS 补丁 rejects 自愈工具

背景
----
老版本 SUSFS 补丁（如 2.3.0 = 456ea36dd4）里有若干 hunk 只做「插入几行 #include」，
而新基线（android16-6.12-2026-03）在同样的位置新增了 `#include <linux/dma-buf.h>`
之类的行，导致 hunk 的上下文完全对不上（这是上下文中间不匹配，不是整体偏移，
加 fuzz 也救不了），patch 只能把整段 reject 掉，构建随之失败。

本工具只处理这一类「纯插入、无删除」的 include 段落失配：

  1. 逐个检查当前目录下的 *.rej，确认 hunk 里没有任何删除行(-)，且所有插入行(+)都是
     预处理指令（#include / #if / #ifdef / #ifndef / #elif / #else / #endif）或空行；
  2. 用 hunk 中「插入点之前、仍能在源码里找到的最后一条上下文行」定位，
     把插入内容补进对应源码文件；
  3. 删掉已修补的 .rej。

任何非 include 类的 reject（改代码、删行、上下文错位到别的函数等）都保留原样，
脚本以退出码 1 结束，调用方据此判定补丁失败，绝不静默错打。

用法
----
    python3 susfs_rej_repair.py [补丁应用目录]     # 默认当前目录

退出码
------
    0 = 所有 rejects 都是 include 插入并已修补（现在没有 .rej 残留）
    1 = 仍有无法自愈的 rejects，需要人工处理
"""

import os
import re
import sys

# 允许的插入行：#include / 预处理条件指令 / 空行
ALLOWED_LINE = re.compile(
    r'^[ \t]*(?:#[ \t]*(?:include|if|ifdef|ifndef|elif|else|endif)\b.*)?$'
)

SUSFS_INCLUDE = "#include <linux/susfs_def.h>"


def split_hunks(text):
    """把 rej 正文按 hunk 头(@@)切开，每条 hunk 只保留 +/-/空格 开头的行。"""
    hunks = []
    cur = None
    for line in text.splitlines():
        if line.startswith("@@"):
            cur = []
            hunks.append(cur)
            continue
        if cur is None:
            continue
        if line[:1] in ("+", "-", " "):
            cur.append(line)
    return hunks


def is_include_only(body):
    """hunk 是否只是插入预处理指令/空行（没有删除任何内容）。"""
    adds = 0
    for line in body:
        if line.startswith("-"):
            return False
        if not line.startswith("+"):
            continue
        if not ALLOWED_LINE.match(line[1:]):
            return False
        adds += 1
    return adds > 0


def first_match(lines, text):
    for idx, line in enumerate(lines):
        if line == text:
            return idx
    return None


def repair_file(rej_path):
    """修补单个 rej，返回 True=已修好（rej 已删除），False=需要人工处理。"""
    target = rej_path[:-4]
    if not os.path.isfile(target):
        print("::error::%s 对应的源文件 %s 不存在" % (rej_path, target))
        return False

    with open(rej_path, encoding="utf-8", errors="replace") as f:
        hunks = split_hunks(f.read())
    with open(target, encoding="utf-8", errors="replace") as f:
        src = f.read().splitlines()

    if not hunks:
        print("::error::%s 解析不出任何 hunk，无法自愈" % rej_path)
        return False

    ok = True
    for body in hunks:
        if not is_include_only(body):
            print("::error::%s 含非 include 内容（改代码/删行），不能自动修补" % rej_path)
            ok = False
            continue

        adds = [line[1:] for line in body if line.startswith("+")]
        # 幂等：这段 include 已经在文件里了就不重复插
        if SUSFS_INCLUDE in [line.strip() for line in src]:
            continue

        # 锚点 = 插入点之前、源码里能找到的最后一条上下文行
        anchor = None
        for line in body:
            if line.startswith("+"):
                break
            if line[:1] in (" ", "-"):
                idx = first_match(src, line[1:])
                if idx is not None:
                    anchor = idx
        if anchor is None:
            print("::error::%s 找不到可用的插入锚点" % rej_path)
            ok = False
            continue

        src = src[: anchor + 1] + adds + src[anchor + 1:]

    if not ok:
        return False

    with open(target, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(src) + "\n")
    os.remove(rej_path)
    print("[+] 已按源码实际位置补插 include: %s" % target)
    return True


def main(root):
    repaired = 0
    failed = 0
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in sorted(filenames):
            if not name.endswith(".rej"):
                continue
            if repair_file(os.path.join(dirpath, name)):
                repaired += 1
            else:
                failed += 1
    print("补丁 rejects 自愈结果: 已修补 %d 个, 无法自愈 %d 个" % (repaired, failed))
    if repaired == 0 and failed == 0:
        # patch 也可能因为「找不到目标文件」之类的错误失败，此时不会留下 .rej，
        # 那种情况绝不能当成自愈成功放过去
        print("::error::没有任何 reject 可修补（patch 失败原因不在 hunk 上下文）")
        return False
    return failed == 0


if __name__ == "__main__":
    sys.exit(0 if main(sys.argv[1] if len(sys.argv) > 1 else ".") else 1)
