# Code Review: paper-vim.ahk

Reviewed: `paper-vim.ahk` (1,191 lines), against AHK v2 documentation.
Verified against official docs: WinMove coordinate semantics, hotkey variant
precedence (`#HotIf`), and icon-handle ownership for GUI controls.

## What's good

- Clean separation: config -> GUI -> core functions -> shell hook -> hotkeys.
  Comments are consistent and useful.
- Correct use of AHK v2 idioms: `#Requires v2.0`, `global` declarations where
  assignments happen, `ClipboardAll()` for save/restore, `InputHook` for `f`/`t`,
  debounced reflow via `SetTimer(fn, -delay)`.
- `OnExit` restoring the taskbar and the startup "restore taskbar left hidden by
  a crashed session" logic are nice touches.
- The `dd` implementation (`{Home}+{End}{BackSpace}{Delete}`) correctly deletes
  the line including the newline -- subtle and correct.

## Critical bugs

### 1. Normal-mode `p` (paste) is dead code -- contradicts the readme

Two `p` hotkeys exist:

- `p:: CycleStack(-1)` (line 1077, `#HotIf Mode > 0 && !Suspended`)
- `p:: Send "^v"` (line 1145, `#HotIf Mode == 1`)

Both are eligible in Normal mode. Per the v2 docs (_HotIf.htm):
*"If more than one variant is eligible to fire, only the one closest to the
top of the script will fire."* So in Normal mode `p` always cycles to the
previous window; paste never fires -- but the readme documents paste under
"Yank (Copy) & Paste".

**Fix:** move `CycleStack(-1)` out of the shared region (e.g., bind it only in
Visual mode, or pick a different key such as `Tab`/`+n` for "previous window").

### 2. Refocus steal when the active window is not managed

In `ReflowStack` (line 596), if `activeIndex == 0` -- which is true whenever the
foreground window is *unmanaged* (Start menu, a dialog, tray flyouts, an
excluded window) -- the script calls `WinActivate(WindowStack[1])`. Since
activation of any window triggers `DeferredReflow` (line 466), simply opening
the Start menu or an unmanaged popup can yank focus back to a managed window
and close the popup.

**Fix:** only force-activate when the *previously managed* active window was
actually removed during the cleanup loop (set a flag there), not when the
active window is merely outside the stack.

### 3. Backwards cleanup loop skips windows after a removal

Lines 573-586: `idx := WindowStack.Length - A_Index + 1` recomputes `Length`
every iteration. After `RemoveAt` shrinks the array, the next computed index
skips one element, so a stale hwnd can survive a cleanup pass.

