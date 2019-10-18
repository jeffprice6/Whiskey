
#Requires -Version 5.1
Set-StrictMode -Version 'Latest'

& (Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-WhiskeyTest.ps1' -Resolve)

$failed = $false
$secret = $null
$secretID = $null
$whiskeyYml = $null
[object[]]$jobs = $null
$nextID = 10000000
$currentJobID = $null
$runByAppVeyor = $null
$latestBuildID = $null

function Get-NextID
{
    $ID = $nextID
    $script:nextID++
    return $ID
}

function GivenJob
{
    param(
        [int]$WithID,

        [Parameter(Mandatory,ParameterSetName='ForNotCurrentJob')]
        [string]$WithStatus,

        [Parameter(Mandatory,ParameterSetName='ForNotCurrentJob')]
        [int]$ThatFinishesAtCheck,

        [Parameter(Mandatory,ParameterSetName='CurrentJob')]
        [Switch]$Current,

        [Parameter(Mandatory,ParameterSetName='ForNotCurrentJob')]
        [string]$WithFinalStatus,

        [Parameter(ParameterSetName='ForNotCurrentJob')]
        [switch]$ThatHasFinishedProperty
    )

    $script:jobs = & {
        if( $jobs )
        {
            Write-Output $jobs
        }

        if( $WithID )
        {
            $jobID = $WithID
        }
        else
        {
            $jobID = Get-NextID
        }

        if( $Current )
        {
            $script:currentJobID = $jobID
        }

        $job = [pscustomobject]@{ 
            'name' = ('job{0}' -f $jobID)
            'jobId' = $jobID;
            'status' = $WithStatus;
            'checks' = $ThatFinishesAtCheck;
            'finalStatus' = $WithFinalStatus;
        } 

        if( $ThatHasFinishedProperty )
        {
            $job | Add-Member -Name 'finished' -MemberType 'NoteProperty' -Value $null
        }
        Write-Output $job
    }
}

function GivenLatestBuildIDIsNotThisBuild
{
    param(

    )

    $script:latestBuildID = Get-NextID
}
function GivenRunBy
{
    param(
        [Parameter(Mandatory,ParameterSetName='Developer')]
        [switch]$Developer,

        [Parameter(Mandatory,ParameterSetName='AppVeyor')]
        [switch]$AppVeyor
    )

    $script:runByAppVeyor = $AppVeyor
}

function GivenSecret
{
    param(
        [Parameter(Mandatory)]
        [string]$Secret,

        [Parameter(Mandatory)]
        [string]$WithID
    )

    $script:secret = $Secret
    $script:secretID = $WithID
}

function GivenWhiskeyYml
{
    param(
        $Value
    )

    $script:whiskeyYml = $Value 
}

function Init
{
    $script:failed = $false
    $script:testRoot = $TestDrive.FullName
    $script:secret = $null
    $script:secretID = $null
    $script:whiskeyYml = $null
    $script:jobs = $null
    $script:currentJobID = $null
    $script:runByAppVeyor = $null
    $script:latestBuildID = $null
    Remove-Item -Path (JOin-Path -Path $testRoot -ChildPath 'whiskey.yml') -ErrorAction Ignore
}

function ThenCheckedStatus
{
    param(
        [int]$Times,
        [switch]$Exactly
    )

    Assert-MockCalled -CommandName 'Invoke-RestMethod' -ModuleName 'Whiskey' -Times $Times -Exactly:$Exactly

    $secret = $script:secret
    Assert-MockCalled -CommandName 'Invoke-RestMethod' `
                      -ModuleName 'Whiskey' `
                      -ParameterFilter { 
                            $Headers['Authorization'] | 
                                Should -Be ('Bearer {0}' -f $secret) `
                                       -Because 'Invoke-RestMethod should be passed authorization header' 
                            $PSBoundParameters['Verbose'] | Should -Not -BeNullOrEmpty -Because 'should not show Invoke-RestMethod verbose output'
                            $PSBoundParameters['Verbose'] | Should -BeFalse -Because 'should not show Invoke-RestMethod verbose output'
                            return $true
                        } `
                      -Times $Times `
                      -Exactly
}

function ThenFails
{
    $failed | Should -BeTrue
}

function ThenSucceeds
{
    $failed | Should -BeFalse
}

function WhenRunningTask
{
    [CmdletBinding()]
    param(
    )

    $Global:Error.Clear()
    $context = New-WhiskeyTestContext -ForBuildServer -ForBuildRoot $testRoot -ForYaml $whiskeyYml
    if( $secretID -and $secret )
    {
        Add-WhiskeyApiKey -Context $context -ID $secretID -Value $secret
    }

    $runByAppVeyor = $script:runByAppVeyor
    Mock -CommandName 'Test-Path' `
         -ModuleName 'Whiskey' `
         -Parameter { $Path -eq 'env:APPVEYOR' } `
         -MockWith { $runByAppVeyor }.GetNewClosure()

    Mock -CommandName 'Get-Item' `
         -ModuleName 'Whiskey' `
         -ParameterFilter { $Path -eq 'env:APPVEYOR_ACCOUNT_NAME' } `
         -MockWith { [pscustomobject]@{ Value = 'Fubar-Snafu' } }

    Mock -CommandName 'Get-Item' `
         -ModuleName 'Whiskey' `
         -ParameterFilter { $Path -eq 'env:APPVEYOR_PROJECT_SLUG' } `
         -MockWith { [pscustomobject]@{ Value = 'Ewwwww' } }
    
    $buildID = Get-NextID
    Mock -CommandName 'Get-Item' `
         -ModuleName 'Whiskey' `
         -ParameterFilter { $Path -eq 'env:APPVEYOR_BUILD_ID' } `
         -MockWith { [pscustomobject]@{ Value = $buildID } }.GetNewClosure()

    $currentJobID = $script:currentJobID
    Mock -CommandName 'Get-Item' `
         -ModuleName 'Whiskey' `
         -ParameterFilter { $Path -eq 'env:APPVEYOR_JOB_ID' } `
         -MockWith { [pscustomobject]@{ Value = $currentJobID } }.GetNewClosure()

    if( -not $latestBuildID )
    {
        $latestBuildID = $buildID
    }

    $project = [pscustomobject]@{
        'project' = [pscustomobject]@{};
        'build' = [pscustomobject]@{
            'buildId' = $latestBuildID;
            'buildNumber' = (Get-NextID);
            'status' = 'running';
            'jobs' = $jobs;
        }
    }

    $Global:CheckNum = $null
    Mock -CommandName 'Invoke-RestMethod' `
         -ModuleName 'Whiskey' `
         -ParameterFilter { $Uri -eq 'https://ci.appveyor.com/api/projects/Fubar-Snafu/Ewwwww' } `
         -MockWith { 

             function Write-Timing
             {
                param(
                    $Message
                )
                $DebugPreference = 'Continue'
                $now = (Get-Date).ToString('HH:mm:ss.ff')
                Write-Debug ('[{0,2}]  [{1}]  {2}' -f $CheckNum,$now,$Message)
             }

             ++$Global:CheckNum
             Write-Timing ('Invoke-RestMethod')

             foreach( $job in $project.build.jobs )
             {
                if( $job.jobID -eq $currentJobID )
                {
                    continue
                }

                if( $CheckNum -lt $job.checks )
                {
                    Write-Timing ('[{0}]  < {1}' -f $job.name,$job.checks)
                    continue
                }

                if( -not ($job | Get-Member 'finished') )
                {
                    Write-Timing ('[{0}]  Adding "finished" property.' -f $job.name)
                    Add-Member -InputObject $job -Name 'finished' -MemberType 'NoteProperty' -Value ((Get-Date).ToString('s'))
                }

                if( $job.status -ne $job.finalStatus )
                {
                    Write-Timing ('[{0}]  Setting final status to "{1}".' -f $job.name,$job.finalStatus)
                    $job.status = $job.finalStatus
                }
            }
            return $project
        }.GetNewClosure()

    $script:failed = $false
    try
    {
        $parameter = @{}
        $task = $context.Configuration['Build'][0]
        if( $task -isnot [string] )
        {
            $parameter = $task['AppVeyorWaitForBuildJobs']
        }
        
        Invoke-WhiskeyTask -TaskContext $context -Name 'AppVeyorWaitForBuildJobs' -Parameter $parameter
    }
    catch
    {
        $script:failed = $true
        Write-Error -ErrorRecord $_
    }
    finally
    {
        Remove-Variable -Name 'CheckNum' -Scope 'Global'
    }
}

Describe 'AppVeyorWaitForBuildJobs.when there is only one job' {
    It 'should immediately finish' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
'@
        GivenJob -Current 
        WhenRunningTask
        ThenSucceeds
        ThenCheckedStatus -Times 1 -Exactly
    }
}

Describe 'AppVeyorWaitForBuildJobs.when there are two jobs' {
    It 'should wait for second job to finish' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
'@
        GivenJob -WithStatus 'running' -ThatFinishesAtCheck 2 -WithFinalStatus 'success'
        GivenJob -Current 
        WhenRunningTask
        ThenSucceeds
        ThenCheckedStatus -Times 2 
    }
}

Describe 'AppVeyorWaitForBuildJobs.when there are three jobs and one job takes awhile' {
    It 'should wait for all jobs to finish' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
    ReportInterval: 00:00:00.1
'@
        GivenJob -WithStatus 'running' -ThatFinishesAtCheck 2 -WithFinalStatus 'success'
        GivenJob -Current 
        GivenJob -WithStatus 'running' -ThatFinishesAtCheck 10 -WithFinalStatus 'success'
        WhenRunningTask
        ThenSucceeds
        ThenCheckedStatus -Times 10 
    }
}

Describe 'AppVeyorWaitForBuildJobs.when AppVeyor eventually always includes a finished property even when job is not finished' {
    It 'should pass' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
'@
        GivenJob -WithStatus 'running' -ThatFinishesAtCheck 2 -WithFinalStatus 'success' -ThatHasFinishedProperty
        GivenJob -Current 
        WhenRunningTask
        ThenSucceeds
        ThenCheckedStatus -Times 2
    }
}

Describe 'AppVeyorWaitForBuildJobs.when other jobs fail' {
    It 'should fail' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
'@
        GivenJob -WithID 4380 -WithStatus 'running' -ThatFinishesAtCheck 2 -WithFinalStatus 'failed' -ThatHasFinishedProperty
        GivenJob -WithID 4381 -WithStatus 'running' -ThatFinishesAtCheck 2 -WithFinalStatus 'failed' -ThatHasFinishedProperty
        GivenJob -Current 
        WhenRunningTask -ErrorAction SilentlyContinue
        ThenFails
        $Global:Error | Where-Object { $_ -match '\ \* job4380 \(status: failed\)' } | Should -Not -BeNullOrEmpty
        $Global:Error | Where-Object { $_ -match '\ \* job4381 \(status: failed\)' } | Should -Not -BeNullOrEmpty
        ThenCheckedStatus -Times 2
    }
}

Describe 'AppVeyorWaitForBuildJobs.when not running under AppVeyor' {
    It 'should fail' {
        Init
        GivenRunBy -Developer
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
'@
        GivenJob -Current 
        WhenRunningTask -ErrorAction SilentlyContinue
        ThenFails
        $Global:Error | Should -Match 'Not\ running\ under\ AppVeyor'
        ThenCheckedStatus -Times 0
    }
}

Describe 'AppVeyorWaitForBuildJobs.when customizing in-progress status indicators' {
    It 'should continue checking while job has custom status' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
    InProgressStatus: nerfherder
'@
        GivenJob -WithStatus 'nerfherder' -ThatFinishesAtCheck 2 -WithFinalStatus 'success' -ThatHasFinishedProperty
        GivenJob -Current 
        WhenRunningTask
        ThenSucceeds
        ThenCheckedStatus -Times 2
    }
}

Describe 'AppVeyorWaitForBuildJobs.when customizing success status indicators' {
    It 'should continue checking while job has custom status' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
    SuccessStatus: failed
'@
        GivenJob -WithStatus 'queued' -ThatFinishesAtCheck 2 -WithFinalStatus 'failed' -ThatHasFinishedProperty
        GivenJob -Current 
        WhenRunningTask
        ThenSucceeds
        ThenCheckedStatus -Times 2
    }
}

Describe 'AppVeyorWaitForBuildJobs.when another build starts after this one' {
    It 'should fail current build' {
        Init
        GivenRunBy -AppVeyor
        GivenSecret 'fubarsnafu' -WithID 'AppVeyor'
        GivenWhiskeyYml @'
Build:
- AppVeyorWaitForBuildJobs:
    ApiKeyID: AppVeyor
    CheckInterval: 00:00:00.1
'@
        GivenJob -WithStatus 'queued' -ThatFinishesAtCheck 2 -WithFinalStatus 'failed' -ThatHasFinishedProperty
        GivenJob -Current 
        GivenLatestBuildIDIsNotThisBuild
        WhenRunningTask -ErrorAction SilentlyContinue
        ThenFails
        $Global:Error | Should -Match 'unable to wait'
        ThenCheckedStatus -Times 1 -Exactly
    }
}