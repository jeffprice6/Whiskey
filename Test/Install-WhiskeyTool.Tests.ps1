
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

$testRoot = $null

function Init
{
    $script:threwException = $false
    $script:taskParameter = $null
    $script:versionParameterName = $null

    $script:testRoot = New-WhiskeyTestRoot

    $script:taskWorkingDirectory = $testRoot
}

function Invoke-NuGetInstall
{
    [CmdletBinding()]
    param(
        $Package,
        $Version,

        [Switch]
        $InvalidPackage,

        [string]
        $ExpectedError
    )

    $Global:Error.Clear()

    $result = $null
    try
    {
        $result = Install-WhiskeyTool -DownloadRoot $testRoot -NugetPackageName $Package -Version $Version
    }
    catch
    {
    }

    if( -not $invalidPackage)
    {
        $result | Should -Exist
        $result | Should -BeLike ('{0}\packages\*' -f $testRoot)
    }
    else
    {
        if( $result )
        {
            $result | Should -Not -Exist
        }
        # $Error has nuget.exe's STDERR depending on your console. 
        $Global:Error.Count | Should -BeLessThan 2
        if( $ExpectedError )
        {
            $Global:Error[0] | Should -Match $ExpectedError
        }
    }
}

function Reset
{
    Remove-Node
}

if( $IsWindows )
{
    Describe 'Install-WhiskeyTool.when given a NuGet Package' {
        It 'should install the NuGet package' {
            Init
            Invoke-NuGetInstall -package 'NUnit.Runners' -version '2.6.4'
        }
    }

    Describe 'Install-WhiskeyTool.when NuGet Pack is bad' {
        It 'should fail' {
            Init
            Invoke-NuGetInstall -package 'BadPackage' -version '1.0.1' -invalidPackage -ErrorAction silentlyContinue
        }
    }

    Describe 'Install-WhiskeyTool.when NuGet pack Version is bad' {
        It 'should fail' {
            Init
            Invoke-NugetInstall -package 'Nunit.Runners' -version '0.0.0' -invalidPackage -ErrorAction silentlyContinue
        }
    }

    Describe 'Install-WhiskeyTool.when given a NuGet Package with an empty version string' {
        It 'should install the latest version' {
            Init
            Invoke-NuGetInstall -package 'NUnit.Runners' -version ''
        }
    }

    Describe 'Install-WhiskeyTool.when installing an already installed NuGet package' {
        It 'should do nothing' {
            Init

            $Global:Error.Clear()

            Invoke-NuGetInstall -package 'Nunit.Runners' -version '2.6.4'
            Invoke-NuGetInstall -package 'Nunit.Runners' -version '2.6.4'

            $Global:Error | Where-Object { $_ -notmatch '\bTestRegistry\b' } | Should -BeNullOrEmpty
        }
    }

    Describe 'Install-WhiskeyTool.when install a NuGet package' {
        It 'should enable NuGet package restore' {
            Init
            Mock -CommandName 'Set-Item' -ModuleName 'Whiskey'
            Install-WhiskeyTool -DownloadRoot $testRoot -NugetPackageName 'NUnit.Runners' -version '2.6.4'
            Assert-MockCalled 'Set-Item' -ModuleName 'Whiskey' -parameterFilter {$Path -eq 'env:EnableNuGetPackageRestore'}
            Assert-MockCalled 'Set-Item' -ModuleName 'Whiskey' -parameterFilter {$Value -eq 'true'}
        }
    }
}
else
{
    Describe 'Install-WhiskeyTool.when run on non-Windows OS' {
        It 'should fail' {
            Init
            Invoke-NuGetInstall -Package 'NUnit.Runners' -Version '2.6.4' -InvalidPackage -ExpectedError 'Only\ supported\ on\ Windows'
        }
    }
}

$threwException = $false
$pathParameterName = 'ToolPath'
$versionParameterName = $null
$taskParameter = $null
$taskWorkingDirectory = $null

function GivenVersionParameterName
{
    param(
        $Name
    )

    $script:versionParameterName = $Name
}

function GivenWorkingDirectory
{
    param(
        $Directory
    )

    $script:taskWorkingDirectory = Join-Path -Path $testRoot -ChildPath $Directory
    New-Item -Path $taskWorkingDirectory -ItemType Directory -Force | Out-Null
}

