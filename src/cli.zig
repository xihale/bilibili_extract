const std = @import("std");
const argIterator = std.process.ArgIterator;
const Allocator = std.mem.Allocator;

const definitions = @import("definitions.zig");

const mkdir_recursively = @import("mkdir_recursively.zig").mkdir_recursively;

const usage =
    \\[-I <path>] [-O <output_path>]
    \\-I <path> - input path, multiple is allowed
    \\-O <output_path> - output path, only one(this program will use the last one if multiple is provided)
    \\-h - show this help message
    \\
    \\Example:
    \\  $ bilibili_extract -I /path/to/input1 -I /path/to/input2 -O /path/to/output
;

pub const Cli = struct {
    input_paths: [][]const u8,
    output_path: []const u8,

    pub fn deinit(cli: Cli, allocator: Allocator) void {
        for (cli.input_paths) |path| allocator.free(path);
        allocator.free(cli.input_paths);
        allocator.free(cli.output_path);
    }
};

pub const cli_error = error{
    InvalidArgument,
    helpRequired,
};

pub fn help(writer: anytype) !void {
    try writer.print("Help:\n{s}\n", .{usage});
}

fn absolute_path(allocator: std.mem.Allocator, cwd: []const u8, path: []const u8) ![]const u8 {
    if (path[0] == '/') return allocator.dupe(u8, path);
    return try std.mem.concat(allocator, u8, &[_][]const u8{ cwd, "/", path });
}

pub fn parseArgs(allocator: Allocator) !Cli {
    var argv = std.process.args();
    _ = argv.skip();
    var _argv = argv;
    defer {
        argv.deinit();
        _argv.deinit();
    }

    var input_count: u8 = 0;
    while (_argv.next()) |arg| {
        if (std.mem.eql(u8, arg, "-I")) {
            input_count = input_count + 1;
            _ = _argv.skip();
        } else if (std.mem.eql(u8, arg, "-O")) {
            _ = _argv.skip();
        } else if (std.mem.eql(u8, arg, "-h")) {
            return cli_error.helpRequired;
        } else {
            return cli_error.InvalidArgument;
        }
    }

    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    var input_paths = try allocator.alloc([]const u8, input_count);
    var output_path: ?[]const u8 = null;

    input_count = 0;

    while (argv.next()) |arg| {
        if (std.mem.eql(u8, arg, "-I")) {
            const path = argv.next() orelse return cli_error.InvalidArgument;
            input_paths[input_count] = try absolute_path(allocator, cwd, path);
            input_count += 1;
        } else if (std.mem.eql(u8, arg, "-O")) {
            const path = argv.next() orelse return cli_error.InvalidArgument;
            if (output_path != null) allocator.free(output_path.?);
            output_path = try absolute_path(allocator, cwd, path);
        }
    }

    if (input_count == 0) {
        const _input_paths = definitions.bili_download_paths;
        input_paths = try allocator.alloc([]const u8, _input_paths.len);
        inline for (_input_paths, 0..) |path, idx|
            input_paths[idx] = try absolute_path(allocator, cwd, path);
    }
    if (output_path == null) {
        output_path = definitions.output_path;
    }

    try mkdir_recursively(output_path.?);
    return Cli{ .input_paths = input_paths, .output_path = output_path.? };
}
