const std = @import("std");
const json = std.json;
const Entry = @import("data_structure.zig");

const Info = struct { title: []const u8, path: []const u8, output_path: []const u8, type_tag: []const u8 };
const Info_json = union(enum) {
    Single: std.json.Parsed(Entry.Single),
    Playlist: std.json.Parsed(Entry.Playlist),
};

// receive path & info
fn conv(allocator: std.mem.Allocator, info: Info) !void {
    std.debug.print("Starting conversion for: {s}\n", .{info.title});

    try mkdir_recursively(info.output_path);

    const path = try std.mem.concat(allocator, u8, &[_][]const u8{ info.path, "/" });
    std.debug.print("Path: {s}\n", .{path});

    const output_path = try std.mem.concat(allocator, u8, &[_][]const u8{ info.output_path, "/" });
    std.debug.print("Output Path: {s}\n", .{output_path});

    const video_file = try std.mem.concat(allocator, u8, &[_][]const u8{ path, "video.m4s" });
    std.debug.print("Video File: {s}\n", .{video_file});

    const audio_file = try std.mem.concat(allocator, u8, &[_][]const u8{ path, "audio.m4s" });
    std.debug.print("Audio File: {s}\n", .{audio_file});

    const output_file = try std.mem.concat(allocator, u8, &[_][]const u8{ output_path, info.title, ".mp4" });
    std.debug.print("Output File: {s}\n", .{output_file});

    // const ffmpeg_cmd = "ffmpeg";
    const argv = [_][]const u8{
        "ffmpeg", // placeholder for formatting alignment
        "-n",
        "-i",
        video_file,
        "-i",
        audio_file,
        "-c",
        "copy",
        "-shortest",
        output_file,
    };

    std.debug.print("Running ffmpeg with arguments: {s}\n", .{argv});

    var ffmpeg_process = std.process.Child.init(&argv, allocator);
    ffmpeg_process.stdout_behavior = .Ignore;
    ffmpeg_process.stderr_behavior = .Ignore;
    try ffmpeg_process.spawn();
    const term = try ffmpeg_process.wait();
    var exit_code_buf: [4]u8 = undefined;

    const message = if (term.Exited != 0) cond: {
        const exit_code = try std.fmt.bufPrint(exit_code_buf[0..], "{d}", .{term.Exited});
        break :cond try std.mem.concat(allocator, u8, &[_][]const u8{ "FFmpeg exited with code ", exit_code });
    } else cond: {
        break :cond try std.mem.concat(allocator, u8, &[_][]const u8{ "Successfully merged audio and video into ", output_file });
    };

    const final_message = try std.mem.concat(allocator, u8, &[_][]const u8{ path, ": ", message, "\n" });

    try std.io.getStdOut().writeAll(final_message);
}

const downloaded_path: []const u8 = "/storage/emulated/0/Android/data/com.bilibili.app.in/download/";
var cwd: []const u8 = undefined;

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
//
//  turn into 1 and walk it,
//  to find sub dir and parse entry.json
//  and then generate the ffmpeg convert command
//  and execute it.

fn parse_info_json(allocator: std.mem.Allocator, info_json_raw: []const u8) !Info_json {
    std.debug.print("Parsing JSON info\n", .{});
    const single_parsed = std.json.parseFromSlice(Entry.Single, allocator, info_json_raw, .{}) catch {
        std.debug.print("Playlist detected\n", .{});
        return Info_json{ .Playlist = try std.json.parseFromSlice(Entry.Playlist, allocator, info_json_raw, .{}) };
    };

    std.debug.print("Single entry detected\n", .{});
    return Info_json{ .Single = single_parsed };
}