function ThenDotNetPathAddedToTaskParameter
{
    $taskParameter[$pathParameterName] | Should -Match '[\\/]dotnet(\.exe)$'
}

function ThenNodeInstalled
{
    param(
        [string]
        $NodeVersion,

        [string]
        $NpmVersion,

        [Switch]
        $AtLatestVersion
    )

    $nodePath = Resolve-WhiskeyNodePath -BuildRootPath $testRoot
    if( $AtLatestVersion )
    {
        $expectedVersion = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' |
                                ForEach-Object { $_ } |
                                Where-Object { $_.lts } |
                                Select-Object -First 1
        $NodeVersion = $expectedVersion.version
        if( -not $NpmVersion )
        {
            $NpmVersion = $expectedVersion.npm
        }
    }

    Join-Path -Path $testRoot -ChildPath ('.node\node-{0}-*-x64.*' -f $NodeVersion) | Should -Exist

    $nodePath | Should -Exist
    & $nodePath '--version' | Should -Be $NodeVersion
    $npmPath = Resolve-WhiskeyNodeModulePath -Name 'npm' -BuildRootPath $testRoot -Global
    $npmPath = Join-Path -Path $npmPath -ChildPath 'bin\npm-cli.js'
    $npmPath | Should -Exist
    & $nodePath $npmPath '--version' | Should -Be $NpmVersion
    $taskParameter[$pathParameterName] | Should -Be (Resolve-WhiskeyNodePath -BuildRootPath $testRoot)
}

function ThenNodeModuleInstalled
{
    param(
        $Name,
        $AtVersion
    )

    $expectedPath = Resolve-WhiskeyNodeModulePath -Name $Name -BuildRootPath $testRoot -Global
    $expectedPath | Should -Exist
    $taskParameter[$pathParameterName] | Should -Be $expectedPath

    if( $AtVersion )
    {
        Get-Content -Path (Join-Path -Path $expectedPath -ChildPath 'package.json') -Raw | ConvertFrom-Json | Select-Object -ExpandProperty 'version' | Should -Be $AtVersion
    }
}

function ThenNodeModuleNotInstalled
{
    param(
        $Name
    )

    $nodeModulesPath = Resolve-WhiskeyNodeModulePath -Name $Name -BuildRootPath $testRoot -Global -ErrorAction Ignore | Should -BeNullOrEmpty
    $nodeModulesPath = Resolve-WhiskeyNodeModulePath -Name $Name -BuildRootPath $testRoot -ErrorAction Ignore | Should -BeNullOrEmpty
    $taskParameter.ContainsKey($pathParameterName) | Should -Be $false
}

function ThenThrewException
{
    param(
        $Regex
    )

    $threwException | Should -Be $true
    $Global:Error[0] | Should -Match $Regex
}

function WhenInstallingTool
{
    [CmdletBinding()]
    param(
        $Name,
        $Parameter = @{ },
        $Version
    )

    $Global:Error.Clear()

    $toolAttribute = New-Object 'Whiskey.RequiresToolAttribute' $Name,$pathParameterName

    if( $versionParameterName )
    {
        $toolAttribute.VersionParameterName = $versionParameterName
    }

    if( $Version )
    {
        $toolAttribute.Version = $Version
    }

    $script:taskParameter = $Parameter

    Push-Location -path $taskWorkingDirectory
    try
    {
        Install-WhiskeyTool -ToolInfo $toolAttribute -InstallRoot $testRoot -TaskParameter $Parameter
    }
    catch
    {
        $script:threwException = $true
        Write-Error -ErrorRecord $_
    }
    finally
    {
        Pop-Location
    }
}

Describe 'Install-WhiskeyTool.when installing Node and a Node module' {
    AfterEach { Reset }
    It 'should install Node and the node module' {
        Init
        WhenInstallingTool 'Node'
        ThenNodeInstalled -AtLatestVersion
        WhenInstallingTool 'NodeModule::license-checker'
        ThenNodeModuleInstalled 'license-checker'
    }
}

Describe 'Install-WhiskeyTool.when installing Node and version defined by tool author' {
    AfterEach { Reset }
    It 'should install the author''s version' {
        Init
        WhenInstallingTool 'Node' -Version '8.1.*'
        ThenNodeInstalled -NodeVersion 'v8.1.4' -NpmVersion '5.0.3'
    }
}

