Configuration DomainServer
{
    Import-DscResource -ModuleName cDomainComputer

    $Domain = @(
        'a.com'
        'b.com'
        'c.com'
        'd.com'
        'e.com'
    )
    Foreach($_Domain in $Domain)
    {
        $DomainJoinCredential = Get-AutomationPSCredential -Name "DomainCred-$($_Domain)"
        Node "Defaultweb"
        {
            WindowsFeature installIIS 
            { 
                Ensure="Present" 
                Name="Web-Server" 
            }

            cDomainComputer DomainJoin
            {
                DomainName = $_Domain
                Credential = $DomainJoinCredential
            }
        }
    }
}