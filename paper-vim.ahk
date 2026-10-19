; ==============================================================================
; Paper-VIM: Vim Keybindings + PaperWM Window Manager
; Version: 1.2.0
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
global FullWidthRatio := 1.0          ; "Full" preset; selects the focus/peek layout
global FocusWidthRatio := 0.85        ; Focus-mode window width (fraction of the viewport)
; Focus mode uses the same Gap as the 25/50/75 tiling presets. The remaining
; space becomes the visible slices of the previous and next windows.
global WindowWidths := Map()          ; Per-window width ratio (hwnd -> 0.25..1.0)
global ViewOffset := 0                ; Horizontal scroll offset of the window row (px)
global Gap := 8                       ; Gap between windows and screen edges
global BarHeight := 60                ; Space reserved at the top for the HUD and dock
global TaskbarMode := "auto"          ; auto, left, top, right, bottom, or none
global TaskbarSize := 0               ; Fixed taskbar size in px (0 = 48); used with a fixed mode
global OverlayMode := false           ; Toggle between tiling and overlay (fullscreen) mode
global TaskbarHidden := false         ; Track Windows taskbar visibility state

; --- Work Area (screen minus the taskbar) ---
global TaskbarLeft := 0               ; Taskbar inset on each screen edge
global TaskbarTop := 0
global TaskbarRight := 0
global TaskbarBottom := 0
global WorkLeft := 0                  ; Usable area origin and size
global WorkTop := 0
global WorkWidth := A_ScreenWidth
global WorkHeight := A_ScreenHeight

; --- Vim Mode State ---
global VimMode := 0                   ; 0=Off, 1=Normal, 2=Visual, 3=Insert
global Suspended := false             ; Script suspension state (pauses all actions)
global SuspendedState := Map()        ; Stores window state before suspension

; --- Desktop Management ---
global CurrentDesktop := 1            ; Currently active virtual desktop number
global InitializedDesktops := Map()  ; Track which desktops have been auto-arranged
global ReflowTimer := 0               ; Debounce timer for window reflow operations

; --- Visual Customization ---
global HUDBackgroundColor := "121212"     ; VIM HUD background (dark gray)
global DockBackgroundColor := "1a1a1a"    ; Dock background (darker gray)
global NormalModeColor := "c00FF00"       ; Normal mode text color (green)
global VisualModeColor := "cFF0000"       ; Visual mode text color (red)
global InsertModeColor := "c00BFFF"       ; Insert mode text color (blue)
global FlashMsgColor := "cFFFF00"         ; Flash message color (yellow)
global SuspendedModeColor := "cFF8800"    ; Suspended mode text color (orange)
global ActiveIndicatorColor := "00FF00"   ; Dock active window underline (green)
global DockInactiveNumberColor := "c888888" ; Dock inactive window number color (gray)

; --- Font Configuration ---
global FontFamily := "Segoe UI"          ; Font family used throughout UI
global HUDFontSize := "s16"              ; HUD text size
global HUDFontWeight := "w800"           ; HUD text weight (bold)
global DockNumberFontSize := "s8"        ; Dock window number text size

; --- Dock Configuration ---
global DockIconSize := 32             ; Size of dock icons in pixels
global DockIconSpacing := 8           ; Spacing between dock icons
global DockLeftCount := 2             ; Number of icons shown left of active
global DockRightCount := 2            ; Number of icons shown right of active
global DockMarginX := 12              ; Dock horizontal margin
global DockMarginY := 8               ; Dock vertical margin
global DockPosY := 10                 ; Dock Y position from top

; --- HUD Configuration ---
global HUDMarginRight := 20           ; HUD distance from the right edge of the work area
global HUDPosY := 40                  ; HUD Y position from the top of the work area
global HUDWidth := 220                ; HUD text control width; the window auto-sizes to the text
global FlashDuration := 800           ; Flash message duration in milliseconds
global FlashTimer := 0                ; Timer handle of the current flash restore

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
global HSHELL_FLASH := 32772          ; Window flash event (HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT)

; ==============================================================================
; GUI INITIALIZATION
; ==============================================================================

; HUD Setup - Mode indicator
VimGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
VimGui.BackColor := HUDBackgroundColor
VimGui.SetFont(HUDFontSize " " HUDFontWeight, FontFamily)
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

; Show the HUD at the top-right of the work area. The HUD auto-sizes to its
; text, so measure the real window width instead of using a fixed width.
ShowHUDAtTopRight() {
    global VimGui, WorkLeft, WorkWidth, WorkTop, HUDPosY, HUDMarginRight

    VimGui.Show("Hide")
    WinGetPos(&hx, &hy, &hudWidth, &hudHeight, VimGui.Hwnd)
    hudX := WorkLeft + WorkWidth - hudWidth - HUDMarginRight
    hudY := WorkTop + HUDPosY
    VimGui.Show("x" hudX " y" hudY " NoActivate")
}

