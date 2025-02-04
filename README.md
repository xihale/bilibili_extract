# Bilibili Download Extractor

## Overview

This is a program designed to process videos downloaded from Bilibili, extracting them into a more human-readable and player-friendly format.

## Get executable binary

You can build the program yourself or use my pre-built binary listed in the `Release` page.

### Building Yourself

1. Ensure you have Zig installed on your system. Follow the instructions on the [official website](https://ziglang.org/download/).
2. Use the following command to build the program:

   ```shell
   zig build -Doptimize=ReleaseFast -Dtarget=aarch64-linux
   ```

3. Copy the generated binary `zig-out/bin/bilibili_extract` to your Termux environment. You can use tools like `adb` or internet sync for this step.

### Using Pre-built Binary

If you prefer not to build it yourself, you can use a pre-built binary provided by the developer.

## Usage

### Prerequisites

- Ensure `ffmpeg` is installed on your system, as the program uses it to combine audio and video streams. Install it using:

  ```shell
  pkg install ffmpeg
  ```

### Steps

1. Download the video from Bilibili and locate the download directory. For example:

   ```plaintext
   /storage/emulated/0/Android/data/com.bilibili.app.in/download/
   ```

2. Run the following command to extract the video:

   ```shell
   bilibili_extract /storage/emulated/0/Android/data/com.bilibili.app.in/download/ /storage/emulated/0/Movies/bilibili_extracted
   ```

This will process the downloaded Bilibili videos and save them in the specified output directory in a more accessible format.his will process the downloaded Bilibili videos and save them in the specified output directory in a more accessible format.
