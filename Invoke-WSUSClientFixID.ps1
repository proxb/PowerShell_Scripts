Function Invoke-WSUSClientFix {
    <#  
    .SYNOPSIS  
        Performs a WSUS client reset on local or remote system.
        
    .DESCRIPTION
        Performs a WSUS client reset on local or remote system.
        
    .PARAMETER Computername
        Name of the remote or local system.
                   
    .NOTES  
        Name: Invoke-WSUSClientFix
        Author: Boe Prox
        DateCreated: 18JAN2012
        DateModified: 28Mar2014  
              
    .EXAMPLE  
        Invoke-WSUSClientFix -Computername 'Server' -Verbose
        
        VERBOSE: Server: Testing network connection
        VERBOSE: Server: Stopping wuauserv service
        VERBOSE: Server: Making remote registry connection to LocalMachine hive
        VERBOSE: Server: Connection to WSUS Client registry keys
        VERBOSE: Server: Removing Software Distribution folder and subfolders
        VERBOSE: Server: Starting wuauserv service
        VERBOSE: Server: Sending wuauclt /resetauthorization /detectnow command
    
        Description
        -----------
        This command resets the WSUS client information on Server.
    #> 
    [cmdletbinding(
        SupportsShouldProcess=$True
    )]
    Param (
        [parameter(ValueFromPipeLine=$True,ValueFromPipeLineByPropertyName=$True)]
        [Alias('__Server','Server','CN')]
        [string[]]$Computername = $Env:Computername
    )
    Begin {
        $reghive = [microsoft.win32.registryhive]::LocalMachine
    }
    Process {
        ForEach ($Computer in $Computername) {
            Write-Verbose ("{0}: Testing network connection" -f $Computer)
            If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
                Write-Verbose ("{0}: Stopping wuauserv service" -f $Computer)
                $wuauserv = Get-Service -ComputerName $Computer -Name wuauserv 
                Stop-Service -InputObject $wuauserv
                
                Write-Verbose ("{0}: Making remote registry connection to {1} hive" -f $Computer, $reghive)
                $remotereg = [microsoft.win32.registrykey]::OpenRemoteBaseKey($reghive,$Computer)
                Write-Verbose ("{0}: Connection to WSUS Client registry keys" -f $Computer)
                $wsusreg1 = $remotereg.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\WindowsUpdate',$True)
                $wsusreg2 = $remotereg.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update',$True)
                
                #Begin deletion of registry values for WSUS Client
                If (-Not [string]::IsNullOrEmpty($wsusreg1.GetValue('SusClientId'))) {
                    If ($PScmdlet.ShouldProcess("SusClientId","Delete Registry Value")) {
                        $wsusreg1.DeleteValue('SusClientId')
                    }
                }
                If (-Not [string]::IsNullOrEmpty($wsusreg1.GetValue('SusClientIdValidation'))) {
                    If ($PScmdlet.ShouldProcess("SusClientIdValidation","Delete Registry Value")) {
                        $wsusreg1.DeleteValue('SusClientIdValidation')
                    }
                }                
                If (-Not [string]::IsNullOrEmpty($wsusreg1.GetValue('PingID'))) {
                    If ($PScmdlet.ShouldProcess("PingID","Delete Registry Value")) {
                        $wsusreg1.DeleteValue('PingID')
                    }
                }
                If (-Not [string]::IsNullOrEmpty($wsusreg1.GetValue('AccountDomainSid'))) {
                    If ($PScmdlet.ShouldProcess("AccountDomainSid","Delete Registry Value")) {
                        $wsusreg1.DeleteValue('AccountDomainSid')
                    }
                }   
                If (-Not [string]::IsNullOrEmpty($wsusreg2.GetValue('LastWaitTimeout'))) {
                    If ($PScmdlet.ShouldProcess("LastWaitTimeout","Delete Registry Value")) {
                        $wsusreg2.DeleteValue('LastWaitTimeout')
                    }
                }
                If (-Not [string]::IsNullOrEmpty($wsusreg2.GetValue('DetectionStartTimeout'))) {
                    If ($PScmdlet.ShouldProcess("DetectionStartTimeout","Delete Registry Value")) {
                        $wsusreg2.DeleteValue('DetectionStartTimeout')
                    }
                }
                If (-Not [string]::IsNullOrEmpty($wsusreg2.GetValue('NextDetectionTime'))) {
                    If ($PScmdlet.ShouldProcess("NextDetectionTime","Delete Registry Value")) {
                        $wsusreg2.DeleteValue('NextDetectionTime')
                    }
                }
                If (-Not [string]::IsNullOrEmpty($wsusreg2.GetValue('AUState'))) {
                    If ($PScmdlet.ShouldProcess("AUState","Delete Registry Value")) {
                        $wsusreg2.DeleteValue('AUState')
                    }
                }
                
                Write-Verbose ("{0}: Removing Software Distribution folder and subfolders" -f $Computer)
                Try {
                    Remove-Item "\\$Computer\c$\Windows\SoftwareDistribution" -Recurse -Force -Confirm:$False -ErrorAction Stop                                                                                         
                } Catch {
                    Write-Warning ("{0}: {1}" -f $Computer,$_.Exception.Message)
                }
                
                Write-Verbose ("{0}: Starting wuauserv service" -f $Computer)
                Start-Service -InputObject $wuauserv
                
                Write-Verbose ("{0}: Sending wuauclt /resetauthorization /detectnow command" -f $Computer)
                Try {
                    Invoke-WmiMethod -Path Win32_Process -ComputerName $Computer -Name Create `
                    -ArgumentList "wuauclt /resetauthorization /detectnow" -ErrorAction Stop | Out-Null
                } Catch {
                    Write-Warning ("{0}: {1}" -f $Computer,$_.Exception.Message)
                }
            }
        }
    }
}
