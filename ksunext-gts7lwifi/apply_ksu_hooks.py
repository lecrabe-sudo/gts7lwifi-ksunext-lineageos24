#!/usr/bin/env python3
"""Integrate KernelSU-Next (legacy branch, manual hooks) into LineageOS sm8250 4.19."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class InsertionRule:
    """Represents a single idempotent text insertion rule."""

    marker: str
    anchor: str
    replacement: str
    count: int = 1


def apply_rules(path: Path, rules: list[InsertionRule]) -> None:
    """Apply ordered insertion rules to a source file, failing if an anchor is missing."""
    content = path.read_text(encoding="utf-8")
    original = content
    for rule in rules:
        if rule.marker in content:
            continue
        occurrences = content.count(rule.anchor)
        if occurrences != rule.count:
            raise RuntimeError(
                f"{path}: expected {rule.count} occurrence(s) of anchor "
                f"{rule.anchor!r}, found {occurrences}"
            )
        content = content.replace(rule.anchor, rule.replacement, 1)

    if content != original:
        path.write_text(content, encoding="utf-8")


def setup_kernelsu_tree(kernel_dir: Path, ksu_dir: Path) -> None:
    """Wire drivers/kernelsu into Kbuild/Kconfig and relax -Werror for KSU under Clang 22."""
    drivers_ksu = kernel_dir / "drivers" / "kernelsu"
    target = ksu_dir / "kernel"
    if not (target / "Kbuild").is_file():
        raise RuntimeError(f"KernelSU-Next kernel directory not found at {target}")

    if drivers_ksu.is_symlink() or drivers_ksu.exists():
        if drivers_ksu.is_symlink():
            drivers_ksu.unlink()
        else:
            raise RuntimeError(f"{drivers_ksu} already exists as non-symlink")
    try:
        rel_target = target.resolve().relative_to(kernel_dir.resolve())
        drivers_ksu.symlink_to(Path("..") / rel_target)
    except ValueError:
        drivers_ksu.symlink_to(target.resolve())

    apply_rules(
        kernel_dir / "drivers" / "Kconfig",
        [
            InsertionRule(
                marker='source "drivers/kernelsu/Kconfig"',
                anchor='source "drivers/spu_verify/Kconfig"\nendmenu',
                replacement=(
                    'source "drivers/spu_verify/Kconfig"\n\n'
                    'source "drivers/kernelsu/Kconfig"\nendmenu'
                ),
            )
        ],
    )

    apply_rules(
        kernel_dir / "drivers" / "Makefile",
        [
            InsertionRule(
                marker="obj-$(CONFIG_KSU)",
                anchor="obj-$(CONFIG_SPU_VERIFY) += spu_verify/",
                replacement=(
                    "obj-$(CONFIG_SPU_VERIFY) += spu_verify/\n"
                    "obj-$(CONFIG_KSU) += kernelsu/"
                ),
            )
        ],
    )

    # LineageOS 24.0 enables CONFIG_CC_WERROR=y with Clang 22 while KernelSU-Next
    # uses C99 declarations after statements; suppress -Werror only in KSU.
    kbuild_path = target / "Kbuild"
    kbuild_text = kbuild_path.read_text(encoding="utf-8")
    warning_guard = "# KSU_SM8250_CLANG_WARN_FLAGS"
    if warning_guard not in kbuild_text:
        addition = (
            f"\n{warning_guard}\n"
            "ccflags-y += -Wno-error -Wno-declaration-after-statement "
            "-Wno-unused-function -Wno-unused-variable\n"
            "subdir-ccflags-y += -Wno-error -Wno-declaration-after-statement "
            "-Wno-unused-function -Wno-unused-variable\n"
        )
        kbuild_path.write_text(kbuild_text + addition, encoding="utf-8")


def apply_manual_hooks(kernel_dir: Path) -> None:
    """Patch the 6 KernelSU-Next legacy manual hook sites in sm8250 4.19."""
    hooks: dict[str, list[InsertionRule]] = {
        "kernel/reboot.c": [
            InsertionRule(
                marker="extern int ksu_handle_sys_reboot(",
                anchor="SYSCALL_DEFINE4(reboot, int, magic1, int, magic2, unsigned int, cmd,",
                replacement=(
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "extern int ksu_handle_sys_reboot(int magic1, int magic2, "
                    "unsigned int cmd, void __user **arg);\n"
                    "#endif\n\n"
                    "SYSCALL_DEFINE4(reboot, int, magic1, int, magic2, unsigned int, cmd,"
                ),
            ),
            InsertionRule(
                marker="ksu_handle_sys_reboot(magic1, magic2, cmd, &arg);",
                anchor="\tint ret = 0;\n\n\t/* We only trust the superuser with rebooting the system. */",
                replacement=(
                    "\tint ret = 0;\n\n"
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\n"
                    "#endif\n\n"
                    "\t/* We only trust the superuser with rebooting the system. */"
                ),
            ),
        ],
        "fs/exec.c": [
            InsertionRule(
                marker="extern int ksu_handle_execveat(",
                anchor="static int do_execveat_common(int fd, struct filename *filename,",
                replacement=(
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr, "
                    "void *argv, void *envp, int *flags);\n"
                    "#endif\n\n"
                    "static int do_execveat_common(int fd, struct filename *filename,"
                ),
            ),
            InsertionRule(
                marker="ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);",
                anchor="\treturn __do_execve_file(fd, filename, argv, envp, flags, NULL);",
                replacement=(
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "\tksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);\n"
                    "#endif\n"
                    "\treturn __do_execve_file(fd, filename, argv, envp, flags, NULL);"
                ),
            ),
        ],
        "fs/open.c": [
            InsertionRule(
                marker="extern int ksu_handle_faccessat(",
                anchor="long do_faccessat(int dfd, const char __user *filename, int mode)",
                replacement=(
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user, "
                    "int *mode, int *flags);\n"
                    "#endif\n\n"
                    "long do_faccessat(int dfd, const char __user *filename, int mode)"
                ),
            ),
            InsertionRule(
                marker="ksu_handle_faccessat(&dfd, &filename, &mode, NULL);",
                anchor="\tunsigned int lookup_flags = LOOKUP_FOLLOW;\n\n\tif (mode & ~S_IRWXO)",
                replacement=(
                    "\tunsigned int lookup_flags = LOOKUP_FOLLOW;\n\n"
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n"
                    "#endif\n\n"
                    "\tif (mode & ~S_IRWXO)"
                ),
            ),
        ],
        "fs/read_write.c": [
            InsertionRule(
                marker="extern int ksu_handle_vfs_read(",
                anchor="ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)",
                replacement=(
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "extern int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr, "
                    "size_t *count_ptr, loff_t **pos);\n"
                    "#endif\n\n"
                    "ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)"
                ),
            ),
            InsertionRule(
                marker="ksu_handle_vfs_read(&file, &buf, &count, &pos);",
                anchor=(
                    "ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)\n"
                    "{\n\tssize_t ret;\n\n\tif (!(file->f_mode & FMODE_READ))"
                ),
                replacement=(
                    "ssize_t vfs_read(struct file *file, char __user *buf, size_t count, loff_t *pos)\n"
                    "{\n\tssize_t ret;\n\n"
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "\tksu_handle_vfs_read(&file, &buf, &count, &pos);\n"
                    "#endif\n\n"
                    "\tif (!(file->f_mode & FMODE_READ))"
                ),
            ),
        ],
        "fs/stat.c": [
            InsertionRule(
                marker="extern int ksu_handle_stat(",
                anchor="int vfs_statx(int dfd, const char __user *filename, int flags,",
                replacement=(
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "extern int ksu_handle_stat(int *dfd, const char __user **filename_user, int *flags);\n"
                    "#endif\n\n"
                    "int vfs_statx(int dfd, const char __user *filename, int flags,"
                ),
            ),
            InsertionRule(
                marker="ksu_handle_stat(&dfd, &filename, &flags);",
                anchor="\tunsigned int lookup_flags = LOOKUP_FOLLOW | LOOKUP_AUTOMOUNT;\n\n\tif ((flags &",
                replacement=(
                    "\tunsigned int lookup_flags = LOOKUP_FOLLOW | LOOKUP_AUTOMOUNT;\n\n"
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "\tksu_handle_stat(&dfd, &filename, &flags);\n"
                    "#endif\n\n"
                    "\tif ((flags &"
                ),
            ),
        ],
        "drivers/input/input.c": [
            InsertionRule(
                marker="extern int ksu_handle_input_handle_event(",
                anchor="static void input_handle_event(struct input_dev *dev,",
                replacement=(
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "extern int ksu_handle_input_handle_event(unsigned int *type, "
                    "unsigned int *code, int *value);\n"
                    "#endif\n\n"
                    "static void input_handle_event(struct input_dev *dev,"
                ),
            ),
            InsertionRule(
                marker="ksu_handle_input_handle_event(&type, &code, &value);",
                anchor="\tint disposition = input_get_disposition(dev, type, code, &value);\n\n\tif (disposition !=",
                replacement=(
                    "\tint disposition = input_get_disposition(dev, type, code, &value);\n\n"
                    "#ifdef CONFIG_KSU_MANUAL_HOOK\n"
                    "\tksu_handle_input_handle_event(&type, &code, &value);\n"
                    "#endif\n\n"
                    "\tif (disposition !="
                ),
            ),
        ],
    }

    for rel_path, rules in hooks.items():
        apply_rules(kernel_dir / rel_path, rules)


def apply_prebuild_backports(kernel_dir: Path) -> None:
    """Apply KSU-Next 4.19 backports before make starts so parallel builds never race."""
    backports: dict[str, list[InsertionRule]] = {
        "fs/namespace.c": [
            InsertionRule(
                marker="static int can_umount(const struct path *path, int flags)",
                anchor="static bool is_mnt_ns_file(struct dentry *dentry)",
                replacement=(
                    "static int can_umount(const struct path *path, int flags)\n"
                    "{\n"
                    "\tstruct mount *mnt = real_mount(path->mnt);\n\n"
                    "\tif (flags & ~(MNT_FORCE | MNT_DETACH | MNT_EXPIRE | UMOUNT_NOFOLLOW))\n"
                    "\t\treturn -EINVAL;\n"
                    "\tif (!may_mount())\n"
                    "\t\treturn -EPERM;\n"
                    "\tif (path->dentry != path->mnt->mnt_root)\n"
                    "\t\treturn -EINVAL;\n"
                    "\tif (!check_mnt(mnt))\n"
                    "\t\treturn -EINVAL;\n"
                    "\tif (mnt->mnt.mnt_flags & MNT_LOCKED) /* Check optimistically */\n"
                    "\t\treturn -EINVAL;\n"
                    "\tif (flags & MNT_FORCE && !capable(CAP_SYS_ADMIN))\n"
                    "\t\treturn -EPERM;\n"
                    "\treturn 0;\n"
                    "}\n\n"
                    "static bool is_mnt_ns_file(struct dentry *dentry)"
                ),
            ),
            InsertionRule(
                marker="int path_umount(struct path *path, int flags)",
                anchor="static bool is_mnt_ns_file(struct dentry *dentry)",
                replacement=(
                    "int path_umount(struct path *path, int flags)\n"
                    "{\n"
                    "\tstruct mount *mnt = real_mount(path->mnt);\n"
                    "\tint ret;\n\n"
                    "\tret = can_umount(path, flags);\n"
                    "\tif (!ret)\n"
                    "\t\tret = do_umount(mnt, flags);\n\n"
                    "\t/* we mustn't call path_put() as that would clear mnt_expiry_mark */\n"
                    "\tdput(path->dentry);\n"
                    "\tmntput_no_expire(mnt);\n"
                    "\treturn ret;\n"
                    "}\n\n"
                    "static bool is_mnt_ns_file(struct dentry *dentry)"
                ),
            ),
        ],
        "fs/internal.h": [
            InsertionRule(
                marker="int path_umount(struct path *path, int flags);",
                anchor="extern void __init mnt_init(void);",
                replacement=(
                    "extern void __init mnt_init(void);\n"
                    "int path_umount(struct path *path, int flags);"
                ),
            ),
        ],
        "include/linux/seccomp.h": [
            InsertionRule(
                marker="#include <linux/atomic.h>",
                anchor="#include <linux/thread_info.h>",
                replacement="#include <linux/thread_info.h>\n#include <linux/atomic.h>",
            ),
            InsertionRule(
                marker="atomic_t filter_count;",
                anchor="struct seccomp {\n\tint mode;",
                replacement="struct seccomp {\n\tint mode;\n\tatomic_t filter_count;",
            ),
        ],
    }

    for rel_path, rules in backports.items():
        apply_rules(kernel_dir / rel_path, rules)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kernel-dir", type=Path, required=True)
    parser.add_argument("--ksu-dir", type=Path, default=None)
    parser.add_argument(
        "--hooks-only",
        action="store_true",
        help="Only patch the 6 manual kernel hooks (skip drivers/kernelsu wiring).",
    )
    args = parser.parse_args()

    if not args.hooks_only:
        if args.ksu_dir is None:
            raise SystemExit("--ksu-dir is required unless --hooks-only is set")
        setup_kernelsu_tree(args.kernel_dir, args.ksu_dir)

    apply_manual_hooks(args.kernel_dir)
    apply_prebuild_backports(args.kernel_dir)
    print("Successfully applied KernelSU-Next integration, backports, and manual hooks.")


if __name__ == "__main__":
    main()
