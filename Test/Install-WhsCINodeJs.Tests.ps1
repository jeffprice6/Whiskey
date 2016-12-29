
& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhsCITest.ps1' -Resolve)

$nvmHome = $env:NVM_HOME
$restoreNvmHome = $false
if( (Test-Path -Path 'env:NVM_HOME') )
{
    $restoreNvmHome = $true
    Remove-Item -Path 'env:NVM_HOME'
}

function Assert-ThatInstallNodeJs
{
    [CmdletBinding()]
    param(
        [string]
        $InstallsVersion,

        [Switch]
        $OnBuildServer,

        [Switch]
        $OnDeveloperComputer,

        [Switch]
        $WhenUsingDefaultInstallDirectory,

        [Switch]
        $PreserveInstall
    )

    $Global:Error.Clear()

    if( $OnDeveloperComputer )
    {
        Mock -CommandName 'Test-WhsCIRunByBuildServer' -ModuleName 'WhsCI' -MockWith { return $false }
    }
    else
    {
        Mock -CommandName 'Test-WhsCIRunByBuildServer' -ModuleName 'WhsCI' -MockWith { return $true }
    }

    $installDir = Join-Path -Path $env:TEMP -ChildPath 'z'
    $installDirParam = @{ NvmInstallDirectory = $installDir }
    if( $WhenUsingDefaultInstallDirectory )
    {
        Mock -CommandName 'Join-Path' -ModuleName 'WhsCI' -ParameterFilter { $Path -eq $env:APPDATA -and $ChildPath -eq 'nvm'  } -MockWith { Join-Path -Path $installDir -ChildPath 'nvm' }.GetNewClosure()
        $installDirParam = @{ }
    }

    try
    {
        $nodePath = Install-WhsCINodeJs -Version $InstallsVersion @installDirParam

        $nvmRoot = Join-Path -Path $installDir -ChildPath 'nvm'
        $nodeRoot = Join-Path -Path $nvmRoot -ChildPath ('v{0}' -f $InstallsVersion)
        $expectedNodePath = Join-Path -Path $nodeRoot -ChildPath 'node.exe'
        $expectdNpmPath = Join-Path -Path $nodeRoot -ChildPath 'node_modules\npm\bin\npm-cli.js'

        if( $OnBuildServer )
        {
            $npmCliJsPath = Join-Path -Path $nodeRoot -ChildPath 'node_modules\npm\bin\npm-cli.js' -Resolve
            $expectedLatest = & $nodePath $npmCliJsPath 'view' 'npm@3' 'version' |
                                    Where-Object { $_ -match '@(\d+\.\d+\.\d+)' } |
                                    ForEach-Object { [version]$Matches[1] } |
                                    Sort-Object -Descending | 
                                    Select-Object -First 1
            It 'should upgrade to NPM 3' {
                [version]$version = & $nodePath $npmCliJsPath '--version'
                $version | Should Be $expectedLatest
            }
        }

        if( $OnDeveloperComputer )
        {
            It 'should write an error' {
                $Global:Error | Should Match 'is not installed'
            }

            It 'should not install Node.js' {
                $expectedNodePath | Should Not Exist
                $expectdNpmPath | Should Not Exist
            }

            It 'should not return anything' {
                $nodePath | Should BeNullOrEmpty
            }
        }
        else
        {
            It 'should write no errors' {
                $Global:Error | Should BeNullOrEmpty
            }

            It ('should install Node.js {0}' -f $InstallsVersion) {
                 $expectedNodePath | Should Exist
            }

            It 'should return path to node' {
                $nodePath | Should Be $expectedNodePath
            }

            It ('should install NPM for Node.js {0}' -f $InstallsVersion) {
                $expectdNpmPath | Should Exist
            }
        }

        if( $WhenUsingDefaultInstallDirectory )
        {
            It ('should install to {0}' -f $env:APPDATA) {
                Assert-MockCalled -CommandName 'Join-Path' -ModuleName 'WhsCI' -Times 1 -ParameterFilter { $Path -eq $env:APPDATA }
            }
        }
    }
    finally
    {
        if( -not $PreserveInstall )
        {
            $emptyDir = Join-Path -Path $env:TEMP -ChildPath ([IO.Path]::GetRandomFileName())
            New-Item -Path $emptyDir -ItemType 'Directory'
            robocopy $emptyDir $installDir /MIR | Write-Verbose
            while( (Test-Path -Path $installDir) )
            {
                Start-Sleep -Milliseconds 100
                Write-Verbose ('Removing {0}' -f $installDir) 
                Remove-Item -Path $installDir -Recurse -Force
            }
        }

        if( (Test-Path -Path 'env:NVM_HOME') )
        {
            Remove-Item -Path 'env:NVM_HOME'
        }
    }
}

Describe 'Install-WhsCINodeJs.when run by build server and NVM isn''t installed' {
  Assert-ThatInstallNodeJs -InstallsVersion '4.4.7' -OnBuildServer -PreserveInstall
  Context 'now its installed' {
    Assert-ThatInstallNodeJs -InstallsVersion '4.4.7' -OnBuildServer
  }
}

Describe 'Install-WhsCINodeJs.when run on developer computer and NVM isn''t installed' {
  Assert-ThatInstallNodeJs -InstallsVersion '4.4.7' -OnDeveloperComputer -ErrorAction SilentlyContinue
}

Describe 'Install-WhsCiNodejs.when using default installation directory' {
    Assert-ThatInstallNodeJs -InstallsVersion '4.4.7' -OnBuildServer -WhenUsingDefaultInstallDirectory
}

if( $restoreNvmHome )
{
    Set-Item -Path 'env:NVM_HOME' -Value $nvmHome
}
