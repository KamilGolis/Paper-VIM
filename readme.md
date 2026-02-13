# Paper-VIM: Vim Keybindings + PaperWM like Window Manager

A powerful AutoHotkey v2.0 script that combines vim-style keyboard navigation with a tiling window manager inspired by PaperWM. Navigate your windows and text with vim keybindings, manage multiple virtual desktops, and visualize your window stack with an elegant dock.

## 🚀 Features

- **Vim Mode Integration**: System-wide vim keybindings for text editing and navigation
- **PaperWM-Style Window Management**: Automatic horizontal scrolling window layout
- **Dynamic Height Adjustment**: Windows auto-resize based on taskbar visibility
- **Taskbar Toggle**: Hide/show Windows taskbar with automatic window reflow
- **Visual Window Dock**: Live icon preview showing your window stack position
- **Multi-Desktop Support**: Automatic window arrangement across virtual desktops
- **Smart Window Tracking**: Automatic management of new/closed windows
- **HUD Indicators**: Visual feedback for current mode and desktop

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
- When **OFF**: Your keyboard works normally
- When **ON**: Vim keybindings are active (green HUD shown)

### Window Navigation
- **n**: Next window in stack
- **p**: Previous window in stack
- **z**: Reflow/refresh window layout
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
- **Center icon** (underlined in green): Current active window
- **Left 2 icons**: Previous windows (press `p` to go left)
- **Right 2 icons**: Next windows (press `n` to go right)
- **Infinite scrolling**: Icons wrap around at stack edges

Example: With windows [1,2,3,4,5], if you're on window 3:
```
Dock shows: [1] [2] [3̲] [4] [5]
```

If you're on window 5:
```
Dock shows: [3] [4] [5̲] [1] [2]
```

---

## 🖥️ Virtual Desktop Management

### Desktop Navigation
- **Ctrl+J**: Switch to previous virtual desktop
- **Ctrl+K**: Switch to next virtual desktop
- **Ctrl+1** through **Ctrl+5**: Jump directly to desktop 1-5

### Moving Windows Between Desktops
- **Ctrl+Shift+J**: Move active window to previous desktop
- **Ctrl+Shift+K**: Move active window to next desktop

### Auto-Arrangement
- On startup, arranges all windows on your current desktop
- When switching to a new desktop, automatically arranges its windows
- Each desktop remembers if it's been initialized
- Flash message confirms: "DESKTOP X ARRANGED"

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

---

## 🎨 HUD & Visual Feedback

### Mode HUD (Top-Right)
- **Green "VIM: NORMAL"**: Normal mode active
- **Red "VIM: VISUAL"**: Visual selection mode active
- **Hidden**: Vim mode off (normal typing)
- **Yellow Flash**: Shows temporary messages (e.g., "DESKTOP 2")

### Window Dock (Top-Center)
- **Always visible** when windows are managed
- **Transparent background**
- **Green underline**: Current active window
- **Updates automatically** when navigating/closing windows

---

## 🔍 How It Works

### Window Stack Management
1. On startup, all existing windows with title bars are added to the stack
2. New windows are automatically detected and added via Windows Shell Hook
3. Closed windows are automatically removed
4. Windows are positioned based on their position relative to the active window

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

Edit these variables at the top of `paper-vim.ahk`:

```ahk
Global TargetWidth := A_ScreenWidth * 0.95  ; Window width (95% of screen)
Global Gap := 8                              ; Gap between windows
Global BarHeight := 60                       ; Reserved space at top (for dock/HUD)
Global TaskbarHeight := 48                   ; Windows taskbar height (for calculations)
```

### Visual Customization
- **Dock icon size**: Change `iconSize := 32` in `UpdateDock()`
- **Dock icon count**: Modify `leftCount := 2` and `rightCount := 2`
- **HUD colors**: Edit color codes in `UpdateHUD()` (00FF00=green, FF0000=red)

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

### Desktop switching doesn't work
- Ensure Windows Virtual Desktops are enabled
- Check that Ctrl+Win+Arrow shortcuts work normally

---

## 📝 Tips & Best Practices

1. **Learn gradually**: Start with just `n`/`p` for window navigation
2. **Use the dock**: Visual feedback helps learn the window stack
3. **Combine modes**: Navigate with `hjkl`, select with `v`, edit normally
4. **Desktop workflow**: Organize projects across virtual desktops
5. **Stack reordering**: Use Ctrl+H/L to arrange windows by priority
6. **Maximize screen space**: Use Ctrl+T to hide taskbar and Ctrl+F for overlay mode for distraction-free work

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