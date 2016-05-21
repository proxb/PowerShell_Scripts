# Test-Port
## SYNOPSIS
Tests port on computer.

## SYNTAX
```powershell
Test-Port [-computer] <Array> [-port] <Array> [-TCPtimeout <Int32>] [-UDPtimeout <Int32>] [-TCP] [-UDP] [-LocalIP <IPAddress>] [<CommonParameters>]
```

## DESCRIPTION
Performing test(s) if port(s) on remote computer(s) is/are open or not. Test is performed by opening the connection using selected protocol TCP/UDP or both.

## PARAMETERS
### -computer &lt;Array&gt;
Name of server to test port state
```
Required?                    true

Position?                    1

Default value

Accept pipeline input?       true (ByValue)

Accept wildcard characters?  false
```

### -port &lt;Array&gt;
Port to test
```
Required?                    true

Position?                    2

Default value

Accept pipeline input?       false

Accept wildcard characters?  false
```

### -TCPtimeout &lt;Int32&gt;
Sets a timeout for TCP port query. (In milliseconds, Default is 1000)
```
Required?                    false

Position?                    named

Default value                1000

Accept pipeline input?       false

Accept wildcard characters?  false
```

### -UDPtimeout &lt;Int32&gt;
Sets a timeout for UDP port query. (In milliseconds, Default is 1000)
```
Required?                    false

Position?                    named

Default value                1000

Accept pipeline input?       false

Accept wildcard characters?  false
```

### -TCP &lt;SwitchParameter&gt;
Use TCP protocol. If any protocol is not selected than TCP is used.
```
Required?                    false

Position?                    named

Default value                False

Accept pipeline input?       false

Accept wildcard characters?  false
```

### -UDP &lt;SwitchParameter&gt;
Use UDP protocol. If any protocol is not selected than TCP is used.
```
Required?                    false

Position?                    named

Default value                False

Accept pipeline input?       false

Accept wildcard characters?  false
```

### -LocalIP &lt;IPAddress&gt;
Local IP address used to probe. If not specified any - generally based on a route table - will be used.
```
Required?                    false

Position?                    named

Default value

Accept pipeline input?       false

Accept wildcard characters?  false
```

## INPUTS


## NOTES
Name: Test-Port.ps1  

Author: Boe Prox  

Updated by: Wojciech Sciesinski, https://www.linkedin.com/in/sciesinskiwojciech  

DateCreated: 18Aug2010

Version: 20160519a



List of Ports: https://www.iana.org/assignments/port-numbers



To Do:  

- Add capability to run background jobs for each host to shorten the time to scan.

## EXAMPLES
### EXAMPLE 1
```powershell
PS C:\>Test-Port -computer 'server' -port 80



Server   : server

Port     : 3389

TypePort : TCP

Open     : True

LocalIP  : 0.0.0.0

Notes    :



Checks port 3389 on server 'server' to see if it is listening
```


### EXAMPLE 2
```powershell
PS C:\>'server' | Test-Port -port 80



Server   : server

Port     : 80

TypePort : TCP

Open     : True

LocalIP  : 0.0.0.0

Notes    :



Checks port 80 on server 'server' to see if it is listening
```


### EXAMPLE 3
```powershell
PS C:\>Test-Port -computer @("server1","server2") -port 80



Server   : server1

Port     : 80

TypePort : TCP

Open     : True

LocalIP  : 0.0.0.0

Notes    :



Server   : server2

Port     : 80

TypePort : TCP

Open     : False

LocalIP  : 0.0.0.0

Notes    : Connection to Port Timed Out



Checks port 80 on server1 and server2 to see if it is listening.
```


### EXAMPLE 4
```powershell
PS C:\>Test-Port -comp dc1 -port 17 -udp -UDPtimeout 10000



Server   : dc1

Port     : 17

TypePort : UDP

Open     : True

LocalIP  : 0.0.0.0

Notes    :



Queries port 17 (qotd) using the UDP protocol and returns whether port is open or not.
```


### EXAMPLE 5
```powershell
PS C:\>Test-Port -Computer server3 -Port 53 -UDP -LocalIP 192.168.13.2



Server   : server3

   Port     : 53

   TypePort : UDP

   Open     : True

LocalIP  : 192.168.13.2

   Notes    :



Checks port 53 using the UDP protocol on destination computer with the name server3 using as a source interface with IP address 192.168.13.2 assigned
```


### EXAMPLE 6
```powershell
PS C:\>@("server1","server2") | Test-Port -port 80



Checks port 80 on server1 and server2 to see if it is listening.
```


### EXAMPLE 7
```powershell
PS C:\>(Get-Content hosts.txt) | Test-Port -port 80



Checks port 80 on servers in host file to see if it is listening.
```


### EXAMPLE 8
```powershell
PS C:\>Test-Port -computer (Get-Content hosts.txt) -port 80



Checks port 80 on servers in host file to see if it is listening
```


### EXAMPLE 9
```powershell
PS C:\>Test-Port -computer (Get-Content hosts.txt) -port @(1..59)



Checks a range of ports from 1-59 on all servers in the hosts.txt file
```
