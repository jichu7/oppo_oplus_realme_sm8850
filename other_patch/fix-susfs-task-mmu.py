#!/usr/bin/env python3
"""Move the SUSFS SUS_MAP check into show_smap().

Older 6.12 trees have show_smap() directly; newer ones (e.g. 6.12.69) added
__show_smap() and the upstream SUSFS hunk can fuzz into that void helper,
where 'vma' does not exist.  This makes the placement deterministic.
"""
import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: fix-susfs-task-mmu.py fs/proc/task_mmu.c", file=sys.stderr)
        return 2

    path = sys.argv[1]
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read()

    block = (
        "\t#ifdef CONFIG_KSU_SUSFS_SUS_MAP\n"
        "\tif (vma->vm_file) {\n"
        "\t\tif (SUSFS_IS_INODE_SUS_MAP(file_inode(vma->vm_file)))\n"
        "\t\t\treturn 0;\n"
        "\t}\n"
        "\t#endif // #ifdef CONFIG_KSU_SUSFS_SUS_MAP\n"
    )

    pattern = re.compile(
        r"[ \t]*#ifdef CONFIG_KSU_SUSFS_SUS_MAP[ \t]*\r?\n"
        r"[ \t]*if \(vma->vm_file\) \{[ \t]*\r?\n"
        r"[ \t]*if \(SUSFS_IS_INODE_SUS_MAP\(file_inode\(vma->vm_file\)\)\)[ \t]*\r?\n"
        r"[ \t]*return 0;[ \t]*\r?\n"
        r"[ \t]*\}[ \t]*\r?\n"
        r"[ \t]*#endif[^\r\n]*\r?\n"
    )
    text = pattern.sub("", text)

    m = re.search(r"static int show_smap\(struct seq_file \*m, void \*v\)[ \t]*\r?\n\{", text)
    if not m:
        print("ERROR: show_smap() not found", file=sys.stderr)
        return 1

    pos = text.find("\n\tif (!vma_data_pages(vma))", m.end())
    if pos < 0:
        pos = text.find("\n\tif (!vma", m.end())
    if pos < 0:
        print("ERROR: show_smap() insertion point not found", file=sys.stderr)
        return 1

    text = text[: pos + 1] + block + text[pos + 1 :]

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)

    print(f"fixed SUSFS SUS_MAP placement in {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
