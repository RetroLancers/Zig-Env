# CPPNV Mind Map - C++ to Zig Conversion Blueprint

## Project Overview
**Purpose**: A C++ .env (dotenv) file interpreter that parses environment variable files with support for variable interpolation, multiple quote types, and heredocs.

---

## 1. Core Data Structures

### 1.1 EnvStream
- **Purpose**: String stream wrapper for reading character-by-character
- **Fields**:
  - `index_` (size_t) - Current read position
  - `data_` (std::string*) - Pointer to string data
  - `length_` (size_t) - Length of string
  - `is_good_` (bool) - Stream state flag
- **Methods**:
  - `get()` - Read next char and advance
  - `good()` - Check if stream is valid
  - `eof()` - Check if end of stream

### 1.2 EnvKey
- **Purpose**: Represents a parsed environment variable key
- **Fields**:
  - `key` (std::string*) - Shared temp buffer or own buffer
  - `own_buffer` (std::string*) - Independent buffer if needed
  - `key_index` (int) - Current index in buffer
- **Methods**:
  - `clip_own_buffer()` - Resize buffer to specific length
  - `has_own_buffer()` - Check if owns independent buffer
  - `set_own_buffer()` - Set and take ownership of buffer

### 1.3 EnvValue
- **Purpose**: Represents a parsed environment variable value with interpolation support
- **Fields**:
  - `value` (std::string*) - The value string
  - `own_buffer` (std::string*) - Independent buffer if needed
  - `interpolations` (std::vector<VariablePosition*>*) - List of ${var} references
  - `is_parsing_variable` (bool) - Currently inside ${...}
  - `interpolation_index` (int) - Current interpolation being parsed
  - `value_index` (int) - Current position in value
  - **Quote tracking**:
    - `quoted` (bool) - Single quoted '
    - `triple_quoted` (bool) - Triple single quoted '''
    - `double_quoted` (bool) - Double quoted "
    - `triple_double_quoted` (bool) - Triple double quoted """
    - `implicit_double_quote` (bool) - Unquoted values treated as double-quoted
    - `back_tick_quoted` (bool) - Backtick quoted `
  - **Parsing state**:
    - `back_slash_streak` (int) - Consecutive backslashes
    - `single_quote_streak` (int) - Consecutive single quotes
    - `double_quote_streak` (int) - Consecutive double quotes
  - **Interpolation state**:
    - `is_already_interpolated` (bool) - Finalized
    - `is_being_interpolated` (bool) - Currently interpolating (circular detection)
    - `did_over_flow` (bool) - Buffer overflow flag
- **Methods**:
  - `clip_own_buffer()` - Resize buffer
  - `has_own_buffer()` - Check ownership
  - `set_own_buffer()` - Set buffer

### 1.4 VariablePosition
- **Purpose**: Tracks position and details of ${variable} interpolations
- **Fields**:
  - `variable_start` (int) - Start of variable name (after whitespace)
  - `start_brace` (int) - Position of {
  - `dollar_sign` (int) - Position of $
  - `end_brace` (int) - Position of }
  - `variable_end` (int) - End of variable name (before whitespace)
  - `variable_str` (std::string*) - Extracted variable name
  - `closed` (bool) - Whether } was found

### 1.5 EnvPair
- **Purpose**: Key-value pair container
- **Fields**:
  - `key` (EnvKey*)
  - `value` (EnvValue*)

---

## 2. Core Reading Logic (EnvReader)

### 2.1 High-Level Functions

#### read_pairs()
- **Input**: EnvStream*, vector<EnvPair*>*
- **Output**: int (count of pairs)
- **Logic**:
  - Loop until EOF
  - Create shared buffer (256 chars)
  - Create EnvPair pointing to shared buffer
  - Call read_pair()
  - On success: push to vector
  - On failure: delete and continue

#### read_pair()
- **Input**: EnvStream*, EnvPair*
- **Output**: read_result enum
- **Logic**:
  1. Call read_key() to parse key
  2. Trim right whitespace from key
  3. Copy key to own buffer if needed
  4. Call read_value() to parse value
  5. Copy value to own buffer if needed
  6. Call remove_unclosed_interpolation()
- **Returns**: success, fail, empty, comment_encountered, end_of_stream_key, end_of_stream_value

### 2.2 Key Parsing

#### read_key()
- **Input**: EnvStream*, EnvKey*
- **Output**: read_result
- **Logic**:
  - Left-trim spaces
  - Accept any character except: newline, =, #
  - '#' triggers comment mode (clear to newline)
  - '=' signals end of key
  - Allow spaces in middle of key
- **Valid chars**: Anything except \n, =, # (at start)

#### clear_garbage()
- Consumes characters until newline
- Used after comments or quoted values to ignore trailing content

### 2.3 Value Parsing

#### read_value()
- **Input**: EnvStream*, EnvValue*
- **Output**: read_result
- **Logic**:
  - Loop through characters
  - Call read_next_char() for each
  - Handle end-of-value cleanup:
    - Process trailing backslashes
    - Process trailing quotes
    - Trim implicit double quotes
  - Clear garbage if triple-quoted and line continues

#### read_next_char()
- **Input**: EnvValue*, char
- **Output**: bool (continue reading)
- **Main State Machine**:
  1. **Backslash handling**: Process control codes unless in single quotes
  2. **Quote tracking**: Detect start/end of quoted strings
  3. **Special first character logic**:
     - Backtick → backtick-quoted mode
     - '#' → empty value (comment)
     - Not quote → implicit double quote mode
  4. **Character-specific logic**:
     - '\\' → Increment backslash streak (unless in single quotes)
     - '{' → Open variable interpolation (if after $)
     - '}' → Close variable interpolation
     - '\'' → Track single quote streaks
     - '"' → Track double quote streaks
     - '\n' → End value (unless heredoc)
     - '#' → End implicit quote value
     - backtick → End backtick quote

### 2.4 Quote Handling

#### walk_single_quotes()
- Detect: ', '', '''
- At start:
  - 1 quote → single quoted mode
  - 2 quotes → empty single quoted
  - 3 quotes → heredoc mode
  - 3+ quotes → heredoc with extra quotes added to buffer
