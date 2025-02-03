const std = @import("std");
const builtin = @import("builtin");

const mkdir_recursively = @import("./utils/mkdir_recursively.zig").mkdir_recursively;
const extract_all = @import("./extract.zig").extract_all;

fn usage() !void {
    try std.io.getStdOut().writeAll("Usage: bilibili_extract <path> <output_path>\n");
}

fn absolute_path(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (path[0] == '/') return path;
    return try std.mem.concat(allocator, u8, &[_][]const u8{ cwd, "/", path });
}

var cwd: []const u8 = undefined;
pub fn main() !void {

    // release mode
    var Allocator = if (builtin.mode != .Debug) std.heap.ArenaAllocator.init(std.heap.page_allocator) else std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = Allocator.deinit();
    const allocator = Allocator.allocator();

    var args = std.process.args();
    _ = args.skip();

    cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    const path = try absolute_path(allocator, args.next() orelse return usage());
    defer allocator.free(path);
    const output_path = try absolute_path(allocator, args.next() orelse return usage());
    defer allocator.free(output_path);

    try mkdir_recursively(output_path);

    try extract_all(allocator, path, output_path);
}
