<#
.SYNOPSIS
    Converts a string in the format contoso.com/Sites/MGO/Users/Joseph Sauer to the
    normale dn format

    CN=Joseph Sauer,OU=Users,OU=MGO,OU=Sites,DC=contoso,DC=com
#>
Function ConvertTo-DistinguishedName
{
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline = $True)]
        [String] $Identity
    )
    $CompletedParameters = Write-StartingMessage -Stream Debug
    $IdentityPart = $Identity | 
        Select-String -AllMatches '([^[/]+)' |
            Select-Object -ExpandProperty Matches |
                Select-Object -ExpandProperty Value

    $StringBuilder = New-Object -TypeName System.Text.StringBuilder
    For($i = -1 ; $i -ge -1*($IdentityPart -as [array]).Count ; $i--)
    {
        $_IdentityPart = $IdentityPart[$i]
        if($i -eq -1)
        { 
            $Null = $StringBuilder.Append("CN=$_IdentityPart")
        }
        elseif ($i -eq -1*($IdentityPart -as [array]).Count)
        {
            foreach($str in $_IdentityPart.Split('.'))
            {
                $Null = $StringBuilder.Append(",DC=$str")
            }
        }
        else
        {
            $Null = $StringBuilder.Append(",OU=$_IdentityPart")
        }
    }
    Write-CompletedMessage @CompletedParameters
    return $StringBuilder.ToString()
}

<#
    .Synopsis
        Checks to see if the target AD group exists and is of category Security
#>
Function Test-ADSecurityGroup
{
    [OutputType([bool])]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADGroup]
        $Identity,

        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $null,

        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $null
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $GetParams = @{
            'Identity' = $Identity
        }
        if($Server -as [bool]) { $Null = $GetParams.add('Server',$Server) }
        if($Credential -as [bool]) { $Null = $GetParams.add('Credential',$Credential) }
        
        $ADGroup = Get-ADGroup @GetParams
    }
    Catch 
    {
        $Exception = $_
        $ExceptionInformation = Get-ExceptionInfo -Exception $Exception
        Switch($ExceptionInformation.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams
    Return $ADGroup.GroupCategory -eq 'Security'
}


<#
.SYNOPSIS
    Given a DateTime, returns a timestamp suitable for use in an LDAP filter
    (e.g. for comparison to lastLogonTimestamp).

.PARAMETER DateTime
    The DateTime object to convert to an LDAP timestamp.
#>
Function ConvertTo-LDAPTimestamp
{
    param(
        [Parameter(Mandatory=$True)]
        [DateTime]
        $DateTime
    )
    return $DateTime.ToFileTime()
}

<#
.SYNOPSIS
    Given a partial distinguished name and a domain, returns a full distinguished name.

.PARAMETER DNPart
    The partial distinguished name.

.PARAMETER Domain
    The domain that the distinguished name exists in.

.EXAMPLE
    > Get-FullDN -DNPart 'OU=Disabled Computers,OU=Information Systems' -Domain 'contoso.COM'
    OU=Disabled Computers,OU=Information Systems,DC=contoso,DC=COM
#>
Function Get-FullDN
{
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $DNPart,

        [Parameter(Mandatory=$True)]
        [String]
        $Domain
    )

    $DomainDN = ConvertTo-DomainDN -Domain $Domain
    return ($DNPart + ',' + $DomainDN)
}

<#
.SYNOPSIS
    Given an LDAP filter with extraneous whitespace, removes the whitespace
    and substitutes in the given FormatArgs.

.DESCRIPTION
    Format-LDAPFilter takes an LDAP filter string, removes any extra whitespace
    from it, then uses the -f operator to insert the given FormatArgs.

    Because LDAP does not like extra whitespace, this function can be used to
    write readable LDAP filters and apply processing to them so that they
    may be used.

.PARAMETER Filter
    The LDAP filter to format.

.PARAMETER FormatArgs
    Values that should be substituted into the LDAP filter.

.EXAMPLE
    > $LDAPComputerFilter = "
      (|
          (&
              (lastLogonTimestamp <= {0})
              (!memberOf = {2})
          )
          (&
              (lastLogonTimestamp <= {0})
              (memberOf = {1})
          )
      )
      "
      Format-LDAPFilter -Filter $LDAPComputerFilter -FormatArgs 'arg0', 'arg1', 'arg2'

    (|(&(lastLogonTimestamp<=arg0)(!memberOf=arg2))(&(lastLogonTimestamp<=arg0)(memberOf=arg1)))
#>
Function Format-LDAPFilter
{
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $Filter,

        [Parameter(Mandatory=$False)]
        [AllowEmptyCollection()]
        [String[]]
        $FormatArgs = @()
    )

    return ($Filter -replace '\s+', '') -f $FormatArgs
}

