; ==============================================================================
; Paper-VIM: Vim Keybindings + PaperWM Window Manager
; Version: 1.0.0
; Author: KamilGolis
; Description: Combines vim-style navigation with PaperWM tiling window manager
; License: MIT
; ==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
; Remove delay between window operations for speed
SetWinDelay -1
; Improve performance for window operations
SetControlDelay -1
; Set coordinate mode to screen for consistency
CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"

; ==============================================================================
; CONFIGURATION & GLOBAL VARIABLES
; ==============================================================================

; --- Window Layout Configuration ---
global WindowStack := []              ; Array of managed window handles
global TargetWidth := A_ScreenWidth * 0.95  ; Width of each window (95% of screen)
global Gap := 8                       ; Gap between windows and screen edges
global CenterX := (A_ScreenWidth - TargetWidth) / 2  ; Horizontal center position
global BarHeight := 60                ; Reserved space at top for HUD and dock
global TaskbarHeight := 48            ; Windows taskbar height (for height calculations)
global V_Top := 2 * Gap               ; Top Y position for windows
global OverlayMode := false           ; Toggle between tiling and overlay (fullscreen) mode
global TaskbarHidden := false         ; Track Windows taskbar visibility state

; --- Vim Mode State ---
global Mode := 0                      ; 0=Off, 1=Normal, 2=Visual

; --- Desktop Management ---
global CurrentDesktop := 1            ; Currently active virtual desktop number
global InitializedDesktops := Map()  ; Track which desktops have been auto-arranged
global ReflowTimer := 0               ; Debounce timer for window reflow operations

; --- Visual Customization ---
global HUDBackgroundColor := "121212"     ; VIM HUD background (dark gray)
global DockBackgroundColor := "1a1a1a"    ; Dock background (darker gray)
global NormalModeColor := "c00FF00"       ; Normal mode text color (green)
global VisualModeColor := "cFF0000"       ; Visual mode text color (red)
global FlashMsgColor := "cFFFF00"         ; Flash message color (yellow)
global ActiveIndicatorColor := "00FF00"   ; Dock active window underline (green)

; --- Dock Configuration ---
global DockIconSize := 32             ; Size of dock icons in pixels
global DockIconSpacing := 8           ; Spacing between dock icons
global DockLeftCount := 2             ; Number of icons shown left of active
global DockRightCount := 2            ; Number of icons shown right of active
global DockMarginX := 12              ; Dock horizontal margin
global DockMarginY := 8               ; Dock vertical margin
global DockPosY := 10                 ; Dock Y position from top
global DockIcons := []                ; Array of dock icon controls

; --- HUD Configuration ---
global HUDPosX := A_ScreenWidth - 240 ; HUD X position from left
global HUDPosY := 40                  ; HUD Y position from top
global HUDWidth := 220                ; HUD width in pixels
global FlashDuration := 800           ; Flash message duration in milliseconds

; --- Timing Configuration ---
global DblClickTimeout := 400         ; Timeout for double-key commands (gg, dd, etc.)
global DebounceDelay := 50            ; Debounce delay for window reflow (ms)
global DesktopSwitchDelay := 200      ; Delay after desktop switch before arranging (ms)
global DockUpdateDelay := 100         ; Delay for dock update after window change (ms)
global TooltipDuration := 1000        ; Tooltip display duration (ms)

; --- Window Style Constants ---
global TitleBarMask := 0x00C00000     ; Window style mask for title bar detection (WS_CAPTION)
global WS_POPUP := 0x80000000         ; Popup window style
global WS_EX_TOOLWINDOW := 0x80       ; Tool window extended style
global WS_EX_DLGMODALFRAME := 0x1     ; Dialog modal frame extended style

; --- Window Message Constants ---
global WM_GETICON := 0x007F           ; Get window icon message
global ICON_BIG := 0                  ; Large icon
global ICON_SMALL2 := 2               ; Small icon (alternative)
global GCL_HICON := -14               ; Get class icon

; --- Shell Hook Event Constants ---
global HSHELL_WINDOWCREATED := 1      ; Window created event
global HSHELL_WINDOWDESTROYED := 2    ; Window destroyed event
global HSHELL_WINDOWACTIVATED := 4    ; Window activated event
global HSHELL_FLASH := 32772          ; Window flash event

