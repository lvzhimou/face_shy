#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 FaceShy.xcodeproj/project.pbxproj

用法（在 FaceShy/ 目录下）：
    python3 tools/generate_xcodeproj.py

特点：
- 自动扫描 FaceShy/ 目录下所有 .swift 与 .xcassets，无需手动维护文件列表
- 新增 / 删除源文件后重新运行本脚本，即可刷新 Xcode 工程
- 生成的是标准 Xcode 工程（objectVersion 56），Xcode 14 / 15 / 16 均可直接打开
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_ROOT_NAME = "FaceShy"                      # 源码目录名（也是 target 名）
SRC_ROOT = os.path.join(ROOT, SRC_ROOT_NAME)
PROJECT_NAME = "FaceShy"
BUNDLE_ID = "com.faceshy.app"
DEPLOYMENT_TARGET = "16.0"
SWIFT_VERSION = "5.0"
MARKETING_VERSION = "1.0.0"
INFO_PLIST = "FaceShy/Resources/Info.plist"


class UUIDGen:
    """生成 24 位大写十六进制 UUID（pbxproj 要求）"""

    def __init__(self):
        self.counter = 0

    def next(self):
        self.counter += 1
        return "FACEB00C%016X" % self.counter


def collect_files():
    """返回 (swift 相对路径列表, 资源相对路径列表, info.plist 相对路径)"""
    swift_files = []
    assets = []

    for dirpath, dirnames, filenames in os.walk(SRC_ROOT):
        dirnames.sort()
        # .xcassets 是目录，不递归进去
        for d in list(dirnames):
            if d.endswith(".xcassets"):
                rel = os.path.relpath(os.path.join(dirpath, d), ROOT).replace("\\", "/")
                assets.append(rel)
                dirnames.remove(d)
        for f in sorted(filenames):
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(dirpath, f), ROOT).replace("\\", "/")
                swift_files.append(rel)

    swift_files.sort()
    assets.sort()
    return swift_files, assets


def build_group_tree(entries):
    """entries: [(相对路径, fileRefUUID)] -> 嵌套 dict"""
    tree = {}
    for rel_path, uuid in entries:
        parts = rel_path.split("/")[1:]              # 去掉最外层 FaceShy/
        node = tree
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node.setdefault("__files__", []).append((parts[-1], uuid))
    return tree


