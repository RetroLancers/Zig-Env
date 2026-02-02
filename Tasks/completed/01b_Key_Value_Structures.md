# Task 01b: Key and Value Structures

## Objective
Implement the complex data structures: `EnvKey`, `EnvValue`, and `EnvPair`.

## Estimated Time
2-3 hours

## Background
These structures have complex state tracking and buffer management. They are more intricate than the basic types and require careful implementation of memory ownership patterns.

## Structures to Implement

### 1. EnvKey (`src/env_key.zig`)
- **Purpose**: Represents a parsed environment variable key
- **C++ Reference**: `node_dotenv.h` EnvKey struct
- **C++ Fields to convert**:
  - `key: std::string*` → `key: []const u8`
  - `own_buffer: std::string*` → `own_buffer: ?[]u8`
  - `key_index: int` → `key_index: usize`
- **Methods to implement**:
  - `init() EnvKey`
  - `deinit(allocator: std.mem.Allocator) void`
  - `clipOwnBuffer(allocator: std.mem.Allocator, length: usize) !void`
  - `hasOwnBuffer() bool`
  - `setOwnBuffer(allocator: std.mem.Allocator, buffer: []u8) void`
- **Zig considerations**:
  - Optional type for own_buffer (`?[]u8`)
  - Allocator pattern for buffer ownership
  - `key` points to either shared buffer or own_buffer

### 2. EnvValue (`src/env_value.zig`)
- **Purpose**: Represents a parsed environment variable value with interpolation support
- **C++ Reference**: `node_dotenv.h` EnvValue struct
- **C++ Fields to convert**:
  - `value: std::string*` → `value: []const u8`
  - `interpolations: std::vector<VariablePosition*>*` → `interpolations: std.ArrayList(VariablePosition)`
  - `is_parsing_variable: bool` → `is_parsing_variable: bool`
  - `interpolation_index: int` → `interpolation_index: usize`
  - **Quote tracking flags** (6 booleans):
    - `quoted: bool`
    - `double_quoted: bool`
    - `backtick_quoted: bool`
    - `triple_quoted: bool`
    - `triple_double_quoted: bool`
    - `implicit_double_quote: bool`
  - **Parsing state** (3 integers for streaks):
    - `single_quote_streak: int` → `single_quote_streak: usize`
    - `double_quote_streak: int` → `double_quote_streak: usize`
    - `back_slash_streak: int` → `back_slash_streak: usize`
  - **Interpolation state** (3 booleans):
    - `is_being_interpolated: bool`
    - `is_already_interpolated: bool`
  - `own_buffer: std::string*` → `own_buffer: ?[]u8`
  - `value_index: int` → `value_index: usize`
- **Methods to implement**:
  - `init(allocator: std.mem.Allocator) !EnvValue`
  - `deinit(allocator: std.mem.Allocator) void`
  - `clipOwnBuffer(allocator: std.mem.Allocator, length: usize) !void`
  - `hasOwnBuffer() bool`
  - `setOwnBuffer(allocator: std.mem.Allocator, buffer: []u8) void`
- **Zig considerations**:
  - Use `std.ArrayList(VariablePosition)` instead of `std::vector`
  - Ensure proper cleanup of all interpolations on deinit
  - Many boolean flags - consider if they can be grouped into an enum or struct

### 3. EnvPair (`src/env_pair.zig`)
- **Purpose**: Key-value pair container
- **C++ Reference**: `node_dotenv.h` EnvPair struct
- **C++ Fields to convert**:
  - `key: EnvKey*` → `key: EnvKey`
  - `value: EnvValue*` → `value: EnvValue`
- **Design decision**: Embed structs directly (not pointers)
  - Embedding avoids extra allocations
  - Simpler memory management
  - Still compatible with C++ semantics
- **Methods to implement**:
  - `init(allocator: std.mem.Allocator) !EnvPair`
  - `deinit(allocator: std.mem.Allocator) void`

## Checklist

- [x] Implement `EnvKey` in `src/env_key.zig`
  - [x] All struct fields
  - [x] `init` function
  - [x] `deinit` function
  - [x] `clipOwnBuffer` function
  - [x] `hasOwnBuffer` function
  - [x] `setOwnBuffer` function
- [x] Add tests for `EnvKey`:
  - [x] Initialization
  - [x] Buffer ownership
  - [x] Clipping buffer
  - [x] Memory cleanup
- [x] Implement `EnvValue` in `src/env_value.zig`
  - [x] All struct fields
  - [x] `init` function
  - [x] `deinit` function (with interpolations cleanup)
  - [x] `clipOwnBuffer` function
  - [x] `hasOwnBuffer` function
  - [x] `setOwnBuffer` function
- [x] Add tests for `EnvValue`:
  - [x] Initialization
  - [x] Interpolations ArrayList management
  - [x] Quote state flags
  - [x] Memory cleanup
- [x] Implement `EnvPair` in `src/env_pair.zig`
  - [x] Embedded key and value
  - [x] `init` function
  - [x] `deinit` function
- [x] Add tests for `EnvPair`:
  - [x] Initialization
  - [x] Memory cleanup (cascading deinit)
- [x] Update `src/root.zig` to export new types
- [x] Verify all tests pass with `zig build test`

## Testing Strategy
Each struct should have unit tests verifying:
- Initialization
- Memory cleanup (no leaks)
- Buffer ownership transitions (shared → owned)
- Edge cases (null buffers, empty interpolations, etc.)

## Dependencies
- Task 01a (Basic Data Structures) - needs VariablePosition

## Notes
- EnvValue is the most complex struct - take time to understand all the state flags
- The quote tracking flags are used during parsing to control behavior
- The "streak" counters track consecutive quote/backslash characters
- Interpolation state flags prevent circular dependency issues
- All allocations must be paired with deallocations
- Use `std.testing.allocator` for leak detection in tests

## Files to Create
- `src/env_key.zig`
- `src/env_value.zig`
- `src/env_pair.zig`