; Update HUD display based on current Vim mode
; @param NewState - Vim mode value: 0=Off, 1=Normal, 2=Visual, 3=Insert
UpdateHUD(NewState) {
    global VimMode := NewState

    ; Keep the HUD inside the usable area when the taskbar moves
    RefreshWorkArea()

    ; If suspended, always show suspended state
    if (Suspended) {
        VimText.Opt(SuspendedModeColor)
        VimText.Value := "SUSPENDED"
        ShowHUDAtTopRight()
        return
    }
    
    if (VimMode == 0) {
        VimGui.Hide()
    } else if (VimMode == 1) {
        VimText.Opt(NormalModeColor)
        VimText.Value := "VIM: NORMAL"
        ShowHUDAtTopRight()
    } else if (VimMode == 2) {
        VimText.Opt(VisualModeColor)
        VimText.Value := "VIM: VISUAL"
        ShowHUDAtTopRight()
    } else if (VimMode == 3) {
        VimText.Opt(InsertModeColor)
        VimText.Value := "VIM: INSERT"
        ShowHUDAtTopRight()
    }
}

; Display temporary message in HUD
; @param Msg - Message to display
; @param Duration - How long to show message (default: FlashDuration)
FlashMessage(Msg, Duration := FlashDuration) {
    global FlashTimer
    if (VimMode > 0 && !Suspended) {
        VimText.Opt(FlashMsgColor)
        VimText.Value := Msg
        ; Cancel any pending restore so messages don't cut each other short
        if (FlashTimer)
            SetTimer(FlashTimer, 0)
        FlashTimer := () => UpdateHUD(VimMode)
        SetTimer(FlashTimer, -Duration)
    }
}

; Toggle script suspension state
; When suspended, all window management actions are paused
; Resume by pressing Ctrl+Q again or CapsLock to enter Vim mode
ToggleSuspend() {
    global Suspended, SuspendedState, OverlayMode, WindowStack
    
    if (!Suspended) {
        ; === SUSPENDING ===
        ; Save current state
        SuspendedState := Map()
        SuspendedState["OverlayMode"] := OverlayMode
        SuspendedState["WindowPositions"] := []
        
        ; Save current window positions
        for hwnd in WindowStack {
            try {
                WinGetPos(&x, &y, &w, &h, hwnd)
                SuspendedState["WindowPositions"].Push(Map(
                    "hwnd", hwnd,
                    "x", x,
                    "y", y,
                    "width", w,
                    "height", h
                ))
            }
            catch as err {
                ; Skip windows that can't be queried
                continue
            }
        }
        
        ; Apply overlay mode (fullscreen windows)
        if (!OverlayMode) {
            OverlayMode := true
            ReflowStack()  ; Apply overlay positioning
        }
        
        ; Now suspend
        Suspended := true
        
        ; Show suspended notification
        UpdateHUD(VimMode)
        
        ; Hide dock when suspended
        try DockGui.Hide()
        catch as err {
            ; Ignore if dock doesn't exist
        }
    } else {
        ; === RESUMING ===
        Suspended := false
        
        ; Restore previous overlay mode state
        if (SuspendedState.Has("OverlayMode")) {
            OverlayMode := SuspendedState["OverlayMode"]
        }
        
        ; Restore window positions if we have them
        if (SuspendedState.Has("WindowPositions")) {
            for winData in SuspendedState["WindowPositions"] {
                try {
                    WinMove(winData["x"], winData["y"], winData["width"], winData["height"], winData["hwnd"])
                }
                catch as err {
                    ; Skip windows that can't be moved
                    continue
                }
            }
        }
        
        ; Clear saved state
        SuspendedState := Map()
        
        ; Resume normal operation
        UpdateHUD(VimMode)
        UpdateDock()
    }
}