; ==============================================================================
; GUI INITIALIZATION
; ==============================================================================

; HUD Setup - Mode indicator
VimGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
VimGui.BackColor := HUDBackgroundColor
VimGui.SetFont("s16 w800", "Segoe UI")
VimText := VimGui.Add("Text", "Center w" HUDWidth, "VIM: NORMAL")
WinSetTransColor(HUDBackgroundColor, VimGui)

; Dock HUD Setup - Window stack visualizer
DockGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
DockGui.BackColor := DockBackgroundColor
WinSetTransColor(DockBackgroundColor, DockGui)
DockGui.MarginX := DockMarginX
DockGui.MarginY := DockMarginY

; ==============================================================================
; CORE FUNCTIONS
; ==============================================================================

; Update HUD display based on current mode
; @param NewState - Mode value: 0=Off, 1=Normal, 2=Visual
UpdateHUD(NewState) {
    global Mode := NewState
    if (Mode == 0) {
        VimGui.Hide()
    } else if (Mode == 1) {
        VimText.Opt(NormalModeColor)
        VimText.Value := "VIM: NORMAL"
        VimGui.Show("x" HUDPosX " y" HUDPosY " NoActivate")
    } else if (Mode == 2) {
        VimText.Opt(VisualModeColor)
        VimText.Value := "VIM: VISUAL"
        VimGui.Show("x" HUDPosX " y" HUDPosY " NoActivate")
    }
}

; Display temporary message in HUD
; @param Msg - Message to display
; @param Duration - How long to show message (default: FlashDuration)
FlashMessage(Msg, Duration := FlashDuration) {
    if (Mode > 0) {
        VimText.Opt(FlashMsgColor)
        VimText.Value := Msg
        SetTimer(() => UpdateHUD(Mode), -Duration)
    }
}

; Update dock display with current window stack
; Shows icons for windows around the active window with visual indicator
UpdateDock() {
    global WindowStack, DockGui

    ; Destroy entire GUI and recreate to avoid duplicates
    try DockGui.Destroy()
    catch
        ; Ignore destroy errors
    
    DockGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
    DockGui.BackColor := DockBackgroundColor
    WinSetTransColor(DockBackgroundColor, DockGui)
    DockGui.MarginX := DockMarginX
    DockGui.MarginY := DockMarginY

    if (WindowStack.Length == 0) {
        return
    }

    ; Get active window
    activeHwnd := WinActive("A")
    activeIndex := 0
    for i, hwnd in WindowStack {
        if (hwnd == activeHwnd) {
            activeIndex := i
            break
        }
    }

    if (activeIndex == 0) {
        return
    }

    ; Helper function to wrap index for circular navigation
    WrapIndex(idx) {
        while (idx < 1)
            idx += WindowStack.Length
        while (idx > WindowStack.Length)
            idx -= WindowStack.Length
        return idx
    }

    ; Build the dock from left to right
    xPos := 0

    ; Add left icons (previous windows, in correct order)
    leftIndices := []
    loop DockLeftCount {
        idx := WrapIndex(activeIndex - DockLeftCount + A_Index - 1)
        leftIndices.Push(idx)
    }

    for idx in leftIndices {
        try {
            iconPath := GetWindowIconPath(WindowStack[idx])
            pic := DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
            xPos += DockIconSize + DockIconSpacing
        }
        catch
            ; Skip windows that fail to get icon
            continue
    }

    ; Add center icon (active window) - with underline
    try {
        iconPath := GetWindowIconPath(WindowStack[activeIndex])
        pic := DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
        ; Add underline below active icon
        DockGui.Add("Text", "x" xPos " y" (DockIconSize + 2) " w" DockIconSize " h2 Background" ActiveIndicatorColor)
        xPos += DockIconSize + DockIconSpacing
    }
    catch
        ; Failed to add active window icon
        return

    ; Add right icons (next windows)
    loop DockRightCount {
        idx := WrapIndex(activeIndex + A_Index)
        try {
            iconPath := GetWindowIconPath(WindowStack[idx])
            pic := DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
            xPos += DockIconSize + DockIconSpacing
        }
        catch
            ; Skip windows that fail to get icon
            continue
    }

    ; Calculate total width and position dock at screen center
    totalIcons := DockLeftCount + 1 + DockRightCount
    totalWidth := (totalIcons * DockIconSize) + ((totalIcons - 1) * DockIconSpacing) + 24
    dockX := (A_ScreenWidth - totalWidth) / 2
    DockGui.Show("x" dockX " y" DockPosY " w" totalWidth " h" (DockIconSize + 16) " NoActivate")
}

