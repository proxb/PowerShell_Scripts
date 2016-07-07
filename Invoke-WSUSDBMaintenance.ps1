Function Invoke-WSUSDBMaintenance {
    <#
        .SYSNOPSIS
            Performs maintenance tasks on the SUSDB database using the WSUS API and T-SQL code.

        .DESCRIPTION
            Performs maintenance tasks on the SUSDB database using the WSUS API.
            
            1. Identifies indexes that are fragmented and defragments them. For certain 
               tables, a fill-factor is set in order to improve insert performance. 
               Based on MSDN sample at http://msdn2.microsoft.com/en-us/library/ms188917.aspx 
               and tailored for SUSDB requirements 
            2. Updates potentially out-of-date table statistics. 

        .PARAMETER UpdateServer
            Update server to connect to

        .PARAMETER Port
            Port to connect to the Update Server. Default port is 80.

        .PARAMETER Secure
            Use a secure connection

        .NOTES
            Name: Invoke-WSUSDBMaintenance
            Author: Boe Prox
            DateCreated: 03 Jul 2013

            T-SQL Code used from http://gallery.technet.microsoft.com/scriptcenter/6f8cde49-5c52-4abd-9820-f1d270ddea61

        .EXAMPLE
            Invoke-WSUSDBMaintenance -UpdateServer DC1 -Port 80 -Verbose
            
            VERBOSE: Connecting to DC1
            VERBOSE: Connecting to SUSDB on DC1
            VERBOSE: Performing operation "Database Maintenance" on Target "SUSDB".
            VERBOSE: Completed.

            Description
            -----------
            Performs database maintenance on the database for Update Server DC1 on DC1
    #>
    [cmdletbinding(
        SupportsShouldProcess = $True
    )]
    Param(
        [parameter(Mandatory=$True)]
        [ValidateScript({
            If (-Not (Get-Module -List -Name UpdateServices)) {
                Try {
                    Add-Type -Path "$Env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll"            
                    $True
                } Catch {
                    Throw ("Missing the required assemblies to use the WSUS API from {0}" -f "$Env:ProgramFiles\Update Services\Api")
                }
            } Else {$True}
        })]
        [string]$UpdateServer,
        [parameter()]
        [ValidateSet('80','443','8530','8531')]
        [int]$Port = 80,
        [parameter()]
        [switch]$Secure
    )
    $tSQL = @"
SET NOCOUNT ON; 
 
-- Rebuild or reorganize indexes based on their fragmentation levels 
DECLARE @work_to_do TABLE ( 
    objectid int 
    , indexid int 
    , pagedensity float 
    , fragmentation float 
    , numrows int 
) 
 
DECLARE @objectid int; 
DECLARE @indexid int; 
DECLARE @schemaname nvarchar(130);  
DECLARE @objectname nvarchar(130);  
DECLARE @indexname nvarchar(130);  
DECLARE @numrows int 
DECLARE @density float; 
DECLARE @fragmentation float; 
DECLARE @command nvarchar(4000);  
DECLARE @fillfactorset bit 
DECLARE @numpages int 
 
-- Select indexes that need to be defragmented based on the following 
-- * Page density is low 
-- * External fragmentation is high in relation to index size 
INSERT @work_to_do 
SELECT 
    f.object_id 
    , index_id 
    , avg_page_space_used_in_percent 
    , avg_fragmentation_in_percent 
    , record_count 
FROM  
    sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'SAMPLED') AS f 
WHERE 
    (f.avg_page_space_used_in_percent < 85.0 and f.avg_page_space_used_in_percent/100.0 * page_count < page_count - 1) 
    or (f.page_count > 50 and f.avg_fragmentation_in_percent > 15.0) 
    or (f.page_count > 10 and f.avg_fragmentation_in_percent > 80.0) 
 
 
SELECT @numpages = sum(ps.used_page_count) 
FROM 
    @work_to_do AS fi 
    INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id 
    INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id 
 
-- Declare the cursor for the list of indexes to be processed. 
DECLARE curIndexes CURSOR FOR SELECT * FROM @work_to_do 
 
-- Open the cursor. 
OPEN curIndexes 
 
-- Loop through the indexes 
WHILE (1=1) 
BEGIN 
    FETCH NEXT FROM curIndexes 
    INTO @objectid, @indexid, @density, @fragmentation, @numrows; 
    IF @@FETCH_STATUS < 0 BREAK; 
 
    SELECT  
        @objectname = QUOTENAME(o.name) 
        , @schemaname = QUOTENAME(s.name) 
    FROM  
        sys.objects AS o 
        INNER JOIN sys.schemas as s ON s.schema_id = o.schema_id 
    WHERE  
        o.object_id = @objectid; 
 
    SELECT  
        @indexname = QUOTENAME(name) 
        , @fillfactorset = CASE fill_factor WHEN 0 THEN 0 ELSE 1 END 
    FROM  
        sys.indexes 
    WHERE 
        object_id = @objectid AND index_id = @indexid; 
 
    IF ((@density BETWEEN 75.0 AND 85.0) AND @fillfactorset = 1) OR (@fragmentation < 30.0) 
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REORGANIZE'; 
    ELSE IF @numrows >= 5000 AND @fillfactorset = 0 
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD WITH (FILLFACTOR = 90)'; 
    ELSE 
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD'; 
    EXEC (@command);  
END 
 
-- Close and deallocate the cursor. 
CLOSE curIndexes; 
DEALLOCATE curIndexes; 
 
IF EXISTS (SELECT * FROM @work_to_do) 
BEGIN 
    SELECT @numpages = @numpages - sum(ps.used_page_count) 
    FROM 
        @work_to_do AS fi 
        INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id 
        INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id 
END  
 
--Update all statistics  
EXEC sp_updatestats  
"@
    Write-Verbose ("Connecting to {0}" -f $UpdateServer)
    Try {
        If (Get-Module -List -Name UpdateServices) {
            $Wsus = Get-WSUSServer -Name $UpdateServer -PortNumber $Port
        } Else {
            $Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($UpdateServer,$Secure,$Port)
        }
        $db = $wsus.GetDatabaseConfiguration().CreateConnection()
        Write-Verbose ("Connecting to {0} on {1}" -f $db.databasename,$db.servername)
        $db.Connect()
        If ($PSCmdlet.ShouldProcess($db.Databasename,'Database Maintenance')) {
            $db.ExecuteCommandNoResult($tSQL,[System.Data.CommandType]::Text)
            $db.CloseCommand()
            $db.Close()
        }   
    } Catch {
        Write-Warning ("{0}" -f $_.Exception.Message)
    }
    Write-Verbose "Completed"
}