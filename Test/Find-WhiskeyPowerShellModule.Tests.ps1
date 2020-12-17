Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

# If you want to upgrade the PackageManagement and PowerShellGet versions, you must also update:
# * Whiskey\Functions\Find-WhiskeyPowerShellModule.ps1
# * Whiskey\Tasks\PublishPowerShellModule.ps1
# * whiskey.yml
$packageManagementVersion = '1.4.5'
$powerShellGetVersion = '2.2.1'

$moduleName = $null
$moduleVersion = $null
$output = $null
$testRoot = $null

function GivenName
{
    param(
        $Name
    )
    $script:moduleName = $Name
}

function GivenVersion
{
    param(
        $Version
    )
    $script:moduleVersion = $Version
}

function GivenReturnedModuleFromTwoRepositories
{
    $pesterRepo1 = Find-Module -Name 'Pester' | Select-Object -First 1
    $pesterRepo2 = $pesterRepo1.PSObject.Copy()
    $pesterRepo2.Repository = 'Another PowerShellGet Repository'

    $moduleOutput = @($pesterRepo1, $pesterRepo2)

    Mock -CommandName 'Find-Module' -ModuleName 'Whiskey' -MockWith { $moduleOutput }.GetNewClosure()
}

function GivenModuleDoesNotExist
{
    $script:moduleName = 'nonexistentmodule'
    Mock -CommandName 'Find-Module' -ModuleName 'Whiskey'
}

function GivenPkgMgmtModulesInstalled
{
    Initialize-WhiskeyTestPSModule -BuildRoot $testRoot
    Resolve-Path -Path (Join-Path -Path $testRoot -ChildPath "$($TestPSModulesDirectoryName)\*\*") |
        Join-Path -ChildPath 'notinstalled' |
        ForEach-Object { New-Item -Path $_ -ItemType 'File' }
}

function GivenPkgMgmtModulesNotInstalled
{
    $psmodulesPath = Join-Path -Path $testRoot -ChildPath 'PSModules'
    if( (Test-Path -Path $psmodulesPath) )
    {
        Remove-Item -Path $psmodulesPath -Recurse -Force
    }
}

function Init
{
    $Global:Error.Clear()
    $script:moduleName = $null
    $script:moduleVersion = $null
    $script:output = $null
    $script:testRoot = New-WhiskeyTestRoot
}

function Reset
{
    Reset-WhiskeyTestPSModule
    Invoke-WhiskeyPrivateCommand -Name 'Unregister-WhiskeyPSModulePath' -Parameter @{ 'PSModulesRoot' = $testRoot }
    $paths = $env:PSModulePath -split ';' | Where-Object { $_ -notlike '*\*.*\PSModules' }
    $env:PSModulePath = $paths -join ';'
}

function ThenPkgManagementModules
{
    [CmdletBinding(DefaultParameterSetName='ImportedAndOrInstalled')]
    param(
        [Parameter(Position=0)]
        [String]$Named,

        [Parameter(Mandatory,ParameterSetName='NotInstalled')]
        [Parameter(Mandatory,ParameterSetName='NotImported')]
        [switch]$Not,

        [Parameter(Mandatory,ParameterSetName='NotImported')]
        [Parameter(ParameterSetName='ImportedAndOrInstalled')]
        [switch]$Imported,

        [Parameter(Mandatory,ParameterSetName='NotInstalled')]
        [Parameter(ParameterSetName='ImportedAndOrInstalled')]
        [switch]$Installed
    )

    if( $Imported )
    {
        $times = 1
        if( $Not )
        {
            $times = 0
        }

        $modulesRoot = $script:testRoot

        if( -not $Named -or $Named -eq 'PackageManagement' )
        {
            $pkgMgmtVersion = $script:packageManagementVersion
            Assert-MockCalled -CommandName 'Import-WhiskeyPowerShellModule' `
                            -ModuleName 'Whiskey' `
                            -Times $times `
                            -Exactly `
                            -ParameterFilter { 
                                    $Name -eq 'PackageManagement' -and `
                                    $PSModulesRoot -eq $modulesRoot -and `
                                    $Version -eq $pkgMgmtVersion 
                                }
        }

        if( -not $Named -or $Named -eq 'PowerShellGet' )
        {
            $psGetVersion = $script:powerShellGetVersion
            Assert-MockCalled -CommandName 'Import-WhiskeyPowerShellModule' `
                            -ModuleName 'Whiskey' `
                            -Times $times `
                            -Exactly `
                            -ParameterFilter { 
                                    $Name -eq 'PowerShellGet' -and `
                                    $PSModulesRoot -eq $modulesRoot -and `
                                    $Version -eq $psGetVersion 
                            }
        }
    }

    if( $Installed )
    {
        if( -not $Named -or $Named -eq 'PackageManagement' )
        {
            Join-Path -Path $testRoot -ChildPath "PSModules\PackageManagement\$($packageManagementVersion)\notinstalled" |
                Should -Not:(-not $Not) -Exist
        }

        if( -not $Named -or $Named -eq 'PowerShellGet' )
        {
            Join-Path -Path $testRoot -ChildPath "PSModules\PowerShellGet\$($powerShellGetVersion)\notinstalled" |
                Should -Not:(-not $Not) -Exist
        }
    }
}

