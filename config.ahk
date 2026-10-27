; ==============================================================================
; Paper-VIM defaults and configuration loader
; ==============================================================================
; Settings are deliberately kept out of paper-vim.ahk. This file provides the
; defaults; an optional paper-vim.ini beside paper-vim.ahk overrides them.
; Runtime state (window handles, maps, timers, GUI controls) stays in the main
; script and is never configurable.

#Requires AutoHotkey v2.0

; --- Settings defaults ---
global FullWidthRatio := 1.0
global FocusWidthRatio := 0.85
global Gap := 8
global BarHeight := 60
global EmergencyMargin := 40
global EmergencyMinWidth := 400
global EmergencyMinHeight := 300
global EmergencyMaxWidth := 1200
global EmergencyMaxHeight := 800
global TaskbarMode := "auto"
global TaskbarSize := 0
global HUDBackgroundColor := "121212"
global DockBackgroundColor := "1a1a1a"
global NormalModeColor := "c00FF00"
global VisualModeColor := "cFF0000"
global InsertModeColor := "c00BFFF"
global TargetingModeColor := "cFF00FF"
global FlashMsgColor := "cFFFF00"
global SuspendedModeColor := "cFF8800"
global ActiveIndicatorColor := "00FF00"
global DockInactiveNumberColor := "c888888"
global FocusBorderEnabled := true
global FocusBorderColor := "00A8FF"
global FocusBorderThickness := 3
global FocusBorderUpdateInterval := 50
global FontFamily := "Segoe UI"
global HUDFontSize := "s16"
global HUDFontWeight := "w800"
global DockNumberFontSize := "s8"
global DockIconSize := 32
global DockIconSpacing := 8
global DockLeftCount := 2
global DockRightCount := 2
global DockMarginX := 12
global DockMarginY := 8
global DockPosY := 10
global DockNumberHeight := 16
global HUDMarginRight := 20
global HUDPosY := 40
global HUDWidth := 220
global FlashDuration := 800
global DblClickTimeout := 400
global DebounceDelay := 50
global DesktopSwitchDelay := 200
global DockUpdateDelay := 100
global TooltipDuration := 1000
global TargetMinCellSize := 8
global TargetGridRows := 2
global TargetGridCols := 2
global TargetGridKeys := ["h", "j", "k", "l"]

; --- Default keymap ---
; Action names are stable; sections map to hotkey contexts.
global DefaultKeymap := Map(
    "Global", Map(
        "ToggleVim", "CapsLock"
    ),
    "Suspend", Map(
        "Suspend", "^q"
    ),
    "Desktop", Map(
        "PrevDesktop", "^j",
        "NextDesktop", "^k",
        "Desktop1", "^1",
        "Desktop2", "^2",
        "Desktop3", "^3",
        "Desktop4", "^4",
        "Desktop5", "^5"
    ),
    "Manage", Map(
        "Overlay", "^f",
        "RemoveWindow", "^+d",
        "ToggleTaskbar", "^t",
        "SwapLeft", "^h",
        "SwapRight", "^l",
        "NextWindow", "n",
        "PrevWindow", "Tab",
        "Reflow", "z",
        "Width25", "^+1",
        "Width50", "^+2",
        "Width75", "^+3",
        "WidthFull", "^+0",
        "Center", "^+c"
    ),
    "Text", Map(
        "Left", "h",
        "Down", "j",
        "Up", "k",
        "Right", "l",
        "WordNext", "w",
        "WordPrev", "b",
        "WordEnd", "e",
        "LineStart", "0",
        "LineEnd", "+4",
        "PageDown", "^d",
        "PageUp", "^u",
        "VisualMode", "v",
        "Insert", "i",
        "GotoStart", "g",
        "GotoEnd", "+g"
    ),
    "Normal", Map(
        "Target", "m",
        "Find", "f",
        "Till", "t",
        "AppFind", "/",
        "DeleteLine", "d",
        "Change", "c",
        "Yank", "y",
        "Paste", "p",
        "Undo", "u",
        "Redo", "^r",
        "DeleteChar", "x",
        "OpenBelow", "o",
        "OpenAbove", "+o",
        "Append", "a",
        "AppendEnd", "+a",
        "Semicolon", "SC027",
        "Command", "+SC027",
        "Window1", "1",
        "Window2", "2",
        "Window3", "3",
        "Window4", "4",
        "Window5", "5",
        "Window6", "6",
        "Window7", "7",
        "Window8", "8",
        "Window9", "9"
    ),
    "Visual", Map(
        "Delete", "d",
        "Change", "c",
        "Yank", "y",
        "DeleteChar", "x",
        "Paste", "p",
        "UnsupportedA", "a",
        "UnsupportedShiftA", "+a",
        "UnsupportedO", "o",
        "UnsupportedShiftO", "+o",
        "UnsupportedSemicolon", "SC027",
        "UnsupportedColon", "+SC027",
        "UnsupportedLess", "+SC033",
        "UnsupportedGreater", "+SC034",
        "UnsupportedShiftV", "+v",
        "UnsupportedCtrlV", "^v",
        "UnsupportedFind", "f",
        "UnsupportedTill", "t",
        "UnsupportedAppFind", "/"
    ),
    "Escape", Map(
        "Escape", "Esc"
    ),
    "Help", Map(
        "Help", "F1"
    )
)

