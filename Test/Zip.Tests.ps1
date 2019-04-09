
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

$threwException = $false
$context = $null
$expandPath = $null

function Get-BuildRoot
{
    $buildRoot = (Join-Path -Path $TestDrive.FullName -ChildPath 'Repo')
    New-Item -Path $buildRoot -ItemType 'Directory' -Force -ErrorAction Ignore | Out-Null
    return $buildRoot
}

function Init
{
    $script:threwException = $false
    $script:context = $null
    $script:expandPath = Join-Path -Path $TestDrive.FullName -ChildPath ([IO.Path]::GetRandomFileName())

    Remove-Module -Force -Name Zip -ErrorAction Ignore
}

function Install-Zip
{
    param(
        $BuildRoot
    )

    # Copy ZIP in place otherwise every test downloads it from the gallery
    $psModulesRoot = Join-Path -Path $BuildRoot -ChildPath 'PSModules'
    if( -not (Test-Path -Path $psModulesRoot -PathType Container) )
    {
        New-Item -Path $psModulesRoot -ItemType 'Directory'
    }

    if( -not (Test-Path -Path (Join-Path -Path $psModulesRoot -ChildPath 'Zip') -PathType Container ) )
    {
        Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\PSModules\Zip') `
                  -Destination $psModulesRoot `
                  -Recurse
    }
}

function GivenARepositoryWithItems
{
    param(
        [string[]]
        $Path,

        $ItemType = 'File'
    )

    $buildRoot = Get-BuildRoot

    foreach( $item in $Path )
    {
        $parent = $item | Split-Path
        if( $parent )
        {
            New-Item -Path (Join-Path -Path $buildRoot -ChildPath $parent) -ItemType 'Directory' -Force -ErrorAction Ignore
        }

        $destinationPath = Join-Path -Path $buildRoot -ChildPath $item
        if( $ItemType -eq 'File' )
        {
            Copy-Item -Path $PSCommandPath -Destination $destinationPath
        }
        else
        {
            New-Item -Path $destinationPath -ItemType 'Directory'
        }
    }

    Install-Zip -BuildRoot $buildRoot
}

function ThenArchiveShouldInclude
{
    param(
        $ArchivePath,

        [Parameter(Position=0)]
        [string[]]
        $Path
    )

    if( -not $Path )
    {
        It ('should include nothing') {
            Get-ChildItem -Path $expandPath | Should -BeNullOrEmpty
        }
        return
    }

    foreach( $item in $Path )
    {
        $expectedPath = Join-Path -Path $expandPath -ChildPath $item
        It ('should include {0}' -f $item) {
            $expectedPath | Should -Exist
        }
    }
}

function ThenArchiveShouldBeCompressed
{
    param(
        $Path,

        [Int]
        $GreaterThan,

        [int]
        $LessThanOrEqualTo
    )

    $archivePath = Join-Path -Path (Get-BuildRoot) -ChildPath $Path
    $archiveSize = (Get-Item $archivePath).Length
    $DebugPreference = 'Continue'
    Write-Debug -Message ('Archive size: {0}' -f $archiveSize)
    if( $GreaterThan )
    {
        It ('should have a compressed archive size greater than {0}' -f $GreaterThan) {
            $archiveSize | Should -BeGreaterThan $GreaterThan
        }
    }

    if( $LessThanOrEqualTo )
    {
        It ('should have a compressed archive size less than or equal to {0}' -f $LessThanOrEqualTo) {
            $archiveSize | Should -Not -BeGreaterThan $LessThanOrEqualTo
        }
    }

}

function ThenArchiveShouldNotInclude
{
    param(
        [string[]]
        $Path
    )

    foreach( $item in $Path )
    {
        It ('archive should not include {0}' -f $item) {
            (Join-Path -Path $expandPath -ChildPath $item) | Should -Not -Exist
        }
    }
}

function ThenTaskFails
{
    Param(
        [String]
        $error
    )

    It ('should fail') {
        $threwException | Should -BeTrue
    }

    It ('should write error message' -f $error) {
        $Global:Error | Should -Match $error
    }
}

function ThenTaskSucceeds
{
    It ('should not throw an error message') {
        $Global:Error | Should -BeNullOrEmpty
    }
}

function WhenPackaging
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $WithYaml,

        [string]
        $ToFile
    )

    # Make sure the build root exists.
    Get-BuildRoot | Out-Null

    $script:context = $taskContext = New-WhiskeyTestContext -ForBuildRoot 'Repo' -ForBuildServer -ForYaml $WithYaml
    $taskParameter = $context.Configuration['Build'][0]['Zip']

    $At = $null
    
    $Global:Error.Clear()

    try
    {
        Invoke-WhiskeyTask -TaskContext $taskContext -Parameter $taskParameter -Name 'Zip'
    }
    catch
    {
        $script:threwException = $true
        Write-Error -ErrorRecord $_
        return
    }
    
    if( -not $ToFile )
    {
        $ToFile = $context.Configuration['Build'][0]['Zip']['ArchivePath']
        $ToFile = Join-Path -Path (Get-BuildRoot) -ChildPath $ToFile
    }
    if( (Test-Path -Path $ToFile -PathType Leaf) )
    {
        Expand-Archive -Path $ToFile -DestinationPath $expandPath -Force
    }
}

Describe 'Zip.when packaging a directory with custom destination name' {
    Init
    GivenARepositoryWithItems 'dir1\some_file.txt','dir2\dir3\another_file.txt','dir4\dir5\last_file.txt'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - dir1: dirA
    - dir2\dir3: dir2\dirC
    - dir4\dir5: dirD\dir5
    Include:
    - "*.txt"
'@
    ThenTaskSucceeds
    ThenArchiveShouldInclude 'dirA\some_file.txt','dir2\dirC\another_file.txt','dirD\dir5\last_file.txt'
}

Describe 'Zip.when archive is empty' {
    Init
    GivenARepositoryWIthItems 'file.txt'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - .
    Include:
    - "*.fubar"
'@
    ThenArchiveShouldInclude
}

Describe 'Zip.when path contains wildcards' {
    Init
    GivenARepositoryWIthItems 'one.ps1','two.ps1','three.ps1'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - "*.ps1"
    Include:
    - "*.txt"
'@
    ThenArchiveShouldInclude 'one.ps1','two.ps1','three.ps1'
}

Describe 'Zip.when packaging a directory' {
    Init
    GivenARepositoryWIthItems 'dir1\subdir\file.txt'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - dir1\subdir\
    Include:
    - "*.txt"
'@
    ThenArchiveShouldInclude 'dir1\subdir\file.txt'
}

Describe 'Zip.when packaging a filtered directory' {
    Init
    GivenARepositoryWIthItems 'dir1\subdir\file.txt','dir1\one.ps1','dir1\dir2\file.txt'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - dir1\subdir\
    Include:
    - "*.txt"
    Exclude:
    - dir2
'@
    ThenArchiveShouldInclude 'dir1\subdir\file.txt'
    ThenArchiveShouldNotInclude 'dir1\one.ps1','dir1\dir2\file.txt'
}

Describe 'Zip.when packaging a directory with a space' {
    Init
    GivenARepositoryWIthItems 'dir 1\sub dir\file.txt'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - dir 1\sub dir\
    Include:
    - "*.txt"
'@
    ThenArchiveShouldInclude 'dir 1\sub dir\file.txt'
}

Describe 'Zip.when packaging a directory with a space and trailing backslash' {
    Init
    GivenARepositoryWIthItems 'dir 1\sub dir\file.txt'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - dir 1\sub dir\
    Include:
    - "*.txt"
'@
    ThenArchiveShouldInclude 'dir 1\sub dir\file.txt'
}

Describe ('Zip.when compression level is Optimal') {
    Init
    GivenARepositoryWithItems 'one.ps1'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    CompressionLevel: Optimal
    Path:
    - "*.ps1"
'@
    ThenArchiveShouldBeCompressed 'Zip.zip' -LessThanOrEqualTo 3100
}

Describe ('Zip.when compression level is Fastest') {
    Init
    GivenARepositoryWithItems 'one.ps1'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    CompressionLevel: Fastest
    Path:
    - "*.ps1"
'@
    ThenArchiveShouldBeCompressed 'Zip.zip' -GreaterThan 3100
}

Describe ('Zip.when compression level is NoCompression') {
    Init
    GivenARepositoryWithItems 'one.ps1'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    CompressionLevel: NoCompression
    Path:
    - "*.ps1"
'@
    ThenArchiveShouldBeCompressed 'Zip.zip' -GreaterThan (Get-Item -Path $PSCommandPath).Length
}

Describe 'Zip.when compression level is not included' {
    Init
    GivenARepositoryWIthItems 'one.ps1'
    WhenPackaging @"
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - "*.ps1"
"@
    ThenArchiveShouldBeCompressed 'Zip.zip' -LessThanOrEqualTo 3100
}

Describe 'Zip.when a bad compression level is included' {
    Init
    GivenARepositoryWIthItems 'one.ps1'
    WhenPackaging -ErrorAction SilentlyContinue @'
Build:
- Zip:
    ArchivePath: Zip.zip
    CompressionLevel: this is no good
    Path:
    - "*.ps1"
'@
    ThenTaskFails 'is an invalid compression level'
}

Describe 'Zip.when archive and source have empty directories' {
    Init
    GivenARepositoryWithItems 'root.ps1','dir1\one.ps1','dir1\emptyDir2\text.txt'
    GivenARepositoryWithItems 'dir1\emptyDir1' -ItemType 'Directory'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - .
    Include:
    - "*.ps1"
    Exclude:
    - .output
'@
    ThenArchiveShouldInclude 'root.ps1','dir1\one.ps1'
    ThenArchiveShouldNotInclude 'dir1\emptyDir1', 'dir1\emptyDir2'
}

Describe 'Zip.when archive has JSON files' {
    Init
    GivenARepositoryWIthItems 'my.json'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - .
    Include:
    - "*.json"
    Exclude:
    - .output
'@
    ThenArchiveShouldInclude 'my.json'
}

Describe 'Zip.when archive includes a directory but whitelist is empty' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path:
    - dir
'@
    ThenArchiveShouldInclude 'dir\my.json','dir\yours.json'
}

Describe 'Zip.when customizing entry name encoding' {
    Context ('using encoding name') {
        Mock -CommandName 'Add-ZipArchiveEntry' -ModuleName 'Whiskey'
        Mock -CommandName 'New-ZipArchive' -ModuleName 'Whiskey'
        Init
        GivenARepositoryWIthItems 'dir\file.txt'
        WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    EntryNameEncoding: ASCII
    Path:
    - dir
'@
        It ('should pass entry encoding') {
            Assert-MockCalled -CommandName 'Add-ZipArchiveEntry' -ModuleName 'Whiskey' -ParameterFilter { $EntryNameEncoding -eq [Text.Encoding]::ASCII }
            Assert-MockCalled -CommandName 'New-ZipArchive' -ModuleName 'Whiskey' -ParameterFilter { $EntryNameEncoding -eq [Text.Encoding]::ASCII }
        }
    }
    Context ('using invalid encoding name') {
        Init
        GivenARepositoryWIthItems 'dir\file.txt'
        WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    EntryNameEncoding: fdsfsdfsdaf
    Path:
    - dir
'@ -ErrorAction SilentlyContinue
        ThenTaskFails 'fdsfsdfsdaf'
    }
    Context ('using code page ID') {
        Mock -CommandName 'Add-ZipArchiveEntry' -ModuleName 'Whiskey'
        Mock -CommandName 'New-ZipArchive' -ModuleName 'Whiskey'
        Init
        GivenARepositoryWIthItems 'dir\file.txt'
        WhenPackaging @"
Build:
- Zip:
    ArchivePath: Zip.zip
    EntryNameEncoding: $([Text.Encoding]::UTF32.CodePage)
    Path:
    - dir
"@
        It ('should pass entry encoding') {
            Assert-MockCalled -CommandName 'Add-ZipArchiveEntry' -ModuleName 'Whiskey' -ParameterFilter { $EntryNameEncoding -eq [Text.Encoding]::UTF32 }
            Assert-MockCalled -CommandName 'New-ZipArchive' -ModuleName 'Whiskey' -ParameterFilter { $EntryNameEncoding -eq [Text.Encoding]::UTF32 }
        }
    }
    Context ('using invalid code page') {
        Init
        GivenARepositoryWIthItems 'dir\file.txt'
        WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    EntryNameEncoding: 65535
    Path:
    - dir
'@ -ErrorAction SilentlyContinue
        ThenTaskFails '65535'
    }
}

Describe 'Zip.when changing archive''s source root' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    SourceRoot: dir
    Path:
    - "*.json"
'@
    ThenArchiveShouldInclude 'my.json','yours.json'
}

Describe 'Zip.when given full path to output file' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: $(WHISKEY_OUTPUT_DIRECTORY)\Zip.zip
    Path: dir
    Include: "*.json"
'@ -ToFile (Join-Path -Path (Get-BuildRoot) -ChildPath '.output\Zip.zip')
    ThenArchiveShouldInclude 'dir\my.json','dir\yours.json'
}

Describe 'Zip.when absolute path to archive root outside repository' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json'
    $systemRoot = 'C:\Windows\system32\'
    if( -not $IsWindows )
    {
        $systemRoot = '/sbin/'
    }
    WhenPackaging @"
Build:
- Zip:
    ArchivePath: $($systemRoot)Zip.zip
    Path: dir
    Include: "*.json"
"@ -ErrorAction SilentlyContinue
    ThenTaskFails 'outside the build root'
}

Describe 'Zip.when relative path to archive root outside repository' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: ..\..\..\Zip.zip
    Path: dir
    Include: "*.json"
'@ -ErrorAction SilentlyContinue
    ThenTaskFails 'outside the build root'
}

Describe 'Zip.when path to archive is in directory that doesn''t exist' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: some\custom\directory\Zip.zip
    Path: dir
    Include: "*.json"
'@ -ToFile (Join-Path -Path (Get-BuildRoot) -ChildPath 'some\custom\directory\Zip.zip')
    ThenArchiveShouldInclude 'dir\my.json','dir\yours.json'
}

Describe 'Zip.when Path property is missing' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
'@ -ErrorAction SilentlyContinue
    ThenTaskFails 'is required'
}

Describe 'Zip.when ZIP archive already exists' {
    Init
    GivenARepositoryWithItems 'dir\my.json', 'dir\yours.json', 'Zip.zip'
    WhenPackaging @'
Build:
- Zip:
    ArchivePath: Zip.zip
    Path: dir
'@
    ThenArchiveShouldInclude 'dir\my.json','dir\yours.json'
}

