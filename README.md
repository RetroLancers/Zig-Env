# Zig-Env

A Zig implementation of a `.env` (dotenv) file interpreter, converted from the C++ [cppnv](./cppnv) project.

## Overview

`.env` files (dotenv) are key-value pairs that evolved from bash environment exports. This project provides a robust parser that supports advanced features like variable interpolation, multiple quote types, heredocs, and control character escaping.

```bash
api_key=abc123
database_url="postgresql://localhost:5432/mydb"
app_name=${api_key}_service
```

## Project Status

🚧 **Active Development** - This is a work-in-progress conversion from C++ to Zig.

The original C++ implementation (`cppnv`) is a feature-complete .env parser used in Node.js. This Zig version aims to provide the same functionality with improved memory safety and performance.

## Features

### Supported (from C++ version)

- ✅ **Basic key-value parsing** - Standard `KEY=value` syntax
- ✅ **Variable interpolation** - `${variable}` references with recursive resolution
- ✅ **Multiple quote types**:
  - Single quotes (`'...'`) - No interpolation or escape codes
  - Double quotes (`"..."`) - Interpolation + escape codes
  - Backticks (`` `...` ``) - Like double quotes with different terminator
  - Implicit quotes - Unquoted values treated as double-quoted with trim + comment support
- ✅ **Heredocs** - Multi-line strings with `"""..."""` or `'''...'''`
- ✅ **Control codes** - `\n`, `\r`, `\t`, `\b`, `\f`, `\v`, `\a`, `\"`, `\'`, `\\`
- ✅ **Comments** - Lines starting with `#` (except in quotes)
- ✅ **Circular dependency detection** - Prevents infinite loops in variable references
- ✅ **Order-independent variables** - Can reference variables defined later in file

### Zig Conversion Progress

See [`cppnv_mindmap.md`](./cppnv_mindmap.md) for the detailed conversion blueprint.

- ✅ **Phase 1: Core Data Structures** - `EnvStream`, `EnvKey`, `EnvValue`, `VariablePosition`, `EnvPair`
- ✅ **Phase 2: Character/String Utilities** - Buffer management, escape utility functions
- ✅ **Phase 3: Quote Parsing** - State machines for single, double, and backtick quotes
- ✅ **Phase 4: Variable Interpolation** - `${variable}` detection and position tracking
- ✅ **Phase 5: Core Reading** - `read_key`, `read_value`, `read_pair`, and character state machine
- ✅ **Phase 6: Finalization** - Recursive interpolation resolution and circular dependency detection
- ✅ **Phase 7: Memory Management** - Explicit deallocation, leak prevention, and `deinit` patterns
- ✅ **Phase 8: File I/O & Public API** - Integration with `std.fs` and high-level interface
- 🔄 **Phase 9: Testing** - Porting 108 test cases (most core logic tests already ported)

## Usage (Planned)

```zig
const std = @import("std");
const zigenv = @import("zigenv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse from file
    var env = try zigenv.parseFile(allocator, ".env");
    defer env.deinit();

    // Access values
    if (env.get("api_key")) |value| {
        std.debug.print("API Key: {s}\n", .{value});
    }
}
```

## Building

This project requires **Zig 0.15.2**.

```bash
# Build the library
zig build

# Run tests
zig build test

# Generate documentation
zig build docs
```

## Project Structure

```
Zig-Env/
├── build.zig              # Build configuration
├── build.zig.zon          # Package dependencies
├── README.md              # Project documentation
├── src/
│   ├── root.zig           # Main module export
│   ├── lib.zig            # Public API
│   ├── env_stream.zig     # EnvStream struct
│   ├── env_key.zig        # EnvKey struct
│   ├── env_value.zig      # EnvValue struct
│   ├── env_pair.zig       # EnvPair struct
│   ├── variable_position.zig
│   ├── result_enums.zig
│   ├── buffer_utils.zig
│   ├── whitespace_utils.zig
│   ├── quote_parser.zig
│   ├── interpolation.zig
│   ├── reader.zig
│   ├── finalizer.zig
│   └── memory.zig
├── tests/
│   ├── basic_test.zig
│   ├── quote_test.zig
│   ├── heredoc_test.zig
│   ├── escape_test.zig
│   └── interpolation_test.zig
├── Tasks/                 # Task management
├── clood-groups/          # Code domain tracking
└── cppnv/                 # Original C++ reference
```