; Get icon path or handle for a window
; @param hwnd - Window handle
; @return Icon path or handle string
GetWindowIconPath(hwnd) {
    if (!hwnd)
        return "*icon1 shell32.dll"
    
    ; Try to get the window's icon
    ; First, try to get large icon
    hIcon := 0
    try hIcon := SendMessage(WM_GETICON, ICON_BIG, 0, , hwnd)
    catch
        hIcon := 0

    if (!hIcon) {
        ; Try small icon
        try hIcon := SendMessage(WM_GETICON, ICON_SMALL2, 0, , hwnd)
        catch
            hIcon := 0
    }

    if (!hIcon) {
        ; Get icon from window class
        try hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", GCL_HICON, "Ptr")
        catch
            hIcon := 0
    }

    if (!hIcon) {
        ; Get icon from executable
        try {
            exePath := WinGetProcessPath(hwnd)
            if (exePath != "")
                return exePath
        }
        catch
            ; Continue to default icon
    }

    if (hIcon) {
        ; Return icon handle
        try {
            return "HICON:" hIcon
        }
        catch
            ; Fall through to default
    }

    ; Return default icon path if all else fails
    return "*icon1 shell32.dll"  ; Default Windows icon
}

; Calculate available window height based on taskbar visibility
; @return Available height in pixels
GetAvailableHeight() {
    global BarHeight, Gap, TaskbarHeight, TaskbarHidden
    baseHeight := A_ScreenHeight - BarHeight - (3 * Gap)
    ; If taskbar is hidden, add its height to available space
    return TaskbarHidden ? baseHeight + TaskbarHeight : baseHeight
}

; ==============================================================================
; SHELL HOOK (AUTOMATION)
; ==============================================================================

; Register shell hook to receive window creation/destruction events
if (!DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)) {
    MsgBox("Failed to register shell hook. Window automation may not work properly.", "Error", "Icon!")
}
OnMessage(DllCall("RegisterWindowMessage", "Str", "SHELLHOOK"), ShellMessage)

; Shell hook message handler
; @param wParam - Message type (1=created, 2=destroyed, 4/32772=activated)
; @param lParam - Window handle
ShellMessage(wParam, lParam, *) {
    if (wParam = HSHELL_WINDOWCREATED)
        ; Window Created
        ManageNewWindow(lParam)
    else if (wParam = HSHELL_WINDOWDESTROYED)
        ; Window Destroyed
        DeferredReflow()
    else if (wParam = HSHELL_WINDOWACTIVATED || wParam = HSHELL_FLASH)
        ; Window Activated or Flashed
        DeferredReflow()
}

; Debounced window reflow to prevent excessive updates
DeferredReflow() {
    global ReflowTimer
    if (ReflowTimer)
        SetTimer(ReflowTimer, 0)
    ReflowTimer := () => ReflowStack()
    ; Debounce: wait before reflowing to batch multiple updates
    SetTimer(ReflowTimer, -DebounceDelay)
}

; Add new window to management stack if it should be managed
; @param hwnd - Window handle to potentially manage
ManageNewWindow(hwnd) {
    if (!hwnd)
        return
    
    if (!WinExist(hwnd))
        return
    
    ; Check if window should be managed
    if (!ShouldManageWindow(hwnd))
        return
    
    ; Check if already in stack
    for item in WindowStack
        if (item == hwnd)
            return
    
    WindowStack.Push(hwnd)
    ReflowStack()
}

