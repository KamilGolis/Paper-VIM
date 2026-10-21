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
- **Script Suspension**: Pause all window management with state preservation
- **HUD Indicators**: Visual feedback for current mode, desktop, and suspension state
- **Active Window Border**: A click-through cyan outline marks the active managed window
- **Fully Customizable**: All colors, fonts, and timing variables configurable

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
- When **ON**: Vim keybindings are active; the HUD shows NORMAL, VISUAL, or INSERT
- **F1**: Toggle the combined keybind reference

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

### Active Window Border
A 3 px cyan outline marks the active managed window, so two adjacent windows are
easy to tell apart.

- The border is drawn outside the visible DWM frame, so it does not cover the
  window content.
- It is click-through and never takes keyboard focus.
- It follows moves, resizes, focus changes, and width changes.
- It is hidden in Off mode, while the help overlay is open, while the script is
  suspended, in emergency mode, in Overlay Mode, and for maximized or fullscreen
  windows.
- Like the rest of the layout, it currently follows the main-monitor limitation.

### Visual Dock
A transparent dock at the top-center of your screen shows:
- **5 window icons** in stack order
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
`EmergencyMaxWidth`/`Height`), hides the HUD and dock, and freezes reflow. It
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
- **i**: Enter Insert (blue) at the cursor
- **Esc**: Return to Normal from Insert or Visual; does nothing in Normal
- **F1**: Toggle the combined keybind reference
- **Insert**: Keys type normally; Esc returns to Normal, CapsLock turns Vim off, and F1 toggles help
- The Vim mode is global, not per window

