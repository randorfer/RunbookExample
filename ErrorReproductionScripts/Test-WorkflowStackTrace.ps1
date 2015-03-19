<# 
    Would expect the stack trace to have something useful. 
    See example Test-FunctionStackTrace for how I would expect it to look

    Output
        at System.Activities.Statements.Throw.Execute(CodeActivityContext context)
        at System.Activities.CodeActivity.InternalExecute(ActivityInstance instance, ActivityExecutor executor, BookmarkManager bookmarkManager)
        at System.Activities.Runtime.ActivityExecutor.ExecuteActivityWorkItem.ExecuteBody(ActivityExecutor executor, BookmarkManager bookmarkManager, Location resultLocation)
    
#>

Workflow foo
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

Workflow bar1
{
    if((Get-Random -Minimum 0 -Maximum 3) -as [bool])
    {
        throw 'problem happened but where'
    }
}

Workflow bar2
{
    if((Get-Random -Minimum 0 -Maximum 3) -as [bool])
    {
        throw 'problem happened but where'
    }
}

Workflow bar3
{
    throw 'problem happened but where'
}

(Foo).StackTrace