**Fix:** capture `n := WindowStack.Length` before the loop and compute
`idx := n - A_Index + 1` (positions below the removal point don't shift).

### 4. Desktop counter desyncs from reality

- `^k` clamps `CurrentDesktop` to 10, but if Windows has fewer desktops,
  `^#{Right}` does nothing while the counter still increments. After that,
  `^1..^5` send the wrong number/direction of `^#Left/Right` and can land on
  the wrong desktop and auto-arrange the wrong one.
- Win+Tab or touchpad gestures change desktops without updating
  `CurrentDesktop` at all.

**Fix options:** clamp by verifying a desktop switch actually happened, listen
to a real desktop-change source (e.g., the `virtual-desktop-accessor` approach
via DwmGetWindowAttribute/COM), or at minimum track desktop per-window instead
of a single counter.

### 5. `InitializeExistingWindows` pulls windows from ALL virtual desktops

`WinGetList()` (line 758) returns windows from other desktops too -- they are
not "hidden" in the Win32 sense. They get pushed into `WindowStack`, tiled,
shown in the dock, and `n`/`p` can activate a window on another desktop,
causing surprise desktop switches.

**Fix:** filter cloaked windows before pushing:

```ahk
DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "UInt*", &cloaked := 0, "UInt", 4)
if (cloaked)
    continue
```

## High impact

### 6. Dock: destroy/recreate the entire GUI on every event, plus bad early-returns

`UpdateDock` (line 246) destroys and rebuilds the GUI on every
activation/flash/reflow. It flickers, churns GDI handles, and both early
returns (lines 258, 272) leave a freshly created but never-shown GUI -- so the
dock silently vanishes whenever the active window is unmanaged.

**Fix:** call `DockGui.Hide()` in the early-return paths, and long-term, update
a fixed set of controls in place instead of rebuilding.

### 7. HICON ownership risk in the dock

`GetWindowIconPath` returns `"HICON:" hIcon` where the handle came from
`WM_GETICON`/`GetClassLongPtr` -- those icons belong to the target window, not
to the script. AHK GUI controls treat icons passed via handles as owned and
destroy them when the control is replaced/destroyed (documented for StatusBar's
`SetIcon`: *"any old icon is destroyed when this method replaces it"*), and the
dock destroys its controls on every rebuild. This risks destroying another
app's icon.

**Fix:** duplicate before handing over:

```ahk
DllCall("CopyIcon", "Ptr", hIcon, "Ptr")
```

### 8. Heavy work inside the shell-hook handler under `Critical`

`ManageNewWindow` calls `ReflowStack()` synchronously inside `ShellMessage`,
and `ReflowStack` holds `Critical "On"` through the whole reflow plus a full
dock GUI rebuild. Shell hook handlers should return fast; long critical
sections buffer and delay all hotkeys.

**Fix:** use `DeferredReflow` from `ManageNewWindow` too, and keep `Critical`
only around the stack mutation, not the GUI rebuild.

### 9. Minimized windows never get repositioned

The v2 docs state WinMove *cannot move minimized windows* and *"success may be
reported even if the window has not moved."* The tiling loop (line 635)
silently fails for minimized stack members, so restoring them later shows them
at stale positions.

**Fix:** `WinRestore` before `WinMove` (as overlay mode already does), or track
minimized windows and reflow them on restore.

### 10. `ShellMessage` re-activates on every activation event

Line 456: the activation notification means the window *was already* activated;
`WinActivate(lParam)` again is redundant and can fight the shell during
Alt-Tab/Task View. The unconditional `WinRestore` on minimized windows
(line 458) also overrides the user.

**Fix:** delete this block and keep only `DeferredReflow()`.

## Medium

### 11. Command mode (`:`) is partly unusable in Normal mode

After `:` opens the InputBox, the hotkeys are still active (they're conditioned
on `Mode`, not on the dialog). Typing `w` triggers `w::` instead of typing the
letter, so `wq` can't be entered.

**Fix:** in the `SC027` handler, set `Mode := 0` before `InputBox` and restore
after -- hotkey contexts are evaluated live, so this disables interception
while the dialog is up.

### 12. Suspension forcibly fullscreens everything

`ToggleSuspend` applies overlay mode on suspend (line 192). If a user suspends
to play a game or give a demo, every window jumps to fullscreen first. Also,
windows created while suspended stay unmanaged until the next shell event, and
`SuspendedState["hwnd"]` is stored but never used.

**Fix:** document this as intended, or save/restore without forcing overlay.

### 13. `FlashMessage` timers overlap

Each call sets a new one-shot restore timer without canceling the previous one;
two rapid flashes cut the second message short.

**Fix:** store the flash funcref in a global and `SetTimer(old, 0)` before
setting a new one.

### 14. Multi-monitor and DPI

All layout math uses `A_ScreenWidth/Height` (primary monitor, at load time) and
hardcoded `TaskbarHeight := 48`, `BarHeight := 60`. On multi-monitor, the
circular "infinite scroll" offsets send windows onto adjacent monitors
(negative X is legal and moves them there).

**Fix:** use `MonitorGetWorkArea` of the active window's monitor, and query the
real taskbar/work-area size instead of constants.

### 15. Hidden windows get dropped from the stack

`WinExist(hwnd)` in the cleanup loop fails for hidden (not minimized) windows
because `DetectHiddenWindows` defaults to off -- so an app that hides its
window (e.g., hide-to-tray) gets removed from tiling and never re-added (only
the creation event adds windows).

**Fix:** enable `DetectHiddenWindows` for the existence check or use
`WinExist("ahk_id " hwnd)` with DWM cloaked checks.

## Minor / polish

- Dead code: `DockIcons := []` (line 68) is never used; `pic :=` locals
  (lines 299, 313, 330) unused.
- The find-active-index loop is duplicated 5+ times; the `^h`/`^l` swap logic
  is ~30 duplicated lines. Factor into `GetActiveIndex()` and `SwapActive(dir)`.
- `+g` (line 1115) should extend the selection in Visual mode:
  `Send(Mode == 2 ? "+^{End}" : "^{End}")` -- same pattern already used for
  `0` and `$`.
- `e` (line 1087) is identical to `w`; vim's `e` goes to word end --
  e.g. `Send "^{Right}{Left}"` is a closer approximation.
- `SC027` is the physical OEM_1 key; on non-US layouts the colon key isn't
  there. Fine if US-only.
- Many `catch as err` blocks ignore `err` -- bare `catch` is enough, and a
  debug flag that `OutputDebug`s swallowed errors would help the "why didn't my
  window tile" class of issues.
- `HSHELL_FLASH` (32772 = 0x8004) is really
  `HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT` -- correct value, but the comment
  could say so.
- `ToggleTaskbar`'s `ahk_class Button` Start-button hide is Win10-only;
  harmless on Win11.

## Suggested priority

Fix in this order: **#1** (documented feature is broken), **#2** (visible
focus-stealing misbehavior), **#5** (cross-desktop contamination -- biggest WM
correctness issue), **#3**, then **#6/#7** together (dock), then the rest as
those areas are touched.

## Verification notes

Two items are marked as risks and worth confirming on a live Windows box:

- HICON destruction behavior (#7)
- The exact focus-stealing frequency (#2), tested with a couple of unmanaged
  popups open.
