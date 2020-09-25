#NoTrayIcon
SetWorkingDir %A_MyDocuments%\AutoHotKey\LutTools
UrlDownloadToFile,%1%,%2%
IfNotExist, %2%
{
FileAppend,ERROR,%2%
}