; Determines if a window should be managed by the tiling system
; @param hwnd - Window handle to check
; @return Boolean indicating if window should be managed
ShouldManageWindow(hwnd) {
    if (!hwnd)
        return false
    
    try {
        style := WinGetStyle(hwnd)
        exStyle := WinGetExStyle(hwnd)
        
        ; Must have a title bar (WS_CAPTION)
        if (!(style & TitleBarMask))
            return false
        
        ; Exclude popup windows
        if (style & WS_POPUP)
            return false
        
        ; Exclude tool windows
        if (exStyle & WS_EX_TOOLWINDOW)
            return false
        
        ; Check if it's a child window (has a parent)
        parent := DllCall("GetParent", "Ptr", hwnd, "Ptr")
        if (parent != 0)
            return false
        
        ; Exclude dialog boxes
        if (exStyle & WS_EX_DLGMODALFRAME)
            return false
        
        ; Exclude specific Windows UI elements by class name
        className := WinGetClass(hwnd)
        excludedClasses := [
            "NotifyIconOverflowWindow",  ; System tray overflow window
            "TopLevelWindowForOverflowXamlIsland",  ; Windows 11 tray overflow
            "Shell_TrayWnd",             ; Taskbar itself
            "Windows.UI.Core.CoreWindow" ; Various Windows UI popups
        ]
        for excludedClass in excludedClasses {
            if (className == excludedClass)
                return false
        }
        
        return true
    } catch as err {
        ; Log error for debugging (optional)
        ; OutputDebug("ShouldManageWindow error: " err.Message)
        return false
    }
}

; Reflow window positions in the stack
; Repositions all windows based on current layout mode and active window
ReflowStack() {
    ; Prevent interruptions during reflow
    Critical
    if (WindowStack.Length == 0) {
        UpdateDock()
        return
    }
    activeHwnd := WinActive("A"), activeIndex := 0

    ; Cleanup closed windows (iterate backwards to safely remove items)
    loop WindowStack.Length {
        idx := WindowStack.Length - A_Index + 1
        if (idx >= 1 && idx <= WindowStack.Length) {
            try {
                if (!WinExist(WindowStack[idx]))
                    WindowStack.RemoveAt(idx)
                else if (WindowStack[idx] == activeHwnd)
                    activeIndex := idx
            }
            catch
                ; Error checking window, remove it
                WindowStack.RemoveAt(idx)
        }
    }

    ; After cleanup, check if we still have windows
    if (WindowStack.Length == 0) {
        UpdateDock()
        return
    }

    ; If active window was closed, activate the first window in stack
    if (activeIndex == 0) {
        try {
            WinActivate(WindowStack[1])
            activeIndex := 1
        } catch {
            UpdateDock()
            return
        }
    }

    if (OverlayMode) {
        ; Small gap on top
        overlayTop := Gap
        ; Bottom gap depends on taskbar visibility
        bottomGap := TaskbarHidden ? Gap : (Gap + TaskbarHeight)
        ; Maximize height with small gaps
        overlayHeight := A_ScreenHeight - overlayTop - bottomGap
        for hwnd in WindowStack {
            try {
                WinRestore(hwnd)
                WinMove(0, overlayTop, A_ScreenWidth, overlayHeight, hwnd)
            }
            catch
                ; Skip windows that can't be moved
                continue
        }
    } else {
        ; Calculate current available height based on taskbar visibility
        currentHeight := GetAvailableHeight()
        for i, hwnd in WindowStack {
            ; Calculate circular distance for infinite scrolling
            rawOffset := i - activeIndex
            ; Wrap around: choose shortest path in circular arrangement
            if (rawOffset > WindowStack.Length / 2)
                rawOffset -= WindowStack.Length
            else if (rawOffset < -WindowStack.Length / 2)
                rawOffset += WindowStack.Length
            relativeOffset := rawOffset * (TargetWidth + Gap)
            try WinMove(CenterX + relativeOffset, V_Top, TargetWidth, currentHeight, hwnd)
            catch
                ; Skip windows that can't be moved
                continue
        }
    }

    UpdateDock()
}

; ==============================================================================
; NAVIGATION LOGIC
; ==============================================================================