<#
.SYNOPSIS
    Given an Active Directory identity, parses out domain (if available) and username information.
    Recognizes down-level logon names (contoso\user) and user principal names (user@contoso.COM).

.PARAMETER Identity
    The identity to parse.
#>
Function Get-ADIdentityInfo
{
    param([Parameter(Mandatory=$True)] [String] $Identity)

    $IdentityInfo = [PSCustomObject] @{
        'Name' = $null;
        'Domain' = $null;
    }
    if($Identity.StartsWith('CN='))
    {
        $MatchSets = $Identity | Select-String -Pattern 'DC=([^,]+)' -AllMatches
        $IdentityInfo.Domain = ($MatchSets.Matches | ForEach-Object -Process { $_.Groups[1].Value }) -join '.'
        $IdentityInfo.Name = (Get-ADObject -Identity $Identity -Server $IdentityInfo.Domain -Properties 'SamAccountName').SamAccountName
    }
    elseif($Identity -like '*@*')
    {
        # It's a user principal name, e.g. 'user@contoso.com'
        $IdentityInfo.Name, $IdentityInfo.Domain = $Identity -split '@'
    }
    elseif($Identity -like '*\*')
    {
        # It's a down-level logon name
        $Domain, $IdentityInfo.Name = $Identity -split '\\'
    }
    else
    {
        $IdentityInfo.Name = $Identity
    }
    if($IdentityInfo.Domain -ne $null)
    {
        $IdentityInfo.Domain = $IdentityInfo.Domain.ToUpper()
    }
    return $IdentityInfo
}

<#
.SYNOPSIS
    Given an Active Directory identity, converts the identity to a down-level logon name.

.PARAMETER Identity
    The identity to convert.

.PARAMETER FullDomain
    If specified, includes the full domain name in the domain portion (contoso.COM instead
    of contoso).
#>

<#
.SYNOPSIS
    Given an ID associated with a user, converts the ID into the primary user ID (i.e. AID to GID or XID).
    If the primary username cannot be determined (because it does not exist), throws an exception.

.PARAMETER Identity
    The username to convert.

.PARAMETER Server
    The Active Directory server to communicate with. Defaults to contoso.COM.

    If the identity includes domain-qualifying information (e.g. it is 'EXTcontoso\acct')
    $Server is ignored in favor of the domain specified in $Identity.
#>
Function ConvertTo-PrimaryUserId
{
    Param(
        [Parameter(Mandatory=$True)]  [String]       $Identity,
        [Parameter(Mandatory=$False)] [String]       $Server = 'contoso.com',
        [Parameter(Mandatory=$False)] [Switch]       $AsADUser = $True,
        [Parameter(Mandatory=$False)] [String[]]     $Properties,
        [Parameter(Mandatory=$False)] [String[]]     $AccountPrefix = @('G','X','M'),
        [Parameter(Mandatory=$False)] [PSCredential] $Credential
    )

    $IdentityInfo = Get-ADIdentityInfo -Identity $Identity
    $UserName = $IdentityInfo.Name
    ForEach($Prefix in $AccountPrefix)
    {
        $PrimaryUserName = $Prefix + $UserName.Substring(1)
        Try
        {
            $GetADUserParameters = @{ 'Identity' = $PrimaryUserName ;
                                      'Server'   = $Server ;
                                      'ErrorAction' = 'Stop' }

            If ($Properties) { $GetADUserParameters += @{ 'Properties' = $Properties } }
            If ($Credential) { $GetADUserParameters += @{ 'Credential' = $Credential } }
            $ADUser = Get-ADUser @GetADUserParameters
            If($AsADUser)
            {
                Return $ADUser
            }
            Else
            {
                Return $PrimaryUserName
            }
        }
        Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
        {
            # This isn't the right prefix, try the next one.
        }
    }
    Throw-Exception -Type 'PrimaryIdentityResolutionFailure' `
                    -Message "Unable to determine the primary identity for identity $Identity" `
                    -Property @{
                        'Identity' = $Identity;
                    }
}

<#
.SYNOPSIS
    Given an ID associated with a user, converts the ID into the user's e-mail address.
    If the primary username (which has the 'mail' attribute in AD) for the user does not exist,
    throws an exception.

.PARAMETER Identity
    The username to convert.

.PARAMETER Server
    The Active Directory server to communicate with. Defaults to contoso.COM.
#>
Function ConvertTo-UserEmail
{
    Param(
        [Parameter(Mandatory=$True)]  [String] $Identity,
        [Parameter(Mandatory=$False)] [String] $Server = 'contoso.COM'
    )
    $PrimaryIdentity = ConvertTo-PrimaryUserId -Identity $Identity -Server $Server -AsADUser -Properties 'mail'
    Return $PrimaryIdentity.mail
}
<#
.SYNOPSIS
    Given a ID associated with a group, converts the ID into the groups's e-mail address.
    If the primary username (which has the 'mail' attribute in AD) for the group does not exist,
    throws an exception.

