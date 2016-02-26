class TestNetConnectionResult
{
    [string] $ComputerName

    #The Remote IP address used for connectivity
    [System.Net.IPAddress] $RemoteAddress

    #Indicates if the Ping was successful
    [bool] $PingSucceeded

    #Details of the ping
    [System.Net.NetworkInformation.PingReply] $PingReplyDetails

    #The TCP socket
    [System.Net.Sockets.Socket] $TcpClientSocket

    #If the test succeeded
    [bool] $TcpTestSucceeded

    #Remote port used
    [uint32] $RemotePort

    #The results of the traceroute
    [string[]] $TraceRoute

    #An indicator to the formatter that details should be shown
    [bool] $Detailed

    #Information on the interface used for connectivity
    [string] $InterfaceAlias
    [uint32] $InterfaceIndex
    [string] $InterfaceDescription
    [Microsoft.Management.Infrastructure.CimInstance] $NetAdapter
    [Microsoft.Management.Infrastructure.CimInstance] $NetRoute

    #Source IP address
    [Microsoft.Management.Infrastructure.CimInstance] $SourceAddress

    #DNS information
    [bool] $NameResolutionSucceeded
    [object] $BasicNameResolution
    [object] $LLMNRNetbiosRecords
    [object] $DNSOnlyRecords
    [object] $AllNameResolutionResults

    #NetSec Info
    [bool] $IsAdmin #If the test succeeded
    [string] $NetworkIsolationContext
    [Microsoft.Management.Infrastructure.CimInstance[]] $MatchingIPsecRules
}

