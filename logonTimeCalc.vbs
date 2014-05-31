On Error Resume Next
Const FORREADING = 1, FORWRITING = 2, FORAPPENDING = 8
Set fso = WScript.CreateObject("Scripting.FileSystemObject")
Set objShell = WScript.CreateObject("WScript.Shell")

'set log debug echo
DBUG = 1

strComputerName = objShell.ExpandEnvironmentStrings("%ComputerName%")

locallogPath = "d:\"
remotelogPath = "d:\"
logName = "LogOnDetails.log"
logNameSQLRem = "sql.txt"

Dim objWMI, colSession, objSession
Set objWMI = GetObject("winmgmts:\\.\root\CIMV2")
Set colSession = objWMI.ExecQuery("Select * from Win32_LogonSession Where LogonType='2'")
For Each objSession in colSession
 strID = objSession.LogonId
 strStart = objSession.StartTime
	if strID <> "" Then
		Exit For
	End If
Next
'to make it work on Win7
If strID = "" Then
	Set colSession = objWMI.ExecQuery("Select * from Win32_LogonSession where LogonType='0'")
	For Each objSession in colSession
 		strID = objSession.LogonId
 		strStart = objSession.StartTime
		if strID <> "" then
			exit for
		end if
	Next
End If

wscript.echo strID & " " & strStart

'We do all the date/time stuff now before the user based stuff otherwise our timings will be messed up due to the time taken for the AD queries
strStartDate = ConvertUTCStringToDate(strStart)
strSessionTimeUTC = DateDiff("s",ConvertUTCStringToDate(strstart),Now())
strSessionTimeDate = ConTime(DateDiff("s",ConvertUTCStringToDate(strstart),Now()))
'If users run the script manually strSessionTimeDate will not be populated if they have been logged on to long so we will chuck in NA here
if strSessionTimeDate = "::" Then
	strSessionTimeDate = "NA"
end if
'Now we have all our time based data we will find AD based data to get the logon site etc

strUserN = FindUser(strID)
strDomain = GetDomain()
strADSite = Check_AD_Site()

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' logging

'set log locally
WhereToLog = locallogPath & logName
LogLocal()

'set log remote in SQL format
WhereToLog = remotelogPath & logNameSQLRem
LogRemote()

' logging
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Sub LogLocal()
	On Error Resume Next
	'now log it
	wLog "-------------------------------------------"
	wLog "Log on Date: " & strStartDate
	wLog "Log on Workstation: " & strComputerName
	wLog "Log on User: " & strUserN
	wLog "Seconds since logon: " & strSessionTimeUTC
	wLog "Time since logon: " & strSessionTimeDate
	wLog "Logon Domain: " & strDomain
	wLog "Logon AD Site: " & strADSite
End Sub

Sub LogRemote()
	On Error Resume Next
	'formatted sessionstart,sessiontimeinUTC,sessiontimeindate,username,computername,domain,adsite
	'now log it
	wLog """" & strStartDate & """,""" & _
	strSessionTimeUTC & """,""" & _
	strSessionTimeDate & """,""" & _
	strUserN & """,""" & _
	strComputerName & """,""" & _
	strDomain & """,""" & _
	strADSite & """"
End Sub

Sub wLog(msg)
        set LogFile = fso.OpentextFile(WhereToLog, FORAPPENDING, 1)
	If DBUG = 1 then wscript.echo msg
        LogFile.WriteLine msg
        LogFile.Close
end Sub

Function Check_AD_Site()
        On Error Resume Next
        Dim site, objitem, IP
        
        Set objSysInfo = CreateObject("ADSystemInfo")
        site = UCase(objSysInfo.SiteName)
        Set objSysInfo = Nothing
        If Len(site) < 1 Then
         wLog "Error detecting AD Site via ADSystemInfo, attempting AD Query for site name"
         Set objWMIService = GetObject("winmgmts:" _
          & "{impersonationLevel=impersonate}!\\.\root\cimv2")
         Set colItems = objWMIService.ExecQuery _
          ("Select * From Win32_NetworkAdapterConfiguration Where IPEnabled = True")
         for Each objitem in colItems
          IP = Join(objitem.IPAddress, ",")
          'wscript.echo "Captured 1st interface IP: " & IP
          Exit For
         Next
         If not InStr(IP) = "10." Or Not intstr(IP) = "172." Or Not InStr(IP) = "192.168." then
          'do nothing as we don't seen to have a priv IP
         Else
          site = GetSiteName(IP)
         End If
         If Len(site) < 1 Then
           'wscript.echo "ERROR The machine appears to not fall under an AD site or is currently not connected to the production network"
         End If
        End If
        If Len(site) > 0 Then
         'wscript.echo "AD Site of machine: " & site
        End If
        Check_AD_Site = site