; Switch to a specific virtual desktop
; @param Target - Desktop number to switch to (1-10)
GoToDesktop(Target) {
    global CurrentDesktop, InitializedDesktops
    
    if (Target < 1 || Target > 10) {
        FlashMessage("INVALID DESKTOP")
        return
    }
    
    Diff := Target - CurrentDesktop
    if (Diff = 0)
        return
    
    Key := (Diff > 0) ? "{Right}" : "{Left}"
    loop Abs(Diff) {
        Send("^#" . Key)
        Sleep 50
    }
    global CurrentDesktop := Target
    FlashMessage("DESKTOP " . Target)

    ; Auto-arrange windows on new desktop if not initialized
    if (!InitializedDesktops.Has(Target)) {
        ; Delay to let desktop switch complete before arranging
        SetTimer(() => InitializeDesktop(Target), -DesktopSwitchDelay)
    }
}

; Initialize windows on a desktop that hasn't been arranged yet
; @param DesktopNum - Desktop number to initialize
InitializeDesktop(DesktopNum) {
    global InitializedDesktops
    if (InitializedDesktops.Has(DesktopNum))
        return

    InitializeExistingWindows()
    InitializedDesktops[DesktopNum] := true
    FlashMessage("DESKTOP " . DesktopNum . " ARRANGED")
}

; Move active window to another desktop
; @param direction - Direction to move (-1=left, 1=right)
MoveWindowToDesktop(direction) {
    if (direction != -1 && direction != 1) {
        return
    }
    
    Send("#{Tab}")
    Sleep 450
    Send("+{F10}")
    Sleep 150
    Send("m")
    Sleep 150
    Send(direction = 1 ? "{Right}{Enter}" : "{Left}{Enter}")
    Sleep 150
    Send("{Esc}")
}

; Cycle through window stack
; @param direction - Direction to cycle (1=next, -1=previous)
CycleStack(direction) {
    if (WindowStack.Length <= 1)
        return

    activeHwnd := WinActive("A"), activeIndex := 0
    for i, hwnd in WindowStack
        if (hwnd == activeHwnd)
            activeIndex := i

    if (activeIndex == 0)
        return

    newIndex := activeIndex + direction
    if (newIndex < 1)
        newIndex := WindowStack.Length
    else if (newIndex > WindowStack.Length)
        newIndex := 1

    try WinActivate(WindowStack[newIndex])
    catch
        ; Failed to activate window
        return
    
    ; ReflowStack will be triggered automatically via ShellMessage hook
    ; Update dock after window activation
    SetTimer(() => UpdateDock(), -DockUpdateDelay)
}

; Add all existing windows to the stack on startup or desktop switch
InitializeExistingWindows() {
    windowList := WinGetList()
    for hwnd in windowList {
        try {
            ; Use the same filtering logic as ManageNewWindow
            if (!ShouldManageWindow(hwnd))
                continue
            
            title := WinGetTitle(hwnd)
            if (title != "" && !InStr(title, "Program Manager")) {
                alreadyExists := false
                for item in WindowStack
                    if (item == hwnd)
                        alreadyExists := true
                if (!alreadyExists)
                    WindowStack.Push(hwnd)
            }
        }
        catch
            ; Skip windows that cause errors
            continue
    }
    ReflowStack()
}

; Helper function for f and t commands (find/till character)
; @param isTill - If true, stop before character; if false, stop on character
ExecuteFind(isTill) {
    ih := InputHook("L1 T2")
    ih.Start(), ih.Wait()
    target := ih.Input
    if (target == "")
        return

    oldClip := ClipboardAll()
    A_Clipboard := ""
    Send "{Home}+{End}^c"
    if (ClipWait(0.5)) {
        lineText := A_Clipboard
        pos := InStr(lineText, target)
        if (pos > 0) {
            Send "{Home}"
            loop (isTill ? pos - 2 : pos - 1)
                Send "{Right}"
        }
    }
    A_Clipboard := oldClip
}