; Update dock display with current window stack
; Shows icons for windows around the active window with visual indicator
UpdateDock() {
    global WindowStack, DockGui

    ; Keep the dock centered inside the usable area when the taskbar moves
    RefreshWorkArea()

    ; No managed windows: hide the dock
    if (WindowStack.Length == 0) {
        try DockGui.Hide()
        catch as err {
            ; Ignore hide errors
        }
        return
    }

    ; Get active window
    activeIndex := GetStackIndex(WinActive("A"))

    ; Active window is not managed: keep the dock as it is instead of
    ; rebuilding a GUI that would never be shown
    if (activeIndex == 0) {
        return
    }

    ; Destroy entire GUI and recreate to avoid duplicates
    try DockGui.Destroy()
    catch as err {
        ; Ignore destroy errors
    }
    
    DockGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
    DockGui.BackColor := DockBackgroundColor
    WinSetTransColor(DockBackgroundColor, DockGui)
    DockGui.MarginX := DockMarginX
    DockGui.MarginY := DockMarginY

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
    numberYPos := DockIconSize + 4  ; Position for number labels below icons

    ; Add left icons (previous windows, in correct order)
    leftIndices := []
    loop DockLeftCount {
        idx := WrapIndex(activeIndex - DockLeftCount + A_Index - 1)
        leftIndices.Push(idx)
    }

    for idx in leftIndices {
        try {
            iconPath := GetWindowIconPath(WindowStack[idx])
            DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
            ; Add number label below icon
            DockGui.SetFont(DockNumberFontSize " " DockInactiveNumberColor, FontFamily)
            DockGui.Add("Text", "x" xPos " y" numberYPos " w" DockIconSize " Center", idx)
            xPos += DockIconSize + DockIconSpacing
        }
        catch as err
            ; Skip windows that fail to get icon
            continue
    }

    ; Add center icon (active window) - with underline and number
    try {
        iconPath := GetWindowIconPath(WindowStack[activeIndex])
        DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
        ; Add underline below active icon
        DockGui.Add("Text", "x" xPos " y" (DockIconSize + 2) " w" DockIconSize " h2 Background" ActiveIndicatorColor)
        ; Add number label below underline with active color
        DockGui.SetFont(DockNumberFontSize " c" ActiveIndicatorColor, FontFamily)
        DockGui.Add("Text", "x" xPos " y" numberYPos " w" DockIconSize " Center", activeIndex)
        xPos += DockIconSize + DockIconSpacing
    }
    catch as err
        ; Failed to add active window icon
        return

    ; Add right icons (next windows)
    loop DockRightCount {
        idx := WrapIndex(activeIndex + A_Index)
        try {
            iconPath := GetWindowIconPath(WindowStack[idx])
            DockGui.Add("Picture", "x" xPos " y0 w" DockIconSize " h" DockIconSize, iconPath)
            ; Add number label below icon
            DockGui.SetFont(DockNumberFontSize " " DockInactiveNumberColor, FontFamily)
            DockGui.Add("Text", "x" xPos " y" numberYPos " w" DockIconSize " Center", idx)
            xPos += DockIconSize + DockIconSpacing
        }
        catch as err
            ; Skip windows that fail to get icon
            continue
    }

    ; Show hidden first so AutoSize gives the real width, then center the dock
    DockGui.Show("Hide")
    WinGetPos(&dx, &dy, &dockWidth, &dockHeight, DockGui.Hwnd)
    dockX := WorkLeft + (WorkWidth - dockWidth) / 2
    dockY := WorkTop + DockPosY
    DockGui.Show("x" dockX " y" dockY " NoActivate")
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
    catch as err {
        hIcon := 0
    }

    if (!hIcon) {
        ; Try small icon
        try hIcon := SendMessage(WM_GETICON, ICON_SMALL2, 0, , hwnd)
        catch as err {
            hIcon := 0
        }
    }

    if (!hIcon) {
        ; Get icon from window class
        try hIcon := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", GCL_HICON, "Ptr")
        catch as err {
            hIcon := 0
        }
    }

    if (!hIcon) {
        ; Get icon from executable
        try {
            exePath := WinGetProcessPath(hwnd)
            if (exePath != "")
                return exePath
        }
        catch as err {
            ; Continue to default icon
        }
    }

    if (hIcon) {
        ; Duplicate the icon before handing it to the GUI: the original
        ; belongs to the target window, and the dock destroys icons it owns
        ; when its controls are rebuilt
        try {
            hCopy := DllCall("CopyIcon", "Ptr", hIcon, "Ptr")
            if (hCopy)
                return "HICON:" hCopy
        }
        catch as err {
            ; Fall through to default icon
        }
    }

    ; Return default icon path if all else fails
    return "*icon1 shell32.dll"  ; Default Windows icon
}

; Recalculate the usable screen area from the taskbar position.
; The taskbar is detected with SHAppBarMessage(ABM_GETTASKBARPOS). TaskbarMode
; and TaskbarSize are manual overrides for unusual setups:
;   TaskbarMode: "auto" (default), "left", "top", "right", "bottom", "none"
;   TaskbarSize: pixels for a fixed mode (0 = 48)
RefreshWorkArea() {
    global TaskbarHidden, TaskbarMode, TaskbarSize
    global TaskbarLeft, TaskbarTop, TaskbarRight, TaskbarBottom
    global WorkLeft, WorkTop, WorkWidth, WorkHeight

    left := 0, top := 0, right := 0, bottom := 0
    mode := StrLower(TaskbarMode)

    if (!TaskbarHidden && mode != "none") {
        if (mode == "auto") {
            hwnd := WinExist("ahk_class Shell_TrayWnd")
            if (hwnd) {
                ptrSize := A_PtrSize
                abdSize := (ptrSize == 8) ? 48 : 36
                edgeOff := (ptrSize == 8) ? 20 : 12
                rcOff := (ptrSize == 8) ? 24 : 16

                ; An auto-hidden taskbar does not reserve any space
                abd := Buffer(abdSize, 0)
                NumPut("UInt", abdSize, abd, 0)
                state := DllCall("shell32\SHAppBarMessage", "UInt", 4, "Ptr", abd)
                autoHide := (state & 1)

                if (!autoHide) {
                    abd := Buffer(abdSize, 0)
                    NumPut("UInt", abdSize, abd, 0)
                    if (DllCall("shell32\SHAppBarMessage", "UInt", 5, "Ptr", abd)) {
                        edge := NumGet(abd, edgeOff, "UInt")
                        rLeft := NumGet(abd, rcOff, "Int")
                        rTop := NumGet(abd, rcOff + 4, "Int")
                        rRight := NumGet(abd, rcOff + 8, "Int")
                        rBottom := NumGet(abd, rcOff + 12, "Int")
                        if (edge == 0)          ; ABE_LEFT
                            left := Max(0, rRight)
                        else if (edge == 1)     ; ABE_TOP
                            top := Max(0, rBottom)
                        else if (edge == 2)     ; ABE_RIGHT
                            right := Max(0, A_ScreenWidth - rLeft)
                        else if (edge == 3)     ; ABE_BOTTOM
                            bottom := Max(0, A_ScreenHeight - rTop)
                    }

                    ; Fall back to the taskbar window rectangle if the shell
                    ; did not report a usable edge
                    if (left == 0 && top == 0 && right == 0 && bottom == 0) {
                        try {
                            WinGetPos(&tx, &ty, &tw, &th, hwnd)
                            if (tw > th) {
                                if (ty <= 0)
                                    top := th
                                else
                                    bottom := A_ScreenHeight - ty
                            } else {
                                if (tx <= 0)
                                    left := tw
                                else
                                    right := A_ScreenWidth - tx
                            }
                        }
                    }
                }
            }
        } else if (mode == "left" || mode == "top" || mode == "right" || mode == "bottom") {
            size := TaskbarSize > 0 ? TaskbarSize : 48
            if (mode == "left")
                left := size
            else if (mode == "top")
                top := size
            else if (mode == "right")
                right := size
            else
                bottom := size
        }
    }

    ; Keep the work area valid even if the reported taskbar is unusually large
    left := Max(0, Min(left, A_ScreenWidth - 1))
    right := Max(0, Min(right, A_ScreenWidth - left - 1))
    top := Max(0, Min(top, A_ScreenHeight - 1))
    bottom := Max(0, Min(bottom, A_ScreenHeight - top - 1))

    TaskbarLeft := left
    TaskbarTop := top
    TaskbarRight := right
    TaskbarBottom := bottom
    WorkLeft := left
    WorkTop := top
    WorkWidth := A_ScreenWidth - left - right
    WorkHeight := A_ScreenHeight - top - bottom
}