.PARAMETER Identity
    The username to convert.

.PARAMETER Server
    The Active Directory server to communicate with. Defaults to contoso.COM.
#>
Function ConvertTo-GroupEmail
{
    Param(
        [Parameter(Mandatory=$True)]
        [String]
        $Identity
    )
    $IdentityInfo = Get-ADIdentityInfo -Identity $Identity
    $Group = Get-ADGroup -Identity $IdentityInfo.Name -Server $IdentityInfo.Domain -Properties 'mail'
    Return $Group.Mail
}
Function Remove-ComputerFromAD
{
    param(
        [Parameter(Mandatory=$True)] [String] $ComputerName,
        [Parameter(Mandatory=$True)] [String] $Server,
        [Parameter(Mandatory=$True)] $Credential
    )

    try
    {
        $ComputerObject = Get-ADComputer -Identity $ComputerName `
                                         -Server $Server `
                                         -Credential $Credential
        Remove-ADObject -Identity $ComputerObject `
                        -Server $Server `
                        -Confirm:$False `
                        -Credential $Credential `
                        -Recursive `
                        -ErrorAction 'Stop' | Out-Null
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        Write-Warning -Message "[$ComputerName] not found in [$Server]" -WarningAction Continue
    }
    catch
    {
        Throw-Exception -Type 'DeleteFailure' `
                        -Message 'Delete Computer from AD Failed Unexpectedly' `
                        -Property @{
            'ComputerName' = $ComputerName ;
            'Server' = $Server ;
            'CredentialName' = $Credential.UserName ;
            'Error' = Convert-ExceptionToString $_
        }
    }
}
<#
.Synopsis
    Returns the Org Unit for the site that the target user is contained in.

.Description
    Site Org Unit is based on a regex match looking for 'OU=[a-zA-Z][a-zA-Z][a-zA-Z][a-zA-Z]?,OU=Sites.*'

.Parameter Identity
    Identity of the AD User to lookup the containing site OU

.Parameter Properties
    The properties of the org unit to load

.Parameter Credential
    The credential to use for querying Active Directory
#>
Function Get-ADUserSiteOU
{
    [OutputType([Microsoft.ActiveDirectory.Management.ADOrganizationalUnit])]
    Param(
        [Parameter(Mandatory=$True)]
        [Microsoft.ActiveDirectory.Management.ADUser]
        $Identity,
        
        [Parameter(Mandatory=$False)]
        [string[]]
        $Properties,

        [Parameter(Mandatory=$False)]
        [PSCredential]
        $Credential
    )
    Write-Debug -Message 'Starting [Get-ADUserSiteOU]'
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $SiteRegex = 'OU=[a-zA-Z][a-zA-Z][a-zA-Z][a-zA-Z]?,OU=Sites.*'
    $GetADUserParameters = @{
        'Identity' = $Identity
    }
    if($Credential) { $GetADUserParameters.Add('Credential',$Credential) | Out-Null }
    $ADUser = Get-ADUser @GetADUserParameters
    
    #Lookup Site OU based on regex from user's DN
    if($ADUser.DistinguishedName -as [string] -match $SiteRegex -as [string])
    {
        $SiteOU = $Matches[0]
        $GetADSiteOrgUnitParams = @{
            'Identity' = $SiteOU ;

        }
        if($Properties -as [bool]) { $GetADSiteOrgUnitParams.Add('Properties', $Properties) | Out-Null }
        if($Credential -as [bool]) { $GetADSiteOrgUnitParams.Add('Credential', $Credential) | Out-Null }

        $Result = Get-ADOrganizationalUnit @GetADSiteOrgUnitParams
    }
    else
    {
        Throw-Exception -Type 'SiteOrgUnitNotFound' `
                        -Message 'Could not determine the site container for the target AD user' `
                        -Property @{
                            'SiteRegex' = $SiteRegex ;
                            'ADUserDN' = $ADUser.DistinguishedName ;
                            'ADUserProperties' = ConvertTo-JSON -InputObject $ADUser
                        }
    }

    Write-Debug -Message 'Finished [Get-ADUserSiteOU]'
    return $Result -as [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]
}

Function ConvertTo-DomainName
{
    Param(
        [Parameter(
            Mandatory = $True
        )]
        [string]
        $DistinguishedName
    )

    if($DistinguishedName -match '(DC=.*)$')
    {
        $SB = New-Object System.Text.StringBuilder
        $Matches[1].Replace('DC=','').Split(',') | % { $SB.Append(".$_") | Out-Null }
        $SB.ToString().Substring(1)
    }
    else
    {
        Throw-Exception -Type 'DistinguishedNameFormat' `
                        -Message 'The distinguished name passed in does not match the format (DC=.*)$' `
                        -Property @{ 'DistinguishedName' = $DistinguishedName }
    }
}
<#
    .Synopsis
        Validates that a passed user account is a owner or backup owner of a specified group
    .Parameter SamAccountName
        SamAccount name of the user to check
    .Parameter UserDomain
        Domain of the user to check
    .Parameter GroupName
        The name of the group to lookup
    .Parameter GroupDomain
        The domain to look the group up in
    .Parameter Credential
        The credential to use when querying AD
#>
Function Test-ADGroupOwner
{
    [OutputType([bool])]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeLine = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        $OwnerIdentity,

        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeLine = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADGroup]
        $GroupIdentity,

        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeLine = $True
        )]
        [string]
        $UserDomain = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeLine = $True
        )]
        [string]
        $GroupDomain = $Null,
        
        [Parameter(
            Mandatory = $False,
            Position = 4,
            ValueFromPipeLine = $True
        )]
        [pscredential]
        $Credential = $null
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParameters = Write-StartingMessage

    Try
    {

        $GetGroupParams = @{
            'Identity' = $GroupIdentity
            'Properties' = 'ManagedBy','GMICustomAttribute2'
        }
        if($Credential) { $Null = $GetGroupParams.Add('Credential', $Credential) }
        if($GroupDomain) { $Null = $GetGroupParams.Add('Server', $GroupDomain) }

        $GetUserParams = @{
            'Identity' = $OwnerIdentity
            'Properties' = 'mail'
        }
        if($Credential) { $Null = $GetUserParams.Add('Credential', $Credential) }
        if($UserDomain) { $Null = $GetUserParams.Add('Server', $UserDomain) }

        $GetManagerParams = @{ }
        if($Credential) { $Null = $GetManagerParams.Add('Credential', $Credential) }
        if($UserDomain) { $Null = $GetUserParams.Add('Server', $UserDomain) }

        $ADUser = Get-ADUser @GetUserParams
        $ADGroup = Get-ADGroup @GetGroupParams
        $Manager = Get-ADUser -Identity $ADGroup.ManagedBy `
                              @GetManagerParams

        if($ADUser.DistinguishedName -eq $ADGroup.ManagedBy)
        {
            Write-Output -InputObject $True
        }
        elseif($ADGroup.GMICustomAttribute2 -like "*$($ADUser.Mail)*")
        {
            Write-Output -InputObject $False
        }
        else
        {
            Write-Output -InputObject $False
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInformation = Get-ExceptionInfo -Exception $Exception
        Switch($ExceptionInformation.FullyQualifiedErrorId)
        {
            'ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADUser'
            {

                Throw-Exception -Type 'ADUserNotFound' `
                                -Message 'Could not find the target user' `
                                -Property @{ 
                                    'SamAccountName' = $SamAccountName ;
                                    'UserDomain' = $UserDomain 
                                }
            }
            'ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADGroup'
            {
                Throw-Exception -Type 'ADGroupNotFound' `
                                -Message 'Could not find the target group' `
                                -Property @{ 
                                    'GroupName' = $SamAccountName ;
                                    'GroupDomain' = $GroupDomain 
                                }
            }
            Default
            {
                Throw $Exception
            }
        }
    }
    Write-CompletedMessage @CompletedParameters
}
Function Get-ADGroupOwner
{
    [OutputType([Microsoft.ActiveDirectory.Management.ADUser[]])]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeLine = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADGroup]
        $Identity,

        [Parameter(
            Mandatory = $False,
            Position = 1,
            ValueFromPipeLine = $True
        )]
        [string]
        $Server = $Null,
        
        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeLine = $True
        )]
        [pscredential]
        $Credential = $null
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $GetGroupParams = @{
            'Identity' = $Identity
            'Properties' = 'ManagedBy','GMICustomAttribute2'
        }
        if($Credential) { $Null = $GetGroupParams.Add('Credential', $Credential) }
        if($Server) { $Null = $GetGroupParams.Add('Server', $Server) }

        $GetManagedByManagerParams = @{}
        if($Credential) { $Null = $GetManagedByManagerParams.Add('Credential', $Credential) }
        if($Server) { $Null = $GetManagedByManagerParams.Add('Server', $Server) }

        $GetManagedByCustomAttribute2Params = @{}
        if($Credential) { $Null = $GetManagedByCustomAttribute2Params.Add('Credential', $Credential) }
        if($Server) { $Null = $GetManagedByCustomAttribute2Params.Add('Server', $Server) }

        $ADGroup = Get-ADGroup @GetGroupParams

        $Manager = @{}
        $ManagedByManager = (Get-ADUser -Identity $ADGroup.ManagedBy `
                                        @GetManagedByManagerParams)
        
        $Manager.Add($ManagedByManager.SamAccountName, $ManagedByManager)

        if($ADGroup.GMICustomAttribute2 -as [bool])
        {
            Foreach($ManagerEmail in $ADGroup.GMICustomAttribute2.Split(';'))
            {
                $CustomAttribute2Manager = Get-ADUser -Filter { Mail -eq $ManagerEmail } `
                                                      @GetManagedByCustomAttribute2Params
                If($CustomAttribute2Manager -as [bool])
                {
                    if(-not $Manager.ContainsKey($CustomAttribute2Manager.SamAccountName))
                    {
                        $Null = $Manager.Add($CustomAttribute2Manager.SamAccountName, $CustomAttribute2Manager)
                    }
                }
            }
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInformation = Get-ExceptionInfo -Exception $Exception
        Switch($ExceptionInformation.FullyQualifiedErrorId)
        {
            'ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADUser'
            {

                Throw-Exception -Type 'ADUserNotFound' `
                                -Message 'Could not find the target user' `
                                -Property @{ 
                                    'SamAccountName' = $SamAccountName ;
                                    'UserDomain' = $UserDomain 
                                }
            }
            'ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADGroup'
            {
                Throw-Exception -Type 'ADGroupNotFound' `
                                -Message 'Could not find the target group' `
                                -Property @{ 
                                    'GroupName' = $SamAccountName ;
                                    'GroupDomain' = $GroupDomain 
                                }
            }
            Default
            {
                Throw $Exception
            }
        }
    }
    Write-CompletedMessage @CompletedParams
    Return $Manager.Values -as [array]
}
<#
    .Synopsis
        Returns a filtered identity list of users that are not
        already a part of a target group

