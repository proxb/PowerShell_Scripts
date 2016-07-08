Function Get-ExchangeCachedMode {
    <#
        .SYNOPSIS
            Retrieves the CachedMode setting for Outlook 2010 on a workstation.
            
        .DESCRIPTION
            Retrieves the CacheMode setting for Outlook 2010 on a workstation.
            
        .PARAMETER Computername
            Collection of computers to check for the CachedMode setting.
            
        .PARAMETER Throttle
            Used to determine how many asynchronous jobs to run.
        
        .NOTES
            Name: Get-ExchangeCachedMode
            Author: Boe Prox
        
        .EXAMPLE
        
        Get-ExchangeCachedMode -Computername Computer01

        Computername   : Computer01
        SID            : S-1-5-21-0133314170-616249376-839522115-56832
        OutlookProfile : Outlook
        CachedMode     : Disabled
        RegValue       : 4,16,0,0
        isLoggedOn     : True
        RegKey         : 600aa55f87091746a6c0ff6a2b78af55
        RegValueName   : 00036601
        User           : Rivendell\PROXB

        Computername   : Computer01
        SID            : S-1-5-21-0133314170-839522115-616249376-56832
        OutlookProfile : proxb
        CachedMode     : Disabled
        RegValue       : 4,16,0,0
        isLoggedOn     : True
        RegKey         : 5470707acae06d4f9d9dd7dfdf21dab5
        RegValueName   : 00036601
        User           : Rivendell\PROXB   

        Computername   : Computer01
        SID            : S-1-5-21-634939626-536326981-3066512030-1001
        OutlookProfile : Outlook
        CachedMode     : Disabled
        RegValue       : 4,16,0,0
        isLoggedOn     : True
        RegKey         : 5689237acae06d4f9d9dd7dfdf7r8g9u
        RegValueName   : 00036601
        User           : Rivendell\SMITHB   
        
        Description
        -----------     
        Performs a query for the CachedMode setting against a remote system.
    #>
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeLine=$True,ValueFromPipeLineByPropertyName=$True)]
        [string[]]$Computername = $Env:Computername,
        [parameter()]
        [int]$Throttle = 15        
    )
    Begin {
        #Required Functions        
        Function Get-RunspaceData {
            [cmdletbinding()]
            param(
                [switch]$Wait
            )
            Do {
                $more = $false         
                Foreach($runspace in $runspaces) {
                    If ($runspace.Runspace.isCompleted) {
                        $runspace.powershell.EndInvoke($runspace.Runspace)
                        $runspace.powershell.dispose()
                        $runspace.Runspace = $null
                        $runspace.powershell = $null
                        $Script:i++                  
                    } ElseIf ($runspace.Runspace -ne $null) {
                        $more = $true
                    }
                }
                If ($more -AND $PSBoundParameters['Wait']) {
                    Start-Sleep -Milliseconds 100
                }   
                #Clean out unused runspace jobs
                $temphash = $runspaces.clone()
                $temphash | Where {
                    $_.runspace -eq $Null
                } | ForEach {
                    Write-Verbose ("Removing {0}" -f $_.computer)
                    $Runspaces.remove($_)
                }             
            } while ($more -AND $PSBoundParameters['Wait'])
        } #End Function    
        
        #Main collection to hold all data returned from runspace jobs
        $Script:report = @()  
        
        #Define hash table for Get-RunspaceData function
        $runspacehash = @{}   
        
        #Define Scriptblock for runspaces
        $scriptblock = {
            Param ($Computer)
            #Function required for SID to Username translation
            Function ConvertSID-ToUserName {
                [cmdletbinding()]
                Param (
                    [parameter()]
                    [string[]]$SID
                )
                Process {
                    ForEach ($S in $Sid) {
                        Try {
                            $s = [system.security.principal.securityidentifier]$s
                            $user = $s.Translate([System.Security.Principal.NTAccount])
                            New-Object PSObject -Property @{
                                Name = $user.value
                                SID = $s.value
                            }                 
                        } Catch {
                            Write-Warning ("Unable to translate {0}.`n{1}" -f $UserName,$_.Exception.Message)
                        }
                    }
                }
            } #End Function   
            
            #Get logged on user
            Try {
               $Username = (Get-WmiObject -ComputerName $Computer -Class Win32_ComputerSystem -ErrorAction Stop).Username
            } Catch {
                Write-Warning ("{0}: {1}" -f $Computer,$_.Exception.Message)
               $Username = "N\A"
            }
            
            $rootkey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("Users",$computer)

            $SIDs = $rootkey.GetSubKeyNames() | Where {
                $_ -match "^S-1-5-\d{2}-\d{10}-\d{9}-\d{9}-\d{5}$"
            }

            #Match up the SID to a username
            $Hash = @{}
            $SIDs | ForEach {
                $Hash.$_ = (ConvertSID-ToUserName $_ | Select -Expand Name)
                $Hash[$hash.$_] = $_
            }

            $SIDs | ForEach {
                $SID = $_
                Try {
                    If ($hash.$_ -eq $Username) {
                        $LoggedOn = $True
                    } Else {
                        $LoggedOn = $False
                    }                
                    $Key = $rootkey.OpenSubKey("$_\Software\Microsoft\Windows NT\CurrentVersion\")
                    If ($Key.GetSubKeyNames() -Contains "Windows Messaging Subsystem") {
                        $User = $hash.$_
                        $Profiles = $Key.OpenSubKey("Windows Messaging SubSystem\Profiles")
                        Write-Verbose ("Getting list of profiles")
                        $Profiles.GetSubKeyNames() | ForEach {
                            $OutlookProfile = $_
                            $Profile = $Profiles.OpenSubKey(("$_"))
                            $profile.GetSubKeyNames() | ForEach {
                                If ($profile.OpenSubKey("$_").GetValueNames() -Contains "00036601") {
                                    Write-Verbose ("Checking value for Cached Mode on profile: {0}" -f $OutlookProfile)
                                    $RegKey = $_
                                    $Key = $profile.OpenSubKey("$_")
                                    $Value = $Key.GetValue("00036601")
                                    If ((($Value[0] -bor 0x80) -eq $Value[0]) -AND (($Value[1] -bor 0x1) -eq $Value[1])) {
                                        $CachedMode = 'Enabled'
                                    } Else {
                                        $CachedMode = 'Disabled'
                                    }
                                    New-Object PSObject -Property @{
                                        User = $User
                                        OutlookProfile = $OutlookProfile
                                        CachedMode = $CachedMode
                                        RegValue =  ($Value -Join ",")
                                        RegKey = $RegKey
                                        RegValueName = "00036601"
                                        Computername = $Computer
                                        isLoggedOn = $LoggedOn
                                        SID = $SID
                                    }
                                } Else {
                                    Write-Warning ("[$($Computer)]$OutlookProfile")
                                }
                            }
                        }
                    } Else {
                        Write-Warning "Outlook not installed or missing configuration information"
                    }
                } Catch {
                    Write-Warning ("{0}: {1}" -f $Computer,$_.Exception.Message)
                }
            } #End ForEach            
        } #End Scriptblock
        
        Write-Verbose ("Creating runspace pool and session states")
        $sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
        $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
        $runspacepool.Open()  
        
        Write-Verbose ("Creating empty collection to hold runspace jobs")
        $Script:runspaces = New-Object System.Collections.ArrayList  
                                           
    }
    Process {
        
        ForEach ($Computer in $Computername) {
            If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) {
               #Create the powershell instance and supply the scriptblock with the other parameters 
               $powershell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($computer).AddArgument($wmihash)
               
               #Add the runspace into the powershell instance
               $powershell.RunspacePool = $runspacepool
               
               #Create a temporary collection for each runspace
               $temp = "" | Select-Object PowerShell,Runspace,Computer
               $Temp.Computer = $Computer
               $temp.PowerShell = $powershell
               
               #Save the handle output when calling BeginInvoke() that will be used later to end the runspace
               $temp.Runspace = $powershell.BeginInvoke()
               Write-Verbose ("Adding {0} collection" -f $temp.Computer)
               $runspaces.Add($temp) | Out-Null
            } Else {
                Write-Warning ("{0}: Unavailable" -f $Computer)
            }
           
           Write-Verbose ("Checking status of runspace jobs")
           Get-RunspaceData @runspacehash
        }     
    } #End Process
    End {                     
        Write-Verbose ("Finish processing the remaining runspace jobs: {0}" -f (@(($runspaces | Where {$_.Runspace -ne $Null}).Count)))
        $runspacehash.Wait = $true
        Get-RunspaceData @runspacehash
        
        Write-Verbose ("Closing the runspace pool")
        $runspacepool.close()               
    }    
}