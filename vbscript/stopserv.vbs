strComputer = "."
Set objWMIService = GetObject("winmgmts:" & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
Set colOperatingSystems = objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
For Each objOperatingSystem in colOperatingSystems
    osnamed = objOperatingSystem.Caption
    res = InStr(UCase(osnamed), "SERVER")
    if res > 0 then
        wscript.echo "YOUR ON A SERVER LOGON SCRIPT WILL NOT RUN!!"
        wscript.quit
    end if
Next
