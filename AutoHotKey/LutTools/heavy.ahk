; made by /u/lutcikaur
; GUI's in use : 1, 2, 3, 4, 5, 6, 7, 8, 9
#NoEnv
#SingleInstance force
#MaxHotkeysPerInterval 500

FileEncoding , UTF-8
SendMode Input
SetTitleMatchMode, 3
macroVersion := 168

If (A_AhkVersion <= "1.1.23")
{
	msgbox, You need AutoHotkey v1.1.23 or later to run this script. `n`nPlease go to http://ahkscript.org/download and download a recent version.
	ExitApp
}

SetWorkingDir %A_MyDocuments%\AutoHotKey\LutTools

elog := A_Now . " " . A_AhkVersion . " " . macroVersion "`n"
FileAppend, %elog% , error.txt, UTF-16

UrlDownloadToFile, http://lutbot.com/ahk/version.html, version.html
	if ErrorLevel
			GuiControl,1:, guiErr, ED06

FileRead, newestVersion, version.html

if ( macroVersion < newestVersion ) {
	UrlDownloadToFile, http://lutbot.com/ahk/changelog.txt, changelog.txt
			if ErrorLevel
					GuiControl,1:, guiErr, ED08
	Gui, 4:Add, Text,, Update Available.`nYoure running version %macroVersion%. The newest is version %newestVersion%`nProceed with update? It will only take a moment, and the script will automatically restart.
	FileRead, changelog, changelog.txt
	Gui, 4:Add, Edit, w600 h200 +ReadOnly, %changelog% 
	Gui, 4:Add, Button, section default grunUpdate, Update
	Gui, 4:Add, Button, ys gshowPatreon, Support with Patreon
	Gui, 4:Add, Button, ys x540 gdontUpdate, Skip Update
	Gui, 4:Show,, LutTools Patch Notes
}

full_command_line := DllCall("GetCommandLine", "str")

if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
{
    try
    {
        if A_IsCompiled
            Run *RunAs "%A_ScriptFullPath%" /restart
        else
            Run *RunAs "%A_AhkPath%" /restart "%A_ScriptFullPath%"
    }
    ExitApp
}

RunWait, verify.ahk

GetTable := DllCall("GetProcAddress", Ptr, DllCall("LoadLibrary", Str, "Iphlpapi.dll", "Ptr"), Astr, "GetExtendedTcpTable", "Ptr")
SetEntry := DllCall("GetProcAddress", Ptr, DllCall("LoadLibrary", Str, "Iphlpapi.dll", "Ptr"), Astr, "SetTcpEntry", "Ptr")
EnumProcesses := DllCall("GetProcAddress", Ptr, DllCall("LoadLibrary", Str, "Psapi.dll", "Ptr"), Astr, "EnumProcesses", "Ptr")
preloadPsapi := DllCall("LoadLibrary", "Str", "Psapi.dll", "Ptr")
OpenProcessToken := DllCall("GetProcAddress", Ptr, DllCall("LoadLibrary", Str, "Advapi32.dll", "Ptr"), Astr, "OpenProcessToken", "Ptr")
LookupPrivilegeValue := DllCall("GetProcAddress", Ptr, DllCall("LoadLibrary", Str, "Advapi32.dll", "Ptr"), Astr, "LookupPrivilegeValue", "Ptr")
AdjustTokenPrivileges := DllCall("GetProcAddress", Ptr, DllCall("LoadLibrary", Str, "Advapi32.dll", "Ptr"), Astr, "AdjustTokenPrivileges", "Ptr")

readFromFile() ;first run

;timers
sleepTime := 500
updateTrackingTimer := 5000 ; 5 seconds
baseUpdateTrackingTimer := 300000 ; 5 minute
verifyLogoutTimer := 0
baseVerifyLogoutTimer := 60000 ; 1 minute
processWarningFound := 0
overlayTimer := 0
baseOverlayTimer := sleepTime
updateTrackingTimerActive := true
overlayTimerActive := true
preloadCportsTimer := 0
basePreloadCportsTimer := 60000 ; 1 minute
preloadCportsCall := "cports.exe /stext TEMP"
calcd = 0
person_dict := {}

;Ranking Overlay
Gui, 1:+ToolWindow
Gui, 1:Color, %colorBG%
Gui, 1:Font, %colorText% s14, Lucida Sans Unicode
Gui, 1:Add, Text, x3 y4 w150 vguiRank, Rank: N/A

Gui, 1:Font, s8
Gui, 1:Add, Text, x160 y2 vguiErr, Waiting
Gui, 1:Add, Text, x160 y17 vguiSettings, Settings:%hotkeyOptions%
Gui, 1:Font, s14

Gui, 1:Show, x0 y0 w225 h47, poeGUI
Gui, 1:-Caption +AlwaysOnTop +Disabled +E0x20 +LastFound
Winset,TransColor, 0xFFFFFF
Winset,Transparent, 190

;Menu
Gui, 2:Add, Text,x5 h20, CharacterName:
Gui, 2:Add, Text,x5 h20, AccountName:
Gui, 2:Add, Text,x5 h20, CharacterLeague:
Gui, 2:Add, Text,x5 h20 c2959a5, Steam Client:
Gui, 2:Add, Text,x5 h20, Alert Whisper:
Gui, 2:Add, Text,x5 h20, Overlay X Offset:
Gui, 2:Add, Text,x5 h20, Overlay Y Offset:
Gui, 2:Add, Text,x5 h20, Background Color :
Gui, 2:Add, Text,x5 h20, Text Color :
Gui, 2:Add, Text,x5 h20, Beta version:
Gui, 2:Add, Text,x5 h20, Ctrl+Scroll:
Gui, 2:Add, Text,x5 h20, Diablo2 logout?:
Gui, 2:Add, Text,x5 h20,

Gui, 2:Add, Text,x5 h20 , Logout:
Gui, 2:Add, Text,x5 h20, ForceLogout:
Gui, 2:Add, Text,x5 h20, /Oos:
Gui, 2:Add, Text,x5 h20, /Remaining :
Gui, 2:Add, Text,x5 h20, /whois :
Gui, 2:Add, Text,x5 h20, /kick :
Gui, 2:Add, Text,x5 h20, Travel to Hideout :
Gui, 2:Add, Text,x5 h20, Invite Player :
Gui, 2:Add, Text,x5 h20, Toggle Overlay Size:
Gui, 2:Add, Text,x5 h20, Price Check :
Gui, 2:Add, Text,x5 h20, Cooldown X Offset:
Gui, 2:Add, Text,x5 h20, Cooldown Y Offset:

Gui, 2:Add, Edit, vguiChar ym w150 h20, %charName%
Gui, 2:Add, Edit, vguiAcc w150 h20, %accName%
Gui, 2:Add, DropDownList, vguiLeague w150, %leagueString%
Gui, 2:Add, Checkbox, vguiSteam w150 h20 Checked%steam%
Gui, 2:Add, Checkbox, vguipasteWatch h20 Checked%pasteWatch%
Gui, 2:Add, Edit, vguiXOffset w150 h20, %xOffset%
Gui, 2:Add, Edit, vguiYOffset w150 h20, %yOffset%
Gui, 2:Add, Edit, w150 h20 vguicolorBG , %colorBG%
Gui, 2:Add, Edit, w150 h20 vguicolorText , %colorText%
Gui, 2:Add, Checkbox, vguibeta h20 Checked%beta%
Gui, 2:Add, Checkbox, vguiscroll h20 Checked%scroll%
Gui, 2:Add, Checkbox, vguidiablo2 h20 Checked%diablo2%

Gui, 2:Add, Text, w150 h20, Hotkey:
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyLogout , %hotkeyLogout%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeySuperLogout , %hotkeySuperLogout%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyOos , %hotkeyOos%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyRemaining , %hotkeyRemaining%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyWhois , %hotkeyWhois%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyKick , %hotkeyKick%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyHideout , %hotkeyHideout%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyInvite , %hotkeyInvite%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyToggleOverlay , %hotkeyToggleOverlay%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyPriceCheck , %hotkeyPriceCheck%
Gui, 2:Add, Edit, vguiWAXOffset w150 h20, %waxOffset%
Gui, 2:Add, Edit, vguiWAYOffset w150 h20, %wayOffset%

