# Refactor Folder Structure and Granularity

## Objective
Refactor the project structure to organize files into domain-specific folders and split large files (especially `reader.zig`) to enforce the "one function/struct per file" rule where possible. This improves maintainability and navigability.

## Proposed Domain Structure

We will reorganize `src/` into the following subdirectories:

### 1. `src/data/` (Core Data Structures)
*   **`env.zig`**: The `Env` struct (currently in `lib.zig`).
*   **`env_key.zig`**: Moved from `src/env_key.zig`.
*   **`env_value.zig`**: Moved from `src/env_value.zig`.
*   **`env_pair.zig`**: Moved from `src/env_pair.zig`.
*   **`variable_position.zig`**: Moved from `src/variable_position.zig`.
*   **`read_result.zig`**: Renamed from `src/result_enums.zig`.
*   **`parser_options.zig`**: Moved from `src/parser_options.zig`.

### 2. `src/parser/` (Parsing Logic)
*   **`reader.zig`**: **ACTION**: Split this into multiple files:
    *   `read_next_char.zig`
    *   `read_key.zig`
    *   `read_value.zig`
    *   `read_pair.zig`
*   **`env_stream.zig`**: Moved from `src/env_stream.zig`.
*   **`quote_parser.zig`**: Moved from `src/quote_parser.zig`.
*   **`escape_processor.zig`**: Moved from `src/escape_processor.zig`.
*   **`file_scanner.zig`**: Moved from `src/file_scanner.zig`.

### 3. `src/buffer/` (Buffer & Memory Management)
*   **`reusable_buffer.zig`**: Moved from `src/reusable_buffer.zig`.
*   **`buffer_utils.zig`**: Moved from `src/buffer_utils.zig`.
*   **`memory_utils.zig`**: Renamed from `src/memory.zig`.

### 4. `src/interpolation/` (Interpolation & Finalization)
*   **`interpolation.zig`**: Moved from `src/interpolation.zig`.
*   **`finalizer.zig`**: Moved from `src/finalizer.zig`.

### 5. `src/utils/` (General Utilities)
*   **`whitespace_utils.zig`**: Moved from `src/whitespace_utils.zig`.

### 6. Root Files
*   **`src/root.zig`**: Remains the main entry point, re-exporting everything from their new locations.
*   **`src/lib.zig`**: (Optional) Can remain as the high-level API entry point (`parseFile`, `parseString`), but the `Env` struct should move to `src/data/env.zig`.

## Implementation Checklist

- [x] **Create Directories**:
    - `src/data/`
    - `src/parser/`
    - `src/buffer/`
    - `src/interpolation/`
    - `src/utils/`

- [x] **Move & Rename Files**:
    - [x] `env_key.zig` -> `src/data/env_key.zig`
    - [x] `env_value.zig` -> `src/data/env_value.zig`
    - [x] `env_pair.zig` -> `src/data/env_pair.zig`
    - [x] `variable_position.zig` -> `src/data/variable_position.zig`
    - [x] `result_enums.zig` -> `src/data/read_result.zig`
    - [x] `parser_options.zig` -> `src/data/parser_options.zig`
    - [x] `env_stream.zig` -> `src/parser/env_stream.zig`
    - [x] `quote_parser.zig` -> `src/parser/quote_parser.zig`
    - [x] `escape_processor.zig` -> `src/parser/escape_processor.zig`
    - [x] `file_scanner.zig` -> `src/parser/file_scanner.zig`
    - [x] `reusable_buffer.zig` -> `src/buffer/reusable_buffer.zig`
    - [x] `buffer_utils.zig` -> `src/buffer/buffer_utils.zig`
    - [x] `memory.zig` -> `src/buffer/memory_utils.zig`
    - [x] `interpolation.zig` -> `src/interpolation/interpolation.zig`
    - [x] `finalizer.zig` -> `src/interpolation/finalizer.zig`
    - [x] `whitespace_utils.zig` -> `src/utils/whitespace_utils.zig`

- [x] **Split `reader.zig`**:
    - [x] Extract `readNextChar` to `src/parser/read_next_char.zig`
    - [x] Extract `readKey` to `src/parser/read_key.zig`
    - [x] Extract `readValue` to `src/parser/read_value.zig`
    - [x] Extract `readPair` to `src/parser/read_pair.zig` (and `readPairsWithHints`)
    - [x] Remove original `reader.zig` once empty.

- [x] **Refactor `lib.zig`**:
    - [x] Extract `Env` struct to `src/data/env.zig`.
    - [x] Update `lib.zig` to import `Env` from `src/data/env.zig`.

- [x] **Update `root.zig`**:
    - Update all `@import` paths to the new locations.
    - Ensure all public API symbols are still exported correctly.

- [x] **Update Internal Imports**:
    - Go through all moved files and update `const ... = @import(...)` paths.
    - Since files are deeper now, imports might need `../../` or relative paths.

- [x] **Update Clood Files**:
    - Update `clood-groups/` JSON files to reflect the new paths.
    - Create new clood groups if necessary (e.g., `parser`, `buffer`).

- [x] **Verify**:
    - Run `zig build test` to ensure everything links and passes.
    - Run `zig build` to ensure the library compiles.
