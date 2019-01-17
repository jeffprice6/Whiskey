
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

$powerShellModulesDirectoryName = 'PSModules'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)
. (Join-Path -Path $PSScriptRoot -ChildPath '..\Whiskey\Functions\Resolve-WhiskeyPowerShellModule.ps1' -Resolve)
. (Join-Path -Path $PSScriptRoot -ChildPath '..\Whiskey\Functions\Install-WhiskeyPowerShellModule.ps1' -Resolve)


function Invoke-PowershellInstall
{
    param(
        $ForModule,
        $Version,
        $ActualVersion
    )

    if( -not $ActualVersion )
    {
        $ActualVersion = $Version
    }

    $optionalParams = @{ }
    $Global:Error.Clear()

    try
    {
        Push-Location -Path $TestDrive.FullName
        $result = Install-WhiskeyPowerShellModule -Name $ForModule -Version $Version
    }
    finally
    {
        Pop-Location
    }

    Context 'the module' {
        $moduleRootPath = Join-Path -Path $TestDrive.FullName -ChildPath ('PSModules\{0}' -f $ForModule)
        It 'should exist' {
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Exist
            $result | Should -Be $moduleRootPath
        }

        It 'should be importable and the expected version' {
            $errors = @()
            $module = Start-Job {
                Import-Module -Name $using:result -PassThru
            } | Wait-Job | Receive-Job -ErrorVariable 'errors'
            $errors | Should -BeNullOrEmpty
            $module.Version | Should -Be $ActualVersion
        }
    }
}

Describe 'Install-WhiskeyPowerShellModule.when installing a PowerShell module and it''s already installed' {
    $Global:Error.Clear()

    Invoke-PowershellInstall -ForModule 'Zip' -Version '0.2.0'
    Invoke-PowershellInstall -ForModule 'Zip' -Version '0.2.0'

    it 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'Install-WhiskeyPowerShellModule.when installing a PowerShell module and omitting patch number' {
    Invoke-PowershellInstall -ForModule 'Zip' -Version '0.2' -ActualVersion '0.2.0'
}

Describe 'Install-WhiskeyPowerShellModule.when installing a PowerShell module omitting Version' {
    $module = Resolve-WhiskeyPowerShellModule -Version '' -Name 'Zip'
    Invoke-PowershellInstall -ForModule 'Zip' -Version '' -ActualVersion $module.Version
}

Describe 'Install-WhiskeyPowerShellModule.when installing a PowerShell module using wildcard version' {
    $module = Resolve-WhiskeyPowerShellModule -Version '0.*' -Name 'Zip'
    Invoke-PowershellInstall -ForModule 'Zip' -Version '0.*' -ActualVersion $module.Version
}

Describe 'Install-WhiskeyPowerShellModule.when installing a PowerShell module' {
    Invoke-PowershellInstall -ForModule 'Zip' -Version '0.2.0'
}

Describe 'Install-WhiskeyPowerShellModule.when installing a PowerShell module and the version doesn''t exist' {
    $Global:Error.Clear()

    $result = Install-WhiskeyPowerShellModule -Path $TestDrive.FullName -Name 'Pester' -Version '3.0.0' -ErrorAction SilentlyContinue

    It 'shouldn''t return anything' {
        $result | Should -BeNullOrEmpty
    }

    It 'should write an error' {
        $Global:Error.Count | Should -Be 1
        $Global:Error[0] | Should -Match 'failed to find module'
    }
}

Describe 'Install-WhiskeyPowerShellModule.when installing a PowerShell module and version parameter is empty' {
    $Global:Error.Clear()

    $result = Install-WhiskeyPowerShellModule -Path $TestDrive.FullName -Name 'Fubar' -Version '' -ErrorAction SilentlyContinue

    It 'shouldn''t return anything' {
        $result | Should -BeNullOrEmpty
    }

    It 'should write an error' {
        $Global:Error.Count | Should -Be 1
        $Global:Error[0] | Should -Match 'Failed to find module'
    }
}

Describe 'Install-WhiskeyPowerShellModule.when PowerShell module is already installed' {
    Install-WhiskeyPowerShellModule -Path $TestDrive.FullName -Name 'Pester' -Version '4.0.6'
    $info = Get-ChildItem -Path $TestDrive.FullName -Filter 'Pester.psd1' -Recurse
    $manifest = Test-ModuleManifest -Path $info.FullName
    Start-Sleep -Milliseconds 333
    Install-WhiskeyPowerShellModule -Path $TestDrive.FullName -Name 'Pester' -Version '4.0.7'
    $newInfo = Get-ChildItem -Path $TestDrive.FullName -Filter 'Pester.psd1' -Recurse
    $newManifest = Test-ModuleManifest -Path $newInfo.FullName
    It 'should not redownload module' {
        $newManifest.Version | Should -Be $manifest.Version
    }
}

Describe 'Install-WhiskeyPowerShellModule.when PowerShell module directory exists but is empty' {
    $moduleRootDir = Join-Path -Path $TestDrive.FullName -ChildPath ('{0}\Pester' -f $powerShellModulesDirectoryName)
    New-Item -Path $moduleRootDir -ItemType Directory | Write-Debug

    Invoke-PowershellInstall -ForModule 'Pester' -Version '4.4.0'
}

Describe 'Install-WhiskeyPowerShellModule.when PowerShell module is missing files' {
    Install-WhiskeyPowerShellModule -Path $TestDrive.FullName -Name 'Pester' -Version '4.4.0'
    $moduleManifest = Join-Path -Path $TestDrive.FullName -ChildPath ('{0}\Pester\4.4.0\Pester.psd1' -f $powerShellModulesDirectoryName) -Resolve
    Remove-Item -Path $moduleManifest -Force

    Invoke-PowershellInstall -ForModule 'Pester' -Version '4.4.0'
}

Remove-Item -Path 'function:Install-WhiskeyPowerShellModule'
