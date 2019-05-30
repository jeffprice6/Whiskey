Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

# Build the assemblies that use NUnit3. Only do this once.
$latestNUnit3Version = '3.7.0'
$nugetPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Whiskey\bin\NuGet.exe' -Resolve
$packagesRoot = Join-Path -Path $PSScriptRoot -ChildPath 'packages'
$argument = $null
$clean = $false
$coverageFilter = $null
$disableCodeCoverage = $false
$failed = $false
$framework = $null
$targetResultFormat = $null
$initialize = $null
$openCoverVersion = $null
$openCoverArgument = $null
$output = $null
$path = $null
$testFilter = $null
$reportGeneratorVersion = $null
$reportGeneratorArgument = $null

$outputDirectory = $null
$nunitReport = $null
$openCoverReport = $null
$reportGeneratorHtml = $null

function Init
{
    $Global:Error.Clear()
    $script:argument = $null
    $script:clean = $false
    $script:coverageFilter = $null
    $script:disableCodeCoverage = $false
    $script:failed = $false
    $script:framework = $null
    $script:targetResultFormat = $null
    $script:initialize = $null
    $script:openCoverVersion = $null
    $script:openCoverArgument = $null
    $script:output = $null
    $script:path = $null
    $script:testFilter = $null
    $script:reportGeneratorVersion = $null
    $script:reportGeneratorArgument = $null
    $script:nunitVersion = $null
    $script:supportNUnit2 = $false

    $script:buildRoot = $TestDrive.FullName

    $script:outputDirectory = Join-Path -Path $buildRoot -ChildPath '.output'

    # Test assemblies in separate folders to avoid cross-reference of NUnit Framework assembly versions
    @(3, 2) | ForEach-Object  {
        New-Item (Join-Path $buildRoot "NUnit$($_)Tests") -Type Directory
        Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath "Assemblies\NUnit$($_)*Test\bin\*\*") `
            -Destination (Join-Path $buildRoot "NUnit$($_)Tests")
    }
}

function Get-NunitXmlElement
{
    param(
        $ReportFile,
        $Element
    )

    Get-Content $reportFile.FullName -Raw |
        ForEach-Object {
            $testResult = [xml]$_
            $testResult.SelectNodes(('//{0}' -f $Element))
        }
}

function GivenArgument
{
    param(
        $Argument
    )
    $script:argument = $Argument
}

function GivenInitialize
{
    $script:initialize = $true
}

function GivenCoverageFilter
{
    param(
        $Filter
    )

    $script:coverageFilter = $Filter
}

function GivenDisableCodeCoverage
{
    $script:disableCodeCoverage = $true
}

function GivenOpenCoverVersion
{
    param(
        $Version
    )

    $script:openCoverVersion = $Version
}

function GivenOpenCoverArgument
{
    param(
        $Argument
    )

    $script:openCoverArgument = $Argument
}

function GivenPath
{
    param(
        $Path
    )

    $script:path = $Path
}

function GivenSupportNUnit2
{
    param(
        [bool]
        $EnableSupport = $true
    )

    $script:supportNUnit2 = $EnableSupport
}

function GetPassingTestPath
{
    return Join-Path 'NUnit3Tests' 'NUnit3PassingTest.dll'
}

function GetPassingNUnit2TestPath
{
    return Join-Path 'NUnit2Tests' 'NUnit2PassingTest.dll'
}

function GetFailingTestPath
{
    return Join-Path 'NUnit3Tests' 'NUnit3FailingTest.dll'
}

function GivenPassingPath
{
    GivenPath (GetPassingTestPath)
}

function GivenFailingPath
{
    GivenPath (GetFailingTestPath)
}

function GivenFramework
{
    param(
        $Version
    )

    $script:framework = $Version
}

function GivenResultFormat
{
    param(
        $ResultFormat
    )

    $script:targetResultFormat = $ResultFormat
}

function GivenTestFilter
{
    param(
        $Filter
    )

    $script:testFilter = $Filter
}

function GivenReportGeneratorVersion
{
    param(
        $Version
    )

    $script:reportGeneratorVersion = $Version
}

function GivenReportGeneratorArgument
{
    param(
        $Argument
    )

    $script:reportGeneratorArgument = $Argument
}

function GivenVersion
{
    param(
        $Version
    )

    $script:nunitVersion = $Version
}

function WhenRunningTask
{
    [CmdletBinding()]
    param(
        [Switch]
        $InCleanMode
    )

    $taskContext = New-WhiskeyTestContext -ForDeveloper -ForBuildRoot $buildRoot -ForOutputDirectory $outputDirectory

    $taskParameter = @{}

    if ($path)
    {
        $taskParameter['Path'] = $path
    }

    if ($openCoverVersion)
    {
        $taskParameter['OpenCoverVersion'] = $openCoverVersion
    }

    if ($reportGeneratorVersion)
    {
        $taskParameter['ReportGeneratorVersion'] = $reportGeneratorVersion
    }

    if ($disableCodeCoverage)
    {
        $taskParameter['DisableCodeCoverage'] = $true
    }

    if ($framework)
    {
        $taskParameter['Framework'] = $framework
    }

    if ($targetResultFormat)
    {
        $taskParameter['NUnitResultFormat'] = $targetResultFormat
    }

    if ($argument)
    {
        $taskParameter['Argument'] = $argument
    }

    if ($testFilter)
    {
        $taskParameter['TestFilter'] = $testFilter
    }

    if ($openCoverArgument)
    {
        $taskParameter['OpenCoverArgument'] = $openCoverArgument
    }

    if ($reportGeneratorArgument)
    {
        $taskParameter['ReportGeneratorArgument'] = $reportGeneratorArgument
    }

    if ($coverageFilter)
    {
        $taskParameter['CoverageFilter'] = $coverageFilter
    }

    if( $nunitVersion )
    {
        $taskParameter['Version'] = $nunitVersion
    }

    if ($supportNUnit2)
    {
        $taskParameter['SupportNUnit2'] = $supportNUnit2
    }

    if ($InCleanMode)
    {
        $taskContext.RunMode = 'Clean'
    }

    if ($initialize)
    {
        $taskContext.RunMode = 'Initialize'
    }

    Mock -CommandName 'Install-WhiskeyTool' -Module 'Whiskey' -MockWith {
        return (Join-Path -Path $DownloadRoot -ChildPath ('packages\{0}.*' -f $NuGetPackageName)) |
                    Get-Item -ErrorAction Ignore |
                    Select-Object -First 1 |
                    Select-Object -ExpandProperty 'FullName'
    }

    Mock -CommandName 'Uninstall-WhiskeyTool' -ModuleName 'Whiskey'

    Copy-Item -Path $packagesRoot -Destination $buildRoot -Recurse -ErrorAction Ignore

    try
    {
        $script:output = Invoke-WhiskeyTask -TaskContext $taskContext -Parameter $taskParameter -Name 'NUnit3'
    }
    catch
    {
        $script:failed = $true
        Write-Error -ErrorRecord $_
    }
}

function ThenPackageInstalled
{
    param(
        $PackageName,
        $Version
    )

    It ('should install package ''{0}''' -f $PackageName) {
        Assert-MockCalled -CommandName 'Install-WhiskeyTool' -ModuleName 'Whiskey' -ParameterFilter {
            # $DebugPreference = 'Continue'
            Write-Debug -Message ('NuGetPackageName  expected  {0}' -f $PackageName)
            Write-Debug -Message ('                  actual    {0}' -f $NuGetPackageName)
            $NuGetPackageName -eq $PackageName
        }
        if( $Version )
        {
            $expectedVersion = $Version
            Assert-MockCalled -CommandName 'Install-WhiskeyTool' -ModuleName 'Whiskey' -ParameterFilter { $Version -eq $expectedVersion }
        }
    }
}

function ThenPackageNotInstalled
{
    param(
        $PackageName
    )

    It ('should not install package ''{0}''' -f $PackageName) {
        Assert-MockCalled -CommandName 'Install-WhiskeyTool' -ModuleName 'Whiskey' -ParameterFilter { $NuGetPackageName -eq $PackageName } -Times 0
    }
}

function ThenPackageUninstalled
{
    param(
        $PackageName,
        $Version
    )

    It ('should not install package ''{0}''' -f $PackageName) {
        Assert-MockCalled -CommandName 'Uninstall-WhiskeyTool' -ModuleName 'Whiskey' -ParameterFilter { $NuGetPackageName -eq $PackageName }
        $expectedVersion = $Version
        Assert-MockCalled -CommandName 'Uninstall-WhiskeyTool' -ModuleName 'Whiskey' -ParameterFilter { $Version -eq $expectedVersion }
    }
}

function ThenPackagesDownloaded
{
    ThenPackageInstalled 'NUnit.ConsoleRunner' $latestNUnit3Version
    ThenPackageInstalled 'OpenCover' $openCoverVersion
    ThenPackageInstalled 'ReportGenerator' $reportGeneratorVersion
}

function ThenRanNUnitWithNoHeaderArgument
{
    It 'should run NUnit with additional given arguments' {
        $output[0] | Should -Not -Match 'NUnit Console Runner'
    }
}

function ThenRanWithSpecifiedFramework
{
    $nunitReport = GetGeneratedNUnitReport

    $resultFramework = Get-NunitXmlElement -ReportFile $nunitReport -Element 'setting'
    $resultFramework = $resultFramework | Where-Object { $_.name -eq 'RuntimeFramework' } | Select-Object -ExpandProperty 'value'

    It 'should run with specified framework' {
        $resultFramework | Should -Be $framework
    }

}

function ThenTaskFailedWithMessage
{
    param(
        $Message
    )

    It 'task should fail' {
        $failed | Should -Be $true
    }

    It ('error message should match [{0}]' -f $Message) {
        $Global:Error[0] | Should -Match $Message
    }
}

function ThenTaskSucceeded
{
    It 'should not write any errors' {
        $Global:Error | Should -BeNullOrEmpty
    }

    It 'task should not fail' {
        $failed | Should -Be $false
    }
}

function ThenRanOnlySpecificTest
{
    param(
        $TestName
    )

    $nunitReport = GetGeneratedNUnitReport

    $testResults = Get-NunitXmlElement -ReportFile $nunitReport -Element 'test-case'
    $testResultsCount = $testResults.name | Measure-Object | Select-Object -ExpandProperty Count

    $testNameCount = $TestName | Measure-Object | Select-Object -ExpandProperty Count

    It 'should only run specific tests' {
        $testResultsCount | Should -Be $testNameCount

        $testResults.name | ForEach-Object {
            $_ | Should -BeIn $TestName
        }
    }
}

function GetGeneratedNUnitReport {
    param(
        $ResultFormat = 'nunit3'
    )

    return Get-ChildItem -Path $outputDirectory -Filter "$($ResultFormat)*.xml"
}

function ThenNUnitReportGenerated
{
    param(
        $ResultFormat = 'nunit3'
    )

    $nunitReport = GetGeneratedNUnitReport -ResultFormat $ResultFormat

    It 'should run NUnit test and generate output' {
        $nunitReport | Should -Not -BeNullOrEmpty -Because 'test results should be saved'
    }

    It 'should generate reports that support running task in parallel' {
        $nunitReport | Select-Object -ExpandProperty 'Name' | Should -Match "^$($ResultFormat)\+.{8}\..{3}\.xml"
    }

    It 'should write results to report xml file' {
        if ($ResultFormat -eq 'nunit3') {
            Get-NunitXmlElement -ReportFile $nunitReport -Element 'test-run' | Should -Not -BeNullOrEmpty
        } else {
            Get-NunitXmlElement -ReportFile $nunitReport -Element 'test-results' | Should -Not -BeNullOrEmpty
        }
        Get-NunitXmlElement -ReportFile $nunitReport -Element 'test-case' | Should -Not -BeNullOrEmpty
    }
}

function ThenCodeCoverageReportGenerated
{
    $openCoverReport = Get-ChildItem -Path $outputDirectory -Filter 'openCover.xml' -Recurse
    $reportGeneratorHtml = Get-ChildItem -Path $outputDirectory -Filter 'index.htm' -Recurse

    It 'should run OpenCover' {
        $openCoverReport | Should -Not -BeNullOrEmpty
    }

    It 'should run ReportGenerator' {
        $reportGeneratorHtml | Should -Not -BeNullOrEmpty
    }
}

function ThenCodeCoverageReportNotCreated
{
    $openCoverReport = Get-ChildItem -Path $outputDirectory -Filter 'openCover.xml' -Recurse
    $reportGeneratorHtml = Get-ChildItem -Path $outputDirectory -Filter 'index.htm' -Recurse

    It 'should not run OpenCover' {
        $openCoverReport | Should -BeNullOrEmpty
    }

    It 'should not run ReportGenerator' {
        $reportGeneratorHtml | Should -BeNullOrEmpty
    }
}

function ThenNUnitShouldNotRun
{
    $nunitReport = GetGeneratedNUnitReport

    It 'should not run NUnit tests' {
        $nunitReport | Should -BeNullOrEmpty -Because 'test results should not be saved if NUnit does not run'
    }
}

function ThenOutput
{
    param(
        $Contains,
        $DoesNotContain
    )

    if ($Contains)
    {
        It ('output should contain [{0}]' -f $Contains) {
            $output -join [Environment]::NewLine | Should -Match $Contains
        }
    }
    else {
        It ('output should not contain [{0}]' -f $DoesNotContain) {
            $output -join [Environment]::NewLine | Should -Not -Match $DoesNotContain
        }
    }
}

function ThenRanWithCoverageFilter
{
    $passingTestResult = Join-Path -Path $outputDirectory -ChildPath 'opencover\NUnit3PassingTest_TestFixture.htm'
    $failingTestResult = Join-Path -Path $outputDirectory -ChildPath 'opencover\NUnit3FailingTest_TestFixture.htm'

    It 'should run OpenCover with given coverage filter' {
        $passingTestResult | Should -Exist
        $failingTestResult | Should -Not -Exist
    }
}

if( -not $IsWindows )
{
    Describe 'NUnit3.when run on non-Windows platform' {
        Init
        WhenRunningTask -ErrorAction SilentlyContinue
        ThenTaskFailedWithMessage 'Windows\ platform'
    }
    return
}

$taskContext = New-WhiskeyContext -Environment 'Developer' -ConfigurationPath (Join-Path -Path $PSScriptRoot -ChildPath 'Assemblies\whiskey.nunit3.yml')
Invoke-WhiskeyBuild -Context $taskContext

Remove-Item -Path $packagesRoot -Recurse -Force -ErrorAction Ignore
& $nugetPath install OpenCover -OutputDirectory $packagesRoot
& $nugetPath install ReportGenerator -OutputDirectory $packagesRoot
& $nugetPath install NUnit.ConsoleRunner -Version $latestNUnit3Version -OutputDirectory $packagesRoot
& $nugetPath install NUnit.Console -Version $latestNUnit3Version -OutputDirectory $packagesRoot

Describe 'NUnit3.when running in Clean mode' {
    Init
    GivenOpenCoverVersion '4.6.519'
    GivenReportGeneratorVersion '2.5.11'
    WhenRunningTask -InCleanMode
    ThenPackageUninstalled 'NUnit.ConsoleRunner' $latestNUnit3Version
    ThenPackageUninstalled 'OpenCover' '4.6.519'
    ThenPackageUninstalled 'ReportGenerator' '2.5.11'
    ThenNUnitShouldNotRun
    ThenCodeCoverageReportNotCreated
    ThenTaskSucceeded
}

Describe 'NUnit3.when running in Initialize mode' {
    Init
    GivenOpenCoverVersion '4.6.519'
    GivenReportGeneratorVersion '2.5.11'
    GivenInitialize
    WhenRunningTask
    ThenPackagesDownloaded
    ThenNUnitShouldNotRun
    ThenCodeCoverageReportNotCreated
    ThenTaskSucceeded
}

Describe 'NUnit3.when missing Path parameter' {
    Init
    WhenRunningTask -ErrorAction SilentlyContinue
    ThenTaskFailedWithMessage 'Property ''Path'' is mandatory. It should be one or more paths to the assemblies whose tests should be run'
}

Describe 'NUnit3.when given bad Path' {
    Init
    GivenPath 'NUnit3PassingTest\bin\Debug\NUnit3FailingTest.dll', 'nonexistentfile'
    WhenRunningTask -ErrorAction SilentlyContinue
    ThenTaskFailedWithMessage 'does not exist.'
}

Describe 'NUnit3.when module fails to install' {
    foreach ($package in @('NUnit.ConsoleRunner', 'OpenCover', 'ReportGenerator'))
    {
        Context ('for missing "{0}" module' -f $package) {
            Init
            Mock -CommandName 'Install-WhiskeyTool' -ModuleName 'Whiskey' -ParameterFilter { $NuGetPackageName -eq $package }
            WhenRunningTask -ErrorAction SilentlyContinue
            ThenTaskFailedWithMessage ('"{0}" failed to install.' -f $package)
        }
    }
}

Describe 'NUnit3.when module fails to install while supporting NUnit2' {
    foreach ($package in @('NUnit.Console') + @('NUnit.ConsoleRunner', 'OpenCover', 'ReportGenerator'))
    {
        Context ('for missing "{0}" module' -f $package) {
            Init
            GivenSupportNUnit2
            Mock -CommandName 'Install-WhiskeyTool' -ModuleName 'Whiskey' -ParameterFilter { $NuGetPackageName -eq $package }
            WhenRunningTask -ErrorAction SilentlyContinue
            ThenTaskFailedWithMessage ('"{0}" failed to install.' -f $package)
        }
    }
}

Describe 'NUnit3.when module executables cannot be found' {
    foreach ($executable in @('nunit3-console.exe', 'OpenCover.Console.exe', 'ReportGenerator.exe'))
    {
        Context ('for missing "{0}" executable' -f $executable) {
            Init
            Mock -CommandName 'Get-ChildItem' -ModuleName 'Whiskey' -ParameterFilter { $Filter -eq $executable }
            WhenRunningTask -ErrorAction SilentlyContinue
            ThenTaskFailedWithMessage ('Unable to find "{0}"' -f $executable)
        }
    }
}

Describe 'NUnit3.when running NUnit tests with disabled code coverage' {
    Init
    GivenPassingPath
    GivenDisableCodeCoverage
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportNotCreated
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit tests with multiple paths' {
    Init
    GivenPath (GetPassingTestPath), (GetPassingTestPath)
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenTaskSucceeded
}

Describe 'NUnit3.when running failing NUnit tests' {
    Init
    GivenPath (GetFailingTestPath), (GetPassingTestPath)
    WhenRunningTask -ErrorAction SilentlyContinue
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenTaskFailedWithMessage 'NUnit3 tests failed'
}

Describe 'NUnit3.when running NUnit tests with specific framework' {
    Init
    GivenPassingPath
    GivenFramework '4.5'
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenRanWithSpecifiedFramework
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit2 tests generating NUnit3 output' {
    Init
    GivenSupportNUnit2
    GivenPath (GetPassingNUnit2TestPath)
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit2 tests generating NUnit2 output' {
    Init
    GivenSupportNUnit2
    GivenPath (GetPassingNUnit2TestPath)
    GivenResultFormat 'nunit2'
    WhenRunningTask
    ThenNUnitReportGenerated -ResultFormat 'nunit2'
    ThenCodeCoverageReportGenerated
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit with extra arguments' {
    Init
    GivenPassingPath
    GivenArgument '--noheader', '--dispose-runners'
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenRanNUnitWithNoHeaderArgument
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit with bad arguments' {
    Init
    GivenPassingPath
    GivenArgument '-badarg'
    WhenRunningTask -ErrorAction SilentlyContinue
    ThenNUnitShouldNotRun
    ThenTaskFailedWithMessage 'NUnit3 didn''t run successfully'
}

Describe 'NUnit3.when running NUnit with a test filter' {
    Init
    GivenPassingPath
    GivenTestFilter "cat == 'Category with Spaces 1'"
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenRanOnlySpecificTest 'HasCategory1'
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit with multiple test filters' {
    Init
    GivenPassingPath
    GivenTestFilter "cat == 'Category with Spaces 1'", "cat == 'Category with Spaces 2'"
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenRanOnlySpecificTest 'HasCategory1','HasCategory2'
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit tests with OpenCover argument' {
    Init
    GivenPassingPath
    GivenOpenCoverArgument '-showunvisited'
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenOutput -Contains '====Unvisited Classes===='
    ThenTaskSucceeded
}

Describe 'NUnit3.when running NUnit tests with OpenCover coverage filter' {
    Init
    GivenPath (GetFailingTestPath), (GetPassingTestPath)
    GivenCoverageFilter '-[NUnit3FailingTest]*','+[NUnit3PassingTest]*'
    WhenRunningTask -ErrorAction SilentlyContinue
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenRanWithCoverageFilter
}

Describe 'NUnit3.when running NUnit tests with ReportGenerator argument' {
    Init
    GivenPassingPath
    GivenReportGeneratorArgument '-verbosity:off'
    WhenRunningTask
    ThenNUnitReportGenerated
    ThenCodeCoverageReportGenerated
    ThenOutput -DoesNotContain 'Initializing report builders'
    ThenTaskSucceeded
}

Describe 'NUnit3.when using custom version of NUnit 3' {
    Init
    GivenPassingPath
    GivenVersion '3.2.1'
    WhenRunningTask
    ThenPackageInstalled 'NUnit.ConsoleRunner' '3.2.1'
    ThenTaskSucceeded
}

Describe 'NUnit3.when using a non-3 version of NUnit' {
    Init
    GivenPassingPath
    GivenVersion '2.6.4'
    WhenRunningTask -ErrorAction SilentlyContinue
    ThenPackageNotInstalled 'NUnit.ConsoleRunner'
    ThenTaskFailedWithMessage 'isn''t\ a\ valid\ 3\.x\ version\ of\ NUnit'
}