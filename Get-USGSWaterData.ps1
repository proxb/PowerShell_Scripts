Function Get-USGSWaterData {
    <#
        .SYNOPSIS
            Retrieves the water height of the Papio Creek along Ft Crook station in Bellevue, NE.
            Running without parameters shows last 24 hours worth of data.

        .DESCRIPTION
            Retrieves the water height of the Papio Creek along Ft Crook station in Bellevue, NE.
            Running without parameters shows last 24 hours worth of data.

        .PARAMETER Location
            The location to query for water information.

            Default Value is: 06610795 (Ft Crook - Papio Creek; Bellevue, NE)
            Find other values at: http://maps.waterdata.usgs.gov/mapper/index.html

        .PARAMETER StartTime
            Oldest starting time to look for data

        .PARAMETER EndTime
            The latest time to end search for data

        .NOTES
            Name: Get-USGSPapioBellevue
            Author: Boe Prox
            Version History:
                1.0 //Boe Prox - 16 May 2016
                    - Initial build

        .INPUTS
            System.String

        .OUTPUTS
            Web.USGS.Data

        .LINK
            http://maps.waterdata.usgs.gov/mapper/index.html

        .EXAMPLE
            Get-USGSWaterData | Select-Object -Last 1 | Format-List

            Location  : 06610795-Papillion-Creek-at-Fort-Crook-Nebr
            DateTime  : 5/18/2016 6:15:00 AM
            Height_FT : 10.52
            Discharge : 354

            Description
            -----------
            Retrieves the last 24 hours worth of data and looking at the most recent 10 entries

        .EXAMPLE
            Get-USGSWaterData -StartDate '05/10/2015' -EndDate '05/12/2015' | Select-Object -Last 5 | Format-List

            Location  : 06610795-Papillion-Creek-at-Fort-Crook-Nebr
            DateTime  : 5/12/2015 10:45:00 PM
            Height_FT : 10.83
            Discharge : 413

            Location  : 06610795-Papillion-Creek-at-Fort-Crook-Nebr
            DateTime  : 5/12/2015 11:00:00 PM
            Height_FT : 10.82
            Discharge : 411

            Location  : 06610795-Papillion-Creek-at-Fort-Crook-Nebr
            DateTime  : 5/12/2015 11:15:00 PM
            Height_FT : 10.84
            Discharge : 416

            Location  : 06610795-Papillion-Creek-at-Fort-Crook-Nebr
            DateTime  : 5/12/2015 11:30:00 PM
            Height_FT : 10.83
            Discharge : 413

            Location  : 06610795-Papillion-Creek-at-Fort-Crook-Nebr
            DateTime  : 5/12/2015 11:45:00 PM
            Height_FT : 10.82
            Discharge : 411

            Description
            -----------
            Retrieves entries from 05/10/2015 to 05/12/2015
    #>
    [OutputType('Web.USGS.Data')]
    [cmdletbinding()]
    Param (
        [string]$Location = '06610795', #Ft Crook Rd in Bellevue, NE
        [datetime]$StartDate = (Get-Date).AddDays(-1),
        [datetime]$EndDate = (Get-Date)
    )

    If ($PSBoundParameters.ContainsKey('Debug')) {
        $DebugPreference = 'Continue'
    }
    If ($StartDate.Date -eq (Get-Date).Date) {
        $StartDate = $StartDate.AddDays(-1)
    }

    $__StartDate = $StartDate.ToString('yyyy-MM-dd')
    $__EndDate = $EndDate.ToString('yyyy-MM-dd')
    $URI = "http://waterdata.usgs.gov/ne/nwis/uv?cb_00065=on&cb_00060=on&format=html&site_no=$($Location)&period=&begin_date=$($__StartDate)&end_date=$($__EndDate)"
    $RegEx = [regex]"^(?<DateTime>(?:\d{2}/){2}\d{4}\s\d{2}:\d{2})\s(?<TimeZone>[a-zA-Z]{1,})(?<Height>\d{1,}\.\d{2})(?:A|P)\s{2}(?<Discharge>(?:\d{1,},)*\d{1,})(?:A|P)"

    Try {
        $Data = Invoke-WebRequest -Uri $URI
    }
    Catch {
        Write-Warning $_
        BREAK
    }

    If ($Data.ParsedHtml.body.innertext -match 'Redirecting') {
        Write-Verbose "Requesting data older or longer than 120 days, performing redirection"
        $Data = Invoke-WebRequest -Uri $Data.links.href
    }

    $Title = ((@($Data.ParsedHtml.getElementsByTagName('Title'))[0].Text -replace '.*USGS(.*)','$1').Trim() -replace ',|\.') -replace ' ','-'
    Write-Verbose "[$($Title)]"
    @($Data.ParsedHtml.getElementsByTagName('Table'))[3].InnerText -split '\r\n' | ForEach {
        If ($_ -match $RegEx) {
            $Object = [pscustomobject]@{
                Location = $Title
                DateTime = [datetime]$Matches.DateTime
                Height_FT = [decimal]$Matches.Height
                Discharge = [decimal]$Matches.Discharge -replace ','
            }
            $Object.pstypenames.insert(0,'Web.USGS.Data')
            $Object
        }
        Else {
            Write-Debug "[$($_)] No match found!"
        }
    }
}