;Hotkeys

Gui, 2:Add, Text, ym, Whisper Hotkeys:
Gui, 2:Add, Hotkey, vguihotkeywm1 w100 h20 , %hotkeywm1%
Gui, 2:Add, Hotkey, vguihotkeywm2 w100 h20 , %hotkeywm2%
Gui, 2:Add, Hotkey, vguihotkeywm3 w100 h20 , %hotkeywm3%
Gui, 2:Add, Hotkey, vguihotkeywm4 w100 h20 , %hotkeywm4%
Gui, 2:Add, Hotkey, vguihotkeywm5 w100 h20 , %hotkeywm5%

Gui, 2:Add, Text,, General Hotkeys:
Gui, 2:Add, Hotkey, vguihotkeypm1 w100 h20 , %hotkeypm1%
Gui, 2:Add, Hotkey, vguihotkeypm2 w100 h20 , %hotkeypm2%
Gui, 2:Add, Hotkey, vguihotkeypm3 w100 h20 , %hotkeypm3%
Gui, 2:Add, Hotkey, vguihotkeypm4 w100 h20 , %hotkeypm4%
Gui, 2:Add, Hotkey, vguihotkeypm5 w100 h20 , %hotkeypm5%
Gui, 2:Add, Hotkey, vguihotkeypm6 w100 h20 , %hotkeypm6%
Gui, 2:Add, Hotkey, vguihotkeypm7 w100 h20 , %hotkeypm7%
Gui, 2:Add, Hotkey, vguihotkeypm8 w100 h20 , %hotkeypm8%
Gui, 2:Add, Hotkey, vguihotkeypm9 w100 h20 , %hotkeypm9%
Gui, 2:Add, Hotkey, vguihotkeypm10 w100 h20 , %hotkeypm10%

Gui, 2:Add, Text,, Ability Key
Gui, 2:Add, Hotkey, vguihotkeyCooldown1 w100 h20 , %hotkeyCooldown1%
Gui, 2:Add, Hotkey, vguihotkeyCooldown2 w100 h20 , %hotkeyCooldown2%
Gui, 2:Add, Hotkey, vguihotkeyCooldown3 w100 h20 , %hotkeyCooldown3%
Gui, 2:Add, Hotkey, vguihotkeyCooldown4 w100 h20 , %hotkeyCooldown4%
Gui, 2:Add, Hotkey, vguihotkeyCooldown5 w100 h20 , %hotkeyCooldown5%
Gui, 2:Add, Hotkey, vguihotkeyCooldown6 w100 h20 , %hotkeyCooldown6%
Gui, 2:Add, Hotkey, vguihotkeyCooldown7 w100 h20 , %hotkeyCooldown7%
Gui, 2:Add, Button, gshowTradeMacro, PoE Trade Macro

;Commands

Gui, 2:Add, Text, ym w200, Whisper Message Text:
Gui, 2:Add, Edit, vguiwm1 w200 h20, %wm1%
Gui, 2:Add, Edit, vguiwm2 w200 h20, %wm2%
Gui, 2:Add, Edit, vguiwm3 w200 h20, %wm3%
Gui, 2:Add, Edit, vguiwm4 w200 h20, %wm4%
Gui, 2:Add, Edit, vguiwm5 w200 h20, %wm5%

Gui, 2:Add, Text, w200, General Command Outputs:
Gui, 2:Add, Edit, vguipm1 w200 h20, %pm1%
Gui, 2:Add, Edit, vguipm2 w200 h20, %pm2%
Gui, 2:Add, Edit, vguipm3 w200 h20, %pm3%
Gui, 2:Add, Edit, vguipm4 w200 h20, %pm4%
Gui, 2:Add, Edit, vguipm5 w200 h20, %pm5%
Gui, 2:Add, Edit, vguipm6 w200 h20, %pm6%
Gui, 2:Add, Edit, vguipm7 w200 h20, %pm7%
Gui, 2:Add, Edit, vguipm8 w200 h20, %pm8%
Gui, 2:Add, Edit, vguipm9 w200 h20, %pm9%
Gui, 2:Add, Edit, vguipm10 w200 h20, %pm10%

Gui, 2:Add, Text, section w90, Duration (ms):
Gui, 2:Add, Edit, vguiduration1 w90 h20, %duration1%
Gui, 2:Add, Edit, vguiduration2 w90 h20, %duration2%
Gui, 2:Add, Edit, vguiduration3 w90 h20, %duration3%
Gui, 2:Add, Edit, vguiduration4 w90 h20, %duration4%
Gui, 2:Add, Edit, vguiduration5 w90 h20, %duration5%
Gui, 2:Add, Edit, vguiduration6 w90 h20, %duration6%
Gui, 2:Add, Edit, vguiduration7 w90 h20, %duration7%
Gui, 2:Add, Button, gshowDiscord, Discord

Gui, 2:Add, Text, ys w90, Color:
Gui, 2:Add, Edit, vguicooldownColor1 w90 h20, %cooldownColor1%
Gui, 2:Add, Edit, vguicooldownColor2 w90 h20, %cooldownColor2%
Gui, 2:Add, Edit, vguicooldownColor3 w90 h20, %cooldownColor3%
Gui, 2:Add, Edit, vguicooldownColor4 w90 h20, %cooldownColor4%
Gui, 2:Add, Edit, vguicooldownColor5 w90 h20, %cooldownColor5%
Gui, 2:Add, Edit, vguicooldownColor6 w90 h20, %cooldownColor6%
Gui, 2:Add, Edit, vguicooldownColor7 w90 h20, %cooldownColor7%
Gui, 2:Add, Button, gswitchLite, Switch To Lite

;Bottom Section (ew)

Gui, 2:Add, Text, xm section, Options (This GUI) :
Gui, 2:Add, Hotkey,ys vguihotkeyOptions, %hotkeyOptions%

Gui, 2:Add, Button, ys gshowFAQ, Visit FAQ
Gui, 2:Add, Button, ys gchangelogGui, View Changelog
Gui, 2:Add, Button, ys gshowPatreon, Support with Patreon
Gui, 2:Add, Button, ys default gupdateHotkeys, Save

;Process Warning Overlay
Gui, 6:+ToolWindow
Gui, 6:Color, %colorBG%
Gui, 6:Font, %colorText% s8
Gui, 6:Add, Text,x7 y7, Your settings are incorrect. Please have marks in the correct boxes if you are running on steam
Gui, 6:Add, Text,x7 y25 vbackupErrorFound, Your settings are incorrect. Please have marks in the correct boxes if you are running on steam
Gui, 6:Add, Text,x7 y43 vbackupErrorExpected, Your settings are incorrect. Please have marks in the correct boxes if you are running on steam
Gui, 6:-Caption +AlwaysOnTop +Disabled +E0x20 +LastFound
Winset,TransColor, 0xFFFFFF
Winset,Transparent, 190

;Cooldown Overlay
Gui, 8:+ToolWindow
Gui, 8:Color, %colorBG%
Gui, 8:Show, x0 y0 w219 h41 NA
Gui, 8:Add, Progress, x0 y0 w225 h10 c%cooldownColor1% BackGround%colorBG% vProg1
Gui, 8:Add, Progress, x0 y10 w225 h10 c%cooldownColor2% BackGround%colorBG% vProg2
Gui, 8:Add, Progress, x0 y20 w225 h10 c%cooldownColor3% BackGround%colorBG% vProg3
Gui, 8:Add, Progress, x0 y30 w225 h10 c%cooldownColor4% BackGround%colorBG% vProg4
Gui, 8:Add, Progress, x0 y40 w225 h10 c%cooldownColor5% BackGround%colorBG% vProg5
Gui, 8:Add, Progress, x0 y50 w225 h10 c%cooldownColor6% BackGround%colorBG% vProg6
Gui, 8:Add, Progress, x0 y60 w225 h10 c%cooldownColor7% BackGround%colorBG% vProg7
Gui, 8:-Caption +AlwaysOnTop +Disabled +E0x20 +LastFound
WinSet, TransColor, 0x%colorBG% 225

