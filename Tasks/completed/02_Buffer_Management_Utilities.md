# Task 02: Buffer Management Utilities

## Objective
Implement character/string buffer utilities that replicate the C++ buffer management patterns in Zig.

## Estimated Time
1-2 hours

## Background
The C++ implementation uses a shared buffer pattern where EnvKey and EnvValue share a temporary buffer, then copy to their own buffer when needed. This requires careful buffer management functions.

## Functions to Implement

### 1. add_to_buffer (`src/buffer_utils.zig`)
- **C++ Reference**: `EnvReader::add_to_buffer(EnvValue* value, char key_char)`
- **Purpose**: Add a character to the value buffer, resizing if needed
- **C++ Logic**:
  ```cpp
  void EnvReader::add_to_buffer(EnvValue* value, const char key_char) {
    size_t size = value->value->size();
    if (static_cast<size_t>(value->value_index) >= size) {
      if (size == 0) {
        size = 100;
      }
      value->value->resize(size * 150 / 100);
    }
    (*value->value)[value->value_index] = key_char;
    value->value_index++;
  }
  ```
- **Zig implementation approach**:
  - Use `std.ArrayList(u8)` for dynamic resizing
  - Or use allocator to manually resize slice
  - Consider `ensureTotalCapacity` for efficient resizing
- **Signature**: `fn addToBuffer(value: *EnvValue, char: u8) !void`

### 2. is_previous_char_an_escape (`src/buffer_utils.zig`)
- **C++ Reference**: `EnvReader::is_previous_char_an_escape(const EnvValue* value)`
- **Purpose**: Check if the character 2 positions back is a backslash
- **Used for**: Detecting escaped `{` and `}` in variable interpolation
- **C++ Logic**:
  ```cpp
  bool EnvReader::is_previous_char_an_escape(const EnvValue* value) {
    return value->value_index > 1 && value->value->at(value->value_index - 2) == '\\';
  }
  ```
- **Signature**: `fn isPreviousCharAnEscape(value: *const EnvValue) bool`

### 3. get_white_space_offset_left (`src/whitespace_utils.zig`)
- **C++ Reference**: `EnvReader::get_white_space_offset_left(...)`
- **Purpose**: Count left whitespace inside `${...}` for trimming
- **C++ Logic**:
  ```cpp
  int EnvReader::get_white_space_offset_left(const std::string* value, const VariablePosition* interpolation) {
    int tmp = interpolation->variable_start;
    int size = 0;
    while (tmp >= interpolation->start_brace) {
      if (value->at(tmp) != ' ') break;
      tmp = tmp - 1;
      size = size + 1;
    }
    return size;
  }
  ```
- **Signature**: `fn getWhiteSpaceOffsetLeft(value: []const u8, interpolation: *const VariablePosition) usize`

### 4. get_white_space_offset_right (`src/whitespace_utils.zig`)
- **C++ Reference**: `EnvReader::get_white_space_offset_right(...)`
- **Purpose**: Count right whitespace inside `${...}` for trimming
- **Signature**: `fn getWhiteSpaceOffsetRight(value: []const u8, interpolation: *const VariablePosition) usize`

## Design Considerations

### Buffer Strategy Options

**Option A: ArrayList-based (Recommended)**
```zig
// EnvValue would contain:
buffer: std.ArrayList(u8),

// addToBuffer becomes:
fn addToBuffer(value: *EnvValue, char: u8) !void {
    try value.buffer.append(char);
}
```
Pros: Simple, automatic growth, standard Zig pattern
Cons: Different from C++ shared buffer model

**Option B: Manual slice management (C++ parity)**
```zig
// EnvValue would contain:
value: []u8,
value_capacity: usize,
allocator: std.mem.Allocator,

// addToBuffer becomes:
fn addToBuffer(value: *EnvValue, char: u8) !void {
    if (value.value_index >= value.value_capacity) {
        // Manually resize
    }
    value.value[value.value_index] = char;
    value.value_index += 1;
}
```
Pros: Matches C++ behavior closely
Cons: More error-prone, duplicates ArrayList functionality

### Recommendation
Use **Option A** (ArrayList) for value building, then convert to owned slice when finalized. This is more idiomatic Zig while still achieving the same result.

## Checklist

- [x] Create `src/buffer_utils.zig`
- [x] Implement `addToBuffer` function
- [x] Implement `isPreviousCharAnEscape` function
- [x] Create `src/whitespace_utils.zig`
- [x] Implement `getWhiteSpaceOffsetLeft` function
- [x] Implement `getWhiteSpaceOffsetRight` function
- [x] Add comprehensive tests for each function:
  - [x] `addToBuffer` with growing buffer
  - [x] `isPreviousCharAnEscape` with various positions
  - [x] Whitespace functions with edge cases
- [x] Test edge cases:
  - [x] Empty buffer
  - [x] Single character buffer
  - [x] Buffer at exactly capacity boundary
  - [x] Whitespace at various positions
- [x] Update `src/root.zig` to export new modules

## Dependencies
- Task 01b (Key and Value Structures) - needs EnvValue, VariablePosition

## Notes
- Memory safety is paramount - all allocations must be tracked
- Use `std.testing.allocator` to detect leaks in tests
- The C++ code uses 150% growth factor; consider Zig's standard growth strategies
- These are utility functions used throughout the parser

## Files to Create
- `src/buffer_utils.zig`
- `src/whitespace_utils.zig`
