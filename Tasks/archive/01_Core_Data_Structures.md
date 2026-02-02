# Task 01: Core Data Structures

## Objective
Convert the fundamental C++ data structures from `node_dotenv.h` to Zig, establishing the foundation for the entire .env parser.

## Background
The C++ implementation uses several interconnected structs with raw pointer management. In Zig, we'll use proper allocator patterns and error handling idioms.

## Structures to Implement

### 1. EnvStream (`src/env_stream.zig`)
- **Purpose**: String stream wrapper for reading character-by-character
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

### 2. VariablePosition (`src/variable_position.zig`)
- **Purpose**: Tracks position and details of `${variable}` interpolations
- **C++ Fields to convert**:
  - `variable_start: int` → `variable_start: usize`
  - `start_brace: int` → `start_brace: usize`
  - `dollar_sign: int` → `dollar_sign: usize`
  - `end_brace: int` → `end_brace: usize`
  - `variable_end: int` → `variable_end: usize`
  - `variable_str: std::string*` → `variable_str: []const u8`
  - `closed: bool` → `closed: bool`
- **Methods to implement**:
  - `init(variable_start, start_brace, dollar_sign) VariablePosition`
  - `deinit(allocator) void` - Clean up owned memory
- **Zig considerations**:
  - Use `usize` for all indices (no negative values)
  - Allocator-aware memory management

### 3. EnvKey (`src/env_key.zig`)
- **Purpose**: Represents a parsed environment variable key
- **C++ Fields to convert**:
  - `key: std::string*` → `key: []const u8`
  - `own_buffer: std::string*` → `own_buffer: ?[]u8`
  - `key_index: int` → `key_index: usize`
- **Methods to implement**:
  - `init() EnvKey`
  - `deinit(allocator) void`
  - `clipOwnBuffer(length: usize) void`
  - `hasOwnBuffer() bool`
  - `setOwnBuffer(allocator, buff: []u8) void`
- **Zig considerations**:
  - Optional type for own_buffer (`?[]u8`)
  - Allocator pattern for buffer ownership

### 4. EnvValue (`src/env_value.zig`)
- **Purpose**: Represents a parsed environment variable value with interpolation support
- **C++ Fields to convert**:
  - `value: std::string*` → `value: []const u8`
  - `interpolations: std::vector<VariablePosition*>*` → `interpolations: std.ArrayList(VariablePosition)`
  - `is_parsing_variable: bool` → `is_parsing_variable: bool`
  - `interpolation_index: int` → `interpolation_index: usize`
  - **Quote tracking flags** (6 booleans)
  - **Parsing state** (3 integers for streaks)
  - **Interpolation state** (3 booleans)
  - `own_buffer: std::string*` → `own_buffer: ?[]u8`
  - `value_index: int` → `value_index: usize`
- **Methods to implement**:
  - `init(allocator) EnvValue`
  - `deinit(allocator) void`
  - `clipOwnBuffer(length: usize) void`
  - `hasOwnBuffer() bool`
  - `setOwnBuffer(allocator, buff: []u8) void`
- **Zig considerations**:
  - Use `std.ArrayList` instead of `std::vector`
  - Ensure proper cleanup of all interpolations on deinit

### 5. EnvPair (`src/env_pair.zig`)
- **Purpose**: Key-value pair container
- **C++ Fields to convert**:
  - `key: EnvKey*` → `key: *EnvKey` or embedded `key: EnvKey`
  - `value: EnvValue*` → `value: *EnvValue` or embedded `value: EnvValue`
- **Design decision needed**: Embed or reference?
  - Embedding avoids extra allocations
  - Pointers match C++ semantics more closely
- **Methods to implement**:
  - `init(allocator) EnvPair`
  - `deinit(allocator) void`

### 6. Result Enums (`src/result_enums.zig`)
- **C++ enums to convert**:
  ```cpp
  enum read_result { success, empty, fail, comment_encountered, end_of_stream_key, end_of_stream_value };
  enum finalize_result { interpolated, copied, circular };
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

- [ ] Create `src/` directory structure
- [ ] Implement `EnvStream` with tests
- [ ] Implement `VariablePosition` with tests
- [ ] Implement `EnvKey` with tests
- [ ] Implement `EnvValue` with tests
- [ ] Implement `EnvPair` with tests
- [ ] Implement result enums
- [ ] Create root module (`src/root.zig`) that exports all types
- [ ] Verify all tests pass with `zig build test`

## Testing Strategy
Each struct should have unit tests verifying:
- Initialization
- Memory cleanup (no leaks)
- Basic operations
- Edge cases (empty data, null buffers, etc.)

## Dependencies
- None (this is the foundation)

## Notes
- Follow the "one struct per file" policy
- Use Zig naming conventions (camelCase for functions, snake_case for variables)
- All allocations must be paired with deallocations
- Consider using `std.testing.allocator` for leak detection in tests
