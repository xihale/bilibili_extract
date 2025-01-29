const std = @import("std");
const json = std.json;

const Info = struct { input_path: []const u8, output_file: []const u8 };
// var mutex = std.Thread.Mutex{};

// receive path & info
fn conv(
    allocator: std.mem.Allocator,
    info: Info,
    // , buf_stream: *std.io.FixedBufferStream([]u8)
) anyerror!void { // nesting error inference https://github.com/ziglang/zig/issues/2971

    // const writer = buf_stream.writer();
    defer {
        // mutex.lock();
        // std.io.getStdOut().writeAll(buf_stream.getWritten()) catch {};
        // mutex.unlock();
        // allocator.free(buf_stream.buffer);
        allocator.free(info.input_path);
        allocator.free(info.output_file);
    }

    // if exists, return the action flow
    blk: {
        std.fs.accessAbsolute(info.output_file, .{}) catch |err| switch (err) {
            error.FileNotFound => break :blk,
            else => return err,
        };
        // try writer.writeAll("output_file already exists, skipped.\n\n");
        return;
    }

    // try writer.print("Starting conversion for: {s}\n", .{info.input_path});

    const video_file = try std.mem.concat(allocator, u8, &[_][]const u8{ info.input_path, "/", "video.m4s" });
    defer allocator.free(video_file);
    // std.log.debug("Video File: {s}\n", .{video_file});

    const audio_file = try std.mem.concat(allocator, u8, &[_][]const u8{ info.input_path, "/", "audio.m4s" });
    defer allocator.free(audio_file);
    // std.log.debug("Audio File: {s}\n", .{audio_file});

    // std.log.debug("Output File: {s}\n", .{info.output_file});

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
        info.output_file,
    };

    // std.log.debug("Running ffmpeg with arguments: {s}\n", .{argv});

    var ffmpeg_process = std.process.Child.init(&argv, allocator);
    ffmpeg_process.stdout_behavior = .Ignore;
    ffmpeg_process.stderr_behavior = .Ignore;
    try ffmpeg_process.spawn();
    // const term = try ffmpeg_process.wait();
    _ = try ffmpeg_process.wait();
    //
    // // if (term.Exited != 0) {
    //     try writer.print("FFmpeg exited with code {d}\n\n", .{term.Exited});
    // } else {
    //     try writer.print("Successfully merged audio and video into \"{s}\"\n\n", .{info.output_file});
    // }
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
//
//  turn into 1 and walk it,
//  to find sub dir and parse entry.json
//  and then generate the ffmpeg convert command
//  and execute it.

// fn parse_info_json(allocator: std.mem.Allocator, info_json_raw: []const u8) !Info_json {
//     std.log.debug("Parsing JSON info\n", .{});
//     const single_parsed = std.json.parseFromSlice(Entry.Single, allocator, info_json_raw, .{}) catch {
//         std.log.debug("Playlist detected\n", .{});
//         return Info_json{ .Playlist = try std.json.parseFromSlice(Entry.Playlist, allocator, info_json_raw, .{}) };
//     };
//
//     std.log.debug("Single entry detected\n", .{});allocator.free
//     return Info_json{ .Single = single_parsed };
// }

const InfoError = error{
    InvalidJson,
};

fn parse_info_json(allocator: std.mem.Allocator, info_json_raw: []const u8) !std.meta.Tuple(&.{ std.json.Parsed(json.Value), Info }) {
    // std.log.debug("Parsing JSON info\n", .{});
    const json_parsed = try std.json.parseFromSlice(std.json.Value, allocator, info_json_raw, .{});
    errdefer json_parsed.deinit();

    const value = json_parsed.value;

    const ep = value.object.get("ep");
    const title = if (value.object.get("title")) |title| title.string else return InfoError.InvalidJson;
    const index = if (ep != null) if (ep.?.object.get("index")) |index| index.string else return InfoError.InvalidJson else undefined;
    const index_title = if (ep != null) if (ep.?.object.get("index_title")) |index_title| index_title.string else return InfoError.InvalidJson else undefined;
    const type_tag = if (value.object.get("type_tag")) |type_tag| type_tag.string else return InfoError.InvalidJson;

    return .{ json_parsed, Info{
        .input_path = type_tag,
        .output_file = if (ep != null) try std.mem.concat(allocator, u8, &[_][]const u8{ title, "/", index, ". ", index_title, ".mp4" }) else try std.mem.concat(allocator, u8, &[_][]const u8{ title, ".mp4" }),
    } };
}

