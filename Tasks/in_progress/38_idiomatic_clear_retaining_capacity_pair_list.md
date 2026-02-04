# Task: 38_idiomatic_clear_retaining_capacity_pair_list.md

## Objective
Change EnvPairList.clearRetainingCapacity in src/zigenv/data/env_pair_list.zig to use explicit slice reassignment (self.items = self.items[0..0]) instead of setting len to 0.

## Checklist
- [ ] Implement changes
- [ ] Verify fix/change

