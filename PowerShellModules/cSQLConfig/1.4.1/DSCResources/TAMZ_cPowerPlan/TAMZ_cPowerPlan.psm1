function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$PlanName
	)
    $CurrPerf = $(powercfg -getactivescheme)
    $CurrStart = $CurrPerf.IndexOf("(")+1
    $CurrEnd = $CurrPerf.Length-$CurrStart-1
    $CurrPerfName =$CurrPerf.Substring($CurrStart,$CurrEnd)

    $returnValue =@{
        PlanName = $CurrPerfName
    }
    $returnValue
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$PlanName
	)

    Write-Verbose -Message "Setting Powerplan to $PlanName" 
    Try 
    {
        $ReqPerf = powercfg -l | %{if($_.contains($PlanName)) {$_.split()[3]}}
        $CurrPlan = $(powercfg -getactivescheme).split()[3]
        if ($CurrPlan -ne $ReqPerf) {powercfg -setactive $ReqPerf}
    }
    
    Catch 
    {
        Write-Warning -Message "Unable to set power plan"
    }

}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$PlanName
	)

    $ElementGuid = $(powercfg -getactivescheme).split()[3]
    $ReqPerfGuid = powercfg -l | %{if($_.contains($PlanName)) {$_.split()[3]}}
    $ReqPerf = powercfg -l | Where-Object {$_.contains($PlanName)}
    $ElementStart = $ReqPerf.IndexOf("(")+1
    $ElementEnd = $Reqperf.Length -$ElementStart -3
    
    $CurrPerf = $(powercfg -getactivescheme)
    $CurrStart = $CurrPerf.IndexOf("(")+1
    $CurrEnd = $CurrPerf.Length-$CurrStart-1
    $CurrPerfName =$CurrPerf.Substring($CurrStart,$CurrEnd)

    If($ElementGuid -eq $ReqPerfGuid)
    {
        Write-Verbose -Message "PowerPlan is set to $PlanName Already"
        return $true
    }
    else
    {
        Write-Verbose -Message "PowerPlan is $CurrPerfName Expect $PlanName"
        return $false
    }
}



Export-ModuleMember -Function *-TargetResource

