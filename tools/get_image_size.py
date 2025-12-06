#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Roblox 图片尺寸获取工具（开发用）

说明：
- 这是一个在本机/CI运行的外部工具，不在Roblox游戏内运行。
- 通过请求 assetdelivery.roblox.com 下载图片字节，并解析 PNG/JPEG 头部得到像素宽高。
- 若资产不是图片或格式不支持，将打印失败信息。
 - 若资产访问受限（返回401），可通过环境变量提供登录Cookie：`ROBLOSECURITY`。

用法：
    python tools/get_image_size.py 16735005717
    python tools/get_image_size.py rbxassetid://16735005717

输出：
    成功时："asset 16735005717 size: <width>x<height>"
    失败时："Failed: <reason>"


- 打开并登录 https://www.roblox.com/ 。
- 按 F12 打开开发者工具。
- 切到 Application
- 左侧选择 Cookies -> https://www.roblox.com 。
- 在右侧列表找到名为 .ROBLOSECURITY 的条目，双击其 Value 值复制。它通常以 _|WARNING:-DO-NOT-SHARE-THIS... 开头。

在 PowerShell 设置环境变量并运行脚本

- 在当前终端设置临时环境变量：
  - $env:ROBLOSECURITY = '<粘贴你的Cookie值>'
- 运行图片尺寸工具：
  - python tools/get_image_size.py 16735005717
- 若输出 asset 16735005717 size: <width>x<height> ，表示成功。
"""

from __future__ import annotations
import sys
import os
import urllib.request
import urllib.error
from typing import Optional, Tuple


# 获取图片字节数据（函数级注释）：
# @param asset_id int Roblox rbxassetid 的数字ID
# @return bytes 图片的二进制内容，失败抛异常
def get_image_bytes(asset_id: int) -> bytes:
    url = f"https://assetdelivery.roblox.com/v1/asset?id={asset_id}"
    cookie = os.environ.get("ROBLOSECURITY")
    req = urllib.request.Request(
        url,
        headers={
            # 设置常见UA避免部分CDN拒绝
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Python-urllib",
            "Accept": "*/*",
            **({"Cookie": f".ROBLOSECURITY={cookie}"} if cookie else {}),
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            # 自动跟随重定向，读取最终内容
            data = resp.read()
            if not data:
                raise RuntimeError("Empty response body")
            return data
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.reason}")
    except urllib.error.URLError as e:
        raise RuntimeError(f"URL error: {e.reason}")


# 解析PNG尺寸（函数级注释）：
# @param data bytes PNG文件的二进制内容
# @return tuple[int,int]|None 宽、高；若非PNG返回None
def parse_png_size(data: bytes) -> Optional[Tuple[int, int]]:
    sig = b"\x89PNG\r\n\x1a\n"
    if len(data) < 24 or data[:8] != sig:
        return None
    width = int.from_bytes(data[16:20], "big")
    height = int.from_bytes(data[20:24], "big")
    return width, height


# 解析JPEG尺寸（函数级注释）：
# @param data bytes JPEG文件的二进制内容
# @return tuple[int,int]|None 宽、高；若非JPEG返回None
def parse_jpeg_size(data: bytes) -> Optional[Tuple[int, int]]:
    if len(data) < 4 or data[0:2] != b"\xFF\xD8":
        return None
    i = 2
    # 遍历段，寻找SOF段以获取尺寸
    while i < len(data):
        if data[i] != 0xFF:
            i += 1
            continue
        if i + 1 >= len(data):
            break
        marker = data[i + 1]
        i += 2
        # SOF0/SOF2等包含宽高
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            if i + 7 > len(data):
                break
            seg_len = int.from_bytes(data[i:i + 2], "big")
            if i + seg_len > len(data):
                break
            # 结构: 长度(2) + 精度(1) + 高(2) + 宽(2) + 其他...
            height = int.from_bytes(data[i + 3:i + 5], "big")
            width = int.from_bytes(data[i + 5:i + 7], "big")
            return width, height
        else:
            if i + 2 > len(data):
                break
            seg_len = int.from_bytes(data[i:i + 2], "big")
            i += seg_len
    return None


# 获取图片尺寸（函数级注释）：
# @param asset_id int rbxassetid（如 16735005717）
# @return tuple[int,int] 宽、高；无法解析时抛异常
def get_image_size(asset_id: int) -> Tuple[int, int]:
    data = get_image_bytes(asset_id)
    size = parse_png_size(data)
    if size:
        return size
    size = parse_jpeg_size(data)
    if size:
        return size
    raise RuntimeError("Unsupported image format or parse failed")


# 主程序（函数级注释）：
# @return None 解析传入ID并打印结果
def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python tools/get_image_size.py <assetId|rbxassetid://assetId>")
        sys.exit(2)
    raw = sys.argv[1].strip()
    if raw.startswith("rbxassetid://"):
        raw = raw.split("rbxassetid://", 1)[1]
    try:
        asset_id = int(raw)
    except ValueError:
        print("Invalid asset id")
        sys.exit(2)
    try:
        w, h = get_image_size(asset_id)
        print(f"asset {asset_id} size: {w}x{h}")
    except Exception as e:
        print(f"Failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
