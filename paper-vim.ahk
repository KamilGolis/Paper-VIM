#Requires AutoHotkey v2.0
#SingleInstance Force
; Remove delay between window operations for speed
SetWinDelay -1

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
global TitleBarMask := 0x00C00000     ; Window style mask for title bar detection

; HUD Setup
VimGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
VimGui.BackColor := HUDBackgroundColor
VimGui.SetFont("s16 w800", "Segoe UI")
VimText := VimGui.Add("Text", "Center w" HUDWidth, "VIM: NORMAL")
WinSetTransColor(HUDBackgroundColor, VimGui)

; Dock HUD Setup
DockGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
DockGui.BackColor := DockBackgroundColor
WinSetTransColor(DockBackgroundColor, DockGui)
DockGui.MarginX := DockMarginX
DockGui.MarginY := DockMarginY

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

FlashMessage(Msg, Duration := FlashDuration) {
    if (Mode > 0) {
        VimText.Opt(FlashMsgColor)
        VimText.Value := Msg
        SetTimer(() => UpdateHUD(Mode), -Duration)
    }
}

UpdateDock() {
    global WindowStack, DockGui

    ; Destroy entire GUI and recreate to avoid duplicates
    try DockGui.Destroy()
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

    ; Helper function to wrap index
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
    }

    ; Add center icon (active window) - with underline
    try {
        iconPath := GetWindowIconPath(WindowStack[activeIndex])
        pic := DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
        ; Add underline below active icon
        DockGui.Add("Text", "x" xPos " y" (DockIconSize + 2) " w" DockIconSize " h2 Background" ActiveIndicatorColor)
        xPos += DockIconSize + DockIconSpacing
    }

    ; Add right icons (next windows)
    loop DockRightCount {
        idx := WrapIndex(activeIndex + A_Index)
        try {
            iconPath := GetWindowIconPath(WindowStack[idx])
            pic := DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
            xPos += DockIconSize + DockIconSpacing
        }
    }

    ; Calculate total width and position dock at screen center
    totalIcons := DockLeftCount + 1 + DockRightCount
    totalWidth := (totalIcons * DockIconSize) + ((totalIcons - 1) * DockIconSpacing) + 24
    dockX := (A_ScreenWidth - totalWidth) / 2
    DockGui.Show("x" dockX " y" DockPosY " w" totalWidth " h" (DockIconSize + 16) " NoActivate")
}

GetWindowIconPath(hwnd) {
    ; Try to get the window's icon
    ; First, try to get large icon
    hIcon := SendMessage(0x007F, 0, 0, , hwnd) ; WM_GETICON, ICON_BIG

    if (!hIcon) {
        ; Try small icon
        hIcon := SendMessage(0x007F, 2, 0, , hwnd) ; WM_GETICON, ICON_SMALL2
    }

    if (!hIcon) {
        ; Get icon from window class
        hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -14, "Ptr") ; GCL_HICON
    }

    if (!hIcon) {
        ; Get icon from executable
        try {
            exePath := WinGetProcessPath(hwnd)
            return exePath
        }
    }

    if (hIcon) {
        ; Save icon to temp file and return path
        try {
            return "HICON:" hIcon
        }
    }

    ; Return default icon path if all else fails
    return "*icon1 shell32.dll"  ; Default Windows icon
}

; Calculate available window height based on taskbar visibility
GetAvailableHeight() {
    global BarHeight, Gap, TaskbarHeight, TaskbarHidden
    baseHeight := A_ScreenHeight - BarHeight - (3 * Gap)
    ; If taskbar is hidden, add its height to available space
    return TaskbarHidden ? baseHeight + TaskbarHeight : baseHeight
}

; ==============================================================================
; SHELL HOOK (AUTOMATION)
; ==============================================================================

DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
OnMessage(DllCall("RegisterWindowMessage", "Str", "SHELLHOOK"), ShellMessage)

ShellMessage(wParam, lParam, *) {
    if (wParam = 1)
    ; Window Created
        ManageNewWindow(lParam)
    if (wParam = 2)
    ; Window Destroyed
        DeferredReflow()
    if (wParam = 4 || wParam = 32772)
    ; Window Activated
        DeferredReflow()
}

DeferredReflow() {
    global ReflowTimer
    if (ReflowTimer)
        SetTimer(ReflowTimer, 0)
    ReflowTimer := () => ReflowStack()
    ; Debounce: wait before reflowing
    SetTimer(ReflowTimer, -DebounceDelay)
}

ManageNewWindow(hwnd) {
    if !WinExist(hwnd)
        return
    
    ; Check if window should be managed
    if !ShouldManageWindow(hwnd)
        return
    
    for item in WindowStack
        if (item == hwnd)
            return
    WindowStack.Push(hwnd)
    ReflowStack()
}