def main():
    swift_files, assets = collect_files()
    gen = UUIDGen()

    # ---------- 文件引用 ----------
    file_refs = {}          # rel_path -> uuid
    for path in swift_files:
        file_refs[path] = gen.next()
    for path in assets:
        file_refs[path] = gen.next()
    info_plist_ref = gen.next()

    # ---------- 编译 / 资源构建条目 ----------
    build_files = {}
    sources_refs = []
    resources_refs = []
    for path in swift_files:
        uid = gen.next()
        build_files[path] = uid
        sources_refs.append((uid, path))
    for path in assets:
        uid = gen.next()
        build_files[path] = uid
        resources_refs.append((uid, path))

    # 已存在的 Info.plist 之外，扫描到的其余资源
    out = []
    w = out.append

    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")

    # ================= PBXBuildFile =================
    w("")
    w("/* Begin PBXBuildFile section */")
    for path in swift_files:
        name = os.path.basename(path)
        w("\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
          % (build_files[path], name, file_refs[path], name))
    for path in assets:
        name = os.path.basename(path)
        w("\t\t%s /* %s in Resources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
          % (build_files[path], name, file_refs[path], name))
    w("/* End PBXBuildFile section */")

    # ================= PBXFileReference =================
    w("")
    w("/* Begin PBXFileReference section */")
    app_product_ref = gen.next()
    w("\t\t%s /* %s.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; "
      "includeInIndex = 0; path = %s.app; sourceTree = BUILT_PRODUCTS_DIR; };"
      % (app_product_ref, PROJECT_NAME, PROJECT_NAME))
    for path in swift_files:
        name = os.path.basename(path)
        w("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
          "path = %s; sourceTree = \"<group>\"; };" % (file_refs[path], name, name))
    for path in assets:
        name = os.path.basename(path)
        w("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
          "path = %s; sourceTree = \"<group>\"; };" % (file_refs[path], name, name))
    w("\t\t%s /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
      "path = Info.plist; sourceTree = \"<group>\"; };" % info_plist_ref)
    w("/* End PBXFileReference section */")

    # ================= PBXFrameworksBuildPhase =================
    frameworks_phase = gen.next()
    w("")
    w("/* Begin PBXFrameworksBuildPhase section */")
    w("\t\t%s /* Frameworks */ = {" % frameworks_phase)
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXFrameworksBuildPhase section */")

    # ================= PBXGroup =================
    # 先建整棵树，需要递归生成 uuid
    entries = [(p, file_refs[p]) for p in swift_files]
    entries += [(p, file_refs[p]) for p in assets]
    tree = build_group_tree(entries)
    # Info.plist 挂到 Resources 分组
    tree.setdefault("Resources", {}).setdefault("__files__", []).append(("Info.plist", info_plist_ref))

    group_chunks = []

    def emit_group(name, node, path_prefix, is_root_group):
        uid = gen.next()
        children_uuids = []

        for key in sorted(k for k in node.keys() if not k.startswith("__")):
            sub_uid = emit_group(key, node[key], "%s/%s" % (path_prefix, key), False)
            children_uuids.append("%s /* %s */" % (sub_uid, key))

        for fname, fref in sorted(node.get("__files__", []), key=lambda x: x[0]):
            children_uuids.append("%s /* %s */" % (fref, fname))

        lines = []
        lines.append("\t\t%s /* %s */ = {" % (uid, name))
        lines.append("\t\t\tisa = PBXGroup;")
        lines.append("\t\t\tchildren = (")
        for c in children_uuids:
            lines.append("\t\t\t\t%s," % c)
        lines.append("\t\t\t);")
        if is_root_group:
            lines.append("\t\t\tpath = %s;" % SRC_ROOT_NAME)
        else:
            lines.append("\t\t\tpath = %s;" % name)
        lines.append("\t\t\tsourceTree = \"<group>\";")
        lines.append("\t\t};")
        group_chunks.append("\n".join(lines))
        return uid

    source_group_uid = emit_group(SRC_ROOT_NAME, tree, SRC_ROOT_NAME, True)

    # Products 分组
    products_group_uid = gen.next()
    group_chunks.append("\n".join([
        "\t\t%s /* Products */ = {" % products_group_uid,
        "\t\t\tisa = PBXGroup;",
        "\t\t\tchildren = (",
        "\t\t\t\t%s /* %s.app */," % (app_product_ref, PROJECT_NAME),
        "\t\t\t);",
        "\t\t\tname = Products;",
        "\t\t\tsourceTree = \"<group>\";",
        "\t\t};",
    ]))

    # 根分组
    main_group_uid = gen.next()
    group_chunks.append("\n".join([
        "\t\t%s = {" % main_group_uid,
        "\t\t\tisa = PBXGroup;",
        "\t\t\tchildren = (",
        "\t\t\t\t%s /* %s */," % (source_group_uid, SRC_ROOT_NAME),
        "\t\t\t\t%s /* Products */," % products_group_uid,
        "\t\t\t);",
        "\t\t\tsourceTree = \"<group>\";",
        "\t\t};",
    ]))

    w("")
    w("/* Begin PBXGroup section */")
    for chunk in group_chunks:
        w(chunk)
    w("/* End PBXGroup section */")

    # ================= PBXNativeTarget =================
    target_uid = gen.next()
    sources_phase = gen.next()
    resources_phase = gen.next()
    cfg_list_target = gen.next()
    w("")
    w("/* Begin PBXNativeTarget section */")
    w("\t\t%s /* %s */ = {" % (target_uid, PROJECT_NAME))
    w("\t\t\tisa = PBXNativeTarget;")
    w("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"%s\" */;" % (cfg_list_target, PROJECT_NAME))
    w("\t\t\tbuildPhases = (")
    w("\t\t\t\t%s /* Sources */," % sources_phase)
    w("\t\t\t\t%s /* Frameworks */," % frameworks_phase)
    w("\t\t\t\t%s /* Resources */," % resources_phase)
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w("\t\t\tname = %s;" % PROJECT_NAME)
    w("\t\t\tproductName = %s;" % PROJECT_NAME)
    w("\t\t\tproductReference = %s /* %s.app */;" % (app_product_ref, PROJECT_NAME))
    w("\t\t\tproductType = \"com.apple.product-type.application\";")
    w("\t\t};")
    w("/* End PBXNativeTarget section */")

    # ================= PBXProject =================
    project_uid = gen.next()
    cfg_list_project = gen.next()
    w("")
    w("/* Begin PBXProject section */")
    w("\t\t%s /* Project object */ = {" % project_uid)
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    w("\t\t\t\tLastUpgradeCheck = 1500;")
    w("\t\t\t\tTargetAttributes = {")
    w("\t\t\t\t\t%s = {" % target_uid)
    w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    w("\t\t\t\t\t};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject \"%s\" */;" % (cfg_list_project, PROJECT_NAME))
    w("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    w("\t\t\tdevelopmentRegion = \"zh-Hans\";")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (")
    w("\t\t\t\t\"zh-Hans\",")
    w("\t\t\t\ten,")
    w("\t\t\t\tBase,")
    w("\t\t\t);")
    w("\t\t\tmainGroup = %s;" % main_group_uid)
    w("\t\t\tproductRefGroup = %s /* Products */;" % products_group_uid)
    w("\t\t\tprojectDirPath = \"\";")
    w("\t\t\tprojectRoot = \"\";")
    w("\t\t\ttargets = (")
    w("\t\t\t\t%s /* %s */," % (target_uid, PROJECT_NAME))
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")

    # ================= PBXResourcesBuildPhase =================
    w("")
    w("/* Begin PBXResourcesBuildPhase section */")
    w("\t\t%s /* Resources */ = {" % resources_phase)
    w("\t\t\tisa = PBXResourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for uid, path in resources_refs:
        w("\t\t\t\t%s /* %s in Resources */," % (uid, os.path.basename(path)))
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXResourcesBuildPhase section */")

    # ================= PBXSourcesBuildPhase =================
    w("")
    w("/* Begin PBXSourcesBuildPhase section */")
    w("\t\t%s /* Sources */ = {" % sources_phase)
    w("\t\t\tisa = PBXSourcesBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    for uid, path in sources_refs:
        w("\t\t\t\t%s /* %s in Sources */," % (uid, os.path.basename(path)))
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXSourcesBuildPhase section */")

    # ================= XCBuildConfiguration =================
    common_project_settings = [
        "ALWAYS_SEARCH_USER_PATHS = NO;",
        "CLANG_ANALYZER_NONNULL = YES;",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
        "CLANG_ENABLE_MODULES = YES;",
        "CLANG_ENABLE_OBJC_ARC = YES;",
        "CLANG_ENABLE_OBJC_WEAK = YES;",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;",
        "CLANG_WARN_BOOL_CONVERSION = YES;",
        "CLANG_WARN_COMMA = YES;",
        "CLANG_WARN_CONSTANT_CONVERSION = YES;",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
        "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
        "CLANG_WARN_EMPTY_BODY = YES;",
        "CLANG_WARN_ENUM_CONVERSION = YES;",
        "CLANG_WARN_INFINITE_RECURSION = YES;",
        "CLANG_WARN_INT_CONVERSION = YES;",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
        "CLANG_WARN_STRICT_PROTOTYPES = YES;",
        "CLANG_WARN_SUSPICIOUS_MOVE = YES;",
        "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
        "CLANG_WARN_UNREACHABLE_CODE = YES;",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
        "COPY_PHASE_STRIP = NO;",
        "ENABLE_STRICT_OBJC_MSGSEND = YES;",
        "GCC_C_LANGUAGE_STANDARD = gnu17;",
        "GCC_NO_COMMON_BLOCKS = YES;",
        "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
        "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
        "GCC_WARN_UNDECLARED_SELECTOR = YES;",
        "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
        "GCC_WARN_UNUSED_FUNCTION = YES;",
        "GCC_WARN_UNUSED_VARIABLE = YES;",
        "IPHONEOS_DEPLOYMENT_TARGET = %s;" % DEPLOYMENT_TARGET,
        "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;",
        "MTL_FAST_MATH = YES;",
        "SDKROOT = iphoneos;",
    ]

    debug_only = [
        "DEBUG_INFORMATION_FORMAT = dwarf;",
        "ENABLE_TESTABILITY = YES;",
        "GCC_DYNAMIC_NO_PIC = NO;",
        "GCC_OPTIMIZATION_LEVEL = 0;",
        "GCC_PREPROCESSOR_DEFINITIONS = (",
        "\t\t\t\t\t\"DEBUG=1\",",
        "\t\t\t\t\t\"$(inherited)\",",
        "\t\t\t\t);",
        "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;",
        "ONLY_ACTIVE_ARCH = YES;",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";",
        "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
    ]

    release_only = [
        "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
        "ENABLE_NS_ASSERTIONS = NO;",
        "MTL_ENABLE_DEBUG_INFO = NO;",
        "SWIFT_COMPILATION_MODE = wholemodule;",
        "SWIFT_OPTIMIZATION_LEVEL = \"-O\";",
        "VALIDATE_PRODUCT = YES;",
    ]

    target_settings = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
        "CODE_SIGN_STYLE = Automatic;",
        "CURRENT_PROJECT_VERSION = 1;",
        "ENABLE_PREVIEWS = YES;",
        "GENERATE_INFOPLIST_FILE = NO;",
        "INFOPLIST_FILE = \"%s\";" % INFO_PLIST,
        "LD_RUNPATH_SEARCH_PATHS = (",
        "\t\t\t\t\t\"$(inherited)\",",
        "\t\t\t\t\t\"@executable_path/Frameworks\",",
        "\t\t\t\t);",
        "MARKETING_VERSION = %s;" % MARKETING_VERSION,
        "PRODUCT_BUNDLE_IDENTIFIER = %s;" % BUNDLE_ID,
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        "SWIFT_VERSION = %s;" % SWIFT_VERSION,
        "TARGETED_DEVICE_FAMILY = 1;",
    ]

    def emit_config(uid, name, settings):
        w("\t\t%s /* %s */ = {" % (uid, name))
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        for line in settings:
            if line.startswith("\t"):
                w(line)
            else:
                w("\t\t\t\t%s" % line)
        w("\t\t\t};")
        w("\t\t\tname = %s;" % name)
        w("\t\t};")

    w("")
    w("/* Begin XCBuildConfiguration section */")
    proj_debug = gen.next()
    proj_release = gen.next()
    tgt_debug = gen.next()
    tgt_release = gen.next()

    emit_config(proj_debug, "Debug", common_project_settings + debug_only)
    emit_config(proj_release, "Release", common_project_settings + release_only)
    emit_config(tgt_debug, "Debug", target_settings)
    emit_config(tgt_release, "Release", target_settings)
    w("/* End XCBuildConfiguration section */")

    # ================= XCConfigurationList =================
    w("")
    w("/* Begin XCConfigurationList section */")
    w("\t\t%s /* Build configuration list for PBXProject \"%s\" */ = {" % (cfg_list_project, PROJECT_NAME))
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w("\t\t\t\t%s /* Debug */," % proj_debug)
    w("\t\t\t\t%s /* Release */," % proj_release)
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w("\t\t%s /* Build configuration list for PBXNativeTarget \"%s\" */ = {" % (cfg_list_target, PROJECT_NAME))
    w("\t\t\tisa = XCConfigurationList;")
    w("\t\t\tbuildConfigurations = (")
    w("\t\t\t\t%s /* Debug */," % tgt_debug)
    w("\t\t\t\t%s /* Release */," % tgt_release)
    w("\t\t\t);")
    w("\t\t\tdefaultConfigurationIsVisible = 0;")
    w("\t\t\tdefaultConfigurationName = Release;")
    w("\t\t};")
    w("/* End XCConfigurationList section */")

    w("\t};")
    w("\trootObject = %s /* Project object */;" % project_uid)
    w("}")

    # ---------- 写出 ----------
    project_dir = os.path.join(ROOT, "%s.xcodeproj" % PROJECT_NAME)
    os.makedirs(project_dir, exist_ok=True)
    pbxproj_path = os.path.join(project_dir, "project.pbxproj")
    with open(pbxproj_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")

    print("已生成: %s" % pbxproj_path)
    print("Swift 源文件: %d 个" % len(swift_files))
    for p in swift_files:
        print("   - %s" % p)
    print("资源: %s" % ", ".join(assets))


if __name__ == "__main__":
    main()
