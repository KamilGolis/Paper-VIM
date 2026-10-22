# Targeting mode

Status: Superseded by [ADR-0003](0003-single-key-targeting-grid.md)

Paper-VIM had four Vim modes: Off, Normal, Visual, and Insert. Adding pointer
control as another mode keeps the grid and the keyboard capture behind the same
global mode switch and lets the HUD, help, CapsLock, and Esc follow one state.

## Decision

Targeting is `VimMode 4`, entered with `m` from Normal and exited with Esc.
The mode covers the monitor under the pointer, splits it into a recursive 2x2
grid, and moves the pointer to the center of the selected cell. Each step is one
horizontal key (`h` or `l`) plus one vertical key (`k` or `j`), in either order.
The overlay is click-through; an `InputHook` owns the keyboard so keys cannot
leak into the active application. Backspace undoes one level, and F1 pauses the
grid while the help overlay is open.

## Consequences

The mode value now has five states, so help and focus-border conditions must
include Targeting. The grid and the InputHook are transient: leaving Targeting
stops the hook and hides the overlay. The mode also sends a left or right click at the current pointer with `Space`
or `r`. After a click it resets the grid to the full monitor without moving the
pointer.
