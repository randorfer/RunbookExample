Configuration JeaConstrained
{
    Param(
    )

    Import-DscResource -ModuleName xJea
    
    Node Webserver {   
        xJeaToolKit Process
        {
            Name         = 'Process'
            CommandSpecs = @"
Name,Parameter,ValidateSet,ValidatePattern
Get-Process
Get-Service
Stop-Process,Name,calc;notepad
Restart-Service,Name,,^A
"@
        }
        xJeaEndPoint Demo1EP
        {
            Name                   = 'Demo1EP'
            Toolkit                = 'Process'
            SecurityDescriptorSddl = 'O:NSG:BAD:P(A;;GX;;;WD)S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)'                                  
            DependsOn              = '[xJeaToolKit]Process'
        }
    }
}