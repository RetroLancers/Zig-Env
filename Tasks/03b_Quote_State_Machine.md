# Task 03b: Quote State Machine

## Objective
Implement the quote detection and state machine functions that handle single quotes, double quotes, and heredocs (triple quotes).

## Estimated Time
2-3 hours

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
    - 1 quote → enter single quoted mode (`quoted = true`)
    - 2 quotes → empty single quoted value, end immediately
    - 3 quotes → enter heredoc mode (`triple_quoted = true`)
    - 3+ quotes → heredoc with extra quotes added to buffer
  - During parsing:
    - In single quote mode: any single quote ends the value
    - In triple quote mode: need 3+ quotes to close
    - After closing triple quotes, remaining line content is "garbage" (ignored)
- **Signature**: `fn walkSingleQuotes(value: *EnvValue) bool`

### 2. walk_double_quotes (`src/quote_parser.zig`)
- **C++ Reference**: `EnvReader::walk_double_quotes(EnvValue* value)` (lines 548-614)
- **Purpose**: Detect and process double quote sequences
- **Returns**: `bool` - true if end quotes detected and input should stop
- **Logic**: Same pattern as walk_single_quotes but for double quotes
  - At value_index == 0:
    - 1 quote → `double_quoted = true`
    - 2 quotes → empty, end
    - 3 quotes → `triple_double_quoted = true`
    - 3+ quotes → heredoc with extras
  - During parsing:
    - In double quote mode: single quote ends
    - In triple double quote mode: 3+ quotes close
- **Signature**: `fn walkDoubleQuotes(value: *EnvValue) bool`

## State Machine Documentation

### Quote State Transitions

```
Initial State: No quotes
  ↓
First character determines mode:
  ' → single_quote_streak++
  " → double_quote_streak++
  ` → backtick_quoted = true, double_quoted = true
  other → implicit_double_quote = true, double_quoted = true

After initial quote streak processed:
  single_quote_streak == 1 → quoted = true (single quoted mode)
  single_quote_streak == 2 → quoted = true, END (empty value)
  single_quote_streak == 3 → triple_quoted = true (heredoc)
  single_quote_streak > 3 → triple_quoted = true, extras added to buffer
  
  (same pattern for double quotes)

During parsing:
  • Single quoted: next ' ends value
  • Double quoted: next " ends value
  • Triple single quoted: need ''' to close
  • Triple double quoted: need """ to close
  • Backtick quoted: next ` ends value
  • Implicit double quoted: newline ends value
```

### Example Quote Processing

**Example 1: Simple single quotes**
```
Input: 'hello'
  
Process:
1. ''' → single_quote_streak = 1
2. walkSingleQuotes() → quoted = true, clear streak
3. 'h','e','l','l','o' → add to buffer
4. ''' → single_quote_streak = 1
5. walkSingleQuotes() → returns true (stop reading)
```

**Example 2: Triple quotes (heredoc)**
```
Input: '''line1
line2
line3'''garbage

Process:
1. ''',''',''' → single_quote_streak = 3
2. walkSingleQuotes() → triple_quoted = true
3. 'line1\nline2\nline3' → add to buffer (including newlines)
4. ''',''',''' → single_quote_streak = 3
5. walkSingleQuotes() → returns true (stop, clear to newline)
6. clearGarbage() → consume 'garbage' until '\n'
```

**Example 3: Excess quotes**
```
Input: ''''hello''''

Process:
1. ''',''',''',''' → single_quote_streak = 4
2. walkSingleQuotes() → triple_quoted = true, add 1 ' to buffer
3. 'hello' → add to buffer
4. ''',''',''',''' → single_quote_streak = 4
5. walkSingleQuotes() → add 1 ' to buffer, returns true
   
Result: "'hello'"
```

## Implementation Details

### C++ Reference Logic (Simplified)
```cpp
bool EnvReader::walk_single_quotes(EnvValue* value) {
  bool stop = false;
  
  // At start of value?
  if (value->value_index == 0) {
    if (value->single_quote_streak == 1) {
      value->quoted = true;
    } else if (value->single_quote_streak == 2) {
      value->quoted = true;
      stop = true;  // Empty value
    } else if (value->single_quote_streak >= 3) {
      value->triple_quoted = true;
      // Add excess quotes to buffer
      for (int i = 3; i < value->single_quote_streak; i++) {
        add_to_buffer(value, '\'');
      }
    }
  } else {
    // During parsing
    if (value->quoted && value->single_quote_streak > 0) {
      stop = true;  // End of single quoted value
    } else if (value->triple_quoted && value->single_quote_streak >= 3) {
      // Add excess quotes
      for (int i = 3; i < value->single_quote_streak; i++) {
        add_to_buffer(value, '\'');
      }
      stop = true;  // End of heredoc
    }
  }
  
  value->single_quote_streak = 0;
  return stop;
}
```

## Checklist

- [x] Create `src/quote_parser.zig`
- [x] Implement `walkSingleQuotes` function
- [x] Implement `walkDoubleQuotes` function
- [x] Add tests for single quote handling:
  - [x] Empty single quotes `''`
  - [x] Normal single quotes `'value'`
  - [x] Triple single quotes `'''heredoc'''`
  - [x] Excess quotes `''''value''''`
  - [x] Single quotes preserve escapes literally
- [x] Add tests for double quote handling:
  - [x] Empty double quotes `""`
  - [x] Normal double quotes `"value"`
  - [x] Triple double quotes `"""heredoc"""`
  - [x] Excess quotes `""""value""""`
- [ ] Add tests for backtick quotes:
  - [ ] `` `value` ``
  - [ ] `` `value with ${var}` ``
- [x] Add tests for mixed scenarios:
  - [x] Single quotes inside double quotes
  - [x] Double quotes inside single quotes
- [x] Update `src/root.zig` to export new module

## Dependencies
- Task 01b (Key and Value Structures) - needs EnvValue
- Task 02 (Buffer Management) - needs addToBuffer
- Task 03a (Escape Processing) - escape processing is disabled in single quotes

## Test Cases from C++ Tests
Reference these C++ test cases when implementing:
- `DotEnvTest::DoubleQuotes` - basic double quote handling
- `DotEnvTest::SingleQuoted` - single quote behavior (no escapes/interpolation)
- `DotEnvTest::TripleSingleQuotedWithMoreGarbage` - heredoc with trailing garbage
- `DotEnvTest::BackTickQuote` - backtick quote behavior

## Notes
- **Single quotes preserve EVERYTHING literally** (no escapes, no interpolation)
- **Double quotes process escapes and interpolation**
- **Backticks behave like double quotes** but terminate differently
- **Heredocs allow multi-line content** without escaping newlines
- **After closing triple quotes**, remaining content on line is "garbage" and must be cleared
- The `single_quote_streak` and `double_quote_streak` counters are incremented each time a quote is encountered consecutively
- The quote functions are called when a non-quote character is encountered after quotes

## Files to Create
- `src/quote_parser.zig`
