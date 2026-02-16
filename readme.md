# Paper-VIM: Vim Keybindings + PaperWM like Window Manager

A powerful AutoHotkey v2.0 script that combines vim-style keyboard navigation with a tiling window manager inspired by PaperWM. Navigate your windows and text with vim keybindings, manage multiple virtual desktops, and visualize your window stack with an elegant dock.

## Motivation

This script was born out of necessity. Unable to use Linux with my preferred setup ([niri](https://github.com/YaLTeR/niri)) on my company computer, and lacking admin rights to install alternative window managers, I created this as a bare minimum implementation of the workflow I wanted. It brings PaperWM-style tiling and vim navigation to Windows without requiring system-level changes or administrative privileges.
**Current Status**: This is still in early phase of development with lots of bugs and limitations (e.g., works only with main monitor setups). However, as a proof of concept, it works quite well for basic workflows. More niri-like features are planned for future releases.
## 🚀 Features

- **Vim Mode Integration**: System-wide vim keybindings for text editing and navigation
- **PaperWM-Style Window Management**: Automatic horizontal scrolling window layout
- **Dynamic Height Adjustment**: Windows auto-resize based on taskbar visibility
- **Taskbar Toggle**: Hide/show Windows taskbar with automatic window reflow
- **Visual Window Dock**: Live icon preview showing your window stack position with numbered indicators
- **Direct Window Navigation**: Jump to any window by pressing its number (1-9)
- **Multi-Desktop Support**: Automatic window arrangement across virtual desktops
- **Smart Window Tracking**: Automatic management of new/closed windows with taskbar click support
- **Script Suspension**: Pause all window management with state preservation
- **HUD Indicators**: Visual feedback for current mode, desktop, and suspension state
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
- **CapsLock**: Toggle between Normal mode and Off
  - When **suspended**: Resume script and enter Normal mode
- When **OFF**: Your keyboard works normally
- When **ON**: Vim keybindings are active (green HUD shown)

### Window Navigation
- **n**: Next window in stack
- **p**: Previous window in stack
- **1-9**: Jump directly to window at that position in stack
- **z**: Reflow/refresh window layout
- **Ctrl+Q**: Suspend/resume script (preserves window state)
- **Ctrl+T**: Toggle taskbar visibility (windows auto-resize)
- **Ctrl+F**: Toggle overlay mode (fullscreen stacked windows)

The active window automatically centers on screen with a scrolling effect!

---

## 📚 Complete Feature Guide

## 🪟 Window Management (PaperWM Style)

### Automatic Layout
- All windows are automatically arranged in a horizontal scrollable stack
- Each window takes 95% of screen width with small gaps
- Windows scroll horizontally as you navigate
- Active window is always centered

### Stack Operations
- **n**: Cycle to next window (right)
- **p**: Cycle to previous window (left)
- **1-9**: Jump directly to window at position 1-9 in stack
- **Ctrl+H**: Swap current window with the one on its left
- **Ctrl+L**: Swap current window with the one on its right
- **z**: Manually reflow/refresh window positions

### Layout Modes
- **Ctrl+F**: Toggle Overlay Mode (all windows maximized with small gaps, stacked)
- **Ctrl+T**: Toggle Windows Taskbar visibility (windows auto-resize to use available space)
- **Ctrl+Shift+D**: Remove active window from managed stack

### Visual Dock
A transparent dock at the top-center of your screen shows:
- **5 window icons** in stack order
- **Window numbers** below each icon (shows position in stack)
- **Center icon** (underlined in green): Current active window with bright green number
- **Left 2 icons**: Previous windows (press `p` to go left) with gray numbers
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

---

## ⌨️ Vim Text Navigation & Editing

### Mode System
- **CapsLock**: Toggle Normal mode ON/OFF
- **v**: Switch between Normal (green) and Visual (red) mode
- **i** or **Esc**: Exit to normal typing (mode OFF)

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
| **i** | Enter insert mode (exit vim) |
| **a** | Append (move right, then insert) |
| **A** (Shift+a) | Append at end of line |
| **o** | Open new line below, insert |
| **O** (Shift+o) | Open new line above, insert |
| **x** | Delete character |
| **dd** | Delete entire line |
| **cc** | Change line (delete + insert) |
| **cw** | Change word |
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
| **c** | Change selection (delete + insert) |
| **x** | Delete selection |

### Command Mode
| Command | Action |
|---------|--------|
| **:** | Open command prompt |
| **:w** | Save file (Ctrl+S) |
| **:q** | Quit/close (Alt+F4) |
| **:wq** | Save and quit |

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
- **Orange "SUSPENDED"**: Script is suspended (all actions paused)
- **Hidden**: Vim mode off (normal typing)
- **Yellow Flash**: Shows temporary messages (e.g., "DESKTOP 2", "WINDOW 3")

### Window Dock (Top-Center)
- **Always visible** when windows are managed (hidden when suspended)
- **Transparent background**
- **Green underline**: Current active window
- **Window numbers**: Below each icon showing stack position
- **Active window number**: Bright green
- **Inactive window numbers**: Gray
- **Updates automatically** when navigating/closing windows

---

## 🔍 How It Works

### Window Stack Management
1. On startup, all existing windows with title bars are added to the stack
2. New windows are automatically detected and added via Windows Shell Hook
3. Closed windows are automatically removed
4. Windows are positioned based on their position relative to the active window
5. **Taskbar click support**: Clicking a window in the taskbar properly activates and focuses it
6. **Suspension handling**: When suspended, all window events are ignored and state is preserved

### Dynamic Height Calculation
- Window height automatically adjusts based on taskbar visibility
- When taskbar is **hidden** (Ctrl+T): Windows gain additional height equal to taskbar height
- When taskbar is **visible**: Windows account for taskbar space at bottom
- **Overlay Mode**: Maximizes height with small gaps (top gap, and bottom gap that includes taskbar when visible)
- All windows automatically reflow when taskbar visibility changes

### Desktop Awareness
- Uses a Map to track which desktops have been initialized
- On desktop switch, checks if arrangement is needed
- Waits 200ms after desktop switch for animation to complete
- Each desktop maintains its own window arrangement

### Vim Mode
- CapsLock toggles a global `Mode` variable (0=off, 1=normal, 2=visual)
- Conditional hotkeys (`#HotIf Mode > 0`) activate vim bindings
- Visual mode adds Shift to navigation keys for text selection
- Normal mode allows quick editing without entering insert mode

---

## ⚙️ Configuration (Advanced)

All configuration variables are defined at the top of `paper-vim.ahk`. You can customize the behavior by editing these values:

### Window Layout Configuration

```ahk
Global TargetWidth := A_ScreenWidth * 0.95  ; Window width (95% of screen)
Global Gap := 8                              ; Gap between windows and screen edges
Global BarHeight := 60                       ; Reserved space at top for HUD and dock
Global TaskbarHeight := 48                   ; Windows taskbar height (for calculations)
```

### Visual Customization - Colors

```ahk
Global HUDBackgroundColor := "121212"        ; VIM HUD background (dark gray)
Global DockBackgroundColor := "1a1a1a"       ; Dock background (darker gray)
Global NormalModeColor := "c00FF00"          ; Normal mode text color (green)
Global VisualModeColor := "cFF0000"          ; Visual mode text color (red)
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
Global DockPosY := 10                        ; Dock Y position from top
```

### HUD Configuration

```ahk
Global HUDPosX := A_ScreenWidth - 240        ; HUD X position from left
Global HUDPosY := 40                         ; HUD Y position from top
Global HUDWidth := 220                       ; HUD width in pixels
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
- Press **i** or **Esc** as backup

### Script suspended and won't respond to hotkeys
- Press **CapsLock** to resume and enter Normal mode
- Press **Ctrl+Q** to toggle suspension off
- Orange "SUSPENDED" indicator confirms suspension state

### Desktop switching doesn't work
- Ensure Windows Virtual Desktops are enabled
- Check that Ctrl+Win+Arrow shortcuts work normally

---

## 📝 Tips & Best Practices

1. **Learn gradually**: Start with just `n`/`p` for window navigation
2. **Use the dock**: Visual feedback and window numbers help learn the window stack
3. **Quick window switching**: Press the number shown in the dock to jump directly to a window
4. **Combine modes**: Navigate with `hjkl`, select with `v`, edit normally
5. **Desktop workflow**: Organize projects across virtual desktops
6. **Stack reordering**: Use Ctrl+H/L to arrange windows by priority
7. **Maximize screen space**: Use Ctrl+T to hide taskbar and Ctrl+F for overlay mode for distraction-free work
8. **Suspend when needed**: Use Ctrl+Q to temporarily disable tiling, then resume quickly with CapsLock
9. **Taskbar integration**: Click windows in taskbar to activate them - the script properly handles focus

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