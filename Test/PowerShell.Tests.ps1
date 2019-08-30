 
#Requires -Version 4
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

$workingDirectory = $null
$failed = $false
$scriptName = $null

function Get-OutputFilePath
{
    $path = (Join-Path -Path ($TestDrive.FullName) -ChildPath ('{0}\run' -f $workingDirectory))
    if( -not [IO.Path]::IsPathRooted($path) )
    {
        $path = Join-Path -Path $TestDrive.FullName -ChildPath $path
    }
    return $path
}

function GivenAFailingScript
{
    GivenAScript 'exit 1'
}

function GivenAPassingScript
{
    GivenAScript ''
}

function GivenAScript
{
    param(
        [Parameter(Position=0)]
        [string]
        $Script,

        [string]
        $WithParam = 'param([Parameter(Mandatory=$true)][object]$TaskContext)'
    )

    $script:scriptName = 'myscript.ps1'
    $scriptPath = Join-Path -Path $TestDrive.FullName -ChildPath $scriptName
        
    @"
$($WithParam)

New-Item -Path '$( Get-OutputFilePath | Split-Path -Leaf)' -ItemType 'File'

$($Script)
"@ | Set-Content -Path $scriptPath
}

function GivenLastExitCode
{
    param(
        $ExitCode
    )

    $Global:LASTEXITCODE = $ExitCode
}

function GivenNoWorkingDirectory
{
    $script:workingDirectory = $null
}

function GivenWorkingDirectory
{
    param(
        [string]
        $Path,

        [Switch]
        $ThatDoesNotExist
    )

    $script:workingDirectory = $Path

    $absoluteWorkingDir = $workingDirectory
    if( -not [IO.Path]::IsPathRooted($absoluteWorkingDir) )
    {
        $absoluteWorkingDir = Join-Path -Path $TestDrive.FullName -ChildPath $absoluteWorkingDir
    }

    if( -not $ThatDoesNotExist -and -not (Test-Path -Path $absoluteWorkingDir -PathType Container) )
    {
        New-Item -Path $absoluteWorkingDir -ItemType 'Directory'
    }

}

function WhenTheTaskRuns
{
    [CmdletBinding()]
    param(
        [object]
        $WithArgument,

        [Switch]
        $InCleanMode,

        [Switch]
        $InInitMode
    )

    $taskParameter = @{
                        Path = @(
                                $scriptName
                            )
                        }

    if( $workingDirectory )
    {
        $taskParameter['WorkingDirectory'] = $workingDirectory
    }

    if( $WithArgument )
    {
        $taskParameter['Argument'] = $WithArgument
    }

    $context = New-WhiskeyTestContext -ForDeveloper -InCleanMode:$InCleanMode -InInitMode:$InInitMode
    
    $failed = $false

    $Global:Error.Clear()
    $script:failed = $false
    try
    {

        Invoke-WhiskeyTask -Name 'PowerShell' -TaskContext $context -Parameter $taskParameter -ErrorAction Continue
    }
    catch
    {
        Write-Error -ErrorRecord $_
        $script:failed = $true
    }
}

function ThenTheLastErrorMatches
{
    param(
        $Pattern
    )

    It ("last error message should match /{0}/" -f $Pattern)  {
        $Global:Error[0] | Should -Match $Pattern
    }
}

function ThenTheLastErrorDoesNotMatch
{
    param(
        $Pattern
    )

    It ("last error message should not match /{0}/" -f $Pattern)  {
        $Global:Error[0] | Should -Not -Match $Pattern
    }
}

function ThenTheScriptRan
{
    It 'the script should run' {
        Get-OutputFilePath | Should -Exist
    }
}

function ThenTheScriptDidNotRun
{
    It 'the script should not run' {
        Get-OutputFilePath | Should -Not -Exist
    }
}

function ThenTheTaskFails
{
    It 'the task should fail' {
        $failed | Should -Be $true
    }
}

function ThenTheTaskPasses
{
    It 'the task should pass' {
        $failed | Should -Be $false
    }
    It ('should write no errors') {
        $Global:Error | Should -BeNullOrEmpty
    }
}

Describe 'PowerShell.when script passes' {
    GivenAPassingScript
    GivenNoWorkingDirectory
    WhenTheTaskRuns
    ThenTheScriptRan
    ThenTheTaskPasses
}

Describe 'PowerShell.when script fails due to non-zero exit code' {
    GivenNoWorkingDirectory
    GivenAFailingScript
    WhenTheTaskRuns -ErrorAction SilentlyContinue
    ThenTheScriptRan
    ThenTheTaskFails
    ThenTheLastErrorMatches 'failed, exited with code'
}

Describe 'PowerShell.when script passes after a previous command fails' {
    GivenNoWorkingDirectory
    GivenAPassingScript
    GivenLastExitCode 1
    WhenTheTaskRuns
    ThenTheScriptRan
    ThenTheTaskPasses
}

Describe 'PowerShell.when script throws a terminating exception' {
    GivenAScript @'
throw 'fubar!'
'@ 
    WhenTheTaskRuns -ErrorAction SilentlyContinue
    ThenTheTaskFails
    ThenTheScriptRan
    ThenTheLastErrorMatches 'threw a terminating exception'
}

Describe 'PowerShell.when script''s error action preference is Stop' {
    GivenAScript @'
$ErrorActionPreference = 'Stop'
Write-Error 'snafu!'
throw 'fubar'
'@ 
    WhenTheTaskRuns -ErrorAction SilentlyContinue
    ThenTheTaskFails
    ThenTheScriptRan
    ThenTheLastErrorMatches 'threw a terminating exception'
    ThenTheLastErrorDoesNotMatch 'fubar'
    ThenTheLastErrorDoesNotMatch 'failed, exited with code'
}

