function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $DomainName,

        [parameter(Mandatory = $true)]
        [PSCredential]$Credential
    )

    $returnValue = @{
		DomainName = (Get-WmiObject -Class WIN32_ComputerSystem).Domain
        Credential = $Credential
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
        $DomainName,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    Add-Computer -WorkGroupName $WorkGroupName -Credential $Credential -Force
    $global:DSCMachineStatus = 1
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $DomainName,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    return ((Get-WmiObject -Class WIN32_ComputerSystem).Domain -as [string]).ToLower().Equals($DomainName.ToString().ToLower())
}


Export-ModuleMember -Function *-TargetResource

