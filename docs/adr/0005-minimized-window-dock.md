# Minimized windows leave the open row and main dock

Minimized windows previously stayed in the tiling row, occupied main-dock
slots, and were selected by `n`/`Tab`. That made a hidden window look like an
open one and wasted a row slot.

A managed window is minimized when `WinGetMinMax()` returns `-1`. Minimized
windows remain in `WindowStack` and keep their remembered width, but
`GetOpenWindows()` filters them out. The tiling row, overlay layout, `n`/`Tab`,
the main dock, and `1-9` use that open list. Restoring a window returns it to
the open list without changing its stack position.

The minimized dock is a separate GUI immediately to the right of the main
dock. `DockMinimizedPadding` sets the gap in pixels (default 24) so the two
docks are clearly separate. It lists every minimized window in stack order and
greys their icons. It is not limited to the nine main-dock slots; only the first
nine minimized windows get numbers, and `Ctrl+1..9` restores those first nine.
Returning a window renumbers the remaining minimized windows. The icons are
greyscaled by converting the source HICON to a desaturated 32-bit bitmap; the
picture controls are also disabled. If the right edge would overflow, the dock
moves to the left of the main dock. When all managed windows are minimized, the
main dock hides and the minimized dock centers.

The trade-off is two number spaces: `1-9` addresses open windows, while the
grey numbers are reserved for a future minimized-window selector.