;Price Check Overlay
Gui, 7:+ToolWindow
Gui, 7:Font, s8
Gui, 7:Add, Text,x7 y7 vpriceLineOne, This is an Item Name This is an Item Name
Gui, 7:Add, Text,x7 y25 vpriceLineTwo, This is an Item Name This is an Item Name
Gui, 7:Add, Text,x7 y43 vpriceLineThree, This is an Item Name This is an Item Name
Gui, 7:-Caption +AlwaysOnTop +Disabled +E0x20 +LastFound
Winset,TransColor, 0xFFFFFF
Winset,Transparent, 190

Gui, 9:+ToolWindow
Gui, 9:Font, s8
Gui, 9:Margin, 5, 5
Gui, 9:Add, Text, w600 h80 vwhisperOutput,
Gui, 9:-Caption +AlwaysOnTop +Disabled +E0x20 +LastFound
Winset,TransColor, 0xFFFFFF

Menu, Tray, Tip, LutTools v%macroVersion%
Menu, Tray, NoStandard
Menu, Tray, Add, LutTools Settings, optionsCommand
Menu, Tray, Add, Switch to Lite Version, switchLite
Menu, Tray, Add, Become a Patreon, showPatreon
Menu, Tray, Add, Join Discord, showDiscord
Menu, Tray, Add, Visit FAQ, showFAQ
Menu, Tray, Add, View Changelog, changelogGui

Menu, Tray, Default, LutTools Settings
Menu, Tray, Add ; Separator
Menu, Tray, Standard

; some initializers. Put these together later.
toggle--
toggleOverlay()
readFromFile() ;second run. im so sorry.

;start the main loop. Gotta be last
loopTimers()


//functions

whisperCheck() {
whisperCheckCommand:
	global person_dict, pasteWatch
	StringLeft, prefix, clipboard, 1
	if (pasteWatch && prefix == "@") {
		clip := StrReplace(clipboard, "`n", "")
		split := StrSplit(clip, A_Space)
		person := split[1]
		person_array := person_dict[person]
		if !person_array {
			person_dict[person] := [clip]
			person_dict[person] = person_array.Push(clip)
		} else {
			in := 0
			output := ""
			Loop % person_array.Length() {
				if (person_array[A_Index] == clip) {
					in = 1
				}
				if (A_Index == 1) {
					output := person_array[A_Index]
				} else {
					output .= "`n" . person_array[A_Index]
				}
			}
			if (in == 0) {
				person_array.Push(clip)
				if (person_dict[person].Length() >= 7) {
					person_array.RemoveAt(0)
				}
				person_dict[person] = person_array
			}
			GuiControl,9:, whisperOutput, %output%
			WinGetActiveStats,name,width,height,x,y
			height *= 0.77
			Gui,9:Show, x100 y%height% NA
			SetTimer, hideWhisperWindow, 4500
		}
	}
	return
}

hideWhisperWindow(){
	hideWhisperWindow:
	Gui,9:Hide
	return
}

priceCheck() {
priceCheckCommand:
	global league
	BlockInput On
	clipboard = 
	Send ^c
	BlockInput Off
	ClipWait, 1
	temp := clipboard

	first := ""
	second := ""
	third := ""
	fourth := ""
	fifth := ""
	secondToLast := ""
	last := ""

	continue := false
	cycle := false
	
	Loop, parse, clipboard, `n, `r
	{ 
		continue := true
	    If A_Index = 1 
	    {
	    	first = %A_LoopField%
	    } 
	    Else If (A_Index = 2) 
	    {
	    	second = %A_LoopField%
	    	StringReplace, second, second, <<set:MS>><<set:M>><<set:S>>,, All
	    }
	    Else If (A_Index = 3) 
	    {
	    	third = %A_LoopField%
	    } 
	    Else If (A_Index = 4) 
	    {
	    	fourth = %A_LoopField%
	    }
	    Else If (A_Index = 5) 
	    {
	    	fifth = %A_LoopField%
	    } 
	    Else 
	    {
	    	secondToLast = %last%
	    	last = %A_LoopField%
	    }
	}

	IfInString, first, Rare
	{
		continue := false
		cycle := true
	}
	IfInString, first, Gem
	{
		continue := false
	}
	Else IfInString, first, Magic
	{
		continue := false
		cycle := true
	}
	IfInString, first, Unique
	{
		cycle := false
	}
	Else IfInString, fifth, Map
	{
		continue := true
		second := third
	}
	Else IfInString, fourth, Map
	{
		continue := true
		if cycle 
		{
			Loop, parse, second, %A_Space%
			{
			    If A_Index = 1 
			    {
			    	second := ""
			    }
			    Else 
			    {
			    	IfEqual, A_LoopField, Map
			    	{
			    		second .= A_LoopField
			    		break
			    	}
			    	second .= A_LoopField . " "
			    }
			}
		}
	}

	IfInString, secondToLast, Relic Unique
	{
		continue := true
		second .= "_Relic"
		first = Rarity: Relic
	}
	
	if continue 
	{
		url := "http://api.lutbot.com:8080/price/v1/"
		MouseGetPos, newX,newY
		StringReplace, newSecond, second, %A_Space%, _, All
		url .= league . "/" . newSecond . ""
		SetTimer, getPrice, 1000
		FileDelete, price.html
		run "Lib\QDL.ahk" %url% "price.html"
		return
		getPrice:
		IfExist, price.html
		{
			SetTimer, getPrice, off
			FileRead, priceData, price.html
			GuiControl,7:, priceLineOne, %second%
			GuiControl,7:, priceLineTwo, %first%
			GuiControl,7:, priceLineThree, %priceData%
			Gui,7:Show, x%newX% y%newY% NA
			SetTimer, hidePriceWindow, 3500
		} else {
			return
		}
		return
	} else {
		MouseGetPos, newX,newY
		GuiControl,7:, priceLineOne, Price-Check does not work on
		GuiControl,7:, priceLineTwo, non-specific items
		GuiControl,7:, priceLineThree, 
		Gui,7:Show, x%newX% y%newY% NA
		SetTimer, hidePriceWindow, 3500
	}
	return
}

hidePriceWindow(){
	hidePriceWindow:
	Gui,7:Hide
	return
}

