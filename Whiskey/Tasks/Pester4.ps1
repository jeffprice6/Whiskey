
function Invoke-WhiskeyPester4Task
{
    [Whiskey.Task('Pester4')]
    [Whiskey.RequiresPowerShellModule('Pester',ModuleInfoParameterName='PesterModuleInfo',Version='4.*',VersionParameterName='Version',SkipImport)]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Whiskey.Context]$TaskContext,

        [Parameter(Mandatory)]
        [hashtable]$TaskParameter
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( -not ($TaskParameter.ContainsKey('Path')))
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Property "Path" is mandatory. It should be one or more paths, which should be a list of Pester test scripts (e.g. Invoke-WhiskeyPester4Task.Tests.ps1) or directories that contain Pester test scripts, e.g.

        Build:
        - Pester4:
            Path:
            - My.Tests.ps1
            - Tests')
        return
    }

    $path = $TaskParameter['Path'] | Resolve-WhiskeyTaskPath -TaskContext $TaskContext -PropertyName 'Path'

    if( $TaskParameter['Exclude'] )
    {
        $path = $path |
                    Where-Object {
                        foreach( $exclusion in $TaskParameter['Exclude'] )
                        {
                            if( $_ -like $exclusion )
                            {
                                Write-WhiskeyVerbose -Context $TaskContext -Message ('EXCLUDE  {0} -like    {1}' -f $_,$exclusion)
                                return $false
                            }
                            else
                            {
                                Write-WhiskeyVerbose -Context $TaskContext -Message ('         {0} -notlike {1}' -f $_,$exclusion)
                            }
                        }
                        return $true
                    }
        if( -not $path )
        {
            Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Found no tests to run. Property "Exclude" matched all paths in the "Path" property. Please update your exclusion rules to include at least one test. View verbose output to see what exclusion filters excluded what test files.')
            return
        }
    }

    [int]$describeDurationCount = 0
    $describeDurationCount = $TaskParameter['DescribeDurationReportCount']
    [int]$itDurationCount = 0
    $itDurationCount = $TaskParameter['ItDurationReportCount']

    $outputFile = Join-Path -Path $TaskContext.OutputDirectory -ChildPath ('pester+{0}.xml' -f [IO.Path]::GetRandomFileName())

    $moduleInfo = $TaskParameter['PesterModuleInfo']
    $pesterManifestPath = $moduleInfo.Path
    Write-WhiskeyVerbose -Context $TaskContext -Message $pesterManifestPath
    Write-WhiskeyVerbose -Context $TaskContext -Message ('  Script      {0}' -f ($Path | Select-Object -First 1))
    $Path | Select-Object -Skip 1 | ForEach-Object { Write-WhiskeyVerbose -Context $TaskContext -Message ('              {0}' -f $_) }
    Write-WhiskeyVerbose -Message ('  OutputFile  {0}' -f $outputFile)
    # We do this in the background so we can test this with Pester.
    $job = Start-Job -ScriptBlock {
        $VerbosePreference = $using:VerbosePreference
        $DebugPreference = $using:DebugPreference
        $ProgressPreference = $using:ProgressPreference
        $WarningPreference = $using:WarningPreference
        $ErrorActionPreference = $using:ErrorActionPreference

        $script = $using:Path
        $pesterManifestPath = $using:pesterManifestPath
        $outputFile = $using:outputFile
        [int]$describeCount = $using:describeDurationCount
        [int]$itCount = $using:itDurationCount

        Invoke-Command -ScriptBlock {
                                        $VerbosePreference = 'SilentlyContinue'
                                        Import-Module -Name $pesterManifestPath
                                    }

        $result = Invoke-Pester -Script $script -OutputFile $outputFile -OutputFormat NUnitXml -PassThru

        $result.TestResult |
            Group-Object 'Describe' |
            ForEach-Object {
                $totalTime = [TimeSpan]::Zero
                $_.Group | ForEach-Object { $totalTime += $_.Time }
                [pscustomobject]@{
                                    Describe = $_.Name;
                                    Duration = $totalTime
                                }
            } | Sort-Object -Property 'Duration' -Descending |
            Select-Object -First $describeCount |
            Format-Table -AutoSize

        $result.TestResult |
            Sort-Object -Property 'Time' -Descending |
            Select-Object -First $itCount |
            Format-Table -AutoSize -Property 'Describe','Name','Time'
    }


    do
    {
        # There's a bug where Write-Host output gets duplicated by Receive-Job if $InformationPreference is set to "Continue".
        # Since Pester uses Write-Host, this is a workaround to avoid seeing duplicate Pester output.
        $job | Receive-Job -InformationAction SilentlyContinue
    }
    while( -not ($job | Wait-Job -Timeout 1) )

    $job | Receive-Job -InformationAction SilentlyContinue

    Publish-WhiskeyPesterTestResult -Path $outputFile

    $result = [xml](Get-Content -Path $outputFile -Raw)

    if( -not $result )
    {
        throw ('Unable to parse Pester output XML report ''{0}''.' -f $outputFile)
    }

    if( $result.'test-results'.errors -ne '0' -or $result.'test-results'.failures -ne '0' )
    {
        throw ('Pester tests failed.')
    }
}