global KeyContexts := Map(
    "Global", "",
    "Suspend", "VimMode > 0 && !HelpVisible",
    "Desktop", "(VimMode == 1 || VimMode == 2) && !Suspended && !HelpVisible",
    "Manage", "(VimMode == 1 || VimMode == 2) && !Suspended && !HelpVisible",
    "Text", "(VimMode == 1 || VimMode == 2) && !Suspended && !HelpVisible",
    "Normal", "VimMode == 1 && !Suspended && !HelpVisible",
    "Visual", "VimMode == 2 && !Suspended && !HelpVisible",
    "Escape", "(VimMode >= 1 && VimMode <= 4) && !Suspended",
    "Help", "(VimMode >= 1 && VimMode <= 4) && !Suspended && !EmergencyMode"
)

global SettingsSchema := Map(
    "Layout", Map(
        "FullWidthRatio", "float",
        "FocusWidthRatio", "float",
        "Gap", "int",
        "BarHeight", "int",
        "EmergencyMargin", "int",
        "EmergencyMinWidth", "int",
        "EmergencyMinHeight", "int",
        "EmergencyMaxWidth", "int",
        "EmergencyMaxHeight", "int",
        "TaskbarMode", "string",
        "TaskbarSize", "int"
    ),
    "Colors", Map(
        "HUDBackgroundColor", "string",
        "DockBackgroundColor", "string",
        "NormalModeColor", "string",
        "VisualModeColor", "string",
        "InsertModeColor", "string",
        "TargetingModeColor", "string",
        "FlashMsgColor", "string",
        "SuspendedModeColor", "string",
        "ActiveIndicatorColor", "string",
        "DockInactiveNumberColor", "string"
    ),
    "FocusBorder", Map(
        "FocusBorderEnabled", "bool",
        "FocusBorderColor", "string",
        "FocusBorderThickness", "int",
        "FocusBorderUpdateInterval", "int"
    ),
    "Fonts", Map(
        "FontFamily", "string",
        "HUDFontSize", "string",
        "HUDFontWeight", "string",
        "DockNumberFontSize", "string"
    ),
    "Dock", Map(
        "DockIconSize", "int",
        "DockIconSpacing", "int",
        "DockLeftCount", "int",
        "DockRightCount", "int",
        "DockMarginX", "int",
        "DockMarginY", "int",
        "DockPosY", "int",
        "DockNumberHeight", "int"
    ),
    "HUD", Map(
        "HUDMarginRight", "int",
        "HUDPosY", "int",
        "HUDWidth", "int",
        "FlashDuration", "int"
    ),
    "Timing", Map(
        "DblClickTimeout", "int",
        "DebounceDelay", "int",
        "DesktopSwitchDelay", "int",
        "DockUpdateDelay", "int",
        "TooltipDuration", "int"
    ),
    "Targeting", Map(
        "TargetMinCellSize", "int",
        "TargetGridRows", "int",
        "TargetGridCols", "int",
        "TargetGridKeys", "keys"
    )
)

