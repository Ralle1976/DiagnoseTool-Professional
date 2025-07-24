#include-once
#include <File.au3>
#include "constants.au3"
#include "parsers\parser_manager_enhanced.au3"

Func _FindLogFilesWithProgress($sPath)
    Local $aLogFiles[0]
    
    If Not FileExists($sPath) Then 
        ConsoleWrite("Fehler: Pfad existiert nicht - " & $sPath & @CRLF)
        Return $aLogFiles
    EndIf
    
    Local $aDirs = _FileListToArrayRec($sPath, "*", $FLTAR_DIRS)
    If @error Then 
        ConsoleWrite("Fehler beim Suchen von Verzeichnissen" & @CRLF)
        Return $aLogFiles
    EndIf
    
    For $i = 1 To $aDirs[0]
        Local $sTempFiles = _FileListToArrayRec($aDirs[$i], "*.log", $FLTAR_FILES)
        If Not @error Then
            _ArrayAdd($aLogFiles, $sTempFiles, 1)
        EndIf
    Next
    
    Return $aLogFiles
EndFunc
