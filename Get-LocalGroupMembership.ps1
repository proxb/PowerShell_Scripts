Function Get-LocalGroupMembership {
    <#
        .SYNOPSIS
            Recursively list all members of a specified Local group.

        .DESCRIPTION
            Recursively list all members of a specified Local group. This can be run against a local or
            remote system or systems. Recursion is unlimited unless specified by the -Depth parameter.

            Alias: glgm

        .PARAMETER Computername
            Local or remote computer/s to perform the query against.
            
            Default value is the local system.

        .PARAMETER Group
            Name of the group to query on a system for all members.
            
            Default value is 'Administrators'

        .PARAMETER Depth
            Limit the recursive depth of a query. 
            
            Default value is 2147483647.

        .PARAMETER Throttle
            Number of concurrently running jobs to run at a time

            Default value is 10

        .NOTES
            Author: Boe Prox
            Created: 8 AUG 2013
            Version 1.0 (8 AUG 2013):
                -Initial creation

        .EXAMPLE
            Get-LocalGroupMembership

            Name              ParentGroup       isGroup Type   Computername Depth
            ----              -----------       ------- ----   ------------ -----
            Administrator     Administrators      False Domain DC1              1
            boe               Administrators      False Domain DC1              1
            testuser          Administrators      False Domain DC1              1
            bob               Administrators      False Domain DC1              1
            proxb             Administrators      False Domain DC1              1
            Enterprise Admins Administrators       True Domain DC1              1
            Sysops Admins     Enterprise Admins    True Domain DC1              2
            Domain Admins     Enterprise Admins    True Domain DC1              2
            Administrator     Enterprise Admins   False Domain DC1              2
            Domain Admins     Administrators       True Domain DC1              1
            proxb             Domain Admins       False Domain DC1              2
            Administrator     Domain Admins       False Domain DC1              2
            Sysops Admins     Administrators       True Domain DC1              1
            Org Admins        Sysops Admins        True Domain DC1              2
            Enterprise Admins Sysops Admins        True Domain DC1              2       
            
            Description
            -----------
            Gets all of the members of the 'Administrators' group on the local system.        
            
        .EXAMPLE
            Get-LocalGroupMembership -Group 'Administrators' -Depth 1
            
            Name              ParentGroup    isGroup Type   Computername Depth
            ----              -----------    ------- ----   ------------ -----
            Administrator     Administrators   False Domain DC1              1
            boe               Administrators   False Domain DC1              1
            testuser          Administrators   False Domain DC1              1
            bob               Administrators   False Domain DC1              1
            proxb             Administrators   False Domain DC1              1
            Enterprise Admins Administrators    True Domain DC1              1
            Domain Admins     Administrators    True Domain DC1              1
            Sysops Admins     Administrators    True Domain DC1              1   
            
            Description
            -----------
            Gets the members of 'Administrators' with only 1 level of recursion.         
            
    #>
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('CN','__Server','Computer','IPAddress')]
        [string[]]$Computername = $env:COMPUTERNAME,
        [parameter()]
        [string]$Group = "Administrators",
        [parameter()]
        [int]$Depth = ([int]::MaxValue),
        [parameter()]
        [Alias("MaxJobs")]
        [int]$Throttle = 10
    )
    Begin {
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose $_
        }
        #region Extra Configurations
        Write-Verbose ("Depth: {0}" -f $Depth)
        #endregion Extra Configurations
        #Define hash table for Get-RunspaceData function
        $runspacehash = @{}
        #Function to perform runspace job cleanup
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
        }

        #region ScriptBlock
            $scriptBlock = {
            Param ($Computer,$Group,$Depth,$NetBIOSDomain,$ObjNT,$Translate)            
            $Script:Depth = $Depth
            $Script:ObjNT = $ObjNT
            $Script:Translate = $Translate
            $Script:NetBIOSDomain = $NetBIOSDomain
            Function Get-LocalGroupMember {
                [cmdletbinding()]
                Param (
                    [parameter()]
                    [System.DirectoryServices.DirectoryEntry]$LocalGroup
                )
                # Invoke the Members method and convert to an array of member objects.
                $Members= @($LocalGroup.psbase.Invoke("Members"))
                $Counter++
                ForEach ($Member In $Members) {                
                    Try {
                        $Name = $Member.GetType().InvokeMember("Name", 'GetProperty', $Null, $Member, $Null)
                        $Path = $Member.GetType().InvokeMember("ADsPath", 'GetProperty', $Null, $Member, $Null)
                        # Check if this member is a group.
                        $isGroup = ($Member.GetType().InvokeMember("Class", 'GetProperty', $Null, $Member, $Null) -eq "group")
                        If (($Path -like "*/$Computer/*")) {
                            $Type = 'Local'
                        } Else {$Type = 'Domain'}
                        New-Object PSObject -Property @{
                            Computername = $Computer
                            Name = $Name
                            Type = $Type
                            ParentGroup = $LocalGroup.Name[0]
                            isGroup = $isGroup
                            Depth = $Counter
                        }
                        If ($isGroup) {
                            # Check if this group is local or domain.
                            #$host.ui.WriteVerboseLine("(RS)Checking if Counter: {0} is less than Depth: {1}" -f $Counter, $Depth)
                            If ($Counter -lt $Depth) {
                                If ($Type -eq 'Local') {
                                    If ($Groups[$Name] -notcontains 'Local') {
                                        $host.ui.WriteVerboseLine(("{0}: Getting local group members" -f $Name))
                                        $Groups[$Name] += ,'Local'
                                        # Enumerate members of local group.
                                        Get-LocalGroupMember $Member
                                    }
                                } Else {
                                    If ($Groups[$Name] -notcontains 'Domain') {
                                        $host.ui.WriteVerboseLine(("{0}: Getting domain group members" -f $Name))
                                        $Groups[$Name] += ,'Domain'
                                        # Enumerate members of domain group.
                                        Get-DomainGroupMember $Member $Name $True
                                    }
                                }
                            }
                        }
                    } Catch {
                        $host.ui.WriteWarningLine(("GLGM{0}" -f $_.Exception.Message))
                    }
                }
            }

            Function Get-DomainGroupMember {
                [cmdletbinding()]
                Param (
                    [parameter()]
                    $DomainGroup, 
                    [parameter()]
                    [string]$NTName, 
                    [parameter()]
                    [string]$blnNT
                )
                Try {
                    If ($blnNT -eq $True) {
                        # Convert NetBIOS domain name of group to Distinguished Name.
                        $objNT.InvokeMember("Set", "InvokeMethod", $Null, $Translate, (3, ("{0}{1}" -f $NetBIOSDomain.Trim(),$NTName)))
                        $DN = $objNT.InvokeMember("Get", "InvokeMethod", $Null, $Translate, 1)
                        $ADGroup = [ADSI]"LDAP://$DN"
                    } Else {
                        $DN = $DomainGroup.distinguishedName
                        $ADGroup = $DomainGroup
                    }         
                    $Counter++   
                    ForEach ($MemberDN In $ADGroup.Member) {
                        $MemberGroup = [ADSI]("LDAP://{0}" -f ($MemberDN -replace '/','\/'))
                        New-Object PSObject -Property @{
                            Computername = $Computer
                            Name = $MemberGroup.name[0]
                            Type = 'Domain'
                            ParentGroup = $NTName
                            isGroup = ($MemberGroup.Class -eq "group")
                            Depth = $Counter
                        }
                        # Check if this member is a group.
                        If ($MemberGroup.Class -eq "group") {              
                            If ($Counter -lt $Depth) {
                                If ($Groups[$MemberGroup.name[0]] -notcontains 'Domain') {
                                    Write-Verbose ("{0}: Getting domain group members" -f $MemberGroup.name[0])
                                    $Groups[$MemberGroup.name[0]] += ,'Domain'
                                    # Enumerate members of domain group.
                                    Get-DomainGroupMember $MemberGroup $MemberGroup.Name[0] $False
                                }                                                
                            }
                        }
                    }
                } Catch {
                    $host.ui.WriteWarningLine(("GDGM{0}" -f $_.Exception.Message))
                }
            }
            #region Get Local Group Members
            $Script:Groups = @{}
            $Script:Counter=0
            # Bind to the group object with the WinNT provider.
            $ADSIGroup = [ADSI]"WinNT://$Computer/$Group,group"
            Write-Verbose ("Checking {0} membership for {1}" -f $Group,$Computer)
            $Groups[$Group] += ,'Local'
            Get-LocalGroupMember -LocalGroup $ADSIGroup
            #endregion Get Local Group Members
        }
        #endregion ScriptBlock
        Write-Verbose ("Checking to see if connected to a domain")
        Try {
            $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            $Root = $Domain.GetDirectoryEntry()
            $Base = ($Root.distinguishedName)

            # Use the NameTranslate object.
            $Script:Translate = New-Object -comObject "NameTranslate"
            $Script:objNT = $Translate.GetType()

            # Initialize NameTranslate by locating the Global Catalog.
            $objNT.InvokeMember("Init", "InvokeMethod", $Null, $Translate, (3, $Null))

            # Retrieve NetBIOS name of the current domain.
            $objNT.InvokeMember("Set", "InvokeMethod", $Null, $Translate, (1, "$Base"))
            [string]$Script:NetBIOSDomain =$objNT.InvokeMember("Get", "InvokeMethod", $Null, $Translate, 3)  
        } Catch {Write-Warning ("{0}" -f $_.Exception.Message)}         
        
        #region Runspace Creation
        Write-Verbose ("Creating runspace pool and session states")
        $sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
        $runspacepool = [runspacefactory]::CreateRunspacePool(1, $Throttle, $sessionstate, $Host)
        $runspacepool.Open()  
        
        Write-Verbose ("Creating empty collection to hold runspace jobs")
        $Script:runspaces = New-Object System.Collections.ArrayList        
        #endregion Runspace Creation
    }

    Process {
        ForEach ($Computer in $Computername) {
            #Create the powershell instance and supply the scriptblock with the other parameters 
            $powershell = [powershell]::Create().AddScript($scriptBlock).AddArgument($computer).AddArgument($Group).AddArgument($Depth).AddArgument($NetBIOSDomain).AddArgument($ObjNT).AddArgument($Translate)
           
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
           
            Write-Verbose ("Checking status of runspace jobs")
            Get-RunspaceData @runspacehash   
        }
    }
    End {
        Write-Verbose ("Finish processing the remaining runspace jobs: {0}" -f (@(($runspaces | Where {$_.Runspace -ne $Null}).Count)))
        $runspacehash.Wait = $true
        Get-RunspaceData @runspacehash
    
        #region Cleanup Runspace
        Write-Verbose ("Closing the runspace pool")
        $runspacepool.close()  
        $runspacepool.Dispose() 
        #endregion Cleanup Runspace    
    }
}

Set-Alias -Name glgm -Value Get-LocalGroupMembership