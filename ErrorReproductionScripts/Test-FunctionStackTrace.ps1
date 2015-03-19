<# 
    This is the expected output for a stack trace
    
    at bar1, <No file>: line 26
    at foo, <No file>: line 12
    at <ScriptBlock>, <No file>: line 43
#>

Function foo
{
    Write-Verbose -Message 'Something'
    Try
    {
        bar1
        bar2
        bar3
    }
    Catch
    {
        $_
    }
}

Function bar1
{
    if((Get-Random -Minimum 0 -Maximum 3) -as [bool])
    {
        throw 'problem happened but where'
    }
}

Function bar2
{
    if((Get-Random -Minimum 0 -Maximum 3) -as [bool])
    {
        throw 'problem happened but where'
    }
}

Function bar3
{
    throw 'problem happened but where'
}

(foo).ScriptStackTrace
