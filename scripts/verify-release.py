#!/usr/bin/env python3
"""Reject releases with the wrong SDK, deployment target or CPU slices.

Accept either Bloct.app or its published ZIP; ZIP verification needs no extraction.
"""
import json
import plistlib
from pathlib import Path
import struct
import sys
import zipfile


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def version(value):
    return (value >> 16, (value >> 8) & 255, value & 255)


def slices(data):
    magic = struct.unpack_from(">I", data)[0]
    if magic in (0xCAFEBABE, 0xCAFEBABF):
        count = struct.unpack_from(">I", data, 4)[0]
        stride = 20 if magic == 0xCAFEBABE else 32
        for index in range(count):
            offset = 8 + index * stride
            start, size = struct.unpack_from(">II" if stride == 20 else ">QQ", data, offset + 8)
            yield data[start:start + size]
    else:
        yield data


def verify(path):
    if path.is_dir():
        info = plistlib.loads((path / "Contents/Info.plist").read_bytes())
        binary = (path / "Contents/MacOS" / info["CFBundleExecutable"]).read_bytes()
    else:
        with zipfile.ZipFile(path) as archive:
            info = plistlib.loads(archive.read("Bloct.app/Contents/Info.plist"))
            binary = archive.read("Bloct.app/Contents/MacOS/" + info["CFBundleExecutable"])
    minimum = tuple(map(int, info["LSMinimumSystemVersion"].split(".")))
    require((minimum + (0, 0))[:3] == (14, 0, 0), "Info.plist must require macOS 14.0")
    architectures = {0x01000007: "x86_64", 0x0100000C: "arm64"}
    results = []
    for data in slices(binary):
        require(data[:4] == b"\xcf\xfa\xed\xfe", "Expected a 64-bit little-endian Mach-O slice")
        cpu = struct.unpack_from("<I", data, 4)[0]
        require(cpu in architectures, "Unexpected CPU architecture")
        commands = struct.unpack_from("<I", data, 16)[0]
        offset = 32
        build = None
        for _ in range(commands):
            command, size = struct.unpack_from("<II", data, offset)
            if command == 0x32:  # LC_BUILD_VERSION
                platform, target, sdk = struct.unpack_from("<III", data, offset + 8)
                require(platform == 1, "Expected the macOS platform")
                build = {"architecture": architectures[cpu],
                         "minimum_macos": version(target), "sdk": version(sdk)}
            require(size >= 8, "Invalid Mach-O load command")
            offset += size
        require(build is not None, "Missing LC_BUILD_VERSION")
        require(build["minimum_macos"] == (14, 0, 0), "Binary must target macOS 14.0")
        require(build["sdk"] == (27, 0, 0), "Binary must use macOS SDK 27.0")
        results.append(build)
    require(sorted(item["architecture"] for item in results) == ["arm64", "x86_64"],
            "Release must include exactly arm64 and x86_64")
    print(json.dumps({"artifact": str(path), "slices": results}, indent=2))


if __name__ == "__main__":
    require(len(sys.argv) == 2, "Usage: verify-release.py Bloct.app-or-zip")
    verify(Path(sys.argv[1]))
