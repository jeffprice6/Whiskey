
function Invoke-WhiskeyDotNetTest
{
    [CmdletBinding()]
    [Whiskey.Task('DotNetTest',Obsolete,ObsoleteMessage='The "DotNetTest" task is obsolete and will be removed in a future version of Whiskey. Please use the "DotNet" task instead.')]
    [Whiskey.RequiresTool('DotNet',PathParameterName='DotNetPath',VersionParameterName='SdkVersion')]
    param(
        [Parameter(Mandatory)]
        [Whiskey.Context]$TaskContext,

        [Parameter(Mandatory)]
        [hashtable]$TaskParameter
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $dotnetExe = $TaskParameter['DotNetPath']

    $projectPaths = ''
    if ($TaskParameter['Path'])
    {
        $projectPaths = $TaskParameter['Path'] | Resolve-WhiskeyTaskPathInternal -TaskContext $TaskContext -PropertyName 'Path'
    }

    $verbosity = $TaskParameter['Verbosity']
    if (-not $verbosity)
    {
        $verbosity = 'minimal'
    }

    $dotnetArgs = & {
        '--configuration={0}' -f (Get-WhiskeyMSBuildConfiguration -Context $TaskContext)
        '--no-build'
        '--results-directory={0}' -f ($TaskContext.OutputDirectory.FullName)

        if ($Taskparameter['Filter'])
        {
            '--filter={0}' -f $TaskParameter['Filter']
        }

        if ($TaskParameter['Logger'])
        {
            '--logger={0}' -f $TaskParameter['Logger']
        }

        if ($verbosity)
        {
            '--verbosity={0}' -f $verbosity
        }

        if ($TaskParameter['Argument'])
        {
            $TaskParameter['Argument']
        }
    }

    Write-WhiskeyVerbose -Context $TaskContext -Message ('.NET Core SDK {0}' -f (& $dotnetExe --version))

    foreach($project in $projectPaths)
    {
        Invoke-WhiskeyDotNetCommand -TaskContext $TaskContext -DotNetPath $dotnetExe -Name 'test' -ArgumentList $dotnetArgs -ProjectPath $project
    }
}
