# Task 03: Quote Parsing Functions

## Objective
Implement the quote parsing state machine functions that handle single quotes, double quotes, triple quotes (heredocs), and backtick quotes.

## Background
The .env parser supports multiple quote types with different behaviors:
- **Single quotes (`'`)**: No interpolation, no escape codes, literal values
- **Double quotes (`"`)**: Interpolation enabled, escape codes processed
- **Triple single quotes (`'''`)**: Heredoc mode, literal multi-line, no escapes
- **Triple double quotes (`"""`)**: Heredoc mode, multi-line with interpolation and escapes
- **Backticks (`` ` ``)**: Like double quotes but different terminator

## Functions to Implement

### 1. walk_single_quotes (`src/quote_parser.zig`)
- **C++ Reference**: `EnvReader::walk_single_quotes(EnvValue* value)` (lines 621-687)
- **Purpose**: Detect and process single quote sequences
- **Returns**: `bool` - true if end quotes detected and input should stop
- **Logic summary**:
  - At value_index == 0 (start of value):
    - 1 quote → enter single quoted mode
    - 2 quotes → empty single quoted value, end
    - 3 quotes → enter heredoc mode
    - 3+ quotes → heredoc with extra quotes added to buffer
  - During parsing:
    - In single quote: any quote ends the value
    - In triple quote: need 3+ quotes to close
- **Signature**: `fn walkSingleQuotes(value: *EnvValue) bool`

### 2. walk_double_quotes (`src/quote_parser.zig`)
- **C++ Reference**: `EnvReader::walk_double_quotes(EnvValue* value)` (lines 548-614)
- **Purpose**: Detect and process double quote sequences
- **Returns**: `bool` - true if end quotes detected and input should stop
- **Logic**: Same as walk_single_quotes but for double quotes
- **Signature**: `fn walkDoubleQuotes(value: *EnvValue) bool`

### 3. walk_back_slashes (`src/quote_parser.zig`)
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
- **Signature**: `fn walkBackSlashes(value: *EnvValue) !void`

### 4. process_possible_control_character (`src/quote_parser.zig`)
- **C++ Reference**: `EnvReader::process_possible_control_character(...)` (lines 454-493)
- **Purpose**: Convert escape sequences to actual control characters
- **Mappings**:
  | Sequence | Result |
  |----------|--------|
  | `\t` | tab (0x09) |
  | `\n` | newline (0x0A) |
  | `\r` | carriage return (0x0D) |
  | `\b` | backspace (0x08) |
  | `\f` | form feed (0x0C) |
  | `\v` | vertical tab (0x0B) |
  | `\a` | alert/bell (0x07) |
  | `\"` | double quote |
  | `\'` | single quote |
  | `\\` | backslash |
- **Returns**: `bool` - true if character was processed as control char
- **Signature**: `fn processPossibleControlCharacter(value: *EnvValue, char: u8) !bool`

## State Machine Documentation

### Quote State Transitions

```
Initial State: No quotes
  ↓
  ' → single_quote_streak++
  " → double_quote_streak++
  ` → backtick_quoted = true, double_quoted = true
  other → implicit_double_quote = true, double_quoted = true

After quote streak processed:
  single_quote_streak == 1 → quoted = true (single quoted mode)
  single_quote_streak == 2 → quoted = true, END (empty value)
  single_quote_streak == 3 → triple_quoted = true (heredoc)
  single_quote_streak > 3 → triple_quoted = true, extra quotes added to buffer
  
  (same pattern for double quotes)
```

### Escape Processing Flow

```
Backslash encountered (not in single/triple_single quoted):
  1. Increment back_slash_streak
  
Next non-backslash char:
  1. walkBackSlashes() - converts pairs to single backslashes
  2. If odd backslash remains (back_slash_streak == 1):
     - Try process_possible_control_character()
     - If not control char, add literal backslash to buffer
```

## Checklist

- [ ] Create `src/quote_parser.zig`
- [ ] Implement `walkSingleQuotes` function
- [ ] Implement `walkDoubleQuotes` function
- [ ] Implement `walkBackSlashes` function
- [ ] Implement `processPossibleControlCharacter` function
- [ ] Add tests for single quote handling:
  - [ ] Empty single quotes `''`
  - [ ] Normal single quotes `'value'`
  - [ ] Triple single quotes `'''heredoc'''`
  - [ ] Excess quotes `''''value''''`
- [ ] Add tests for double quote handling:
  - [ ] Empty double quotes `""`
  - [ ] Normal double quotes `"value"`
  - [ ] Triple double quotes `"""heredoc"""`
- [ ] Add tests for escape sequences:
  - [ ] All control characters
  - [ ] Escaped quotes
  - [ ] Multiple backslashes
- [ ] Add tests for backtick quotes
- [ ] Update `src/root.zig` to export new module

## Dependencies
- Task 01 (Core Data Structures) - needs EnvValue
- Task 02 (Buffer Management) - needs addToBuffer

## Test Cases from C++ Tests

Reference these C++ test cases when implementing:
- `DotEnvTest::DoubleQuotes` - basic double quote handling
- `DotEnvTest::SingleQuoted` - single quote behavior (no escapes/interpolation)
- `DotEnvTest::TripleSingleQuotedWithMoreGarbage` - heredoc with trailing garbage
- `DotEnvTest::BackTickQuote` - backtick quote behavior
- `DotEnvTest::ControlCodes` - escape sequence processing

## Notes
- Single quotes preserve EVERYTHING literally (no escapes, no interpolation)
- Double quotes process escapes and interpolation
- Backticks behave like double quotes but terminate differently
- Heredocs allow multi-line content
- After closing triple quotes, remaining content on line is "garbage" and ignored
