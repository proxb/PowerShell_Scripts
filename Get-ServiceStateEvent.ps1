Function Get-ServiceStateEvent {
    <#
        .SYNOPSIS
            Finds all events related to a service state change in the event log.

        .DESCRIPTION
            Finds all events related to a service state change in the event log.

        .PARAMETER Computername
            Name of the computer to query

        .PARAMETER Path
            The full path to a specified event log that has been archived or saved to 
            a filesystem location.

        .NOTES
            Name: Get-ServiceStateEvent
            Author: Boe Prox
            Version History:
                1.0 //Boe Prox - 07/08/2016
                    - Initial version

        .EXAMPLE
            Get-ServiceStateEvent -Computer $Env:Computername

            Description
            -----------
            Displays all events related to service state changes.
    #>
    [cmdletbinding(
        DefaultParameterSetName = 'Computer'
    )]
    Param (
        [parameter(ParameterSetName='Computer')]
        [string[]]$Computername = $env:COMPUTERNAME,
        [parameter(ParameterSetName='File', ValueFromPipelineByPropertyName = $True)]
        [Alias('Fullname')]
        [string[]]$Path
    )
    Begin {
        Write-Verbose $PSCmdlet.ParameterSetName
        If ($PScmdlet.parametersetname -eq 'File') {
            $Query = @"
<QueryList>
  <Query Id="0" Path="file://TOREPLACE">
    <Select Path="file://TOREPLACE">*[System[(EventID=7036)]]</Select>
  </Query>
</QueryList>
"@
        } Else {
            $Query = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[(EventID=7036)]]</Select>
  </Query>
</QueryList>
"@        
        }
    }
    Process {
        Switch ($PScmdlet.ParameterSetName) {
            'Computer' {
                ForEach ($Computer in $Computername) {
                    Get-WinEvent -ComputerName $Computer -LogName System -FilterXPath $Query | ForEach {
                        $Properties = $_.Properties
                        [pscustomobject] @{
                            Computername = $_.MachineName
                            TimeCreated = $_.TimeCreated
                            Servicename = $Properties[0].Value
                            State = $Properties[1].Value
                        }
                    }
                }
            }
            'File' {
                ForEach ($Item in $Path) {
                    $SearchQuery = $Query -Replace 'TOREPLACE',$Item
                    Write-Verbose $SearchQuery
                    Get-WinEvent -Path $Item -FilterXPath $SearchQuery  | ForEach {
                        $Properties = $_.Properties
                        [pscustomobject] @{
                            Computername = $_.MachineName
                            TimeCreated = $_.TimeCreated
                            Servicename = $Properties[0].Value
                            State = $Properties[1].Value
                        }
                    }
                }
            }
        }
    }
}