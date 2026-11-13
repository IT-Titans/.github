#Requires -Version 7.4
<#
.SYNOPSIS
    Runs the inline scripts of the reusable workflows against known inputs and
    checks a few rules on the files of this repository.

.DESCRIPTION
    The reusable workflows cannot be run outside GitHub, but their logic sits in
    inline PowerShell that takes all input from environment variables. This
    script reads those blocks out of the workflow files and runs each one the
    way the runner does, once per case.

    Every check has cases that must fail. A gate that has only ever been seen
    passing proves nothing: a required check once passed here because the pull
    request template carried an example that satisfied it.

    The step scripts are read with a small reader for "run: |" blocks, not with
    a YAML parser, so that the tests need nothing but PowerShell. The reader
    fails loudly when a step is renamed or its script is not a literal block.

.EXAMPLE
    pwsh ./tests/Test-WorkflowScripts.ps1

.EXAMPLE
    pwsh ./tests/Test-WorkflowScripts.ps1 -ShowOutput
#>
[CmdletBinding()]
param(
    # Print the output of every step script, not only of the deviating ones.
    [switch] $ShowOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repository = Split-Path -Parent $PSScriptRoot
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$titleWorkflow = Join-Path $repository '.github/workflows/conventional-pr-title.yml'
$dotnetWorkflow = Join-Path $repository '.github/workflows/dotnet-ci.yml'

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-script-tests-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null

$results = [System.Collections.Generic.List[object]]::new()

function Get-StepScript {
    <# Returns the text of the "run: |" block of the named step. #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $StepName
    )

    $lines = @(Get-Content -LiteralPath $Path)
    $indentOf = { param($line) $line.Length - $line.TrimStart(' ').Length }

    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*- name:\s*(.+?)\s*$' -and $Matches[1] -ceq $StepName) {
            $start = $i
            break
        }
    }

    if ($start -lt 0) {
        throw "No step named '$StepName' in $Path."
    }

    $stepIndent = & $indentOf $lines[$start]

    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^\s*- ' -and (& $indentOf $line) -le $stepIndent) {
            break
        }

        if ($line -notmatch '^\s*run:\s*\|\s*$') {
            continue
        }

        $runIndent = & $indentOf $line
        $body = [System.Collections.Generic.List[string]]::new()

        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            $candidate = $lines[$j]

            if ($candidate.Trim().Length -eq 0) {
                $body.Add('')
                continue
            }

            if ((& $indentOf $candidate) -le $runIndent) {
                break
            }

            $body.Add($candidate)
        }

        while ($body.Count -gt 0 -and $body[$body.Count - 1] -eq '') {
            $body.RemoveAt($body.Count - 1)
        }

        if ($body.Count -eq 0) {
            throw "The run block of step '$StepName' in $Path is empty."
        }

        $blockIndent = & $indentOf ($body | Where-Object { $_ } | Select-Object -First 1)
        $text = foreach ($entry in $body) {
            if ($entry) { $entry.Substring($blockIndent) } else { '' }
        }

        return ($text -join "`n") + "`n"
    }

    throw "The step '$StepName' in $Path has no 'run: |' block."
}

function Invoke-StepScript {
    <#
        Runs a step script in a child process the way the runner does for
        "shell: pwsh": the script is saved to a file, prefixed with the error
        preference and followed by the propagation of the last exit code.
    #>
    param(
        [Parameter(Mandatory)] [string] $Script,
        [hashtable] $Environment = @{},
        [string] $WorkingDirectory = $scratch
    )

    $file = Join-Path $scratch ([guid]::NewGuid().ToString('N') + '.ps1')
    $wrapped = "`$ErrorActionPreference = 'stop'`n" + $Script + "`nif ((Test-Path -LiteralPath variable:\LASTEXITCODE)) { exit `$LASTEXITCODE }`n"
    Set-Content -LiteralPath $file -Value $wrapped -Encoding utf8 -NoNewline

    $summaryFile = Join-Path $scratch ([guid]::NewGuid().ToString('N') + '.summary.md')
    $all = @{ GITHUB_STEP_SUMMARY = $summaryFile } + $Environment

    $previous = @{}
    foreach ($name in $all.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name, [string] $all[$name])
    }

    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = & pwsh -NoProfile -NonInteractive -Command ". '$file'" 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
        foreach ($name in $previous.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previous[$name])
        }
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output
        Summary  = if (Test-Path -LiteralPath $summaryFile) { Get-Content -LiteralPath $summaryFile -Raw } else { '' }
    }
}

