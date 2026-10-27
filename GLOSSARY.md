# Paper-VIM

Global keyboard layer that combines Vim-style modes with a tiling window manager.

## Language

**Vim mode**:
The global state that decides whether keys act as Vim commands or as text input.
_Avoid_: Mode (alone)

**Off**:
The Vim mode where no Vim keys are intercepted and the HUD is hidden.

**Normal**:
The Vim mode for navigation and editing commands. Text is not typed.

**Insert**:
The Vim mode for text input. Only Esc, CapsLock, and F1 are intercepted.

**Visual**:
The Vim mode where navigation extends a text selection.

**Targeting**:
The Vim mode that moves the pointer with a recursive grid. Enter with `m` from
Normal; Esc returns to Normal.

**Targeting grid**:
The current grid partition of a monitor or selected cell. It is 2x2 by default.
Each cell has one key; choosing a cell moves the pointer to its center and
splits that cell again.

**Command mode**:
The transient prompt opened with `:` from Normal mode. It accepts `w`, `q`, and `wq`.

**Setting**:
A user-facing value in `paper-vim.ini` or `config.ahk`. Runtime state such as
window handles, GUI controls, and timers is not a setting.

**Keymap**:
The mapping from stable action names to AutoHotkey hotkey names, grouped by mode
or context.

**Active window**:
The top-level window that currently receives keyboard input.

**Managed window**:
A window in the tiling stack that Paper-VIM positions and tracks.

**Floating window**:
A visible top-level window that Paper-VIM leaves at its own size and position.
It is not in the tiling stack, has no dock slot, receives no automatic reflow,
and has no focus border.
_Avoid_: excluded window, ignored window

**Exclusion rule**:
A built-in or configured condition that makes a window floating. Built-in rules
cover owned windows and specific window classes and processes; configured rules
match process names or window classes.

**Focus border**:
The visual outline that marks the active managed window.

**Tiling layout**:
The layout where managed windows are arranged in a horizontal row.

**Focus/peek layout**:
The layout for a full-width active window: the active window is centered at 85% width and its neighbours remain visible at the sides.

**Overlay layout**:
The layout where every managed window fills the work area with a small gap.
