# Task 04: Variable Interpolation Functions

## Objective
Implement the variable interpolation detection and tracking functions that handle `${variable}` syntax.

## Background
The .env parser supports variable interpolation with the `${variable}` syntax. Variables can reference other variables defined earlier or later in the file. Whitespace inside `${ var }` is trimmed. Circular dependencies are detected.

## Functions to Implement

### 1. position_of_dollar_last_sign (`src/interpolation.zig`)
- **C++ Reference**: `EnvReader::position_of_dollar_last_sign(...)` (lines 350-373)
- **Purpose**: Search backward from current position to find `$` that precedes `{`
- **Returns**: `ReadResult` (success with position, empty if value_index < 1, fail if escaped or not found)
- **C++ Logic**:
  ```cpp
  EnvReader::read_result EnvReader::position_of_dollar_last_sign(
      const EnvValue* value, int* position) {
    if (value->value_index < 1) {
      return empty;
    }
    auto tmp = value->value_index - 2;
    
    while (tmp >= 0) {
      if (value->value->at(tmp) == '$') {
        if (tmp > 0 && value->value->at(tmp - 1) == '\\') {
          return fail;  // escaped $
        }
        break;
      }
      if (value->value->at(tmp) == ' ') {
        tmp = tmp - 1;
        continue;  // skip whitespace between $ and {
      }
      return fail;  // non-whitespace between $ and {
    }
    *position = tmp;
    return success;
  }
  ```
- **Zig return type**: `?usize` (null if not found/escaped) or error union
- **Signature**: `fn positionOfDollarLastSign(value: *const EnvValue) ?usize`

### 2. open_variable (`src/interpolation.zig`)
- **C++ Reference**: `EnvReader::open_variable(EnvValue* value)` (lines 535-546)
- **Purpose**: Called when `{` is encountered; start tracking a new variable interpolation
- **C++ Logic**:
  ```cpp
  void EnvReader::open_variable(EnvValue* value) {
    int position;
    const auto result = position_of_dollar_last_sign(value, &position);
    
    if (result == success) {
      value->is_parsing_variable = true;
      value->interpolations->push_back(
          new VariablePosition(value->value_index,      // variable_start
                               value->value_index - 1,   // start_brace
                               position));               // dollar_sign
    }
  }
  ```
- **Signature**: `fn openVariable(allocator: std.mem.Allocator, value: *EnvValue) !void`

### 3. close_variable (`src/interpolation.zig`)
- **C++ Reference**: `EnvReader::close_variable(EnvValue* value)` (lines 505-533)
- **Purpose**: Called when `}` is encountered; finalize the current variable interpolation
- **C++ Logic**:
  ```cpp
  void EnvReader::close_variable(EnvValue* value) {
    value->is_parsing_variable = false;
    VariablePosition* interpolation = value->interpolations->at(value->interpolation_index);
    interpolation->end_brace = value->value_index - 1;
    interpolation->variable_end = value->value_index - 2;
    
    // Trim left whitespace
    if (auto left = get_white_space_offset_left(value->value, interpolation); left > 0) {
      interpolation->variable_start += left;
    }
    // Trim right whitespace
    if (auto right = get_white_space_offset_right(value->value, interpolation); right > 0) {
      interpolation->variable_end -= right;
    }
    
    // Extract variable name
    auto len = (interpolation->variable_end - interpolation->variable_start) + 1;
    interpolation->variable_str->resize(len);
    interpolation->variable_str->replace(0, len, *value->value, 
                                         interpolation->variable_start, len);
    interpolation->closed = true;
    value->interpolation_index++;
  }
  ```
- **Signature**: `fn closeVariable(allocator: std.mem.Allocator, value: *EnvValue) !void`

### 4. remove_unclosed_interpolation (`src/interpolation.zig`)
- **C++ Reference**: `EnvReader::remove_unclosed_interpolation(EnvValue* value)` (lines 905-916)
- **Purpose**: After parsing completes, remove any interpolation that wasn't closed with `}`
- **C++ Logic**:
  ```cpp
  void EnvReader::remove_unclosed_interpolation(EnvValue* value) {
    for (int i = value->interpolation_index - 1; i >= 0; i--) {
      const VariablePosition* interpolation = value->interpolations->at(i);
      if (interpolation->closed) continue;
      value->interpolations->erase(value->interpolations->begin() + value->interpolation_index);
      delete interpolation;
      value->interpolation_index--;
    }
  }
  ```
- **Signature**: `fn removeUnclosedInterpolation(allocator: std.mem.Allocator, value: *EnvValue) void`

## Interpolation Data Flow

```
Input: "Hello ${  name  }, welcome to ${city}!"

Parsing timeline:
1. Process 'H', 'e', 'l', 'l', 'o', ' '
2. Process '$' - add to buffer
3. Process '{' - call openVariable()
   → Create VariablePosition(start=7, brace=6, dollar=5)
   → is_parsing_variable = true
4. Process ' ', ' ', 'n', 'a', 'm', 'e', ' ', ' '
5. Process '}' - call closeVariable()
   → Trim whitespace: variable_start=9, variable_end=12
   → Extract variable_str = "name"
   → closed = true
6. Continue with rest of string...

Result:
- interpolations[0]: { variable_str: "name", dollar_sign: 5, end_brace: 14 }
- interpolations[1]: { variable_str: "city", dollar_sign: 28, end_brace: 33 }
```

## Edge Cases to Handle

1. **Escaped dollar sign**: `\${var}` should NOT be interpolated
2. **Unclosed brace**: `${var` should be ignored (not interpolated)
3. **Empty variable**: `${}` - should this be valid? (Check C++ behavior)
4. **Whitespace inside**: `${ var }` should trim to "var"
5. **Nested braces**: `${a${b}}` - check C++ behavior
6. **No matching variable**: `${nonexistent}` - handled at finalization

## Checklist

- [ ] Create `src/interpolation.zig`
- [ ] Implement `positionOfDollarLastSign` function
- [ ] Implement `openVariable` function
- [ ] Implement `closeVariable` function
- [ ] Implement `removeUnclosedInterpolation` function
- [ ] Add tests for basic interpolation detection:
  - [ ] Simple `${var}`
  - [ ] Multiple variables `${a} ${b}`
  - [ ] Whitespace trimming `${ var }`
- [ ] Add tests for edge cases:
  - [ ] Escaped `\${var}`
  - [ ] Unclosed `${var`
  - [ ] Empty `${}`
- [ ] Add tests for interpolation in different quote contexts:
  - [ ] Works in double quotes
  - [ ] Doesn't work in single quotes
  - [ ] Works in backticks
  - [ ] Works in implicit double quotes
- [ ] Update `src/root.zig` to export new module

## Dependencies
- Task 01 (Core Data Structures) - needs EnvValue, VariablePosition
- Task 02 (Buffer Management) - needs whitespace offset functions

## Test Cases from C++ Tests

Reference these C++ test cases:
- `DotEnvTest::InterpolateValues` - basic interpolation
- `DotEnvTest::InterpolateValuesAdvanced` - chained/recursive interpolation
- `DotEnvTest::InterpolateValuesCircular` - circular dependency detection
- `DotEnvTest::InterpolateValuesEscaped` - escaped `${}` syntax
- `DotEnvTest::InterpolateUnClosed` - unclosed braces

## Notes
- Interpolation tracking happens during parsing, but actual substitution happens in finalize_value (Task 06)
- The VariablePosition stores character indices, not byte indices (important for multi-byte chars if ever supported)
- Single quotes completely disable interpolation - `'${var}'` stays as literal `${var}`