function Add-Result {
    param([string] $Group, [string] $Case, [bool] $Passed, [string] $Detail = '')

    $results.Add([pscustomobject]@{ Group = $Group; Case = $Case; Passed = $Passed; Detail = $Detail })
}

function Test-Step {
    <#
        Runs one case and records whether the step ended as expected. -Expect is
        'pass' or 'fail'; -OutputPattern must match the output as well.
    #>
    param(
        [Parameter(Mandatory)] [string] $Group,
        [Parameter(Mandatory)] [string] $Case,
        [Parameter(Mandatory)] [string] $Script,
        [Parameter(Mandatory)] [ValidateSet('pass', 'fail')] [string] $Expect,
        [hashtable] $Environment = @{},
        [string] $WorkingDirectory = $scratch,
        [string] $OutputPattern
    )

    $run = Invoke-StepScript -Script $Script -Environment $Environment -WorkingDirectory $WorkingDirectory
    $ended = if ($run.ExitCode -eq 0) { 'pass' } else { 'fail' }

    $passed = $ended -eq $Expect
    $detail = "expected $Expect, step ended as $ended (exit code $($run.ExitCode))"

    if ($passed -and $OutputPattern -and $run.Output -notmatch $OutputPattern) {
        $passed = $false
        $detail = "output does not match /$OutputPattern/"
    }

    Add-Result -Group $Group -Case $Case -Passed $passed -Detail $detail

    if ($ShowOutput -or -not $passed) {
        Write-Host "--- $Group / $Case"
        Write-Host $run.Output.TrimEnd()
    }
}

