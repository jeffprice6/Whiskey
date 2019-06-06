
& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

$mockPackage = [pscustomobject]@{ }
$mockRelease = [pscustomobject]@{ }
$mockDeploy = [pscustomobject]@{ }
$packageVersion = 'version'
$defaultApiKeyID = 'BuildMaster'
$defaultApiKey = 'fubarsnafu'
$defaultAppName = 'application'
$defaultReleaseId = 483
$packageVariable = @{ 'PackageVariable' = @{ 'One' = 'Two'; 'Three' = 'Four'; } }
$context = $null
$version = $null
$releaseName = $null
$appName = $null
$taskParameter = $null
$releaseId = $null
$apiKeyID = $null
$apiKey = $null
$uri = $null
$packageName = $null
$startAtStage = $null
$skipDeploy = $null

function GivenNoApiKey
{
    param(
        $ID,
        $ApiKey
    )

    $script:apiKeyID = $null
    $script:ApiKey = $null
}

function GivenNoApplicationName
{
    $script:appName = $null
}

function GivenNoReleaseName
{
    $script:releaseName = $null
}

function GivenNoRelease
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]
        $Name,
        [Parameter(Mandatory=$true)]
        [string]
        $ForApplication
    )

    $script:appName = $ForApplication
    $script:releaseId = $null
}

function GivenNoUri
{
    $script:uri = $null
}

function GivenProperty
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $Property
    )

    $script:taskParameter = $Property
}

function GivenPackageName
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $Name
    )
    
    $script:packageName = $Name
}

function GivenStartAtStage
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        $Stage
    )
    
    $script:startAtStage = $Stage
}

function GivenSkipDeploy
{
    param(
    )
    
    $script:skipDeploy = 'true'
}

function Init
{
    $script:version = '9.8.3-rc.1+build.deadbee'
    $script:appName = $defaultAppName
    $script:releaseName = 'release'
    $script:uri = 'https://buildmaster.example.com'
    $script:apiKeyID = $defaultApiKeyID
    $script:apiKey = $defaultApiKey
    $script:releaseId = $defaultReleaseId
    $script:packageVariable = @{ 'PackageVariable' = @{ 'One' = 'Two'; 'Three' = 'Four'; } }
    $script:taskParameter = @{ }
    $script:packageName = $null
    $script:startAtStage = $null
    $script:skipDeploy = 'false'
}

function WhenCreatingPackage
{
    [CmdletBinding()]
    param(
    )

    if( -not $taskParameter )
    {
        $taskParameter = @{ }
    }

    if( $appName )
    {
        $taskParameter['ApplicationName'] = $appName
    }

    if( $releaseName )
    {
        $taskParameter['ReleaseName'] = $releaseName
    }
    
    $script:context = New-WhiskeyTestContext -ForVersion $version -ForTaskName 'PublishBuildMasterPackage' -ForBuildServer
    
    if( $apiKeyID )
    {
        $taskParameter['ApiKeyID'] = $apiKeyID
        Add-WhiskeyApiKey -Context $context -ID $apiKeyID -Value $apiKey
    }
    
    if( $uri )
    {
        $taskParameter['Uri'] = $uri
    }
    
    if( $packageName )
    {
        $taskParameter['PackageName'] = $packageName
    }

    if( $startAtStage )
    {
        $taskParameter['StartAtStage'] = $startAtStage
    }

    if( $skipDeploy )
    {
        $taskParameter['SkipDeploy'] = $skipDeploy
    }
    
    $package = $mockPackage
    $deploy = $mockDeploy
    $release = [pscustomobject]@{ Application = $appName; Name = $releaseName; id = $releaseId  }
    if( $releaseId )
    {
        Mock -CommandName 'Get-BMRelease' -ModuleName 'Whiskey' -MockWith { return $release  }.GetNewClosure()
    }
    else
    {
        Mock -CommandName 'Get-BMRelease' -ModuleName 'Whiskey' -MockWith { }
    }
    Mock -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -MockWith { return [pscustomobject]@{ Release = $Release; PackageNumber = $PackageNumber; Variable = $Variable } }
    Mock -CommandName 'Publish-BMReleasePackage' -ModuleName 'Whiskey' -MockWith { return [pscustomobject]@{ Package = $package } }

    $script:threwException = $false
    try
    {
        $Global:Error.Clear()
        Invoke-WhiskeyTask -TaskContext $context -Name 'PublishBuildMasterPackage' -Parameter $taskParameter
    }
    catch
    {
        $script:threwException = $true
        Write-Error $_
    }
}

