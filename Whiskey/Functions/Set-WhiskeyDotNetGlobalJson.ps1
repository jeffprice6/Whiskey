
function Set-WhiskeyDotNetGlobalJson
{
    <#
    .SYNOPSIS
    Sets values within a .NET Core global.json file.

    .DESCRIPTION
    The `Set-WhiskeyDotNetGlobalJson` function sets values within a .NET Core `global.json` file. If the `global.json` file does not exist in the given `Directory` then it will be created. If the `global.json` file already exists, then the function will only update the desired values and leave the rest of the content as-is.

    .EXAMPLE
    Set-WhiskeyDotNetGlobalJson -Directory 'C:\Build\app' -SdkVersion '2.1.4'

    Demonstrates setting the `sdk.version` property in global.json to '2.1.4'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        # The directory where the `global.json` will be created/modified.
        [String]$Directory,

        [Parameter(Mandatory)]
        # The version of the SDK to set within the `global.json` file.
        [String]$SdkVersion
    )

    Set-StrictMode -version 'Latest'
    Use-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

    Write-WhiskeyVerbose -Message ('[{0}] Setting global.json properties: ''sdk.version'' => ''{1}''' -f $MyInvocation.MyCommand,$SdkVersion)

    if (-not (Test-Path -Path $Directory -PathType Container))
    {
        Write-WhiskeyError -Message ('The directory ''{0}'' does not exist.' -f $Directory)
        return
    }

    $globalJsonPath = Join-Path -Path $Directory -ChildPath 'global.json'
    Write-WhiskeyVerbose -Message ('[{0}] Looking for global.json at ''{1}''' -f $MyInvocation.MyCommand,$globalJsonPath)

    if (Test-Path -Path $globalJsonPath -PathType Leaf)
    {
        Write-WhiskeyVerbose -Message ('[{0}] Found existing global.json' -f $MyInvocation.MyCommand)
        Write-WhiskeyVerbose -Message ('[{0}] Updating ''{1}''' -f $MyInvocation.MyCommand,$globalJsonPath)
        try
        {
            $globalJson = Get-Content -Path $globalJsonPath -Raw | ConvertFrom-Json
        }
        catch
        {
            Write-WhiskeyError -Message ('global.json file ''{0}'' contains invalid JSON.' -f $globalJsonPath)
            return
        }

        if (-not ($globalJson | Get-Member -Name 'sdk'))
        {
            $globalJson | Add-Member -MemberType NoteProperty -Name 'sdk' -Value ([pscustomobject]@{ })
        }

        if (-not ($globalJson.sdk | Get-Member -Name 'version'))
        {
            $globalJson.sdk | Add-Member -MemberType NoteProperty -Name 'version' -Value ([pscustomobject]@{ })
        }

        $globalJson.sdk.version = $SdkVersion
    }
    else
    {
        Write-WhiskeyVerbose -Message ('[{0}] global.json does not exist at ''{1}''' -f $MyInvocation.MyCommand,$globalJsonPath)
        Write-WhiskeyVerbose -Message ('[{0}] Creating ''{1}''' -f $MyInvocation.MyCommand,$globalJsonPath)
        $globalJson = @{
                            'sdk' = @{
                                'version' = $SdkVersion
                            }
                       }
    }

    $globalJson | ConvertTo-Json -Depth 100 | Set-Content -Path $globalJsonPath -Force
    Write-WhiskeyVerbose -Message ('[{0}] global.json update finished.' -f $MyInvocation.MyCommand)
}
