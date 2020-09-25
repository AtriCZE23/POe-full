; made by /u/lutcikaur
; GUI's in use : 2, 3, 4
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
	Gui, 4:Show,, LutTools Lite Patch Notes
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
preloadCportsTimer := 0
basePreloadCportsTimer := 60000 ; 1 minute
preloadCportsCall := "cports.exe /stext TEMP"

;Menu
Gui, 2:Add, Text,x5 h20, Steam Client:
Gui, 2:Add, Text,x5 h20, Dx11 (x64) Client:
Gui, 2:Add, Text,x5 h20, Logout:
Gui, 2:Add, Text,x5 h20, ForceLogout:
Gui, 2:Add, Text,section x5 h20, Options (This GUI) :

Gui, 2:Add, Checkbox, vguiSteam ym w150 h20 Checked%steam%
Gui, 2:Add, Checkbox, vguihighBits h20 Checked%highBits%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeyLogout , %hotkeyLogout%
Gui, 2:Add, Hotkey, w150 h20 vguihotkeySuperLogout , %hotkeySuperLogout%
Gui, 2:Add, Hotkey, h20 vguihotkeyOptions, %hotkeyOptions%

Gui, 2:Add, Button, xs section gshowDiscord, Discord
Gui, 2:Add, Button, ys gshowFAQ, Visit FAQ
Gui, 2:Add, Button, ys gchangelogGui, View Changelog
Gui, 2:Add, Button, xs section gshowPatreon, Support with Patreon
Gui, 2:Add, Button, ys gswitchHeavy, Switch To Full
Gui, 2:Add, Button, ys default gupdateHotkeys, Save


Menu, Tray, Tip, LutTools Lite v%macroVersion%
Menu, Tray, NoStandard
Menu, Tray, Add, LutTools Settings, optionsCommand
Menu, Tray, Add, Switch to Full Version, switchHeavy
Menu, Tray, Add, Become a Patreon, showPatreon
Menu, Tray, Add, Join Discord, showDiscord
Menu, Tray, Add, Visit FAQ, showFAQ
Menu, Tray, Add, View Changelog, changelogGui

Menu, Tray, Default, LutTools Settings
Menu, Tray, Add ; Separator
Menu, Tray, Standard



; some initializers. Put these together later.
readFromFile() ;second run. im so sorry.

;start the main loop. Gotta be last
;loopTimers()


//functions
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

changelogGui(){
changelogGui:
	FileRead, changelog, changelog.txt
	Gui, 3:Add, Edit, w600 h200 +ReadOnly, %changelog% 
	Gui, 3:Show,, LutTools Lite Patch Notes
	return
}

preloadCports(){
	global preloadCportsTimer, basePreloadCportsTimer, preloadCportsCall
	Run, %preloadCportsCall%
	preloadCportsTimer := basePreloadCportsTimer
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
		if ErrorLevel {
			error("ED07")
		}
	UrlDownloadToFile, http://lutbot.com/ahk/verify.ahk, verify.ahk
	UrlDownloadToFile, http://lutbot.com/ahk/heavy.ahk, heavy.ahk
	UrlDownloadToFile, http://lutbot.com/ahk/lite.ahk, lite.ahk
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
switchHeavy:
	IniWrite, 1, settings.ini, variables, RunHeavy
	Run heavy.ahk
	ExitApp
}

loopTimers(){
	global
	Loop {
		preloadCportsTimer -= sleepTime
		verifyLogoutTimer -= sleepTime
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
		Sleep sleepTime  
	}
	return
}

options(){
optionsCommand:
	hotkeys()
	return
}

hotkeys(){
	global processWarningFound, macroVersion
	Gui, 2:Show,, Lutbot v%macroVersion% lite
	return
}

updateHotkeys() {
updateHotkeys:
	submit()
	return
}

submit(){  
	global
	Gui, 2:Submit 
	IniWrite, %guiSteam%, settings.ini, variables, PoeSteam
	IniWrite, %guihighBits%, settings.ini, variables, HighBits
	IniWrite, %guihotkeyLogout%, settings.ini, hotkeys, logout
	IniWrite, %guihotkeySuperLogout%, settings.ini, hotkeys, superLogout
	IniWrite, %guihotkeyOptions%, settings.ini, hotkeys, options

	readFromFile()
	checkActiveType()

	return    
}

readFromFile(){
	global
	;reset hotkeys
	Hotkey, IfWinActive, ahk_class POEWindowClass
	If hotkeyLogout
		Hotkey,% hotkeyLogout, logoutCommand, Off

	Hotkey, IfWinActive
	If hotkeyOptions
		Hotkey,% hotkeyOptions, optionsCommand, Off
	If hotkeySuperLogout
		Hotkey,% hotkeySuperLogout, superLogoutCommand, Off
	Hotkey, IfWinActive, ahk_class POEWindowClass

	; variables

	IniRead, steam, settings.ini, variables, PoeSteam
	IniRead, highBits, settings.ini, variables, HighBits
	IniRead, hotkeyLogout, settings.ini, hotkeys, logout, %A_Space%
	IniRead, hotkeySuperLogout, settings.ini, hotkeys, superLogout, %A_Space%
	IniRead, hotkeyOptions, settings.ini, hotkeys, options, %A_Space%

	IniRead, launcherPath, settings.ini, variables, LauncherPath

	Hotkey, IfWinActive, ahk_class POEWindowClass
	If hotkeyLogout
		Hotkey,% hotkeyLogout, logoutCommand, On

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
	if steam = ERROR
		steam = 0
	if highBits = ERROR
		highBits = 0
	
	if ( steam ) {
		if ( highBits ) {
			cportsCommand := "cports.exe /close * * * * PathOfExile_x64Steam.exe"
			executable := "PathOfExile_x64Steam.exe"
		} else {
			cportsCommand := "cports.exe /close * * * * PathOfExileSteam.exe"
			executable := "PathOfExileSteam.exe"
		}
	} else {
		if ( highBits ) {
			cportsCommand := "cports.exe /close * * * * PathOfExile_x64.exe"
			executable := "PathOfExile_x64.exe"
		} else {
			cportsCommand := "cports.exe /close * * * * PathOfExile.exe"
			executable := "PathOfExile.exe"
		}
	}
}