; Calculate available window height inside the work area
; @return Available height in pixels
GetAvailableHeight() {
    global BarHeight, Gap, WorkHeight
    return Max(1, WorkHeight - BarHeight - (2 * Gap))
}

; Top Y position for tiled windows (below the HUD/dock strip)
; @return Y position in pixels
GetWindowTop() {
    global BarHeight, Gap, WorkTop
    return WorkTop + BarHeight + Gap
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
    ; Ignore all window events when suspended
    if (Suspended)
        return
    
    if (wParam = HSHELL_WINDOWCREATED)
        ; Window Created
        ManageNewWindow(lParam)
    else if (wParam = HSHELL_WINDOWDESTROYED)
        ; Window Destroyed
        DeferredReflow()
    else if (wParam = HSHELL_WINDOWACTIVATED || wParam = HSHELL_FLASH) {
        ; Window activated or flashed (including taskbar clicks).
        ; The window is already focused at this point; re-activating it would
        ; fight the shell (Alt-Tab, Task View). Just reflow so the layout
        ; and dock follow the focused window.
        DeferredReflow()
    }
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
    global WindowWidths
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
    ; A newly created window starts at full width. Do not reset widths in
    ; InitializeExistingWindows: that path also runs on desktop switches and
    ; must preserve sizes the user has chosen.
    WindowWidths[hwnd] := FullWidthRatio
    DeferredReflow()
}

