Option Explicit

Public Const WindowHidden = 0
Public Const ForReading = 1
Public Const ForWriting = 2
Public Const ForAppending = 8

Dim objShell:           Set objShell = CreateObject("WScript.Shell")
Dim objFSO:             Set objFSO = CreateObject("Scripting.FilesystemObject")
Dim strThisComputer:    strThisComputer = objShell.ExpandEnvironmentStrings("%ComputerName%")
Dim strMigBasePath:     strMigBasePath = "c:\MIG"
Dim cMD, iRes
Dim intBit
Dim strDestComputer
Dim strComputer:        strComputer = "."
Dim objWMI, colOperatingSystems
Dim i, strOSVer, f, bHLink
Dim strUSMTSrc:         strUSMTSrc = "c:\USMTSTUFF"
Dim strStorePath:       strStorePath = "\USMT"
Dim strDestFile:        strDestFile = "c:\dest.txt"
Dim strDExist:          strDExist = False
Dim strMode
bHLink = False  'default to no hardlink

GetArgs()
If strMode = "SCAN" Then
        'run scanstate tasks
        wscript.echo "Running ScanState tasks"
        ChkPath(strMigBasePath)
        ChkOSVer()
        GetUSMTSrc()
        ChkDestAlive()
        RunScanState()
Else
        'run loadstate tasks
        wscript.echo "Running LoadState tasks"
        ChkPath(strMigBasePath)
        ChkPath("c:"&strStorePath)
        SharePath()
        ChkOSVer()
        GetUSMTSrc()
        ChkDrive()
        RunLoadState()
End If

'will only get this far if successful
wscript.echo "SUCCESSFULLY COMPLETED"
Wscript.quit(0)

Sub GetArgs()
        Dim colNamedArgs
        strMode = "NA"
        Set colNamedArgs = WScript.Arguments.Named
        If colNamedArgs.Exists(UCase("MODE")) Then
                Select Case UCase(colNamedArgs.Item(UCase("MODE")))
                        Case "SCAN"
                                strMode = "SCAN"
                        Case "LOAD"
                                strMode = "LOAD"
                        Case Else
                                strMode = "NA"
                End Select
        End If
        If strMode = "NA" Then 
                WScript.Echo "/Mode not defined"
                WScript.Quit(-99)
        End If
End Sub

Sub SharePath()
        cMD = "net share usmt=c:\usmt /GRANT:Everyone,FULL"
        iRes = objShell.Run(cMD, WindowHidden, True)
        If iRes <> 0 Then
                wscript.echo "Error creating share: " & iRes
                wscript.quit(-1)
        Else
                wscript.echo "SUCCESS creating USMT share!"
        End If
        cMD = "Icacls c:\usmt /grant Everyone:F /inheritance:e /T"
        iRes = objShell.Run(cMD, WindowHidden, True)
        If iRes <> 0 Then
                wscript.echo "Error fixing share permissions: " & iRes
                wscript.quit(-1)
        Else
                wscript.echo "SUCCESS fixing share permissions!"
        End If
End Sub

Sub ChkOSVer()
        'get OS version
        Set objWMI = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
        Set colOperatingSystems = objWMI.ExecQuery("Select * from Win32_OperatingSystem")
        For Each i in colOperatingSystems
                strOSVer = i.Version
        Next

        Select Case Mid(strOSVer,1,3)
                Case "5.1"
                        strOSVer = "XP"
                        strUSMTSrc = strUSMTSrc & "\USMT5"
                Case "6.1"
                        strOSVer = "7"
                        strUSMTSrc = strUSMTSrc & "\USMT6.3"
                Case "6.2"
                        strOSVer = "8"
                        strUSMTSrc = strUSMTSrc & "\USMT6.3"
                Case "6.3"
                        strOSVer = "8.1"
                        strUSMTSrc = strUSMTSrc & "\USMT6.3"
                Case Else
                        'dont know about you
                        wscript.echo "ERROR UNKNOWN OS"
                        Wscript.Quit(-1)
        End Select


        'What Arch are we running 32 or 64bit?
        intBit = GetObject("winmgmts:root\cimv2:Win32_Processor='cpu0'").AddressWidth

        If intBit = 32 Then
                'build 32bit path to USMT
                strUSMTSrc = strUSMTSrc & "\x86\"
        Else
                'build 64bit path to USMT
                strUSMTSrc = strUSMTSrc & "\amd64\"
        End If
End Sub

Sub GetUSMTSrc()
        'Get the files
        cMD = "xcopy.exe """ & strUSMTSrc & "*.*"" " & strMigBasePath & "\ /s /y"
        iRes = objShell.Run (cMD, WindowHidden, True)
        If iRes <> 0 Then
                Wscript.Echo "Error moving USMT files"
                WScript.Quit(-1)
        End If
        'move the xml templates that drive scanstate
        cMD = "xcopy.exe """ & strUSMTSrc & "\..\..\conf\*.*"" " & strMigBasePath & "\ /s /y"
        iRes = objShell.Run (cMD, WindowHidden, True)
        If iRes <> 0 Then
                Wscript.Echo "Error moving USMT xml"
                WScript.Quit(-1)
        End If
