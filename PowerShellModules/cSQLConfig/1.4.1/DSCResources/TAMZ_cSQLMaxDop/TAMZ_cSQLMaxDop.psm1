function ConnectSQL
{
    param
    (
		[System.String]
		$SQLServer = $env:COMPUTERNAME,

		[System.String]
		$SQLInstanceName = "MSSQLSERVER"
    )
    
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    
    if($SQLInstanceName -eq "MSSQLSERVER")
    {
        $ConnectSQL = $SQLServer
    }
    else
    {
        $ConnectSQL = "$SQLServer\$SQLInstanceName"
    }

    Write-Verbose "Connecting to SQL $ConnectSQL"
    $SQL = New-Object Microsoft.SqlServer.Management.Smo.Server $ConnectSQL

    if($SQL)
    {
        Write-Verbose "Connected to SQL $ConnectSQL"
        $SQL
    }
    else
    {
        Write-Verbose "Failed connecting to SQL $ConnectSQL"
    }
}

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.Boolean]
		$DynamicAlloc
	)
    
    $SQLServer =$env:COMPUTERNAME
    $SQLInstanceName = "MSSQLSERVER"

    if(!$SQL)
    {
        $SQL = ConnectSQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    if($SQL)
    {
       Write-Verbose "Getting Current MaxDop Configuration"
       $GetMaxDop = $sql.Configuration.MaxDegreeOfParallelism.ConfigValue
       If($GetMaxDop)
       {
            Write-Verbose "MaxDop is $GetMaxDop"
       }
    }
    $returnValue = @{
            DynamicAlloc =$DynamicAlloc
		    MaxDop = $GetMaxDop 
            }
    $returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.Boolean]
		$DynamicAlloc,

		[System.Int32]
		$MaxDop,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    $SQLServer =$env:COMPUTERNAME
    $SQLInstanceName = "MSSQLSERVER"

    if(!$SQL)
    {
        $SQL = ConnectSQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    if($SQL)
    {
        
        switch($Ensure)
        {
            "Present"
            {
                If($DynamicAlloc -eq $True)
                {
                    $NumCores = $SQL.Processors
                    $NumProcs = ($sql.AffinityInfo.NumaNodes | Measure-Object).Count
                    if ($NumProcs -eq 1) 
                    {
                        $MaxDop =  ($NumCores /2)
                        $MaxDop=[math]::round( $MaxDop,[system.midpointrounding]::AwayFromZero)
                    }
                    elseif ($NumCores -ge 8) 
                    {
                        $MaxDop = 8
                    }
                    else
                    {
                        $MaxDop = $NumCores
                    }
                } 
            }
                
            "Absent"
            {
                $MaxDop = 0
            }

            }

            try
            {
                Write-Verbose -Message "Setting MaxDop to $MaxDop"
                $sql.Configuration.MaxDegreeOfParallelism.ConfigValue =$MaxDop
                $sql.alter()
            }
            catch
            {
                Write-Verbose "Failed setting MaxDop to $MaxDop"
            }
    }
}      

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.Boolean]
		$DynamicAlloc,

		[System.Int32]
		$MaxDop,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    $SQLServer =$env:COMPUTERNAME
    $SQLInstanceName = "MSSQLSERVER"

    if(!$SQL)
    {
        $SQL = ConnectSQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }
    
    $GetMaxDop = $SQL.Configuration.MaxDegreeOfParallelism.ConfigValue
    switch($Ensure)
    {
        "Present"
        {
            If ($DynamicAlloc)
            {
                
                If ($GetMaxDop -eq 0)
                {
                    Write-verbose -message "Current MaxDop is $GetMaxDop should be updated to $MaxDop"
                    return $false
                }
                else 
                {
                    Write-verbose -message "Current MaxDop is configured at $GetMaxDop."
                    return $True
                }
            }
            else
            {
                If ($GetMaxDop -eq $MaxDop)
                {
                    Write-verbose -message  "Current MaxDop is at Requested value. Do nothing." 
                    return $true
                }
                else 
                {
                    Write-verbose -message  "Current MaxDop is $GetMaxDop should be updated to $MaxDop"
                    return $False
                }
            }
        }
        "Absent" 
        {
            If ($GetMaxDop -eq 0)
            {
                Write-verbose -message  "Current MaxDop is at Requested value. Do nothing." 
                return $true
            }
            else 
            {
                Write-verbose -message  "Current MaxDop is $GetMaxDop should be updated"
                return $False
            }
        }
    }
}



Export-ModuleMember -Function *-TargetResource

