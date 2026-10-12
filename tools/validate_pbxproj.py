#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
严格校验 project.pbxproj 是否为合法的 OpenStep（old-style）plist。

为什么需要它：
    Apple 的 CFPropertyList 旧式解析器对「非引号字符串」有严格限制——
    只允许字母、数字以及 _ $ / : . - 。
    一旦出现其它字符（例如文件名里的 `+`）而没有用双引号包起来，
    Xcode 会报：
        The project 'Xxx' is damaged and cannot be opened due to a parse error
    而 xcodebuild 同时还会打出一句极具误导性的：
        JSON text did not start with array or object
    真正的原因根本看不出来。本脚本把这类错误在本地就拦下来。

用法（在 FaceShy/ 目录下）：
    python3 tools/validate_pbxproj.py [path/to/project.pbxproj]

退出码：0 = 通过，非 0 = 失败
"""

import os
import sys

DEFAULT_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "FaceShy.xcodeproj", "project.pbxproj",
)

# 与 Apple CFPropertyList 旧式解析器一致的非引号字符集
UNQUOTED_OK = set(
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789_$/:.-"
)
WS = " \t\r\n"
DELIMS = "{}()=;,"


class ParseError(Exception):
    def __init__(self, msg, text, pos):
        self.pos = pos
        line = text.count("\n", 0, pos) + 1
        col = pos - (text.rfind("\n", 0, pos) + 1) + 1
        line_text = text.splitlines()[line - 1] if text.splitlines() else ""
        super().__init__(
            "%s\n  位置: 第 %d 行 第 %d 列\n  该行: %s"
            % (msg, line, col, line_text.rstrip())
        )


class StrictParser:
    """只接受 Apple CFPropertyList 认可语法的 OpenStep plist 解析器。"""

    def __init__(self, text):
        self.t = text
        self.i = 0

    # ---------- 基础 ----------
    def _skip(self):
        while self.i < len(self.t):
            c = self.t[self.i]
            if c in WS:
                self.i += 1
            elif c == "/" and self.t.startswith("/*", self.i):
                end = self.t.find("*/", self.i + 2)
                if end < 0:
                    raise ParseError("块注释 /* 没有闭合", self.t, self.i)
                self.i = end + 2
            elif c == "/" and self.t.startswith("//", self.i):
                end = self.t.find("\n", self.i)
                self.i = len(self.t) if end < 0 else end + 1
            else:
                return

    def parse(self):
        self._skip()
        val = self._value()
        self._skip()
        if self.i != len(self.t):
            raise ParseError("文件结束后还有多余内容", self.t, self.i)
        return val

    def _value(self):
        self._skip()
        if self.i >= len(self.t):
            raise ParseError("内容意外结束", self.t, self.i)
        c = self.t[self.i]
        if c == "{":
            return self._dict()
        if c == "(":
            return self._array()
        if c == '"':
            return self._quoted()
        return self._unquoted()

    def _dict(self):
        self.i += 1  # {
        result = {}
        while True:
            self._skip()
            if self.i >= len(self.t):
                raise ParseError("字典 { 没有闭合", self.t, self.i)
            if self.t[self.i] == "}":
                self.i += 1
                return result
            key = self._value()
            if not isinstance(key, str):
                raise ParseError("字典键必须是字符串", self.t, self.i)
            self._skip()
            if self.i >= len(self.t) or self.t[self.i] != "=":
                got = self.t[self.i] if self.i < len(self.t) else "<EOF>"
                raise ParseError("键 %r 后面应该是 '='，实际是 %r" % (key, got), self.t, self.i)
            self.i += 1
            result[key] = self._value()
            self._skip()
            if self.i >= len(self.t):
                raise ParseError("字典 { 没有闭合", self.t, self.i)
            if self.t[self.i] == "}":
                self.i += 1
                return result
            if self.t[self.i] != ";":
                got = self.t[self.i]
                hint = ""
                if got not in UNQUOTED_OK and got not in DELIMS:
                    hint = "  ← 该字符必须用双引号包裹！"
                raise ParseError(
                    "键 %r 的值后面缺少 ';'，实际遇到 %r%s" % (key, got, hint),
                    self.t, self.i)
            self.i += 1

    def _array(self):
        self.i += 1  # (
        result = []
        while True:
            self._skip()
            if self.i >= len(self.t):
                raise ParseError("数组 ( 没有闭合", self.t, self.i)
            if self.t[self.i] == ")":
                self.i += 1
                return result
            result.append(self._value())
            self._skip()
            if self.i >= len(self.t):
                raise ParseError("数组 ( 没有闭合", self.t, self.i)
            if self.t[self.i] == ")":
                self.i += 1
                return result
            if self.t[self.i] != ",":
                raise ParseError("数组元素后面缺少 ','", self.t, self.i)
            self.i += 1

    def _quoted(self):
        start = self.i
        self.i += 1
        buf = []
        while True:
            if self.i >= len(self.t):
                raise ParseError("双引号字符串没有闭合", self.t, start)
            c = self.t[self.i]
            if c == "\\":
                if self.i + 1 >= len(self.t):
                    raise ParseError("字符串转义符后内容结束", self.t, self.i)
                nxt = self.t[self.i + 1]
                mapping = {'"': '"', "'": "'", "\\": "\\", "n": "\n", "t": "\t"}
                if nxt == "U":
                    hexs = self.t[self.i + 2:self.i + 6]
                    if len(hexs) == 4:
                        try:
                            buf.append(chr(int(hexs, 16)))
                            self.i += 6
                            continue
                        except ValueError:
                            pass
                buf.append(mapping.get(nxt, "\\" + nxt))
                self.i += 2
                continue
            if c == '"':
                self.i += 1
                return "".join(buf)
            self.i += 1

    def _unquoted(self):
        start = self.i
        while self.i < len(self.t):
            c = self.t[self.i]
            if c not in UNQUOTED_OK:
                break
            self.i += 1
        if self.i == start:
            c = self.t[self.i]
            raise ParseError(
                "遇到非法字符 %r —— 非引号字符串只允许字母数字与 _ $ / : . -，"
                "其它字符必须放进双引号里（并给它加引号后才能通过解析）" % c,
                self.t, start)
        raw = self.t[start:self.i]
        if raw.isdigit() or (raw.startswith("-") and raw[1:].isdigit()):
            try:
                return int(raw)
            except ValueError:
                pass
        return raw


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH
    if not os.path.isfile(path):
        print("❌ 找不到文件: %s" % path)
        return 1

    raw = open(path, "rb").read()
    print("校验文件: %s" % path)
    print("  大小: %d 字节" % len(raw))

    # 前置检查
    problems = []
    if raw.count(b"\r\n"):
        problems.append("含 CRLF 换行（应为纯 LF）: %d 处" % raw.count(b"\r\n"))
    if raw[:3] == b"\xef\xbb\xbf":
        problems.append("含 UTF-8 BOM（pbxproj 不应有 BOM）")
    if any(b >= 0x80 for b in raw):
        problems.append("含非 ASCII 字节")
    if not raw.startswith(b"// !$*UTF8*$!"):
        problems.append("首行不是 '// !$*UTF8*$!'")
    for p in problems:
        print("  ❌ %s" % p)

    text = raw.decode("utf-8", "strict")

    # 语法解析
    try:
        tree = StrictParser(text).parse()
    except ParseError as e:
        print("\n❌ 语法解析失败：")
        print("  %s" % e)
        return 1

    print("  ✅ OpenStep 语法解析通过")

    # 结构检查
    ok = True
    objs = tree.get("objects")
    if not isinstance(objs, dict):
        print("  ❌ 缺少最外层 objects 字典")
        return 1
    print("  objects 条目数: %d" % len(objs))

    ro = tree.get("rootObject")
    if ro not in objs:
        print("  ❌ rootObject %r 未在 objects 中定义" % ro)
        ok = False
    else:
        print("  rootObject: %s (%s)" % (ro, objs[ro].get("isa")))
        if objs[ro].get("isa") != "PBXProject":
            print("  ❌ rootObject 的 isa 不是 PBXProject")
            ok = False

    # 引用完整性（只检查形如 24 位十六进制的 UUID）
    def is_uuid(s):
        return isinstance(s, str) and len(s) == 24 and all(
            c in "0123456789ABCDEFabcdef" for c in s)

    refs = set()

    def walk(o):
        if isinstance(o, dict):
            for v in o.values():
                if is_uuid(v):
                    refs.add(v)
                walk(v)
        elif isinstance(o, list):
            for v in o:
                if is_uuid(v):
                    refs.add(v)
                walk(v)

    walk(tree)
    dangling = sorted(r for r in refs if r not in objs)
    if dangling:
        print("  ❌ 悬空引用（引用了不存在的对象）: %s" % ", ".join(dangling))
        ok = False
    else:
        print("  ✅ 引用完整（%d 个引用全部可解析）" % len(refs))

    # 统计
    counts = {}
    for o in objs.values():
        if isinstance(o, dict):
            counts[o.get("isa")] = counts.get(o.get("isa"), 0) + 1
    print("  对象类型统计: %s" % ", ".join(
        "%s=%d" % (k, v) for k, v in sorted(counts.items()) if k))

    src = counts.get("PBXSourcesBuildPhase", 0)
    print("  Sources 构建阶段数: %d" % src)

    if problems:
        ok = False

    print()
    print("✅ 校验通过" if ok else "❌ 校验失败")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