### Help Overlay
Press **F1** in Normal, Visual, or Insert mode to toggle a combined keybind
reference. It shows Normal, Visual, and Insert sections in one window, with the
current mode marked by `<< current`. Press **F1** or **Esc** to close it. This
is a static information window, not a which-key menu; other keys are ignored
while it is open. F1 is not bound when Vim mode is off.

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
| **/** | Open find dialog (Ctrl+F) |

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
| **cc** | Change line (delete, then Insert) |
| **cw** | Change word (delete, then Insert) |
| **u** | Undo |
| **Ctrl+R** | Redo |

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
| **gg** | Extend selection to document start |
| **G** | Extend selection to document end |
| **Esc** | Return to Normal |

Unsupported in Visual mode: `V` (linewise), `Ctrl+V` (blockwise), `a`, `A`,
`o`, `O`, `>`, `<`, the Normal-only find commands (`f`, `t`, `/`), and the
`;` and `:` keys. These keys are swallowed in Visual mode so they do not type
into the document.

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

**Note**: Numbers correspond to the position shown in the dock. Flash message confirms: "WINDOW X" or "WINDOW X NOT FOUND"

---

## 🎨 HUD & Visual Feedback

### Mode HUD (Top-Right)
- **Green "VIM: NORMAL"**: Normal mode active
- **Red "VIM: VISUAL"**: Visual selection mode active
- **Blue "VIM: INSERT"**: Insert mode active
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
1. On startup, all existing windows with title bars are added to the stack
2. New windows are automatically detected and added via Windows Shell Hook
3. Closed or hidden windows are automatically removed; a visible window is
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
- Each desktop maintains its own window arrangement

### Vim Mode
- CapsLock toggles a global `VimMode` variable (0=off, 1=normal, 2=visual, 3=insert)
- Vim command hotkeys use `#HotIf VimMode == 1 || VimMode == 2`
- Insert mode intercepts Esc, CapsLock, and F1; all other keys pass through
- Visual mode adds Shift to navigation keys for text selection
- Layout hotkeys are disabled in Insert mode

---

## ⚙️ Configuration (Advanced)

All configuration variables are defined at the top of `paper-vim.ahk`. You can customize the behavior by editing these values:

### Window Layout Configuration

```ahk
Global FullWidthRatio := 1.0                 ; "Full" preset; selects focus/peek mode
Global FocusWidthRatio := 0.85               ; Focus-mode window width
Global WindowWidths := Map()                 ; Per-window width ratios (remembered at runtime)
Global Gap := 8                              ; Gap between windows and work-area edges
Global BarHeight := 60                       ; Top strip reserved for the HUD and dock
Global TaskbarMode := "auto"                 ; auto, left, top, right, bottom, or none
Global TaskbarSize := 0                      ; Fixed taskbar size in px (0 = 48); used with a fixed mode
```

Width presets are `0.25`, `0.50`, and `0.75` of the usable work area. The pixel
width is computed as `workWidth * ratio - Gap * (1 + ratio)`, which incorporates
the gaps so the presets tile evenly.

The full preset is different: it uses `FocusWidthRatio` (85% by default) and the
same `Gap` for its gutters as the tiled presets. The remaining space is the
visible slice of the previous and next window. On a 3840 px screen this leaves
about 7.3% of each neighbour visible.

`TaskbarMode := "auto"` reads the taskbar position from Windows. If detection
fails on your setup, set a fixed edge and size, for example:

```ahk
Global TaskbarMode := "left"
Global TaskbarSize := 72
```

### Visual Customization - Colors

```ahk
Global HUDBackgroundColor := "121212"        ; VIM HUD background (dark gray)
Global DockBackgroundColor := "1a1a1a"       ; Dock background (darker gray)
Global NormalModeColor := "c00FF00"          ; Normal mode text color (green)
Global VisualModeColor := "cFF0000"          ; Visual mode text color (red)
Global InsertModeColor := "c00BFFF"          ; Insert mode text color (blue)
Global FlashMsgColor := "cFFFF00"            ; Flash message color (yellow)
Global SuspendedModeColor := "cFF8800"       ; Suspended mode text color (orange)
Global ActiveIndicatorColor := "00FF00"      ; Dock active window underline (green)
Global DockInactiveNumberColor := "c888888"  ; Dock inactive window number color (gray)
```

### Font Configuration

```ahk
Global FontFamily := "Segoe UI"              ; Font family used throughout UI
Global HUDFontSize := "s16"                  ; HUD text size
Global HUDFontWeight := "w800"               ; HUD text weight (bold)
Global DockNumberFontSize := "s8"            ; Dock window number text size
```

### Dock Configuration

```ahk
Global DockIconSize := 32                    ; Size of dock icons in pixels
Global DockIconSpacing := 8                  ; Spacing between dock icons
Global DockLeftCount := 2                    ; Number of icons shown left of active
Global DockRightCount := 2                   ; Number of icons shown right of active
Global DockMarginX := 12                     ; Dock horizontal margin
Global DockMarginY := 8                      ; Dock vertical margin
Global DockPosY := 10                        ; Dock Y position from the top of the work area
```

### HUD Configuration

```ahk
Global HUDMarginRight := 20                  ; HUD distance from the right edge of the work area
Global HUDPosY := 40                         ; HUD Y position from the top of the work area
Global HUDWidth := 220                       ; HUD text control width; window auto-sizes
```

### Focus Border Configuration

```ahk
Global FocusBorderEnabled := true            ; Draw a focus border around the active window
Global FocusBorderColor := "00A8FF"          ; Focus border color (cyan)
Global FocusBorderThickness := 3             ; Border thickness in physical pixels
Global FocusBorderUpdateInterval := 50       ; Move/resize tracking interval (ms)
```

### Timing Configuration

```ahk
Global FlashDuration := 800                  ; Flash message duration (milliseconds)
Global DblClickTimeout := 400                ; Timeout for double-key commands (gg, dd, etc.)
Global DebounceDelay := 50                   ; Debounce delay for window reflow (ms)
Global DesktopSwitchDelay := 200             ; Delay after desktop switch before arranging (ms)
Global DockUpdateDelay := 100                ; Delay for dock update after window change (ms)
Global TooltipDuration := 1000               ; Tooltip display duration (ms)
```

### Window Style Constants

```ahk
Global TitleBarMask := 0x00C00000            ; Window style mask for title bar detection
```

---

## 🐛 Troubleshooting

### Windows don't arrange automatically
- Press **z** to manually trigger reflow
- Ensure windows have title bars (minimalist apps may not be detected)

### Windows overlap the taskbar
- The script auto-detects the taskbar edge and size. If your taskbar is unusual,
  set `TaskbarMode` to `"left"`, `"top"`, `"right"`, or `"bottom"` and set
  `TaskbarSize` to the taskbar width or height in pixels
- Use `TaskbarMode := "none"` to let windows use the whole screen

### Some windows don't work correctly
- **System windows** like Task Manager, Windows Settings, and some OS dialogs may not respond to window management commands
- These windows often have special protections that prevent automated positioning
- **Workaround**: Use **Ctrl+Shift+D** to remove them from the managed stack

### Dock shows blank/missing icons
If the dock shows blank spaces or default icons instead of app icons:

- **Admin Rights Issue**: When running without administrator privileges, system-level apps (like Task Manager or Windows Settings) may refuse to share their icon handle via `SendMessage` due to **UIPI (User Interface Privilege Isolation)** restrictions
- **Solution**: Run the script as administrator (right-click → "Run as administrator")
- **Alternative**: Accept that some system windows will show default icons in the dock

### Dock shows duplicate icons
- This should be fixed; if it occurs, restart the script

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