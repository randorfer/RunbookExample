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
		$IncludeDisabled,

		[parameter(Mandatory = $true)]
		[System.String[]]
		$AccountstoPass
	)
    $SQLServer =$env:COMPUTERNAME
    $SQLInstanceName = "MSSQLSERVER"

    $AccountArray = @()
    $AccountArray = $AccountstoPass+'sa'+'NT SERVICE\SQLWriter','NT SERVICE\Winmgmt','NT SERVICE\MSSQLSERVER','NT SERVICE\SQLSERVERAGENT', 'NT SERVICE\SQLTELEMETRY'
    if(!$SQL)
    {
        $SQL = ConnectSQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    if($SQL)
    {
        Try
        {
            $SAAccounts = $SQL.Roles["sysadmin"].EnumMemberNames()
            $SACollection= (Compare-Object -ReferenceObject $AccountArray -DifferenceObject $SAAccounts |Where-Object {$_.SideINdicator -eq "=>"}).InputObject
  
            $Count = $SACollection.Count

	        If ($Count -ge 1)
            {
                $Ensure = $false
            }
            else 
            {
                $Ensure = $true
            }
            Write-Verbose -Message "$count Sysadmins found which should not exist."
	        $returnValue = @{
		        IncludeDisabled = $IncludeDisabled
		        AccountstoPass = $AccountstoPass
		        Ensure = $Ensure
	        }
        }
        Catch
        {
            Throw "Unable to Get SysAdmins" 
        }
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
		$IncludeDisabled,

		[parameter(Mandatory = $true)]
		[System.String[]]
		$AccountstoPass,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    $SQLServer =$env:COMPUTERNAME
    $SQLInstanceName = "MSSQLSERVER"
    
    $AccountArray = @()
    $AccountArray = $AccountstoPass+'sa'+'NT SERVICE\SQLWriter','NT SERVICE\Winmgmt','NT SERVICE\MSSQLSERVER','NT SERVICE\SQLSERVERAGENT', 'NT SERVICE\SQLTELEMETRY'
    if(!$SQL)
    {
        $SQL = ConnectSQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    if($SQL)
    {
        try
        {
            $SAAccounts = $SQL.Roles["sysadmin"].EnumMemberNames()

            $SACollection= (Compare-Object -ReferenceObject $AccountArray -DifferenceObject $SAAccounts |Where-Object {$_.SideINdicator -eq "=>"}).InputObject
            $SAtoRemove =@()

            foreach ($login in $SACollection)
            {
                Write-Verbose -Message "$login is about to be removed from SA"
                $SQL.Roles["Sysadmin"].DropMember($login)
                Write-Verbose -Message "$login has been removed"
            }

            Write-Verbose -Message "Users not needing SA have been removed."
        }
        catch
        {
            throw "Users were not able to be removed."
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
		$IncludeDisabled,

		[parameter(Mandatory = $true)]
		[System.String[]]
		$AccountstoPass,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
	)
    $SQLServer =$env:COMPUTERNAME
    $SQLInstanceName = "MSSQLSERVER"
    
    $AccountArray = @()
    $AccountArray = $AccountstoPass+'sa'+'NT SERVICE\SQLWriter','NT SERVICE\Winmgmt','NT SERVICE\MSSQLSERVER','NT SERVICE\SQLSERVERAGENT', 'NT SERVICE\SQLTELEMETRY'
    if(!$SQL)
    {
        $SQL = ConnectSQL -SQLServer $SQLServer -SQLInstanceName $SQLInstanceName
    }

    if($SQL)
    {
        try
        {
            $SAAccounts = $SQL.Roles["sysadmin"].EnumMemberNames()
            $SACollection= (Compare-Object -ReferenceObject $AccountArray -DifferenceObject $SAAccounts |Where-Object {$_.SideINdicator -eq "=>"}).InputObject
            $Count = $SACollection.Count
    
            If ($Count -ge 1)
            {
                Write-Verbose -Message "SA's exist on the box Test Fails."
                return $false
            }
            else 
            {
                return $true
            }
        }
        catch
        {
            Throw "Failure getting Sysadmin information for Test"
        }
    }
}



Export-ModuleMember -Function *-TargetResource