global Keymap := Map()
global ConfigWarnings := []

; Copy defaults into the live keymap before applying user overrides.
LoadConfig() {
    global Keymap, DefaultKeymap, SettingsSchema, ConfigWarnings
    global TargetGridKeys

    ConfigWarnings := []
    Keymap := Map()
    for context, actions in DefaultKeymap
        Keymap[context] := actions.Clone()

    path := A_ScriptDir "\paper-vim.ini"
    if (!FileExist(path))
        return

    sectionNames := IniRead(path)
    for section in StrSplit(sectionNames, "`n", "`r") {
        if (section = "")
            continue
        if (SettingsSchema.Has(section))
            continue
        if (SubStr(section, 1, 5) = "Keys." && Keymap.Has(SubStr(section, 6)))
            continue
        ConfigWarnings.Push("Unknown section [" section "]")
    }

    for section, schema in SettingsSchema {
        sectionText := IniRead(path, section, , "")
        if (sectionText = "")
            continue
        Loop Parse, sectionText, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue
            eq := InStr(line, "=")
            if (!eq) {
                ConfigWarnings.Push("Ignored line without '=' in [" section "]: " line)
                continue
            }
            key := Trim(SubStr(line, 1, eq - 1))
            value := UnquoteConfig(Trim(SubStr(line, eq + 1)))
            if (!schema.Has(key)) {
                ConfigWarnings.Push("Unknown setting [" section "] " key)
                continue
            }
            parsed := ParseConfigValue(section "." key, schema[key], value)
            ApplySetting(section, key, parsed)
        }
    }

    for context, actions in Keymap {
        section := "Keys." context
        sectionText := IniRead(path, section, , "")
        if (sectionText = "")
            continue
        Loop Parse, sectionText, "`n", "`r" {
            line := Trim(A_LoopField)
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue
            eq := InStr(line, "=")
            if (!eq) {
                ConfigWarnings.Push("Ignored line without '=' in [" section "]: " line)
                continue
            }
            action := Trim(SubStr(line, 1, eq - 1))
            key := UnquoteConfig(Trim(SubStr(line, eq + 1)))
            if (!actions.Has(action)) {
                ConfigWarnings.Push("Unknown key action [" section "] " action)
                continue
            }
            actions[action] := key
        }
    }

    ValidateKeymap()
    ShowConfigWarnings()
}

; Strip one matching pair of surrounding quotes.
UnquoteConfig(value) {
    if (StrLen(value) < 2)
        return value
    first := SubStr(value, 1, 1)
    last := SubStr(value, -1)
    if ((first = Chr(34) && last = Chr(34)) || (first = Chr(39) && last = Chr(39)))
        return SubStr(value, 2, StrLen(value) - 2)
    return value
}

ParseConfigValue(name, type, value) {
    if (type = "string")
        return value
    if (type = "keys") {
        keys := []
        for part in StrSplit(value, ",", " ") {
            part := Trim(part)
            if (part = "")
                continue
            keys.Push(part)
        }
        if (keys.Length = 0)
            ConfigFail(name " must contain at least one key")
        return keys
    }
    if (type = "bool") {
        if (value = "true" || value = "1")
            return true
        if (value = "false" || value = "0")
            return false
        ConfigFail(name " must be true/false or 1/0")
    }
    if (type = "int") {
        if (!RegExMatch(value, "^-?\d+$"))
            ConfigFail(name " must be an integer")
        return Integer(value)
    }
    if (type = "float") {
        if (!RegExMatch(value, "^-?\d+(\.\d+)?$"))
            ConfigFail(name " must be a number")
        return Float(value)
    }
    return value
}

