
[CmdletBinding()]
param(
)

$originalVerbosePreference = $Global:VerbosePreference

try
{
    $Global:VerbosePreference = 'SilentlyContinue'

    # Some tests load ProGetAutomation from a Pester test drive. Forcibly remove the module if it is loaded to avoid errors.
    if( (Get-Module -Name 'ProGetAutomation') )
    {
        Remove-Module -Name 'ProGetAutomation' -Force 
    }

    & (Join-Path -Path $PSScriptRoot -ChildPath '..\Whiskey\Import-Whiskey.ps1' -Resolve)

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'WhiskeyTest.psm1') -Force 

    foreach( $name in @( 'PackageManagement', 'PowerShellGet' ) )
    {
        if( (Get-Module -Name $name) )
        {
            Remove-Module -Name $name -Force 
        }

        Import-WhiskeyTestModule -Name $name -Force
    }

    Import-WhiskeyTestModule -Name 'BuildMasterAutomation' -Force
    Import-WhiskeyTestModule -Name 'ProGetAutomation' -Force

}
finally
{
    $Global:VerbosePreference = $originalVerbosePreference
}