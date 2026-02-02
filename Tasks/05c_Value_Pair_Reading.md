# Task 05c: Value and Pair Reading

## Objective  
Implement the orchestration functions that use `readNextChar` to parse complete values and pairs.

## Estimated Time
2 hours

## Background
With the complex `readNextChar` function complete, these functions are straightforward orchestration logic that tie everything together.

## Functions to Implement

### 1. read_value (`src/reader.zig`)
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

### 2. read_pair (`src/reader.zig`)
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

### 3. read_pairs (`src/reader.zig`)
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

## Checklist

- [ ] Continue `src/reader.zig` (from Task 05b)
- [ ] Implement `readValue` function
  - [ ] Main parsing loop
  - [ ] End-of-value cleanup logic
  - [ ] Handle remaining backslashes
  - [ ] Handle remaining quotes
  - [ ] Handle heredoc garbage clearing
  - [ ] Trim implicit double quote values
- [ ] Implement `readPair` function
  - [ ] Call readKey
  - [ ] Trim key
  - [ ] Copy key to own buffer
  - [ ] Call readValue
  - [ ] Copy value to own buffer
  - [ ] Remove unclosed interpolations
- [ ] Implement `readPairs` function
  - [ ] Loop until EOF
  - [ ] Create pairs
  - [ ] Handle different ReadResult cases
  - [ ] Memory management (free failed pairs)
- [ ] Add tests for `readValue`:
  - [ ] Simple values
  - [ ] Quoted values
  - [ ] Heredoc values
  - [ ] Values with escapes
  - [ ] Values with interpolation
- [ ] Add tests for `readPair`:
  - [ ] Simple pair
  - [ ] Pair with whitespace
  - [ ] Pair with quotes
- [ ] Add tests for `readPairs`:
  - [ ] Multiple pairs
  - [ ] Comments between pairs
  - [ ] Empty lines
  - [ ] Windows line endings
- [ ] Update `src/root.zig` to export if needed

## Dependencies
- Task 03a (Escape Processing)
- Task 03b (Quote Parsing)
- Task 04 (Variable Interpolation) - needs removeUnclosedInterpolation
- Task 05a (Basic Reading)
- Task 05b (Character State Machine)

## Test Cases from C++ Tests
- `DotEnvTest::ReadDotEnvFile` - multi-pair parsing
- `DotEnvTest::ImplicitDoubleQuote` - value trimming

## Notes
- The shared buffer pattern in C++ can be simplified in Zig
- Each pair can own its data from the start
- End-of-value cleanup is important - handles trailing quotes/backslashes
- Implicit double quote values need right-trimming
- Memory cleanup is critical for failed pairs

## Files to Modify
- `src/reader.zig` (completion)
