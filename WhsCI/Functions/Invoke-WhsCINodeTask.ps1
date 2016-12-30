
function Invoke-WhsCINodeTask
{
    <#
    .SYNOPSIS
    Runs a Node build.
    
    .DESCRIPTION
    The `Invoke-WhsCINodeTask` function runs Node builds. It uses NPM's `run` command to run a list of NPM scripts. These scripts are defined in your package.json file's `scripts` properties. If any script fails, the build will fail. This function checks if a script fails by looking at the exit code to `npm`. Any non-zero exit code is treated as a failure.

    You are required to specify what version of Node you want in the engines field of your package.json file. (See https://docs.npmjs.com/files/package.json#engines for more information.) The version of Node is installed for you using NVM. 

    This task also does the following as part of each Node build:

    * Runs `npm install` to install your dependencies.
    * Runs NSP, the Node Security Platform, to check for any vulnerabilities in your depedencies.
    * Checks dependencies for prohibite licenses.

    .EXAMPLE
    Invoke-WhsCINodeTask -WorkingDirectory 'C:\Projects\ui-cm' -NpmScript 'build','test'

    Demonstrates how to run the `build` and `test` NPM targets in the `C:\Projects\ui-cm` directory. The function would run `npm run build test`.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The path to the directory where the Node build should run.
        $WorkingDirectory,

        [Parameter(Mandatory=$true)]
        [string[]]
        # The NPM commands to run as part of the build.
        $NpmScript,

        [Parameter(Mandatory=$true)]
        # The path where the license report should be saved. This directory will be created if it doesn't exist.
        [string]
        $LicenseReportDirectory
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    $originalPath = $env:PATH

    Push-Location -Path $WorkingDirectory
    try
    {
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
        $nodePath = Install-WhsCINodeJs -Version $version
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
        $runNoColorArgs = @()
        if( (Test-WhsCIRunByBuildServer) -or $Host.Name -ne 'ConsoleHost' )
        {
            $installNoColorArg = '--no-color'
            $runNoColorArgs = @( '--', '--no-color' )
        }

        & $nodePath $npmPath 'install' '--production=false' $installNoColorArg
        if( $LASTEXITCODE )
        {
            throw ('Node command `npm install` failed with exit code {0}.' -f $LASTEXITCODE)
        }

        foreach( $script in $npmScript )
        {
            & $nodePath $npmPath 'run' $script $runNoColorArgs
            if( $LASTEXITCODE )
            {
                throw ('Node command `npm run {0}` failed with exit code {1}.' -f $script,$LASTEXITCODE)
            }
        }

        & $nodePath $npmPath 'install' 'nsp@latest' '-g'

        $nodeModulesRoot = Join-Path -Path $nodeRoot -ChildPath 'node_modules'
        $nspPath = Join-Path -Path $nodeModulesRoot -ChildPath 'nsp\bin\nsp' -Resolve
        if( -not $nspPath )
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

        if( (Test-WhsCIRunByBuildServer) )
        {
            & $nodePath $npmPath 'install' 'license-checker@latest' '-g'
            $licenseCheckerPath = Join-Path -Path $nodeModulesRoot -ChildPath 'license-checker\bin\license-checker' -Resolve
            if( -not $licenseCheckerPath )
            {
                throw ('License Checker module failed to install to ''{0}''.' -f $nodeModulesRoot)
            }

            New-Item -Path $LicenseReportDirectory -ItemType 'Directory' -Force -ErrorAction Ignore
            $licensePath = '{0}.licenses.json' -f $packageJson.name
            $licensePath = Join-Path -Path $LicenseReportDirectory -ChildPath $licensePath

            & $nodePath $licenseCheckerPath '--json' | Set-Content -Path $licensePath
        }
    }
    finally
    {
        Set-Item -Path 'env:PATH' -Value $originalPath

        Pop-Location
    }
}
