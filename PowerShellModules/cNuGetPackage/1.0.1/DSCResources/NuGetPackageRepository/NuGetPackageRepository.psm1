$NuGet = "$PSScriptRoot\..\..\bin\nuget.exe"
function GetNugetConfig
{
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )
    $ErrorActionPreference = 'Stop'

    $ConfigData = (& $nuget sources) -as [string]
    
    $Source = [string]::Empty
    $UserName = [string]::Empty
    $Ensure = 'Absent'
    if($ConfigData -match "$Name \[([^\]]+)]\s+([^\s]+)")
    {
        $Source = $Matches[2]
        if($Matches[1] -eq 'Enabled') { $Ensure = 'Present' }
    }
    $returnValue = @{
        Name = $Name
        Source = $Source
        Credential = [ciminstance]$convertToCimCredential
        Ensure = $Ensure
    }

    $returnValue
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Source,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure
    )
    
    $returnValue = GetNugetConfig -Name $Name

    $returnValue    
}
Export-ModuleMember -Function Get-TargetResource -Verbose:$false


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Source,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    $ErrorActionPreference = 'Stop'

    Switch($Ensure)
    {
        'Present'
        {
            Try { $Null = & $NuGet sources remove -name $Name } Catch {}
            if($Credential) 
            {
                $Output = & $NuGet sources add -name $Name -Source $Source -UserName $($Credential.UserName) -Password $($Credential.GetNetworkCredential().Password)
            }
            else 
            { 
                $Output = & $NuGet sources add -name $Name -Source $Source
            }
        }
        'Absent'
        {
            $Output = & $NuGet sources Remove -Name $Name
        }
    }
    Write-Debug -Message $Output
}
Export-ModuleMember -Function Set-TargetResource -Verbose:$false


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Source,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.Management.Automation.PSCredential]
        $Credential
    )

    $NuGetConfig = GetNugetConfig -Name $Name

    if($Source -ne $NuGetConfig.Source) { Return $false }
    if($Ensure -ne $NuGetConfig.Ensure) { Return $false }
    else
    {
        return (-not $NuGetConfig.Credential.Username -as [bool])
    }
}
Export-ModuleMember -Function Test-TargetResource -Verbose:$false