ApplySetting(section, key, value) {
    global FullWidthRatio, FocusWidthRatio, Gap, BarHeight, EmergencyMargin, EmergencyMinWidth, EmergencyMinHeight, EmergencyMaxWidth, EmergencyMaxHeight, TaskbarMode, TaskbarSize, HUDBackgroundColor, DockBackgroundColor, NormalModeColor, VisualModeColor, InsertModeColor, TargetingModeColor, FlashMsgColor, SuspendedModeColor, ActiveIndicatorColor, DockInactiveNumberColor, FocusBorderEnabled, FocusBorderColor, FocusBorderThickness, FocusBorderUpdateInterval, FontFamily, HUDFontSize, HUDFontWeight, DockNumberFontSize, DockIconSize, DockIconSpacing, DockLeftCount, DockRightCount, DockMarginX, DockMarginY, DockPosY, DockNumberHeight, HUDMarginRight, HUDPosY, HUDWidth, FlashDuration, DblClickTimeout, DebounceDelay, DesktopSwitchDelay, DockUpdateDelay, TooltipDuration, TargetMinCellSize, TargetGridRows, TargetGridCols, TargetGridKeys
    switch (section "." key) {
        case "Layout.FullWidthRatio": FullWidthRatio := value
        case "Layout.FocusWidthRatio": FocusWidthRatio := value
        case "Layout.Gap": Gap := value
        case "Layout.BarHeight": BarHeight := value
        case "Layout.EmergencyMargin": EmergencyMargin := value
        case "Layout.EmergencyMinWidth": EmergencyMinWidth := value
        case "Layout.EmergencyMinHeight": EmergencyMinHeight := value
        case "Layout.EmergencyMaxWidth": EmergencyMaxWidth := value
        case "Layout.EmergencyMaxHeight": EmergencyMaxHeight := value
        case "Layout.TaskbarMode": TaskbarMode := value
        case "Layout.TaskbarSize": TaskbarSize := value
        case "Colors.HUDBackgroundColor": HUDBackgroundColor := value
        case "Colors.DockBackgroundColor": DockBackgroundColor := value
        case "Colors.NormalModeColor": NormalModeColor := value
        case "Colors.VisualModeColor": VisualModeColor := value
        case "Colors.InsertModeColor": InsertModeColor := value
        case "Colors.TargetingModeColor": TargetingModeColor := value
        case "Colors.FlashMsgColor": FlashMsgColor := value
        case "Colors.SuspendedModeColor": SuspendedModeColor := value
        case "Colors.ActiveIndicatorColor": ActiveIndicatorColor := value
        case "Colors.DockInactiveNumberColor": DockInactiveNumberColor := value
        case "FocusBorder.FocusBorderEnabled": FocusBorderEnabled := value
        case "FocusBorder.FocusBorderColor": FocusBorderColor := value
        case "FocusBorder.FocusBorderThickness": FocusBorderThickness := value
        case "FocusBorder.FocusBorderUpdateInterval": FocusBorderUpdateInterval := value
        case "Fonts.FontFamily": FontFamily := value
        case "Fonts.HUDFontSize": HUDFontSize := value
        case "Fonts.HUDFontWeight": HUDFontWeight := value
        case "Fonts.DockNumberFontSize": DockNumberFontSize := value
        case "Dock.DockIconSize": DockIconSize := value
        case "Dock.DockIconSpacing": DockIconSpacing := value
        case "Dock.DockLeftCount": DockLeftCount := value
        case "Dock.DockRightCount": DockRightCount := value
        case "Dock.DockMarginX": DockMarginX := value
        case "Dock.DockMarginY": DockMarginY := value
        case "Dock.DockPosY": DockPosY := value
        case "Dock.DockNumberHeight": DockNumberHeight := value
        case "HUD.HUDMarginRight": HUDMarginRight := value
        case "HUD.HUDPosY": HUDPosY := value
        case "HUD.HUDWidth": HUDWidth := value
        case "HUD.FlashDuration": FlashDuration := value
        case "Timing.DblClickTimeout": DblClickTimeout := value
        case "Timing.DebounceDelay": DebounceDelay := value
        case "Timing.DesktopSwitchDelay": DesktopSwitchDelay := value
        case "Timing.DockUpdateDelay": DockUpdateDelay := value
        case "Timing.TooltipDuration": TooltipDuration := value
        case "Targeting.TargetMinCellSize": TargetMinCellSize := value
        case "Targeting.TargetGridRows": TargetGridRows := value
        case "Targeting.TargetGridCols": TargetGridCols := value
        case "Targeting.TargetGridKeys": TargetGridKeys := value
    }
}