try {
    # --- Pull request title ---------------------------------------------------

    $titleScript = Get-StepScript -Path $titleWorkflow -StepName 'Check the pull request title'
    $defaultTypes = 'build chore ci docs feat fix perf refactor revert style test'

    $titles = [ordered]@{
        'feat: add a rule for stale connections'  = 'pass'
        'fix(parser): handle an empty name'       = 'pass'
        'feat!: drop the legacy export'           = 'pass'
        'refactor(api)!: rename the endpoint'     = 'pass'
        'docs: update the README'                 = 'pass'
        'chore(deps): bump xunit from 2.9 to 3.0' = 'pass'
        'Add a rule for stale connections'        = 'fail'
        'Feat: add a rule'                        = 'fail'
        'feat:add a rule'                         = 'fail'
        'feat:  add a rule'                       = 'fail'
        'feat: '                                  = 'fail'
        'feat'                                    = 'fail'
        'feat(): add a rule'                      = 'fail'
        'feat (api): add a rule'                  = 'fail'
        'feature: add a rule'                     = 'fail'
        'wip: try something'                      = 'fail'
        'Merge branch main into feature'          = 'fail'
        '::error::feat: add a rule'               = 'fail'
        ' feat: leading space'                    = 'fail'
        ''                                        = 'fail'
    }

    foreach ($title in $titles.Keys) {
        $label = if ($title) { $title } else { '(empty title)' }
        Test-Step -Group 'title' -Case $label -Script $titleScript -Expect $titles[$title] `
            -Environment @{ PR_TITLE = $title; ALLOWED_TYPES = $defaultTypes }
    }

    Test-Step -Group 'title' -Case 'type outside a narrowed list' -Script $titleScript -Expect 'fail' `
        -Environment @{ PR_TITLE = 'chore: tidy up'; ALLOWED_TYPES = 'feat fix' } -OutputPattern 'is not one of: feat, fix'
    Test-Step -Group 'title' -Case 'empty list of types' -Script $titleScript -Expect 'fail' `
        -Environment @{ PR_TITLE = 'feat: add a rule'; ALLOWED_TYPES = '' }

    # --- Coverage minimum -----------------------------------------------------

    $gateScript = Get-StepScript -Path $dotnetWorkflow -StepName 'Enforce the coverage minimum'

    $gateCases = @(
        @{ Case = 'total and assemblies above the minimum'; Report = 'coverage-pass.xml'; Minimum = '90'; Expect = 'pass' }
        @{ Case = 'one assembly below, total above'; Report = 'coverage-assembly-below.xml'; Minimum = '90'; Expect = 'fail'; Pattern = 'Sample\.Beta is at 68\.50 %, below the required 90 %' }
        @{ Case = 'same report with a lower minimum'; Report = 'coverage-assembly-below.xml'; Minimum = '60'; Expect = 'pass' }
        @{ Case = 'total below the minimum'; Report = 'coverage-total-below.xml'; Minimum = '90'; Expect = 'fail'; Pattern = 'TOTAL is at 89\.00 %' }
        @{ Case = 'exactly at the minimum'; Report = 'coverage-at-minimum.xml'; Minimum = '90'; Expect = 'pass' }
        @{ Case = 'fractional minimum above the rate'; Report = 'coverage-at-minimum.xml'; Minimum = '90.5'; Expect = 'fail'; Pattern = 'below the required 90\.5 %' }
        @{ Case = 'line rate is not a number'; Report = 'coverage-not-a-number.xml'; Minimum = '90'; Expect = 'fail'; Pattern = 'Sample\.Contracts has no line rate' }
        @{ Case = 'report without assemblies'; Report = 'coverage-no-assemblies.xml'; Minimum = '90'; Expect = 'fail'; Pattern = 'lists no assemblies' }
        @{ Case = 'report file missing'; Report = 'does-not-exist.xml'; Minimum = '90'; Expect = 'fail'; Pattern = 'No merged coverage report' }
        @{ Case = 'required assemblies all present'; Report = 'coverage-pass.xml'; Minimum = '90'; Required = 'Sample.Alpha, Sample.Beta'; Expect = 'pass' }
        @{ Case = 'required assembly missing'; Report = 'coverage-pass.xml'; Minimum = '90'; Required = "Sample.Alpha`nSample.Ui"; Expect = 'fail'; Pattern = 'Sample\.Ui is missing from the coverage report' }
    )

    foreach ($case in $gateCases) {
        $environment = @{
            REPORT_PATH         = Join-Path $fixtures $case.Report
            MINIMUM             = $case.Minimum
            REQUIRED_ASSEMBLIES = if ($case.ContainsKey('Required')) { $case.Required } else { '' }
        }

        $pattern = if ($case.ContainsKey('Pattern')) { $case.Pattern } else { '' }
        Test-Step -Group 'coverage' -Case $case.Case -Script $gateScript -Expect $case.Expect -Environment $environment -OutputPattern $pattern
    }

    # --- Coverage settings ----------------------------------------------------

    $settingsScript = Get-StepScript -Path $dotnetWorkflow -StepName 'Check the coverage settings'

    Test-Step -Group 'settings' -Case 'generated code excluded, compiler-generated kept' -Script $settingsScript -Expect 'pass' `
        -Environment @{ RUNSETTINGS = Join-Path $fixtures 'settings-ok.runsettings' }
    Test-Step -Group 'settings' -Case 'CompilerGeneratedAttribute excluded' -Script $settingsScript -Expect 'fail' `
        -Environment @{ RUNSETTINGS = Join-Path $fixtures 'settings-compiler-generated.runsettings' } -OutputPattern 'async state machine'
    Test-Step -Group 'settings' -Case 'runsettings file missing' -Script $settingsScript -Expect 'fail' `
        -Environment @{ RUNSETTINGS = Join-Path $fixtures 'does-not-exist.runsettings' } -OutputPattern 'does not exist'

    # --- Toolchain pin --------------------------------------------------------

    $pinScript = Get-StepScript -Path $dotnetWorkflow -StepName 'Check the toolchain pin'

    $withPin = Join-Path $scratch 'with-global-json'
    $withoutPin = Join-Path $scratch 'without-global-json'
    New-Item -ItemType Directory -Path $withPin, $withoutPin | Out-Null
    Set-Content -LiteralPath (Join-Path $withPin 'global.json') -Value '{ "sdk": { "version": "10.0.100", "rollForward": "latestFeature" } }'

    Test-Step -Group 'toolchain' -Case 'global.json present' -Script $pinScript -Expect 'pass' `
        -Environment @{ DOTNET_VERSION_INPUT = '' } -WorkingDirectory $withPin
    Test-Step -Group 'toolchain' -Case 'no global.json, no version input' -Script $pinScript -Expect 'fail' `
        -Environment @{ DOTNET_VERSION_INPUT = '' } -WorkingDirectory $withoutPin -OutputPattern 'Pin the SDK'
    Test-Step -Group 'toolchain' -Case 'no global.json, version input given' -Script $pinScript -Expect 'pass' `
        -Environment @{ DOTNET_VERSION_INPUT = '10.0.x' } -WorkingDirectory $withoutPin

    # --- Rules on the files of this repository ----------------------------------

    $workflowFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $repository '.github/workflows') -Filter '*.yml'
        Get-ChildItem -LiteralPath (Join-Path $repository 'workflow-templates') -Filter '*.yml' -ErrorAction SilentlyContinue
    )

    foreach ($file in $workflowFiles) {
        $name = [System.IO.Path]::GetRelativePath($repository, $file.FullName) -replace '\\', '/'
        $lines = @(Get-Content -LiteralPath $file.FullName)

        # Every action and every reusable workflow from another repository is
        # pinned to a full commit SHA, with the version as a trailing comment.
        $unpinned = @(
            $lines | Where-Object { $_ -match '^\s*(-\s*)?uses:\s*(\S+)' } | Where-Object {
                $reference = ($_ -replace '^\s*(-\s*)?uses:\s*', '')
                $reference -notmatch '^\./' -and $reference -notmatch '^[^@\s]+@[0-9a-f]{40}\s+#\s*v\d+\.\d+\.\d+\s*$'
            }
        )
        Add-Result -Group 'files' -Case "$name pins every action to a commit SHA with a version comment" `
            -Passed ($unpinned.Count -eq 0) -Detail (($unpinned | ForEach-Object { $_.Trim() }) -join '; ')

        # The token starts read-only for the whole workflow.
        $text = $lines -join "`n"
        Add-Result -Group 'files' -Case "$name sets top-level permissions to contents: read" `
            -Passed ($text -match '(?m)^permissions:\n  contents: read\n(?!  \S)')

        # No expression inside a script: an input written into script text can
        # carry code. Inputs reach scripts through environment variables.
        $inRun = $false
        $runIndent = 0
        $interpolated = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $lines) {
            $indent = $line.Length - $line.TrimStart(' ').Length
            if ($inRun -and $line.Trim().Length -gt 0 -and $indent -le $runIndent) {
                $inRun = $false
            }

            if ($inRun -and $line -match '\$\{\{') {
                $interpolated.Add($line.Trim())
            }

            if ($line -match '^\s*run:') {
                if ($line -match '\$\{\{') { $interpolated.Add($line.Trim()) }
                $inRun = $true
                $runIndent = $indent
            }
        }
        Add-Result -Group 'files' -Case "$name has no expression inside a script" `
            -Passed ($interpolated.Count -eq 0) -Detail ($interpolated -join '; ')
    }

    # Every starter has a metadata file that parses and carries the two required
    # keys. GitHub does not offer a starter whose metadata it cannot read.
    $templates = Join-Path $repository 'workflow-templates'
    foreach ($starter in @(Get-ChildItem -LiteralPath $templates -Filter '*.yml' -ErrorAction SilentlyContinue)) {
        $metadata = Join-Path $templates ($starter.BaseName + '.properties.json')
        $valid = $false
        $detail = 'metadata file missing'

        if (Test-Path -LiteralPath $metadata -PathType Leaf) {
            try {
                $parsed = Get-Content -LiteralPath $metadata -Raw | ConvertFrom-Json -AsHashtable
                $valid = [bool] $parsed['name'] -and [bool] $parsed['description']
                $detail = 'name or description missing'
            }
            catch {
                $detail = $_.Exception.Message
            }
        }

        Add-Result -Group 'files' -Case "workflow-templates/$($starter.Name) has readable metadata" -Passed $valid -Detail $detail
    }

    # The pull request template must not contain text that could satisfy a check
    # on its own: no issue reference, no closing keyword, no ticked box, no
    # line shaped like a Conventional Commit.
    $template = Get-Content -LiteralPath (Join-Path $repository '.github/pull_request_template.md') -Raw
    $forbidden = [ordered]@{
        'an issue or pull request number'  = '#\d'
        'a link to an issue or pull request' = '(?i)/(issues|pull)/\d'
        'a closing keyword'                = '(?i)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\b'
        'a ticked checkbox'                = '\[[xX]\]'
        'a line shaped like a Conventional Commit' = '(?m)^\s*[a-z]+(\([^)]*\))?!?: \S'
    }

    foreach ($entry in $forbidden.GetEnumerator()) {
        Add-Result -Group 'files' -Case "pull request template contains no text that reads as $($entry.Key)" `
            -Passed ($template -notmatch $entry.Value)
    }
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Report -------------------------------------------------------------------

$results | ForEach-Object {
    $mark = if ($_.Passed) { 'ok  ' } else { 'FAIL' }
    $line = '{0}  {1,-10} {2}' -f $mark, $_.Group, $_.Case
    if (-not $_.Passed -and $_.Detail) {
        $line += "  [$($_.Detail)]"
    }
    Write-Host $line
}

$deviations = @($results | Where-Object { -not $_.Passed })
Write-Host ''
Write-Host "$($results.Count) checks, $($deviations.Count) deviations."

if ($deviations.Count -gt 0) {
    exit 1
}