End Sub

Sub ChkDestAlive()
        'find the dest computer
        If Not objFSO.FileExists(strDestFile) Then
                strDestComputer = Inputbox("Please enter the destination computername","Input Required")
                If strDestComputer = "" Then
                        'no input detected
                        wscript.echo "No destination computer defined. Quiting"
                        WScript.Quit(-1)
                End If
        Else
                Set f = objFSO.OpenTextFile(strDestFile, FORREADING)
                strDestComputer = f.ReadLine
                f.Close
        End If

        strStorePath = "\\" & strDestComputer & strStorePath

        If UCase(strDestComputer) = "LOCALHOST" Or UCase(strDestComputer) = UCase(strThisComputer) Then
                'assume we want a hardlink
                bHLink = True
        Else
                'make sure we can connect to the dest
                Set f = objFSO.CreateTextFile("c:\chkdest.txt",True)
                f.Write "check" & vbCrLf
                f.Close
                cMD = "xcopy.exe c:\chkdest.txt " & strStorePath & "\ /y"
                iRes = objShell.Run(cMD, WindowHidden, True)
                If iRes <> 0 Then
                        wscript.echo "Error connecting to destination computer"
                        Wscript.Quit(-1)
                End If
        End If
End Sub

Sub RunScanState()
        'Build USMT scanstate
        cMD = strMigBasePath & "\scanstate.exe" & " " & strStorePath &_
                " /o" &_
                " /ue:" & strThisComputer & "\Administrator" &_
                " /ue:" & strThisComputer & "\Admin" &_
                " /UEL:365" &_
                " /Config:c:\mig\config.xml" &_
                " /i:c:\mig\Mig.xml" &_
                " /i:c:\mig\MigApp.xml" &_
                " /i:c:\mig\MigDocs.xml" &_
                " /i:c:\mig\MigUser.xml" &_
                " /v:13 /l:c:\scanstate.log"
        If bHLink Then cMD = cMD & " /hardlink /nocompress"

        iRes = objShell.Run(cMD, WindowHidden, True)
        If iRes <> 0 Then
                wscript.echo "Error Received running scanstate: " & iRes
                wscript.quit(-1)
        Else
                wscript.echo "SUCCESS!"
        End If

        'copy the scanstate log so the dest knows it can restore
        cMD = "xcopy.exe c:\scanstate.log " & strStorePath & "\ /y"
        iRes = objShell.Run(cMD, WindowHidden, True)
        If iRes <> 0 Then
                wscript.echo "Error connecting to destination computer"
                Wscript.Quit(-1)
        End If
        If bHLink Then
                'put a file so loadstate knows it is a hardlink
                Set f = objFSO.CreateTextFile("c:\usmt\HARDLINK.txt",True)
                f.Write "HARDLINK" & vbCrLf
                f.Close
        End If
End Sub

Sub RunLoadState()
        'Build USMT loadstate
        Dim intSleep:   intSleep = 120 * 1000           '120 seconds.. * 1000 is because it is in ms..
        Dim strScanStateLoc: strScanStateLoc = "c:\usmt\scanstate.log"
        Dim strMigXML: strMigXML = "c:\mig\Mig.xml"
        'pre check to see if this is a hardlink store
        If objFSO.FileExists("c:\usmt\HARDLINK.txt") Then
                'we are restoring from a hardlink
                bHLink = True
        End If

        cMD = strMigBasePath & "\loadstate.exe C:\usmt" &_
                " /ue:" & strThisComputer & "\Administrator" &_
                " /ue:" & strThisComputer & "\Admin" &_
                " /i:" & strMigXML  &_
                " /i:c:\mig\MigApp.xml" &_
                " /i:c:\mig\MigDocs.xml" &_
                " /i:c:\mig\MigUser.xml" &_
                " /v:13 /l:c:\loadstate.log"
        If bHLink Then cMD = cMD & " /hardlink /nocompress"

        wscript.echo cMD
        'make sure the scanstate.log exists
        Do While Not objFSO.FileExists(strScanStateLoc)
                wscript.echo "Waiting for scanstate...."
                wscript.sleep intSleep
        Loop
        iRes = objShell.Run(cMD, WindowHidden, True)
        If iRes <> 0 Then
                wscript.echo "Error Received running loadstate: " & iRes
                wscript.quit(-1)
        Else
                wscript.echo "SUCCESS!"
        End If
End Sub

Sub ChkDrive()
        If objFSO.DriveExists("D:") Then
                strDExist = True
        End If
End Sub

Function ChkPath(thePath)
        'does path exist
        If Not objFSO.FolderExists(thePath) Then
                Dim aTemp, d, p
                'build path
                aTemp = split(thePath,InStrRev(thePath,"\"))
                p = ""
                For Each d in aTemp
                        If p <> "" Then p = p & "\"
                        p = p&d
                        If Not objFSO.FolderExists(p) Then objFSO.CreateFolder(p)
                Next
        End If
