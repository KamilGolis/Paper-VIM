# Split docks for open and minimized windows

Minimized windows previously stayed in the tiling row, occupied main-dock
slots, and were selected by `n`/`Tab`. A managed window is minimized when
`WinGetMinMax()` returns `-1`. Minimized windows remain in `WindowStack` and
keep their remembered width, but `GetOpenWindows()` filters them out. The
tiling row, overlay layout, `n`/`Tab`, the open dock, and open-window numbers
use that open list. Restoring a window returns it to the open list without
changing its stack position.

The docks are split around the horizontal center of the work area:

- the open dock starts just right of center and grows right;
- the minimized dock ends just left of center and grows left;
- `DockMinimizedPadding` is the total center gap in pixels (default 24), split
  equally between the two docks.

The open dock shows at most ten windows. It is numbered `1..9` and `0` for the
tenth, displays a `+` when more windows are open, and does not scroll. The
active marker moves to the active window. If the active window is outside the
first ten, it is promoted to the first dock position and the remaining visible
windows follow in stack order. The `+` is not selectable.

The minimized dock lists every minimized window and greys the icons. Number `1`
is nearest the center and later numbers extend left. The first ten are numbered
`1..9` and `0`; `Ctrl+1..9` restores numbers 1–9 and `Ctrl+0` restores number
0. Returning a window renumbers the remaining minimized windows. Icons beyond
ten remain visible without numbers. The icons are greyscaled by converting the
source HICON to a desaturated 32-bit bitmap; the picture controls are also
disabled.

The trade-off is two number spaces: unmodified `1..9` address open windows,
while `Ctrl+1..9` and `Ctrl+0` address minimized windows.
