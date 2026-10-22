# Single-key targeting cells

Targeting originally required one horizontal and one vertical key per step. A
grid of rows and columns lets one key select each cell. The grid defaults to 2x2
with `h` top-left, `j` top-right, `k` bottom-left, and `l` bottom-right. Rows,
columns, and keys are configurable; keys are assigned row by row and must match
the cell count. A press selects exactly one level; auto-repeat is ignored until
the key is released.

## Consequences

The key layout is positional rather than Vim-directional. Backspace always undoes
one level. Help, labels, and the readme show one key per cell. Invalid grid or
key configuration prevents Targeting and shows `TARGET CONFIG INVALID`.
