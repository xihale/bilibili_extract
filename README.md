## What is this?

It's a program that deal bilibili downloaded, extracting those into a more human-readable & player-friendly format.

## How to use?

```shell
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-linux
```

and then copy the `zig-out/bin/bilibili_extract` to your `termux` (you can use adb or internet sync, etc)

## Usage

First, you need to download the video from bilibili, and locate the download dir.
As for me, that's `/storage/emulated/0/Android/data/com.bilibili.app.in/download/`
Then, you can use the following command to extract the video:

```shell
bilibili_extract /storage/emulated/0/Android/data/com.bilibili.app.in/download/ /storage/emulated/0/Movies/bilibili_extracted
```

## TODOs

- [ ] dynimic json parse based on std.json.dynamic.Value
- [ ] skip err & log err list
- [ ] multiple thread
- [ ] sane log