Describe 'PowerShell.when script''s error action preference is Stop and script doesn''t complete successfully' {
    GivenAScript @'
$ErrorActionPreference = 'Stop'
Non-ExistingCmdlet -Name 'Test'
throw 'fubar'
'@ 
    WhenTheTaskRuns -ErrorAction SilentlyContinue
    ThenTheTaskFails
    ThenTheScriptRan
    ThenTheLastErrorMatches 'threw a terminating exception'
    ThenTheLastErrorDoesNotMatch 'fubar'
    ThenTheLastErrorDoesNotMatch 'failed, exited with code'
}

Describe 'PowerShell.when working directory does not exist' {
    GivenWorkingDirectory 'C:\I\Do\Not\Exist' -ThatDoesNotExist
    GivenAPassingScript
    WhenTheTaskRuns  -ErrorAction SilentlyContinue
    ThenTheTaskFails
}

function ThenFile
{
    param(
        $Path,
        $HasContent
    )

    $fullpath = Join-Path -Path ($TestDrive.FullName) -ChildPath $Path 
    $fullpath | Should -Exist
    Get-Content -Path $fullpath | Should -Be $HasContent
}

Describe 'PowerShell.when passing positional parameters' {
    GivenNoWorkingDirectory
    GivenAScript @"
`$One | Set-Content -Path 'one.txt'
`$Two | Set-Content -Path 'two.txt'
"@ -WithParam @"
param(
    `$One,
    `$Two
)
"@
    WhenTheTaskRuns -WithArgument (@( 'fubar', 'snafu' ))
    ThenTheTaskPasses
    ThenTheScriptRan
    It 'should pass parameters to script' {
        ThenFile 'one.txt' -HasContent 'fubar'
        ThenFile 'two.txt' -HasContent 'snafu'
    }
}

Describe 'PowerShell.when passing named parameters' {
    GivenNoWorkingDirectory
    GivenAScript @"
`$One | Set-Content -Path 'one.txt'
`$Two | Set-Content -Path 'two.txt'
"@ -WithParam @"
param(
    # Don't remove the [Parameter] attributes. Part of the test!
    [Parameter(Mandatory=`$true)]
    `$One,
    [Parameter(Mandatory=`$true)]
    `$Two
)
"@
    WhenTheTaskRuns -WithArgument @{ 'Two' = 'fubar'; 'One' = 'snafu' }
    ThenTheTaskPasses
    ThenTheScriptRan
    It 'should pass parameters to script' {
        ThenFile 'one.txt' -HasContent 'snafu'
        ThenFile 'two.txt' -HasContent 'fubar'
    }
}

Describe 'PowerShell.when script has TaskContext parameter' {
    $emptyContext = Invoke-WhiskeyPrivateCommand -Name 'New-WhiskeyContextObject'
    GivenAScript @"
exit 0
"@ -WithParam @"
param(
    # Don't remove the [Parameter] attributes. Part of the test!
    [Parameter(Mandatory=`$true)]
    `$TaskContext
)

    `$expectedMembers = & {
$(
    foreach( $memberName in $emptyContext | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty 'Name' )
    {
        "'{0}'`n" -f $memberName
    }
)
    }

    foreach( `$expectedMember in `$expectedMembers )
    {
        if( -not (`$TaskContext | Get-Member -Name `$expectedMember) )
        {
            throw ('TaskContext missing member ''{0}''.' -f `$expectedMember)
        }
    }

    if( `$TaskContext.Version -is [string] )
    {
        throw ('TaskContext.Version is a string instead of a [Whiskey.BuildVersion].')
    }

    if( `$TaskContext.BuildMetadata -is [string] )
    {
        throw ('TaskContext.BuildMetadata is a string instead of a [Whiskey.BuildInfo].')
    }
"@
    WhenTheTaskRuns 
    ThenTheTaskPasses
}

Describe 'PowerShell.when script has Switch parameter' {
    GivenAScript @"
if( -not `$SomeBool -or `$SomeOtherBool )
{
    throw
}
"@ -WithParam @"
param(
    [Switch]
    `$SomeBool,

    [Switch]
    `$SomeOtherBool
)
"@
    WhenTheTaskRuns -WithArgument @{ 'SomeBool' = 'true' ; 'SomeOtherBool' = 'false' }
    ThenTheTaskPasses
}


Describe 'PowerShell.when script has a common parameter that isn''t an argument' {
    GivenAScript @"
Write-Debug 'Fubar'
"@ -WithParam @"
[CmdletBinding()]
param(
)
"@
    WhenTheTaskRuns -WithArgument @{ }
    ThenTheTaskPasses
}

Describe 'PowerShell.when run in Clean mode' {
    GivenAScript
    WhenTheTaskRuns -InCleanMode
    ThenTheTaskPasses
    ThenTheScriptRan
}

Describe 'PowerShell.when run in Initialize mode' {
    GivenAScript 
    WhenTheTaskRuns -InInitMode
    ThenTheTaskPasses
    ThenTheScriptRan
}

Describe 'PowerShell.when Whiskey stored in a directory that doesn''t match module name' {
    $whiskeyRoot = Join-Path -Path $TestDrive.FullName -ChildPath '.whiskey'
    Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\Whiskey' -Resolve) `
              -Recurse `
              -Destination $whiskeyRoot
    & (Join-Path -Path $whiskeyRoot -ChildPath 'Import-Whiskey.ps1' -Resolve)
    try
    {
        GivenAScript
        WhenTheTaskRuns
        ThenTheTaskPasses
        ThenTheScriptRan
    }
    finally
    {
        Remove-Module -Name 'Whiskey' -Force
    }
}