#>
Function Select-NewADGroupMember
{
    [OutputType([string[]])]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True
        )]
        [string[]]
        $Member,
        
        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADGroup]
        $Identity,

        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $null,

        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $MemberServer = $null,

        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $null
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $GetParams = @{
            'Identity' = $Identity
        }
        $GetUserParams = @{}
        if($Credential) 
        { 
            $Null = $GetParams.Add('Credential', $Credential)
            $Null = $GetUserParams.Add('Credential', $Credential)
        }
        if($Server) { $Null = $GetParams.Add('Server', $Server) }
        if($MemberServer) { $Null = $GetUserParams.Add('Server', $MemberServer) }

        $GroupMember = Get-ADGroupMember @GetParams

        $NewGroupMembers = New-Object System.Collections.ArrayList
            
        Foreach($_user in $Member)
        {
            Try
            {
                $ADUser = Get-ADUser @GetUserParams -Identity $_User
                if($GroupMember.DistinguishedName -notcontains $ADUser.DistinguishedName)
                {
                    Write-Output -InputObject $ADUser.DistinguishedName
                }
            }
            Catch
            {
                Write-Exception -Exception $_ -Stream Warning
            }
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            'ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADGroupMember'
            {
                Throw-Exception -Type 'GroupFindFailure' `
                                -Message 'Could not find the target group' `
                                -Property $GetParams
            }
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams
}
<#
    .Synopsis
        Checks to see if the target AD group exists