End Function
 
Function ConvertUTCStringToDate(theUTCTime)
 On Error Resume Next
 
 ConvertUTCStringToDate = CDate(Mid(theUTCTime, 7, 2) & "/" & _
  Mid(theUTCTime, 5, 2) & "/" & Left(theUTCTime, 4) _
  & " " & Mid(theUTCTime, 9, 2) & ":" & _
  Mid(theUTCTime, 11, 2) & ":" & Mid(theUTCTime, 13, 2))
End Function
 
Function FindUser(strID)
 On Error Resume Next
 Set objWMI = GetObject("winmgmts:\\.\root\CIMV2")
 Set colUser = objWMI.ExecQuery("ASSOCIATORS OF {Win32_LogonSession.LogonId='" & strID & "'} Where ResultClass=Win32_UserAccount")
 For Each objUser in colUser
  strUser = objUser.Name
 Next
	FindUser = strUser
End Function
 
Function GetDomain()
        On Error Resume Next
 
        Dim objWMIService
        Dim colComputerSystem, objComputerSystem
 
        'Get the Resource Domain of this machine
        Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
        If Err.Number <> 0 Then
         	'wLog "ERROR connecting to WMI: " & Err.Number
  		Set objWMIService = Nothing
 		GetDomain = "NOTFOUND"
         	Exit Function
 	End If
 
        Set colComputerSystem = objWMIService.ExecQuery("Select * from win32_ComputerSystem",,48)
        For Each objComputerSystem In colComputerSystem
         GetDomain = objComputerSystem.Domain
        Next
End Function
 
Function GetSiteName(IPAddr)
        Dim DecIP, SubnetContainer, LDAPQry
        Dim SiteAddrs, MaskBits, NumAddrs
        Dim LoIPAddr, HiIPAddr
        
        SiteNamez = "NOTFOUND" ' Fallback if site not found
        DecIP = Dot2Dec(IPAddr) ' Convert decimal
        
        '/// AD QUERY FOR SITES \\\'
        ConfigNameContext =           GetObject("LDAP://RootDSE").Get("configurationNamingContext")
        SubnetContainer = "CN=Subnets,CN=Sites," & ConfigNameContext
        LDAPQry = "<LDAP://" & SubnetContainer &              ">;(objectCategory=subnet);cn,siteObject"
        Set AdConn = CreateObject("ADODB.Connection")
        AdConn.Provider = "ADsDSOObject"
        AdConn.Properties("Timeout") = 60
        AdConn.Open "Active Directory Provider"
        Set AdCmd = CreateObject("ADODB.Command")
        Set AdCmd.ActiveConnection = AdConn
        AdCmd.Properties("SearchScope") = 2
        AdCmd.Properties("Page Size") = 1000
        AdCmd.CommandText = LDAPQry
        Set RS = AdCmd.Execute
        '/// AD QUERY FOR SITES \\\'
        
        SiteAddrs = (2^31)-1
        
        RS.MoveFirst
        While Not RS.EOF
         Subnet = RS.Fields("cn")
         MaskBits = Split(Subnet,"/")
         NumAddrs = (2 ^ (32 - MaskBits(1))) - 1 'calc addresses in range
         LoIPAddr = Dot2Dec(MaskBits(0))
         HiIPAddr = LoIPAddr + NumAddrs
         ' Check in range and set!!
         If DecIP => LoIPAddr And DecIP <= HiIPAddr And NumAddrs <=SiteAddrs then
          SiteNamez = RS.Fields("siteObject")
          SiteNamez = GetObject("LDAP://" & RS.Fields("siteObject")).Get("name")
          'wscript.echo SiteNamez
          GetSiteName = SiteNamez
         End If
         RS.MoveNext
        Wend
        
        Set RS = Nothing
        Set AdCmd = Nothing
        Set AdConn = Nothing
End function
 
Function Dot2Dec(IPAddress)
        Dim Octets
        Octets = Split(IPAddress,".")
        Dot2Dec = (Octets(0)*(2^24)) + (Octets(1)*(2^16)) + (Octets(2)*(2^8)) + Octets(3)
End Function
 
Function ConTime(sec)
On Error Resume Next
 ConvSec = sec Mod 60
 If Len(ConvSec) = 1 Then
  ConvSec = "0" & ConvSec
 End If
 ConvMin = (sec Mod 3600) \ 60
 If Len(ConvMin) = 1 Then
  ConvMin = "0" & ConvMin
 End If
 ConvHour = sec \ 3600
 If Len(ConvHour) = 1 Then
  ConvHour = "0" & ConvHour
 End If
 ConTime = ConvHour & ":" & ConvMin & ":" & ConvSec
End Function
