
& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

$testRoot = $null

# Private Whiskey function. Define it so Pester doesn't complain about it not existing.
function Remove-WhiskeyFileSystemItem
{
}

function GivenAnInstalledNuGetPackage
{
    [CmdLetBinding()]
    param(
        [String]
        $WithVersion = '2.6.4',

        [String]
        $WithName = 'NUnit.Runners'

    )
    $WithVersion = Resolve-WhiskeyNuGetPackageVersion -NuGetPackageName $WithName -Version $WithVersion
    if( -not $WithVersion )
    {
        return
    }
    $dirName = '{0}.{1}' -f $WithName, $WithVersion
    $installRoot = Join-Path -Path $testRoot -ChildPath 'packages'
    New-Item -Name $dirName -Path $installRoot -ItemType 'Directory' | Out-Null
}

function GivenFile
{
    param(
        $Path
    )

    New-Item -Path (Join-Path -Path $testRoot -ChildPath $Path) -ItemType 'File' -Force
}

function GivenToolInstalled
{
    param(
        $Name
    )

    New-Item -Path (Join-Path -Path $testRoot -ChildPath ('.{0}\{0}.exe' -f $Name)) -ItemType File -Force | Out-Null
}

function Init
{
    $Global:Error.Clear()
    $script:testRoot = New-WhiskeyTestRoot
}

function ThenFile
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

function ThenNoErrors
{
    $Global:Error | Should -BeNullOrEmpty
}

function ThenNuGetPackageUninstalled
{
    [CmdLetBinding()]
    param(
        [String]
        $WithVersion = '2.6.4',

        [String]
        $WithName = 'NUnit.Runners'
    )

    $Name = '{0}.{1}' -f $WithName, $WithVersion
    $path = Join-Path -Path $testRoot -ChildPath 'packages'
    $uninstalledPath = Join-Path -Path $path -ChildPath $Name

    $uninstalledPath | Should -Not -Exist

    $Global:Error | Should -beNullOrEmpty
}

function ThenNuGetPackageNotUninstalled
{
    [CmdLetBinding()]
    param(
        [String]$WithVersion = '2.6.4',

        [String]$WithName = 'NUnit.Runners',

        [switch]$PackageShouldExist,

        [string]$WithError
    )

    $Name = '{0}.{1}' -f $WithName, $WithVersion
    $path = Join-Path -Path $testRoot -ChildPath 'packages'
    $uninstalledPath = Join-Path -Path $path -ChildPath $Name

    if( -not $PackageShouldExist )
    {
        $uninstalledPath | Should -Not -Exist
    }
    else
    {
        $uninstalledPath | Should -Exist
        Remove-Item -Path $uninstalledPath -Recurse -Force
    }

    $Global:Error | Should -Match $WithError
}

function ThenUninstalledDotNet
{
    Join-Path -Path $testRoot -ChildPath '.dotnet' | Should -Not -Exist
}

function ThenUninstalledNode
{
    Join-Path -Path $testRoot -ChildPath '.node' | Should -Not -Exist
}

function WhenUninstallingNuGetPackage
{
    [CmdletBinding()]
    param(
        [String]
        $WithVersion = '2.6.4',

        [String]
        $WithName = 'NUnit.Runners'
    )

    $Global:Error.Clear()
    Uninstall-WhiskeyTool -NuGetPackageName $WithName -Version $WithVersion -BuildRoot $testRoot
}

function WhenUninstallingTool
{
    [CmdletBinding()]
    param(
        [Whiskey.RequiresToolAttribute]$ToolInfo
    )

    Push-Location $testRoot
    try
    {
        Uninstall-WhiskeyTool -ToolInfo $ToolInfo -InstallRoot $testRoot
    }
    finally
    {
        Pop-Location
    }
}

if( $IsWindows )
{
    Describe 'Uninstall-WhiskeyTool.when given a NuGet Package' {
        It 'should delete it' {
            Init
            GivenAnInstalledNuGetPackage
            WhenUninstallingNuGetPackage
            ThenNuGetPackageUnInstalled
        }
    }
    
    Describe 'Uninstall-WhiskeyTool.when given a NuGet Package with an empty version' {
        It 'should delete all versions' {
            Init
            GivenAnInstalledNuGetPackage -WithVersion ''
            WhenUninstallingNuGetPackage -WithVersion ''
            ThenNuGetPackageUnInstalled -WithVersion ''
        }
    }
    
    Describe 'Uninstall-WhiskeyTool.when given a NuGet Package with a wildcard version' {
        It 'should fail' {
            Init
            GivenAnInstalledNuGetPackage -WithVersion '2.*' -ErrorAction SilentlyContinue
            WhenUninstallingNuGetPackage -WithVersion '2.*' -ErrorAction SilentlyContinue
            ThenNuGetPackageNotUnInstalled -WithVersion '2.*' -WithError 'Wildcards are not allowed for NuGet packages'
        }
    }    
}

Describe 'Uninstall-WhiskeyTool.when uninstalling Node and node modules' {
    It 'should uninstall everything' {
        Init
        GivenToolInstalled 'node'
        WhenUninstallingTool (New-Object 'Whiskey.RequiresToolAttribute' 'Node','NodePath')
        WhenUninstallingTool (New-Object 'Whiskey.RequiresToolAttribute' 'NodeModule::rimraf','NodeModulePath')
        ThenUninstalledNode
        ThenNoErrors

        # Also ensure Remove-WhiskeyFileSystemItem is used to delete the tool
        Mock -CommandName 'Remove-WhiskeyFileSystemItem' -ModuleName 'Whiskey'
        GivenToolInstalled 'node'
        WhenUninstallingTool (New-Object 'Whiskey.RequiresToolAttribute' 'Node','NodePath')
        Assert-MockCalled -CommandName 'Remove-WhiskeyFileSystemItem' -ModuleName 'Whiskey'
    }
}

Describe 'Uninstall-WhiskeyTool.when uninstalling DotNet SDK' {
    It 'should remove dotNet SDK' {
        Init
        GivenToolInstalled 'DotNet'
        WhenUninstallingTool (New-Object 'Whiskey.RequiresToolAttribute' 'DotNet','DotNetPath')
        ThenUninstalledDotNet
        ThenNoErrors

        # Also ensure Remove-WhiskeyFileSystemItem is used to delete the tool
        Mock -CommandName 'Remove-WhiskeyFileSystemItem' -ModuleName 'Whiskey'
        GivenToolInstalled 'DotNet'
        WhenUninstallingTool (New-Object 'Whiskey.RequiresToolAttribute' 'DotNet','DotNetPath')
        Assert-MockCalled -CommandName 'Remove-WhiskeyFileSystemItem' -ModuleName 'Whiskey'
    }
}

Describe 'Uninstall-WhiskeyTool.when uninstalling PowerShell module' {
    It 'should delete PowerShell module' {
        Init
        $mockModulePath = '{0}\Whiskey\0.37.1\Whiskey.psd1' -f $PSModulesDirectoryName
        Init
        GivenFile $mockModulePath
        WhenUninstallingTool (New-Object 'Whiskey.RequiresPowerShellModuleAttribute' 'Whiskey','WhiskeyPath')
        ThenFile $mockModulePath -Not -Exists
        ThenNoErrors
    }
}