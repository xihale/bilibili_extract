const std = @import("std");
const builtin = @import("builtin");

const extract_all = @import("extract.zig").extract_all;
const cli_utils = @import("cli.zig");

var cwd: []const u8 = undefined;
pub fn main() !void {

    // release mode
    var Allocator = if (builtin.mode != .Debug) std.heap.ArenaAllocator.init(std.heap.page_allocator) else std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = Allocator.deinit();
    const allocator = Allocator.allocator();

    const cli = cli_utils.parseArgs(allocator) catch |err| switch (err) {
        cli_utils.cli_error.helpRequired => {
            try cli_utils.help(std.io.getStdOut().writer());
            return;
        },
        cli_utils.cli_error.InvalidArgument => {
            try std.io.getStdErr().writer().writeAll("Invalid argument.\n");
            try cli_utils.help(std.io.getStdErr().writer());
            return;
        },
        else => return err,
    };
    defer cli.deinit(allocator);

    if (cli.input_paths.len == 0) {
        // auto detect input paths
        unreachable; // unimplemented
    }

    for (cli.input_paths) |input_path|
        try extract_all(allocator, input_path, cli.output_path);
}
