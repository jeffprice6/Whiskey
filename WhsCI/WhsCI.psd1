#
# Module manifest for module 'WhsCI'
#
# Generated by: ajensen
#
# Generated on: 12/8/2016
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'WhsCI.psm1'

    # Version number of this module.
    ModuleVersion = '0.2.0'

    # ID used to uniquely identify this module
    GUID = '93bd40f1-dee5-45f7-ba98-cb38b7f5b897'

    # Author of this module
    Author = 'WebMD Health Services'

    # Company or vendor of this module
    CompanyName = 'WebMD Health Services'

    # Copyright statement for this module
    Copyright = '(c) 2016 WebMD Health Services. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Continuous Integration/Continuous Delivery module.'

    # Minimum version of the Windows PowerShell engine required by this module
    # PowerShellVersion = ''

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
    RequiredAssemblies = @( 'bin\SemanticVersion.dll' )

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    #ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @( 
                        'BitbucketServerAutomation',
                        'BuildMasterAutomation',
                        'powershell-yaml'
                     )

    # Functions to export from this module
    FunctionsToExport = @( 
                            'ConvertTo-WhsCISemanticVersion',
                            'Get-WhsCIOutputDirectory',
                            'Install-WhsCINodeJs',
                            'Install-WhsCITool',
                            'Invoke-WhsCIAppPackageTask',
                            'Invoke-WhsCIMSBuildTask',
                            'Invoke-WhsCINodeAppPackageTask',
                            'Invoke-WhsCINodeTask',
                            'Invoke-WhsCINuGetPackTask',
                            'Invoke-WhsCINUnit2Task',
                            'Invoke-WhsCIPester3Task',
                            'Invoke-WhsCIPowerShellTask',
                            'Invoke-WhsCIPublishPowerShellModuleTask',
                            'Invoke-WhsCiBuild',
                            'New-WhsCIBuildMasterPackage',
                            'New-WhsCIContext',
                            'Resolve-WhsCITaskPath',
                            'Stop-WhsCITask',
                            'Test-WhsCIRunByBuildServer',
                            'Write-CommandOutput'
                         );

    # Cmdlets to export from this module
    #CmdletsToExport = '*'

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
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://confluence.webmd.net/display/WHS/WhsCI'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
* All of Arc is now included in packages. We no longer filter anything. This is preparation for the day when Arc is distributed as a package.
'@

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}

