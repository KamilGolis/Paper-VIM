; ==============================================================================
; Paper-VIM: Vim Keybindings + PaperWM Window Manager
; Version: 1.8.0
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

; Defaults and the optional paper-vim.ini overrides live in config.ahk.
#Include config.ahk

global DockSlotCount := DockLeftCount + 1 + DockRightCount
global TargetGridCellCount := TargetGridRows * TargetGridCols

; ==============================================================================
; CONFIGURATION & GLOBAL VARIABLES
; ==============================================================================

; --- Window Layout State ---
; User-facing layout settings are defined in config.ahk.
global WindowStack := []              ; Array of managed window handles
global WindowWidths := Map()          ; Per-window width ratio (hwnd -> 0.25..1.0)
global ViewOffset := 0                ; Horizontal scroll offset of the window row (px)
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
global VimMode := 0                   ; 0=Off, 1=Normal, 2=Visual, 3=Insert, 4=Targeting
global Suspended := false             ; Script suspension state (pauses all actions)
global SuspendedState := Map()        ; Stores window state before suspension
global EmergencyMode := false         ; Set after an unhandled error; freezes layout
global EmergencyInProgress := false   ; Prevents recursive emergency-layout handling
global HelpVisible := false           ; Keybind help overlay is open
global HelpTargetHwnd := 0            ; Window to reactivate after help closes

; --- Targeting Mode ---
global TargetActive := false          ; Targeting grid and input hook are active
global TargetHelpPaused := false      ; Targeting is hidden while help is open
global TargetHook := ""               ; InputHook that owns the keyboard in Targeting
global TargetMonL := 0                ; Target monitor bounds in screen coordinates
global TargetMonT := 0
global TargetMonR := 0
global TargetMonB := 0
global TargetL := 0                   ; Current active cell bounds
global TargetT := 0
global TargetR := 0
global TargetB := 0
global TargetHistory := []            ; Previous active cells, for Backspace
global TargetHeldKeys := Map()        ; Held cell keys, to ignore auto-repeat
global TargetDimGui := ""             ; Full-monitor dim layer
global TargetAncestorGui := ""        ; Faint outlines of previous cells
global TargetGridGui := ""            ; Current configured grid labels
global TargetCellCtrls := []          ; Cell border controls
global TargetCellLabels := []         ; Single-key cell label controls
global TargetAncestorCtrls := []      ; Fixed pool of previous-outline controls
global TargetKeyMap := Map()          ; Virtual key code -> one-based cell index

; --- Desktop Management ---
global CurrentDesktop := 1            ; Currently active virtual desktop number
global InitializedDesktops := Map()  ; Track which desktops have been auto-arranged
global ReflowTimer := 0               ; Debounce timer for window reflow operations

; --- Visual and Focus Border State ---
; User-facing colors and focus-border settings are defined in config.ahk.
global FocusBars := []                   ; Four click-through border Gui windows
global FocusBorderShown := false         ; Border bars are currently visible
global FocusBorderTarget := 0            ; Window handle the border is tracking
global FocusBorderX := 0                 ; Cached outer border coordinates
global FocusBorderY := 0
global FocusBorderW := 0
global FocusBorderH := 0

; --- Dock State ---
; User-facing dock settings are defined in config.ahk.
global DockSlotPics := []             ; Persistent Picture controls
global DockNumberCtrls := []          ; Persistent number label controls
global DockSlotHwnds := []            ; Window handle currently shown in each slot
global DockActiveUnderline := 0       ; Persistent active-slot underline
global DockWidth := 0                 ; Cached auto-sized dock width
global DockHeight := 0                ; Cached auto-sized dock height
global DockShown := false             ; Dock window is currently visible
global DockShownX := 0                ; Last shown position
global DockShownY := 0

; --- HUD State ---
global FlashTimer := 0                ; Timer handle of the current flash restore

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

; Install the emergency guard before any layout code runs.
OnError(EmergencyOnError)

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
DockGui.SetFont(DockNumberFontSize " " DockInactiveNumberColor, FontFamily)

; Create fixed dock slots once. UpdateDock only changes their images, numbers,
; and positions; rebuilding the GUI caused visible flicker on every reflow.
loop DockSlotCount {
    slotX := (A_Index - 1) * (DockIconSize + DockIconSpacing)
    DockSlotPic := DockGui.Add("Picture", "x" slotX " y0 w" DockIconSize " h" DockIconSize, A_WinDir "\System32\shell32.dll")
    DockSlotPics.Push(DockSlotPic)
    DockNumberCtrl := DockGui.Add("Text", "x" slotX " y" (DockIconSize + 4) " w" DockIconSize " h" DockNumberHeight " Center", "")
    DockNumberCtrls.Push(DockNumberCtrl)
}
DockActiveUnderline := DockGui.Add("Text", "x0 y" (DockIconSize + 2) " w" DockIconSize " h2 Background" ActiveIndicatorColor, "")

; Measure the fixed dock once while hidden. Its width does not change because
; the number of slots is fixed.
DockGui.Show("Hide")
WinGetPos(&dockMeasuredX, &dockMeasuredY, &DockWidth, &DockHeight, DockGui.Hwnd)
if (DockWidth <= 1)
    DockWidth := DockMarginX * 2 + DockSlotCount * DockIconSize + (DockSlotCount - 1) * DockIconSpacing
if (DockHeight <= 1)
    DockHeight := DockMarginY * 2 + DockIconSize + 4 + DockNumberHeight
DockGui.Hide()
loop DockSlotCount
    DockSlotHwnds.Push(0)

; Keybind help overlay (hidden until F1 is pressed)
HelpGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
HelpGui.BackColor := "121212"
HelpGui.MarginX := 0
HelpGui.MarginY := 0
HelpGui.SetFont("s9 cFFFFFF", "Consolas")
helpLeftWidth := Min(720, Max(400, A_ScreenWidth - 800))
helpRightWidth := Min(600, Max(320, A_ScreenWidth - helpLeftWidth - 100))
helpHeight := Min(900, Max(500, A_ScreenHeight - 400))
HelpLeftCtl := HelpGui.Add("Text", "x20 y20 w" helpLeftWidth " h" helpHeight " -Wrap", "")
HelpRightCtl := HelpGui.Add("Text", "x" (20 + helpLeftWidth + 20) " y20 w" helpRightWidth " h" helpHeight " -Wrap", "")
HelpGui.OnEvent("Close", (*) => DismissHelp())

; Focus border bars: four click-through, never-active windows. -DPIScale keeps
; their coordinates in physical pixels, matching DWM frame bounds.
loop 4 {
    FocusBorderBar := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000 +E0x08000000 -DPIScale")
    FocusBorderBar.BackColor := FocusBorderColor
    FocusBorderBar.Show("NA x0 y0 w1 h1 Hide")
    ; Layered + transparent extended style makes the bar click-through.
    WinSetTransparent(255, FocusBorderBar)
    FocusBars.Push(FocusBorderBar)
}

; Targeting overlays. The dim layer darkens the monitor; the two transparent
; layers draw faint previous outlines and the current grid without stealing
; the mouse or keyboard focus.
TargetDimGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000 +E0x08000000 -DPIScale")
TargetDimGui.BackColor := "000000"
TargetDimGui.Show("NA x0 y0 w1 h1 Hide")
WinSetTransparent(70, TargetDimGui)

TargetAncestorGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000 +E0x08000000 -DPIScale")
TargetAncestorGui.BackColor := "010203"
TargetAncestorGui.Show("NA x0 y0 w1 h1 Hide")
WinSetTransColor("010203", TargetAncestorGui)
WinSetTransparent(100, TargetAncestorGui)
loop 12 {
    TargetAncestorCtrl := TargetAncestorGui.Add("Text", "x0 y0 w1 h1 +Border +BackgroundTrans", "")
    TargetAncestorCtrl.Visible := false
    TargetAncestorCtrls.Push(TargetAncestorCtrl)
}

TargetGridGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000 +E0x08000000 -DPIScale")
TargetGridGui.BackColor := "010203"
TargetGridGui.SetFont("s20 cFFFFFF w700", "Consolas")
TargetGridGui.Show("NA x0 y0 w1 h1 Hide")
WinSetTransColor("010203", TargetGridGui)
Loop TargetGridCellCount {
    TargetCellCtrl := TargetGridGui.Add("Text", "x0 y0 w1 h1 +Border +BackgroundTrans", "")
    TargetCellCtrls.Push(TargetCellCtrl)
}
Loop TargetGridCellCount {
    TargetCellLabel := TargetGridGui.Add("Text", "x0 y0 w1 h1 +0x200 Center +BackgroundTrans", "")
    TargetCellLabels.Push(TargetCellLabel)
}

; ==============================================================================
; CORE FUNCTIONS
; ==============================================================================

; Show the HUD at the top-right of the work area. The HUD auto-sizes to its
; text, so measure the real window width instead of using a fixed width.
ShowHUDAtTopRight() {
    global VimGui, WorkLeft, WorkWidth, WorkTop, HUDPosY, HUDMarginRight
    global VimMode, TargetActive, TargetMonT, TargetMonR

    VimGui.Show("Hide")
    WinGetPos(&hx, &hy, &hudWidth, &hudHeight, VimGui.Hwnd)
    if (VimMode == 4 && TargetActive) {
        ; Keep the mode indicator on the monitor that owns the grid.
        hudX := TargetMonR - hudWidth - HUDMarginRight
        hudY := TargetMonT + HUDPosY
    } else {
        hudX := WorkLeft + WorkWidth - hudWidth - HUDMarginRight
        hudY := WorkTop + HUDPosY
    }
    VimGui.Show("x" hudX " y" hudY " NoActivate")
}

; Update HUD display based on current Vim mode
; @param NewState - Vim mode value: 0=Off, 1=Normal, 2=Visual, 3=Insert, 4=Targeting
UpdateHUD(NewState) {
    global VimMode := NewState

    ; Keep the HUD inside the usable area when the taskbar moves
    RefreshWorkArea()
    UpdateFocusBorder()

    ; If suspended, always show suspended state
    if (Suspended) {
        VimText.Opt(SuspendedModeColor)
        VimText.Value := "SUSPENDED"
        ShowHUDAtTopRight()
        return
    }

    ; The help overlay owns the screen while it is open.
    if (HelpVisible) {
        VimGui.Hide()
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
    } else if (VimMode == 4) {
        VimText.Opt(TargetingModeColor)
        VimText.Value := "VIM: TARGET"
        ShowHUDAtTopRight()
    }
}

; Display temporary message in HUD
; @param Msg - Message to display
; @param Duration - How long to show message (default: FlashDuration)
FlashMessage(Msg, Duration := FlashDuration) {
    global FlashTimer
    if (VimMode > 0 && !LayoutFrozen() && !HelpVisible) {
        VimText.Opt(FlashMsgColor)
        VimText.Value := Msg
        ; Cancel any pending restore so messages don't cut each other short
        if (FlashTimer)
            SetTimer(FlashTimer, 0)
        FlashTimer := () => UpdateHUD(VimMode)
        SetTimer(FlashTimer, -Duration)
    }
}

; True when window layout actions must not run.
LayoutFrozen() {
    global Suspended, EmergencyMode
    return Suspended || EmergencyMode
}

; --- Keybind Help -----------------------------------------------------------

; Toggle the combined keybind reference.
ToggleHelp() {
    if (HelpVisible)
        DismissHelp()
    else if (VimMode == 4 && TargetActive)
        PauseTargetingForHelp()
    else
        ShowHelp()
}

; Show the combined keybind reference, marking the current Vim mode.
ShowHelp() {
    global HelpVisible, HelpGui, HelpLeftCtl, HelpRightCtl, HelpTargetHwnd
    global VimMode, VimGui

    if (HelpVisible || VimMode < 1 || VimMode > 4)
        return

    HelpTargetHwnd := WinActive("A")
    panels := BuildHelpText(VimMode)
    HelpLeftCtl.Value := panels[1]
    HelpRightCtl.Value := panels[2]
    HelpVisible := true
    UpdateFocusBorder()
    try VimGui.Hide()
    try {
        HelpGui.Show("AutoSize Center")
        WinActivate("ahk_id " HelpGui.Hwnd)
    } catch as err {
        DismissHelp()
    }
}

; Close the help overlay and return to the Vim mode it was opened from.
DismissHelp() {
    global HelpVisible, HelpGui, HelpTargetHwnd, VimMode
    global TargetHelpPaused

    if (!HelpVisible)
        return

    HelpVisible := false
    try HelpGui.Hide()
    if (HelpTargetHwnd && WinExist("ahk_id " HelpTargetHwnd))
        try WinActivate("ahk_id " HelpTargetHwnd)

    ; Targeting was only hidden while help was open; put its grid back.
    if (VimMode == 4 && TargetHelpPaused) {
        ResumeTargetingAfterHelp()
        return
    }

    UpdateHUD(VimMode)
}

; Build the combined keybind reference.
; @param currentMode - Vim mode to mark: 1=Normal, 2=Visual, 3=Insert, 4=Targeting
; @return Array: [left column text, right column text]
BuildHelpText(currentMode) {
    global TargetGridRows, TargetGridCols
    modeName := (currentMode == 1) ? "NORMAL" : (currentMode == 2) ? "VISUAL" : (currentMode == 3) ? "INSERT" : "TARGET"
    normalTitle := "NORMAL MODE" . (currentMode == 1 ? "  << current" : "")
    visualTitle := "VISUAL MODE" . (currentMode == 2 ? "  << current" : "")
    insertTitle := "INSERT MODE" . (currentMode == 3 ? "  << current" : "")
    targetTitle := "TARGETING MODE" . (currentMode == 4 ? "  << current" : "")

    leftLines := [
        "Paper-VIM keybinds  |  current mode: " modeName,
        "Key labels below are defaults; paper-vim.ini may override them.",
        "",
        "COMMON",
        "  F1                      Toggle this help",
        "  CapsLock                Toggle Vim mode on/off",
        "  Ctrl+Q                  Suspend / resume (not in emergency mode)",
        "",
        normalTitle,
        "  v                       Enter Visual",
        "  m                       Enter Targeting (mouse grid)",
        "  i / a / A / o / O       Enter Insert (cursor / append / new line)",
        "  Esc                     Nothing (stays Normal)",
        "",
        "NAVIGATION",
        "  h j k l                 Left / down / up / right",
        "  w b e                   Next word / previous word / end of word",
        "  0 $                     Start / end of line",
        "  gg G                    Start / end of document",
        "  Ctrl+D / Ctrl+U         Page down / up",
        "",
        "EDITING",
        "  x                       Delete character",
        "  dd                      Delete line",
        "  c                       Change word (then Insert)",
        "  yy                      Yank line",
        "  p                       Paste",
        "  u / Ctrl+R              Undo / redo",
        "",
        "FIND",
        "  f<char> / t<char>       Find / till character forward",
        "  /                       Application find dialog",
        "",
        "COMMAND",
        "  :                       Open command (Normal only)",
        "  :w / :q / :wq           Save / close / save and close",
        "  Semicolon (;)           Swallowed in Normal and Visual"
    ]

    rightLines := [
        "WINDOW MANAGEMENT",
        "  n / Tab                 Next / previous window",
        "  1-9                     Jump to window number",
        "  Ctrl+H / Ctrl+L         Swap with left / right window",
        "  Ctrl+Shift+1/2/3        Width 25% / 50% / 75%",
        "  Ctrl+Shift+0            Full width (focus/peek)",
        "  Ctrl+Shift+C            Center active window",
        "  Ctrl+Shift+D            Remove active window from stack",
        "  Ctrl+F                  Toggle overlay mode",
        "  Ctrl+T                  Toggle taskbar",
        "  z                       Reflow layout",
        "",
        "VIRTUAL DESKTOPS",
        "  Ctrl+J / Ctrl+K         Previous / next desktop",
        "  Ctrl+1-5                Jump to desktop 1-5",
        "",
        targetTitle,
        "  m                       Enter Targeting (from Normal)",
        "  Cell keys: " TargetKeySummary() " (row by row)",
        "  Grid size: " TargetGridRows " x " TargetGridCols,
        "  one key                 Move pointer; repeat to refine",
        "  Space / r               Left / right click; reset grid",
        "  Backspace               Undo one grid level",
        "  Esc                     Exit to Normal",
        "",
        visualTitle,
        "  v / Esc                 Return to Normal",
        "  h j k l                 Extend selection by character",
        "  w b e                   Extend selection by word",
        "  0 $                     Extend to line start / end",
        "  gg / G                  Extend to document start / end",
        "  Ctrl+D / Ctrl+U         Extend by page",
        "  d / x                   Delete selection",
        "  c                       Change selection (delete, then Insert)",
        "  y                       Yank selection",
        "  p                       Paste over selection",
        "  i                       Collapse to selection start, then Insert",
        "",
        "Window management keys remain active (Normal section).",
        "Window-number keys 1-9 are Normal-only.",
        "",
        insertTitle,
        "  Esc                     Return to Normal",
        "",
        "Text input is passed through to the application.",
        "Enter Insert from Normal with i, a, A, o, O, or c."
    ]

    leftText := ""
    for line in leftLines
        leftText .= line "`n"
    rightText := ""
    for line in rightLines
        rightText .= line "`n"
    return [leftText, rightText]
}


