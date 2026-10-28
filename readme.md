# Paper-VIM: Vim Keybindings + PaperWM like Window Manager

A powerful AutoHotkey v2.0 script that combines vim-style keyboard navigation with a tiling window manager inspired by PaperWM. Navigate your windows and text with vim keybindings, manage multiple virtual desktops, and visualize your window stack with an elegant dock.

## Motivation

This script was born out of necessity. Unable to use Linux with my preferred setup ([niri](https://github.com/YaLTeR/niri)) on my company computer, and lacking admin rights to install alternative window managers, I created this as a bare minimum implementation of the workflow I wanted. It brings PaperWM-style tiling and vim navigation to Windows without requiring system-level changes or administrative privileges.
**Current Status**: This is still in early phase of development with lots of bugs and limitations (e.g., works only with main monitor setups). However, as a proof of concept, it works quite well for basic workflows. More niri-like features are planned for future releases.
## 🚀 Features

- **Vim Mode Integration**: System-wide vim keybindings for text editing and navigation
- **PaperWM-Style Window Management**: Automatic horizontal scrolling window layout
- **Per-Window Width Presets**: Shrink the active window to 25%, 50%, or 75%, or restore the 85% focus layout with neighbour peeks
- **Niri-Style Focus Scrolling**: `n`/`Tab` scroll the row only as far as needed, so the focused window parks at the left or right edge
- **Center Window**: Center the active window on demand with `Ctrl+Shift+C`
- **Dynamic Work Area**: Windows respect the taskbar edge and size, including left, right, top, and bottom docks
- **Taskbar Toggle**: Hide/show Windows taskbar with automatic window reflow
- **Taskbar Auto-Detection**: Reads the taskbar rect with `SHAppBarMessage`; `TaskbarMode`/`TaskbarSize` are manual overrides
- **Visual Window Dock**: Live icon preview showing your window stack position with numbered indicators
- **Direct Window Navigation**: Jump to any window by pressing its number (1-9)
- **Multi-Desktop Support**: Automatic window arrangement across virtual desktops
- **Smart Window Tracking**: Automatic management of new/closed windows with taskbar click support
- **Floating Windows**: Installers, owned dialogs, and configured launchers stay out of the tiling stack
- **Script Suspension**: Pause all window management with state preservation
- **HUD Indicators**: Visual feedback for current mode, desktop, and suspension state
- **Active Window Border**: A click-through cyan outline marks the active managed window
- **Targeting Mode**: Press `m` in Normal to move the pointer with a configurable recursive keyboard grid, one key per cell
- **Fully Customizable**: UI colors, fonts, timing values, and the targeting grid size and keys are configurable

## 📋 Requirements

- **Windows 10/11** with Virtual Desktop support
- **AutoHotkey v2.0** ([Download here](https://www.autohotkey.com/))

## 🔧 Installation & Setup

1. Install AutoHotkey v2.0
2. Download `paper-vim.ahk`
3. Double-click `paper-vim.ahk` to run
4. (Optional) Right-click → "Run as administrator" for better compatibility with system windows
5. (Optional) Add to Windows Startup folder for automatic launch

> **Note**: Running as administrator allows the script to manage system windows (like Task Manager) and display their icons correctly in the dock. Without admin rights, some system windows may not be fully manageable due to UIPI restrictions.

## 🎮 Quick Start Guide

### Toggle Vim Mode
- **CapsLock**: Toggle Vim mode on/off from any active mode
  - When **suspended**: Resume script and enter Normal mode
- When **OFF**: Your keyboard works normally
- When **ON**: Vim keybindings are active; the HUD shows NORMAL, VISUAL, INSERT, or TARGET
- **F1**: Toggle the combined keybind reference
- **m** (Normal): Enter Targeting; press one cell key to move the pointer; Esc exits

### Window Navigation
- **n**: Next window in stack
- **Tab**: Previous window in stack
- **1-9**: Jump directly to window at that position in stack
- **z**: Reflow/refresh window layout
- **Ctrl+Q**: Suspend/resume script (preserves window state)
- **Ctrl+T**: Toggle taskbar visibility (windows auto-resize)
- **Ctrl+F**: Toggle overlay mode (fullscreen stacked windows)
- **Ctrl+Shift+1/2/3**: Set the active window width to 25%, 50%, or 75%
- **Ctrl+Shift+0**: Restore the active window to full width
- **Ctrl+Shift+C**: Center the active window

The window row scrolls horizontally. Full-width windows use a focus layout: 85% of the viewport, the same small gutter as tiled windows, and the rest shows a slice of the previous and next window. Press `Ctrl+Shift+C` to center the active window.

---

## 📚 Complete Feature Guide

## 🪟 Window Management (PaperWM Style)

### Automatic Layout
- All windows are automatically arranged in a horizontal scrollable stack
- Each window remembers its own width: 25%, 50%, 75%, or full
- 25/50/75 widths are fractions of the usable work area and account for the gaps,
  so four 25% windows or two 50% windows tile the work area exactly
- The view scrolls horizontally as you navigate, niri-style: a window that is
  already visible does not move; an off-screen window is scrolled to the left
  or right edge
- **Full width is the focus layout**: the active window is 85% of the viewport.
  The gutters use the same `Gap` (8 px) as the tiled presets, and the remaining
  space shows a slice of the previous and next window
- Maximized managed windows are restored before they are tiled. This prevents a
  window from staying maximized at a tiled rectangle, which can look glitched
  and hides the focus border.

### Window Width
- **Ctrl+Shift+1**: 25% width
- **Ctrl+Shift+2**: 50% width
- **Ctrl+Shift+3**: 75% width
- **Ctrl+Shift+0**: Full width (focus layout with peeks)
- **Ctrl+Shift+C**: Center the active window

Each window keeps its width when you navigate, cycle, or reorder the stack.
The width is stored per window handle, so moving a window with `Ctrl+H`/`Ctrl+L`
moves its size with it.

Full-width windows stay centered so both peeks remain visible while you navigate.
The 25/50/75 presets use niri-style edge scrolling.

### Stack Operations
- **n**: Cycle to next window (right)
- **Tab**: Cycle to previous window (left)
- **1-9**: Jump directly to window at position 1-9 in stack
- **Ctrl+H**: Swap current window with the one on its left
- **Ctrl+L**: Swap current window with the one on its right
- **z**: Manually reflow/refresh window positions

### Layout Modes
- **Ctrl+F**: Toggle Overlay Mode (all windows maximized with small gaps, stacked)
- **Ctrl+T**: Toggle Windows Taskbar visibility (windows auto-resize to use available space)
- **Ctrl+Shift+D**: Remove active window from managed stack

### Floating Windows
Some windows should not join the tiling stack: installers, modal dialogs,
launchers, and owned windows. Paper-VIM leaves floating windows at their own size
and position. They have no dock slot, receive no automatic reflow, and have no
focus border.

Built-in floating rules cover:

- owned top-level windows
- class `#32770`
- class `MsiDialogCloseClass`
- process `msiexec.exe`

`Microsoft.CmdPal.UI.exe` (PowerToys Command Palette) floats by default.
Add process names or window classes in `[Exclusions]`:

```ini
[Exclusions]
Processes=Microsoft.CmdPal.UI.exe
Classes=
```

`Processes` and `Classes` replace the configurable lists; the built-in rules stay
active. Matching is case-insensitive.

### Active Window Border
A 3 px cyan outline marks the active managed window, so two adjacent windows are
easy to tell apart.

- The border is drawn outside the visible DWM frame, so it does not cover the
  window content.
- It is click-through and never takes keyboard focus.
- It follows moves, resizes, focus changes, and width changes.
- It is hidden in Off mode, while the help overlay is open, while the script is
  suspended, in emergency mode, and for maximized or fullscreen windows. It stays
  visible in Overlay Mode.
- Like the rest of the layout, it currently follows the main-monitor limitation.

### Visual Dock
A transparent dock at the top-center of your screen shows:
- **Five icon slots** in stack order; slots wrap when fewer than five windows are managed
- **Window numbers** below each icon (shows position in stack)
- **Center icon** (underlined in green): Current active window with bright green number
- **Left 2 icons**: Previous windows (press `Tab` to go left) with gray numbers
- **Right 2 icons**: Next windows (press `n` to go right) with gray numbers
- **Infinite scrolling**: Icons wrap around at stack edges
- **Direct access**: Press the number shown to jump to that window

Example: With windows [1,2,3,4,5], if you're on window 3:
```
Dock shows: [1] [2] [3̲] [4] [5]
Numbers:     1   2   3   4   5
            (gray)(gray)(green)(gray)(gray)
```

If you're on window 5:
```
Dock shows: [3] [4] [5̲] [1] [2]
Numbers:     3   4   5   1   2
```

---

## 🖥️ Virtual Desktop Management

### Desktop Navigation
- **Ctrl+J**: Switch to previous virtual desktop
- **Ctrl+K**: Switch to next virtual desktop
- **Ctrl+1** through **Ctrl+5**: Jump directly to desktop 1-5

### Auto-Arrangement
- On startup, arranges all windows on your current desktop
- When switching to a new desktop, automatically arranges its windows
- Each desktop remembers if it's been initialized
- Flash message confirms: "DESKTOP X ARRANGED"

---

## 🛑 Script Suspension

### Suspend/Resume
- **Ctrl+Q**: Toggle script suspension (available in Vim mode)
- **CapsLock** (when suspended): Resume script and enter Normal mode

### Suspension Behavior
When you suspend the script:
1. **Current state is saved**: All window positions and overlay mode setting are preserved
2. **Windows maximize**: Script applies overlay mode (fullscreen) to all windows
3. **All hotkeys disabled**: Only CapsLock and Ctrl+Q remain functional
4. **Visual indicator**: HUD shows "SUSPENDED" in orange
5. **Dock hidden**: Window dock is hidden while suspended

When you resume the script:
1. **State restored**: Windows return to their exact positions before suspension
2. **Overlay mode restored**: Previous overlay/tiling mode setting is restored
3. **All hotkeys enabled**: Full functionality returns
4. **Normal operation**: HUD and dock reappear

### Use Cases
- **Temporarily disable tiling**: When you need normal window behavior
- **Game mode**: Suspend before launching full-screen games
- **Presentations**: Quickly disable window management
- **Quick break**: Pause without losing your window arrangement

### Emergency Layout on Error
If the script hits an unhandled error, it moves every managed window to the
same reachable rectangle near the top-left of the work area (up to 1200x800
px; controlled by `EmergencyMargin`, `EmergencyMinWidth`/`Height`, and
`EmergencyMaxWidth`/`Height`), hides the HUD, dock, help overlay, and focus
border, and freezes reflow. It
then shows the normal AutoHotkey error dialog. This keeps windows reachable
even if the script stops. Emergency mode is terminal: CapsLock and Ctrl+Q do
not resume it. Restart the script to restore tiling.

This guard covers unhandled AutoHotkey errors and error exits. A forced
process kill or native crash cannot run in-process code; restart the script
after such a crash.

---

## ⌨️ Vim Text Navigation & Editing

### Mode System
- **CapsLock**: Toggle Vim mode ON/OFF from any active mode
- **v**: Switch between Normal (green) and Visual (red) mode
- **m**: Enter Targeting (magenta) from Normal
- **i**: Enter Insert (blue) at the cursor
- **Esc**: Return to Normal from Insert, Visual, or Targeting; does nothing in Normal
- **F1**: Toggle the combined keybind reference
- **Insert**: Keys type normally; Esc returns to Normal, CapsLock turns Vim off, and F1 toggles help
- The Vim mode is global, not per window

### Help Overlay
Press **F1** in Normal, Visual, Insert, or Targeting mode to toggle a combined
keybind reference. It shows Normal, Visual, Insert, and Targeting sections in
one window, with the current mode marked by `<< current`. Press **F1** or
**Esc** to close it. Closing help from Targeting returns to the same grid and
pointer position. This is a static information window, not a which-key menu;
other keys are ignored while it is open. F1 is not bound when Vim mode is off.

### Basic Navigation (Normal Mode)
| Key | Action |
|-----|--------|
| **h** | Move left |
| **j** | Move down |
| **k** | Move up |
| **l** | Move right |
| **w** | Next word (Ctrl+Right) |
| **b** | Previous word (Ctrl+Left) |
| **e** | End of word |
| **0** | Start of line (Home) |
| **$** | End of line (End) |

### Document Navigation
| Key | Action |
|-----|--------|
| **gg** | Go to top of document (Ctrl+Home) |
| **G** (Shift+g) | Go to bottom (Ctrl+End) |
| **Ctrl+D** | Page down |
| **Ctrl+U** | Page up |

### Find Commands
| Key | Action |
|-----|--------|
| **f{char}** | Find character forward on line |
| **t{char}** | Till character (stop before it) |
| **/** | Open find dialog (Ctrl+F) and turn Vim mode Off |

### Editing Commands (Normal Mode)
| Key | Action |
|-----|--------|
| **i** | Enter Insert at the cursor |
| **a** | Append after the cursor, then Insert |
| **A** (Shift+a) | Append at end of line, then Insert |
| **o** | Open new line below, then Insert |
| **O** (Shift+o) | Open new line above, then Insert |
| **x** | Delete character |
| **dd** | Delete entire line |
| **c** | Change word (delete next word, then Insert) |
| **u** | Undo |
| **Ctrl+R** | Redo |

`cc` and `cw` are not implemented by the current single-key `c` handler. `c`
performs a word change; `cc` and `cw` currently type the second character. Use
`dd` followed by `o` for a line change.

### Yank (Copy) & Paste
| Key | Action |
|-----|--------|
| **yy** | Yank (copy) entire line |
| **p** | Paste |

### Visual Mode
| Key | Action |
|-----|--------|
| **v** | Toggle visual mode |
| **h/j/k/l** | Navigate while selecting text |
| **w/b/e/0/$** | Word/line navigation while selecting |
| **Ctrl+D/U** | Page down/up while selecting |
| **y** | Yank (copy) selection |
| **d** | Delete selection |
| **c** | Change selection (delete, then Insert) |
| **x** | Delete selection |
| **p** | Paste over the selection (Windows clipboard) |
| **i** | Collapse selection to its start, then Insert |
| **gg** | Extend selection to document start |
| **G** | Extend selection to document end |
| **Esc** | Return to Normal |

Unsupported in Visual mode: `V` (linewise), `Ctrl+V` (blockwise), `a`, `A`,
`o`, `O`, `>`, `<`, the Normal-only find commands (`f`, `t`, `/`), and the
`;` and `:` keys. These keys are swallowed in Visual mode so they do not type
into the document.

### Targeting Mode (Normal Mode Only)
| Key | Action |
|-----|--------|
| **m** | Enter Targeting on the monitor under the pointer |
| **h / j** (default) | Choose the top-left / top-right cell |
| **k / l** (default) | Choose the bottom-left / bottom-right cell |
| **Space** | Left click at the pointer; reset the grid to the first level |
| **r** | Right click at the pointer; reset the grid to the first level |
| **Backspace** | Undo one grid level and return to its center |
| **Esc** | Exit Targeting and return to Normal |
| **CapsLock** | Turn Vim off |
| **F1** | Toggle help; closing help returns to Targeting |

The grid covers the full monitor, including the taskbar. By default it is 2x2
with keys `h` top-left, `j` top-right, `k` bottom-left, and `l` bottom-right.
Press a cell key to move the pointer to the center of that cell and split it
into the next configured grid. Repeat to refine. Previous grid outlines remain
faintly visible. The grid size and keys are configurable; keys are assigned row
by row.

The grid stops splitting below `TargetMinCellSize` (8 px by default). The dark
overlay is click-through and does not take mouse focus. `Space` left-clicks and
`r` right-clicks at the current pointer; after either click the grid returns to
the first configured level without moving the pointer.

### Command Mode (Normal Mode Only)
| Command | Action |
|---------|--------|
| **:** | Open command prompt |
| **:w** | Save file (Ctrl+S) |
| **:q** | Quit/close (Alt+F4) |
| **:wq** | Save and quit |
| **;** | Swallowed in Normal and Visual mode |

The command box accepts an optional leading `:` and is case-insensitive.
It restores focus to the window that was active before the box opened. These
are application shortcuts, not Vim commands: in a browser, `:w` opens
"Save Page" and `:q` closes the whole browser window.

### Window Navigation by Number (Normal Mode Only)
| Key | Action |
|-----|--------|
| **1** | Jump to window #1 in stack |
| **2** | Jump to window #2 in stack |
| **3** | Jump to window #3 in stack |
| **4** | Jump to window #4 in stack |
| **5** | Jump to window #5 in stack |
| **6** | Jump to window #6 in stack |
| **7** | Jump to window #7 in stack |
| **8** | Jump to window #8 in stack |
| **9** | Jump to window #9 in stack |

**Note**: Numbers correspond to the position shown in the dock. The flash
message confirms "WINDOW X"; an out-of-range number shows "WINDOW X NOT FOUND",
and a hidden target shows "WINDOW X NOT AVAILABLE".

---

## 🎨 HUD & Visual Feedback

### Mode HUD (Top-Right)
- **Green "VIM: NORMAL"**: Normal mode active
- **Red "VIM: VISUAL"**: Visual selection mode active
- **Blue "VIM: INSERT"**: Insert mode active
- **Magenta "VIM: TARGET"**: Targeting mode active
- **Orange "SUSPENDED"**: Script is suspended (all actions paused)
- **Hidden**: Vim mode off (normal typing)
- **Yellow Flash**: Shows temporary messages (e.g., "DESKTOP 2", "WINDOW 3")
- **Anchored to the work area**: The HUD measures its real auto-sized width and
  positions itself from the top-right corner, so the text stays fully on screen

### Window Dock (Top-Center)
- **Always visible** when windows are managed (hidden when suspended)
- **Transparent background**
- **Green underline**: Current active window
- **Window numbers**: Below each icon showing stack position
- **Active window number**: Bright green
- **Inactive window numbers**: Gray
- **Centered on the work area**: The dock measures its real auto-sized width
- **Updates automatically** when navigating/closing windows

---

## 🔍 How It Works

### Window Stack Management
1. On startup, eligible visible windows with title bars are added to the stack;
   floating windows are skipped
2. New eligible windows are automatically detected and added via Windows Shell Hook
3. Closed or hidden windows are automatically removed; a visible floating window
   is removed without being treated as closed, and a visible managed window is
   re-added when it is activated again
4. Windows are laid out left to right in stack order, each with its remembered width
5. The view offset scrolls only when the focused window would leave the screen,
   matching niri's `center-focused-column "never"` behavior
6. **Taskbar click support**: Clicking a window in the taskbar properly activates and focuses it
7. **Suspension handling**: When suspended, all window events are ignored and state is preserved

### Dynamic Work Area
- The script detects the taskbar edge and size with `SHAppBarMessage(ABM_GETTASKBARPOS)`
- A left or right taskbar shifts the window origin and reduces the usable width
- A top or bottom taskbar reduces the usable height on that side
- The HUD and dock are positioned inside the usable area, so they do not sit behind the taskbar
- The top `BarHeight` strip is reserved for the HUD and dock; the bottom margin is only `Gap`
- When the taskbar is hidden (Ctrl+T): windows use the full screen again
- **Overlay Mode**: Fills the usable area with one gap on each edge
- All windows automatically reflow when the taskbar moves or its visibility changes

### Desktop Awareness
- Uses a Map to track which desktops have been initialized
- On desktop switch, checks if arrangement is needed
- Waits 200ms after desktop switch for animation to complete
- The script keeps one global window stack; Windows preserves window positions
  on other desktops. There is no separate per-desktop stack.

### Vim Mode
- CapsLock toggles a global `VimMode` variable (0=off, 1=normal, 2=visual, 3=insert, 4=targeting)
- Vim command hotkeys use `#HotIf VimMode == 1 || VimMode == 2`
- Insert mode intercepts Esc, CapsLock, and F1; all other keys pass through
- Visual mode adds Shift to navigation keys for text selection
- Targeting mode uses an `InputHook` to capture keys while the grid is active; the hook blocks keys from reaching the application
- Layout hotkeys are disabled in Insert and Targeting modes

---

## ⚙️ Configuration

Defaults live in `config.ahk`. To override them, copy `paper-vim.example.ini`
to `paper-vim.ini` next to `paper-vim.ahk` and edit only the values you need.
Omitted values keep their defaults. Restart Paper-VIM after changing the file.

`paper-vim.ini` is ignored by Git. User-facing settings are configurable; runtime
state such as window handles, GUI controls, caches, and timers is not.

```ini
[Layout]
Gap=8
BarHeight=60
TaskbarMode=auto
TaskbarSize=0

[Colors]
HUDBackgroundColor=121212
NormalModeColor=c00FF00
TargetingModeColor=cFF00FF

[Targeting]
TargetGridRows=2
TargetGridCols=2
TargetGridKeys=h, j, k, l

[Exclusions]
Processes=Microsoft.CmdPal.UI.exe
Classes=

[Keys.Normal]
Target=q

[Keys.Manage]
NextWindow=F6

[Keys.Text]
Left=F5
```

### Settings

The example file lists every setting and default:

- `[Layout]` — ratios, gaps, emergency bounds, taskbar mode and size
- `[Colors]` — HUD, dock, mode, flash, and suspended colors
- `[FocusBorder]` — enabled flag, color, thickness, update interval
- `[Fonts]` — UI font family and sizes
- `[Dock]` — icon size, spacing, side counts, margins, position
- `[HUD]` — margins, position, width, flash duration
- `[Timing]` — double-key timeout, reflow debounce, desktop, dock, and tooltip delays
- `[Targeting]` — minimum cell size, rows, columns, and key list
- `[Exclusions]` — process names and window classes that open as floating windows

Values are parsed by type: integers, numbers, booleans (`true`/`false` or
`1`/`0`), strings, and comma-separated lists (including key lists). Unknown
sections or keys produce a warning; invalid values stop startup with an error.

### Keybindings

Every user-facing hotkey has an action name. Override the key in the matching
`[Keys.<context>]` section:

```ini
[Keys.Global]
ToggleVim=CapsLock

[Keys.Normal]
Target=m
Find=f
DeleteLine=d

[Keys.Text]
Left=h
Down=j
Up=k
Right=l

[Keys.Visual]
Delete=d
Change=c
```

Use AutoHotkey key names and modifiers: `n`, `Tab`, `^j`, `+4`, `SC027`, `^+1`.
The example file lists all action names and defaults. Duplicate keys in one
context, empty keys, and keys that AutoHotkey cannot register stop startup with
an error. Restart is required after editing keybindings.

### Targeting limits

`TargetGridKeys` must contain exactly `TargetGridRows * TargetGridCols` unique
keys. The keys are assigned row by row. The grid must contain at least two
cells; a 1x1 grid is invalid. `Esc`, `Backspace`, `Space`, `r`, `F1`, and
`CapsLock` are reserved for Targeting controls and cannot be cell keys. Invalid
targeting configuration shows `TARGET CONFIG INVALID` instead of opening the
grid. Short key labels work best in the grid overlay.

### Window style constants

Window style and message constants remain in `paper-vim.ahk`; they are not
user settings.

## 🐛 Troubleshooting

### Windows don't arrange automatically
- Press **z** to manually trigger reflow
- Ensure windows have title bars (minimalist apps may not be detected)

### Windows overlap the taskbar
- The script auto-detects the taskbar edge and size. If your taskbar is unusual,
  set `TaskbarMode=left`, `top`, `right`, or `bottom` in `[Layout]` and set
  `TaskbarSize` to the taskbar width or height in pixels
- Use `TaskbarMode=none` to let windows use the whole screen

### Some windows don't work correctly
- **System windows** like Task Manager, Windows Settings, and some OS dialogs may not respond to window management commands
- These windows often have special protections that prevent automated positioning
- Installers, owned dialogs, and PowerToys Command Palette open as floating windows automatically
- Add other process names or window classes under `[Exclusions]`
- **Workaround**: Use **Ctrl+Shift+D** to remove a managed window from the stack

### Dock shows blank/missing icons
If the dock shows blank spaces or default icons instead of app icons:

- **Admin Rights Issue**: When running without administrator privileges, system-level apps (like Task Manager or Windows Settings) may refuse to share their icon handle via `SendMessage` due to **UIPI (User Interface Privilege Isolation)** restrictions
- **Solution**: Run the script as administrator (right-click → "Run as administrator")
- **Alternative**: Accept that some system windows will show default icons in the dock

### Dock repeats icons with fewer than five windows
- The dock always fills five slots and wraps around the stack, so an icon can
  repeat when fewer than five windows are managed. This is expected.

### Vim mode stuck on
- Press **CapsLock** to toggle off
- Press **Esc** to return to Normal from Insert or Visual
- If the HUD is hidden, Vim mode is off; press **CapsLock** to enter Normal

### Script suspended and won't respond to hotkeys
- Press **CapsLock** to resume and enter Normal mode
- Press **Ctrl+Q** to toggle suspension off
- Orange "SUSPENDED" indicator confirms suspension state

### Desktop switching doesn't work
- Ensure Windows Virtual Desktops are enabled
- Check that Ctrl+Win+Arrow shortcuts work normally

---

## 📝 Tips & Best Practices

1. **Learn gradually**: Start with just `n`/`Tab` for window navigation
2. **Use the dock**: Visual feedback and window numbers help learn the window stack
3. **Quick window switching**: Press the number shown in the dock to jump directly to a window
4. **Combine modes**: Navigate with `hjkl`, select with `v`, edit normally
5. **Desktop workflow**: Organize projects across virtual desktops
6. **Stack reordering**: Use Ctrl+H/L to arrange windows by priority
7. **Build columns**: Use Ctrl+Shift+1/2/3 to make the active window 25%, 50%, or 75% wide; two 50% windows or four 25% windows fit side by side
8. **Center when needed**: Press Ctrl+Shift+C to center the active window after resizing or navigating
9. **Maximize screen space**: Use Ctrl+T to hide taskbar and Ctrl+F for overlay mode for distraction-free work
10. **Suspend when needed**: Use Ctrl+Q to temporarily disable tiling, then resume quickly with CapsLock
11. **Taskbar integration**: Click windows in taskbar to activate them - the script properly handles focus

---

## 📜 License

MIT. Built with AutoHotkey v2.0.

## 🙏 Credits

Inspired by:
- **PaperWM**: Scrollable tiling window manager for GNOME
- **Vim**: The legendary text editor
- **i3/sway**: Tiling window manager concepts

---

## 🔗 Resources

- [AutoHotkey v2.0 Documentation](https://www.autohotkey.com/docs/v2/)
- [PaperWM Project](https://github.com/paperwm/PaperWM)
- [Vim Documentation](https://www.vim.org/docs.php)

Enjoy your enhanced Windows workflow! 🚀