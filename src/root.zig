const std = @import("std");

pub const ReusableBuffer = @import("reusable_buffer.zig").ReusableBuffer;
pub const EnvStream = @import("env_stream.zig").EnvStream;
pub const EnvKey = @import("env_key.zig").EnvKey;
pub const EnvValue = @import("env_value.zig").EnvValue;
pub const EnvPair = @import("env_pair.zig").EnvPair;
pub const VariablePosition = @import("variable_position.zig").VariablePosition;
pub const ReadResult = @import("result_enums.zig").ReadResult;
pub const FinalizeResult = @import("result_enums.zig").FinalizeResult;
pub const file_scanner = @import("file_scanner.zig");
pub const ParserOptions = @import("parser_options.zig").ParserOptions;

// Public API
pub const parse = @import("lib.zig").parse;
pub const parseFile = @import("lib.zig").parseFile;
pub const parseFileWithOptions = @import("lib.zig").parseFileWithOptions;
pub const parseString = @import("lib.zig").parseString;
pub const parseStringWithOptions = @import("lib.zig").parseStringWithOptions;
pub const parseReader = @import("lib.zig").parseReader;
pub const parseReaderWithOptions = @import("lib.zig").parseReaderWithOptions;
pub const Env = @import("lib.zig").Env;

// Tests
test {
    _ = @import("reusable_buffer.zig");
    _ = @import("env_stream.zig");
    _ = @import("env_key.zig");
    _ = @import("env_value.zig");
    _ = @import("env_pair.zig");
    _ = @import("variable_position.zig");
    _ = @import("result_enums.zig");
    _ = @import("buffer_utils.zig");
    _ = @import("whitespace_utils.zig");
    _ = @import("escape_processor.zig");
    _ = @import("quote_parser.zig");
    _ = @import("interpolation.zig");
    _ = @import("finalizer.zig");
    _ = @import("reader.zig");
    _ = @import("memory.zig");
    _ = @import("lib.zig");
    _ = @import("file_scanner.zig");
    _ = @import("parser_options.zig");
}