#>
Function Test-ADGroup
{
    [OutputType([bool])]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADGroup]
        $Identity,

        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $null,

        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $null
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -Stream Debug -String $Identity

    Try
    {
        $GetParams = @{
            'Identity' = $Identity
        }
        if($Server -as [bool]) { $Null = $GetParams.add('Server',$Server) }
        if($Credential -as [bool]) { $Null = $GetParams.add('Credential',$Credential) }
        
        $ADGroup = Get-ADGroup @GetParams
    }
    Catch 
    {
        $Exception = $_
        $ExceptionInformation = Get-ExceptionInfo -Exception $Exception
        Switch($ExceptionInformation.FullyQualifiedErrorId)
        {
            'ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADGroup'
            {
                $ADGroup = $False
            }
            'ActiveDirectoryServer:0,Microsoft.ActiveDirectory.Management.Commands.GetADGroup'
            {
                $ADGroup = $False
            }
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams -Status ($ADGroup -as [bool])
    Return $ADGroup -as [bool]
}


<#
    .Synopsis
        Checks to see if the target AD user exists
#>
Function Test-ADUser
{
    [OutputType([bool])]
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        $Identity,

        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $null,

        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $null
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -Stream Debug -String $Identity

    Try
    {
        $GetParams = @{
            'Identity' = $Identity
        }
        if($Server -as [bool]) { $Null = $GetParams.add('Server',$Server) }
        if($Credential -as [bool]) { $Null = $GetParams.add('Credential',$Credential) }
        
        $ADUser = Get-ADUser @GetParams
    }
    Catch 
    {
        $Exception = $_
        $ExceptionInformation = Get-ExceptionInfo -Exception $Exception
        Switch($ExceptionInformation.FullyQualifiedErrorId)
        {
            'ActiveDirectoryCmdlet:Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException,Microsoft.ActiveDirectory.Management.Commands.GetADUser'
            {
                $ADUser = $False
            }
            'ActiveDirectoryServer:0,Microsoft.ActiveDirectory.Management.Commands.GetUser'
            {
                $ADUser = $False
            }
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams -Status ($ADUser -as [bool])
    Return $ADUser -as [bool]
}

<#
    .Synopsis
        Sets owners of a target AD Group
            Sets managedby to user 1
            Sets all users to GMICustomAttribute2
#>
Function Set-ADGroupOwner
{
    Param(
        [Parameter(
            Mandatory = $True,
            ValueFromPipeline = $True,
            Position = 0
        )]
        [Microsoft.ActiveDirectory.Management.ADGroup]
        $Identity,

        [Parameter(
            Mandatory = $True,
            ValueFromPipeline = $True,
            Position = 1
        )]
        [Microsoft.ActiveDirectory.Management.ADUser[]]
        $User,

        [Parameter(
            Mandatory = $False,
            ValueFromPipeline = $True,
            Position = 2
        )]
        [string]
        $Server = $Null,

        [Parameter(
            Mandatory = $False,
            ValueFromPipeline = $True,
            Position = 3
        )]
        [pscredential]
        $Credential
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $StringBuilder = New-Object -TypeName System.Text.StringBuilder

        For($i = 0 ; $i -lt $User.Count ; $i++)
        {
            Try
            {
                $GetParams = @{
                    'Identity' = $User[$i]
                    'Properties' = 'mail'
                }
                if($Credential -as [bool]) { $Null = $GetParams.add('Credential',$Credential) }
                $ADUser = Get-ADUser @GetParams
                if(($i -eq 0) -or ($Null -eq $ManagedBy))
                {
                    if($ADUser.mail -as [bool])
                    {
                        $Null = $StringBuilder.Append("$($ADUser.Mail)")
                        $ManagedBy = $ADUser
                    }
                    else
                    {
                        $ManagedBy = $Null
                    }
                }
                elseif($ADUser.mail -as [bool] -and $StringBuilder.ToString() -notlike "*$($ADUser.mail)")
                {
                    $Null = $StringBuilder.Append(";$($ADUser.Mail)")
                }
            }
            Catch
            {
                Write-Exception -Exception $_ -Stream Warning
            }
        }

        $SetParams = @{
            'Identity' = $Identity
            'ManagedBy' = $ManagedBy
            'Replace' = @{
                'GMICustomAttribute2' = $StringBuilder.ToString()
            }
        }
        if($Server -as [bool]) { $Null = $SetParams.add('Server',$Server) }
        if($Credential -as [bool]) { $Null = $SetParams.add('Credential',$Credential) }
        Set-ADGroup @SetParams
    }
    Catch 
    {
        $Exception = $_
        $ExceptionInformation = Get-ExceptionInfo -Exception $Exception
        Switch($ExceptionInformation.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams
}

<#
    .Synopsis
        Creates a new AD User account with FTP settings
#>
Function New-ADFTPUser
{
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        $Owner,
        
        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [string]
        $Path,

        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $CompanyName = $Null,

        [Parameter(
            Mandatory = $True,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [securestring]
        $Password,

        [Parameter(
            Mandatory = $False,
            Position = 4,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 5,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $Null
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $ADOptionalParameters = @{}
        if($Credential) { $Null = $ADOptionalParameters.Add('Credential', $Credential) }
        if($Server) { $Null = $ADOptionalParameters.Add('Server', $Server) }
        if(-not (Test-ADUser -Identity $Owner @ADOptionalParameters))
        {
            Throw-Exception -Type 'InvalidOwnerSelected' `
                            -Message 'The owner was not found in AD. Failing' `
                            -Property @{
                                'Owner' = $Owner
                            }
        }
        $Manager = Get-ADUser -Identity $Owner @ADOptionalParameters
        $UserSamAccountName = Select-ADNextADUserSamAccountName -Prefix 'FTP' `
                                                               -Match '^FTP([0-9][0-9][0-9][0-9][0-9][0-9])$' `
                                                               @ADOptionalParameters

         $OtherAttributes = @{
            'GMICustomAttribute2' = $Manager.SamAccountName
            'GMICustomAttribute20' = 'Linked'
         }
         $NewUserParameters = @{
            'Name'                  = $UserSamAccountName 
            'SamAccountName'        = $UserSamAccountName
            'DisplayName'           = "$UserSamAccountName - $CompanyName"
            'GivenName'             = $UserSamAccountName
            'Surname'               = 'Access'
            'Path'                  = $Path
            'AccountPassword'       = $Password
            'Enabled'               = $True
            'CannotChangePassword'  = $True
            'OtherAttributes'       = $OtherAttributes
            'PasswordNeverExpires'  = $True
            'Passthru'              = $True
            'ErrorAction'           = 'Stop'
            'Manager'               = $Manager.DistinguishedName
        }
        
        $NewUserParameters += $ADOptionalParameters
        if($CompanyName) { $Null = $NewUserParameters.Add('Description', "FTP account for $CompanyName") }

        $ADUser = New-ADUser @NewUserParameters
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams -Status ($ADUser | ConvertTo-Json)
    Return $ADUser
}
<#
    .Synopsis
        Returns the next name for an AD user in a sequence defined by
        Match (regex).
    .Example
        Select-ADNextADUserSamAccountName -Prefix 'FTP' `
                                          -Match '^FTP([0-9][0-9][0-9][0-9][0-9][0-9])$
#>
Function Select-ADNextADUserSamAccountName
{
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True
        )]
        [string]
        $Prefix,

        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [string]
        $Match,
        
        [Parameter(
            Mandatory = $False,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $Null
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $ADOptionalParameters = @{}
        if($Credential) { $Null = $ADOptionalParameters.Add('Credential', $Credential) }
        if($Server) { $Null = $ADOptionalParameters.Add('Server', $Server) }

        $SearchFilter = "$Prefix*"
        $ADUser = Get-ADUser -Filter { SamAccountName -like $SearchFilter } @ADOptionalParameters

        $SamAccountName = $ADUser.SamAccountName | ForEach-Object { 
            if($_ -match $Match)
            {
                $Matches[1]
            }
        } | Sort-Object

        if($SamAccountName -as [bool])
        {
            $Number = ($SamAccountName -as [array])[-1]
            $StringFormatBuilder = New-Object -TypeName System.Text.StringBuilder
            for($i = 0 ; $i -lt $Number.Length ; $i++)
            {
                $Null = $StringFormatBuilder.Append('0')
            }
            $NewSamAccountName = "$Prefix$((($Number -as [int]) + 1).ToString($StringFormatBuilder.ToString()))"
        }
        else
        {
            $NewSamAccountNameBuilder = New-Object -TypeName System.Text.StringBuilder
            $Null = $NewSamAccountNameBuilder.Append($Prefix)
            For($i = 0 ; $i -lt 127 ; $i++)
            {
                $Null = $NewSamAccountNameBuilder.Append('0')
                if($NewSamAccountNameBuilder.ToString() -match $Match)
                {
                    $NewSamAccountName = $NewSamAccountNameBuilder.ToString()
                    $NewSamAccountName = "$($NewSamAccountName.Substring(0,$NewSamAccountName.Length-1))1"
                    break
                }
            }
        }
        if(-not ($NewSamAccountName -as [bool]))
        {
            Throw-Exception -Type 'CouldNotDetermineNextAccountName' `
                            -Message 'Based on the input the next ID could not be determined'
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams -Status $NewSamAccountName
    Return $NewSamAccountName -as [string]
}
<#
    .Synopsis
        Creates a new password (securestring) using the Web.Security.Membership class
#>
Function New-ADUserPassword
{
    [OutputType([System.Security.SecureString])]
    Param(
        [Parameter(
            Mandatory = $False,
            ValueFromPipeline = $True,
            Position = 0
        )]
        [int]
        $Length = 15,

        [Parameter(
            Mandatory = $False,
            ValueFromPipeline = $True,
            Position = 1
        )]
        [int]
        $NumberOfNonAlphanumericCharacters = 3,

        [Parameter(
            Mandatory = $False,
            ValueFromPipeline = $True,
            Position = 3
        )]
        [switch]
        $IncludePlainTextPassword
    )
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $Password = [Web.Security.Membership]::GeneratePassword($Length,$NumberOfNonAlphanumericCharacters)
		$SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams -Status $Password
    $ReturnObj = @{ 'SecurePassword' = ($SecurePassword -as [System.Security.SecureString]) }
    if($IncludePlainTextPassword.IsPresent) { $Null = $ReturnObj.Add('PlainTextPassword', $Password) }
    Return $ReturnObj
}

<#
    .Synopsis
        Creates a new AD Group with FTP settings
#>
Function New-ADFTPGroup
{
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        $FTPUserIdentity,

        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        $Owner,
        
        [Parameter(
            Mandatory = $True,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $Path,

        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [string]
        $CompanyName = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 4,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADPrincipal[]]
        $Members = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 5,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 6,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $Null
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage

    Try
    {
        $GetDomainControllerParameters = @{
            'Discover' = $True
        }
        if($Server) { $Null = $GetDomainControllerParameters.Add('DomainName', $Server) }
        $DomainController = Get-ADDomainController @GetDomainControllerParameters

        $ADOptionalParameters = @{
            'Server' = $DomainController.HostName[0]
        }
        if($Credential) { $Null = $ADOptionalParameters.Add('Credential', $Credential) }

        if(-not (Test-ADUser -Identity $Owner @ADOptionalParameters))
        {
            Throw-Exception -Type 'InvalidOwnerSelected' `
                            -Message 'The owner was not found in AD. Failing' `
                            -Property @{
                                'Owner' = $Owner
                            }
        }
        $GroupName = "$($FTPUserIdentity.SamAccountName) Access Group"
        $NewGroupParameters = @{
            'Name'                  = $GroupName
            'Path'                  = $Path
            'Passthru'              = $True
            'ErrorAction'           = 'Stop'
            'GroupScope'            = 'Universal'
            'GroupCategory'         = 'Security'
        }
        $NewGroupParameters += $ADOptionalParameters
        if($CompanyName) { $Null = $NewGroupParameters.Add('Description', "FTP group for $CompanyName") }
        
        $ADGroup = New-ADGroup @NewGroupParameters

        Set-ADGroupOwner -Identity $ADGroup -User $Owner @ADOptionalParameters

        $Members = Select-NewADGroupMember -Member $Members `
                                           -Identity $ADGroup `
                                           @ADOptionalParameters
        if($Members -as [bool])
        {
            $Null = Add-ADGroupMember -Identity $ADGroup `
                                      -Members $Members `
                                      @ADOptionalParameters
        }
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams -Status ($ADGroup | ConvertTo-Json)
    Return $ADGroup
}
<#
    .Synopsis
        Creates a total FTP Setup in AD (AD User and Group)
#>
Function New-ADFTPSetup
{
    Param(
        [Parameter(
            Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADUser]
        $Owner,
        
        [Parameter(
            Mandatory = $True,
            Position = 1,
            ValueFromPipeline = $True
        )]
        [string]
        $FTPUserPath,

        [Parameter(
            Mandatory = $True,
            Position = 2,
            ValueFromPipeline = $True
        )]
        [string]
        $FTPGroupPath,
        
        [Parameter(
            Mandatory = $False,
            Position = 3,
            ValueFromPipeline = $True
        )]
        [string]
        $CompanyName = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 4,
            ValueFromPipeline = $True
        )]
        [int]
        $PasswordLength = 15,

        [Parameter(
            Mandatory = $False,
            Position = 5,
            ValueFromPipeline = $True
        )]
        [int]
        $PasswordNonAlphaNumbericCharacterCount = 3,

        [Parameter(
            Mandatory = $False,
            Position = 6,
            ValueFromPipeline = $True
        )]
        [Microsoft.ActiveDirectory.Management.ADPrincipal[]]
        $Members = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 7,
            ValueFromPipeline = $True
        )]
        [string]
        $Server = $Null,

        [Parameter(
            Mandatory = $False,
            Position = 8,
            ValueFromPipeline = $True
        )]
        [pscredential]
        $Credential = $Null
    )

    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    $CompletedParams = Write-StartingMessage -String "Args [$($Args | ConvertTo-Json ([int]::MaxValue))]"

    Try
    {
        $ADOptionalParameters = @{}
        if($Credential) { $Null = $ADOptionalParameters.Add('Credential', $Credential) }
        if($Server) { $Null = $ADOptionalParameters.Add('Server', $Server) }

        $Password = New-ADUserPassword -Length $PasswordLength `
                                       -NumberOfNonAlphanumericCharacters $PasswordNonAlphaNumbericCharacterCount `
                                       -IncludePlainTextPassword

        $FTPUser = New-ADFTPUser -Owner $Owner `
                                 -Path $FTPUserPath `
                                 -CompanyName $CompanyName `
                                 -Password $Password.SecurePassword `
                                 @ADOptionalParameters

        $FTPGroup = New-ADFTPGroup -FTPUserIdentity $FTPUser `
                                   -Owner $Owner `
                                   -Path $FTPGroupPath `
                                   -CompanyName $CompanyName `
                                   -Members $Members `
                                   @ADOptionalParameters
    }
    Catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch ($ExceptionInfo.FullyQualifiedErrorId)
        {
            Default
            {
                throw
            }
        }
    }

    Write-CompletedMessage @CompletedParams -Status "FTPUser [$($FTPUser | ConvertTo-Json)] FTPGroup [$($FTPGroup | ConvertTo-Json)]"
    $ReturnObj = @{
        'FTPUserPassword' = $Password.PlainTextPassword
        'FTPUser' = $FTPUser
        'FTPGroup' = $FTPGroup
    }
    Return $ReturnObj
}
Export-ModuleMember -Function * -Verbose:$false
