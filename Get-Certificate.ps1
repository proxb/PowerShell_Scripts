Function Get-Certificate  {	
    <#
    .SYNOPSIS
        Retrieves  certificates from a local or remote system.

    .DESCRIPTION
        Retrieves  certificates from a local or remote system. Also includes the 
        time until expiration and allows for filtering of certificates and includes
        archived certificates.

    .PARAMETER  Computername
        A single or  list of computernames to perform search against

    .PARAMETER  StoreName
        The name of  the certificate store name that you want to search

    .PARAMETER  StoreLocation
        The location  of the certificate store.

    .PARAMETER  IncludeArchive
        Includes certificates that have been archived

    .PARAMETER  Issuer
        Filter by certificate Issuer

    .PARAMETER  Subject
        Filter by certificate Subject

    .PARAMETER  Thumbprint
        Filter by certificate Thumbprint

    .NOTES
        Name:  Get-Certificate
        Author: Boe  Prox
        Version  History:
            1.3 //Boe Prox
                -Added parameters for filtering
                -Removed parametersetnames
                -Fixed computername output in verbose streams
            1.0 //Boe Prox
                -Initial Version

    .EXAMPLE
        Get-Certificate -Computername 'boe-pc' -StoreName My -StoreLocation  LocalMachine

        Thumbprint                                 Subject                              
        ----------                                 -------                              
        F29B6CB248E3395B2EB45FCA6EA15005F64F2B4E   CN=SomeCert                          
        B93BA840652FB8273CCB1ABD804B2A035AA39877   CN=YetAnotherCert                    
        B1FF5E183E5C4F03559E80B49C2546BBB14CCB18   CN=BOE                               
        65F5A012F0FE3DF8AC6B5D6E07817F05D2DF5104   CN=SomeOtherCert                     
        63BD74490E182A341405B033DFE6768E00ECF21B   CN=www.example.com

        Description
        -----------
        Lists all certificates

    .EXAMPLE
        Get-Certificate -Computername 'boe-pc' -StoreName My -StoreLocation  LocalMachine -Subject '*Boe*'

        Thumbprint                                 Subject                              
        ----------                                 -------                                                
        B1FF5E183E5C4F03559E80B49C2546BBB14CCB18   CN=BOE                               

        Description
        -----------
        Lists certificates that contain the subject: boe

    #> 	
	[cmdletbinding()]	
	Param (		
		[parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]		
		[Alias('PSComputername','__Server','IPAddress')]		
		[string[]]$Computername =  $env:COMPUTERNAME,	
        [parameter()]	
		[System.Security.Cryptography.X509Certificates.StoreName]$StoreName = 'My',		
        [parameter()]
		[System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation  = 'LocalMachine',
        [parameter()]
        [switch]$IncludeArchive,
        [parameter()]
        [string]$Issuer,
        [parameter()]
        [string]$Subject,
        [parameter()]
        [string]$Thumbprint
	
	)	
    Begin {
		$WhereList = New-Object System.Collections.ArrayList
		If ($PSBoundParameters.ContainsKey('Issuer')) {
			[void]$WhereList.Add('$_.Issuer -LIKE $Issuer')
		}
		If ($PSBoundParameters.ContainsKey('Subject')) {
			[void]$WhereList.Add('$_.Subject -LIKE $Subject')
		}
		If ($PSBoundParameters.ContainsKey('Thumbprint')) {
			[void]$WhereList.Add('$_.Thumbprint -LIKE $Thumbprint')
		}
    If ($WhereList.count -gt 0) {
		    $Where = [scriptblock]::Create($WhereList -join ' -AND ')
		    Write-Debug "WhereBlock: $($Where)"
    }
    }
	Process  {		
		ForEach  ($Computer in  $Computername) {			
			Try  {				
				Write-Verbose  ("Connecting to \\{0}\{1}\{2}" -f $Computer,$StoreLocation,$StoreName)				
				$CertStore  = New-Object  System.Security.Cryptography.X509Certificates.X509Store  -ArgumentList "\\$($Computer)\$($StoreName)", $StoreLocation				
        		If ($PSBoundParameters.ContainsKey('IncludeArchive')) {
                    $Flags = [System.Security.Cryptography.X509Certificates.OpenFlags]'ReadOnly','IncludeArchived'
                } Else {
                    $Flags = [System.Security.Cryptography.X509Certificates.OpenFlags]'ReadOnly'
                }		                
				$CertStore.Open($Flags)																	
    			If ($WhereList.count -gt 0) {
                    $Certificates = $CertStore.Certificates | Where $Where
                } Else {
                    $Certificates = $CertStore.Certificates
                }	
                $Certificates | ForEach {							
					$Days = Switch ((New-TimeSpan  -End $_.NotAfter).Days)  {								
						{$_ -gt 0} {$_}								
						Default {'Expired'}								
					}							
					$_ | Add-Member -MemberType  NoteProperty -Name  ExpiresIn -Value  $Days -PassThru | 
                        Add-Member -MemberType NoteProperty -Name Computername -Value $Computer -PassThru														
				}															
			} Catch  {				
				Write-Warning  "$($Computer): $_"				
			}			
		}		
	}	
} 