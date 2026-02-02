# Task 01a: Basic Data Structures

## Objective
Implement the foundational data structures: `EnvStream`, `VariablePosition`, and result enums.

## Estimated Time
1-2 hours

## Background
These are the simplest, most foundational types in the parser. They have minimal interdependencies and can be implemented and tested independently.

## Structures to Implement

### 1. EnvStream (`src/env_stream.zig`)
- **Purpose**: String stream wrapper for reading character-by-character
- **C++ Reference**: `node_dotenv.h` EnvStream class
- **C++ Fields to convert**:
  - `index_: size_t` → `index: usize`
  - `data_: std::string*` → `data: []const u8`
  - `length_: size_t` → `length: usize`
  - `is_good_: bool` → `is_good: bool`
- **Methods to implement**:
  - `init(data: []const u8) EnvStream`
  - `get() ?u8` - Read next char and advance (return null on EOF)
  - `good() bool` - Check if stream is valid
  - `eof() bool` - Check if end of stream
- **Zig considerations**:
  - Use slice instead of pointer to string
  - Return optional `?u8` instead of -1 for EOF
  - No allocator needed (no owned memory)

### 2. VariablePosition (`src/variable_position.zig`)
- **Purpose**: Tracks position and details of `${variable}` interpolations
- **C++ Reference**: `node_dotenv.h` VariablePosition struct
- **C++ Fields to convert**:
  - `variable_start: int` → `variable_start: usize`
  - `start_brace: int` → `start_brace: usize`
  - `dollar_sign: int` → `dollar_sign: usize`
  - `end_brace: int` → `end_brace: usize`
  - `variable_end: int` → `variable_end: usize`
  - `variable_str: std::string*` → `variable_str: []const u8`
  - `closed: bool` → `closed: bool`
- **Methods to implement**:
  - `init(variable_start: usize, start_brace: usize, dollar_sign: usize) VariablePosition`
  - `deinit(allocator: std.mem.Allocator) void` - Clean up owned memory
- **Zig considerations**:
  - Use `usize` for all indices (no negative values)
  - Allocator-aware memory management for `variable_str`
  - `variable_str` will be allocated when the variable is finalized

### 3. Result Enums (`src/result_enums.zig`)
- **Purpose**: Define return types for parsing operations
- **C++ Reference**: `node_dotenv.h` read_result and finalize_result enums
- **C++ enums to convert**:
  ```cpp
  enum read_result { 
    success, 
    empty, 
    fail, 
    comment_encountered, 
    end_of_stream_key, 
    end_of_stream_value 
  };
  
  enum finalize_result { 
    interpolated, 
    copied, 
    circular 
  };
  ```
- **Zig implementation**:
  ```zig
  pub const ReadResult = enum {
      success,
      empty,
      fail,
      comment_encountered,
      end_of_stream_key,
      end_of_stream_value,
  };
  
  pub const FinalizeResult = enum {
      interpolated,
      copied,
      circular,
  };
  ```

## Checklist

- [x] Create `src/` directory if it doesn't exist
- [x] Implement `EnvStream` in `src/env_stream.zig`
  - [x] `init` function
  - [x] `get` method
  - [x] `good` method
  - [x] `eof` method
- [x] Add tests for `EnvStream`:
  - [x] Basic reading
  - [x] EOF detection
  - [x] Empty stream
  - [x] Stream state tracking
- [x] Implement `VariablePosition` in `src/variable_position.zig`
  - [x] `init` function
  - [x] `deinit` function
- [x] Add tests for `VariablePosition`:
  - [x] Initialization
  - [x] Memory cleanup
- [x] Implement result enums in `src/result_enums.zig`
  - [x] `ReadResult` enum
  - [x] `FinalizeResult` enum
- [x] Create root module (`src/root.zig`) that exports all types
- [x] Verify all tests pass with `zig build test`

## Testing Strategy
Each struct should have unit tests verifying:
- Initialization with various inputs
- Memory cleanup (no leaks)
- Basic operations
- Edge cases (empty data, EOF behavior, etc.)

## Dependencies
- None (this is the foundation)

## Notes
- Follow the "one struct per file" policy
- Use Zig naming conventions (camelCase for functions, snake_case for variables)
- All allocations must be paired with deallocations
- Use `std.testing.allocator` for leak detection in tests
- These types are simple value types - focus on correctness and clarity

## Files to Create
- `src/env_stream.zig`
- `src/variable_position.zig`
- `src/result_enums.zig`
- `src/root.zig` (if it doesn't exist)
