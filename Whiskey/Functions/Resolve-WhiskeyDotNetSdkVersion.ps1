
function Resolve-WhiskeyDotNetSdkVersion
{
    <#
    .SYNOPSIS
    Searches for a version of the .NET Core SDK to ensure it exists and returns the resolved version.

    .DESCRIPTION
    The `Resolve-WhiskeyDotNetSdkVersion` function ensures a given version is a valid released version of the .NET Core SDK. By default, the function will return the latest LTS version of the SDK. If a `Version` number is given then that version is compared against the list of released SDK versions to ensure the given version is valid. If no valid version is found matching `Version`, then an error is written and nothing is returned.

    .EXAMPLE
    Resolve-WhiskeyDotNetSdkVersion -LatestLTS

    Demonstrates returning the latest LTS version of the .NET Core SDK.

    .EXAMPLE
    Resolve-WhiskeyDotNetSdkVersion -Version '2.1.2'

    Demonstrates ensuring that version '2.1.2' is a valid released version of the .NET Core SDK.

    .EXAMPLE
    Resolve-WhiskeyDotNetSdkVersion -Version '2.*'

    Demonstrates resolving the latest '2.x.x' version of the .NET Core SDK.
    #>
    [CmdletBinding(DefaultParameterSetName='LatestLTS')]
    param(
        [Parameter(ParameterSetName='LatestLTS')]
        # Returns the latest LTS version of the .NET Core SDK.
        [switch]$LatestLTS,

        [Parameter(Mandatory, ParameterSetName='Version')]
        # Version of the .NET Core SDK to search for and resolve. Accepts wildcards.
        [String]$Version
    )

    Set-StrictMode -version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    if ($Version)
    {
        $urisToTry = @(
            'https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json',
            'https://raw.githubusercontent.com/dotnet/core/master/release-notes/releases-index.json'
        )
        $releasesIndex = $null
        foreach( $uri in $urisToTry )
        {
            $releasesIndex = 
                Invoke-RestMethod -Uri $uri -ErrorAction Ignore |
                Select-Object -ExpandProperty 'releases-index' -ErrorAction Ignore

            if( $releasesIndex )
            {
                $releasesIndexUri = $uri
            }
        }

        if( -not $releasesIndex )
        {
            Write-WhiskeyError -Message ('Unable to find the .NET Core releases index. We tried each of these URIs:{0} {0}* {1}{0} ' -f [Environment]::NewLine,($urisToTry -join ('{0}* ' -f [Environment]::NewLine)))
            return
        }

        $releasesIndex =
            $releasesIndex |
            Where-Object { [Version]::TryParse($_.'channel-version', [ref]$null) } |
            ForEach-Object {
                $_.'channel-version' = [Version]$_.'channel-version'
                $_
            } |
            Sort-Object -Property 'channel-version' -Descending

        $Version -match '^\d+\.(?:\d+|\*)|^\*' | Out-Null
        $matcher = $Matches[0]

        $release = $releasesIndex | Where-Object { $_.'channel-version' -like $matcher } | Select-Object -First 1
        if (-not $release)
        {
            Write-WhiskeyError -Message ('.NET Core release matching "{0}" could not be found in "{1}"' -f $matcher, $releasesIndexUri)
            return
        }

        $releasesJsonUri = $release | Select-Object -ExpandProperty 'releases.json'
        Write-WhiskeyVerbose -Message ('[{0}] Resolving .NET Core SDK version "{1}" against known released versions at: "{2}"' -f $MyInvocation.MyCommand,$Version,$releasesJsonUri)

        $releasesJson = Invoke-RestMethod -Uri $releasesJsonUri -ErrorAction Stop

        $sdkVersions = & {
            $releasesJson.releases |
                Where-Object { $_ | Get-Member -Name 'sdk' } |
                Select-Object -ExpandProperty 'sdk' |
                Select-Object -ExpandProperty 'version'

            $releasesJson.releases |
                Where-Object { $_ | Get-Member -Name 'sdks' } |
                Select-Object -ExpandProperty 'sdks' |
                Select-Object -ExpandProperty 'version'
        }

        $resolvedVersion =
            $sdkVersions |
            ForEach-Object { $_ -as [Version] } |
            Where-Object { $_ -like $Version } |
            Sort-Object -Descending |
            Select-Object -First 1

        if (-not $resolvedVersion)
        {
            Write-WhiskeyError -Message ('A released version of the .NET Core SDK matching "{0}" could not be found in "{1}"' -f $Version, $releasesJsonUri)
            return
        }

        Write-WhiskeyVerbose -Message ('[{0}] SDK version "{1}" resolved to "{2}"' -f $MyInvocation.MyCommand,$Version,$resolvedVersion)
    }
    else
    {
        $latestLTSVersionUri = 'https://dotnetcli.blob.core.windows.net/dotnet/Sdk/LTS/latest.version'

        Write-WhiskeyVerbose -Message ('[{0}] Resolving latest LTS version of .NET Core SDK from: "{1}"' -f $MyInvocation.MyCommand,$latestLTSVersionUri)
        $latestLTSVersion = Invoke-RestMethod -Uri $latestLTSVersionUri -ErrorAction Stop

        if ($latestLTSVersion -match '(\d+\.\d+\.\d+)')
        {
            $resolvedVersion = $Matches[1]
        }
        else
        {
            Write-WhiskeyError -Message ('Could not retrieve the latest LTS version of the .NET Core SDK. "{0}" returned:{1}{2}' -f $latestLTSVersionUri,[Environment]::NewLine,$latestLTSVersion)
            return
        }

        Write-WhiskeyVerbose -Message ('[{0}] Latest LTS version resolved as: "{1}"' -f $MyInvocation.MyCommand,$resolvedVersion)
    }

    return $resolvedVersion
}