function ThenCreatedPackage
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $InRelease,

        [Parameter(Mandatory=$true)]
        [string]
        $ForApplication,

        [Parameter(Mandatory=$true)]
        [string]
        $AtUri,

        [Parameter(Mandatory=$true)]
        [string]
        $UsingApiKey,

        [Parameter(Mandatory=$true)]
        [hashtable]
        $WithVariables
    )

    It ('should create package ''{0}''' -f $Name) {
        Assert-MockCalled -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -ParameterFilter { $PackageNumber -eq $Name }
    }

    It ('should create package in release ''{0}''' -f $InRelease) {
        Assert-MockCalled -CommandName 'Get-BMRelease' -ModuleName 'Whiskey' -ParameterFilter { $Name -eq $InRelease }
        Assert-MockCalled -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -ParameterFilter { $Release.id -eq $releaseId }
    }

    It ('should create package in application ''{0}''' -f $ForApplication) {
        Assert-MockCalled -CommandName 'Get-BMRelease' -ModuleName 'Whiskey' -ParameterFilter { $Application -eq $ForApplication }
    }
    
    It ('should create package at ''{0}''' -f $AtUri) {
        Assert-MockCalled -CommandName 'Get-BMRelease' -ModuleName 'Whiskey' -ParameterFilter { $Session.Uri -eq $AtUri }
        Assert-MockCalled -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -ParameterFilter { $Session.Uri -eq $AtUri }
    }

    It ('should create package with API key ''{0}''' -f $UsingApiKey) {
        Assert-MockCalled -CommandName 'Get-BMRelease' -ModuleName 'Whiskey' -ParameterFilter { $Session.ApiKey -eq $UsingApiKey }
        Assert-MockCalled -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -ParameterFilter { $Session.ApiKey -eq $UsingApiKey }
    }
    
    foreach( $variableName in $WithVariables.Keys )
    {
        $variableValue = $WithVariables[$variableName]
        It ('should create package variable ''{0}''' -f $variableName) {
            Assert-MockCalled -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -ParameterFilter { 
                #$DebugPreference = 'Continue'
                Write-Debug ('Expected  {0}' -f $variableValue)
                Write-Debug ('Actual    {0}' -f $Variable[$variableName])
                $Variable.ContainsKey($variableName) -and $Variable[$variableName] -eq $variableValue
            }
        }
    }

    It ('should fail the build if BuildMaster calls fail') {
        Assert-MockCalled -CommandName 'Get-BMRelease' -ModuleName 'Whiskey' -ParameterFilter { $ErrorActionPreference -eq 'Stop' }
        Assert-MockCalled -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -ParameterFilter { $ErrorActionPreference -eq 'stop' }
    }
}

function ThenPackageDeployed
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $AtUri,

        [Parameter(Mandatory=$true)]
        [string]
        $UsingApiKey,
        
        [string]
        $AtStage
    )
    
    if( $AtStage )
    {    
        It ('should deploy package to stage ''{0}''' -f $AtStage) {
            Assert-MockCalled -CommandName 'Publish-BMReleasePackage' -ModuleName 'Whiskey' -ParameterFilter { $Stage -eq $AtStage }
        }
    }
    else
    {
        It 'should deploy package to first stage of release pipeline' {
            Assert-MockCalled -CommandName 'Publish-BMReleasePackage' -ModuleName 'Whiskey' -ParameterFilter { $Stage -eq '' }
        }
    }

    It ('should deploy package at ''{0}''' -f $AtUri) {
        Assert-MockCalled -CommandName 'Publish-BMReleasePackage' -ModuleName 'Whiskey' -ParameterFilter { $Session.Uri -eq $AtUri }
    }

    It ('should deploy package with API key ''{0}''' -f $UsingApiKey) {
        Assert-MockCalled -CommandName 'Publish-BMReleasePackage' -ModuleName 'Whiskey' -ParameterFilter { $Session.ApiKey -eq $UsingApiKey }
    }
    
    It ('should fail the build if BuildMaster calls fail') {
        Assert-MockCalled -CommandName 'Publish-BMReleasePackage' -ModuleName 'Whiskey' -ParameterFilter { $ErrorActionPreference -eq 'stop' }
    }
}

function ThenPackageNotDeployed
{
    param(
    )
    
    It 'should not start deploy' {
        Assert-MockCalled -CommandName 'Publish-BMReleasePackage' -ModuleName 'Whiskey' -Times 0
    }
}