;legacy now
getVersion(){
	global macroVersion
	url := "http://api.lutbot.com:8080/version/v1/"
	SetTimer, getVer, 1000
	FileDelete, version.html
	run "Lib\QDL.ahk" %url% "version.html"
	return
	getVer:
	IfExist, version.html
	{
		SetTimer, getVer, off
		FileRead, newestVersion, version.html
		
		if ( macroVersion < newestVersion ) {
			UrlDownloadToFile, http://lutbot.com/ahk/changelog.txt, changelog.txt
					if ErrorLevel
							error("ED08")
			Gui, 4:Add, Text,, Update Available.`nYoure running version %macroVersion%. The newest is version %newestVersion%`nThis is either a bug fix, or I added something new.`nCan I download it for you? It will only take a moment, and the script will automatically restart with the latest version.
			FileRead, changelog, changelog.txt
			Gui, 4:Add, Edit, w600 h200 +ReadOnly, %changelog% 
			Gui, 4:Add, Button, section default grunUpdate, Update
			Gui, 4:Add, Button, ys gdontUpdate, Skip Update
			Gui, 4:Show,, LutTools Patch Notes
		}
	} else {
		return
	}
	return
}

getLeagueListing() {
	SetTimer, loadLeague, 1000
	run "Lib\QDL.ahk" "http://api.lutbot.com:8080/ladders/v1/" "leagues.json"
	return
}

loadLeague:
	parseLeagues()
return

parseLeagues() {
	global league, leagueString
	IfExist, leagues.json 
	{
		SetTimer, loadLeague, off
		FileRead, leagues, leagues.json

		regexLocation := 1
		arrayCount := 0
		newStart := 0

		ls := ""

		While regexLocation
		{
			regexLocation := RegExMatch( leagues, """([A-z()0-9_]+)""", regexString, regexLocation+1)
			if regexLocation != 0
			{
				ls .= "|" . regexString1
				leagueString := ls
			}
		}
		GuiControl,2:, guiLeague, "|"
		GuiControl,2:, guiLeague, %leagueString%
		GuiControl,2:ChooseString, guiLeague, %league%
	}
	return
}

superLogoutCommand(){
superLogoutCommand:
	Critical
	logoutCommand()
	return
}

logoutCommand(){
global executable, backupExe
logoutCommand:
	Critical
	succ := logout(executable)
	if (succ == 0) && backupExe != "" {
		newSucc := logout(backupExe)
		error("ED12",executable,backupExe)
		if (newSucc == 0) {
			error("ED13")
		}
	}
	return
}

cportsLogout(){
	global cportsCommand, lastlogout
	Critical
	start := A_TickCount
	ltime := lastlogout + 1000
	if ( ltime < A_TickCount ) {
		RunWait, %cportsCommand%
		lastlogout := A_TickCount
	}
	Sleep 10
	error("nb:" . A_TickCount - start)
	return
}

logout(executable){
	global  GetTable, SetEntry, EnumProcesses, OpenProcessToken, LookupPrivilegeValue, AdjustTokenPrivileges, loadedPsapi
	Critical
	start := A_TickCount

	poePID := Object()
	s := 4096
	Process, Exist 
	h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", ErrorLevel, "Ptr")

	DllCall(OpenProcessToken, "Ptr", h, "UInt", 32, "PtrP", t)
	VarSetCapacity(ti, 16, 0)
	NumPut(1, ti, 0, "UInt")

	DllCall(LookupPrivilegeValue, "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
	NumPut(luid, ti, 4, "Int64")
	NumPut(2, ti, 12, "UInt")

	r := DllCall(AdjustTokenPrivileges, "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
	DllCall("CloseHandle", "Ptr", t)
	DllCall("CloseHandle", "Ptr", h)

	try
	{
		s := VarSetCapacity(a, s)
		c := 0
		DllCall(EnumProcesses, "Ptr", &a, "UInt", s, "UIntP", r)
		Loop, % r // 4
		{
			id := NumGet(a, A_Index * 4, "UInt")

			h := DllCall("OpenProcess", "UInt", 0x0010 | 0x0400, "Int", false, "UInt", id, "Ptr")

			if !h
				continue
			VarSetCapacity(n, s, 0)
			e := DllCall("Psapi\GetModuleBaseName", "Ptr", h, "Ptr", 0, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
			if !e 
				if e := DllCall("Psapi\GetProcessImageFileName", "Ptr", h, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
					SplitPath n, n
			DllCall("CloseHandle", "Ptr", h)
			if (n && e)
				if (n == executable) {
					poePID.Insert(id)
				}
		}

		l := poePID.Length()
		if ( l = 0 ) {
			Process, wait, %executable%, 0.2
			if ( ErrorLevel > 0 ) {
				poePID.Insert(ErrorLevel)
			}
		}
		
		VarSetCapacity(dwSize, 4, 0) 
		result := DllCall(GetTable, UInt, &TcpTable, UInt, &dwSize, UInt, 0, UInt, 2, UInt, 5, UInt, 0) 
		VarSetCapacity(TcpTable, NumGet(dwSize), 0) 

		result := DllCall(GetTable, UInt, &TcpTable, UInt, &dwSize, UInt, 0, UInt, 2, UInt, 5, UInt, 0) 

		num := NumGet(&TcpTable,0,"UInt")

		IfEqual, num, 0
		{
			cportsLogout()
			error("ED11",num,l,executable)
			return False
		}

		out := 0
		Loop %num%
		{
			cutby := a_index - 1
			cutby *= 24
			ownerPID := NumGet(&TcpTable,cutby+24,"UInt")
			for index, element in poePID {
				if ( ownerPID = element )
				{
					VarSetCapacity(newEntry, 20, 0) 
					NumPut(12,&newEntry,0,"UInt")
					NumPut(NumGet(&TcpTable,cutby+8,"UInt"),&newEntry,4,"UInt")
					NumPut(NumGet(&TcpTable,cutby+12,"UInt"),&newEntry,8,"UInt")
					NumPut(NumGet(&TcpTable,cutby+16,"UInt"),&newEntry,12,"UInt")
					NumPut(NumGet(&TcpTable,cutby+20,"UInt"),&newEntry,16,"UInt")
					result := DllCall(SetEntry, UInt, &newEntry)
					IfNotEqual, result, 0
					{
						cportsLogout()
						error("TCP" . result,out,result,l,executable)
						return False
					}
					out++
				}
			}
		}
		if ( out = 0 ) {
			cportsLogout()
			error("ED10",out,l,executable)
			return False
		} else {
			error(l . ":" . A_TickCount - start,out,l,executable)
		}
	} 
	catch e
	{
		cportsLogout()
		error("ED14","catcherror",e)
		return False
	}
	
	return True
}

error(var,var2:="",var3:="",var4:="",var5:="",var6:="",var7:="") {
	GuiControl,1:, guiErr, %var%
	print := A_Now . "," . var . "," . var2 . "," . var3 . "," . var4 . "," . var5 . "," . var6 . "," . var7 . "`n"
	FileAppend, %print%, error.txt, UTF-16
	return
}

invite(){
inviteCommand:
	BlockInput On
	Send ^{Enter}{Home}{Delete}/invite {Enter}
	BlockInput Off
	return
}

oosCommand(){
oosCommand:
	BlockInput On
	SendInput, {enter}
	Sleep 2
	SendInput, {/}oos
	SendInput, {enter}
	BlockInput Off
	return
}

remaining(){
remainingCommand:
	BlockInput On
	SendInput, {enter}
	Sleep 2
	SendInput, {/}remaining
	SendInput, {enter}
	BlockInput Off
	return
}

whois(){
whoisCommand:
	BlockInput On
	Send ^{Enter}{Home}{Delete}/whois {Enter}
	BlockInput Off
	return
}

kick(){
kickCommand:
	BlockInput On
	Send ^{Enter}{Home}{Delete}/kick {Enter}
	BlockInput Off
	return
}

hideout(){
hideoutCommand:
	BlockInput On
	SendInput, {Enter}
	Sleep 2
	SendInput, {/}hideout
	SendInput, {Enter}
	BlockInput Off
	return
}

whisperCommand1:
	BlockInput On
	Sleep 2
	SendInput ^{Enter}
	SendInput %wm1%
	SendInput {Enter}
	BlockInput Off
	return
whisperCommand2:
	BlockInput On
	Sleep 2
	SendInput ^{Enter}
	SendInput %wm2%
	SendInput {Enter}
	BlockInput Off
	return
whisperCommand3:
	BlockInput On
	Sleep 2
	SendInput ^{Enter}
	SendInput %wm3%
	SendInput {Enter}
	BlockInput Off
	return
whisperCommand4:
	BlockInput On
	Sleep 2
	SendInput ^{Enter}
	SendInput %wm4%
	SendInput {Enter}
	BlockInput Off
	return
whisperCommand5:
	BlockInput On
	Sleep 2
	SendInput ^{Enter}
	SendInput %wm5%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand1:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm1%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand2:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm2%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand3:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm3%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand4:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm4%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand5:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm5%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand6:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm6%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand7:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm7%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand8:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm8%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand9:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm9%
	SendInput {Enter}
	BlockInput Off
	return
partyCommand10:
	BlockInput On
	Sleep 2
	SendInput {Enter}
	SendInput ^A{BS}
	SendRaw %pm10%
	SendInput {Enter}
	BlockInput Off
	return
cooldownCommand1:
	control(1)
	return
cooldownCommand2:
	control(2)
	return
cooldownCommand3:
	control(3)
	return
cooldownCommand4:
	control(4)
	return
cooldownCommand5:
	control(5)
	return
cooldownCommand6:
	control(6)
	return
cooldownCommand7:
	control(7)
	return

scrollUpCommand:
	SendInput ^{Left}
	return
scrollDownCommand:
	SendInput ^{Right}
	return

control(i){
	global prog1, prog2, prog3, prog4, prog5, prog6, prog7
	prog%i% := A_TickCount
	return
}

changelogGui(){
changelogGui:
	FileRead, changelog, changelog.txt
	Gui, 3:Add, Edit, w600 h200 +ReadOnly, %changelog% 
	Gui, 3:Show,, LutTools Patch Notes
	return
}

playSound:
	Gui, 2:Submit, nohide
	SoundPlay, %guiSoundSelector%
	return

toggleOverlay(){
toggleOverlayCommand:
	global toggle
	toggle++
	if toggle > 1
		toggle := -1
	if toggle = -1
	{
		Gui, 1:Hide
		Gui, 8:Hide
	}
	if toggle = 0
	{
		;Gui, 1:Show, h42 NA
		Gui, 1:Show, h32 NA
		Gui, 8:Show, NA
	}
	if toggle = 1
	{
		Gui, 1:Show, h32 NA
		Gui, 8:Show, NA
	}
	return
}

preloadCports(){
	global preloadCportsTimer, basePreloadCportsTimer, preloadCportsCall
	Run, %preloadCportsCall%
	preloadCportsTimer := basePreloadCportsTimer
}

checkOverlay(){
	global overlayTimer, baseOverlayTimer, toggle, xOffset, yOffset, processWarningFound, calcd, waxOffset, wayOffset, onex, oney, eightx, eighty
	if toggle != -1
	{		
			IfWinActive ahk_class POEWindowClass
			{
				WinGetActiveStats,name,width,height,x,y
				if ( toggle = 1 ) || ( toggle = 0 )
				{
					if ( calcd = 0 ) 
					{
						width += x
						hh := y
						hh += yOffset
						ww := width - 231
						ww += xOffset
						onex := ww
						oney := hh

						width *= 0.3215
						width += waxOffset
						height *= 0.91
						height += wayOffset
						eighty := height
						eightx := width

						calcd = 1
					}
					Gui, 8:Show, y%eighty% x%eightx% NA
					Gui, 1:Show, y%oney% x%onex% NA
				}
				if ( processWarningFound > 0 )
				{
					Gui, 6:Show, x0 y0 NA
				} else {
					Gui, 6:Hide
				}
			} else {
				Gui, 1:Hide
				Gui, 8:Hide
				Gui, 6:Hide
			}
	}
	overlayTimer := baseOverlayTimer
	return
}

checkActiveType() {
	global verifyLogoutTimer, baseVerifyLogoutTimer, executable, processWarningFound, backupExe
	val := 0
	Process, Exist, %executable%
	if !ErrorLevel
	{
		WinGet, id, list,ahk_class POEWindowClass,, Program Manager
		Loop, %id%
		{
			this_id := id%A_Index%
			WinGet, this_name, ProcessName, ahk_id %this_id%
			backupExe := this_name
			found .= ", " . this_name
			val++
		}

		if ( val > 0 )
		{
			processWarningFound := 1
			berrmsgf .= "You are running: " . found . ""
			berrmsge .= "Your settings expect: " . executable . ""
		} else {
			processWarningFound := 0
			backupExe := "No issues detected"
		}

		GuiControl,6:, backupErrorFound, %berrmsgf%
		GuiControl,6:, backupErrorExpected, %berrmsge%
	}

	verifyLogoutTimer := baseVerifyLogoutTimer
	return
}

runUpdate(){
global
runUpdate:
	if launcherPath != ERROR
		UrlDownloadToFile, http://lutbot.com/ahk/macro.ahk, %launcherPath%
	UrlDownloadToFile, http://lutbot.com/ahk/verify.ahk, verify.ahk
	UrlDownloadToFile, http://lutbot.com/ahk/lite.ahk, lite.ahk
	UrlDownloadToFile, http://lutbot.com/ahk/heavy.ahk, heavy.ahk
		if ErrorLevel {
			error("update","fail",A_ScriptFullPath, macroVersion, A_AhkVersion)
			error("ED07")
		}
		else {
			error("update","pass",A_ScriptFullPath, macroVersion, A_AhkVersion)
			Run "%A_ScriptFullPath%"
		}
	Sleep 5000 ;This shouldn't ever hit.
	error("update","uhoh", A_ScriptFullPath, macroVersion, A_AhkVersion)
dontUpdate:
	Gui, 4:Destroy
	return	
showPatreon:
	Run http://patreon.com/lutcikaur
	return
showFAQ:
	Run http://lutbot.com/#/faq
	return
showDiscord:
	Run https://discord.gg/nttekWT
	return
switchLite:
	IniWrite, 0, settings.ini, variables, RunHeavy
	Run lite.ahk
	ExitApp
showTradeMacro:
	Run https://poe-trademacro.github.io/
	return
}

loopTimers(){
	global
	Loop {
		cooldowns = 7
		do = 0
		if ( toggle = 1 ) || ( toggle = 0 )
		{
			Loop % cooldowns
			{
				i := A_Index
				ppp := prog%i% + duration%i% + 501
				IfLess, A_TickCount , %ppp%
				{
					do = 1
					p := prog%i%
					d := duration%i%
					s = %d%
					s /= 100
					pp := p - A_TickCount
					pp /= s
					pp := 100 + pp
					GuiControl,8:,Prog%i%,%pp%
				}
			}
		}
		if ( do = 1 ) {
			ss := 100
		} else {
			ss := sleepTime
		}

		if ( overlayTimerActive = true ) 
			overlayTimer -= ss    
		if ( updateTrackingTimerActive = true )
			updateTrackingTimer -= ss
		if ( !beta )
			preloadCportsTimer -= ss

		verifyLogoutTimer -= ss

		if ( overlayTimer <= 0 ) && ( overlayTimerActive = true )
		{
			checkOverlay()
		}
					
		if ( updateTrackingTimer <= 0 ) && ( updateTrackingTimerActive = true )
		{
			if ( toggle = 1 ) || ( toggle = 0 )
			{
				if WinActive("ahk_class POEWindowClass")
					updateTracking()
				else
					updateTrackingTimer := 60000
			}
		}
		if ( preloadCportsTimer <= 0 )
		{
			if WinActive("ahk_class POEWindowClass")
				preloadCports()
			else
				preloadCportsTimer := basePreloadCportsTimer
		}

		if ( verifyLogoutTimer <= 0 )
		{
			if WinActive("ahk_class POEWindowClass")
				checkActiveType()
		}


		Sleep ss  
	}
	return
}

updateTracking(){
	global accName, league, updateTrackingTimer, baseUpdateTrackingTimer, toggle, charName
	updateTrackingTimer := baseUpdateTrackingTimer ; Wait the base time
	StringLower, lowName, charName
	if ( toggle < 0 ) {
		return
	}
	url := "http://api.lutbot.com:8080/rank/v2/" . league . "/" . accName . "/" . lowName . "" 
	SetTimer, loadLadder, 1000
	FileDelete, ladder.json
	run "Lib\QDL.ahk" %url% "ladder.json"
	return
}

loadLadder:
	track()
return

track(){
	rr := "Rank: N/A"
	IfExist, ladder.json 
	{
		SetTimer, loadLadder, off
		FileRead, ladderString, ladder.json
		if ( ladderString = "0" ) {
			rank := "Rank: Unranked"
		} else {
			rank := "Rank: "
			rank .= ladderString
		}
		GuiControl,1:, guiRank, %rank%
	} else {
		return
	}
	return
}


optionsCommand:
	hotkeys()
return

hotkeys(){
	global processWarningFound, macroVersion
	getLeagueListing()
	Gui, 2:Show,, Macro Settings Version %macroVersion% :: AHK Version %A_AhkVersion%
	processWarningFound := 0
	Gui, 6:Hide
	return
}


updateHotkeys:
	submit()
return

submit(){  
	global
	Gui, 2:Submit 
	IniWrite, %guiChar%, settings.ini, variables, CharacterName
	IniWrite, %guiAcc%, settings.ini, variables, AccountName
	IniWrite, %guiLeague%, settings.ini, variables, League
	IniWrite, %guiSteam%, settings.ini, variables, PoeSteam
	IniWrite, %guiXOffset%, settings.ini, variables, XOffset
	IniWrite, %guiYOffset%, settings.ini, variables, YOffset
	IniWrite, %guiWAXOffset%, settings.ini, variables, WAXOffset
	IniWrite, %guiWAYOffset%, settings.ini, variables, WAYOffset
	IniWrite, %guicolorBG%, settings.ini, variables, ColorBG
	IniWrite, %guicolorText%, settings.ini, variables, ColorText
	IniWrite, %toggle%, settings.ini, variables, OverlayToggle
	IniWrite, %guiSoundSelector%, settings.ini, variables, SoundSelector
	IniWrite, %guibeta%, settings.ini, variables, Beta
	IniWrite, %guiscroll%, settings.ini, variables, Scroll
	IniWrite, %guipasteWatch%, settings.ini, variables, PasteWatch
	IniWrite, %guidiablo2%, settings.ini, variables, Diablo2
	IniWrite, %guiduration1%, settings.ini, variables, duration1
	IniWrite, %guiduration2%, settings.ini, variables, duration2
	IniWrite, %guiduration3%, settings.ini, variables, duration3
	IniWrite, %guiduration4%, settings.ini, variables, duration4
	IniWrite, %guiduration5%, settings.ini, variables, duration5
	IniWrite, %guiduration6%, settings.ini, variables, duration6
	IniWrite, %guiduration7%, settings.ini, variables, duration7
	IniWrite, %guicooldownColor1%, settings.ini, variables, cooldownColor1
	IniWrite, %guicooldownColor2%, settings.ini, variables, cooldownColor2
	IniWrite, %guicooldownColor3%, settings.ini, variables, cooldownColor3
	IniWrite, %guicooldownColor4%, settings.ini, variables, cooldownColor4
	IniWrite, %guicooldownColor5%, settings.ini, variables, cooldownColor5
	IniWrite, %guicooldownColor6%, settings.ini, variables, cooldownColor6
	IniWrite, %guicooldownColor7%, settings.ini, variables, cooldownColor7
	IniWrite, %guiwm1%, settings.ini, whisperMessages, wm1
	IniWrite, %guiwm2%, settings.ini, whisperMessages, wm2
	IniWrite, %guiwm3%, settings.ini, whisperMessages, wm3
	IniWrite, %guiwm4%, settings.ini, whisperMessages, wm4
	IniWrite, %guiwm5%, settings.ini, whisperMessages, wm5
	IniWrite, %guipm1%, settings.ini, partyMessages, pm1
	IniWrite, %guipm2%, settings.ini, partyMessages, pm2
	IniWrite, %guipm3%, settings.ini, partyMessages, pm3
	IniWrite, %guipm4%, settings.ini, partyMessages, pm4
	IniWrite, %guipm5%, settings.ini, partyMessages, pm5
	IniWrite, %guipm6%, settings.ini, partyMessages, pm6
	IniWrite, %guipm7%, settings.ini, partyMessages, pm7
	IniWrite, %guipm8%, settings.ini, partyMessages, pm8
	IniWrite, %guipm9%, settings.ini, partyMessages, pm9
	IniWrite, %guipm10%, settings.ini, partyMessages, pm10
	IniWrite, %guihotkeyLogout%, settings.ini, hotkeys, logout
	IniWrite, %guihotkeySuperLogout%, settings.ini, hotkeys, superLogout
	IniWrite, %guihotkeyOos%, settings.ini, hotkeys, oos
	IniWrite, %guihotkeyRemaining%, settings.ini, hotkeys, remaining
	IniWrite, %guihotkeyWhois%, settings.ini, hotkeys, whois
	IniWrite, %guihotkeyKick%, settings.ini, hotkeys, kick
	IniWrite, %guihotkeyHideout%, settings.ini, hotkeys, hideout
	IniWrite, %guihotkeyInvite%, settings.ini, hotkeys, invite
	IniWrite, %guihotkeyToggleOverlay%, settings.ini, hotkeys, toggleOverlay
	IniWrite, %guihotkeyOptions%, settings.ini, hotkeys, options
	IniWrite, %guihotkeyPriceCheck%, settings.ini, hotkeys, priceCheck
	IniWrite, %guihotkeyCooldown1%, settings.ini, hotkeys, cooldown1
	IniWrite, %guihotkeyCooldown2%, settings.ini, hotkeys, cooldown2
	IniWrite, %guihotkeyCooldown3%, settings.ini, hotkeys, cooldown3
	IniWrite, %guihotkeyCooldown4%, settings.ini, hotkeys, cooldown4
	IniWrite, %guihotkeyCooldown5%, settings.ini, hotkeys, cooldown5
	IniWrite, %guihotkeyCooldown6%, settings.ini, hotkeys, cooldown6
	IniWrite, %guihotkeyCooldown7%, settings.ini, hotkeys, cooldown7
	IniWrite, %guihotkeywm1%, settings.ini, hotkeys, wm1
	IniWrite, %guihotkeywm2%, settings.ini, hotkeys, wm2
	IniWrite, %guihotkeywm3%, settings.ini, hotkeys, wm3
	IniWrite, %guihotkeywm4%, settings.ini, hotkeys, wm4
	IniWrite, %guihotkeywm5%, settings.ini, hotkeys, wm5
	IniWrite, %guihotkeypm1%, settings.ini, hotkeys, pm1
	IniWrite, %guihotkeypm2%, settings.ini, hotkeys, pm2
	IniWrite, %guihotkeypm3%, settings.ini, hotkeys, pm3
	IniWrite, %guihotkeypm4%, settings.ini, hotkeys, pm4
	IniWrite, %guihotkeypm5%, settings.ini, hotkeys, pm5
	IniWrite, %guihotkeypm6%, settings.ini, hotkeys, pm6
	IniWrite, %guihotkeypm7%, settings.ini, hotkeys, pm7
	IniWrite, %guihotkeypm8%, settings.ini, hotkeys, pm8
	IniWrite, %guihotkeypm9%, settings.ini, hotkeys, pm9
	IniWrite, %guihotkeypm10%, settings.ini, hotkeys, pm10

	readFromFile()
	checkActiveType()

	return    
}

readFromFile(){
	global
	;reset hotkeys ughh.
	Hotkey, IfWinActive, ahk_class POEWindowClass
	If hotkeyLogout
		Hotkey,% hotkeyLogout, logoutCommand, Off
	If hotkeyOos
		Hotkey,% hotkeyOos, oosCommand, Off
	If hotkeyRemaining
		Hotkey,% hotkeyRemaining, remainingCommand, Off
	If hotkeyWhois
		Hotkey,% hotkeyWhois, whoisCommand, Off
	If hotkeyKick
		Hotkey,% hotkeyKick, kickCommand, Off
	If hotkeyHideout
		Hotkey,% hotkeyHideout, hideoutCommand, Off
	If hotkeyInvite
		Hotkey,% hotkeyInvite, inviteCommand, Off
	If hotkeyToggleOverlay
		Hotkey,% hotkeyToggleOverlay, toggleOverlayCommand, Off
	If hotkeyPriceCheck
		Hotkey,% hotkeyPriceCheck, priceCheckCommand, Off
	If hotkeyCooldown1
		Hotkey,% hotkeyCooldown1, cooldownCommand1, Off
	If hotkeyCooldown2
		Hotkey,% hotkeyCooldown2, cooldownCommand2, Off
	If hotkeyCooldown3
		Hotkey,% hotkeyCooldown3, cooldownCommand3, Off
	If hotkeyCooldown4
		Hotkey,% hotkeyCooldown4, cooldownCommand4, Off
	If hotkeyCooldown5
		Hotkey,% hotkeyCooldown5, cooldownCommand5, Off
	If hotkeyCooldown6
		Hotkey,% hotkeyCooldown6, cooldownCommand6, Off
	If hotkeyCooldown7
		Hotkey,% hotkeyCooldown7, cooldownCommand7, Off
	If hotkeywm1
		Hotkey,% hotkeywm1, whisperCommand1, Off
	If hotkeywm2
		Hotkey,% hotkeywm2, whisperCommand1, Off
	If hotkeywm3
		Hotkey,% hotkeywm3, whisperCommand1, Off
	If hotkeywm4
		Hotkey,% hotkeywm4, whisperCommand1, Off
	If hotkeywm5
		Hotkey,% hotkeywm5, whisperCommand1, Off
	If hotkeypm1
		Hotkey,% hotkeypm1, partyCommand1, Off
	If hotkeypm2
		Hotkey,% hotkeypm2, partyCommand2, Off
	If hotkeypm3
		Hotkey,% hotkeypm3, partyCommand3, Off
	If hotkeypm4
		Hotkey,% hotkeypm4, partyCommand4, Off
	If hotkeypm5
		Hotkey,% hotkeypm5, partyCommand5, Off
	If hotkeypm6
		Hotkey,% hotkeypm6, partyCommand6, Off
	If hotkeypm7
		Hotkey,% hotkeypm7, partyCommand7, Off
	If hotkeypm8
		Hotkey,% hotkeypm8, partyCommand8, Off
	If hotkeypm9
		Hotkey,% hotkeypm9, partyCommand9, Off
	If hotkeypm10
		Hotkey,% hotkeypm10, partyCommand10, Off

	Hotkey,~^v, whisperCheckCommand, Off

	Hotkey,WheelUp, scrollUpCommand, Off
	Hotkey,WheelDown, scrollDownCommand, Off

	Hotkey, IfWinActive
	If hotkeyOptions
		Hotkey,% hotkeyOptions, optionsCommand, Off
	If hotkeySuperLogout
		Hotkey,% hotkeySuperLogout, superLogoutCommand, Off
	Hotkey, IfWinActive, ahk_class POEWindowClass

	; variables
	IniRead, charName, settings.ini, variables, CharacterName
	IniRead, accName, settings.ini, variables, AccountName
	IniRead, league, settings.ini, variables, League
	IniRead, steam, settings.ini, variables, PoeSteam

	IniRead, xOffset, settings.ini, variables, XOffset
	IniRead, yOffset, settings.ini, variables, YOffset
	IniRead, waxOffset, settings.ini, variables, WAXOffset
	IniRead, wayOffset, settings.ini, variables, WAYOffset
	IniRead, colorBG, settings.ini, variables, ColorBG
	IniRead, colorText, settings.ini, variables, ColorText
	IniRead, toggle, settings.ini, variables, OverlayToggle
	IniRead, soundSelector, settings.ini, variables, SoundSelector
	IniRead, beta, settings.ini, variables, Beta
	IniRead, scroll, settings.ini, variables, Scroll
	IniRead, pasteWatch, settings.ini, variables, PasteWatch
	IniRead, diablo2, settings.ini, variables, Diablo2
	IniRead, duration1, settings.ini, variables, Duration1
	IniRead, duration2, settings.ini, variables, Duration2
	IniRead, duration3, settings.ini, variables, Duration3
	IniRead, duration4, settings.ini, variables, Duration4
	IniRead, duration5, settings.ini, variables, Duration5
	IniRead, duration6, settings.ini, variables, Duration6
	IniRead, duration7, settings.ini, variables, Duration7
	IniRead, cooldownColor1, settings.ini, variables, CooldownColor1
	IniRead, cooldownColor2, settings.ini, variables, CooldownColor2
	IniRead, cooldownColor3, settings.ini, variables, CooldownColor3
	IniRead, cooldownColor4, settings.ini, variables, CooldownColor4
	IniRead, cooldownColor5, settings.ini, variables, CooldownColor5
	IniRead, cooldownColor6, settings.ini, variables, CooldownColor6
	IniRead, cooldownColor7, settings.ini, variables, CooldownColor7
	; whisper messages
	IniRead, wm1, settings.ini, whisperMessages, wm1
	IniRead, wm2, settings.ini, whisperMessages, wm2
	IniRead, wm3, settings.ini, whisperMessages, wm3
	IniRead, wm4, settings.ini, whisperMessages, wm4
	IniRead, wm5, settings.ini, whisperMessages, wm5
	;party messages
	IniRead, pm1, settings.ini, partyMessages, pm1
	IniRead, pm2, settings.ini, partyMessages, pm2
	IniRead, pm3, settings.ini, partyMessages, pm3
	IniRead, pm4, settings.ini, partyMessages, pm4
	IniRead, pm5, settings.ini, partyMessages, pm5
	IniRead, pm6, settings.ini, partyMessages, pm6
	IniRead, pm7, settings.ini, partyMessages, pm7
	IniRead, pm8, settings.ini, partyMessages, pm8
	IniRead, pm9, settings.ini, partyMessages, pm9
	IniRead, pm10, settings.ini, partyMessages, pm10
	;hotkeys
	IniRead, hotkeyLogout, settings.ini, hotkeys, logout, %A_Space%
	IniRead, hotkeySuperLogout, settings.ini, hotkeys, superLogout, %A_Space%
	IniRead, hotkeyOos, settings.ini, hotkeys, oos, %A_Space%
	IniRead, hotkeyRemaining, settings.ini, hotkeys, remaining, %A_Space%
	IniRead, hotkeyWhois, settings.ini, hotkeys, whois, %A_Space%
	IniRead, hotkeyKick, settings.ini, hotkeys, kick, %A_Space%
	IniRead, hotkeyHideout, settings.ini, hotkeys, hideout, %A_Space%
	IniRead, hotkeyInvite, settings.ini, hotkeys, invite, %A_Space%
	IniRead, hotkeyToggleOverlay, settings.ini, hotkeys, toggleOverlay, %A_Space%
	IniRead, hotkeyOptions, settings.ini, hotkeys, options, %A_Space%
	IniRead, hotkeyPriceCheck, settings.ini, hotkeys, priceCheck, %A_Space%
	IniRead, hotkeyCooldown1, settings.ini, hotkeys, cooldown1, %A_Space%
	IniRead, hotkeyCooldown2, settings.ini, hotkeys, cooldown2, %A_Space%
	IniRead, hotkeyCooldown3, settings.ini, hotkeys, cooldown3, %A_Space%
	IniRead, hotkeyCooldown4, settings.ini, hotkeys, cooldown4, %A_Space%
	IniRead, hotkeyCooldown5, settings.ini, hotkeys, cooldown5, %A_Space%
	IniRead, hotkeyCooldown6, settings.ini, hotkeys, cooldown6, %A_Space%
	IniRead, hotkeyCooldown7, settings.ini, hotkeys, cooldown7, %A_Space%
	IniRead, hotkeywm1, settings.ini, hotkeys, wm1, %A_Space%
	IniRead, hotkeywm2, settings.ini, hotkeys, wm2, %A_Space%
	IniRead, hotkeywm3, settings.ini, hotkeys, wm3, %A_Space%
	IniRead, hotkeywm4, settings.ini, hotkeys, wm4, %A_Space%
	IniRead, hotkeywm5, settings.ini, hotkeys, wm5, %A_Space%
	IniRead, hotkeypm1, settings.ini, hotkeys, pm1, %A_Space%
	IniRead, hotkeypm2, settings.ini, hotkeys, pm2, %A_Space%
	IniRead, hotkeypm3, settings.ini, hotkeys, pm3, %A_Space%
	IniRead, hotkeypm4, settings.ini, hotkeys, pm4, %A_Space%
	IniRead, hotkeypm5, settings.ini, hotkeys, pm5, %A_Space%
	IniRead, hotkeypm6, settings.ini, hotkeys, pm6, %A_Space%
	IniRead, hotkeypm7, settings.ini, hotkeys, pm7, %A_Space%
	IniRead, hotkeypm8, settings.ini, hotkeys, pm8, %A_Space%
	IniRead, hotkeypm9, settings.ini, hotkeys, pm9, %A_Space%
	IniRead, hotkeypm10, settings.ini, hotkeys, pm10, %A_Space%

	IniRead, launcherPath, settings.ini, variables, LauncherPath

	Hotkey, IfWinActive, ahk_class POEWindowClass
	If hotkeyLogout
		Hotkey,% hotkeyLogout, logoutCommand, On
	If hotkeyOos
		Hotkey,% hotkeyOos, oosCommand, On
	If hotkeyRemaining
		Hotkey,% hotkeyRemaining, remainingCommand, On
	If hotkeyWhois
		Hotkey,% hotkeyWhois, whoisCommand, On
	If hotkeyKick
		Hotkey,% hotkeyKick, kickCommand, On
	If hotkeyHideout
		Hotkey,% hotkeyHideout, hideoutCommand, On
	If hotkeyInvite
		Hotkey,% hotkeyInvite, inviteCommand, On
	If hotkeyToggleOverlay
		Hotkey,% hotkeyToggleOverlay, toggleOverlayCommand, On
	If hotkeyPriceCheck
		Hotkey,% hotkeyPriceCheck, priceCheckCommand, On
	If hotkeyCooldown1
	{
		hkCD1 = ~
		hkCD1 .= hotkeyCooldown1
		Hotkey,% hkCD1, cooldownCommand1, On
	}
	If hotkeyCooldown2
	{
		hkCD2 = ~
		hkCD2 .= hotkeyCooldown2
		Hotkey,% hkCD2, cooldownCommand2, On
	}
	If hotkeyCooldown3
	{
		hkCD3 = ~
		hkCD3 .= hotkeyCooldown3
		Hotkey,% hkCD3, cooldownCommand3, On
	}
	If hotkeyCooldown4
	{
		hkCD4 = ~
		hkCD4 .= hotkeyCooldown4
		Hotkey,% hkCD4, cooldownCommand4, On
	}
	If hotkeyCooldown5
	{
		hkCD5 = ~
		hkCD5 .= hotkeyCooldown5
		Hotkey,% hkCD5, cooldownCommand5, On
	}
	If hotkeyCooldown6
	{
		hkCD6 = ~
		hkCD6 .= hotkeyCooldown6
		Hotkey,% hkCD6, cooldownCommand6, On
	}
	If hotkeyCooldown7
	{
		hkCD7 = ~
		hkCD7 .= hotkeyCooldown7
		Hotkey,% hkCD7, cooldownCommand7, On
	}
	If hotkeywm1
		Hotkey,% hotkeywm1, whisperCommand1, On
	If hotkeywm2
		Hotkey,% hotkeywm2, whisperCommand2, On
	If hotkeywm3
		Hotkey,% hotkeywm3, whisperCommand3, On
	If hotkeywm4
		Hotkey,% hotkeywm4, whisperCommand4, On
	If hotkeywm5
		Hotkey,% hotkeywm5, whisperCommand5, On
	If hotkeypm1
		Hotkey,% hotkeypm1, partyCommand1, On
	If hotkeypm2
		Hotkey,% hotkeypm2, partyCommand2, On
	If hotkeypm3
		Hotkey,% hotkeypm3, partyCommand3, On
	If hotkeypm4
		Hotkey,% hotkeypm4, partyCommand4, On
	If hotkeypm5
		Hotkey,% hotkeypm5, partyCommand5, On
	If hotkeypm6
		Hotkey,% hotkeypm6, partyCommand6, On
	If hotkeypm7
		Hotkey,% hotkeypm7, partyCommand7, On
	If hotkeypm8
		Hotkey,% hotkeypm8, partyCommand8, On
	If hotkeypm9
		Hotkey,% hotkeypm9, partyCommand9, On
	If hotkeypm10
		Hotkey,% hotkeypm10, partyCommand10, On

	If scroll
		Hotkey,^WheelUp, scrollUpCommand, On
	If scroll
		Hotkey,^WheelDown, scrollDownCommand, On

	If pasteWatch
		Hotkey,~^v, whisperCheckCommand, On

	Hotkey, IfWinActive
	If hotkeyOptions {
		Hotkey,% hotkeyOptions, optionsCommand, On
		GuiControl,1:, guiSettings, Settings:%hotkeyOptions%
	}
	else {
		Hotkey,F10, optionsCommand, On
		msgbox You dont have some hotkeys set!`nPlease hit F10 to open up your config prompt and please configure your hotkeys (Path of Exile has to be in focus).`nThe way you configure hotkeys is now in the GUI (default F10). Otherwise, you didn't put a hotkey for the options menu. You need that silly.
		GuiControl,1:, guiSettings, Settings:%hotkeyOptions%
	}
	If hotkeySuperLogout
		Hotkey,% hotkeySuperLogout, superLogoutCommand, On
	Hotkey, IfWinActive, ahk_class POEWindowClass
	; extra checks

	if beta = ERROR
		beta = 1
	if diablo2 = ERROR
		diablo2 = 0
	if scroll = ERROR
		scroll = 1
	if waxOffset = ERROR
		waxOffset = 0
	if wayOffset = ERROR
		wayOffset = 0

	if duration1 = ERROR
		duration1 = 4000
	if duration2 = ERROR
		duration2 = 4000
	if duration3 = ERROR
		duration3 = 4000
	if duration4 = ERROR
		duration4 = 4000
	if duration5 = ERROR
		duration5 = 4000
	if duration6 = ERROR
		duration6 = 4000
	if duration7 = ERROR
		duration7 = 4000

	if cooldownColor1 = ERROR
		cooldownColor1 = ffff00
	if cooldownColor2 = ERROR
		cooldownColor2 = ff0000
	if cooldownColor3= ERROR
		cooldownColor3 = 00ffff
	if cooldownColor4= ERROR
		cooldownColor4 = ffffff
	if cooldownColor5= ERROR
		cooldownColor5 = 00ff00
	if cooldownColor6= ERROR
		cooldownColor6 = 0000ff
	if cooldownColor7= ERROR
		cooldownColor7 = ff00ff

	if steam = ERROR
		steam = 0
	if pasteWatch = ERROR
		pasteWatch = 1
	if (colorBG = "ERROR") || (colorBG = "")
		colorBG = 11213a
	if (colorText = "ERROR") || (colorText = "")
		colorText = c9d4e5

	if ( steam ) {
		cportsCommand := "cports.exe /close * * * * PathOfExile_x64Steam.exe"
		executable := "PathOfExile_x64Steam.exe"
	} else {
		cportsCommand := "cports.exe /close * * * * PathOfExile_x64.exe"
		executable := "PathOfExile_x64.exe"
	}

	if ( diablo2 ) {
		cportsCommand := "cports.exe /close * * * * Game.exe"
		executable := "Game.exe"
	}

	calcd = 0

	Gui, 1:Color, %colorBG%
	Gui, 1:Font, %colorText% s14, Lucida Sans Unicode
	prog1 := A_TickCount - 10000
	prog2 := A_TickCount - 10000
	prog3 := A_TickCount - 10000
	prog4 := A_TickCount - 10000
	prog5 := A_TickCount - 10000
	prog6 := A_TickCount - 10000
	prog7 := A_TickCount - 10000
	GuiControl, 8:+c%cooldownColor1%, Prog1
	GuiControl, 8:+c%cooldownColor2%, Prog2
	GuiControl, 8:+c%cooldownColor3%, Prog3
	GuiControl, 8:+c%cooldownColor4%, Prog4
	GuiControl, 8:+c%cooldownColor5%, Prog5
	GuiControl, 8:+c%cooldownColor6%, Prog6
	GuiControl, 8:+c%cooldownColor7%, Prog7

	updateTrackingTimer := 5000
}

; ; ERROR LIST
; min lv = null : you typed in the league name wrong.
; ED01 : Error downloading rank from http://exiletools.com/ , their server might be unavailible.
; ED02 -> ED04 : Error downloading currports from my website. http://www.nirsoft.net/utils/cports.html holds the original file.
; ED05 : Error downloading ladder stats from http://exiletools.com/ , their server might be unavailible.
; ED06 : Error checking for new version.
; ED07 : Error downloading newest version of ahk script.
; ED08 : Error downloading newest changelog.
; ED09 : Error downloading list of active leagues
; ED10 : Logged out with cports No process
; ED11 : Logged out with cports TcpTable Failure
; ED12 : Invalid logout settings
; ED13 : Total logout miss
; ED14 : try/catch