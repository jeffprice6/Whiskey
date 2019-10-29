#
# Module manifest for module 'Whiskey'
#
# Generated by: ajensen
#
# Generated on: 12/8/2016
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'Whiskey.psm1'

    # Version number of this module.
    ModuleVersion = '0.43.0'

    # ID used to uniquely identify this module
    GUID = '93bd40f1-dee5-45f7-ba98-cb38b7f5b897'

    # Author of this module
    Author = 'WebMD Health Services'

    # Company or vendor of this module
    CompanyName = 'WebMD Health Services'

    CompatiblePSEditions = @( 'Desktop', 'Core' )

    # Copyright statement for this module
    Copyright = '(c) 2016 - 2018 WebMD Health Services. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Continuous Integration/Continuous Delivery module.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @( 'bin\SemanticVersion.dll', 'bin\Whiskey.dll', 'bin\YamlDotNet.dll' )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @(
                            'Formats\System.Exception.format.ps1xml',
                            'Formats\System.Management.Automation.ErrorRecord.format.ps1xml',
                            'Formats\Whiskey.BuildInfo.format.ps1xml',
                            'Formats\Whiskey.BuildVersion.format.ps1xml',
                            'Formats\Whiskey.Context.format.ps1xml',
                            'Formats\Whiskey.TaskAttribute.format.ps1xml'
                        )

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @( )

    # Functions to export from this module
    FunctionsToExport = @(
                            'Add-WhiskeyApiKey',
                            'Add-WhiskeyCredential',
                            'Add-WhiskeyTaskDefault',
                            'Add-WhiskeyVariable',
                            'Assert-WhiskeyNodePath',
                            'Assert-WhiskeyNodeModulePath',
                            'ConvertFrom-WhiskeyContext'
                            'ConvertFrom-WhiskeyYamlScalar',
                            'ConvertTo-WhiskeyContext',
                            'ConvertTo-WhiskeySemanticVersion',
                            'Get-WhiskeyApiKey',
                            'Get-WhiskeyTask',
                            'Get-WhiskeyCredential',
                            'Get-WhiskeyMSBuildConfiguration',
                            'Install-WhiskeyTool',
                            'Invoke-WhiskeyNodeTask',
                            'Invoke-WhiskeyNpmCommand',
                            'Invoke-WhiskeyPipeline',
                            'Invoke-WhiskeyBuild',
                            'Invoke-WhiskeyTask',
                            'New-WhiskeyContext',
                            'Publish-WhiskeyBuildMasterPackage',
                            'Publish-WhiskeyNuGetPackage',
                            'Publish-WhiskeyProGetUniversalPackage',
                            'Publish-WhiskeyBBServerTag',
                            'Register-WhiskeyEvent',
                            'Resolve-WhiskeyNodePath',
                            'Resolve-WhiskeyNodeModulePath',
                            'Resolve-WhiskeyNuGetPackageVersion',
                            'Resolve-WhiskeyTaskPath',
                            'Resolve-WhiskeyVariable',
                            'Set-WhiskeyBuildStatus',
                            'Set-WhiskeyMSBuildConfiguration',
                            'Stop-WhiskeyTask',
                            'Uninstall-WhiskeyTool',
                            'Unregister-WhiskeyEvent',
                            'Write-WhiskeyDebug',
                            'Write-WhiskeyError',
                            'Write-WhiskeyInfo',
                            'Write-WhiskeyVerbose',
                            'Write-WhiskeyWarning'
                         );

    # Cmdlets to export from this module
    CmdletsToExport = @( )

    # Variables to export from this module
    #VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = '*'

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @( 'build', 'pipeline', 'devops', 'ci', 'cd', 'continuous-integration', 'continuous-delivery', 'continuous-deploy' )

            # A URL to the license for this module.
            LicenseUri = 'https://www.apache.org/licenses/LICENSE-2.0'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/webmd-health-services/Whiskey'

            # A URL to an icon representing this module.
            # IconUri = ''

            # Any prerelease to use when publishing to a repository.
            Prerelease = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
* Moved Whiskey's documentation to [GitHub](https://github.com/webmd-health-services/Whiskey/wiki).
* Fixed: Whiskey's assembly wasn't getting its version metadata set.
* Whiskey no longer ships with PackageManagement and PowerShellGet modules. They are now downloaded from one of your registered PowerShell repositories the first time another PowerShell module is installed.
* The function `Import-WhiskeyPowerShellModule` is no longer public. If your task uses Whiskey's `RequiresTool` attribute to install a PowerShell module, Whiskey now imports that module for you automatically.
* Whiskey now automatically imports PowerShell modules tasks use as declared by their `RequiresTool` attribute.
* Upgraded Whiskey to use PackageManagement 1.4.5 (from 1.4.4).
* Fixed: Whiskey doesn't install the latest version of a PowerShell module if there's any version already installed.
* Improved detection of corrupted PowerShell modules that will force a re-install. Whiskey now uses `Test-ModuleManifest` to determine if a module was installed correctly.
* Added a new built-in Whiskey variable `WHISKEY_SEMVER2_PRERELEASE_ID` which contains the prerelease identifier of the prerelease label on a SemVer2 version string. E.g. Given the version `1.2.3-alpha.47+buildmetata`, this variable would be `alpha`.
* When publishing a prerelease version of a node module, the `PublishNodeModule` task will now automatically publish the module with the prerelease identifier as the distribution tag.
* Added a `Tag` property to the `PublishNodeModule` task that controls what distribution tag the module is published with. If specified, this property takes precendence over a tag from a prerelease identifier.
* Created `AppVeyorWaitForBuildJob` task that will wait for other jobs in an AppVeyor build to complete before continuing.
* Fixed: plug-ins are global to all builds instead of tied to specific builds. This is a backwards-incompatible change. `Register-WhiskeyEvent` and `Unregister-WhiskeyEvent` now require the context of the build on which the events should run. Please update usages.
* Added a custom error record display formatter that shows the entire script stack trace for an error instead of PowerShell's weird position message (which isn't entirely accureate).
* Created a `Write-WhiskeyError` function for displaying build errors to the user.
* Standardized and improved output of Whiskey's `Write-WhiskeyError`, `Write-WhiskeyWarning`, `Write-WhiskeyInfo`, `Write-WhiskeyVerbose`, and `Write-WhiskeyDebug`. Timings and the currently executing task name (if applicable) are added as a prefix to all but error-level messages. Output also no longer contains the current pipeline name or task index/number.
* Fixed: PowerShell task doesn't show any information to the user about what it's doing.
* Created `Log` task for writing logging messages. messages can be written at different levels: Error, Warning, Info (the default), Verbose, or Debug.
* Whiskey now enables information messages during a build. To disable them, pass `-InformationAction Ignore` to `Invoke-WhiskeyBuild` in your build script.
* Added official support for enabling a task's debug output setting the `Debug` property to `true`.
* Fixed: Parallel and PowerShell tasks show duplicate Write-Host output.
* Whiskey's default build.ps1 script is now runnable from any Unix shell.
'@
        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
