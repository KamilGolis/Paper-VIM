# Single-key targeting cells

Targeting originally required one horizontal and one vertical key per step. The
grid is always a 2x2 partition, so one key can select each cell. The keys are
fixed to screen positions: `h` top-left, `j` top-right, `k` bottom-left, and `l`
bottom-right. A press selects exactly one level; auto-repeat is ignored until
the key is released.

## Consequences

The key layout is positional rather than Vim-directional. Backspace always undoes
one level. Help, labels, and the readme show one key per cell.