function ThenReturnedModule
{
    param(
        [Parameter(Mandatory)]
        [String]$Name,
        [String]$AtVersion
    )

    $output | Should -Not -BeNullOrEmpty
    $output | Should -HaveCount 1

    $output.Name | Should -Be $Name

    if( $AtVersion )
    {
        $output.Version.ToString() | Should -BeLike $AtVersion
    }

    $output | Get-Member -Name 'Version' | Should -Not -BeNullOrEmpty
    $output | Get-Member -Name 'Repository' | Should -Not -BeNullOrEmpty
}

function ThenReturnedNothing
{
    $output | Should -BeNullOrEmpty
}

function ThenNoErrors
{
    $Global:Error | Should -BeNullOrEmpty
}

function ThenErrorMessage
{
    param(
        $Message
    )

    $Global:Error | Should -Match $Message 
}

function WhenResolvingPowerShellModule
{
    [CmdletBinding()]
    param(
    )

    Mock -CommandName 'Import-WhiskeyPowershellModule' -ModuleName 'Whiskey'

    $parameter = @{
        'Name' = $moduleName;
        'BuildRoot' = $testRoot;
    }

    if( $moduleVersion )
    {
        $parameter['Version'] = $moduleVersion
    }

    $script:output = Invoke-WhiskeyPrivateCommand -Name 'Find-WhiskeyPowerShellModule' -Parameter $parameter -ErrorAction $ErrorActionPreference
}

Describe 'Find-WhiskeyPowerShellModule.when package management modules are not installed' {
    AfterEach { Reset }
    It 'should find it' {
        Init
        GivenName 'Pester'
        GivenPkgMgmtModulesNotInstalled
        WhenResolvingPowerShellModule
        ThenPkgManagementModules -Imported -Installed
        ThenReturnedModule 'Pester'
        ThenNoErrors
    }
}

Describe 'Find-WhiskeyPowerShellModule.when given module Name "Pester" and Version "4.3.1"' {
    AfterEach { Reset }
    It 'should resolve that version' {
        Init
        GivenName 'Pester'
        GivenVersion '4.3.1'
        GivenPkgMgmtModulesInstalled
        WhenResolvingPowerShellModule
        ThenPkgManagementModules -Imported
        ThenPkgManagementModules -Not -Installed
        ThenReturnedModule 'Pester' -AtVersion '4.3.1'
        ThenNoErrors
    }
}

Describe 'Find-WhiskeyPowerShellModule.when given Version wildcard' {
    AfterEach { Reset }
    It 'should resolve the latest version that matches the wildcard' {
        Init
        GivenName 'Pester'
        GivenVersion '4.3.*'
        GivenPkgMgmtModulesInstalled
        WhenResolvingPowerShellModule
        ThenPkgManagementModules -Imported
        ThenPkgManagementModules -Not -Installed
        ThenReturnedModule 'Pester' -AtVersion '4.3.1'
        ThenNoErrors
    }
}

