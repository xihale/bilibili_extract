const std = @import("std");

pub fn mkdir_recursively(
    path: []const u8,
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
        current_dir.close();
        current_dir = new_dir;
    }

    current_dir.close();
}
