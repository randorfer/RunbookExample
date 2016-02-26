Configuration HybridRunbookWorker
{
    Param(
    )

    #Import the required DSC Resources
    Import-DscResource -Module xNetworking

    Node 'HybridRunbookWorker'
    {
        xFireWall OMS_HTTPS_Access
        {
            Direction = 'Outbound'
            Name = 'HybridWorker-HTTPS'
            DisplayName = 'Hybrid Runbook Worker (HTTPS)'
            Description = 'Allow Hybrid Runbook Worker Communication'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            RemotePort = '443'
            RemoteAddress = '*.cloudapp.net'
        }
        xFireWall OMS_Sandbox_Access
        {
            Direction = 'Outbound'
            Name = 'HybridWorker-Sandbox'
            DisplayName = 'Hybrid Runbook Worker (Sandbox)'
            Description = 'Allow Hybrid Runbook Worker Communication'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            RemotePort = '9354'
            RemoteAddress = '*.cloudapp.net'
        }
        xFireWall OMS_PortRange
        {
            Direction = 'Outbound'
            Name = 'HybridWorker-PortRange'
            DisplayName = 'Hybrid Runbook Worker (Port-Range)'
            Description = 'Allow Hybrid Runbook Worker Communication'
            Enabled = $true
            Action = 'Allow'
            Protocol = 'TCP'
            RemotePort = '30000-30199'
            RemoteAddress = '*.cloudapp.net'
        }
    }
}

