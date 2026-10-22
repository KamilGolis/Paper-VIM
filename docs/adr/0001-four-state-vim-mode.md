> Superseded in part by ADR 0002 (Targeting adds a fifth mode).

# Four-state Vim mode

Paper-VIM used one mode value for both Off and Insert. Pressing `i` or Esc set that value, hid the HUD, and disabled every Vim key; returning to Normal required CapsLock. We split the global mode into four states: Off, Normal, Visual, and Insert. Insert passes keys through except Esc and CapsLock, and Esc returns to Normal from Insert or Visual. We rejected a separate Insert boolean because it would create a second source of truth for the HUD and for every hotkey condition.

## Consequences

Vim command hotkeys are active only in Normal and Visual. Layout hotkeys are also disabled in Insert. The mode remains global rather than per-window.
