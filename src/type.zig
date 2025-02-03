/// input_path: the path to the input directory containing the video.m4s and audio.m4s
/// output_file: the path to the output file
/// they are both absolute paths
pub const Info =
    struct { input_path: []const u8, output_file: []const u8 };
