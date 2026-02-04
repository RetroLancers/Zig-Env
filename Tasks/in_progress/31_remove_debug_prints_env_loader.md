# Task: 31_remove_debug_prints_env_loader.md

## Objective
Remove the leftover debug stderr prints in src/env_loader.zig: delete the Output.prettyErrorln calls that print 'Bun is using Zig-Env to parse string...'/'Zig-Env parsed string successfully.' and their templated variants so they no longer log on each .env load.

## Checklist
- [ ] Implement changes
- [ ] Verify fix/change