Describe 'Install-WhiskeyTool.when installing Node module and Node isn''t installed' {
    AfterEach { Reset }
    It 'should fail' {
        Init
        WhenInstallingTool 'NodeModule::license-checker' -ErrorAction SilentlyContinue
        ThenThrewException 'Node\ isn''t\ installed\ in\ your\ repository'
        ThenNodeModuleNotInstalled 'license-checker'
    }
}

Describe 'Install-WhiskeyTool.when installing specific version of a Node module via version parameter' {
    AfterEach { Reset }
    It 'should install that version of Node' {
        Init
        Install-Node -BuildRoot $testRoot
        GivenVersionParameterName 'Fubar'
        WhenInstallingTool 'NodeModule::license-checker' @{ 'Fubar' = '13.1.0' } -Version '16.0.0'
        ThenNodeModuleInstalled 'license-checker' -AtVersion '13.1.0'
    }
}

Describe 'Install-WhiskeyTool.when installing specific version of a Node module via RequiresTool attribute''s Version property' {
    AfterEach { Reset }
    It 'should install the version in the attribute' {
        Init
        Install-Node -BuildRoot $testRoot
        WhenInstallingTool 'NodeModule::nsp' @{ } -Version '2.7.0'
        ThenNodeModuleInstalled 'nsp' -AtVersion '2.7.0'
    }
}

Describe 'Install-WhiskeyTool.when installing .NET Core SDK' {
    It 'should install dotNet Core' {
        Init
        Mock -CommandName 'Install-WhiskeyDotNetTool' -ModuleName 'Whiskey' -MockWith { Join-Path -Path $InstallRoot -ChildPath '.dotnet\dotnet.exe' }
        GivenWorkingDirectory 'app'
        GivenVersionParameterName 'SdkVersion'
        WhenInstallingTool 'DotNet' @{ 'SdkVersion' = '2.1.4' }
        ThenDotNetPathAddedToTaskParameter
        Assert-MockCalled -CommandName 'Install-WhiskeyDotNetTool' -ModuleName 'Whiskey' -Times 1 -ParameterFilter {
            $InstallRoot -eq $testRoot -and `
            $WorkingDirectory -eq $taskWorkingDirectory -and `
            $version -eq '2.1.4'
        }
    }
}

Describe 'Install-WhiskeyTool.when .NET Core SDK fails to install' {
    It 'should fail' {
        Init
        Mock -CommandName 'Install-WhiskeyDotNetTool' -ModuleName 'Whiskey' -MockWith { Write-Error -Message 'Failed to install .NET Core SDK' }
        GivenVersionParameterName 'SdkVersion'
        WhenInstallingTool 'DotNet' @{ 'SdkVersion' = '2.1.4' } -ErrorAction SilentlyContinue
        ThenThrewException 'Failed\ to\ install\ .NET\ Core\ SDK'
    }
}

function ThenDirectory
{
    param(
        $Path,
        [Switch]
        $Not,
        [Switch]
        $Exists
    )

    if( $Not )
    {
        Join-Path -Path $testRoot -ChildPath $Path | Should -Not -Exist
    }
    else
    {
        Join-Path -Path $testRoot -ChildPath $Path | Should -Exist
    }
}

Describe 'Install-WhiskeyTool.when installing a PowerShell module' {
    AfterEach { Reset }
    It 'should install the module' {
        Init
        GivenVersionParameterName 'Version'
        WhenInstallingTool 'PowerShellModule::Zip' -Parameter @{ 'Version' = '0.2.0' }
        ThenDirectory 'PSModules\Zip' -Exists
        $job = Start-Job { Import-Module -Name (Join-Path -Path $using:testRoot -ChildPath 'PSModules\Zip') -PassThru }
        $moduleInfo = $job | Wait-Job | Receive-Job
        $moduleInfo.Version | Should -Be '0.2.0'
    }
}
Describe 'Install-WhiskeyTool.when failing to install a PowerShell module' {
    AfterEach { Reset }
    It 'should fail' {
        Init
        GivenVersionParameterName 'Version'
        WhenInstallingTool 'PowerShellModule::jfklfjsiomklmslkfs' -ErrorAction SilentlyContinue
        ThenDirectory 'PSModules\Whiskey' -Not -Exists
        ThenThrewException -Regex 'Failed\ to\ find'
    }
}