fn run(
    allocator: std.mem.Allocator,
    info: Info,
    // , buf_stream: *std.io.FixedBufferStream([]u8)
) void {
    conv(allocator, info
    // , buf_stream
    ) catch {};
}
fn conv_all(allocator: std.mem.Allocator, path: []const u8, output_path: []const u8) !void {
    // std.log.debug("Starting conversion for all entries in path: {s}\n", .{path});
    const openDirOptions = .{ .access_sub_paths = false, .iterate = true };
    var dir = try std.fs.openDirAbsolute(path, openDirOptions);
    defer dir.close();

    var it = dir.iterate();

    // std.log.debug("Current working directory: {s}\n", .{cwd});

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    var wg = std.Thread.WaitGroup{};

    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;

        const next_path = try std.mem.concat(allocator, u8, &[_][]const u8{ path, "/", entry.name });
        defer allocator.free(next_path);
        // std.log.debug("Next path: {s}\n", .{next_path});
        var sub_dir = try std.fs.openDirAbsolute(next_path, openDirOptions);
        defer sub_dir.close();
        var sub_it = sub_dir.iterate();
        while (try sub_it.next()) |sub_entry| {
            if (sub_entry.kind != .directory) continue;
            const buf = try allocator.alloc(u8, 4096);
            // defer allocator.free(buf);
            // var buf_stream = std.io.fixedBufferStream(buf);
            // const writer = buf_stream.writer();
            // try writer.print("Processing: {s}/{s}\n", .{ entry.name, sub_entry.name });
            const current_path = try std.mem.concat(allocator, u8, &[_][]const u8{ next_path, "/", sub_entry.name });
            defer allocator.free(current_path);
            // std.log.debug("Current path: {s}\n", .{current_path});
            const info_json_path = try std.mem.concat(allocator, u8, &[_][]const u8{ current_path, "/entry.json" });
            defer allocator.free(info_json_path);
            const info_json_file = try std.fs.cwd().openFile(info_json_path, .{});
            defer info_json_file.close();
            const file_size = try info_json_file.getEndPos();
            const info_json_raw = try allocator.alloc(u8, file_size);
            defer allocator.free(info_json_raw);
            _ = try info_json_file.readAll(info_json_raw);

            // std.log.debug("Parsing JSON from file: {s}\n", .{info_json_path});
            const parsed, const info_json = parse_info_json(allocator, info_json_raw) catch
            // |err|
                {
                // switch (err) {
                //     InfoError.InvalidJson => {
                //         writer.writeAll("Invalid JSON file, possibly because it was not completely downloaded. Skipped.\n") catch {};
                //     },
                //     else => {
                //         writer.print("ERROR: {}", .{err}) catch {};
                //     },
                // }
                allocator.free(buf); // TODO: other solutions that use defer or errdefer.
                continue;
            };

            defer {
                // allocator.free(info_json.input_path);
                allocator.free(info_json.output_file);
                parsed.deinit();
            }

            const info = Info{
                .input_path = try std.mem.concat(allocator, u8, &[_][]const u8{ current_path, "/", info_json.input_path }),
                .output_file = try std.mem.concat(allocator, u8, &[_][]const u8{ output_path, "/", info_json.output_file }),
            };

            try mkdir_recursively(info.output_file[0..std.mem.lastIndexOf(u8, info.output_file, "/").?]);

            pool.spawnWg(&wg, run, .{
                allocator, info,
                // , &buf_stream
            });
        }
    }

    wg.wait();
}

fn mkdir_recursively(
    path: []const u8,
    // allocator: std.mem.Allocator,
) !void {
    var components = try std.fs.path.componentIterator(path);

    var current_dir = try std.fs.openDirAbsolute("/", .{});
    // current_dir.close();

    while (components.next()) |component| {
        const name = component.name;
        const new_dir = current_dir.openDir(name, .{}) catch |err| switch (err) {
            error.FileNotFound => blk: {
                current_dir.makeDir(name) catch |e| return e;
                break :blk try current_dir.openDir(name, .{});
            },
            else => return err,
        };
        current_dir = new_dir;
    }
}

fn usage() !void {
    try std.io.getStdOut().writeAll("Usage: bilibili_extract <path> <output_path>\n");
}

fn absolute_path(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (path[0] == '/') return path;
    return try std.mem.concat(allocator, u8, &[_][]const u8{ cwd, "/", path });
}

var cwd: []const u8 = undefined;
pub fn main() !void {

    // inital work
    var heap = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer heap.deinit();

    // for debug
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer {
    //     // if (gpa.deinit() == .leak) std.debug.panic("Leaked.\n", .{});
    //     _ = gpa.deinit();
    // }

    // const allocator = gpa.allocator();
    const allocator = heap.allocator();

    var args = std.process.args();
    _ = args.skip();

    cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    const path = try absolute_path(allocator, args.next() orelse return usage());
    defer allocator.free(path);
    const output_path = try absolute_path(allocator, args.next() orelse return usage());
    defer allocator.free(output_path);

    try mkdir_recursively(output_path);

    try conv_all(allocator, path, output_path);
}