fn conv_all(allocator: std.mem.Allocator, path: []const u8, output_path: []const u8) !void {
    std.debug.print("Starting conversion for all entries in path: {s}\n", .{path});
    const openDirOptions = .{ .access_sub_paths = false, .iterate = true };
    var dir = try std.fs.openDirAbsolute(path, openDirOptions);
    defer dir.close();

    var it = dir.iterate();

    std.debug.print("Current working directory: {s}\n", .{cwd});

    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;
        std.debug.print("Processing entry: {s}\n", .{entry.name});

        const next_path = try std.mem.concat(allocator, u8, &[_][]const u8{ path, "/", entry.name });
        std.debug.print("Next path: {s}\n", .{next_path});
        var sub_dir = try std.fs.openDirAbsolute(next_path, openDirOptions);
        defer sub_dir.close();
        var sub_it = sub_dir.iterate();
        while (try sub_it.next()) |sub_entry| {
            if (sub_entry.kind != .directory) continue;
            std.debug.print("Processing sub-entry: {s}\n", .{sub_entry.name});
            const current_path = try std.mem.concat(allocator, u8, &[_][]const u8{ next_path, "/", sub_entry.name });
            std.debug.print("Current path: {s}\n", .{current_path});
            const info_json_path = try std.mem.concat(allocator, u8, &[_][]const u8{ current_path, "/entry.json" });
            const info_json_file = try std.fs.cwd().openFile(info_json_path, .{});
            const file_size = try info_json_file.getEndPos();
            const info_json_raw = try allocator.alloc(u8, file_size);
            defer allocator.free(info_json_raw);
            _ = try info_json_file.readAll(info_json_raw);

            std.debug.print("Parsing JSON from file: {s}\n", .{info_json_path});
            const info_json_parsed = try parse_info_json(allocator, info_json_raw);

            const info = switch (info_json_parsed) {
                .Single => cond: {
                    const info_json = info_json_parsed.Single.value;
                    defer info_json_parsed.Single.deinit();
                    break :cond Info{
                        .title = info_json.title,
                        .type_tag = info_json.type_tag,
                        .path = try std.mem.concat(allocator, u8, &[_][]const u8{ current_path, "/", info_json.type_tag }),
                        .output_path = output_path,
                    };
                },
                .Playlist => cond: {
                    const info_json = info_json_parsed.Playlist.value;
                    defer info_json_parsed.Playlist.deinit();
                    break :cond Info{
                        .title = info_json.title,
                        .type_tag = info_json.type_tag,
                        .path = try std.mem.concat(allocator, u8, &[_][]const u8{ current_path, "/", info_json.type_tag }),
                        .output_path = try std.mem.concat(allocator, u8, &[_][]const u8{ output_path, "/", info_json.title, "/" }),
                    };
                },
            };

            std.debug.print("Info: {{title: {s}, path: {s}, output_path: {s}}}\n", .{ info.title, info.path, info.output_path });
            try conv(allocator, info); // TODO: multithread
        }
    }
}

fn mkdir_recursively(
    path: []const u8,
    // allocator: std.mem.Allocator,
) !void {
    var components = try std.fs.path.componentIterator(path);

    var current_dir = try std.fs.openDirAbsolute("/", .{});

    while (components.next()) |component| {
        const name = component.name;
        const new_dir = current_dir.openDir(name, .{}) catch |err| switch (err) {
            error.FileNotFound => blk: {
                current_dir.makeDir(name) catch |e| return e;
                break :blk try current_dir.openDir(name, .{});
            },
            else => return err,
        };
        // try dir_stack.append(new_dir);
        current_dir = new_dir;
    }
}

fn usage() !void {
    try std.io.getStdOut().writeAll("Usage: bilibili_extract <path> <output_path>\n");
}

pub fn main() !void {
    var heap = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer heap.deinit();

    const allocator = heap.allocator();

    var args = std.process.args();
    _ = args.skip();

    const _path = args.next() orelse return usage();
    const _output_path = args.next() orelse return usage();

    cwd = try std.process.getCwdAlloc(allocator);
    // defer allocator.free(cwd); // 删除 free

    var detect_output_path = false;
    var detect_path = false;

    const output_path =
        if (_output_path[0] == '/') _output_path else cond: {
        detect_output_path = true;
        break :cond try std.mem.concat(allocator, u8, &[_][]const u8{ cwd, "/", _output_path });
    };
    const path = if (_path[0] == '/') _path else cond: {
        detect_path = true;
        break :cond try std.mem.concat(allocator, u8, &[_][]const u8{ cwd, "/", _path });
    };

    try mkdir_recursively(output_path);

    try conv_all(allocator, path, output_path);
}
