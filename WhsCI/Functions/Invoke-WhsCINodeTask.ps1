
function Invoke-WhsCINodeTask
{
    <#
    .SYNOPSIS
    Runs a Node build.
    
    .DESCRIPTION
    The `Invoke-WhsCINodeTask` function runs Node builds. It uses NPM's `run` command to run a list of NPM scripts. These scripts are defined in your package.json file's `Scripts` property. If any script fails, the build will fail. This function checks if a script fails by looking at the exit code to `npm`. Any non-zero exit code is treated as a failure.

    You are required to specify what version of Node.js you want in the engines field of your package.json file. (See https://docs.npmjs.com/files/package.json#engines for more information.) The version of Node is installed for you using NVM. 

    This task accepts these parameters:

    * `NpmScripts`: a list of one or more NPM scripts to run, e.g. `npm run SCRIPT_NAME`. Each script is run indepently.
    * `WorkingDirectory`: the directory where all the build commands should be run. Defaults to the directory where the build's `whsbuild.yml` file was found. Must be relative to the `whsbuild.yml` file.

    Here's a sample `whsbuild.yml` using the Node task:

        BuildTasks:
        - Node:
          NpmScripts:
          - build
          - test

    This task also does the following as part of each Node.js build:

    * Runs `npm install` to install your dependencies.
    * Runs NSP, the Node Security Platform, to check for any vulnerabilities in your depedencies.
    * Saves a report on each dependency's license.
    * Prunes developer dependencies (if running under a build server).

    .EXAMPLE
    Invoke-WhsCINodeTask -TaskContext $context -TaskParameter @{ NpmScripts = 'build','test' }

    Demonstrates how to run the `build` and `test` NPM targets in the directory specified by the `$context.BuildRoot` property. The function would run `npm run build test`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]
        # The context the task is running under.
        $TaskContext,

        [Parameter(Mandatory=$true)]
        [hashtable]
        # The task parameters, which are:
        #
        # * `NpmScripts`: a list of one or more NPM scripts to run, e.g. `npm run $SCRIPT_NAME`. Each script is run indepently.
        # * `WorkingDirectory`: the directory where all the build commands should be run. Defaults to the directory where the build's `whsbuild.yml` file was found. Must be relative to the `whsbuild.yml` file.
        $TaskParameter
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $npmScripts = $TaskParameter['NpmScripts']
    $npmScriptCount = $npmScripts | Measure-Object | Select-Object -ExpandProperty 'Count'
    $numSteps = 5 + $npmScriptCount
    $stepNum = 0

    $originalPath = $env:PATH
    $activity = 'Running Node Task'

    function Update-Progress
    {
        param(
            [Parameter(Mandatory=$true)]
            [string]
            $Status,

            [int]
            $Step
        )

        Write-Progress -Activity $activity -Status $Status.TrimEnd('.') -PercentComplete ($Step/$numSteps*100)
    }

    $workingDir = $TaskContext.BuildRoot
    if( $TaskParameter.ContainsKey('WorkingDirectory') )
    {
        $workingDir = $TaskParameter['WorkingDirectory'] | Resolve-WhsCITaskPath -TaskContext $TaskContext -PropertyName 'WorkingDirectory'
    }

    Push-Location -Path $workingDir
    try
    {
        Update-Progress -Status 'Validating package.json' -Step ($stepNum++)

        $packageJsonPath = Resolve-Path -Path 'package.json' | Select-Object -ExpandProperty 'ProviderPath'
        if( -not $packageJsonPath )
        {
            throw ('Package.json file ''{0}'' does not exist. This file is mandatory when using the Node build task.' -f (Join-Path -Path (Get-Location).ProviderPath -ChildPath 'package.json'))
        }

        $packageJson = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
        if( -not $packageJson )
        {
            throw ('Package.json file ''{0}'' contains invalid JSON. Please see previous errors for more information.' -f $packageJsonPath)
        }

        if( -not ($packageJson | Get-Member -Name 'name') -or -not $packageJson.name )
        {
            throw ('Package name is missing or doesn''t have a value. Please ensure ''{0}'' contains a ''name'' field., e.g. `"name": "fubarsnafu"`. A package name is required by NSP, the Node Security Platform, when scanning for security vulnerabilities.' -f $packageJsonPath)
        }

        if( -not ($packageJson | Get-Member -Name 'engines') -or -not ($packageJson.engines | Get-Member -Name 'node') )
        {
            throw ('Node version is not defined or is missing from the package.json file ''{0}''. Please ensure the Node version to use is defined using the package.json''s engines field, e.g. `"engines": {{ node: "VERSION" }}`. See https://docs.npmjs.com/files/package.json#engines for more information.' -f $packageJsonPath)
            return
        }

        if( $packageJson.engines.node -notmatch '(\d+\.\d+\.\d+)' )
        {
            throw ('Node version ''{0}'' is invalid. The Node version must be a valid semantic version. Package.json file ''{1}'', engines field:{2}{3}' -f $packageJson.engines.node,$packageJsonPath,[Environment]::NewLine,($packageJson.engines | ConvertTo-Json -Depth 50))
        }

        $version = $Matches[1]
        Update-Progress -Status ('Installing Node.js {0}' -f $version) -Step ($stepNum++)
        $nodePath = Install-WhsCINodeJs -RegistryUri $TaskContext.NpmRegistryUri -Version $version
        if( -not $nodePath )
        {
            throw ('Node version ''{0}'' failed to install. Please see previous errors for details.' -f $version)
        }

        $nodeRoot = $nodePath | Split-Path
        $npmPath = Join-Path -Path $nodeRoot -ChildPath 'node_modules\npm\bin\npm-cli.js' -Resolve
        if( -not $npmPath )
        {
            throw ('NPM didn''t get installed by NVM when installing Node {0}. Please use NVM to uninstall this version of Node.' -f $version)
        }

        Set-Item -Path 'env:PATH' -Value ('{0};{1}' -f $nodeRoot,$env:Path)

        $installNoColorArg = @()
        $pruneNoColorArg = @()
        $runNoColorArgs = @()
        if( (Test-WhsCIRunByBuildServer) -or $Host.Name -ne 'ConsoleHost' )
        {
            $pruneNoColorArg = $installNoColorArg = '--no-color'
            $runNoColorArgs = @( '--', '--no-color' )
        }

        Update-Progress -Status ('npm install') -Step ($stepNum++)
        & $nodePath $npmPath 'install' '--production=false' $installNoColorArg
        if( $LASTEXITCODE )
        {
            throw ('NPM command `npm install` failed with exit code {0}.' -f $LASTEXITCODE)
        }

        if( -not $npmScripts )
        {
            Write-WhsCIWarning -TaskContext $TaskContext -Message (@'
Element 'NpmScripts' is missing or empty. Your build isn''t *doing* anything. The 'NpmScripts' element should be a list of one or more npm scripts to run during your build, e.g.

BuildTasks:
- Node:
  NpmScripts:
  - build
  - test           
'@)
        }

        foreach( $script in $npmScripts )
        {
            Update-Progress -Status ('npm run {0}' -f $script) -Step ($stepNum++)
            & $nodePath $npmPath 'run' $script $runNoColorArgs
            if( $LASTEXITCODE )
            {
                throw ('NPM command `npm run {0}` failed with exit code {1}.' -f $script,$LASTEXITCODE)
            }
        }

        Update-Progress -Status ('nsp check') -Step ($stepNum++)
        $nodeModulesRoot = Join-Path -Path $nodeRoot -ChildPath 'node_modules'
        $nspPath = Join-Path -Path $nodeModulesRoot -ChildPath 'nsp\bin\nsp'
        $npmCmd = 'install'
        if( (Test-Path -Path $nspPath -PathType Leaf) )
        {
            $npmCmd = 'update'
        }
        & $nodePath $npmPath $npmCmd 'nsp@latest' '-g'
        if( -not (Test-Path -Path $nspPath -PathType Leaf) )
        {
            throw ('NSP module failed to install to ''{0}''.' -f $nodeModulesRoot)
        }

        $output = & $nodePath $nspPath 'check' '--output' 'json' 2>&1 |
                        ForEach-Object { if( $_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } } 
        $results = ($output -join [Environment]::NewLine) | ConvertFrom-Json
        if( $LASTEXITCODE )
        {
            $summary = $results | Format-List | Out-String
            throw ('NSP, the Node Security Platform, found the following security vulnerabilities in your dependencies (exit code: {0}):{1}{2}' -f $LASTEXITCODE,[Environment]::NewLine,$summary)
        }

        Update-Progress -Status ('license-checker') -Step ($stepNum++)
        $licenseCheckerPath = Join-Path -Path $nodeModulesRoot -ChildPath 'license-checker\bin\license-checker'
        $npmCmd = 'install'
        if( (Test-Path -Path $licenseCheckerPath -PathType Leaf) )
        {
            $npmCmd = 'update'
        }
        & $nodePath $npmPath $npmCmd 'license-checker@latest' '-g'
        if( -not (Test-Path -Path $licenseCheckerPath -PathType Leaf) )
        {
            throw ('License Checker module failed to install to ''{0}''.' -f $nodeModulesRoot)
        }

        $reportJson = & $nodePath $licenseCheckerPath '--json'
        $report = ($reportJson -join [Environment]::NewLine) | ConvertFrom-Json
        if( -not $report )
        {
            throw ('License Checker failed to output a valid JSON report.')
        }

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
        ConvertTo-Json -InputObject $newReport -Depth ([int32]::MaxValue) | Set-Content -Path $licensePath

        $productionArg = ''
        $productionArgDisplay = ''
        if( (Test-WhsCIRunByBuildServer) )
        {
            $productionArg = '--production'
            $productionArgDisplay = ' --production'
        }

        Update-Progress -Status ('npm prune{0}' -f $productionArgDisplay) -Step ($stepNum++)
        & $nodePath $npmPath 'prune' $productionArg $pruneNoColorArg
        if( $LASTEXITCODE )
        {
            throw ('NPM command `npm prune{0}` failed, returning exist code {1}.' -f $productionArgDisplay,$LASTEXITCODE)
        }
    }
    finally
    {
        Set-Item -Path 'env:PATH' -Value $originalPath

        Pop-Location

        Write-Progress -Activity $activity -Completed -PercentComplete 100
    }
}