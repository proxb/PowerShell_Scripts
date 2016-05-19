function Test-Port {
<#    
.SYNOPSIS    
    Tests port on computer.  
    
.DESCRIPTION  
    Performing test(s) if port(s) on remote computer(s) is/are open or not. Test is performed by opening the connection using selected protocol TCP/UDP or both.
     
.PARAMETER computer  
    Name of server to test port state
      
.PARAMETER port  
    Port to test 
       
.PARAMETER tcp  
    Use TCP protocol. If any protocol is not selected than TCP is used.
      
.PARAMETER udp  
    Use UDP protocol. If any protocol is not selected than TCP is used.
     
.PARAMETER UDPTimeOut 
    Sets a timeout for UDP port query. (In milliseconds, Default is 1000)  
      
.PARAMETER TCPTimeOut 
    Sets a timeout for TCP port query. (In milliseconds, Default is 1000)
	
.PARAMETER	LocalIP
	Local IP address used to probe. If not specified any - generally based on a route table - will be used.
                 
.NOTES    
    Name: Test-Port.ps1  
    Author: Boe Prox  
    Updated by: Wojciech Sciesinski, https://www.linkedin.com/in/sciesinskiwojciech  
    DateCreated: 18Aug2010 
	Version: 20160519a
    
	List of Ports: https://www.iana.org/assignments/port-numbers
	
    To Do:  
    Add capability to run background jobs for each host to shorten the time to scan.         
.LINK    
    https://boeprox.wordpress.org 
	
.LINK
	https://github.com/proxb/PowerShell_Scripts
     
.EXAMPLE    
    Test-Port -computer 'server' -port 80  
    
	Server   : server
	Port     : 3389
	TypePort : TCP
	Open     : True
	LocalIP  : 0.0.0.0
	Notes    :
	
	Checks port 3389 on server 'server' to see if it is listening  
    
.EXAMPLE    
    'server' | Test-Port -port 80  
    	
	Server   : server
	Port     : 80
	TypePort : TCP
	Open     : True
	LocalIP  : 0.0.0.0
	Notes    :
    
	Checks port 80 on server 'server' to see if it is listening
	
.EXAMPLE    
    Test-Port -computer @("server1","server2") -port 80  
	
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
    
.EXAMPLE
    Test-Port -comp dc1 -port 17 -udp -UDPtimeout 10000
    
    Server   : dc1
    Port     : 17
    TypePort : UDP
    Open     : True
	LocalIP  : 0.0.0.0
    Notes    : 
    
    Queries port 17 (qotd) using the UDP protocol and returns whether port is open or not.
	
.EXAMPLE
	Test-Port -Computer server3 -Port 53 -UDP -LocalIP 192.168.13.2
	
	Server   : server3
    Port     : 53
    TypePort : UDP
    Open     : True
	LocalIP  : 192.168.13.2
    Notes    : 
	
	Checks port 53 using the UDP protocol on destination computer with the name server3 using as a source interface with IP address 192.168.13.2 assigned
       
.EXAMPLE    
    @("server1","server2") | Test-Port -port 80  
    
	Checks port 80 on server1 and server2 to see if it is listening.  
      
.EXAMPLE    
    (Get-Content hosts.txt) | Test-Port -port 80  
    
	Checks port 80 on servers in host file to see if it is listening. 
     
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port 80 
	
    Checks port 80 on servers in host file to see if it is listening 
        
.EXAMPLE    
    Test-Port -computer (Get-Content hosts.txt) -port @(1..59)  
    
	Checks a range of ports from 1-59 on all servers in the hosts.txt file
	

            
#>    
    [cmdletbinding(
                   DefaultParameterSetName = '',
                   ConfirmImpact = 'low'
                   )]
    Param (
        [Parameter(
                   Mandatory = $True,
                   Position = 0,
                   ParameterSetName = '',
                   ValueFromPipeline = $True)]
        [array]$computer,
        [Parameter(
                   Position = 1,
                   Mandatory = $True,
                   ParameterSetName = '')]
        [ValidateRange(0, 65535)]
        [array]$port,
        [Parameter(
                   Mandatory = $False,
                   ParameterSetName = '')]
        [int]$TCPtimeout = 1000,
        [Parameter(
                   Mandatory = $False,
                   ParameterSetName = '')]
        [int]$UDPtimeout = 1000,
        [Parameter(
                   Mandatory = $False,
                   ParameterSetName = '')]
        [switch]$TCP,
        [Parameter(
                   Mandatory = $False,
                   ParameterSetName = '')]
        [switch]$UDP,
        [Parameter(
                   Mandatory = $False,
                   ParameterSetName = '')]
        [ipaddress]$LocalIP
    )
    Begin {
        If (!$tcp -AND !$udp) { $tcp = $True }
        #Typically you never do this, but in this case I felt it was for the benefit of the function  
        #as any errors will be noted in the output of the report          
        #$ErrorActionPreference = "SilentlyContinue"  
        $report = New-Object System.Collections.ArrayList
    }
    Process {
        ForEach ($c in $computer) {
            ForEach ($p in $port) {
                If ($tcp) {
                    #Create temporary holder   
                    $temp = "" | Select-Object -Property Server, Port, TypePort, Open, LocalIP, Notes
                    
                    #If LocalIP value is provided create IPEndPoint object
                    # and use it in the constructor Socket constractor 
                    
                    If ($LocalIP) {
                        #Create object for connecting to port on computer, provided local IP is used as source
                        $EndPoint = New-Object System.Net.IPEndPoint ($LocalIP, 0)
                        Try {
                            $tcpobject = new-Object Net.Sockets.TcpClient $EndPoint -ErrorAction Continue
                        }
                        Catch {
                            [String]$MessageText = "Network address {0} is not available on the local computer." -f $LocalIP
                            Throw $MessageText
                        }
                        $tempLocalIP = $LocalIP
                        
                        #If LocalIP value is not provide use any local IP
                    }
                    Else {
                        #Create object for connecting to port on computer
                        $tcpobject = new-Object system.Net.Sockets.TcpClient
                        [ipaddress]$tempLocalIP = "0.0.0.0"
                    }
                    
                    #Connect to remote machine's port                
                    $connect = $tcpobject.BeginConnect($c, $p, $null, $null)
                    
                    $connec.s
                    
                    #Configure a timeout before quitting  
                    $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout, $false)
                    #If timeout  
                    If (!$wait) {
                        #Close connection  
                        $tcpobject.Close()
                        Write-Verbose "Connection Timeout"
                        #Build report  
                        $temp.Server = $c
                        $temp.Port = $p
                        $temp.TypePort = "TCP"
                        $temp.Open = $False
                        $temp.LocalIP = $tempLocalIP
                        $temp.Notes = "Connection to Port Timed Out"
                    }
                    Else {
                        $error.Clear()
                        $tcpobject.EndConnect($connect) | out-Null
                        #If error  
                        If ($error[0]) {
                            #Begin making error more readable in report  
                            [string]$string = ($error[0].exception).message
                            $message = (($string.split(":")[1]).replace('"', "")).TrimStart()
                            $failed = $true
                        }
                        #Close connection      
                        $tcpobject.Close()
                        #If unable to query port to due failure  
                        If ($failed) {
                            #Build report  
                            $temp.Server = $c
                            $temp.Port = $p
                            $temp.TypePort = "TCP"
                            $temp.Open = $False
                            $temp.LocalIP = $tempLocalIP
                            $temp.Notes = "$message"
                        }
                        Else {
                            #Build report  
                            $temp.Server = $c
                            $temp.Port = $p
                            $temp.TypePort = "TCP"
                            $temp.Open = $True
                            $temp.LocalIP = $tempLocalIP
                            $temp.Notes = ""
                        }
                    }
                    #Reset failed value  
                    $failed = $Null
                    #Merge temp array with report              
                    $report.add($temp) | Out-Null
                }
                If ($udp) {
                    #Create temporary holder   
                    $temp = "" | Select-Object -Property Server, Port, TypePort, Open, LocalIP, Notes
                    
                    #If LocalIP value is provided create IPEndPoint object
                    # and use it in the constructor Socket constractor
                    If ($LocalIP) {
                        #Create object for connecting to port on computer, provided local IP is used as source
                        $EndPoint = New-Object System.Net.IPEndPoint ($LocalIP, 0)
                        Try {
                            $udpobject = new-Object Net.Sockets.Udpclient $EndPoint -ErrorAction Continue
                        }
                        Catch {
                            [String]$MessageText = "Network address {0} is not available on the local computer." -f $LocalIP
                            Throw $MessageText
                        }
                        
                        $tempLocalIP = $LocalIP
                        #If LocalIP value is not provide use any local IP
                    }
                    Else {
                        #Create object for connecting to port on computer, any local IP is used  
                        $udpobject = new-Object system.Net.Sockets.Udpclient
                        [ipaddress]$tempLocalIP = "0.0.0.0"
                    }
                    
                    #Set a timeout on receiving message 
                    $udpobject.client.ReceiveTimeout = $UDPTimeout
                    
                    #Connect to remote machine's port                
                    Write-Verbose "Making UDP connection to remote server"
                    $udpobject.Connect("$c", $p)
                    #Sends a message to the host to which you have connected. 
                    Write-Verbose "Sending message to remote host"
                    $a = new-object system.text.asciiencoding
                    $byte = $a.GetBytes("$(Get-Date)")
                    [void]$udpobject.Send($byte, $byte.length)
                    #IPEndPoint object will allow us to read datagrams sent from any source.  
                    Write-Verbose "Creating remote endpoint"
                    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any, 0)
                    Try {
                        #Blocks until a message returns on this socket from a remote host. 
                        Write-Verbose "Waiting for message return"
                        $receivebytes = $udpobject.Receive([ref]$remoteendpoint)
                        [string]$returndata = $a.GetString($receivebytes)
                        If ($returndata) {
                            Write-Verbose "Connection Successful"
                            #Build report  
                            $temp.Server = $c
                            $temp.Port = $p
                            $temp.TypePort = "UDP"
                            $temp.Open = $True
                            $temp.LocalIP = $tempLocalIP
                            $temp.Notes = $returndata
                            $udpobject.close()
                        }
                    }
                    Catch {
                        If ($Error[0].ToString() -match "\bRespond after a period of time\b") {
                            #Close connection  
                            $udpobject.Close()
                            #Make sure that the host is online and not a false positive that it is open 
                            If (Test-Connection -comp $c -count 1 -quiet) {
                                Write-Verbose "Connection Open"
                                #Build report  
                                $temp.Server = $c
                                $temp.Port = $p
                                $temp.TypePort = "UDP"
                                $temp.Open = $True
                                $temp.LocalIP = $tempLocalIP
                                $temp.Notes = ""
                            }
                            Else {
                                <# 
                                It is possible that the host is not online or that the host is online,  
                                but ICMP is blocked by a firewall and this port is actually open. 
                                #>                                
                                Write-Verbose "Host maybe unavailable"
                                #Build report  
                                $temp.Server = $c
                                $temp.Port = $p
                                $temp.TypePort = "UDP"
                                $temp.Open = $False
                                $temp.LocalIP = $tempLocalIP
                                $temp.Notes = "Unable to verify if port is open or if host is unavailable."
                            }
                        }
                        ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host") {
                            #Close connection  
                            $udpobject.Close()
                            Write-Verbose "Connection Timeout"
                            #Build report  
                            $temp.Server = $c
                            $temp.Port = $p
                            $temp.TypePort = "UDP"
                            $temp.Open = $False
                            $temp.LocalIP = $tempLocalIP
                            $temp.Notes = "Connection to Port Timed Out"
                        }
                        Else {
                            $udpobject.close()
                        }
                    }
                    #Merge temp array with report              
                    $report.add($temp) | out-null
                }
            }
        }
    }
    End {
        #Generate Report  
        Return $report
    }
}
