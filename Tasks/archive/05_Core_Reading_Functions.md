# Task 05: Core Reading Functions

## Objective
Implement the main parsing functions that read keys, values, and pairs from the .env stream.

## Background
The core reading logic is a state machine that processes the input stream character by character, handling keys (everything before `=`), values (everything after `=`), and comments (lines starting with `#`).

## Functions to Implement

### 1. clear_garbage (`src/reader.zig`)
- **C++ Reference**: `EnvReader::clear_garbage(EnvStream* file)` (lines 337-348)
- **Purpose**: Consume characters until newline, used after quoted values or comments
- **C++ Logic**:
  ```cpp
  void EnvReader::clear_garbage(EnvStream* file) {
    char key_char;
    do {
      key_char = file->get();
      if (key_char < 0) break;
      if (!file->good()) break;
    } while (key_char != '\n');
  }
  ```
- **Signature**: `fn clearGarbage(stream: *EnvStream) void`

### 2. read_key (`src/reader.zig`)
- **C++ Reference**: `EnvReader::read_key(EnvStream* file, EnvKey* key)` (lines 382-422)
- **Purpose**: Parse the key portion of a key=value pair
- **Rules**:
  - Left-trim leading spaces
  - Accept any character except: newline, `=`, `#`
  - `#` at start (after spaces) triggers comment mode → clear to newline
  - `=` signals end of key
  - Spaces in middle of key are allowed (e.g., `my key=value`)
- **C++ Logic**:
  ```cpp
  EnvReader::read_result EnvReader::read_key(EnvStream* file, EnvKey* key) {
    if (!file->good()) return end_of_stream_key;
    
    while (file->good()) {
      const auto key_char = file->get();
      if (key_char < 0) break;
      if (key_char == '#') {
        clear_garbage(file);
        return comment_encountered;
      }
      switch (key_char) {
        case ' ':
          if (key->key_index == 0) continue;  // left trim
          key->key->push_back(key_char);
          key->key_index++;
          break;
        case '=':
          if (!file->good()) return end_of_stream_value;
          return success;
        case '\r': continue;
        case '\n': return fail;
        default:
          key->key->push_back(key_char);
          key->key_index++;
      }
      if (!file->good()) break;
    }
    return end_of_stream_key;
  }
  ```
- **Signature**: `fn readKey(stream: *EnvStream, key: *EnvKey) !ReadResult`

### 3. read_next_char (`src/reader.zig`)
- **C++ Reference**: `EnvReader::read_next_char(EnvValue* value, char key_char)` (lines 702-839)
- **Purpose**: Process a single character while parsing a value (main state machine)
- **Returns**: `bool` - true to continue reading, false to stop
- **This is the most complex function** - handles:
  - Backslash escape sequences (delegate to walkBackSlashes, processPossibleControlCharacter)
  - Quote tracking (delegate to walkSingleQuotes, walkDoubleQuotes)
  - First character special cases (backtick, `#`, implicit quote mode)
  - Variable interpolation (`{`, `}`) (delegate to openVariable, closeVariable)
  - Newlines (end value unless in heredoc)
  - All other characters
- **Signature**: `fn readNextChar(allocator: std.mem.Allocator, value: *EnvValue, char: u8) !bool`

### 4. read_value (`src/reader.zig`)
- **C++ Reference**: `EnvReader::read_value(EnvStream* file, EnvValue* value)` (lines 851-903)
- **Purpose**: Parse the value portion of a key=value pair
- **C++ Logic**:
  ```cpp
  EnvReader::read_result EnvReader::read_value(EnvStream* file, EnvValue* value) {
    if (!file->good()) return end_of_stream_value;
    
    char key_char = 0;
    while (file->good()) {
      key_char = file->get();
      if (key_char < 0) break;
      
      if (read_next_char(value, key_char) && file->good()) {
        continue;
      }
      break;
    }
    
    // End-of-value cleanup
    if (value->back_slash_streak > 0) {
      walk_back_slashes(value);
      if (value->back_slash_streak == 1) {
        process_possible_control_character(value, '\0');
      }
    }
    if (value->single_quote_streak > 0) {
      if (walk_single_quotes(value) && key_char != '\n') {
        clear_garbage(file);
      }
    }
    if ((value->triple_double_quoted || value->triple_quoted) && key_char != '\n') {
      clear_garbage(file);
    }
    if (value->double_quote_streak > 0) {
      if (walk_double_quotes(value) && key_char != '\n') {
        clear_garbage(file);
      }
    }
    // Trim right side of implicit double quote
    if (value->implicit_double_quote) {
      while (value->value_index > 0 && value->value->at(value->value_index - 1) == ' ') {
        value->value_index--;
      }
    }
    return success;
  }
  ```
