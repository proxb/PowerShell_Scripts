Function Get-ADGroupMemberDate {
    <#
        .SYNOPSIS
            Provides the date that a member was added to a specified Active Directory group.
        
        .DESCRIPTION
            Provides the date that a member was added to a specified Active Directory group.
        
        .PARAMETER Group
            The group that will be inspected for members and date added. If a distinguished name (dn) is not used,
            an attempt to get the dn before making the query.
        
        .PARAMETER DomainController
            Name of the domain controller to query. Optional parameter.
        
        .NOTES
            Name: Get-ADGroupMemberDate
            Author: Boe Prox
            DateCreated: 17 May 2013
            Version 1.0

            The State property will be one of the following:

            PRESENT: User currently exists in group and the replicated using Linked Value Replication (LVR).
            ABSENT: User has been removed from group and has not been garbage collected based on Tombstone Lifetime (TSL).
            LEGACY: User currently exists as a member of the group but has no replication data via LVR.
        
        .EXAMPLE
            Get-ADGroupMemberDate -Group "Domain Admins" -DomainController DC3

            ModifiedCount    : 2
            DomainController : DC3
            LastModified     : 5/4/2013 6:48:06 PM
            Username         : joesmith
            State            : ABSENT
            Group            : CN=Domain Admins,CN=Users,DC=Domain,DC=Com

            ModifiedCount    : 1
            DomainController : DC3
            LastModified     : 1/6/2010 7:36:08 AM
            Username         : adminuser
            State            : PRESENT
            Group            : CN=Domain Admins,CN=Users,DC=Domain,DC=Com
            ...

            Description
            -----------
            This lists out all of the members of Domain Admins using DC3 as the Domain Controller.
        
        .EXAMPLE
            Get-ADGroup -Identity "TestGroup" | Get-ADGroupMemberDate

            ModifiedCount    : 2
            DomainController : DC1
            LastModified     : 5/4/2013 6:48:06 PM
            Username         : joesmith
            State            : ABSENT
            Group            : CN=TestGroup,OU=Groups,DC=Domain,DC=Com

            ModifiedCount    : 1
            DomainController : DC1
            LastModified     : 1/6/2010 7:36:08 AM
            Username         : bobsmith
            State            : PRESENT
            Group            : CN=TestGroup,OU=Groups,DC=Domain,DC=Com
            ...

            Description
            -----------
            This lists out all of the members of TestGroup from the output of Get-ADGroup and auto-selecting DC1 as the Domain Controller.

    #>
    [OutputType('ActiveDirectory.Group.Info')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Mandatory=$True)]
        [Alias('DistinguishedName')]
        [string]$Group,
        [parameter()]
        [string]$DomainController = ($env:LOGONSERVER -replace "\\\\")
    )
    Begin {
        #RegEx pattern for output
        [regex]$pattern = '^(?<State>\w+)\s+member(?:\s(?<DateTime>\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2})\s+(?:.*\\)?(?<DC>\w+|(?:(?:\w{8}-(?:\w{4}-){3}\w{12})))\s+(?:\d+)\s+(?:\d+)\s+(?<Modified>\d+))?'
    }
    Process {
        If ($Group -notmatch "^CN=.*") {
            Write-Verbose "Attempting to get distinguished name of $Group"

            Try {
                $distinguishedName = ([adsisearcher]"name=$group").Findone().Properties['distinguishedname'][0]
                If (-Not $distinguishedName) {Throw "Fail!"}
            } Catch {
                Write-Warning "Unable to locate $group"
                Break                
            }

        } Else {$distinguishedName = $Group}

        Write-Verbose "Distinguished Name is $distinguishedName"
        $data = (repadmin /showobjmeta $DomainController $distinguishedName | Select-String "^\w+\s+member" -Context 2)

        ForEach ($rep in $data) {
           If ($rep.line -match $pattern) {
               $object = New-Object PSObject -Property @{
                    Username = [regex]::Matches($rep.context.postcontext,"CN=(?<Username>.*?),.*") | ForEach {$_.Groups['Username'].Value}
                    LastModified = If ($matches.DateTime) {[datetime]$matches.DateTime} Else {$Null}
                    DomainController = $matches.dc
                    Group = $distinguishedName
                    State = $matches.state
                    ModifiedCount = $matches.modified
                }

                $object.pstypenames.insert(0,'ActiveDirectory.Group.Info')
                $object
            }
        }
    }
}