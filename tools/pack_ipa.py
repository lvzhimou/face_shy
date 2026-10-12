#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
IPA 打包 / 校验工具（跨平台，Windows 也能跑）

用途一：把 .app 打包成未签名 .ipa（当你在别处拿到了 .app，或想在本地重新打包时）
    python3 tools/pack_ipa.py /path/to/FaceShy.app
    python3 tools/pack_ipa.py /path/to/FaceShy.app -o dist/FaceShy-unsigned.ipa

用途二：校验 IPA 是否符合 iOS 安装包规范（强烈建议自签前跑一遍）
    python3 tools/pack_ipa.py --verify build/FaceShy-unsigned.ipa

校验内容：
    - 顶层目录必须是 Payload/
    - Payload 下有且只有一个 .app
    - .app 内有 Info.plist，且能解析出 CFBundleIdentifier / CFBundleExecutable / CFBundleShortVersionString
    - CFBundleExecutable 指向的二进制文件真实存在
    - 是否已签名（有无 _CodeSignature/），未签名不影响自签工具使用
    - 主二进制的架构（可执行文件为 Mach-O 时读取）

注意：Windows 文件系统不保存 Unix 权限位，在 Windows 上重新打包可能丢失
      可执行权限（0755）。首选在 macOS 上打包；本工具会尽量还原权限位。
