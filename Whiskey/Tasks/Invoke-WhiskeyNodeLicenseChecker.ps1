
function Invoke-WhiskeyNodeLicenseChecker
{
    <#
    .SYNOPSIS
    Generates a report of each dependency's license.
    
    .DESCRIPTION
    The `NodeLicenseChecker` task runs the node module `license-checker` against all the modules listed in the `dependencies` and `devDepenendencies` properties of the `package.json` file for this application. The task will create a JSON report file named `node-license-checker-report.json` located in the `.output` directory of the build root.

    This task installs the latest LTS version of Node into a `.node` directory (in the same directory as your whiskey.yml file). To use a specific version, set the `engines.node` property in your package.json file to the version you want. (See https://docs.npmjs.com/files/package.json#engines for more information.)

    If the application's `package.json` file does not exist in the build root next to the `whiskey.yml` file, specify a `WorkingDirectory` where it can be found.

    # Properties

    * `Version`: the version of the license checker to use. The default is the latest version.

    # Examples

    ## Example 1

        BuildTasks:
        - NodeLicenseChecker
    
    This example will run `license-checker` against the modules listed in the `package.json` file located in the build root.

    ## Example 2

        BuildTasks:
        - NodeLicenseChecker:
            Version: 13.0.1
    
    This example will install and use version 13.0.1 of the license checker.
    #>
    [CmdletBinding()]
    [Whiskey.Task('NodeLicenseChecker')]
    [Whiskey.RequiresTool('Node', 'NodePath')]
    [Whiskey.RequiresTool('NodeModule::license-checker', 'LicenseCheckerPath', VersionParameterName='Version')]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        $TaskContext,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $TaskParameter
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $licenseCheckerRoot = $TaskParameter['LicenseCheckerPath']
    if( -not $licenseCheckerRoot -or -not (Test-Path -Path $licenseCheckerRoot -PathType Container) )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Whiskey failed to install required Node module license-checker. Something pretty serious has gone wrong.')
    }

    $licenseCheckerPath = Join-Path -Path $licenseCheckerRoot -ChildPath 'bin\license-checker' -Resolve
    if( -not $licenseCheckerPath )
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message ('Node license-checker module is missing a `{0}\bin\license-checker` script. Please use the `Version` property on your NodeLicenseChecker task and specify a version of the license checker that has this script.')
    }

    $nodePath = $TaskParameter['NodePath']

    Write-WhiskeyTiming -Message ('Generating license report')
    $reportJson = Invoke-Command -NoNewScope -ScriptBlock {
        & $nodePath $licenseCheckerPath '--json'
    }
    Write-WhiskeyTiming -Message ('COMPLETE')

    $report = Invoke-Command -NoNewScope -ScriptBlock {
        ($reportJson -join [Environment]::NewLine) | ConvertFrom-Json
    }
    if (-not $report)
    {
        Stop-WhiskeyTask -TaskContext $TaskContext -Message 'License Checker failed to output a valid JSON report.'
    }

    Write-WhiskeyTiming -Message 'Converting license report.'
    # The default license checker report has a crazy format. It is an object with properties for each module.
    # Let's transform it to a more sane format: an array of objects.
    [object[]]$newReport = $report | 
                                Get-Member -MemberType NoteProperty | 
                                Select-Object -ExpandProperty 'Name' | 
                                ForEach-Object { $report.$_ | Add-Member -MemberType NoteProperty -Name 'name' -Value $_ -PassThru }

    # show the report
    $newReport | Sort-Object -Property 'licenses','name' | Format-Table -Property 'licenses','name' -AutoSize | Out-String | Write-Verbose

    $licensePath = 'node-license-checker-report.json'
    $licensePath = Join-Path -Path $TaskContext.OutputDirectory -ChildPath $licensePath
    ConvertTo-Json -InputObject $newReport -Depth 100 | Set-Content -Path $licensePath
    Write-WhiskeyTiming -Message ('COMPLETE')
}
