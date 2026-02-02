# Task 05b: Character Reading State Machine

## Objective
Implement the `readNextChar` function - the most complex function in the entire parser that processes individual characters during value parsing.

## Estimated Time
3-4 hours

## Background
This is THE heart of the parser. It's a complex state machine that handles all character processing logic including quotes, escapes, interpolation, and special characters. This function coordinates calls to all the specialized parsing functions from previous tasks.

## Function to Implement

### read_next_char (`src/reader.zig`)
- **C++ Reference**: `EnvReader::read_next_char(EnvValue* value, char key_char)` (lines 702-839)
- **Purpose**: Process a single character while parsing a value (main state machine)
- **Returns**: `bool` - true to continue reading, false to stop
- **Complexity**: This function handles:
  - Backslash escape sequences (delegate to walkBackSlashes, processPossibleControlCharacter)
  - Quote tracking (delegate to walkSingleQuotes, walkDoubleQuotes)
  - First character special cases (backtick, `#`, implicit quote mode)
 - Variable interpolation (`{`, `}`) (delegate to openVariable, closeVariable)
  - Newlines (end value unless in heredoc)
  - All other characters

## State Machine Flow

```
Input character processing:

1. Is it a backtick at start (value_index == 0)?
   YES → Set backtick_quoted = true, double_quoted = true
   NO → Continue

2. Is it a hash (#) at start (value_index == 0)?
   YES → Clear to garbage, return false (stop)
   NO → Continue

3. Is it a newline (\n)?
   YES → Is in heredoc (triple_quoted || triple_double_quoted)?
         YES → Add to buffer, continue
         NO → Return false (stop, end of value)
   NO → Continue

4. Is it a carriage return (\r)?
   YES → Skip, continue
   NO → Continue

5. Is it a single quote (')?
   YES → Increment single_quote_streak
         If quoted or triple_quoted, process with walkSingleQuotes()
         If stops → return false
   NO → Continue to step 6

6. Was previous char a single quote (single_quote_streak > 0)?
   YES → Call walkSingleQuotes()
         If stops → return false
         Continue with current char processing
   NO → Continue

7. Is it a double quote (")?
   YES → Increment double_quote_streak
         If double_quoted or triple_double_quoted, process with walkDoubleQuotes()
         If stops → return false
   NO → Continue to step 8

8. Was previous char a double quote (double_quote_streak > 0)?
   YES → Call walkDoubleQuotes()
         If stops → return false
         Continue with current char processing
   NO → Continue

9. Is it a backslash (\)?
   YES → Is in single/triple_single quoted mode?
         YES → Add literal backslash to buffer
         NO → Increment back_slash_streak
   NO → Continue to step 10

10. Was previous char a backslash (back_slash_streak > 0)?
    YES → Call walkBackSlashes()
          If back_slash_streak still == 1:
            Call processPossibleControlCharacter()
          Continue with current char processing
    NO → Continue

11. Is it an opening brace ({)?
    YES → Is in double_quoted mode (not single quoted)?
          YES → Call openVariable()
                Is previous char an escape?
                  YES → Skip (escaped brace)
                  NO → Add to buffer
          NO → Add literal '{' to buffer
    NO → Continue to step 12

12. Is it a closing brace (})?
    YES → Is parsing variable?
          YES → Call closeVariable()
          Is previous char an escape?
            NO → Add to buffer
    NO → Continue to step 13

13. Default case:
    - At value_index == 0 and not quoted?
      → Set implicit_double_quote = true, double_quoted = true
    - Add character to buffer

14. Return true (continue reading)
```

## Implementation Tips

This function is complex. Consider breaking it down:

```zig
fn readNextChar(allocator: std.mem.Allocator, value: *EnvValue, char: u8) !bool {
    // Handle backtick at start
    if (value.value_index == 0 and char == '`') {
        return try handleBacktickStart(value);
    }
    
    // Handle comment at start
    if (value.value_index == 0 and char == '#') {
        return false; // Will be handled by caller with clearGarbage
    }
    
    // Handle newline
    if (char == '\n') {
        return handleNewline(value);
    }
    
    // Handle carriage return
    if (char == '\r') {
        return true; // Skip
    }
    
    // Handle single quotes
    if (char == '\'') {
        return try handleSingleQuote(value);
    }
    if (value.single_quote_streak > 0) {
        const stop = walkSingleQuotes(value);
        if (stop) return false;
    }
    
    // ... continue pattern for other character types
    
    // Default: add to buffer
    if (value.value_index == 0 and !value.quoted and !value.double_quoted) {
        value.implicit_double_quote = true;
        value.double_quoted = true;
    }
    try addToBuffer(value, char);
    return true;
}
```

## Edge Cases

1. **Backtick at start**: `` `value` `` → backtick_quoted = true
2. **Comment at start**: `#comment` → return false immediately
3. **Newline in heredoc**: Continue (multiline value)
4. **Newline in regular value**: Stop (end of value)
5. **Quotes at various positions**: Must track streaks correctly
6. **Escaped braces**: `\{` and `\}` should not trigger interpolation
7. **Implicit double quote mode**: Unquoted values get this mode

## Checklist

- [ ] Continue `src/reader.zig` (from Task 05a)
- [ ] Implement `readNextChar` function
  - [ ] Backtick handling at start
  - [ ] Comment handling at start
  - [ ] Newline handling (heredoc vs normal)
  - [ ] Carriage return handling
  - [ ] Single quote processing
  - [ ] Double quote processing
  - [ ] Backslash processing
  - [ ] Opening brace processing
  - [ ] Closing brace processing
  - [ ] Default character handling
- [ ] Add tests for all code paths:
  - [ ] Backtick values
  - [ ] Comment values
  - [ ] Newlines in different quote modes
  - [ ] All quote types
  - [ ] Escape sequences
  - [ ] Variable interpolation markers
  - [ ] Implicit double quote mode
- [ ] Integration tests with other functions
- [ ] Update `src/root.zig` to export if needed

## Dependencies
- Task 02 (Buffer Management) - needs addToBuffer, isPreviousCharAnEscape
- Task 03a (Escape Processing) - needs walkBackSlashes, processPossibleControlCharacter
- Task 03b (Quote Parsing) - needs walkSingleQuotes, walkDoubleQuotes
- Task 04 (Variable Interpolation) - needs openVariable, closeVariable
- Task 05a (Basic Reading) - needs clearGarbage

## Test Cases from C++ Tests
Reference these C++ test cases:
- `DotEnvTest::ReadDotEnvFile` - basic value parsing
- `DotEnvTest::ImplicitDoubleQuote` - unquoted values
- `DotEnvTest::DoubleQuotedHereDoc*` - multi-line heredoc parsing
- `DotEnvTest::BackTickQuote` - backtick handling

## Notes
- This is the MOST COMPLEX function in the parser
- Take time to understand the C++ implementation fully
- Consider breaking into smaller helper functions
- The order of checks matters - follow the C++ logic closely
- Many edge cases to handle - thorough testing is critical
- This function calls most other parsing functions
- State tracking via boolean flags and streak counters is crucial

## Files to Modify
- `src/reader.zig` (continued from 05a)
