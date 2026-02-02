# Task 05a: Basic Reading Functions

## Objective
Implement the basic utility functions for reading keys and clearing garbage from the stream.

## Estimated Time
1-2 hours

## Background
These are simpler helper functions that can be implemented and tested independently before tackling the complex value reading logic.

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
- **Usage**: After closing triple quotes or encountering comments, remaining line content is "garbage" that should be skipped

### 2. read_key (`src/reader.zig`)
- **C++ Reference**: `EnvReader::read_key(EnvStream* file, EnvKey* key)` (lines 382-422)
- **Purpose**: Parse the key portion of a key=value pair
- **Rules**:
  - Left-trim leading spaces
  - Accept any character except: newline, `=`, `#`
  - `#` at start (after spaces) triggers comment mode → clear to newline
  - `=` signals end of key
  - Spaces in middle of key are allowed (e.g., `my key=value`)
  - Windows line endings: `\r` is ignored
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
- **Return values**:
  - `success` - key read successfully, `=` found
  - `comment_encountered` - line was a comment
  - `fail` - invalid key (e.g., newline before `=`)
  - `end_of_stream_key` - EOF reached during key
  - `end_of_stream_value` - EOF right after `=`

## Key Parsing Examples

**Example 1: Simple key**
```
Input: "MY_KEY=value"

Process:
1. 'M', 'Y', '_', 'K', 'E', 'Y' → add to key
2. '=' → return success

Result: key = "MY_KEY"
```

**Example 2: Key with leading spaces**
```
Input: "  SPACED_KEY=value"

Process:
1. ' ', ' ' → skip (left trim, key_index == 0)
2. 'S', 'P', 'A', 'C', 'E', 'D', '_', 'K', 'E', 'Y' → add to key
3. '=' → return success

Result: key = "SPACED_KEY"
```

**Example 3: Key with internal spaces**
```
Input: "my key=value"

Process:
1. 'm', 'y' → add to key
2. ' ' → add to key (key_index > 0)
3. 'k', 'e', 'y' → add to key
4. '=' → return success

Result: key = "my key"
```

**Example 4: Comment line**
```
Input: "#this is a comment"

Process:
1. '#' → call clearGarbage()
   → consume until '\n'
   → return comment_encountered

Result: no key produced, skip to next line
```

**Example 5: Invalid key (newline before =)**
```
Input: "INVALID\n"

Process:
1. 'I', 'N', 'V', 'A', 'L', 'I', 'D' → add to key
2. '\n' → return fail

Result: invalid line, skip
```

## Checklist

- [ ] Create `src/reader.zig`
- [ ] Implement `clearGarbage` function
- [ ] Add tests for `clearGarbage`:
  - [ ] Clears to newline
  - [ ] Handles EOF
  - [ ] Doesn't consume past newline
- [ ] Implement `readKey` function
- [ ] Add tests for `readKey`:
  - [ ] Simple key `KEY=value`
  - [ ] Key with leading spaces `  SPACED_KEY=value`
  - [ ] Key with internal spaces `my key=value`
  - [ ] Comment line `#comment`
  - [ ] Invalid key `KEY\n`
  - [ ] Windows line endings `KEY\r\n`
  - [ ] EOF during key
  - [ ] EOF after `=`
- [ ] Update `src/root.zig` to export new module

## Dependencies
- Task 01a (Basic Data Structures) - needs EnvStream, ReadResult
- Task 01b (Key and Value Structures) - needs EnvKey

## Test Cases from C++ Tests
Reference these C++ test cases:
- `DotEnvTest::ReadDotEnvFile` - basic key reading
- `DotEnvTest::ImplicitDoubleQuote` - whitespace handling

## Notes
- Keys are relatively simple compared to values
- The `readKey` function doesn't need to handle quotes or escapes
- Left-trimming is automatic, but spaces within the key are preserved
- Comments can appear at the start of a line (after left-trimming)
- Windows line endings (`\r`) are silently ignored

## Files to Create/Modify
- `src/reader.zig` (create)
