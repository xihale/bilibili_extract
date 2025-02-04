/// input_path: the path to the input directory containing the video.m4s and audio.m4s
/// output_file: the path to the output file
/// they are both absolute paths
pub const Info =
    struct { input_path: []const u8, output_file: []const u8 };

const pub_data_path = "/sdcard/Android/data/";

pub const bili_pkg_names =
    .{ "com.bilibili.app.in", "tv.danmaku.bili" };
pub const bili_download_paths = blk: {
    var paths: [bili_pkg_names.len][]const u8 = undefined;
    for (bili_pkg_names, 0..) |pkg_name, idx| {
        paths[idx] = pub_data_path ++ pkg_name ++ "/Download";
    }
    break :blk paths;
};
pub const output_path = "/sdcard/Download/bilibili_extracted/";
