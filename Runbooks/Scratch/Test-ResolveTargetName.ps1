<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Test-ResolveTargetName

Try
{
        $TargetName = 'www.google.com'
        $TargetPort = 0

        $RemoteAddress = [System.Net.IPAddress]::Loopback
        if ([System.Net.IPAddress]::TryParse($TargetName, [ref]$RemoteAddress))
        {
            return $RemoteAddress
        }

        
        $UDPClient = [System.Net.Sockets.UDPClient]::new($TargetName,$TargetPort)
        $UDPClient.Connect($TargetName,$TargetPort)
        return $UDPClient.Client.RemoteEndPoint.Address

}
Catch
{
    $Exception = $_
    $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
    Switch ($ExceptionInfo.FullyQualifiedErrorId)
    {
        Default
        {
            Write-Exception $Exception -Stream Warning
        }
    }
}

Write-CompletedMessage @CompletedParameters