; --- Targeting Mode ---------------------------------------------------------

; Find the full bounds of the monitor containing a screen point.
; @return Array [left, top, right, bottom]
GetMonitorBoundsAt(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &left, &top, &right, &bottom)
        if (x >= left && x < right && y >= top && y < bottom)
            return [left, top, right, bottom]
    }

    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    return [left, top, right, bottom]
}

; Build the virtual-key map from the configured cell keys. Keys are assigned
; row by row. Return false when the grid or key list is invalid.
BuildTargetKeyMap() {
    global TargetGridRows, TargetGridCols, TargetGridKeys, TargetKeyMap, TargetGridCellCount
    TargetKeyMap := Map()
    if (TargetGridRows < 1 || TargetGridCols < 1 || TargetGridCellCount < 2)
        return false
    if (TargetGridKeys.Length != TargetGridCellCount)
        return false

    for index, keyName in TargetGridKeys {
        vk := GetKeyVK(keyName)
        ; These keys own Targeting controls, not grid cells.
        if (!vk || vk = 0x1B || vk = 0x08 || vk = 0x20 || vk = 0x52 || vk = 0x70 || vk = 0x14)
            return false
        if (TargetKeyMap.Has(vk))
            return false
        TargetKeyMap[vk] := index
    }
    return true
}

; Return the configured keys in row-major order for the F1 help.
TargetKeySummary() {
    global TargetGridKeys
    summary := ""
    for keyName in TargetGridKeys
        summary .= (summary = "" ? "" : " ") keyName
    return summary
}

; Enter Targeting from Normal mode. The grid covers the monitor under the
; pointer, including the taskbar, so every screen point is reachable.
EnterTargeting() {
    global VimMode, TargetActive, TargetHelpPaused, TargetHistory
    global TargetMonL, TargetMonT, TargetMonR, TargetMonB
    global TargetL, TargetT, TargetR, TargetB

    if (VimMode != 1 || TargetActive)
        return

    if (!BuildTargetKeyMap()) {
        FlashMessage("TARGET CONFIG INVALID")
        return
    }

    MouseGetPos(&mouseX, &mouseY)
    bounds := GetMonitorBoundsAt(mouseX, mouseY)

    TargetMonL := bounds[1]
    TargetMonT := bounds[2]
    TargetMonR := bounds[3]
    TargetMonB := bounds[4]
    TargetL := TargetMonL
    TargetT := TargetMonT
    TargetR := TargetMonR
    TargetB := TargetMonB
    TargetHistory := []
    TargetHelpPaused := false
    TargetActive := true

    ShowTargetOverlay()
    StartTargetHook()
    UpdateHUD(4)
    RaiseOverlays()
}

; Stop the Targeting input hook.
StopTargetHook() {
    global TargetHook
    if (TargetHook) {
        try TargetHook.Stop()
        TargetHook := ""
    }
}

; Stop Targeting and leave Vim mode unchanged.
StopTargeting() {
    global TargetActive, TargetHelpPaused
    StopTargetHook()
    HideTargetOverlay()
    TargetActive := false
    TargetHelpPaused := false
}

; Leave Targeting and enter a Vim mode.
ExitTargeting(returnMode := 1) {
    StopTargeting()
    UpdateHUD(returnMode)
}

; Capture every key while Targeting is active. The InputHook blocks keys from
; reaching the active application, including keys that are not grid commands.
StartTargetHook() {
    global TargetHook, TargetHeldKeys
    if (TargetHook) {
        try TargetHook.Stop()
    }

    TargetHeldKeys := Map()
    TargetHook := InputHook("L0")
    TargetHook.KeyOpt("{All}", "N S I")
    TargetHook.OnKeyDown := TargetKeyDown
    TargetHook.OnKeyUp := TargetKeyUp
    TargetHook.Start()
}

; Handle one key from the Targeting InputHook.
TargetKeyDown(ih, vk, sc) {
    global VimMode, TargetActive, TargetHeldKeys, TargetKeyMap
    if (VimMode != 4 || !TargetActive)
        return

    ; One key selects one cell. Ignore auto-repeat until the key is released.
    if (TargetKeyMap.Has(vk)) {
        if (TargetHeldKeys.Has(vk))
            return
        TargetHeldKeys[vk] := true
        ApplyTargetCell(TargetKeyMap[vk])
        return
    }

    switch vk {
        case 0x1B: ExitTargeting(1)          ; Esc
        case 0x08: UndoTargetLevel()          ; Backspace
        case 0x70: PauseTargetingForHelp()    ; F1
        case 0x20: TargetClick("left")        ; Space
        case 0x52: TargetClick("right")       ; r
    }
}

; A released cell key can be used again for the next grid level.
TargetKeyUp(ih, vk, sc) {
    global TargetHeldKeys
    if (TargetHeldKeys.Has(vk))
        TargetHeldKeys.Delete(vk)
}

; Click at the current pointer, then reset the grid without moving it.
; @param button - "left" or "right"
TargetClick(button) {
    if (button = "left") {
        DllCall("mouse_event", "UInt", 0x0002, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0) ; LEFTDOWN
        DllCall("mouse_event", "UInt", 0x0004, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0) ; LEFTUP
    } else {
        DllCall("mouse_event", "UInt", 0x0008, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0) ; RIGHTDOWN
        DllCall("mouse_event", "UInt", 0x0010, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0) ; RIGHTUP
    }
    ResetTargetingGrid()
}

; Return the grid to the full target monitor. The pointer must not move.
ResetTargetingGrid() {
    global TargetMonL, TargetMonT, TargetMonR, TargetMonB
    global TargetL, TargetT, TargetR, TargetB
    global TargetHistory

    TargetL := TargetMonL
    TargetT := TargetMonT
    TargetR := TargetMonR
    TargetB := TargetMonB
    TargetHistory := []
    DrawTargetGrid()
}

