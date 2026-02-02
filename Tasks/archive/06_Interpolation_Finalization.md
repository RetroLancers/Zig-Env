# Task 06: Interpolation Finalization

## Objective
Implement the `finalize_value` function that performs recursive variable substitution after all pairs have been parsed.

## Background
Variable interpolation in .env files is order-independent: a variable can reference another variable defined later in the file. This is achieved by:
1. First parsing all pairs and recording interpolation positions
2. Then recursively resolving all interpolations

The finalization step also detects circular dependencies (A references B, B references A).

## Functions to Implement

### 1. finalize_value (`src/finalizer.zig`)
- **C++ Reference**: `EnvReader::finalize_value(...)` (lines 918-970)
- **Purpose**: Recursively substitute all `${var}` references with their values
- **Returns**: `FinalizeResult` (interpolated, copied, circular)
- **C++ Logic**:
  ```cpp
  EnvReader::finalize_result EnvReader::finalize_value(
      const EnvPair* pair,
      std::vector<EnvPair*>* pairs) {
    
    // No interpolations? Mark as done and return.
    if (pair->value->interpolation_index == 0) {
      pair->value->is_already_interpolated = true;
      pair->value->is_being_interpolated = false;
      return copied;
    }
    
    // Mark as being processed (for circular detection)
    pair->value->is_being_interpolated = true;
    
    // Create own buffer copy
    const auto buffer = new std::string(*pair->value->value);
    pair->value->set_own_buffer(buffer);
    
    // Process interpolations in REVERSE order (important!)
    const auto size = pair->value->interpolations->size();
    for (auto i = size - 1; i >= 0; i--) {
      const VariablePosition* interpolation = pair->value->interpolations->at(i);
      
      // Find the referenced variable in pairs
      for (const EnvPair* other_pair : *pairs) {
        // Check if variable name matches key
        const size_t variable_str_len = ...; // Calculate length
        if (variable_str_len != other_pair->key->key->size()) continue;
        if (memcmp(...) != 0) continue;  // Names don't match
        
        // Found matching key!
        
        // Check for circular dependency
        if (other_pair->value->is_being_interpolated) {
          return circular;
        }
        
        // Recursively finalize if not already done
        if (!other_pair->value->is_already_interpolated) {
          const auto walk_result = finalize_value(other_pair, pairs);
          if (walk_result == circular) return circular;
        }
        
        // Perform substitution: replace ${var} with resolved value
        buffer->replace(
          interpolation->dollar_sign,
          (interpolation->end_brace - interpolation->dollar_sign) + 1,
          *other_pair->value->value
        );
        
        break;  // Found match, stop searching
      }
    }
    
    pair->value->is_already_interpolated = true;
    pair->value->is_being_interpolated = false;
    return interpolated;
  }
  ```

### 2. finalize_all_values (`src/finalizer.zig`)
- **Purpose**: Helper to finalize all pairs in order
- **Signature**: `fn finalizeAllValues(allocator: std.mem.Allocator, pairs: *std.ArrayList(EnvPair)) !void`
- **Logic**:
  ```zig
  pub fn finalizeAllValues(allocator: std.mem.Allocator, pairs: *std.ArrayList(EnvPair)) !void {
      for (pairs.items) |*pair| {
          const result = try finalizeValue(allocator, pair, pairs);
          if (result == .circular) {
              // Handle circular dependency - variable stays as ${var}
          }
      }
  }
  ```

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

C++ uses `std::string::replace()`. In Zig, we need to:

**Option A: Use ArrayList(u8)**
```zig
// Replace range [start..end] with new content
fn replaceRange(buffer: *std.ArrayList(u8), start: usize, end: usize, replacement: []const u8) !void {
    const old_len = end - start;
    const new_len = replacement.len;
    
    if (new_len > old_len) {
        // Need to expand: insert extra space
        try buffer.insertSlice(end, replacement[old_len..]);
    } else if (new_len < old_len) {
        // Need to shrink: remove extra space
        buffer.replaceRange(start, end, replacement);
    }
    // Copy new content
    @memcpy(buffer.items[start..start + new_len], replacement);
}
```

**Option B: Rebuild string**
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

## Checklist

- [ ] Create `src/finalizer.zig`
- [ ] Implement string replacement helper function
- [ ] Implement `finalizeValue` function
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
- Task 01 (Core Data Structures)
- Task 04 (Variable Interpolation) - for VariablePosition
- Task 05 (Core Reading) - for pairs list

## Test Cases from C++ Tests

Reference these C++ test cases:
- `DotEnvTest::InterpolateValues` - basic substitution
- `DotEnvTest::InterpolateValuesAdvanced` - chained/recursive
- `DotEnvTest::InterpolateValuesCircular` - circular detection
- `DotEnvTest::DoubleQuotedHereDoc2` - heredoc with multiple interpolations

## Circular Dependency Behavior

When circular dependency is detected:
- C++ returns `circular` but doesn't indicate which variable is problematic
- The variable with the circular reference keeps its `${var}` literal text
- This matches the behavior in `DotEnvTest::InterpolateValuesCircular`:
  ```cpp
  EXPECT_EQ(*env_pairs.at(2)->value->value, "hello ${b4} hello");  // Stays literal
  ```

## Notes
- The finalization step is O(n*m) where n = number of pairs, m = average interpolations per value
- Deep recursion could theoretically cause stack overflow with extreme nesting, but unlikely in practice
- Consider iterative approach if stack depth becomes a concern
- Memory-wise: each finalized value gets its own buffer (no more shared buffers after finalization)