"""

import argparse
import os
import plistlib
import shutil
import stat
import struct
import sys
import zipfile

DEFAULT_IPA_NAME = "FaceShy-unsigned.ipa"


# ------------------------------------------------------------------ 工具函数
def human_size(num_bytes):
    for unit in ("B", "KB", "MB", "GB"):
        if num_bytes < 1024 or unit == "GB":
            return "%.1f %s" % (num_bytes, unit)
        num_bytes /= 1024.0


def macho_architectures(data):
    """从 Mach-O 头部读出架构列表，失败返回 []"""
    magic = data[:4]
    if magic in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe"):          # 32/64 位小端
        cputype = struct.unpack("<I", data[4:8])[0]
        names = {7: "i386", 12: "arm", 0x01000007: "x86_64", 0x0100000C: "arm64"}
        return [names.get(cputype, hex(cputype))]
    if magic in (b"\xfe\xed\xfa\xcf", b"\xfe\xed\xfa\xce"):          # 大端
        cputype = struct.unpack(">I", data[4:8])[0]
        names = {7: "i386", 12: "arm", 0x01000007: "x86_64", 0x0100000C: "arm64"}
        return [names.get(cputype, hex(cputype))]
    if magic == b"\xca\xfe\xba\xbe":                                 # Fat / Universal
        count = struct.unpack(">I", data[4:8])[0]
        names = {7: "i386", 12: "arm", 0x01000007: "x86_64", 0x0100000C: "arm64"}
        result = []
        for i in range(min(count, 8)):
            offset = 8 + i * 20
            cputype = struct.unpack(">I", data[offset:offset + 4])[0]
            result.append(names.get(cputype, hex(cputype)))
        return result
    return []


# ------------------------------------------------------------------ 校验
def verify_ipa(ipa_path):
    print("检查文件：%s" % ipa_path)
    if not os.path.isfile(ipa_path):
        print("  ❌ 文件不存在")
        return 1

    size = os.path.getsize(ipa_path)
    print("  文件大小：%s" % human_size(size))

    problems = []
    warnings = []

    with zipfile.ZipFile(ipa_path) as zf:
        names = zf.namelist()
        if not names:
            print("  ❌ 空压缩包")
            return 1

        # 1) 顶层目录
        tops = sorted({n.split("/")[0] for n in names})
        if "Payload" not in tops:
            problems.append("顶层没有 Payload/ 目录（iOS 安装包必须是 Payload/xxx.app 结构）")
        extra = [t for t in tops if t not in ("Payload", "__MACOSX")]
        if extra:
            warnings.append("包含多余顶层目录：%s（一般无碍，但部分工具会报错）" % ", ".join(extra))

        # 2) Payload 下的 .app
        app_dirs = sorted({n.split("/")[1] for n in names
                           if n.startswith("Payload/") and len(n.split("/")) > 1 and n.split("/")[1].endswith(".app")})
        if not app_dirs:
            problems.append("Payload/ 下没有 .app")
            app_name = None
        else:
            app_name = app_dirs[0]
            if len(app_dirs) > 1:
                problems.append("Payload/ 下有多个 .app：%s（只允许一个）" % ", ".join(app_dirs))
            print("  App 名称：%s" % app_name)

        if app_name:
            prefix = "Payload/%s/" % app_name

            # 3) Info.plist
            info_entry = prefix + "Info.plist"
            if info_entry not in names:
                problems.append("缺少 Info.plist")
                info = {}
            else:
                try:
                    with zf.open(info_entry) as f:
                        info = plistlib.load(f)
                    print("  Bundle ID：%s" % info.get("CFBundleIdentifier", "(缺失)"))
                    print("  版本：%s (build %s)" % (info.get("CFBundleShortVersionString", "-"),
                                                   info.get("CFBundleVersion", "-")))
                    print("  显示名：%s" % info.get("CFBundleDisplayName", info.get("CFBundleName", "-")))
                    print("  最低系统：%s" % info.get("MinimumOSVersion", "(未声明)"))
                except Exception as exc:
                    problems.append("Info.plist 解析失败：%s" % exc)
                    info = {}

            # 4) 可执行文件
            executable = info.get("CFBundleExecutable")
            if executable:
                exe_entry = prefix + executable
                if exe_entry not in names:
                    problems.append("Info.plist 里声明的可执行文件缺失：%s" % executable)
                else:
                    entry_info = zf.getinfo(exe_entry)
                    mode = entry_info.external_attr >> 16
                    if mode and not (mode & stat.S_IXUSR):
                        warnings.append("可执行文件没有 x 权限位（mode=%o），部分自签工具会因此失败，"
                                        "建议改用 macOS 上的 build_ipa.sh 打包" % mode)
                    with zf.open(exe_entry) as f:
                        header = f.read(4096)
                    archs = macho_architectures(header)
                    if archs:
                        print("  二进制架构：%s" % ", ".join(archs))
                        if "arm64" not in archs:
                            problems.append("二进制不包含 arm64，真机无法安装（当前：%s）" % ", ".join(archs))
                    else:
                        warnings.append("无法识别可执行文件格式（可能不是 Mach-O）")
            else:
                problems.append("Info.plist 里没有 CFBundleExecutable")

            # 5) 签名状态
            signed = any(n.startswith(prefix + "_CodeSignature/") for n in names)
            has_provision = (prefix + "embedded.mobileprovision") in names
            print("  签名状态：%s" % ("已签名" if signed else "未签名（自签工具会重新签名，可正常使用）"))
            if has_provision:
                print("  描述文件：包含 embedded.mobileprovision")
            if signed:
                warnings.append("包内已存在签名，自签工具重签前可能要求先去签名")

    print()
    for w in warnings:
        print("  ⚠️  %s" % w)
    if problems:
        for p in problems:
            print("  ❌ %s" % p)
        print("\n结论：IPA 结构有问题，需要修复后再自签")
        return 1

    print("  ✅ 结构校验通过，可以直接交给自签工具使用")
    return 0


# ------------------------------------------------------------------ 打包
def iter_app_files(app_dir):
    for root, dirs, files in os.walk(app_dir):
        dirs.sort()
        for name in sorted(files):
            yield os.path.join(root, name)


def pack_ipa(app_path, output=None):
    app_path = os.path.abspath(app_path)
    if not os.path.isdir(app_path):
        print("❌ 不是有效的 .app 目录：%s" % app_path)
        return 1
    if not app_path.endswith(".app"):
        print("❌ 路径必须以 .app 结尾：%s" % app_path)
        return 1
    if not os.path.isfile(os.path.join(app_path, "Info.plist")):
        print("❌ 目录里没有 Info.plist，不像是 iOS App 包：%s" % app_path)
        return 1

    app_name = os.path.basename(app_path)
    output = output or os.path.join(os.getcwd(), DEFAULT_IPA_NAME)
    output = os.path.abspath(output)
    os.makedirs(os.path.dirname(output), exist_ok=True)

    symlinks = 0
    print("打包：%s" % app_name)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for file_path in iter_app_files(app_path):
            rel = os.path.relpath(file_path, os.path.dirname(app_path))
            # IPA 规范：压缩包内必须是 Payload/xxx.app/...
            arc_name = "Payload/" + rel.replace(os.sep, "/")
            if os.path.islink(file_path):
                symlinks += 1
                continue  # 纯 Python 写符号链接在 Windows 上不可靠，交由自签工具重建
            st = os.stat(file_path)
            info = zipfile.ZipInfo.from_file(file_path, arc_name)
            info.external_attr = (st.st_mode & 0xFFFF) << 16   # 保留 Unix 权限位
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(file_path, "rb") as src, zf.open(info, "w") as dst:
                shutil.copyfileobj(src, dst)

    print("  ✅ 已生成：%s（%s）" % (output, human_size(os.path.getsize(output))))
    if symlinks:
        print("  ⚠️  跳过了 %d 个符号链接，若 App 内含 Framework 请务必改用 macOS 打包" % symlinks)
    print()
    return verify_ipa(output)


# ------------------------------------------------------------------ 入口
def main():
    parser = argparse.ArgumentParser(
        description="IPA 打包 / 校验工具（跨平台）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="示例：\n"
               "  python3 tools/pack_ipa.py build/DerivedData/Build/Products/Release-iphoneos/FaceShy.app\n"
               "  python3 tools/pack_ipa.py --verify build/FaceShy-unsigned.ipa\n")
    parser.add_argument("target", nargs="?", help="要打包的 .app 目录，或配合 --verify 指定 .ipa 文件")
    parser.add_argument("-o", "--output", help="输出 IPA 路径（默认当前目录/%s）" % DEFAULT_IPA_NAME)
    parser.add_argument("--verify", action="store_true", help="只校验，不打包（target 传 .ipa 文件）")
    args = parser.parse_args()

    if not args.target:
        parser.print_help()
        return 2

    if args.verify:
        return verify_ipa(args.target)
    return pack_ipa(args.target, args.output)


if __name__ == "__main__":
    sys.exit(main())
