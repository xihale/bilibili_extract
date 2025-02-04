const std = @import("std");
const Info = @import("definitions.zig").Info;
const mkdir_recursively = @import("mkdir_recursively.zig").mkdir_recursively;
const Allocator = std.mem.Allocator;
const json = std.json;

const InfoError = error{
    InvalidJson,
};

const ExtractError =
    InfoError ||
    std.fs.Dir.AccessError ||
    std.fs.File.OpenError ||
    std.process.Child.SpawnError ||
    std.mem.Allocator.Error;

/// to call ffmpeg to merge audio and video into output file
fn extract(
    allocator: Allocator,
    info: Info,
) ExtractError!void { // nesting error inference https://github.com/ziglang/zig/issues/2971

    defer {
        allocator.free(info.input_path);
        allocator.free(info.output_file);
    }

    // if exists, return the action flow
    blk: {
        std.fs.accessAbsolute(info.output_file, .{}) catch |err| switch (err) {
            error.FileNotFound => break :blk, // continue the work flow
            else => return err,
        };
        return;
    }

    // generate the path of video and audio file
    const video_file = try std.mem.concat(allocator, u8, &[_][]const u8{ info.input_path, "/", "video.m4s" });
    defer allocator.free(video_file);
    const audio_file = try std.mem.concat(allocator, u8, &[_][]const u8{ info.input_path, "/", "audio.m4s" });
    defer allocator.free(audio_file);

    // the arguments to call ffmpeg to merge audio and video into output file
    const argv = [_][]const u8{
        "ffmpeg",    "-n",
        "-i",        video_file,
        "-i",        audio_file,
        "-c",        "copy",
        "-shortest", info.output_file,
    };

    var ffmpeg_process = std.process.Child.init(&argv, allocator);
    ffmpeg_process.stdout_behavior = .Ignore;
    ffmpeg_process.stderr_behavior = .Ignore;
    try ffmpeg_process.spawn();
    _ = try ffmpeg_process.wait();
}

// Structure
//
// └── 1
//     ├── sub1
//     │  ├── 64 (or 80 depending on entry.json)
//     │  │   ├── audio.m4s
//     │  │   ├── index.json
//     │  │   └── video.m4s
//     │  ├── danmaku.xml
//     │  └── entry.json
//     └── sub2
//         ├── 64 (or 80 depending on entry.json)
//         │   ├── audio.m4s
//         │   ├── index.json
//         │   └── video.m4s
//         ├── danmaku.xml
//         └── entry.json

fn parse_info_json(allocator: Allocator, info_json_raw: []const u8, output_path: []const u8) !std.meta.Tuple(&.{ json.Parsed(json.Value), Info }) {
    const json_parsed = try json.parseFromSlice(json.Value, allocator, info_json_raw, .{});
    errdefer json_parsed.deinit();

    const value = json_parsed.value;

    const title = value.object.get("title").?.string;
    const type_tag = value.object.get("type_tag").?.string;

    // anime
    const output_file = if (value.object.get("ep")) |ep| blk: {
        const index = ep.object.get("index").?.string;
        const index_title = ep.object.get("index_title").?.string;
        break :blk try std.mem.concat(allocator, u8, &[_][]const u8{ title, "/", index, ". ", index_title, ".mp4" });
    } else blk: {
        const page_data = value.object.get("page_data").?.object;
        const part = page_data.get("part").?.string;
        if (!std.mem.eql(u8, title, part)) { // playlist
            // mkdir
            var dir = try std.fs.openDirAbsolute(output_path, .{});
            try dir.makeDir(title);
            break :blk try std.mem.concat(allocator, u8, &[_][]const u8{ title, "/", part, ".mp4" });
        } else {
            break :blk try std.mem.concat(allocator, u8, &[_][]const u8{ title, ".mp4" });
        }
    };

    return .{ json_parsed, Info{
        .input_path = type_tag,
        .output_file = output_file,
    } };
}

pub fn extract_no_err(
    allocator: Allocator,
    info: Info,
) void {
    extract(allocator, info) catch {};
}

pub fn extract_all(allocator: Allocator, path: []const u8, output_path: []const u8) !void {
    const openDirOptions = .{ .access_sub_paths = false, .iterate = true };
    var dir = std.fs.openDirAbsolute(path, openDirOptions) catch |err| switch (err) {
        error.FileNotFound => return, // skip invalid path
        else => return err,
    };
    defer dir.close();

    var it = dir.iterate();

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    var wg = std.Thread.WaitGroup{};

    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;

        const next_path = try std.mem.concat(allocator, u8, &[_][]const u8{ path, "/", entry.name });
        defer allocator.free(next_path);
        var sub_dir = try std.fs.openDirAbsolute(next_path, openDirOptions);
        defer sub_dir.close();
        var sub_it = sub_dir.iterate();
        while (try sub_it.next()) |sub_entry| {
            if (sub_entry.kind != .directory) continue;
            const current_path = try std.mem.concat(allocator, u8, &[_][]const u8{ next_path, "/", sub_entry.name });
            defer allocator.free(current_path);
            const entry_json_path = try std.mem.concat(allocator, u8, &[_][]const u8{ current_path, "/entry.json" });
            defer allocator.free(entry_json_path);
            const entry_json = std.fs.cwd().openFile(entry_json_path, .{}) catch |err| switch (err) {
                error.FileNotFound => {
                    try extract_all(allocator, current_path, output_path); // scan next path to find entry.json
                    continue;
                },
                else => return err,
            };
            defer entry_json.close();

            // read entry.json
            const file_size = try entry_json.getEndPos();
            const info_json_raw = try allocator.alloc(u8, file_size);
            defer allocator.free(info_json_raw);
            _ = try entry_json.readAll(info_json_raw);

            const parsed, const pre_info = parse_info_json(allocator, info_json_raw, output_path) catch continue; // skip invalid json

            defer {
                // input_path is a reference to parsed->type_tag.string, so there is no need to free it.
                allocator.free(pre_info.output_file);
                parsed.deinit();
            }

            // make it absolute path
            const info = Info{
                .input_path = try std.mem.concat(allocator, u8, &[_][]const u8{ current_path, "/", pre_info.input_path }),
                .output_file = try std.mem.concat(allocator, u8, &[_][]const u8{ output_path, "/", pre_info.output_file }),
            };

            pool.spawnWg(&wg, extract_no_err, .{
                allocator,
                info,
            });
        }
    }

    wg.wait();
}