- **Signature**: `fn readValue(allocator: std.mem.Allocator, stream: *EnvStream, value: *EnvValue) !ReadResult`

### 5. read_pair (`src/reader.zig`)
- **C++ Reference**: `EnvReader::read_pair(EnvStream* file, const EnvPair* pair)` (lines 215-286)
- **Purpose**: Parse a complete key=value pair
- **Flow**:
  1. Call read_key()
  2. Trim right whitespace from key
  3. Copy key to own buffer
  4. Call read_value()
  5. Copy value to own buffer
  6. Call remove_unclosed_interpolation()
- **Signature**: `fn readPair(allocator: std.mem.Allocator, stream: *EnvStream, pair: *EnvPair) !ReadResult`

### 6. read_pairs (`src/reader.zig`)
- **C++ Reference**: `EnvReader::read_pairs(EnvStream* file, vector<EnvPair*>* pairs)` (lines 289-322)
- **Purpose**: Parse all key=value pairs from the stream
- **C++ Logic**:
  ```cpp
  int EnvReader::read_pairs(EnvStream* file, std::vector<EnvPair*>* pairs) {
    int count = 0;
    auto buffer = std::string(256, '\0');
    
    while (true) {
      buffer.clear();
      EnvPair* pair = new EnvPair();
      pair->key = new EnvKey();
      pair->key->key = &buffer;  // shared buffer
      pair->value = new EnvValue();
      pair->value->value = &buffer;  // shared buffer
      
      const read_result result = read_pair(file, pair);
      if (result == end_of_stream_value) {
        pairs->push_back(pair);
        count++;
        break;
      }
      if (result == success) {
        pairs->push_back(pair);
        count++;
        continue;
      }
      
      delete pair->key;
      delete pair->value;
      delete pair;
      if (result == comment_encountered || result == fail) continue;
      break;
    }
    return count;
  }
  ```
- **Signature**: `fn readPairs(allocator: std.mem.Allocator, stream: *EnvStream) !std.ArrayList(EnvPair)`

## State Machine Diagram

```
                    ┌──────────────┐
                    │ START/NEWKEY │
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
      ┌───────┐       ┌─────────┐      ┌─────────┐
      │ SPACE │──────▶│   KEY   │      │ COMMENT │
      └───────┘       └────┬────┘      └────┬────┘
    (left-trim)            │                │
                           │ '='            │ (clear to newline)
                           ▼                │
                    ┌─────────────┐         │
                    │    VALUE    │         │
                    └──────┬──────┘         │
                           │                │
          ┌────────────────┴────────────────┤
          │                                 │
          ▼                                 ▼
    ┌───────────┐                    ┌──────────┐
    │ NEXT_PAIR │◀───────────────────│ CONTINUE │
    └───────────┘                    └──────────┘
```

## Checklist

- [ ] Create `src/reader.zig`
- [ ] Implement `clearGarbage` function
- [ ] Implement `readKey` function
- [ ] Implement `readNextChar` function (complex - may need multiple sub-functions)
- [ ] Implement `readValue` function
- [ ] Implement `readPair` function
- [ ] Implement `readPairs` function
- [ ] Add tests for key parsing:
  - [ ] Simple key `KEY=value`
  - [ ] Spaced key `  SPACED_KEY  =value`
  - [ ] Key with internal spaces `my key=value`
- [ ] Add tests for value parsing:
  - [ ] Unquoted values
  - [ ] Single quoted values
  - [ ] Double quoted values
  - [ ] Triple quoted (heredoc) values
  - [ ] Values with escape sequences
  - [ ] Values with interpolation markers
- [ ] Add tests for full pair parsing:
  - [ ] Multiple pairs
  - [ ] Comments between pairs
  - [ ] Empty lines
  - [ ] Windows line endings (`\r\n`)
- [ ] Update `src/root.zig` to export new module

## Dependencies
- Task 01 (Core Data Structures)
- Task 02 (Buffer Management)
- Task 03 (Quote Parsing)
- Task 04 (Variable Interpolation)

## Test Cases from C++ Tests

Reference these C++ test cases:
- `DotEnvTest::ReadDotEnvFile` - basic file parsing
- `DotEnvTest::ImplicitDoubleQuote` - unquoted values with comments/trimming
- `DotEnvTest::DoubleQuotedHereDoc*` - multi-line heredoc parsing

## Notes
- The shared buffer pattern in C++ can be simplified in Zig - each pair can own its data
- Windows line endings (`\r\n`) need to be handled - strip `\r` before `\n`
- The `readNextChar` function is the heart of the parser and has many edge cases
- Consider breaking `readNextChar` into smaller helper functions for maintainability
