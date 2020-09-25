#NoTrayIcon
#NoEnv
#SingleInstance force
FileEncoding , UTF-8
SetWorkingDir %A_ScriptDir%

IfNotExist, Lib
{
	FileCreateDir, Lib
}
FileDelete, Lib\QDL.ahk
str := "#NoTrayIcon`nSetWorkingDir %A_MyDocuments%\AutoHotKey\LutTools`nUrlDownloadToFile,%1%,%2%`nIfNotExist, %2%`n{`nFileAppend,ERROR,%2%`n}"
FileAppend, %str%, Lib\QDL.ahk

IfNotExist, cports.exe
{
UrlDownloadToFile, http://lutbot.com/ahk/cports.exe, cports.exe
	if ErrorLevel
			msgbox, We couldn't download cports.exe, this is used as a fallback to the normal logout method. The logout functionality may not work until this is resolved. Please download cports.exe from http://lutbot.com/ahk/cports.exe and place it in %A_MyDocuments%\AutoHotKey.
UrlDownloadToFile, http://lutbot.com/ahk/cports.chm, cports.chm
UrlDownloadToFile, http://lutbot.com/ahk/readme.txt, readme.txt
}

IfNotExist, settings.ini
{
	defaultIni := "[variables]`n"
	defaultIni .= "CharacterName=`n"
	defaultIni .= "AccountName=`n"
	defaultIni .= "League=`n"
	defaultIni .= "PoeSteam=0`n"
	defaultIni .= "XOffset=0`n"
	defaultIni .= "YOffset=0`n"
	defaultIni .= "WAXoffset=0`n"
	defaultIni .= "WAYoffset=0`n"
	defaultIni .= "ColorBG=11213a`n"
	defaultIni .= "ColorText=c9d4e5`n"
	defaultIni .= "OverlayToggle=0`n"
	defaultIni .= "SoundSelector=*-1`n"
	defaultIni .= "Beta=1`n"
	defaultIni .= "Scroll=1`n"
	defaultIni .= "Diablo2=0`n"
	defaultIni .= "HighBits=1`n"
	defaultIni .= "Duration1=4000`n"
	defaultIni .= "Duration2=4000`n"
	defaultIni .= "Duration3=4000`n"
	defaultIni .= "Duration4=4000`n"
	defaultIni .= "Duration5=4000`n"
	defaultIni .= "Duration6=4000`n"
	defaultIni .= "Duration7=4000`n"
	defaultIni .= "CooldownColor1=ffff00`n"
	defaultIni .= "CooldownColor2=ff0000`n"
	defaultIni .= "CooldownColor3=00ffff`n"
	defaultIni .= "CooldownColor4=ffffff`n"
	defaultIni .= "CooldownColor5=00ff00`n"
	defaultIni .= "CooldownColor6=0000ff`n"
	defaultIni .= "CooldownColor7=ff00ff`n"
	defaultIni .= "RunHeavy=1`n"
	defaultIni .= "[whisperMessages]`n"
	defaultIni .= "wm1=One moment, I'm in a map.`n"
	defaultIni .= "wm2=Sorry, That item has already been sold.`n"
	defaultIni .= "wm3=Type a sentence here`n"
	defaultIni .= "wm4=Type a sentence here`n"
	defaultIni .= "wm5=Type a sentence here`n"
	defaultIni .= "[partyMessages]`n"
	defaultIni .= "pm1=Type messages here`n"
	defaultIni .= "pm2=Accepts regular messages like this`n"
	defaultIni .= "pm3=#or global messages like this`n"
	defaultIni .= "pm4=%also party messages`n"
	defaultIni .= "pm5=&don't spam your guild!`n"
	defaultIni .= "pm6=we can use commands too`n"
	defaultIni .= "pm7=/passives`n"
	defaultIni .= "pm8=or go afk`n"
	defaultIni .= "pm9=/afk i gotta poo`n"
	defaultIni .= "pm10=the possibilties are endless`n"
	defaultIni .= "[hotkeys]`n"
	defaultIni .= "logout=```n"
	defaultIni .= "superLogout=F12`n"
	defaultIni .= "oos=F2`n"
	defaultIni .= "remaining=F3`n"
	defaultIni .= "whois=F4`n"
	defaultIni .= "kick=F8`n"
	defaultIni .= "hideout=F5`n"
	defaultIni .= "invite=F6`n"
	defaultIni .= "toggleOverlay=F9`n"
	defaultIni .= "options=F10`n"
	defaultIni .= "priceCheck=F7`n"
	defaultIni .= "cooldown1=r`n"
	defaultIni .= "cooldown2=q`n"
	defaultIni .= "cooldown3=1`n"
	defaultIni .= "cooldown4=2`n"
	defaultIni .= "cooldown5=3`n"
	defaultIni .= "cooldown6=4`n"
	defaultIni .= "cooldown7=5`n"
	defaultIni .= "wm1=^1`n"
	defaultIni .= "wm2=^2`n"
	defaultIni .= "wm3=^3`n"
	defaultIni .= "wm4=^4`n"
	defaultIni .= "wm5=^5`n"
	defaultIni .= "pm1=!1`n"
	defaultIni .= "pm2=!2`n"
	defaultIni .= "pm3=!3`n"
	defaultIni .= "pm4=!4`n"
	defaultIni .= "pm5=!5`n"
	defaultIni .= "pm6=!6`n"
	defaultIni .= "pm7=!7`n"
	defaultIni .= "pm8=!8`n"
	defaultIni .= "pm9=!9`n"
	defaultIni .= "pm10=!0"

	FileAppend, %defaultIni%, settings.ini, UTF-16
}

ExitApp