; Move to the center of the selected cell (one-based, row-major) and make it
; the new active cell. The cell is split into the configured grid next.
ApplyTargetCell(index) {
    global TargetL, TargetT, TargetR, TargetB, TargetHistory, TargetMinCellSize
    global TargetGridRows, TargetGridCols

    width := TargetR - TargetL
    height := TargetB - TargetT
    row := Floor((index - 1) / TargetGridCols)
    col := Mod(index - 1, TargetGridCols)

    newL := TargetL + Floor(width * col / TargetGridCols)
    newR := (col + 1 = TargetGridCols) ? TargetR : TargetL + Floor(width * (col + 1) / TargetGridCols)
    newT := TargetT + Floor(height * row / TargetGridRows)
    newB := (row + 1 = TargetGridRows) ? TargetB : TargetT + Floor(height * (row + 1) / TargetGridRows)

    if ((newR - newL) < TargetMinCellSize || (newB - newT) < TargetMinCellSize) {
        FlashMessage("TARGET LIMIT")
        return
    }

    TargetHistory.Push(Map("l", TargetL, "t", TargetT, "r", TargetR, "b", TargetB))
    TargetL := newL
    TargetT := newT
    TargetR := newR
    TargetB := newB

    MouseMove(Round((TargetL + TargetR) / 2), Round((TargetT + TargetB) / 2), 0)
    DrawTargetGrid()
}

; Backspace: restore the previous active cell and move back to its center.
UndoTargetLevel() {
    global TargetL, TargetT, TargetR, TargetB, TargetHistory

    if (TargetHistory.Length == 0) {
        FlashMessage("NO TARGET TO UNDO")
        return
    }

    previous := TargetHistory.Pop()
    TargetL := previous["l"]
    TargetT := previous["t"]
    TargetR := previous["r"]
    TargetB := previous["b"]

    MouseMove(Round((TargetL + TargetR) / 2), Round((TargetT + TargetB) / 2), 0)
    DrawTargetGrid()
}

; Redraw the configured grid and the faint outlines of previous cells.
DrawTargetGrid() {
    global TargetMonL, TargetMonT, TargetMonR, TargetMonB
    global TargetL, TargetT, TargetR, TargetB, TargetHistory
    global TargetCellCtrls, TargetCellLabels, TargetAncestorCtrls
    global TargetGridRows, TargetGridCols, TargetGridKeys

    width := TargetR - TargetL
    height := TargetB - TargetT
    cells := []
    Loop TargetGridRows {
        rowIndex := A_Index
        Loop TargetGridCols {
            colIndex := A_Index
            left := TargetL + Floor(width * (colIndex - 1) / TargetGridCols)
            right := (colIndex = TargetGridCols) ? TargetR : TargetL + Floor(width * colIndex / TargetGridCols)
            top := TargetT + Floor(height * (rowIndex - 1) / TargetGridRows)
            bottom := (rowIndex = TargetGridRows) ? TargetB : TargetT + Floor(height * rowIndex / TargetGridRows)
            cells.Push([left, top, right, bottom])
        }
    }

    ; One configured key per cell, row by row. Size each label to its cell.
    for index, cell in cells {
        cellX := cell[1] - TargetMonL
        cellY := cell[2] - TargetMonT
        cellW := cell[3] - cell[1]
        cellH := cell[4] - cell[2]
        keyText := TargetGridKeys[index]
        keyLength := StrLen(keyText)
        thisLabelSize := Min(22, Max(7, Floor(Min(cellW, cellH) / 4)))
        if (keyLength > 1)
            thisLabelSize := Min(thisLabelSize, Max(7, Floor(cellW / (keyLength + 1))))
        thisLabelSize := Min(thisLabelSize, Max(7, cellH - 2))
        thisLabelHeight := Min(Max(24, thisLabelSize * 2 + 8), cellH)

        border := TargetCellCtrls[index]
        border.Move(cellX, cellY, cellW, cellH)
        border.Value := ""

        label := TargetCellLabels[index]
        label.Move(cellX, cellY + Floor((cellH - thisLabelHeight) / 2), cellW, thisLabelHeight)
        label.SetFont("s" thisLabelSize " cFFFFFF w700", "Consolas")
        label.Value := keyText
    }

    for ctrl in TargetAncestorCtrls
        ctrl.Visible := false

    index := 0
    for rect in TargetHistory {
        index += 1
        if (index > TargetAncestorCtrls.Length)
            break
        ctrl := TargetAncestorCtrls[index]
        ctrl.Move(rect["l"] - TargetMonL, rect["t"] - TargetMonT,
            rect["r"] - rect["l"], rect["b"] - rect["t"])
        ctrl.Visible := true
    }
}

; Show the three Targeting layers over the current monitor.
ShowTargetOverlay() {
    global TargetDimGui, TargetAncestorGui, TargetGridGui
    global TargetMonL, TargetMonT, TargetMonR, TargetMonB

    width := TargetMonR - TargetMonL
    height := TargetMonB - TargetMonT
    position := "NA x" TargetMonL " y" TargetMonT " w" width " h" height

    TargetDimGui.Show(position)
    TargetAncestorGui.Show(position)
    TargetGridGui.Show(position)
    DrawTargetGrid()
    RaiseOverlays()
}

; Hide all Targeting layers without destroying them.
HideTargetOverlay() {
    global TargetDimGui, TargetAncestorGui, TargetGridGui
    try TargetDimGui.Hide()
    try TargetAncestorGui.Hide()
    try TargetGridGui.Hide()
}

; Hide Targeting while help is open; Targeting resumes when help closes.
PauseTargetingForHelp() {
    global TargetActive, TargetHelpPaused

    if (!TargetActive) {
        ShowHelp()
        return
    }

    TargetHelpPaused := true
    StopTargetHook()
    HideTargetOverlay()
    ShowHelp()
}

; Restore Targeting after the help overlay closes.
ResumeTargetingAfterHelp() {
    global TargetActive, TargetHelpPaused

    if (!TargetActive || !TargetHelpPaused)
        return false

    TargetHelpPaused := false
    ShowTargetOverlay()
    StartTargetHook()
    UpdateHUD(4)
    RaiseOverlays()
    return true
}

; Toggle script suspension state
; When suspended, all window management actions are paused
; Resume by pressing Ctrl+Q again or CapsLock to enter Vim mode
ToggleSuspend() {
    global Suspended, SuspendedState, OverlayMode, WindowStack, EmergencyMode, DockShown

    ; Emergency mode is terminal for this session; restart to resume.
    if (EmergencyMode)
        return
    
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
        HideFocusBorder()
        
        ; Show suspended notification
        UpdateHUD(VimMode)
        
        ; Hide dock when suspended
        try DockGui.Hide()
        catch as err {
            ; Ignore if dock doesn't exist
        }
        DockShown := false
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
        UpdateFocusBorder()
    }
}

