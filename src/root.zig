const std = @import("std");
const testing = std.testing;

pub const EnvStream = @import("env_stream.zig").EnvStream;
pub const VariablePosition = @import("variable_position.zig").VariablePosition;
pub const ReadResult = @import("result_enums.zig").ReadResult;
pub const FinalizeResult = @import("result_enums.zig").FinalizeResult;
pub const EnvKey = @import("env_key.zig").EnvKey;
pub const EnvValue = @import("env_value.zig").EnvValue;
pub const EnvPair = @import("env_pair.zig").EnvPair;

pub const buffer_utils = @import("buffer_utils.zig");
pub const whitespace_utils = @import("whitespace_utils.zig");
pub const escape_processor = @import("escape_processor.zig");
pub const quote_parser = @import("quote_parser.zig");
pub const interpolation = @import("interpolation.zig");
pub const finalizer = @import("finalizer.zig");
pub const reader = @import("reader.zig");
pub const memory = @import("memory.zig");
pub const lib = @import("lib.zig");

// Public API
pub const Env = lib.Env;
pub const parse = lib.parse;
pub const parseFile = lib.parseFile;
pub const parseString = lib.parseString;
pub const parseReader = lib.parseReader;

test {
    _ = @import("env_stream.zig");
    _ = @import("variable_position.zig");
    _ = @import("result_enums.zig");
    _ = @import("env_key.zig");
    _ = @import("env_value.zig");
    _ = @import("env_pair.zig");
    _ = @import("buffer_utils.zig");
    _ = @import("whitespace_utils.zig");
    _ = @import("escape_processor.zig");
    _ = @import("quote_parser.zig");
    _ = @import("interpolation.zig");
    _ = @import("finalizer.zig");
    _ = @import("reader.zig");
    _ = @import("memory.zig");
    _ = @import("lib.zig");
}