function Test-NetConnection
{
    [CmdletBinding( )]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)] [Alias('RemoteAddress','cn')] [string] $ComputerName = "internetbeacon.msedge.net",

        [Parameter(ParameterSetName = "ICMP", Mandatory = $False)]  [Switch]$TraceRoute ,
        [Parameter(ParameterSetName = "ICMP", Mandatory = $False)] [ValidateRange(1,120)] [int]$Hops = 30,

        [Parameter(ParameterSetName = "CommonTCPPort", Mandatory = $True, Position = 1)] [ValidateSet("HTTP","RDP","SMB","WINRM")] [String]$CommonTCPPort ="",
        [Parameter(ParameterSetName = "RemotePort", Mandatory = $True, ValueFromPipelineByPropertyName = $true)] [Alias('RemotePort')] [ValidateRange(1,65535)] [int]$Port = 0,

        [Parameter()] [ValidateSet("Quiet","Detailed")] [String]$InformationLevel = "Standard"
    )

    Begin
    {

        ##Description: Checks if the local execution context is elevated
        ##Input: None
        ##Output: Boolean. True if the local execution context is elevated.
        function CheckIfAdmin 
        {
            $CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $CurrentSecurityPrincipal = [System.Security.Principal.WindowsPrincipal]::new($CurrentIdentity)
            $AdminPrincipal = [System.Security.Principal.WindowsBuiltInRole]::Administrator
            return $CurrentSecurityPrincipal.IsInRole($AdminPrincipal)
        }

        ##Description: Returns the remote IP address used for connectivity.
        ##Input: The user-provided computername that will be pinged/tested
        ##Output: An IP address for the remote host
        function ResolveTargetName
           {

                param($TargetName,$TargetPort)

                $RemoteAddress = [System.Net.IPAddress]::Loopback
                if ([System.Net.IPAddress]::TryParse($TargetName, [ref]$RemoteAddress))
                {
                    return $RemoteAddress
                }

                try
                {
                    $UDPClient = [System.Net.Sockets.UDPClient]::new($TargetName,$TargetPort)
                    $UDPClient.Connect($TargetName,$TargetPort)
                    return $UDPClient.Client.RemoteEndPoint.Address
                }
                catch [System.Net.Sockets.SocketException]
                {
                    Write-Exception -Exception $_
                    $Message = "Name resolution of $TargetName failed -- Status: " + $_.Exception.InnerException.SocketErrorCode.ToString()
                    Write-Warning $Message
                    return $null
                }
           }

        ##Description: Pings a specified host
        ##Input: IP address to ping
        ##Output: PingReplyDetails for the ping attempt to host
        function PingTest
        {
            param($TargetIPAddress)
            $Ping = [System.Net.NetworkInformation.Ping]::new()

            ##Indeterminate progress indication
            Write-Progress  -Activity "Test-NetConnection :: $TargetIPAddress" -Status "Ping/ICMP Test" -CurrentOperation "Waiting for echo reply" -SecondsRemaining -1 -PercentComplete -1

            try
            {
                return $Ping.Send($TargetIPAddress)
            }
            catch [System.Net.NetworkInformation.PingException]
            {
                $Message = "Ping to $TargetIPAddress failed -- Status: " + $_.Exception.InnerException.Message.ToString()
                Write-Warning $Message
                return $null
            }
        }

        ##Description: Traces a route to a specified IP address using repetitive echo requests
        ##Input: IP address to trace against
        ##Output: Array of IP addresses representing the traced route. The message from the ping reply status is emmited, if there is no response.
        function TraceRoute
        {
            param($TargetIPAddress,$Hops)
            $Ping = [System.Net.NetworkInformation.Ping]::new()
            $PingOptions = [System.Net.NetworkInformation.PingOptions]::new()
            $PingOptions.Ttl=1
            [byte[]]$DataBuffer = @()
            1..10 | foreach {$DataBuffer += [byte]0}
            $ReturnTrace = @()
             
            do
            {
                try
                {
                    $CurrentHop = [int] $PingOptions.Ttl
                    write-progress -CurrentOperation "TTL = $CurrentHop" -Status "ICMP Echo Request (Max TTL = $Hops)" -Activity "TraceRoute" -PercentComplete -1 -SecondsRemaining -1
                    $PingReplyDetails = $Ping.Send($TargetIPAddress, 4000, $DataBuffer, $PingOptions)

                    if($PingReplyDetails.Address -eq $null)
                    {
                         $ReturnTrace += $PingReplyDetails.Status.ToString()
                    }
                    else
                    {
                         $ReturnTrace += $PingReplyDetails.Address.IPAddressToString
                    }
              }
              catch
              {
                    Write-Debug "Exception thrown in PING send"
                 $ReturnTrace += "..."
              }
              $PingOptions.Ttl++
          }
          while(($PingReplyDetails.Status -ne 'Success') -and ($PingOptions.Ttl -le $Hops))

            ##If the last entry in the trace does not equal the target, then the trace did not successfully complete
            if($ReturnTrace[-1] -ne $TargetIPAddress)
                {
                    $OutputString = "Trace route to destination " + $TargetIPAddress + " did not complete. Trace terminated :: " + $ReturnTrace[-1]
                    Write-Warning $OutputString
                }

           return $ReturnTrace
        }

        ##Description: Attempts a TCP connection against a specified IP address
        ##Input: IP address and port to connect to
        ##Output: If the connection succeeded (as a boolean), and the socket
        function TestTCP
        {
            param($TargetName,$TargetPort)
            try
            {
                $ProgressString = "Test-NetConnection - " + $TargetName + ":" + $TargetPort
                Write-Progress -Activity $ProgressString -Status "Attempting TCP connect" -CurrentOperation "Waiting for response" -SecondsRemaining -1 -PercentComplete -1
                $TCPClient = [System.Net.Sockets.TcpClient]::new($TargetName, $TargetPort)
                return $TCPClient.Client, $TCPClient.Connected;
            }
            catch
            {
                Write-Debug "Exception thrown in TCP connect"
                return $null
            }
        }

        ##Description: Modifies the provided object with the correct local connectivty information
        ##Input: TestNetConnectionResults object that will be modified
        ##Output: Modified TestNetConnectionResult object
        function ResolveRoutingandAdapterWMIObjects
        {
            param($TestNetConnectionResult)

            try
            {
                $TestNetConnectionResult.SourceAddress, $TestNetConnectionResult.NetRoute = Find-NetRoute -RemoteIPAddress $TestNetConnectionResult.RemoteAddress -ErrorAction SilentlyContinue
                $TestNetConnectionResult.NetAdapter = $TestNetConnectionResult.NetRoute | Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue

                $TestNetConnectionResult.InterfaceAlias = $TestNetConnectionResult.NetRoute.InterfaceAlias
                $TestNetConnectionResult.InterfaceIndex = $TestNetConnectionResult.NetRoute.InterfaceIndex
                $TestNetConnectionResult.InterfaceDescription =  $TestNetConnectionResult.NetAdapter.InterfaceDescription
            }
            catch
            {
                Write-Debug "Exception thrown in ResolveRoutingandAdapterWMIObjects"
            }
            return $TestNetConnectionResult
        }

        ##Description: Resolves the DNS details for the computername
        ##Input: The TestNetConnectionResults object that will be "filled in" with DNS information
        ##Output: The modified TestNetConnectionResults object
        function ResolveDNSDetails
        {
            param($TestNetConnectionResult)
            $TestNetConnectionResult.DNSOnlyRecords = @( Resolve-DnsName $ComputerName -DnsOnly -NoHostsFile -Type A_AAAA -ErrorAction SilentlyContinue | where-object {($_.QueryType -eq "A") -or ($_.QueryType -eq "AAAA") } )
            $TestNetConnectionResult.LLMNRNetbiosRecords = @( Resolve-DnsName $ComputerName -LlmnrNetbiosOnly   -NoHostsFile -ErrorAction SilentlyContinue | where-object {($_.QueryType -eq "A") -or ($_.QueryType -eq "AAAA") } )
            $TestNetConnectionResult.BasicNameResolution = @(Resolve-DnsName $ComputerName -ErrorAction SilentlyContinue | where-object {($_.QueryType -eq "A") -or ($_.QueryType -eq "AAAA")} )

            $TestNetConnectionResult.AllNameResolutionResults = $Return.BasicNameResolution  + $Return.DNSOnlyRecords + $Return.LLMNRNetbiosRecords | Sort-Object -Unique -Property Address
            return $TestNetConnectionResult
        }

        ##Description: Resolves the network security details for the computername
        ##Input: The TestNetConnectionResults object that will be "filled in" with network security information
        ##Output: Teh modified TestNetConnectionResults object
        function ResolveNetworkSecurityDetails
        {
            param($TestNetConnectionResult)
            $TestNetConnectionResult.IsAdmin  = CheckIfAdmin
            $NetworkIsolationInfo = Invoke-CimMethod -Namespace root\standardcimv2 -ClassName MSFT_NetAddressFilter -MethodName QueryIsolationType -Arguments @{InterfaceIndex = [uint32]$TestNetConnectionResult.InterfaceIndex; RemoteAddress = [string]$TestNetConnectionResult.RemoteAddress} -ErrorAction SilentlyContinue

            switch ($NetworkIsolationInfo.IsolationType)
            {
                1 {$TestNetConnectionResult.NetworkIsolationContext = "Private Network";}
                0 {$TestNetConnectionResult.NetworkIsolationContext = "Loopback";}
                2 {$TestNetConnectionResult.NetworkIsolationContext = "Internet";}
            }

            ##Elevation is required to read IPsec information for the connection.
            if($TestNetConnectionResult.IsAdmin)
            {
                $TestNetConnectionResult.MatchingIPsecRules = Find-NetIPsecRule -RemoteAddress $TestNetConnectionResult.RemoteAddress  -RemotePort $TestNetConnectionResult.RemotePort -Protocol TCP -ErrorAction SilentlyContinue
            }

            return $TestNetConnectionResult
        }
    }

    Process
    {
        ##Construct the return object and fill basic details
        $Return = [TestNetConnectionResult]::new()
        $Return.ComputerName = $ComputerName
        $Return.Detailed = ($InformationLevel -eq "Detailed")

        #UDP connect is done, to simplify name resolution and source address detection
        $Return.RemoteAddress = ResolveTargetName -TargetName $ComputerName -TargetPort $Return.RemotePort

        if($Return.RemoteAddress -eq $null)
        {
            if($InformationLevel -eq "Quiet")
            {
                return  $false
            }
            return $Return
        }
        else
        {
            $Return.NameResolutionSucceeded = $True
        }

        ##Ping
        $Return.PingReplyDetails = PingTest -TargetIPAddress $Return.RemoteAddress
        if ($Return.PingReplyDetails -ne $null)
        {
            $Return.PingSucceeded = ($Return.PingReplyDetails.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)

            ##Output a warning message if the ping did not succeed
            if(!$Return.PingSucceeded)
            {
                $WarningString = "Ping to $ComputerName failed -- Status: " + $Return.PingReplyDetails.Status.ToString()
                write-warning $WarningString
            }
        }

        #### Begin TCP test ####
        $TCPTestAttempted = $False

            ##Check if the user specified a port directly
            if ($Port -ne 0)
            {
                Write-Debug "User specified a port directly."
                $TCPTestAttempted = $True
                $Return.RemotePort = $Port;
                $Return.TcpClientSocket, $Return.TcpTestSucceeded = TestTCP -TargetName $Return.ComputerName -TargetPort $Return.RemotePort

            }
            ##If no port was specified directly, then we check to see if a CommonTCPPort was specified
            if ($CommonTCPPort -ne "")
            {
                switch ($CommonTCPPort)
                {
                    "HTTP" {$Return.RemotePort = 80}
                    "RDP" {$Return.RemotePort = 3389}
                    "SMB" {$Return.RemotePort = 445}
                    "WINRM" {$Return.RemotePort = 5985}
                }

                $TCPTestAttempted = $True
                $Return.TcpClientSocket,$Return.TcpTestSucceeded = TestTCP -TargetName $Return.ComputerName -TargetPort $Return.RemotePort
            }

            ##If the user specified "quiet" then we should only return a boolean
            if($InformationLevel -eq "Quiet")
            {
                if($TCPTestAttempted)
                    {
                        return  $Return.TcpTestSucceeded
                    }
                else
                    {
                        return  $Return.PingSucceeded
                    }
            }

            ##If we did a TCP test and it failed (did not succeed) then we need to write a warning
            if((!$Return.TcpTestSucceeded) -and ($TCPTestAttempted))
            {
               $WarningString = "TCP connect to $ComputerName"+ ":" + $Return.RemotePort +" failed"
                write-warning $WarningString
            }
        #### End of TCP test ####

        ##TraceRoute, only occurs if switched by the user
        if($TraceRoute -eq $True)
        {
            $Return.TraceRoute = TraceRoute -TargetIPAddress $Return.RemoteAddress -Hops $Hops
        }

        $DNSClientCmdletExists = Get-Command Resolve-DnsName -ErrorAction SilentlyContinue
        if ($DNSClientCmdletExists)
        {
            $Return = ResolveDNSDetails -TestNetConnectionResult $Return
        }
        $Return = ResolveNetworkSecurityDetails -TestNetConnectionResult $Return
        $Return = ResolveRoutingandAdapterWMIObjects -TestNetConnectionResult $Return


        return $Return
    }
}

##Export cmdlet and alias to module
New-Alias TNC Test-NetConnection
Export-ModuleMember -Alias TNC -Function Test-NetConnection