; Determines if a window should be managed by the tiling system
ShouldManageWindow(hwnd) {
    try {
        style := WinGetStyle(hwnd)
        exStyle := WinGetExStyle(hwnd)
        
        ; Must have a title bar (WS_CAPTION)
        if !(style & TitleBarMask)
            return false
        
        ; Exclude popup windows (WS_POPUP = 0x80000000)
        if (style & 0x80000000)
            return false
        
        ; Exclude tool windows (WS_EX_TOOLWINDOW = 0x80)
        if (exStyle & 0x80)
            return false
        
        ; Check if it's a child window (has a parent)
        parent := DllCall("GetParent", "Ptr", hwnd, "Ptr")
        if (parent != 0)
            return false
        
        ; Exclude dialog boxes (WS_EX_DLGMODALFRAME = 0x1)
        if (exStyle & 0x1)
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
    } catch {
        return false
    }
}

ReflowStack() {
    ; Prevent interruptions during reflow
    Critical
    if (WindowStack.Length == 0) {
        UpdateDock()
        return
    }
    activeHwnd := WinActive("A"), activeIndex := 0

    ; Cleanup closed windows
    loop WindowStack.Length {
        idx := WindowStack.Length - A_Index + 1
        if (idx >= 1 && idx <= WindowStack.Length) {
            try {
                if !WinExist(WindowStack[idx])
                    WindowStack.RemoveAt(idx)
                else if (WindowStack[idx] == activeHwnd)
                    activeIndex := idx
            }
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
        }
    }

    UpdateDock()
}

; ==============================================================================
; NAVIGATION LOGIC
; ==============================================================================

GoToDesktop(Target) {
    global CurrentDesktop, InitializedDesktops
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

InitializeDesktop(DesktopNum) {
    global InitializedDesktops
    if (InitializedDesktops.Has(DesktopNum))
        return

    InitializeExistingWindows()
    InitializedDesktops[DesktopNum] := true
    FlashMessage("DESKTOP " . DesktopNum . " ARRANGED")
}

MoveWindowToDesktop(direction) {
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
    ; ReflowStack will be triggered automatically via ShellMessage hook
    ; Update dock after window activation
    SetTimer(() => UpdateDock(), -DockUpdateDelay)
}

InitializeExistingWindows() {
    windowList := WinGetList()
    for hwnd in windowList {
        try {
            ; Use the same filtering logic as ManageNewWindow
            if !ShouldManageWindow(hwnd)
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
    }
    ReflowStack()
}

; Helper function for f and t commands
ExecuteFind(isTill) {
    ih := InputHook("L1 T2")
    ih.Start(), ih.Wait()
    target := ih.Input
    if (target == "")
        return

    oldClip := ClipboardAll()
    A_Clipboard := ""
    Send "{Home}+{End}^c"
    if ClipWait(0.5) {
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

ToggleTaskbar() {
    global TaskbarHidden
    target := "ahk_class Shell_TrayWnd"

    if !TaskbarHidden {
        WinHide(target)
        ; Also hide the Start Button (sometimes required on Win 10/11)
        if WinExist("ahk_class Button")
            WinHide("ahk_class Button")
        TaskbarHidden := true
        ToolTip("Taskbar: HIDDEN")
    } else {
        WinShow(target)
        if WinExist("ahk_class Button")
            WinShow("ahk_class Button")
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
InitializeExistingWindows()
; Mark current desktop as initialized
InitializedDesktops[CurrentDesktop] := true

CapsLock:: UpdateHUD(Mode == 0 ? 1 : 0)

#HotIf Mode > 0
; --- Virtual Desktops ---
^j:: {
    Send("^#+{Left}")
    global CurrentDesktop -= 1
    global InitializedDesktops
    if (!InitializedDesktops.Has(CurrentDesktop)) {
        SetTimer(() => InitializeDesktop(CurrentDesktop), -DesktopSwitchDelay)
    }
}
^k:: {
    Send("^#+{Right}")
    global CurrentDesktop += 1
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
    ReflowStack()
}
^+d:: {
    activeHwnd := WinActive("A")
    for i, hwnd in WindowStack
        if (hwnd == activeHwnd) {
            WindowStack.RemoveAt(i)
            break
        }
    ReflowStack()
}
; Ctrl + T to toggle Taskbar visibility
^t:: ToggleTaskbar()

; --- Reordering ---
^h:: {
    activeHwnd := WinActive("A"), idx := 0
    for i, hwnd in WindowStack
        if (hwnd == activeHwnd) {
            idx := i
            break
        }
    if (idx > 1) {
        temp := WindowStack[idx - 1]
        WindowStack[idx - 1] := WindowStack[idx]
        WindowStack[idx] := temp
        ReflowStack()
        try WinActivate(activeHwnd)
    }
}
^l:: {
    activeHwnd := WinActive("A"), idx := 0
    for i, hwnd in WindowStack
        if (hwnd == activeHwnd) {
            idx := i
            break
        }
    if (idx > 0 && idx < WindowStack.Length) {
        temp := WindowStack[idx + 1]
        WindowStack[idx + 1] := WindowStack[idx]
        WindowStack[idx] := temp
        ReflowStack()
        try WinActivate(activeHwnd)
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