ValidateKeymap() {
    global Keymap, ConfigWarnings
    for context, actions in Keymap {
        seen := Map()
        for action, key in actions {
            key := Trim(key)
            if (key = "")
                ConfigFail("Empty key for " context "." action)
            normalized := StrLower(key)
            if (seen.Has(normalized))
                ConfigFail("Duplicate key '" key "' in " context ": " seen[normalized] " and " action)
            seen[normalized] := action
        }
    }

    ; Keys from contexts that can be active together must also be unique.
    groups := Map(
        "Normal", ["Global", "Suspend", "Desktop", "Manage", "Text", "Normal", "Escape", "Help"],
        "Visual", ["Global", "Suspend", "Desktop", "Manage", "Text", "Visual", "Escape", "Help"]
    )
    for groupName, contexts in groups {
        seen := Map()
        for context in contexts {
            for action, key in Keymap[context] {
                normalized := StrLower(Trim(key))
                owner := context "." action
                if (seen.Has(normalized))
                    ConfigFail("Key '" key "' conflicts in " groupName " mode: " seen[normalized] " and " owner)
                seen[normalized] := owner
            }
        }
    }
}

ShowConfigWarnings() {
    global ConfigWarnings
    if (ConfigWarnings.Length = 0)
        return
    message := "Paper-VIM configuration warnings:`n`n"
    for warning in ConfigWarnings
        message .= "- " warning "`n"
    MsgBox(message, "Paper-VIM Configuration", "Icon!")
}

ConfigFail(message) {
    MsgBox(message, "Paper-VIM Configuration", "Icon!")
    ExitApp(1)
}

KeyMatches(context, action, hotkeyName) {
    global Keymap, DefaultKeymap
    return hotkeyName = Keymap[context][action] || hotkeyName = DefaultKeymap[context][action]
}

; Rebind only the keys that differ from the defaults. The original hotkey
; definitions remain active for unchanged keys; changed keys use RunKeyAction.
RegisterKeymap() {
    global Keymap, DefaultKeymap, KeyContexts
    for context, actions in Keymap {
        expression := KeyContexts[context]
        if (expression = "")
            HotIf()
        else
            HotIf(expression)

        ; Disable every changed default before registering any replacement.
        for action, key in actions {
            defaultKey := DefaultKeymap[context][action]
            if (key != defaultKey) {
                try Hotkey(defaultKey, "Off")
                catch as err
                    ConfigFail("Cannot disable " context "." action " (" defaultKey "): " err.Message)
            }
        }

        for action, key in actions {
            defaultKey := DefaultKeymap[context][action]
            if (key = defaultKey)
                continue
            try Hotkey(key, RunKeyAction.Bind(context, action))
            catch as err
                ConfigFail("Invalid key '" key "' for " context "." action ": " err.Message)
        }
    }
    HotIf()
}

; Load overrides before the GUI is created. RegisterKeymap is called after the
; default hotkey definitions near the bottom of paper-vim.ahk.
LoadConfig()
