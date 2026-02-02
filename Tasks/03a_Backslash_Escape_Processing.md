# Task 03a: Backslash and Escape Processing

## Objective
Implement the escape sequence processing functions that handle backslashes and control character conversion.

## Estimated Time
1-2 hours

## Background
The .env parser processes escape sequences in double-quoted and backtick-quoted values. Backslashes are processed in pairs, and certain escape sequences like `\n`, `\t` are converted to their actual control characters.

## Functions to Implement

### 1. walk_back_slashes (`src/escape_processor.zig`)
- **C++ Reference**: `EnvReader::walk_back_slashes(EnvValue* value)` (lines 495-503)
- **Purpose**: Convert pairs of `\\` to single `\`, leave odd backslash for control char processing
- **C++ Logic**:
  ```cpp
  void EnvReader::walk_back_slashes(EnvValue* value) {
    if (const int total_backslash_pairs = value->back_slash_streak / 2; total_backslash_pairs > 0) {
      for (int i = 0; i < total_backslash_pairs; i++) {
        add_to_buffer(value, '\\');
      }
      value->back_slash_streak -= total_backslash_pairs * 2;
    }
  }
  ```
- **How it works**:
  - If `back_slash_streak` is 4: output 2 backslashes, streak becomes 0
  - If `back_slash_streak` is 3: output 1 backslash, streak becomes 1 (for escape processing)
  - If `back_slash_streak` is 2: output 1 backslash, streak becomes 0
  - If `back_slash_streak` is 1: output nothing, streak stays 1 (for escape processing)
- **Signature**: `fn walkBackSlashes(value: *EnvValue) !void`

### 2. process_possible_control_character (`src/escape_processor.zig`)
- **C++ Reference**: `EnvReader::process_possible_control_character(...)` (lines 454-493)
- **Purpose**: Convert escape sequences to actual control characters
- **Returns**: `bool` - true if character was processed as control char, false otherwise
- **Escape sequence mappings**:
  | Sequence | Result | Value |
  |----------|--------|-------|
  | `\t` | tab | 0x09 |
  | `\n` | newline | 0x0A |
  | `\r` | carriage return | 0x0D |
  | `\b` | backspace | 0x08 |
  | `\f` | form feed | 0x0C |
  | `\v` | vertical tab | 0x0B |
  | `\a` | alert/bell | 0x07 |
  | `\"` | double quote | 0x22 |
  | `\'` | single quote | 0x27 |
  | `\\` | backslash | 0x5C |
- **Signature**: `fn processPossibleControlCharacter(value: *EnvValue, char: u8) !bool`
- **C++ Logic** (simplified):
  ```cpp
  bool EnvReader::process_possible_control_character(EnvValue* value, const char key_char) {
    auto process = false;
    switch (key_char) {
      case 't': add_to_buffer(value, '\t'); process = true; break;
      case 'n': add_to_buffer(value, '\n'); process = true; break;
      case 'r': add_to_buffer(value, '\r'); process = true; break;
      case 'b': add_to_buffer(value, '\b'); process = true; break;
      case 'f': add_to_buffer(value, '\f'); process = true; break;
      case 'v': add_to_buffer(value, '\v'); process = true; break;
      case 'a': add_to_buffer(value, '\a'); process = true; break;
      case '"': add_to_buffer(value, '"'); process = true; break;
      case '\'': add_to_buffer(value, '\''); process = true; break;
      case '\\': add_to_buffer(value, '\\'); process = true; break;
      default: 
        // Not a recognized escape - add literal backslash then the char
        add_to_buffer(value, '\\');
        add_to_buffer(value, key_char);
        break;
    }
    value->back_slash_streak = 0;
    return process;
  }
  ```

## Escape Processing Flow

```
Input: "hello\\n\\\\world"

Parsing:
1. 'h', 'e', 'l', 'l', 'o' → added to buffer
2. '\' → back_slash_streak = 1
3. '\' → back_slash_streak = 2
4. 'n' → call walkBackSlashes() → outputs 1 '\' to buffer
        → back_slash_streak = 0
        → 'n' added as literal 'n'
5. '\' → back_slash_streak = 1
6. '\' → back_slash_streak = 2
7. '\' → back_slash_streak = 3
8. '\' → back_slash_streak = 4
9. 'w' → call walkBackSlashes() → outputs 2 '\' to buffer
        → back_slash_streak = 0
        → 'w' added to buffer
...

Result: "hello\\n\\\\world"
```

**With escape processing enabled (double quotes):**
```
Input: "hello\n\\world"

1. 'h', 'e', 'l', 'l', 'o' → buffer
2. '\' → back_slash_streak = 1
3. 'n' → walkBackSlashes() does nothing (streak=1, no pairs)
        → processPossibleControlCharacter('\', 'n')
        → outputs newline (0x0A)
        → back_slash_streak = 0
4. '\' → back_slash_streak = 1
5. '\' → back_slash_streak = 2
6. 'w' → walkBackSlashes() → outputs 1 '\'
        → back_slash_streak = 0
        → 'w' added

Result: "hello
\world"  (actual newline in string)
```

## Checklist

- [ ] Create `src/escape_processor.zig`
- [ ] Implement `walkBackSlashes` function
- [ ] Implement `processPossibleControlCharacter` function
- [ ] Add tests for backslash processing:
  - [ ] Even number of backslashes (2, 4, 6)
  - [ ] Odd number of backslashes (1, 3, 5)
  - [ ] Zero backslashes
- [ ] Add tests for all control characters:
  - [ ] `\t` → tab
  - [ ] `\n` → newline
  - [ ] `\r` → carriage return
  - [ ] `\b` → backspace
  - [ ] `\f` → form feed
  - [ ] `\v` → vertical tab
  - [ ] `\a` → alert
  - [ ] `\"` → quote
  - [ ] `\'` → quote
  - [ ] `\\` → backslash
- [ ] Add tests for unrecognized escapes:
  - [ ] `\x` → should output `\x` literally
  - [ ] `\z` → should output `\z` literally
- [ ] Update `src/root.zig` to export new module

## Dependencies
- Task 01b (Key and Value Structures) - needs EnvValue
- Task 02 (Buffer Management) - needs addToBuffer

## Test Cases from C++ Tests
Reference these C++ test cases when implementing:
- `DotEnvTest::ControlCodes` - escape sequence processing
- `DotEnvTest::DoubleQuotes` - basic escapes in double quotes

## Notes
- **Single quotes disable ALL escape processing** - `'\n'` stays as literal `\n`
- **Double quotes enable escape processing** - `"\n"` becomes newline
- Triple single quotes (heredoc) also disable escape processing
- Triple double quotes (heredoc) enable escape processing
- The backslash processing happens BEFORE control character detection
- If an unrecognized escape like `\x` is encountered, both the backslash and 'x' are added literally

## Files to Create
- `src/escape_processor.zig`