; Toggle Windows taskbar visibility
ToggleTaskbar() {
    global TaskbarHidden
    target := "ahk_class Shell_TrayWnd"

    if (!TaskbarHidden) {
        try WinHide(target)
        catch
            ; Taskbar hide failed
            return
        
        ; Also hide the Start Button (sometimes required on Win 10/11)
        try {
            if (WinExist("ahk_class Button"))
                WinHide("ahk_class Button")
        }
        catch
            ; Start button hide failed
        
        TaskbarHidden := true
        ToolTip("Taskbar: HIDDEN")
    } else {
        try WinShow(target)
        catch
            ; Taskbar show failed
            return
        
        try {
            if (WinExist("ahk_class Button"))
                WinShow("ahk_class Button")
        }
        catch
            ; Start button show failed
        
        TaskbarHidden := false
        ToolTip("Taskbar: VISIBLE")
    }
    SetTimer(() => ToolTip(), -TooltipDuration)
    
    ; Recalculate all window heights after toggling taskbar
    ReflowStack()
}

; ==============================================================================
; VIM MODE (HOTKEYS & LOCKDOWN)
; ==============================================================================

; Initialize existing windows on startup
try {
    InitializeExistingWindows()
    ; Mark current desktop as initialized
    InitializedDesktops[CurrentDesktop] := true
}
catch as err {
    MsgBox("Failed to initialize windows on startup: " err.Message, "Warning", "Icon!")
}

; Toggle Vim mode with CapsLock
CapsLock:: {
    UpdateHUD(Mode == 0 ? 1 : 0)
}

#HotIf Mode > 0
; --- Virtual Desktops ---
^j:: {
    Send("^#+{Left}")
    global CurrentDesktop -= 1
    if (CurrentDesktop < 1)
        global CurrentDesktop := 1
    global InitializedDesktops
    if (!InitializedDesktops.Has(CurrentDesktop)) {
        SetTimer(() => InitializeDesktop(CurrentDesktop), -DesktopSwitchDelay)
    }
}
^k:: {
    Send("^#+{Right}")
    global CurrentDesktop += 1
    if (CurrentDesktop > 10)
        global CurrentDesktop := 10
    global InitializedDesktops
    if (!InitializedDesktops.Has(CurrentDesktop)) {
        SetTimer(() => InitializeDesktop(CurrentDesktop), -DesktopSwitchDelay)
    }
}
^1:: GoToDesktop(1)
^2:: GoToDesktop(2)
^3:: GoToDesktop(3)
^4:: GoToDesktop(4)
^5:: GoToDesktop(5)
^+j:: MoveWindowToDesktop(-1)
^+k:: MoveWindowToDesktop(1)

; --- Layout Control ---
^f:: {
    global OverlayMode := !OverlayMode
    FlashMessage(OverlayMode ? "OVERLAY MODE" : "TILING MODE")
    ReflowStack()
}
^+d:: {
    if (WindowStack.Length == 0)
        return
    
    activeHwnd := WinActive("A")
    if (!activeHwnd)
        return
    
    for i, hwnd in WindowStack {
        if (hwnd == activeHwnd) {
            WindowStack.RemoveAt(i)
            FlashMessage("WINDOW REMOVED")
            break
        }
    }
    ReflowStack()
}
; Ctrl + T to toggle Taskbar visibility
^t:: ToggleTaskbar()

; --- Reordering ---
^h:: {
    if (WindowStack.Length <= 1)
        return
    
    activeHwnd := WinActive("A")
    if (!activeHwnd)
        return
    
    idx := 0
    for i, hwnd in WindowStack {
        if (hwnd == activeHwnd) {
            idx := i
            break
        }
    }
    
    if (idx > 1) {
        temp := WindowStack[idx - 1]
        WindowStack[idx - 1] := WindowStack[idx]
        WindowStack[idx] := temp
        ReflowStack()
        try WinActivate(activeHwnd)
        catch
            ; Failed to reactivate
    }
}
^l:: {
    if (WindowStack.Length <= 1)
        return
    
    activeHwnd := WinActive("A")
    if (!activeHwnd)
        return
    
    idx := 0
    for i, hwnd in WindowStack {
        if (hwnd == activeHwnd) {
            idx := i
            break
        }
    }
    
    if (idx > 0 && idx < WindowStack.Length) {
        temp := WindowStack[idx + 1]
        WindowStack[idx + 1] := WindowStack[idx]
        WindowStack[idx] := temp
        ReflowStack()
        try WinActivate(activeHwnd)
        catch
            ; Failed to reactivate
    }
}

