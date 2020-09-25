﻿; #####################################################################################################################
; # This script checks if the right AHK version is installed and runs the TradeMacro merge script.
; #####################################################################################################################
#SingleInstance, Force
#NoEnv
SetWorkingDir, %A_ScriptDir%

versionFilePath := A_ScriptDir "\resources\VersionTrade.txt"
FileRead, versionFile, %versionFilePath%
error := ErrorLevel

If (not StrLen(versionFile) or error) {
	If (RegExMatch(A_ScriptDir, "i)\.zip$")) {
		MsgBox, 16, PoE-TradeMacro - Critical error, % "You are trying to run PoE-TradeMacro from inside a zip-archive, please unzip the whole folder. `n`nClosing script..."
		ExitApp
	} Else {
		If (not FileExist(versionFilePath)) {
			MsgBox, 16, PoE-TradeMacro - Critical error, % "Script couldn't find the file """ A_ScriptDir "\resources\VersionTrade.txt"". `n`nClosing script..."
		} Else {
			msg := "Script couldn't read/access the file """ A_ScriptDir "\resources\VersionTrade.txt"". "
			msg .= "`n"   "Try running this script as admin if you haven't done so already."
			msg .= "`n`n" "This could also be caused by some other application blocking AHK from reading the file, like your security suite or some application that snycs the drive/folder that the macro is located in."
			msg .= "`n`n" "Closing script..."
			MsgBox, 16, PoE-TradeMacro - Critical error, % msg
		}
		ExitApp
	}
}
Else {
	RegExMatch(versionFile, "i)TradeReleaseVersion.*?:=.*?""(.*?)""", relV)
	TradeReleaseVersion := relV1
	RegExMatch(versionFile, "i)TradeAHKVersionRequired.*?:=.*?""(.*?)""", reqV)
	TradeAHKVersionRequired := reqV1
}

TradeMsgWrongAHKVersion := "AutoHotkey v" . TradeAHKVersionRequired . " or later is needed to run this script. It is important not to run version 2.x. or 1.0. `n`nYou are using AutoHotkey v" . A_AhkVersion . " (installed at: " . A_AhkPath . ")`n`nPlease go to http://ahkscript.org to download the most recent version."
If (A_AhkVersion < TradeAHKVersionRequired or A_AhkVersion >= "2.0.00.00" or A_AhkVersion < "1.1.00.00")
{
	MsgBox, 16, Wrong AutoHotkey Version, % TradeMsgWrongAHKVersion
	ExitApp
}

arguments := ""
Loop, %0%  ; For each parameter
{
	arguments .= " " %A_Index%	
}

Run "%A_AhkPath%" "%A_ScriptDir%\resources\ahk\Merge_TradeMacro.ahk" "%A_ScriptDir%" %arguments%
ExitApp