
function Invoke-WhiskeyDotNetPublish
{
    [CmdletBinding()]
    [Whiskey.Task("DotNetPublish")]
    [Whiskey.RequiresTool('DotNet','DotNetPath',VersionParameterName='SdkVersion')]
    param(
        [Parameter(Mandatory=$true)]
        [Whiskey.Context]
        $TaskContext,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $TaskParameter
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $dotnetExe = $TaskParameter['DotNetPath']

    $projectPaths = ''
    if ($TaskParameter['Path'])
    {
        $projectPaths = $TaskParameter['Path'] | Resolve-WhiskeyTaskPath -TaskContext $TaskContext -PropertyName 'Path'
    }

    $verbosity = $TaskParameter['Verbosity']
    if (-not $verbosity -and $TaskContext.ByBuildServer)
    {
        $verbosity = 'detailed'
    }

    $dotnetArgs = & {
        '--configuration={0}' -f (Get-WhiskeyMSBuildConfiguration -Context $TaskContext)
        '-p:Version={0}'      -f $TaskContext.Version.SemVer1.ToString()

        if ($verbosity)
        {
            '--verbosity={0}' -f $verbosity
        }

        if ($TaskParameter['OutputDirectory'])
        {
            '--output={0}' -f $TaskParameter['OutputDirectory']
        }

        if ($TaskParameter['Argument'])
        {
            $TaskParameter['Argument']
        }
    }

    Write-WhiskeyVerbose -Context $TaskContext -Message ('.NET Core SDK {0}' -f (& $dotnetExe --version))

    foreach($project in $projectPaths)
    {
        $fullArgumentList = & {
            'publish'
            $project
            $dotnetArgs
        }

        Write-WhiskeyCommand -Context $TaskContext -Path $dotnetExe -ArgumentList $fullArgumentList

        & $dotnetExe publish $project $dotnetArgs

        if ($LASTEXITCODE -ne 0)
        {
            Stop-WhiskeyTask -TaskContext $TaskContext -Message ('dotnet.exe failed with exit code {0}' -f $LASTEXITCODE)
        }
    }
}