; Check if a window is cloaked by DWM (moved to another virtual desktop,
; hidden by a UWP host shell, etc.)
; @param hwnd - Window handle
; @return True if the window is cloaked
IsCloaked(hwnd) {
    ; DWMWA_CLOAKED = 14
    cloaked := 0
    try DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14, "UInt*", &cloaked, "UInt", 4)
    return cloaked != 0
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
        
        ; Exclude cloaked windows (windows on other virtual desktops, UWP
        ; host shells) so we never tile windows we cannot see
        if (IsCloaked(hwnd))
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
; @param centerActive - Center the active window instead of only scrolling
;                       enough to keep it on screen
ReflowStack(centerActive := false) {
    global WindowWidths, ViewOffset

    ; Don't reflow when suspended
    if (Suspended)
        return

    ; Taskbar position/size can change at any time (dock moved, auto-hide,
    ; Ctrl+T); recalculate the usable area before placing windows
    RefreshWorkArea()
    
    ; Prevent interruptions during reflow (thread-safe)
    Critical "On"
    
    if (WindowStack.Length == 0) {
        ViewOffset := 0
        WindowWidths.Clear()
        UpdateDock()
        Critical "Off"
        return
    }
    activeHwnd := WinActive("A")
    
    ; Cleanup closed windows (iterate backwards over a captured count, so
    ; removals don't shift the indices of elements still to be visited)
    activeRemoved := false
    n := WindowStack.Length
    loop n {
        idx := n - A_Index + 1
        try {
            if (!WinExist(WindowStack[idx])) {
                if (WindowStack[idx] == activeHwnd)
                    activeRemoved := true
                WindowWidths.Delete(WindowStack[idx])
                WindowStack.RemoveAt(idx)
            }
        }
        catch as err {
            ; Error checking window, remove it
            if (WindowStack[idx] == activeHwnd)
                activeRemoved := true
            WindowWidths.Delete(WindowStack[idx])
            WindowStack.RemoveAt(idx)
        }
    }

    ; Find the active window after cleanup, so removed windows cannot leave
    ; the index pointing at the wrong element
    activeIndex := GetStackIndex(activeHwnd)

    ; After cleanup, check if we still have windows
    if (WindowStack.Length == 0) {
        ViewOffset := 0
        WindowWidths.Clear()
        UpdateDock()
        Critical "Off"
        return
    }

    ; The active window is not in the stack
    if (activeIndex == 0) {
        if (activeRemoved) {
            ; The active managed window was closed: hand focus to the first
            ; window in the stack
            try {
                WinActivate(WindowStack[1])
                activeIndex := 1
            } catch as err {
                UpdateDock()
                Critical "Off"
                return
            }
        } else {
            ; The active window is unmanaged (Start menu, dialog, popup):
            ; keep the current layout instead of stealing focus
            UpdateDock()
            Critical "Off"
            return
        }
    }

    if (OverlayMode) {
        ; Fill the usable area, leaving one gap at each edge
        overlayLeft := WorkLeft + Gap
        overlayTop := WorkTop + Gap
        overlayWidth := Max(1, WorkWidth - (2 * Gap))
        overlayHeight := Max(1, WorkHeight - (2 * Gap))
        for hwnd in WindowStack {
            try {
                WinRestore(hwnd)
                WinMove(overlayLeft, overlayTop, overlayWidth, overlayHeight, hwnd)
            }
            catch as err
                ; Skip windows that can't be moved
                continue
        }
    } else {
        ; Calculate current available height inside the work area
        currentHeight := GetAvailableHeight()
        windowTop := GetWindowTop()

        ; Full-width windows use a focus layout: 85% of the viewport. The
        ; remaining space is split between the previous/next peeks, using the
        ; same Gap as the 25/50/75 tiling presets for the gutters.
        viewportWidth := WorkWidth - 2 * Gap
        peekMode := (GetWindowWidthRatio(activeHwnd) >= 0.9999)

        ; Lay the stack out as a single row: each window keeps its own width,
        ; and the row scrolls horizontally like niri's scrolling layout.
        widths := []
        lefts := []
        cursor := 0
        for i, hwnd in WindowStack {
            widths.Push(GetWindowWidth(hwnd))
            lefts.Push(cursor)
            cursor += widths[i] + Gap
        }

        activeLeft := lefts[activeIndex]
        activeWidth := widths[activeIndex]
        leftEdge := WorkLeft + Gap
        rightEdge := WorkLeft + WorkWidth - Gap

        if (peekMode || centerActive) {
            ; Center the focused window. In peek mode the space left over
            ; after the 85% window and the Gap becomes the neighbour peeks.
            ViewOffset := Round(activeLeft + activeWidth / 2 - viewportWidth / 2)
        } else {
            ; Niri's default "never" centering: scroll only when the active
            ; window would leave the screen, parking it at the screen edge.
            screenLeft := leftEdge + activeLeft - ViewOffset
            screenRight := screenLeft + activeWidth
            if (screenLeft < leftEdge)
                ViewOffset -= (leftEdge - screenLeft)
            else if (screenRight > rightEdge)
                ViewOffset += (screenRight - rightEdge)
        }

        for i, hwnd in WindowStack {
            ; WinMove cannot move minimized windows; they keep their old
            ; position and are repositioned by the reflow triggered when
            ; they are restored
            try {
                if (WinGetMinMax(hwnd) = -1)
                    continue
            }
            catch as err
                continue
            x := Round(leftEdge + lefts[i] - ViewOffset)
            try WinMove(x, windowTop, widths[i], currentHeight, hwnd)
            catch as err
                ; Skip windows that can't be moved
                continue
        }
    }

    UpdateDock()
    Critical "Off"
}

; ==============================================================================
; NAVIGATION LOGIC
; ==============================================================================

; Switch to a specific virtual desktop
; @param Target - Desktop number to switch to (1-10)
GoToDesktop(Target) {
    global CurrentDesktop, InitializedDesktops
    
    ; Don't switch desktops when suspended
    if (Suspended)
        return
    
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

; Get the 1-based position of a window in the stack
; @param hwnd - Window handle to locate
; @return Position in WindowStack, or 0 if not found
GetStackIndex(hwnd) {
    if (!hwnd)
        return 0
    for i, item in WindowStack
        if (item == hwnd)
            return i
    return 0
}

; Get the width ratio remembered for a window
; @param hwnd - Window handle
; @return Width ratio relative to the work area width
GetWindowWidthRatio(hwnd) {
    global WindowWidths, FullWidthRatio
    if (WindowWidths.Has(hwnd))
        return WindowWidths[hwnd]
    return FullWidthRatio
}

; Convert a width ratio into pixels for the current work area.
; Gaps are subtracted from the proportion, so four 25% windows or two 50%
; windows tile the screen exactly instead of overflowing by the gaps.
; @param hwnd - Window handle
; @return Window width in pixels
GetWindowWidth(hwnd) {
    global Gap, WorkWidth, FocusWidthRatio
    ratio := GetWindowWidthRatio(hwnd)
    if (ratio >= 0.9999) {
        ; "Full" is the focus layout: 85% of the viewport. The gutter and
        ; edge gaps are the shared Gap, so the rest is visible neighbour.
        viewportWidth := WorkWidth - (2 * Gap)
        return Round(viewportWidth * FocusWidthRatio)
    }
    return Round(WorkWidth * ratio - Gap * (1 + ratio))
}

; Remember a width for the active window and reflow the stack
; @param ratio - Width ratio relative to the work area width
; @param label - Text shown in the HUD flash message
SetWindowWidthPreset(ratio, label) {
    global WindowWidths
    hwnd := WinActive("A")
    if (!hwnd || GetStackIndex(hwnd) == 0) {
        FlashMessage("NO MANAGED WINDOW")
        return
    }
    WindowWidths[hwnd] := ratio
    FlashMessage("WIDTH " label)
    ReflowStack()
}

; Center the active window in the viewport (niri's center-column action)
CenterActiveWindow() {
    global OverlayMode
    if (OverlayMode) {
        FlashMessage("OVERLAY MODE")
        return
    }
    if (GetStackIndex(WinActive("A")) == 0) {
        FlashMessage("NO MANAGED WINDOW")
        return
    }
    ReflowStack(true)
    FlashMessage("CENTERED")
}

; Cycle through window stack
; @param direction - Direction to cycle (1=next, -1=previous)
CycleStack(direction) {
    ; Don't cycle when suspended
    if (Suspended)
        return
    
    if (WindowStack.Length <= 1)
        return

    activeIndex := GetStackIndex(WinActive("A"))

    if (activeIndex == 0)
        return

    newIndex := activeIndex + direction
    if (newIndex < 1)
        newIndex := WindowStack.Length
    else if (newIndex > WindowStack.Length)
        newIndex := 1

    try WinActivate(WindowStack[newIndex])
    catch as err
        ; Failed to activate window
        return
    
    ; ReflowStack will be triggered automatically via ShellMessage hook
    ; Update dock after window activation
    SetTimer(() => UpdateDock(), -DockUpdateDelay)
}

; Switch to window by index in stack
; @param index - Window index (1-based)
GoToWindowByIndex(index) {
    ; Don't switch windows when suspended
    if (Suspended)
        return
    
    if (WindowStack.Length == 0 || index < 1 || index > WindowStack.Length) {
        FlashMessage("WINDOW " . index . " NOT FOUND")
        return
    }

    try {
        WinActivate(WindowStack[index])
        FlashMessage("WINDOW " . index)
        ; Update dock after window activation
        SetTimer(() => UpdateDock(), -DockUpdateDelay)
    }
    catch as err {
        FlashMessage("FAILED TO ACTIVATE")
    }
}

; Add all existing windows to the stack on startup or desktop switch
InitializeExistingWindows() {
    ; Don't initialize when suspended
    if (Suspended)
        return
    
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
        catch as err
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

    ; Save and clear clipboard
    oldClip := ClipboardAll()
    A_Clipboard := ""
    
    ; Copy current line
    Send "{Home}+{End}^c"
    if (ClipWait(0.5)) {
        lineText := A_Clipboard
        pos := InStr(lineText, target)
        if (pos > 0) {
            Send "{Home}"
            moveCount := isTill ? pos - 2 : pos - 1
            ; Ensure we don't send negative moves
            if (moveCount > 0) {
                loop moveCount
                    Send "{Right}"
            }
        }
    }
    
    ; Restore clipboard
    A_Clipboard := oldClip
}

; Toggle Windows taskbar visibility
ToggleTaskbar() {
    ; Don't toggle taskbar when suspended
    if (Suspended)
        return
    
    global TaskbarHidden
    target := "ahk_class Shell_TrayWnd"

    if (!TaskbarHidden) {
        try WinHide(target)
        catch as err
            ; Taskbar hide failed
            return
        
        ; Also hide the Start Button (sometimes required on Win 10/11)
        try {
            if (WinExist("ahk_class Button"))
                WinHide("ahk_class Button")
        }
        catch as err
            ; Start button hide failed
        
        TaskbarHidden := true
        ToolTip("Taskbar: HIDDEN")
    } else {
        try WinShow(target)
        catch as err
            ; Taskbar show failed
            return
        
        try {
            if (WinExist("ahk_class Button"))
                WinShow("ahk_class Button")
        }
        catch as err
            ; Start button show failed
        
        TaskbarHidden := false
        ToolTip("Taskbar: VISIBLE")
    }
    SetTimer(() => ToolTip(), -TooltipDuration)
    
    ; Reflow against the new work area and move the HUD with it
    ReflowStack()
    if (VimMode > 0)
        UpdateHUD(VimMode)
}

; ==============================================================================
; CLEANUP
; ==============================================================================

; Cleanup function called on script exit
OnExit(CleanupAndExit)

CleanupAndExit(ExitReason, ExitCode) {
    ; Hide GUIs before exit
    try VimGui.Destroy()
    catch as err {
        ; Already destroyed
    }
    
    try DockGui.Destroy()
    catch as err {
        ; Already destroyed
    }
    
    ; Show taskbar if it was hidden
    if (TaskbarHidden) {
        try WinShow("ahk_class Shell_TrayWnd")
        catch as err {
            ; Failed to show taskbar
        }
        ; Also show the Start Button
        try {
            if (WinExist("ahk_class Button"))
                WinShow("ahk_class Button")
        }
        catch as err {
            ; Failed to show start button
        }
    }
}

; ==============================================================================
; VIM MODE (HOTKEYS & LOCKDOWN)
; ==============================================================================

; Detect and initialize taskbar state on startup
try {
    ; Check if taskbar is currently visible
    taskbarTarget := "ahk_class Shell_TrayWnd"
    if (WinExist(taskbarTarget)) {
        ; Try to detect if taskbar is hidden by checking if it's visible
        try {
            taskbarVisible := DllCall("IsWindowVisible", "Ptr", WinExist(taskbarTarget), "Int")
            global TaskbarHidden := !taskbarVisible
            
            ; If taskbar was hidden from previous session, show it on startup
            if (TaskbarHidden) {
                WinShow(taskbarTarget)
                ; Also show the Start Button
                try {
                    if (WinExist("ahk_class Button"))
                        WinShow("ahk_class Button")
                }
                catch as err {
                    ; Start button show failed
                }
                global TaskbarHidden := false
                ToolTip("Taskbar: RESTORED ON STARTUP")
                SetTimer(() => ToolTip(), -2000)
            }
        }
        catch as err {
            ; If detection fails, assume taskbar is visible
            global TaskbarHidden := false
        }
    }
}
catch as err {
    ; If taskbar detection fails, assume it's visible
    global TaskbarHidden := false
}

; Detect the taskbar inset before the first layout
RefreshWorkArea()

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
    ; If suspended, resume by calling ToggleSuspend and enter Normal mode
    if (Suspended) {
        ToggleSuspend()  ; This will restore window positions
        UpdateHUD(1)     ; Enter Normal mode
    } else {
        ; Normal toggle behavior
        UpdateHUD(VimMode == 0 ? 1 : 0)
    }
}

#HotIf (VimMode == 1 || VimMode == 2) && !Suspended
; --- Virtual Desktops ---
^j:: {
    Send("^#{Left}")  ; Ctrl+Win+Left
    global CurrentDesktop -= 1
    if (CurrentDesktop < 1)
        global CurrentDesktop := 1
    global InitializedDesktops
    if (!InitializedDesktops.Has(CurrentDesktop)) {
        SetTimer(() => InitializeDesktop(CurrentDesktop), -DesktopSwitchDelay)
    }
}
^k:: {
    Send("^#{Right}")  ; Ctrl+Win+Right
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
#HotIf

#HotIf VimMode > 0
; --- Layout Control ---
^q:: ToggleSuspend()  ; Toggle script suspension
#HotIf

#HotIf (VimMode == 1 || VimMode == 2) && !Suspended
^f:: {
    global OverlayMode := !OverlayMode
    FlashMessage(OverlayMode ? "OVERLAY MODE" : "TILING MODE")
    ReflowStack()
}
^+d:: {
    global WindowWidths
    if (WindowStack.Length == 0)
        return
    
    activeHwnd := WinActive("A")
    if (!activeHwnd)
        return
    
    for i, hwnd in WindowStack {
        if (hwnd == activeHwnd) {
            WindowWidths.Delete(hwnd)
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
; Swap the active window with its neighbour
; @param dir - 1 = swap with right neighbour, -1 = swap with left neighbour
SwapActive(dir) {
    if (WindowStack.Length <= 1)
        return
    
    idx := GetStackIndex(WinActive("A"))
    if (idx == 0)
        return
    
    j := idx + dir
    if (j < 1 || j > WindowStack.Length)
        return
    
    temp := WindowStack[j]
    WindowStack[j] := WindowStack[idx]
    WindowStack[idx] := temp
    ReflowStack()
    
    activeHwnd := WindowStack[j]
    try WinActivate(activeHwnd)
    catch as err {
        ; Failed to reactivate
    }
}

^h:: SwapActive(-1)
^l:: SwapActive(1)

; --- Navigation ---
n:: CycleStack(1)
Tab:: CycleStack(-1)  ; p is used for paste in Normal mode
z:: ReflowStack()

; --- Window Width & Centering (niri-style columns) ---
^+1:: SetWindowWidthPreset(0.25, "25%")
^+2:: SetWindowWidthPreset(0.50, "50%")
^+3:: SetWindowWidthPreset(0.75, "75%")
^+0:: SetWindowWidthPreset(FullWidthRatio, "FULL")
^+c:: CenterActiveWindow()

; --- Vim Text Navigation ---
h:: Send(VimMode == 2 ? "+{Left}" : "{Left}")
j:: Send(VimMode == 2 ? "+{Down}" : "{Down}")
k:: Send(VimMode == 2 ? "+{Up}" : "{Up}")
l:: Send(VimMode == 2 ? "+{Right}" : "{Right}")
w:: Send(VimMode == 2 ? "^+{Right}" : "^{Right}")
b:: Send(VimMode == 2 ? "^+{Left}" : "^{Left}")
e:: Send(VimMode == 2 ? "^+{Right}+{Left}" : "^{Right}{Left}") ; word end (approximation)
0:: Send(VimMode == 2 ? "+{Home}" : "{Home}")
+4:: Send(VimMode == 2 ? "+{End}" : "{End}") ; '$' key
^d:: Send(VimMode == 2 ? "+{PgDn}" : "{PgDn}") ; Page down
^u:: Send(VimMode == 2 ? "+{PgUp}" : "{PgUp}") ; Page up

; --- Vim Mode Switching ---
v:: UpdateHUD(VimMode == 1 ? 2 : 1)

; --- Enter Insert from Normal or Visual ---
i:: {
    if (VimMode == 2)
        Send "{Left}"  ; collapse the selection to its start
    UpdateHUD(3)
}

; --- Document Navigation (Normal and Visual) ---
g:: {
    if (A_PriorHotkey == "g" and A_TimeSincePriorHotkey < DblClickTimeout) {
        if (VimMode == 2)
            Send "+^{Home}" ; 'gg' extends selection in Visual mode
        else
            Send "^{Home}"  ; 'gg'
    }
}
+g:: {
    if (VimMode == 2)
        Send "+^{End}" ; 'G' extends selection in Visual mode
    else
        Send "^{End}"  ; 'G'
}
#HotIf

; --- Escape (Normal, Visual, Insert) ---
#HotIf (VimMode == 1 || VimMode == 2 || VimMode == 3) && !Suspended
Esc:: {
    if (VimMode != 1)
        UpdateHUD(1)
    ; Normal mode: swallow Esc; Off mode: the hotkey is inactive
}
#HotIf

; --- Normal Vim Mode Commands ---
#HotIf VimMode == 1 && !Suspended
; Find Commands
f:: ExecuteFind(false)
t:: ExecuteFind(true)
/:: {
    Send "^f"
    UpdateHUD(0)
}

; Delete Commands
d:: {
    if (A_PriorHotkey == "d" and A_TimeSincePriorHotkey < DblClickTimeout)
        Send "{Home}+{End}{BackSpace}{Delete}" ; 'dd'
}

; Change Commands
c:: {
    if (A_PriorHotkey == "c" and A_TimeSincePriorHotkey < DblClickTimeout) {
        Send "{Home}+{End}{BackSpace}" ; 'cc'
        UpdateHUD(3)
    } else {
        Send "^{Delete}" ; 'cw'
        UpdateHUD(3)
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
o:: Send("{End}{Enter}"), UpdateHUD(3)
+o:: Send("{Home}{Enter}{Up}"), UpdateHUD(3)
a:: Send("{Right}"), UpdateHUD(3)
+a:: Send("{End}"), UpdateHUD(3)

; Command Line
SC027:: return ; ';' is swallowed; use ':' for command mode
+SC027:: { ; ':' key
    ; Turn hotkeys off while the command box is open, so typed letters
    ; (w, q) reach the box instead of firing hotkeys
    targetHwnd := WinActive("A")
    prevVimMode := VimMode
    UpdateHUD(0)
    Result := InputBox("Command: w (save), q (quit), wq (save & quit)", "Vim Command", "h80 w300")
    if (Result.Result = "OK") {
        val := Trim(StrLower(Result.Value))
        if (SubStr(val, 1, 1) == ":")
            val := Trim(SubStr(val, 2))
        if (val = "w" || val = "q" || val = "wq") {
            ; Restore focus to the window that was active before the InputBox
            if (targetHwnd && WinExist("ahk_id " targetHwnd)) {
                try WinActivate("ahk_id " targetHwnd)
                Sleep 100
            }
            if (val = "w" || val = "wq")
                Send "^s"
            if (val = "q")
                Send "!{F4}"
            if (val = "wq") {
                Sleep 100
                Send "!{F4}"
            }
        }
    }
    ; Restore previous mode unless a command already changed it
    if (VimMode == 0 && prevVimMode != 0)
        UpdateHUD(prevVimMode)
}

; Window Navigation by Number
1:: GoToWindowByIndex(1)
2:: GoToWindowByIndex(2)
3:: GoToWindowByIndex(3)
4:: GoToWindowByIndex(4)
5:: GoToWindowByIndex(5)
6:: GoToWindowByIndex(6)
7:: GoToWindowByIndex(7)
8:: GoToWindowByIndex(8)
9:: GoToWindowByIndex(9)
#HotIf

; --- Visual Vim Mode Commands ---
#HotIf VimMode == 2 && !Suspended
d:: Send("{BackSpace}"), UpdateHUD(1)
c:: Send("{BackSpace}"), UpdateHUD(3)
y:: Send("^c"), UpdateHUD(1), FlashMessage("YANKED")
x:: Send("{Delete}"), UpdateHUD(1)
p:: Send("^v"), UpdateHUD(1)

; Unsupported Visual commands are swallowed so they do not type into the document.
a:: return
+a:: return
o:: return
+o:: return
SC027:: return
+SC027:: return
+SC033:: return   ; '<' (indentation is not supported)
+SC034:: return   ; '>' (indentation is not supported)
+v:: return       ; 'V' (linewise Visual is not supported)
^v:: return       ; Ctrl+V (blockwise Visual is not supported)
f:: return
t:: return
/:: return
#HotIf

#HotIf