; Update dock display with current window stack
; Shows icons for windows around the active window with visual indicator
UpdateDock() {
    global WindowStack, DockGui
    global DockSlotPics, DockNumberCtrls, DockActiveUnderline, DockSlotHwnds, DockSlotCount
    global DockWidth, DockHeight, DockShown, DockShownX, DockShownY
    global DockIconSize, DockIconSpacing, DockLeftCount, DockRightCount, DockNumberHeight
    global DockMarginX, DockMarginY, WorkLeft, WorkTop, WorkWidth, DockPosY
    global ActiveIndicatorColor, DockInactiveNumberColor, DockNumberFontSize, FontFamily

    ; Keep the dock centered inside the usable area when the taskbar moves
    RefreshWorkArea()

    ; No managed windows: hide the dock
    if (WindowStack.Length == 0) {
        try DockGui.Hide()
        DockShown := false
        DockSlotHwnds := []
        loop DockSlotCount
            DockSlotHwnds.Push(0)
        return
    }

    ; Get active window
    activeIndex := GetStackIndex(WinActive("A"))

    ; Active window is not managed: keep the dock as it is
    if (activeIndex == 0)
        return

    ; Helper function to wrap index for circular navigation
    WrapIndex(idx) {
        while (idx < 1)
            idx += WindowStack.Length
        while (idx > WindowStack.Length)
            idx -= WindowStack.Length
        return idx
    }

    ; Build the five visible slot indices: left, active, right.
    indices := []
    loop DockLeftCount
        indices.Push(WrapIndex(activeIndex - DockLeftCount + A_Index - 1))
    indices.Push(activeIndex)
    loop DockRightCount
        indices.Push(WrapIndex(activeIndex + A_Index))

    xPos := 0
    for slot, idx in indices {
        hwnd := WindowStack[idx]

        ; Only replace the icon when this slot changes windows. This avoids
        ; extracting and reloading every icon on every reflow.
        if (DockSlotHwnds[slot] != hwnd) {
            DockSlotPics[slot].Value := GetWindowIconPath(hwnd)
            DockSlotHwnds[slot] := hwnd
        }
        DockSlotPics[slot].Move(xPos, 0, DockIconSize, DockIconSize)

        number := DockNumberCtrls[slot]
        number.Move(xPos, DockIconSize + 4, DockIconSize, DockNumberHeight)
        number.Value := idx
        if (idx == activeIndex) {
            number.SetFont(DockNumberFontSize " c" ActiveIndicatorColor, FontFamily)
            DockActiveUnderline.Move(xPos, DockIconSize + 2, DockIconSize, 2)
            DockActiveUnderline.Visible := true
        } else {
            number.SetFont(DockNumberFontSize " " DockInactiveNumberColor, FontFamily)
        }

        xPos += DockIconSize + DockIconSpacing
    }

    dockX := WorkLeft + (WorkWidth - DockWidth) / 2
    dockY := WorkTop + DockPosY
    if (!DockShown || dockX != DockShownX || dockY != DockShownY) {
        DockGui.Show("NA x" dockX " y" dockY " NoActivate")
        DockShown := true
        DockShownX := dockX
        DockShownY := dockY
    }

    ; Keep the dock above the focus-border bars. Showing the dock does not
    ; necessarily put it above an existing topmost border bar.
    RaiseOverlays()
}

; Get icon path or handle for a window
; @param hwnd - Window handle
; @return Icon path or handle string
GetWindowIconPath(hwnd) {
    if (!hwnd)
        return A_WinDir "\System32\shell32.dll"
    
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
    return A_WinDir "\System32\shell32.dll"  ; Default Windows icon
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
    ; Keep the focus border current even when layout changes are frozen.
    UpdateFocusBorder()

    ; Ignore all window events when layout is frozen
    if (LayoutFrozen())
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
        ; and dock follow the focused window. Re-add a visible window that
        ; was removed from the stack while it was hidden.
        ManageNewWindow(lParam, true)
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
ManageNewWindow(hwnd, requireVisible := false) {
    global WindowWidths
    if (!hwnd || LayoutFrozen())
        return
    
    if (!WinExist(hwnd))
        return

    ; Activation can be used to re-add a window that was hidden and then
    ; shown again. Creation events may fire before the window is visible, so
    ; the creation path leaves this check off.
    if (requireVisible && !IsStackWindow(hwnd))
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

; ==============================================================================
; FOCUS BORDER
; ==============================================================================

; Hide the focus border and clear its cached geometry.
HideFocusBorder() {
    global FocusBars, FocusBorderShown, FocusBorderTarget
    global FocusBorderX, FocusBorderY, FocusBorderW, FocusBorderH

    if (!IsSet(FocusBars))
        return

    if (FocusBorderShown) {
        for bar in FocusBars {
            try bar.Hide()
        }
    }
    FocusBorderShown := false
    FocusBorderTarget := 0
    FocusBorderX := 0
    FocusBorderY := 0
    FocusBorderW := 0
    FocusBorderH := 0
}

; Get the visible frame of a window in physical pixels. DWM's extended frame
; bounds exclude the invisible resize border that WinGetPos includes.
; @param hwnd - Window handle
; @return Array [left, top, right, bottom], or 0 when unavailable
GetFocusBorderRect(hwnd) {
    rect := Buffer(16, 0)
    hr := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rect, "UInt", 16, "UInt")
    if (hr = 0) {
        left := NumGet(rect, 0, "Int")
        top := NumGet(rect, 4, "Int")
        right := NumGet(rect, 8, "Int")
        bottom := NumGet(rect, 12, "Int")
        if (right > left && bottom > top)
            return [left, top, right, bottom]
    }

    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w > 0 && h > 0)
            return [x, y, x + w, y + h]
    } catch as err {
        ; Fall through to the unavailable result
    }
    return 0
}

; Check whether a window should get the focus border.
; @param hwnd - Candidate active window
; @return True when the window is managed and visible in tiled mode
IsFocusBorderCandidate(hwnd) {
    global FocusBorderEnabled, VimMode, Suspended, EmergencyMode, HelpVisible, OverlayMode

    if (!FocusBorderEnabled || VimMode == 0 || VimMode == 4 || Suspended || EmergencyMode || HelpVisible || OverlayMode)
        return false
    if (!hwnd || !WinExist("ahk_id " hwnd))
        return false
    if (GetStackIndex(hwnd) == 0)
        return false

    try {
        if (WinGetMinMax("ahk_id " hwnd) != 0)
            return false
    } catch as err {
        return false
    }
    return true
}

