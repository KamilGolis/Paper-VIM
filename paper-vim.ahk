#Requires AutoHotkey v2.0
#SingleInstance Force
; Remove delay between window operations for speed
SetWinDelay -1

; ==============================================================================
; CONFIGURATION & HUD
; ==============================================================================
global WindowStack := []
global TargetWidth := A_ScreenWidth * 0.95
global Gap := 8
global CenterX := (A_ScreenWidth - TargetWidth) / 2
global BarHeight := 60
global TaskbarHeight := 48
global TaskbarHidden := false
global V_Height := A_ScreenHeight - BarHeight - (3 * Gap)
global V_Top := 2 * Gap
global OverlayMode := false
global Mode := 0
global CurrentDesktop := 1
global ReflowTimer := 0
; Track which desktops have been arranged
global InitializedDesktops := Map()

; HUD Setup
VimGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
VimGui.BackColor := "121212"
VimGui.SetFont("s16 w800", "Segoe UI")
VimText := VimGui.Add("Text", "Center w220", "VIM: NORMAL")
WinSetTransColor("121212", VimGui)

; Dock HUD Setup
DockGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
DockGui.BackColor := "1a1a1a"
WinSetTransColor("1a1a1a", DockGui)
DockGui.MarginX := 12
DockGui.MarginY := 8
global DockIcons := []

UpdateHUD(NewState) {
    global Mode := NewState
    if (Mode == 0) {
        VimGui.Hide()
    } else if (Mode == 1) {
        VimText.Opt("c00FF00")
        VimText.Value := "VIM: NORMAL"
        VimGui.Show("x" (A_ScreenWidth - 240) " y40 NoActivate")
    } else if (Mode == 2) {
        VimText.Opt("cFF0000")
        VimText.Value := "VIM: VISUAL"
        VimGui.Show("x" (A_ScreenWidth - 240) " y40 NoActivate")
    }
}

FlashMessage(Msg, Duration := 800) {
    if (Mode > 0) {
        origColor := (Mode == 2) ? "cFF0000" : "c00FF00"
        VimText.Opt("cFFFF00")
        VimText.Value := Msg
        SetTimer(() => UpdateHUD(Mode), -Duration)
    }
}

UpdateDock() {
    global WindowStack, DockGui, DockIcons

    ; Destroy entire GUI and recreate to avoid duplicates
    try DockGui.Destroy()
    DockGui := Gui("+AlwaysOnTop -Caption +ToolWindow +LastFound")
    DockGui.BackColor := "1a1a1a"
    WinSetTransColor("1a1a1a", DockGui)
    DockGui.MarginX := 12
    DockGui.MarginY := 8
    DockIcons := []

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

    iconSize := 32
    iconSpacing := 8
    ; Show 2 icons on the left
    leftCount := 2
    ; Show 2 icons on the right
    rightCount := 2

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

    ; Add left icons (2 previous windows, in correct order)
    leftIndices := []
    loop leftCount {
        idx := WrapIndex(activeIndex - leftCount + A_Index - 1)
        leftIndices.Push(idx)
    }

    for idx in leftIndices {
        try {
            iconPath := GetWindowIconPath(WindowStack[idx])
            pic := DockGui.Add("Picture", "x" xPos " y0 w" iconSize " h" iconSize, iconPath)
            DockIcons.Push(pic)
            xPos += iconSize + iconSpacing
        }
    }

    ; Add center icon (active window) - with underline
    try {
        iconPath := GetWindowIconPath(WindowStack[activeIndex])
        pic := DockGui.Add("Picture", "x" xPos " y0 w" iconSize " h" iconSize, iconPath)
        DockIcons.Push(pic)
        ; Add underline below active icon
        DockGui.Add("Text", "x" xPos " y" (iconSize + 2) " w" iconSize " h2 Background00FF00")
        xPos += iconSize + iconSpacing
    }

    ; Add right icons (2 next windows)
    loop rightCount {
        idx := WrapIndex(activeIndex + A_Index)
        try {
            iconPath := GetWindowIconPath(WindowStack[idx])
            pic := DockGui.Add("Picture", "x" xPos " y0 w" iconSize " h" iconSize, iconPath)
            DockIcons.Push(pic)
            xPos += iconSize + iconSpacing
        }
    }

    ; Calculate total width and position dock at screen center
    ; 5 total icons (2 left, 1 active, 2 right)
    totalIcons := leftCount + 1 + rightCount
    totalWidth := (totalIcons * iconSize) + ((totalIcons - 1) * iconSpacing) + 24
    dockX := (A_ScreenWidth - totalWidth) / 2
    DockGui.Show("x" dockX " y10 w" totalWidth " h" (iconSize + 16) " NoActivate")
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
    ; Debounce: wait 50ms before reflowing
    SetTimer(ReflowTimer, -50)
}

ManageNewWindow(hwnd) {
    if !WinExist(hwnd)
        return
    style := WinGetStyle(hwnd)
    if !(style & 0x00C00000)
    ; Title bar filter
        return
    for item in WindowStack
        if (item == hwnd)
            return
    WindowStack.Push(hwnd)
    ReflowStack()
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
        if (activeIndex == 0) {
            UpdateDock()
            return
        }
        ; Calculate current available height based on taskbar visibility
        currentHeight := GetAvailableHeight()
        for i, hwnd in WindowStack {
            relativeOffset := (i - activeIndex) * (TargetWidth + Gap)
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
        SetTimer(() => InitializeDesktop(Target), -200)
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
    SetTimer(() => UpdateDock(), -100)
}

InitializeExistingWindows() {
    windowList := WinGetList()
    for hwnd in windowList {
        try {
            style := WinGetStyle(hwnd)
            if (style & 0x00C00000) {
                ; Has title bar
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
    SetTimer(() => ToolTip(), -1000)
    
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
        SetTimer(() => InitializeDesktop(CurrentDesktop), -200)
    }
}
^k:: {
    Send("^#+{Right}")
    global CurrentDesktop += 1
    global InitializedDesktops
    if (!InitializedDesktops.Has(CurrentDesktop)) {
        SetTimer(() => InitializeDesktop(CurrentDesktop), -200)
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
    if (A_PriorHotkey == "g" and A_TimeSincePriorHotkey < 400)
        Send "^{Home}" ; 'gg'
}
+g:: Send "^{End}" ; 'G'

; Delete Commands
d:: {
    if (A_PriorHotkey == "d" and A_TimeSincePriorHotkey < 400)
        Send "{Home}+{End}{BackSpace}{Delete}" ; 'dd'
}

; Change Commands
c:: {
    if (A_PriorHotkey == "c" and A_TimeSincePriorHotkey < 400) {
        Send "{Home}+{End}{BackSpace}" ; 'cc'
        UpdateHUD(0)
    } else {
        Send "^{Delete}" ; 'cw'
        UpdateHUD(0)
    }
}

; Yank Commands
y:: {
    if (A_PriorHotkey == "y" and A_TimeSincePriorHotkey < 400) {
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