- During parsing:
  - In single quote: any quote ends
  - In triple quote: need 3+ quotes to close

#### walk_double_quotes()
- Detect: ", "", """
- Same logic as walk_single_quotes but for double quotes

#### walk_back_slashes()
- Convert pairs of \\ to single \
- Leave odd backslash for control char processing

#### process_possible_control_character()
- **Input**: EnvValue*, char
- **Mappings**:
  - \t → tab
  - \n → newline
  - \r → carriage return
  - \b → backspace
  - \f → form feed
  - \v → vertical tab
  - \a → alert
  - \\" → double quote
  - \\' → single quote
  - \\\\ → backslash

### 2.5 Variable Interpolation

#### open_variable()
- Triggered by '{'
- Checks if $ preceded it (via position_of_dollar_last_sign)
- Creates new VariablePosition
- Sets is_parsing_variable = true

#### close_variable()
- Triggered by '}'
- Extracts variable name from value string
- Trims whitespace from variable name
- Sets closed = true
- Increments interpolation_index

#### position_of_dollar_last_sign()
- Searches backward from current position
- Looks for $ with only spaces between it and {
- Returns fail if escaped $ found

#### remove_unclosed_interpolation()
- Iterate through interpolations
- Remove any with closed = false
- Clean up memory

### 2.6 Interpolation Finalization

#### finalize_value()
- **Input**: EnvPair*, vector<EnvPair*>*
- **Output**: finalize_result (interpolated, copied, circular)
- **Logic**:
  1. If no interpolations: mark as done, return copied
  2. Mark as being_interpolated (circular detection)
  3. Create own buffer copy
  4. For each interpolation (reverse order):
     - Find matching key in pairs vector
     - If found variable is being_interpolated → circular dependency
     - If found variable not finalized → recursively finalize
     - Replace ${var} with finalized value
  5. Mark as already_interpolated
  - **Whitespace handling**: Trim spaces inside ${ var }

### 2.7 Memory Management

#### delete_pair()
- Delete key
- Delete value (which deletes interpolations)
- Delete pair

#### delete_pairs()
- Iterate and delete all pairs

---

## 3. Helper Functions

### Buffer Management
- `add_to_buffer()` - Add character to value buffer, resize if needed
- `clip_own_buffer()` - Resize to exact size
- `set_own_buffer()` - Take ownership of new buffer

### Whitespace Utilities
- `get_white_space_offset_left()` - Count left spaces in ${...}
- `get_white_space_offset_right()` - Count right spaces in ${...}

### State Checkers
- `is_previous_char_an_escape()` - Check if char before last is \\

---

## 4. Node.js Integration (node namespace)

### 4.1 Dotenv Class
- **Purpose**: High-level API for Node.js
- **Fields**:
  - `store_` (std::map<string, string>) - Parsed key-value pairs
- **Methods**:
  - `ParsePath()` - Read .env file from filesystem
  - `ParseLine()` - Parse single line (simple version)
  - `SetEnvironment()` - Apply to Node.js process.env
  - `AssignNodeOptionsIfAvailable()` - Special handling for NODE_OPTIONS
  - `GetPathFromArgs()` - Extract --env-file paths from CLI args

### 4.2 File I/O
- Uses libuv for file operations (uv_fs_*)
- Read file in 8KB chunks
- Create EnvStream from file contents
- Parse with EnvReader

---

## 5. Testing Coverage (test_dotenv.cc)

### Test Categories
1. **Basic Parsing**: Keys, values, spacing, comments
2. **Quote Types**: Single, double, backtick, implicit
3. **Heredocs**: Triple single ('''), triple double (""")
4. **Control Codes**: \t, \n, \r, \b, \f, \\, escape sequences
5. **Interpolation**: Basic ${var}, whitespace handling
6. **Advanced Interpolation**: Chained variables, circular detection
7. **Edge Cases**: Empty quotes, unclosed interpolations, garbage after quotes

---

## 6. Conversion Tasks Breakdown

### Phase 1: Core Data Structures
- [ ] EnvStream struct
- [ ] EnvKey struct
- [ ] EnvValue struct
- [ ] VariablePosition struct
- [ ] EnvPair struct
- [ ] Result enums (read_result, finalize_result)

### Phase 2: Character/String Utilities
- [ ] add_to_buffer function
- [ ] Buffer management (resize, copy)
- [ ] is_previous_char_an_escape function
- [ ] Whitespace offset functions

### Phase 3: Quote Parsing
- [ ] walk_single_quotes function
- [ ] walk_double_quotes function
- [ ] walk_back_slashes function
- [ ] process_possible_control_character function

### Phase 4: Variable Interpolation
- [ ] open_variable function
- [ ] close_variable function
- [ ] position_of_dollar_last_sign function
- [ ] remove_unclosed_interpolation function

### Phase 5: Core Reading
- [ ] clear_garbage function
- [ ] read_key function
- [ ] read_next_char function
- [ ] read_value function
- [ ] read_pair function
- [ ] read_pairs function

### Phase 6: Finalization
- [ ] finalize_value function (recursive interpolation)

### Phase 7: Memory Management
- [ ] delete_pair function
- [ ] delete_pairs function
- [ ] Proper allocator usage

### Phase 8: File I/O & Public API
- [ ] File reading (replace libuv with Zig std.fs)
- [ ] Simple line parser
- [ ] Public API design

### Phase 9: Testing
- [ ] Port all test cases
- [ ] Add additional Zig-specific tests

---

## 7. Key Zig Conversion Considerations

### Memory Management
- Replace raw pointers with Zig allocators
- Use `ArrayList` instead of `std::vector`
- Use `StringHashMap` instead of `std::map`
- Proper defer/errdefer for cleanup

### Error Handling
- Convert bool returns to `!void` or error unions
- Define custom error sets
- Use `try` for propagation

### String Handling
- Use `[]const u8` for strings
- Consider slices vs owned strings
- UTF-8 considerations

### File I/O
- Replace libuv with `std.fs`
- Use Zig's buffered reader patterns

### Testing
- Use Zig's built-in test framework
- Convert gtest assertions to Zig test expectations

### One Struct/Function Per File Policy
- Each struct gets its own file
- Each major function gets its own file
- Group related utilities

---

## 8. Dependencies to Remove/Replace

### C++ Dependencies
- `<map>` → Zig StringHashMap
- `<string>` → Zig slices/ArrayList(u8)
- `<vector>` → Zig ArrayList
- `<sstream>` → Custom stream implementation

### Node.js Dependencies
- `uv.h` → std.fs
- `env-inl.h` → Remove (Node-specific)
- `node_file.h` → Remove (Node-specific)
- `v8::String` → Remove (Node-specific)

---

## 9. Algorithm Complexity Notes

### Time Complexity
- **read_pairs**: O(n) where n = file length
- **finalize_value**: O(m * p) where m = # variables, p = # pairs (worst case with deep interpolation)
- **Circular detection**: Early termination on circular refs

### Space Complexity
- Temporary shared buffer reused across pairs
- Own buffers allocated only when needed
- Interpolation positions tracked per value

---

## 10. Special Features to Preserve

### Quote Behavior
- Single quotes: No interpolation, no escape codes
- Double quotes: Interpolation + escape codes
- Backticks: Like double quotes but different terminator
- Implicit: Unquoted values treated as double-quoted with trim + comment support
- Heredocs: Multi-line support

### Interpolation Features
- Whitespace trimming inside ${ var }
- Recursive resolution
- Circular dependency detection
- Order-independent (can reference variables defined later)

### Comment Handling
- '#' starts comment (except in quotes)
- Inline comments after values (implicit quote mode)
- Full-line comments

### Edge Cases
- Windows line endings (\r\n)
- Empty values
- Escaped delimiters
- Unclosed interpolations (ignored)
- Garbage after quoted values (ignored)