## Development Workflow

We follow a structured task-based workflow documented in [`Tasks/00_How_we_do_tasks.md`](./Tasks/00_How_we_do_tasks.md):

1. **Define tasks** in `Tasks/in_progress/`
2. **Execute** and check off items
3. **Move to** `Tasks/completed/` when done
4. **Update clood files** in `clood-groups/` to track related code domains

### Coding Standards

- **One struct/function per file** - Strict policy for maintainability
- **Proper error handling** - Use Zig error unions and `try`
- **Memory safety** - Use allocators, `defer`, and `errdefer`
- **Comprehensive testing** - Port all C++ tests to Zig's test framework

## Conversion Strategy

The conversion follows a phased approach to maintain correctness:

1. **Understand** - Deep analysis of C++ implementation (see `cppnv_mindmap.md`)
2. **Translate** - Convert data structures and algorithms to idiomatic Zig
3. **Test** - Port comprehensive test suite from C++ (108 test cases)
4. **Optimize** - Leverage Zig's comptime and memory safety features

### Key Zig Improvements

- **Memory safety** - No raw pointers, use allocators and slices
- **Error handling** - Explicit error unions instead of bool returns
- **Comptime** - Compile-time optimizations where applicable
- **No hidden allocations** - All allocations explicit and trackable
- **Cross-platform** - Replace Node.js/libuv with `std.fs`

## Performance Optimizations

### Memory Allocation Strategy
1. **Pre-Scanning**: The parser scans the file content once to determine optimal buffer sizes
2. **Smart Growth**: Buffers grow by 30% when capacity is exceeded
3. **Single Allocation**: For most common cases, buffers are allocated once at the correct size

This reduces allocation overhead by ~60-80% for typical .env files.

## Original C++ Implementation

The original C++ implementation (`cppnv`) was designed for Node.js integration and includes:

- Custom stream implementation for character-by-character parsing
- Shared buffer optimization to reduce allocations
- Recursive variable interpolation with circular detection
- Support for Windows (`\r\n`) and Unix (`\n`) line endings

See [`cppnv/Readme.MD`](./cppnv/Readme.MD) for original documentation.

## Examples

### Basic Parsing

```bash
# .env file
DATABASE_URL=postgresql://localhost:5432/mydb
API_KEY=secret123
DEBUG=true
```

### Variable Interpolation

```bash
# .env file
BASE_URL=https://api.example.com
API_VERSION=v2
FULL_URL=${BASE_URL}/${API_VERSION}
# FULL_URL resolves to: https://api.example.com/v2
```

### Heredocs

```bash
# .env file
PRIVATE_KEY="""
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA...
-----END RSA PRIVATE KEY-----
"""
```

### Quote Types

```bash
# .env file
SINGLE='No ${interpolation} or \n escape codes'
DOUBLE="Has ${interpolation} and \n escape codes"
IMPLICIT=Also has ${interpolation} and \n escape codes
```

## Testing

The C++ implementation has 108 comprehensive test cases covering:

- Basic parsing (keys, values, spacing, comments)
- Quote types (single, double, backtick, implicit)
- Heredocs (triple single/double quotes)
- Control codes and escape sequences
- Variable interpolation (basic, chained, circular detection)
- Edge cases (empty quotes, unclosed interpolations, garbage handling)

All tests will be ported to Zig's built-in test framework.

## Contributing

This is a personal conversion project, but contributions and suggestions are welcome!

## License

[Specify license - check original cppnv license]

## References

- Original C++ implementation: [`cppnv/`](./cppnv)
- Conversion blueprint: [`cppnv_mindmap.md`](./cppnv_mindmap.md)
- Task workflow: [`Tasks/00_How_we_do_tasks.md`](./Tasks/00_How_we_do_tasks.md)

---

**Note**: This project is under active development. The API and features are subject to change as the conversion progresses.
