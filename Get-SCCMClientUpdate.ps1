Function Get-SCCMClientUpdate {
<#
    .SYNOPSIS
        Allows you to query for updates via the SCCM Client Agent
    
    .DESCRIPTION
        Allows you to query for updates via the SCCM Client Agent
    
    .PARAMETER ShowHidden
        If in Quiet mode, use ShowHidden to view updates.
    
    .PARAMETER UpdateAction
        Define the type of action to query for.
    
        The following values are allowed:
        Install - This setting retrieves all updates that are available to be installed or in the process of being installed.
        Uninstall - This setting retrieves updates that are already installed and are available to be uninstalled. 
    
    .NOTES
        Author: Boe Prox
        Created: 3July2012
        Name: Get-SCCMClientUpdate
    
    .EXAMPLE
        Get-SCCMClientUpdate -ShowHidden | Format-Table Name,KB,BulletinID,EnforcementDeadline,UpdateStatus 

        Name                    KB                      BulletinID              EnforcementDeadline     UpdateStatus
        ----                    --                      ----------              -------------------     ------------
        Security Update for ... 2709162                 {MS12-041}              6/26/2012 1:00:00 AM    JobStateWaitInstall
        Service Pack 3 for V... 2526301                 {}                      6/4/2012 8:00:00 PM     JobStateDownloading
        Security Update for ... 2656374                 {MS12-025}              6/26/2012 1:00:00 AM    JobStateWaitInstall
        Security Update for ... 2656351                 {MS11-100}              6/3/2012 11:00:00 PM    JobStateStateError
        Security Update for ... 2686833                 {MS12-038}              6/26/2012 1:00:00 AM    JobStateWaitInstall
        Cumulative Security ... 2699988                 {MS12-037}              6/26/2012 1:00:00 AM    JobStateWaitInstall
        Security Update for ... 2656368                 {MS12-025}              6/26/2012 1:00:00 AM    JobStateWaitInstall
        Security Update for ... 2686827                 {MS12-038}              6/26/2012 1:00:00 AM    JobStateWaitInstall
        Update for Windows V... 2677070                 {}                      6/26/2012 1:00:00 AM    JobStateWaitInstall
        Update for Windows V... 2718704                 {}                      6/26/2012 1:00:00 AM    JobStateWaitInstall
        Security Update for ... 2685939                 {MS12-036}              6/26/2012 1:00:00 AM    JobStateWaitInstall
        Windows Malicious So... 890830                  {}                      6/26/2012 1:00:00 AM    JobStateWaitInstall     
        
        Description
        -----------
        This command will show all updates waiting to be installed on SCCM Client.
#>
    [cmdletbinding()]
    Param(
        [parameter()]
        [switch]$ShowHidden,
        [parameter()]
        [ValidateSet('Install','Uninstall')]
        [string]$UpdateAction = 'Install'
    )
    Begin {
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose ("{0}" -f $_)
        }
        
        $Action = [hashtable]@{
            Install = 2
            Uninstall = 3
        }
        $statusHash = [hashtable]@{
            0 = 'JobStateNone'
            1 = 'JobStateAvailable'
            2 = 'JobStateSubmitted'
            3 = 'JobStateDetecting'
            4 = 'JobStateDownloadingCIDef'
            5 = 'JobStateDownloadingSdmPkg'
            6 = 'JobStatePreDownload'
            7 = 'JobStateDownloading'
            8 = 'JobStateWaitInstall'
            9 = 'JobStateInstalling'
            10 = 'JobStatePendingSoftReboot'
            11 = 'JobStatePendingHardReboot'
            12 = 'JobStateWaitReboot'
            13 = 'JobStateVerifying'
            14 = 'JobStateInstallComplete'
            15 = 'JobStateStateError'
            16 = 'JobStateWaitServiceWindo'
        }   
        [ref]$progress = $Null            
    }
    Process {
        Write-Verbose ("UpdateAction: {0}" -f $UpdateAction)
        Try {
            $SCCMUpdate = New-Object -ComObject UDA.CCMUpdatesDeployment
            $updates = $SCCMUpdate.EnumerateUpdates(
                                                    $Action[$UpdateAction],
                                                    $PSBoundParameters['ShowHidden'],
                                                    $Progress
            )
            $Count = $updates.GetCount()
        } Catch {
            Write-Warning ("{0}" -f $_.Exception.Message)        
        }
        If ($Count -gt 0) {
            Write-Verbose ("Found {0} updates!" -f $Count)
            Try {
                For ($i=0;$i -lt $Count;$i++) {
                    [ref]$status = $Null
                    [ref]$Complete = $Null
                    [ref]$Errors = $Null                 
                    $update = $updates.GetUpdate($i)
                    $UpdateObject = New-Object PSObject -Property @{
                        KB = $update.GetArticleID()
                        BulletinID = {Try {$update.GetBulletinID()} Catch {}}.invoke()
                        DownloadSize = $update.GetDownloadSize()
                        EnforcementDeadline = $update.GetEnforcementDeadline()
                        ExclusiveUpdateOption = $update.GetExclusiveUpdateOption()
                        ID = $update.GetID()
                        InfoLink = $update.GetInfoLink(1033)
                        Manufacture = $update.GetManufacturer(1033)
                        Name = $update.GetName(1033)
                        NotificationOption = $update.GetNotificationOption()
                        Progress = $update.GetProgress($status,$Complete,$Errors)
                        UpdateStatus = $statusHash[$status.value]
                        ErrorCode = $Errors.Value                        
                        RebootDeadling = $update.GetRebootDeadline()
                        State = $update.GetState()
                        Summary = $update.GetSummary(1033)
                    }
                    $UpdateObject.PSTypeNames.Insert(0,'SCCMUpdate.Update')
                    $UpdateObject
                }
            } Catch {
                Write-Warning ("{0}" -f $_.Exception.Message)
            }
        } Else {
            Write-Verbose 'No updates found!'
        }
    }
}