; --- Navigation ---
n:: CycleStack(1)
p:: CycleStack(-1)
z:: ReflowStack()

; --- Vim Text Navigation ---
h:: Send(Mode == 2 ? "+{Left}" : "{Left}")
j:: Send(Mode == 2 ? "+{Down}" : "{Down}")
k:: Send(Mode == 2 ? "+{Up}" : "{Up}")
l:: Send(Mode == 2 ? "+{Right}" : "{Right}")
w:: Send(Mode == 2 ? "^+{Right}" : "^{Right}")
b:: Send(Mode == 2 ? "^+{Left}" : "^{Left}")
e:: Send(Mode == 2 ? "^+{Right}" : "^{Right}")
0:: Send(Mode == 2 ? "+{Home}" : "{Home}")
+4:: Send(Mode == 2 ? "+{End}" : "{End}") ; '$' key
^d:: Send(Mode == 2 ? "+{PgDn}" : "{PgDn}") ; Page down
^u:: Send(Mode == 2 ? "+{PgUp}" : "{PgUp}") ; Page up

; --- Search & Find ---
f:: ExecuteFind(false)
t:: ExecuteFind(true)
/:: {
    Send "^f"
    UpdateHUD(0)
}

; --- Mode Switching ---
v:: UpdateHUD(Mode == 1 ? 2 : 1)

; --- Exit ---
i:: UpdateHUD(0)
Esc:: UpdateHUD(0)

; --- Normal Mode Commands ---
#HotIf Mode == 1
; Document Navigation
g:: {
    if (A_PriorHotkey == "g" and A_TimeSincePriorHotkey < DblClickTimeout)
        Send "^{Home}" ; 'gg'
}
+g:: Send "^{End}" ; 'G'

; Delete Commands
d:: {
    if (A_PriorHotkey == "d" and A_TimeSincePriorHotkey < DblClickTimeout)
        Send "{Home}+{End}{BackSpace}{Delete}" ; 'dd'
}

; Change Commands
c:: {
    if (A_PriorHotkey == "c" and A_TimeSincePriorHotkey < DblClickTimeout) {
        Send "{Home}+{End}{BackSpace}" ; 'cc'
        UpdateHUD(0)
    } else {
        Send "^{Delete}" ; 'cw'
        UpdateHUD(0)
    }
}

; Yank Commands
y:: {
    if (A_PriorHotkey == "y" and A_TimeSincePriorHotkey < DblClickTimeout) {
        Send "{Home}+{End}^c" ; 'yy'
        FlashMessage("COPIED LINE")
    } else {
        Send "^c"
    }
}

; Editing Commands
p:: Send "^v"
u:: Send "^z"
^r:: Send "^y" ; Redo
x:: Send "{Delete}"
o:: Send("{End}{Enter}"), UpdateHUD(0)
+o:: Send("{Home}{Enter}{Up}"), UpdateHUD(0)
a:: Send("{Right}"), UpdateHUD(0)
+a:: Send("{End}"), UpdateHUD(0)

; Command Line
SC027:: { ; ':' key
    Result := InputBox("Command: w (save), q (quit), wq (save & quit)", "Vim Command", "h80 w300")
    if (Result.Result = "OK") {
        val := StrLower(Result.Value)
        if (val = "w")
            Send "^s"
        if (val = "q")
            Send "!{F4}"
        if (val = "wq") {
            Send "^s"
            Sleep 100
            Send "!{F4}"
        }
    }
}
#HotIf

; --- Visual Mode Commands ---
#HotIf Mode == 2
d:: Send("{BackSpace}"), UpdateHUD(1)
c:: Send("{BackSpace}"), UpdateHUD(0)
y:: Send("^c"), UpdateHUD(1), FlashMessage("YANKED")
x:: Send("{Delete}"), UpdateHUD(1)
#HotIf

#HotIf