Describe 'Find-WhiskeyPowerShellModule.when given module that does not exist' {
    AfterEach { Reset }
    It 'should fail' {
        Init
        GivenModuleDoesNotExist
        GivenPkgMgmtModulesInstalled
        WhenResolvingPowerShellModule -ErrorAction SilentlyContinue
        ThenPkgManagementModules -Imported
        ThenPkgManagementModules -Not -Installed
        ThenErrorMessage 'Failed to find'
        ThenReturnedNothing
    }
}

Describe 'Find-WhiskeyPowerShellModule.when Find-Module returns module from two repositories' {
    AfterEach { Reset }
    It 'should pick one' {
        Init
        GivenName 'Pester'
        GivenPkgMgmtModulesInstalled
        GivenReturnedModuleFromTwoRepositories
        WhenResolvingPowerShellModule
        ThenPkgManagementModules -Imported
        ThenPkgManagementModules -Not -Installed
        ThenReturnedModule 'Pester'
        ThenNoErrors
    }
}

Describe 'Find-WhiskeyPowerShellModule.when package management modules aren''t installed' {
    AfterEach { Reset }
    It 'should install package management modules' {
        Init
        GivenName 'Pester'
        GivenPkgMgmtModulesInstalled
        WhenResolvingPowerShellModule
        Join-Path -Path $testRoot -ChildPath ('{0}\PackageManagement\{1}' -f $TestPSModulesDirectoryName,$packageManagementVersion) | Should -Exist
        Join-Path -Path $testRoot -ChildPath ('{0}\PowerShellGet\{1}' -f $TestPSModulesDirectoryName,$powerShellGetVersion) | Should -Exist
        ThenPkgManagementModules -Not -Installed
        ThenPkgManagementModules -Imported
        ThenNoErrors
    }
}

Describe 'Find-WhiskeyPowerShellModule.when package management modules manifest is missing' {
    AfterEach { Reset }
    It 'should uninstall potentially corrupt modules' {
        Init
        GivenName 'Pester'
        GivenPkgMgmtModulesInstalled
        $childPath = "$($TestPSModulesDirectoryName)\PackageManagement\$($packageManagementVersion)\PackageManagement.psd1"
        $manifestPath = Join-Path -Path $testRoot -ChildPath $childPath
        New-Item -Path $manifestPath -ItemType 'File' -Force
        { Test-ModuleManifest -Path $manifestPath } | Should -Throw
        $Global:Error.Clear()
        WhenResolvingPowerShellModule
        Test-ModuleManifest -Path $manifestPath | Should -Not -BeNullOrEmpty
        ThenPkgManagementModules 'PackageManagement' -Installed
        ThenPkgManagementModules 'PowerShellGet' -Not -Installed
        ThenPkgManagementModules -Imported
        ThenNoErrors
    }
}

Describe 'Find-WhiskeyPowerShellModule.when package management modules manifests can''t be loaded' {
    AfterEach { Reset }
    It 'should uninstall potentially corrupt modules' {
        Init
        GivenName 'Pester'
        GivenPkgMgmtModulesInstalled
        $childPath = "$($TestPSModulesDirectoryName)\PowerShellGet\$($powershellGetVersion)\PowerShellGet.psd1"
        $manifestPath = Join-Path -Path $testRoot -ChildPath $childPath
        New-Item -Path $manifestPath -ItemType 'File' -Force
        '@{ "RequiredAssemblies" = "Fubar.dll" }' | Set-Content -Path $manifestPath
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Ignore } | Should -Throw
        $Global:Error.Clear()
        WhenResolvingPowerShellModule
        Test-ModuleManifest -Path $manifestPath | Should -Not -BeNullOrEmpty
        ThenPkgManagementModules 'PackageManagement' -Not -Installed
        ThenPkgManagementModules 'PowerShellGet' -Installed
        ThenPkgManagementModules -Imported
        ThenNoErrors
    }
}
