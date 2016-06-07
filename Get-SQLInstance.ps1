Function Get-SQLInstance {
    <#
        .SYNOPSIS
            Retrieves SQL server information from a local or remote servers.

        .DESCRIPTION
            Retrieves SQL server information from a local or remote servers. Pulls all 
            instances from a SQL server and detects if in a cluster or not.

        .PARAMETER Computername
            Local or remote systems to query for SQL information.

        .NOTES
            Name: Get-SQLInstance
            Author: Boe Prox
            Version History:
                1.5 //Boe Prox - 31 May 2016
                    - Added WMI queries for more information
                    - Custom object type name
                1.0 //Boe Prox -  07 Sept 2013
                    - Initial Version

        .EXAMPLE
            Get-SQLInstance -Computername SQL1

            Computername      : SQL1
            Instance          : MSSQLSERVER
            SqlServer         : SQLCLU
            WMINamespace      : ComputerManagement10
            Sqlstates         : 2061
            Version           : 10.53.6000.34
            Splevel           : 3
            Clustered         : True
            Installpath       : C:\Program Files\Microsoft SQL 
                                Server\MSSQL10_50.MSSQLSERVER\MSSQL
            Datapath          : D:\MSSQL10_50.MSSQLSERVER\MSSQL
            Language          : 1033
            Fileversion       : 2009.100.6000.34
            Vsname            : SQLCLU
            Regroot           : Software\Microsoft\Microsoft SQL 
                                Server\MSSQL10_50.MSSQLSERVER
            Sku               : 1804890536
            Skuname           : Enterprise Edition (64-bit)
            Instanceid        : MSSQL10_50.MSSQLSERVER
            Startupparameters : -dD:\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\master.mdf;-eD:\MSSQL1
                                0_50.MSSQLSERVER\MSSQL\Log\ERRORLOG;-lD:\MSSQL10_50.MSSQLSERV
                                ER\MSSQL\DATA\mastlog.ldf
            Errorreporting    : False
            Dumpdir           : D:\MSSQL10_50.MSSQLSERVER\MSSQL\LOG\
            Sqmreporting      : False
            Iswow64           : False
            BackupDirectory   : F:\MSSQL10_50.MSSQLSERVER\MSSQL\Backup
            AlwaysOnName      : 
            Nodes             : {SQL1, SQL2}
            Caption           : SQL Server 2008 R2
            FullName          : SQLCLU\MSSQLSERVER

            Description
            -----------
            Retrieves the SQL information from SQL1
    #>
    [OutputType('SQLServer.Information')]
    [cmdletbinding()] 
    Param(
        [parameter(ValueFromPipeline=$True)]
        [string[]]$Computername = 'G13'
    )
    Process {
        ForEach ($Computer in $Computername) {
            # 1 = MSSQLSERVER
            $Filter = "SELECT * FROM SqlServiceAdvancedProperty WHERE SqlServiceType=1" 
            $WMIParams=@{
                Computername = $Computer
                NameSpace='root\Microsoft\SqlServer'
                Query="SELECT name FROM __NAMESPACE WHERE name LIKE 'ComputerManagement%'"
                Authentication = 'PacketPrivacy'
                ErrorAction = 'Stop'
            }
            Write-Verbose "[$Computer] Starting SQL Scan"
            $PropertyHash = [ordered]@{
                Computername = $Computer
                Instance = $Null
                SqlServer = $Null
                WmiNamespace = $Null
                SQLSTATES = $Null
                VERSION = $Null
                SPLEVEL = $Null
                CLUSTERED = $Null
                INSTALLPATH = $Null
                DATAPATH = $Null
                LANGUAGE = $Null
                FILEVERSION = $Null
                VSNAME = $Null
                REGROOT = $Null
                SKU = $Null
                SKUNAME = $Null
                INSTANCEID = $Null
                STARTUPPARAMETERS = $Null
                ERRORREPORTING = $Null
                DUMPDIR = $Null
                SQMREPORTING = $Null
                ISWOW64 = $Null
                BackupDirectory = $Null
                AlwaysOnName = $Null
            }
            Try {
                Write-Verbose "[$Computer] Performing Registry Query"
                $Registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Computer) 
            }
            Catch {
                Write-Warning "[$Computer] $_"
                Continue
            }
            $baseKeys = "SOFTWARE\\Microsoft\\Microsoft SQL Server",
            "SOFTWARE\\Wow6432Node\\Microsoft\\Microsoft SQL Server"
            Try {
                $ErrorActionPreference = 'Stop'
                If ($Registry.OpenSubKey($basekeys[0])) {
                    $regPath = $basekeys[0]
                } 
                ElseIf ($Registry.OpenSubKey($basekeys[1])) {
                    $regPath = $basekeys[1]
                } 
                Else {
                    Continue
                }
            } 
            Catch {
                Continue
            }
            Finally {
                $ErrorActionPreference = 'Continue'
            }
            $RegKey= $Registry.OpenSubKey("$regPath")
            If ($RegKey.GetSubKeyNames() -contains "Instance Names") {
                $RegKey= $Registry.OpenSubKey("$regpath\\Instance Names\\SQL" ) 
                $instances = @($RegKey.GetValueNames())
            } 
            ElseIf ($regKey.GetValueNames() -contains 'InstalledInstances') {
                $isCluster = $False
                $instances = $RegKey.GetValue('InstalledInstances')
            } 
            Else {
                Continue
            }

            If ($instances.count -gt 0) { 
                ForEach ($Instance in $Instances) {
                    $PropertyHash['Instance']=$Instance
                    $Nodes = New-Object System.Collections.Arraylist
                    $clusterName = $Null
                    $isCluster = $False
                    $instanceValue = $regKey.GetValue($instance)
                    $instanceReg = $Registry.OpenSubKey("$regpath\\$instanceValue")
                    If ($instanceReg.GetSubKeyNames() -contains "Cluster") {
                        $isCluster = $True
                        $instanceRegCluster = $instanceReg.OpenSubKey('Cluster')
                        $clusterName = $instanceRegCluster.GetValue('ClusterName')
                        $clusterReg = $Registry.OpenSubKey("Cluster\\Nodes")                            
                        $clusterReg.GetSubKeyNames() | ForEach {
                            $null = $Nodes.Add($clusterReg.OpenSubKey($_).GetValue('NodeName'))
                        }                    
                    }  
                    $PropertyHash['Nodes'] = $Nodes

                    $instanceRegSetup = $instanceReg.OpenSubKey("Setup")
                    Try {
                        $edition = $instanceRegSetup.GetValue('Edition')
                    } Catch {
                        $edition = $Null
                    }
                    $PropertyHash['Skuname'] = $edition
                    Try {
                        $ErrorActionPreference = 'Stop'
                        #Get from filename to determine version
                        $servicesReg = $Registry.OpenSubKey("SYSTEM\\CurrentControlSet\\Services")
                        $serviceKey = $servicesReg.GetSubKeyNames() | Where {
                            $_ -match "$instance"
                        } | Select -First 1
                        $service = $servicesReg.OpenSubKey($serviceKey).GetValue('ImagePath')
                        $file = $service -replace '^.*(\w:\\.*\\sqlservr.exe).*','$1'
                        $PropertyHash['version'] =(Get-Item ("\\$Computer\$($file -replace ":","$")")).VersionInfo.ProductVersion
                    } Catch {
                        #Use potentially less accurate version from registry
                        $PropertyHash['Version'] = $instanceRegSetup.GetValue('Version')
                    } Finally {
                        $ErrorActionPreference = 'Continue'
                    }

                    Try {
                        Write-Verbose "[$Computer] Performing WMI Query"
                        $Namespace = $Namespace = (Get-WMIObject @WMIParams | Sort-Object -Descending | Select-Object -First 1).Name
                        If ($Namespace) {
                            $PropertyHash['WMINamespace'] = $Namespace
                            $WMIParams.NameSpace="root\Microsoft\SqlServer\$Namespace"
                            $WMIParams.Query=$Filter

                            $WMIResults = Get-WMIObject @WMIParams 
                            $GroupResults = $WMIResults | Group ServiceName
                            $PropertyHash['Instance'] = $GroupResults.Name
                            $WMIResults | ForEach {
                                $Name = "{0}{1}" -f ($_.PropertyName.SubString(0,1),$_.PropertyName.SubString(1).ToLower())    
                                $Data = If ($_.PropertyStrValue) {
                                    $_.PropertyStrValue
                                }
                                Else {
                                    If ($Name -match 'Clustered|ErrorReporting|SqmReporting|IsWow64') {
                                        [bool]$_.PropertyNumValue
                                    }
                                    Else {
                                        $_.PropertyNumValue
                                    }        
                                }
                                $PropertyHash[$Name] = $Data
                            }

                            #region Always on availability group
                            if ($PropertyHash['Version'].Major -ge 11) {                                          
                                $splat.Query="SELECT WindowsFailoverClusterName FROM HADRServiceSettings WHERE InstanceName = '$($Group.Name)'"
                                $PropertyHash['AlwaysOnName'] = (Get-WmiObject @WMIParams).WindowsFailoverClusterName
                                if ($PropertyHash['AlwaysOnName']) {
                                    $PropertyHash.SqlServer = $PropertyHash['AlwaysOnName']
                                }
                            } 
                            else {
                                $PropertyHash['AlwaysOnName'] = $null
                            }  
                            #endregion Always on availability group

                            #region Backup Directory
                            $RegKey=$Registry.OpenSubKey("$($PropertyHash['RegRoot'])\MSSQLServer")
                            $PropertyHash['BackupDirectory'] = $RegKey.GetValue('BackupDirectory')
                            #endregion Backup Directory
                        }#IF NAMESPACE
                    }
                    Catch {
                    }
                    #region Caption
                    $Caption = {Switch -Regex ($PropertyHash['version']) {
                        "^13" {'SQL Server 2016';Break}
                        "^12" {'SQL Server 2014';Break}
                        "^11" {'SQL Server 2012';Break}
                        "^10\.5" {'SQL Server 2008 R2';Break}
                        "^10" {'SQL Server 2008';Break}
                        "^9"  {'SQL Server 2005';Break}
                        "^8"  {'SQL Server 2000';Break}
                        Default {'Unknown'}
                    }}.InvokeReturnAsIs()
                    $PropertyHash['Caption'] = $Caption
                    #endregion Caption

                    #region Full SQL Name
                    $Name = If ($clusterName) {
                        $clusterName
                        $PropertyHash['SqlServer'] = $clusterName
                    }
                    Else {
                        $Computer
                        $PropertyHash['SqlServer'] = $Computer
                    }
                    $PropertyHash['FullName'] = ("{0}\{1}" -f $Name,$PropertyHash['Instance'])
                    #emdregion Full SQL Name                        
                    $Object = [pscustomobject]$PropertyHash
                    $Object.pstypenames.insert(0,'SQLServer.Information')
                    $Object
                }#FOREACH INSTANCE                 
            }#IF
        }
    }
}