function ThenPackageNotCreated
{
    [CmdletBinding()]
    param(
    )

    process
    {
        It 'should not create release package' {
            Assert-MockCalled -CommandName 'New-BMPackage' -ModuleName 'Whiskey' -Times 0
        }

        ThenPackageNotDeployed
    }
}

function ThenTaskFails
{
    param(
        $Pattern
    )

    It 'should throw an exception' {
        $threwException | Should -Be $true
    }

    It 'should write an errors' {
        $Global:Error | Should -Match $Pattern
    }
}

Describe 'Publish-WhiskeyBuildMasterPackage.when called' {
    Init
    GivenProperty $packageVariable
    WhenCreatingPackage
    ThenCreatedPackage '9.8.3' -InRelease 'release' -ForApplication 'application' -AtUri 'https://buildmaster.example.com' -UsingApiKey 'fubarsnafu' -WithVariables @{ One = 'Two'; Three = 'Four' }
    ThenPackageDeployed -AtUri 'https://buildmaster.example.com' -UsingApiKey 'fubarsnafu'
}

Describe 'Publish-WhiskeyBuildMasterPackage.when creating package with defined name' {
    $packageNameOverride = 'PackageABCD'
    Init
    GivenPackageName $packageNameOverride
    GivenProperty $packageVariable
    WhenCreatingPackage
    ThenCreatedPackage $packageNameOverride -InRelease 'release' -ForApplication 'application' -AtUri 'https://buildmaster.example.com' -UsingApiKey 'fubarsnafu' -WithVariables @{ One = 'Two'; Three = 'Four' }
    ThenPackageDeployed -AtUri 'https://buildmaster.example.com' -UsingApiKey 'fubarsnafu'
}

Describe 'Publish-WhiskeyBuildMasterPackage.when deploying release package to specific stage' {
    $releaseStage = 'Test'
    Init
    GivenStartAtStage $releaseStage
    GivenProperty $packageVariable
    WhenCreatingPackage
    ThenCreatedPackage '9.8.3' -InRelease 'release' -ForApplication 'application' -AtUri 'https://buildmaster.example.com' -UsingApiKey 'fubarsnafu' -WithVariables @{ One = 'Two'; Three = 'Four' }
    ThenPackageDeployed -AtUri 'https://buildmaster.example.com' -UsingApiKey 'fubarsnafu' -AtStage $releaseStage
}

Describe 'Publish-WhiskeyBuildMasterPackage.when creating package without starting deployment' {
    Init
    GivenSkipDeploy
    GivenProperty $packageVariable
    WhenCreatingPackage
    ThenCreatedPackage '9.8.3' -InRelease 'release' -ForApplication 'application' -AtUri 'https://buildmaster.example.com' -UsingApiKey 'fubarsnafu' -WithVariables @{ One = 'Two'; Three = 'Four' }
    ThenPackageNotDeployed
}

Describe 'Publish-WhiskeyBuildMasterPackage.when no application or release in BuildMaster' {
    Init
    GivenNoRelease 'release' -ForApplication 'application'
    WhenCreatingPackage -ErrorAction SilentlyContinue
    ThenPackageNotCreated
    ThenTaskFails 'unable\ to\ create\ and\ deploy\ a\ release\ package'
}

Describe ('Publish-WhiskeyBuildMasterPackage.when ApplicationName property is missing') {
    Init
    GivenNoApplicationName
    WhenCreatingPackage -ErrorAction SilentlyContinue
    ThenPackageNotCreated
    ThenTaskFails ('\bApplicationName\b.*\bmandatory\b')
}

Describe ('Publish-WhiskeyBuildMasterPackage.when ReleaseName property is missing') {
    Init
    GivenNoReleaseName
    WhenCreatingPackage -ErrorAction SilentlyContinue
    ThenPackageNotCreated
    ThenTaskFails ('\bReleaseName\b.*\bmandatory\b')
}

Describe ('Publish-WhiskeyBuildMasterPackage.when Uri property is missing') {
    Init
    GivenNoUri
    WhenCreatingPackage -ErrorAction SilentlyContinue
    ThenPackageNotCreated
    ThenTaskFails ('\bUri\b.*\bmandatory\b')
}

Describe ('Publish-WhiskeyBuildMasterPackage.when ApiKeyID property is missing') {
    Init
    GivenNoApiKey
    WhenCreatingPackage -ErrorAction SilentlyContinue
    ThenPackageNotCreated
    ThenTaskFails ('\bApiKeyID\b.*\bmandatory\b')
}
