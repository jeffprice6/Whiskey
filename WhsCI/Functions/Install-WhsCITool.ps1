
function Install-WhsCITool
{
    <#
    .SYNOPSIS
    Downloads and installs tools needed by the WhsCI module.

    .DESCRIPTION
    The `Install-WhsCITool` function downloads and installs PowerShell modules needed by functions in the WhsCI module. PowerShell modules are installed to `$env:LOCALAPPDATA\WebMD Health Services\WhsCI\Modules`. A `DirectoryInfo` object for the downloaded tool's directory is returned.
    
    Users of the `WhsCI` API typcially won't need to use this function. It is called by other `WhsCI` function so they ahve the tools they need.

    .EXAMPLE
    Install-WhsCITool -ModuleName 'Pester'

    Demonstrates how to install the most recent version of the `Pester` module.

    .EXAMPLE
    Install-WhsCITool -ModuleName 'Pester' -Version 3

    Demonstrates how to instals the most recent version of a specific major version of a module. In this case, Pester version 3.6.4 would be installed (which is the most recent 3.x version of Pester as of this writing).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ParameterSetName='PowerShell')]
        [string]
        # The name of the NuGet package to download.
        $ModuleName,

        [Parameter(Mandatory=$true,ParameterSetName='PowerShell')]
        [version]
        # The version of the package to download. Must be a three part number, i.e. it must have a MAJOR, MINOR, and BUILD number.
        $Version,

        [string]
        # The root directory where the tools should be downloaded. The default is `$env:LOCALAPPDATA\WebMD Health Services\WhsCI`.
        #
        # PowerShell modules are saved to `$DownloadRoot\Modules`.
        #
        # NuGet packages are saved to `$DownloadRoot\packages`.
        $DownloadRoot
    )

    Set-StrictMode -Version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if( $Version.Build -lt 0 )
    {
        $Version = [version]('{0}.{1}.0' -f $Version.Major,$Version.Minor)
    }

    if( -not $DownloadRoot )
    {
        $DownloadRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'WebMD Health Services\WhsCI'
    }

    $modulesRoot = Join-Path -Path $DownloadRoot -ChildPath 'Modules'
    New-Item -Path $modulesRoot -ItemType 'Directory' -ErrorAction Ignore | Out-Null

    $expectedPath = Join-Path -Path $modulesRoot -ChildPath ('{0}\{1}\*.psd1' -f $ModuleName,$Version)
    if( $PSVersionTable.PSVersion -lt [version]'5.0' )
    {
        $expectedPath = Join-Path -Path $modulesRoot -ChildPath ('{0}.{1}\*.psd1' -f $ModuleName,$Version)
    }

    if( (Test-Path -Path $expectedPath -PathType Leaf) )
    {
        Resolve-Path -Path $expectedPath | Select-Object -ExpandProperty 'ProviderPath'
        return
    }

    Save-Module -Name $ModuleName -RequiredVersion $Version -Path $modulesRoot -ErrorVariable 'errors' -ErrorAction $ErrorActionPreference
 
    $moduleRoot = Join-Path -Path $modulesRoot -ChildPath ('{0}\{1}\{0}.psd1' -f $ModuleName,$Version)
    if( (Test-Path -Path $moduleRoot -PathType Leaf) )
    {
        return $moduleRoot
    }

    # Looks like we're on PowerShell 4
    $moduleRoot = Join-Path -Path $modulesRoot -ChildPath $ModuleName
    if( -not (Test-Path -Path $moduleRoot -PathType Container) )
    {
        Write-Error -Message ('Failed to download {0} {1} from the PowerShell Gallery. Either the {0} module does not exist, or it does but version {1} does not exist. Browse the PowerShell Gallery at https://www.powershellgallery.com/' -f $ModuleName,$Version)
        return
    }

    $moduleRootName = '{0}.{1}' -f $ModuleName,$Version
    Rename-Item -Path $moduleRoot -NewName $moduleRootName
    $moduleRoot = Join-Path -Path $modulesRoot -ChildPath $moduleRootName
    $moduleRoot = Join-Path -Path $moduleRoot -ChildPath ('{0}.psd1' -f $ModuleName)
    if( -not (Test-Path -Path $moduleRoot -PathType Leaf) )
    {
        Write-Error -Message ('Failed to install {0} {1}: it downloaded successfully, but we failed to rename it to {2}.' -f $ModuleName,$Version,$moduleRootName)
        return
    }

    return $moduleRoot
}