; Keep the HUD and dock above the border bars after the bars are raised.
RaiseOverlays() {
    global VimGui, DockGui
    flags := 0x0001 | 0x0002 | 0x0010   ; NOSIZE | NOMOVE | NOACTIVATE

    if (IsSet(VimGui) && VimGui.Hwnd)
        try DllCall("SetWindowPos", "Ptr", VimGui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
    if (IsSet(DockGui) && DockGui.Hwnd)
        try DllCall("SetWindowPos", "Ptr", DockGui.Hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", flags)
}

; Position the four border bars around the visible window frame.
; @param hwnd - Window handle being tracked
; @param left - Visible frame left edge
; @param top - Visible frame top edge
; @param right - Visible frame right edge
; @param bottom - Visible frame bottom edge
ShowFocusBorder(hwnd, left, top, right, bottom) {
    global FocusBars, FocusBorderThickness, FocusBorderShown
    global FocusBorderTarget, FocusBorderX, FocusBorderY, FocusBorderW, FocusBorderH

    if (FocusBars.Length < 4)
        return

    t := Max(1, FocusBorderThickness)
    x := left - t
    y := top - t
    r := right + t
    b := bottom + t
    w := r - x
    h := b - y
    if (w <= 2 * t || h <= 2 * t)
        return

    FocusBars[1].Show("NA x" x " y" y " w" w " h" t)
    FocusBars[2].Show("NA x" x " y" (b - t) " w" w " h" t)
    FocusBars[3].Show("NA x" x " y" (y + t) " w" t " h" (h - 2 * t))
    FocusBars[4].Show("NA x" (r - t) " y" (y + t) " w" t " h" (h - 2 * t))

    FocusBorderTarget := hwnd
    FocusBorderX := x
    FocusBorderY := y
    FocusBorderW := w
    FocusBorderH := h
    FocusBorderShown := true
    RaiseOverlays()
}

; Update the focus border from the current active window.
UpdateFocusBorder() {
    global FocusBorderEnabled, FocusBorderThickness, FocusBorderShown
    global FocusBorderTarget, FocusBorderX, FocusBorderY, FocusBorderW, FocusBorderH
    global WorkLeft, WorkTop, WorkWidth, WorkHeight

    if (!FocusBorderEnabled) {
        HideFocusBorder()
        return
    }

    hwnd := WinActive("A")
    if (!IsFocusBorderCandidate(hwnd)) {
        HideFocusBorder()
        return
    }

    rect := GetFocusBorderRect(hwnd)
    if (!rect) {
        HideFocusBorder()
        return
    }

    ; A normal window that covers the whole work area is effectively
    ; fullscreen; the border would be clipped at the screen edges.
    if (rect[1] <= WorkLeft && rect[2] <= WorkTop
        && rect[3] >= WorkLeft + WorkWidth && rect[4] >= WorkTop + WorkHeight) {
        HideFocusBorder()
        return
    }

    t := Max(1, FocusBorderThickness)
    x := rect[1] - t
    y := rect[2] - t
    w := (rect[3] + t) - x
    h := (rect[4] + t) - y
    if (FocusBorderShown && hwnd == FocusBorderTarget
        && x == FocusBorderX && y == FocusBorderY
        && w == FocusBorderW && h == FocusBorderH)
        return

    ShowFocusBorder(hwnd, rect[1], rect[2], rect[3], rect[4])
}

; Restore a maximized or minimized window without changing keyboard focus.
; ShowWindow's SW_SHOWNOACTIVATE (4) clears the maximized state without the
; activation that WinRestore performs on background windows.
RestoreWindowNoActivate(hwnd) {
    if (!hwnd || !WinExist("ahk_id " hwnd))
        return
    try DllCall("ShowWindow", "Ptr", hwnd, "Int", 4)
}

; Reflow window positions in the stack
; Repositions all windows based on current layout mode and active window
; @param centerActive - Center the active window instead of only scrolling
;                       enough to keep it on screen
ReflowStack(centerActive := false) {
    global WindowWidths, ViewOffset

    ; Don't reflow when layout is frozen
    if (LayoutFrozen())
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
        UpdateFocusBorder()
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
            if (!IsStackWindow(WindowStack[idx])) {
                if (WindowStack[idx] == activeHwnd)
                    activeRemoved := true
                ForgetWindowWidth(WindowStack[idx])
                WindowStack.RemoveAt(idx)
            }
        }
        catch as err {
            ; Error checking window, remove it
            if (WindowStack[idx] == activeHwnd)
                activeRemoved := true
            ForgetWindowWidth(WindowStack[idx])
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
        UpdateFocusBorder()
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
                UpdateFocusBorder()
                return
            }
        } else {
            ; The active window is unmanaged (Start menu, dialog, popup):
            ; keep the current layout instead of stealing focus
            UpdateDock()
            Critical "Off"
            UpdateFocusBorder()
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
                RestoreWindowNoActivate(hwnd)
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
            ; they are restored. A maximized window must be restored first:
            ; moving it while maximized leaves it in a maximized state at a
            ; tiled rectangle, which also hides the focus border.
            try {
                minMax := WinGetMinMax(hwnd)
                if (minMax = -1)
                    continue
                if (minMax = 1)
                    RestoreWindowNoActivate(hwnd)
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
    UpdateFocusBorder()
}

; ==============================================================================
; NAVIGATION LOGIC
; ==============================================================================

; Switch to a specific virtual desktop
; @param Target - Desktop number to switch to (1-10)
GoToDesktop(Target) {
    global CurrentDesktop, InitializedDesktops
    
    ; Don't switch desktops when layout is frozen
    if (LayoutFrozen())
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

; True when a window still exists and is visible on the desktop.
; Minimized windows count as visible; hidden windows do not.
; @param hwnd - Window handle
; @return True when the window belongs in the visible stack
IsStackWindow(hwnd) {
    if (!hwnd || !WinExist("ahk_id " hwnd))
        return false
    try {
        return (WinGetStyle("ahk_id " hwnd) & 0x10000000) != 0
    } catch as err {
        return false
    }
}

; Remove hidden or destroyed windows from the stack. A window can be managed
; while visible and then hidden without being destroyed (for example, a
; command palette). Leaving it in the stack reserves a layout slot and makes
; the window row look wrong.
PruneWindowStack() {
    global WindowStack
    if (LayoutFrozen())
        return

    changed := false
    n := WindowStack.Length
    loop n {
        idx := n - A_Index + 1
        if (!IsStackWindow(WindowStack[idx])) {
            ForgetWindowWidth(WindowStack[idx])
            WindowStack.RemoveAt(idx)
            changed := true
        }
    }

    if (changed)
        DeferredReflow()
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

; Remove a remembered width if one exists. Map.Delete throws when the key is
; absent, so check first.
; @param hwnd - Window handle
ForgetWindowWidth(hwnd) {
    global WindowWidths
    if (WindowWidths.Has(hwnd))
        WindowWidths.Delete(hwnd)
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
    ; Don't cycle when layout is frozen
    if (LayoutFrozen())
        return

    ; Remove hidden windows before choosing a target. Otherwise WinActivate can
    ; land on a hidden command-palette or tray window and leave no visible focus.
    PruneWindowStack()

    if (WindowStack.Length <= 1)
        return

    activeIndex := GetStackIndex(WinActive("A"))

    if (activeIndex == 0)
        return

    newIndex := activeIndex
    loop WindowStack.Length - 1 {
        newIndex += direction
        if (newIndex < 1)
            newIndex := WindowStack.Length
        else if (newIndex > WindowStack.Length)
            newIndex := 1
        if (IsStackWindow(WindowStack[newIndex]))
            break
    }

    if (newIndex == activeIndex)
        return

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
    ; Don't switch windows when layout is frozen
    if (LayoutFrozen())
        return
    
    if (WindowStack.Length == 0 || index < 1 || index > WindowStack.Length) {
        FlashMessage("WINDOW " . index . " NOT FOUND")
        return
    }

    target := WindowStack[index]
    if (!IsStackWindow(target)) {
        FlashMessage("WINDOW " . index . " NOT AVAILABLE")
        return
    }

    try {
        WinActivate(target)
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
    global WindowWidths, FullWidthRatio
    ; Don't initialize when layout is frozen
    if (LayoutFrozen())
        return
    
    windowList := WinGetList()
    for hwnd in windowList {
        try {
            ; Use the same filtering logic as ManageNewWindow
            if (!ShouldManageWindow(hwnd) || !IsStackWindow(hwnd))
                continue
            
            title := WinGetTitle(hwnd)
            if (title != "" && !InStr(title, "Program Manager")) {
                alreadyExists := false
                for item in WindowStack
                    if (item == hwnd)
                        alreadyExists := true
                if (!alreadyExists) {
                    WindowStack.Push(hwnd)
                    ; Existing windows are adopted without going through
                    ; ManageNewWindow, so seed their default width here.
                    if (!WindowWidths.Has(hwnd))
                        WindowWidths[hwnd] := FullWidthRatio
                }
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
    ; Don't toggle taskbar when layout is frozen
    if (LayoutFrozen())
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
; ERROR RECOVERY
; ==============================================================================

; Move every managed window to one reachable, overlapping rectangle.
; This runs after an unhandled error so a broken layout cannot strand windows
; off-screen or behind each other in an unreachable horizontal row.
EmergencyLayout() {
    global WindowStack, WorkLeft, WorkTop, WorkWidth, WorkHeight
    global VimGui, DockGui, HelpGui, HelpVisible, DockShown
    global EmergencyMargin, EmergencyMinWidth, EmergencyMinHeight
    global EmergencyMaxWidth, EmergencyMaxHeight

    ; Remove the Targeting input hook and overlay before moving windows.
    try StopTargeting()

    ; Hide the always-on-top HUD, dock, and help overlay so they cannot cover
    ; the windows.
    if (IsSet(VimGui))
        try VimGui.Hide()
    if (IsSet(DockGui))
        try DockGui.Hide()
    DockShown := false
    if (IsSet(HelpGui))
        try HelpGui.Hide()
    try HideFocusBorder()
    HelpVisible := false

    availableWidth := WorkWidth
    availableHeight := WorkHeight
    if (availableWidth <= 0)
        availableWidth := A_ScreenWidth
    if (availableHeight <= 0)
        availableHeight := A_ScreenHeight

    safeWidth := Min(EmergencyMaxWidth, Max(EmergencyMinWidth, availableWidth - 2 * EmergencyMargin))
    safeHeight := Min(EmergencyMaxHeight, Max(EmergencyMinHeight, availableHeight - 2 * EmergencyMargin))
    safeX := WorkLeft + EmergencyMargin
    safeY := WorkTop + EmergencyMargin

    try {
        for hwnd in WindowStack {
            try {
                if (!WinExist("ahk_id " hwnd))
                    continue
                if (WinGetMinMax("ahk_id " hwnd) != 0)
                    WinRestore("ahk_id " hwnd)
                WinMove(safeX, safeY, safeWidth, safeHeight, "ahk_id " hwnd)
            }
        }
    } catch as err {
        ; A broken stack must not make the error handler throw.
    }
}

; Last-resort handler for unhandled errors. Move the windows before AHK shows
; its normal error dialog or exits.
EmergencyOnError(err, mode) {
    global EmergencyMode, EmergencyInProgress, Suspended

    if (EmergencyInProgress)
        return false

    EmergencyInProgress := true
    EmergencyMode := true
    Suspended := true   ; stop reflows and shell-hook layout changes
    Critical "Off"      ; an error may have left Critical On
    try {
        EmergencyLayout()
    } catch as layoutErr {
        ; Keep EmergencyMode set; a later error can retry the layout.
    }
    EmergencyInProgress := false

    ; Let AutoHotkey show its normal error dialog after the windows are safe.
    return false
}

; ==============================================================================
; CLEANUP
; ==============================================================================

; Cleanup function called on script exit
OnExit(CleanupAndExit)

CleanupAndExit(ExitReason, ExitCode) {
    global EmergencyMode

    ; Release the Targeting keyboard hook and overlays before exiting.
    try StopTargetHook()
    try TargetDimGui.Destroy()
    try TargetAncestorGui.Destroy()
    try TargetGridGui.Destroy()

    ; Retry the safe layout if the script is exiting because of an error.
    if (EmergencyMode || ExitReason = "Error")
        try EmergencyLayout()

    ; Hide GUIs before exit
    try VimGui.Destroy()
    catch as err {
        ; Already destroyed
    }
    
    try DockGui.Destroy()
    catch as err {
        ; Already destroyed
    }

    try HelpGui.Destroy()
    catch as err {
        ; Already destroyed
    }

    if (IsSet(FocusBars)) {
        for bar in FocusBars {
            try bar.Destroy()
            catch as err {
                ; Already destroyed
            }
        }
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

; Track the active window for the focus border. The shell hook handles
; activation immediately; this timer catches moves, resizes, and restores.
SetTimer(UpdateFocusBorder, FocusBorderUpdateInterval)

; Remove windows that were hidden without being destroyed. Without this, a
; hidden window keeps a layout slot and pushes later windows off-screen.
SetTimer(PruneWindowStack, 500)

; Toggle Vim mode with CapsLock
CapsLock:: {
    ; F1 and Esc close help; CapsLock must not change the mode while it is open.
    if (HelpVisible)
        return

    ; Targeting is a temporary mode; CapsLock leaves it and turns Vim off.
    if (VimMode == 4) {
        StopTargeting()
        UpdateHUD(0)
        return
    }

    ; If suspended, resume by calling ToggleSuspend and enter Normal mode
    if (Suspended) {
        if (EmergencyMode)
            return       ; emergency mode is terminal; restart the script
        ToggleSuspend()  ; This will restore window positions
        UpdateHUD(1)     ; Enter Normal mode
    } else {
        ; Normal toggle behavior
        UpdateHUD(VimMode == 0 ? 1 : 0)
    }
}

#HotIf (VimMode == 1 || VimMode == 2) && !Suspended && !HelpVisible
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

#HotIf VimMode > 0 && !HelpVisible
; --- Layout Control ---
^q:: ToggleSuspend()  ; Toggle script suspension
#HotIf

#HotIf (VimMode == 1 || VimMode == 2) && !Suspended && !HelpVisible
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
            ForgetWindowWidth(hwnd)
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
    if (KeyMatches("Text", "GotoStart", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout) {
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

; --- Escape (Normal, Visual, Insert, Targeting) ---
; Esc stays hot while help is open so it can close the overlay; the other
; mode keys are disabled by !HelpVisible in their own contexts.
#HotIf (VimMode >= 1 && VimMode <= 4) && !Suspended
Esc:: {
    if (HelpVisible) {
        DismissHelp()
        return
    }
    if (VimMode == 4) {
        ExitTargeting(1)
        return
    }
    if (VimMode != 1)
        UpdateHUD(1)
    ; Normal mode: swallow Esc; Off mode: the hotkey is inactive
}
#HotIf

; --- Normal Vim Mode Commands ---
#HotIf VimMode == 1 && !Suspended && !HelpVisible
; Targeting
m:: EnterTargeting()

; Find Commands
f:: ExecuteFind(false)
t:: ExecuteFind(true)
/:: {
    Send "^f"
    UpdateHUD(0)
}

; Delete Commands
d:: {
    if (KeyMatches("Normal", "DeleteLine", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout)
        Send "{Home}+{End}{BackSpace}{Delete}" ; 'dd'
}

; Change Commands
c:: {
    if (KeyMatches("Normal", "Change", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout) {
        Send "{Home}+{End}{BackSpace}" ; 'cc'
        UpdateHUD(3)
    } else {
        Send "^{Delete}" ; 'cw'
        UpdateHUD(3)
    }
}

; Yank Commands
y:: {
    if (KeyMatches("Normal", "Yank", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout) {
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
#HotIf VimMode == 2 && !Suspended && !HelpVisible
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

; --- Keybind Help ---
#HotIf (VimMode >= 1 && VimMode <= 4) && !Suspended && !EmergencyMode
F1:: ToggleHelp()
#HotIf

#HotIf


; Execute a configured key action. Unchanged keys still use the original hotkey
; definitions; changed keys are bound to this dispatcher.
RunKeyAction(context, action, *) {
    global VimMode, Suspended, EmergencyMode, HelpVisible, OverlayMode
    global WindowStack, WindowWidths, CurrentDesktop, InitializedDesktops
    global DesktopSwitchDelay, FullWidthRatio, DblClickTimeout

    switch (context "." action) {
        case "Global.ToggleVim":
        {
            if (HelpVisible)
                return
            if (VimMode == 4) {
                StopTargeting()
                UpdateHUD(0)
                return
            }
            if (Suspended) {
                if (EmergencyMode)
                    return
                ToggleSuspend()
                UpdateHUD(1)
            } else {
                UpdateHUD(VimMode == 0 ? 1 : 0)
            }
        }

        case "Suspend.Suspend":
            ToggleSuspend()

        case "Desktop.PrevDesktop":
        {
            Send("^#{Left}")
            CurrentDesktop -= 1
            if (CurrentDesktop < 1)
                CurrentDesktop := 1
            if (!InitializedDesktops.Has(CurrentDesktop))
                SetTimer(() => InitializeDesktop(CurrentDesktop), -DesktopSwitchDelay)
        }
        case "Desktop.NextDesktop":
        {
            Send("^#{Right}")
            CurrentDesktop += 1
            if (CurrentDesktop > 10)
                CurrentDesktop := 10
            if (!InitializedDesktops.Has(CurrentDesktop))
                SetTimer(() => InitializeDesktop(CurrentDesktop), -DesktopSwitchDelay)
        }
        case "Desktop.Desktop1": GoToDesktop(1)
        case "Desktop.Desktop2": GoToDesktop(2)
        case "Desktop.Desktop3": GoToDesktop(3)
        case "Desktop.Desktop4": GoToDesktop(4)
        case "Desktop.Desktop5": GoToDesktop(5)

        case "Manage.Overlay":
        {
            OverlayMode := !OverlayMode
            FlashMessage(OverlayMode ? "OVERLAY MODE" : "TILING MODE")
            ReflowStack()
        }
        case "Manage.RemoveWindow":
        {
            if (WindowStack.Length == 0)
                return
            activeHwnd := WinActive("A")
            if (!activeHwnd)
                return
            for i, hwnd in WindowStack {
                if (hwnd == activeHwnd) {
                    ForgetWindowWidth(hwnd)
                    WindowStack.RemoveAt(i)
                    FlashMessage("WINDOW REMOVED")
                    break
                }
            }
            ReflowStack()
        }
        case "Manage.ToggleTaskbar": ToggleTaskbar()
        case "Manage.SwapLeft": SwapActive(-1)
        case "Manage.SwapRight": SwapActive(1)
        case "Manage.NextWindow": CycleStack(1)
        case "Manage.PrevWindow": CycleStack(-1)
        case "Manage.Reflow": ReflowStack()
        case "Manage.Width25": SetWindowWidthPreset(0.25, "25%")
        case "Manage.Width50": SetWindowWidthPreset(0.50, "50%")
        case "Manage.Width75": SetWindowWidthPreset(0.75, "75%")
        case "Manage.WidthFull": SetWindowWidthPreset(FullWidthRatio, "FULL")
        case "Manage.Center": CenterActiveWindow()

        case "Text.Left": Send(VimMode == 2 ? "+{Left}" : "{Left}")
        case "Text.Down": Send(VimMode == 2 ? "+{Down}" : "{Down}")
        case "Text.Up": Send(VimMode == 2 ? "+{Up}" : "{Up}")
        case "Text.Right": Send(VimMode == 2 ? "+{Right}" : "{Right}")
        case "Text.WordNext": Send(VimMode == 2 ? "^+{Right}" : "^{Right}")
        case "Text.WordPrev": Send(VimMode == 2 ? "^+{Left}" : "^{Left}")
        case "Text.WordEnd": Send(VimMode == 2 ? "^+{Right}+{Left}" : "^{Right}{Left}")
        case "Text.LineStart": Send(VimMode == 2 ? "+{Home}" : "{Home}")
        case "Text.LineEnd": Send(VimMode == 2 ? "+{End}" : "{End}")
        case "Text.PageDown": Send(VimMode == 2 ? "+{PgDn}" : "{PgDn}")
        case "Text.PageUp": Send(VimMode == 2 ? "+{PgUp}" : "{PgUp}")
        case "Text.VisualMode": UpdateHUD(VimMode == 1 ? 2 : 1)
        case "Text.Insert":
        {
            if (VimMode == 2)
                Send "{Left}"
            UpdateHUD(3)
        }
        case "Text.GotoStart":
        {
            if (KeyMatches("Text", "GotoStart", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout) {
                if (VimMode == 2)
                    Send "+^{Home}"
                else
                    Send "^{Home}"
            }
        }
        case "Text.GotoEnd":
        {
            if (VimMode == 2)
                Send "+^{End}"
            else
                Send "^{End}"
        }

        case "Normal.Target": EnterTargeting()
        case "Normal.Find": ExecuteFind(false)
        case "Normal.Till": ExecuteFind(true)
        case "Normal.AppFind":
        {
            Send "^f"
            UpdateHUD(0)
        }
        case "Normal.DeleteLine":
        {
            if (KeyMatches("Normal", "DeleteLine", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout)
                Send "{Home}+{End}{BackSpace}{Delete}"
        }
        case "Normal.Change":
        {
            if (KeyMatches("Normal", "Change", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout) {
                Send "{Home}+{End}{BackSpace}"
                UpdateHUD(3)
            } else {
                Send "^{Delete}"
                UpdateHUD(3)
            }
        }
        case "Normal.Yank":
        {
            if (KeyMatches("Normal", "Yank", A_PriorHotkey) and A_TimeSincePriorHotkey < DblClickTimeout) {
                Send "{Home}+{End}^c"
                FlashMessage("COPIED LINE")
            } else {
                Send "^c"
            }
        }
        case "Normal.Paste": Send "^v"
        case "Normal.Undo": Send "^z"
        case "Normal.Redo": Send "^y"
        case "Normal.DeleteChar": Send "{Delete}"
        case "Normal.OpenBelow":
        {
            Send("{End}{Enter}")
            UpdateHUD(3)
        }
        case "Normal.OpenAbove":
        {
            Send("{Home}{Enter}{Up}")
            UpdateHUD(3)
        }
        case "Normal.Append":
        {
            Send("{Right}")
            UpdateHUD(3)
        }
        case "Normal.AppendEnd":
        {
            Send("{End}")
            UpdateHUD(3)
        }
        case "Normal.Semicolon": return
        case "Normal.Command":
        {
            targetHwnd := WinActive("A")
            prevVimMode := VimMode
            UpdateHUD(0)
            Result := InputBox("Command: w (save), q (quit), wq (save & quit)", "Vim Command", "h80 w300")
            if (Result.Result = "OK") {
                val := Trim(StrLower(Result.Value))
                if (SubStr(val, 1, 1) == ":")
                    val := Trim(SubStr(val, 2))
                if (val = "w" || val = "q" || val = "wq") {
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
            if (VimMode == 0 && prevVimMode != 0)
                UpdateHUD(prevVimMode)
        }
        case "Normal.Window1": GoToWindowByIndex(1)
        case "Normal.Window2": GoToWindowByIndex(2)
        case "Normal.Window3": GoToWindowByIndex(3)
        case "Normal.Window4": GoToWindowByIndex(4)
        case "Normal.Window5": GoToWindowByIndex(5)
        case "Normal.Window6": GoToWindowByIndex(6)
        case "Normal.Window7": GoToWindowByIndex(7)
        case "Normal.Window8": GoToWindowByIndex(8)
        case "Normal.Window9": GoToWindowByIndex(9)

        case "Visual.Delete":
        {
            Send("{BackSpace}")
            UpdateHUD(1)
        }
        case "Visual.Change":
        {
            Send("{BackSpace}")
            UpdateHUD(3)
        }
        case "Visual.Yank":
        {
            Send("^c")
            UpdateHUD(1)
            FlashMessage("YANKED")
        }
        case "Visual.DeleteChar":
        {
            Send("{Delete}")
            UpdateHUD(1)
        }
        case "Visual.Paste":
        {
            Send("^v")
            UpdateHUD(1)
        }
        case "Visual.UnsupportedA", "Visual.UnsupportedShiftA", "Visual.UnsupportedO", "Visual.UnsupportedShiftO", "Visual.UnsupportedSemicolon", "Visual.UnsupportedColon", "Visual.UnsupportedLess", "Visual.UnsupportedGreater", "Visual.UnsupportedShiftV", "Visual.UnsupportedCtrlV", "Visual.UnsupportedFind", "Visual.UnsupportedTill", "Visual.UnsupportedAppFind":
            return

        case "Escape.Escape":
        {
            if (HelpVisible) {
                DismissHelp()
                return
            }
            if (VimMode == 4) {
                ExitTargeting(1)
                return
            }
            if (VimMode != 1)
                UpdateHUD(1)
        }

        case "Help.Help": ToggleHelp()
    }
}

; Apply paper-vim.ini key overrides after all default hotkeys exist.
RegisterKeymap()