# Task 06: Interpolation Finalization

## Objective
Implement the `finalize_value` function that performs recursive variable substitution after all pairs have been parsed.

## Estimated Time
2-3 hours

## Background
Variable interpolation in .env files is order-independent: a variable can reference another variable defined earlier or later in the file. This is achieved by:
1. First parsing all pairs and recording interpolation positions (done in previous tasks)
2. Then recursively resolving all interpolations (this task)

The finalization step also detects circular dependencies (A references B, B references A).

## Functions to Implement

### 1. finalize_value (`src/finalizer.zig`)
- **C++ Reference**: `EnvReader::finalize_value(...)` (lines 918-970)
- **Purpose**: Recursively substitute all `${var}` references with their values
- **Returns**: `FinalizeResult` (interpolated, copied, circular)
 - Process interpolations in REVERSE order (important - see Algorithm Details)
- Check for circular dependencies using `is_being_interpolated` flag
- Recursively finalize referenced variables if needed
- **Signature**: `fn finalizeValue(allocator: std.mem.Allocator, pair: *EnvPair, pairs: *std.ArrayList(EnvPair)) !FinalizeResult`

### 2. finalize_all_values (`src/finalizer.zig`)
- **Purpose**: Helper to finalize all pairs in order
- **Signature**: `fn finalizeAllValues(allocator: std.mem.Allocator, pairs: *std.ArrayList(EnvPair)) !void`

## Algorithm Details

### Why Reverse Order?
Interpolations are processed in reverse order because string replacement changes positions:

```
Original: "${a} and ${b}"
           ^5     ^13

If we replace ${a} first with "hello":
Result: "hello and ${b}"
                   ^12  (position shifted!)

By processing in reverse (${b} first), earlier positions remain valid.
```

### Circular Dependency Detection

The algorithm uses two flags:
- `is_being_interpolated`: Currently in the recursion stack (being processed)
- `is_already_interpolated`: Fully processed and done

Example circular case:
```
a=${b}
b=${a}
```

Processing:
1. Start finalizing `a` → set `is_being_interpolated = true`
2. `a` references `b` → recurse into `b`
3. `b` references `a` → check `a.is_being_interpolated` → true → CIRCULAR!
4. Return `circular` result

### Zig String Replacement Strategy

Choose one of these approaches:

**Option A: Rebuild string**
```zig
fn replaceInterpolation(allocator: Allocator, value: []const u8, interp: *VariablePosition, replacement: []const u8) ![]u8 {
    const before = value[0..interp.dollar_sign];
    const after = value[interp.end_brace + 1..];
    
    var result = try allocator.alloc(u8, before.len + replacement.len + after.len);
    @memcpy(result[0..before.len], before);
    @memcpy(result[before.len..before.len + replacement.len], replacement);
    @memcpy(result[before.len + replacement.len..], after);
    return result;
}
```

**Option B: Use ArrayList(u8)** with insertSlice/replaceRange

## Checklist

- [ ] Create `src/finalizer.zig`
- [ ] Implement string replacement helper function
- [ ] Implement `finalizeValue` function
  - [ ] Handle no interpolations case
  - [ ] Mark as being interpolated
  - [ ] Create own buffer copy
  - [ ] Process interpolations in reverse
  - [ ] Find matching key
  - [ ] Check for circular dependency
  - [ ] Recursively finalize if needed
  - [ ] Perform substitution
  - [ ] Mark as done
- [ ] Implement `finalizeAllValues` helper
- [ ] Add tests for basic interpolation:
  - [ ] Single variable `${var}`
  - [ ] Multiple variables `${a} ${b}`
  - [ ] Chained `a` → `b` → `c`
- [ ] Add tests for circular dependency:
  - [ ] Direct circular `a` → `b` → `a`
  - [ ] Indirect circular `a` → `b` → `c` → `a`
- [ ] Add tests for missing variables:
  - [ ] `${nonexistent}` stays as literal (no crash)
- [ ] Add tests for complex cases:
  - [ ] Heredoc with interpolation
  - [ ] Multiple interpolations of same variable
- [ ] Update `src/root.zig` to export new module

## Dependencies
- Task 01b (Key and Value Structures)
- Task 04 (Variable Interpolation) - for VariablePosition
- Task 05c (Value and Pair Reading) - for pairs list

## Test Cases from C++ Tests
- `DotEnvTest::InterpolateValues` - basic substitution
- `DotEnvTest::InterpolateValuesAdvanced` - chained/recursive
- `DotEnvTest::InterpolateValuesCircular` - circular detection
- `DotEnvTest::DoubleQuotedHereDoc2` - heredoc with multiple interpolations

## Circular Dependency Behavior

When circular dependency is detected:
- The variable with the circular reference keeps its `${var}` literal text
- Processing continues for other variables
- No error is thrown

## Notes
- The finalization step is O(n*m) where n = number of pairs, m = average interpolations per value
- Deep recursion could theoretically cause stack overflow with extreme nesting
- Each finalized value gets its own buffer
- Missing variables stay as `${var}` literals

## Files to Create
- `src/finalizer.zig`
