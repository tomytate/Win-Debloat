<#
.SYNOPSIS
    AST 5-Way Parity Assertion Engine for Win-Debloat.
.DESCRIPTION
    Performs pure static Abstract Syntax Tree (AST) analysis on all .psm1 files in src/
    and Win-Debloat.psd1 to mathematically prove 100% parity across:
      1. Defined FunctionDefinitionAst names in .psm1
      2. Export-ModuleMember -Function arrays in .psm1
      3. FunctionsToExport array in Win-Debloat.psd1
      4. Export-ModuleMember -Alias / Set-Alias arrays in .psm1
      5. AliasesToExport array in Win-Debloat.psd1
.OUTPUTS
    Exit code 0 on 100% mathematical parity; 1 on any parity mismatch.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

function Get-AstStringValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.Ast]$AstNode
    )

    $values = [System.Collections.Generic.List[string]]::new()

    try {
        if ($AstNode.PSObject.Methods['SafeGetValue']) {
            $safeVal = $AstNode.SafeGetValue()
            if ($null -ne $safeVal) {
                if ($safeVal -is [System.Collections.IEnumerable] -and $safeVal -isnot [string]) {
                    foreach ($item in $safeVal) {
                        if ($null -ne $item -and [string]::IsNullOrWhiteSpace("$item") -eq $false) {
                            $values.Add("$item")
                        }
                    }
                    return [string[]]$values.ToArray()
                }
                elseif (-not [string]::IsNullOrWhiteSpace("$safeVal")) {
                    $values.Add("$safeVal")
                    return [string[]]$values.ToArray()
                }
            }
        }
    }
    catch {
    }

    if ($AstNode -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        $values.Add($AstNode.Value)
    }
    elseif ($AstNode -is [System.Management.Automation.Language.ArrayLiteralAst]) {
        foreach ($elem in $AstNode.Elements) {
            $values.AddRange([string[]](Get-AstStringValues -AstNode $elem))
        }
    }
    elseif ($AstNode -is [System.Management.Automation.Language.ArrayExpressionAst]) {
        if ($AstNode.SubExpression -and $AstNode.SubExpression.Statements) {
            foreach ($stmt in $AstNode.SubExpression.Statements) {
                if ($stmt -is [System.Management.Automation.Language.PipelineAst]) {
                    foreach ($pipeElem in $stmt.PipelineElements) {
                        if ($pipeElem -is [System.Management.Automation.Language.CommandExpressionAst]) {
                            $values.AddRange([string[]](Get-AstStringValues -AstNode $pipeElem.Expression))
                        }
                    }
                }
            }
        }
    }
    elseif ($AstNode -is [System.Management.Automation.Language.ParenExpressionAst]) {
        $values.AddRange([string[]](Get-AstStringValues -AstNode $AstNode.SubExpression))
    }

    return [string[]]$values.ToArray()
}

function Get-ExportModuleMemberExports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.ScriptBlockAst]$Ast
    )

    $exportedFunctions = [System.Collections.Generic.List[string]]::new()
    $exportedAliases   = [System.Collections.Generic.List[string]]::new()

    $commands = $Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Export-ModuleMember'
    }, $true)

    foreach ($cmd in $commands) {
        $elements = $cmd.CommandElements
        $currentParam = $null

        for ($i = 1; $i -lt $elements.Count; $i++) {
            $elem = $elements[$i]
            if ($elem -is [System.Management.Automation.Language.CommandParameterAst]) {
                $paramName = $elem.ParameterName
                if ($elem.Argument) {
                    $vals = [string[]](Get-AstStringValues -AstNode $elem.Argument)
                    if ($paramName -like 'F*') { foreach ($v in $vals) { $exportedFunctions.Add($v) } }
                    elseif ($paramName -like 'A*') { foreach ($v in $vals) { $exportedAliases.Add($v) } }
                }
                else {
                    $currentParam = $paramName
                }
            }
            else {
                $vals = [string[]](Get-AstStringValues -AstNode $elem)
                if ($null -eq $currentParam -or $currentParam -like 'F*') {
                    foreach ($v in $vals) { $exportedFunctions.Add($v) }
                }
                elseif ($currentParam -like 'A*') {
                    foreach ($v in $vals) { $exportedAliases.Add($v) }
                }
            }
        }
    }

    return @{
        Functions = [string[]]($exportedFunctions | Sort-Object -Unique)
        Aliases   = [string[]]($exportedAliases | Sort-Object -Unique)
    }
}

function Get-SetAliasExports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.ScriptBlockAst]$Ast
    )

    $aliases = [System.Collections.Generic.List[string]]::new()

    $commands = $Ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        ($node.GetCommandName() -eq 'Set-Alias' -or $node.GetCommandName() -eq 'New-Alias')
    }, $true)

    foreach ($cmd in $commands) {
        $elements = $cmd.CommandElements
        for ($i = 1; $i -lt $elements.Count; $i++) {
            $elem = $elements[$i]
            if ($elem -is [System.Management.Automation.Language.CommandParameterAst]) {
                if ($elem.ParameterName -like 'N*') {
                    if ($elem.Argument) {
                        $vals = [string[]](Get-AstStringValues -AstNode $elem.Argument)
                        foreach ($v in $vals) { $aliases.Add($v) }
                    }
                    elseif ($i + 1 -lt $elements.Count) {
                        $nextElem = $elements[$i + 1]
                        if ($nextElem -isnot [System.Management.Automation.Language.CommandParameterAst]) {
                            $vals = [string[]](Get-AstStringValues -AstNode $nextElem)
                            foreach ($v in $vals) { $aliases.Add($v) }
                            $i++
                        }
                    }
                }
            }
            elseif ($i -eq 1) {
                $vals = [string[]](Get-AstStringValues -AstNode $elem)
                foreach ($v in $vals) { $aliases.Add($v) }
            }
        }
    }

    return [string[]]($aliases | Sort-Object -Unique)
}

function Parse-Psd1ManifestAst {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Psd1Path
    )

    $raw = Get-Content -LiteralPath $Psd1Path -Raw -ErrorAction Stop
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($raw, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        throw "PSD1 Manifest syntax errors in $Psd1Path : $($errors | Out-String)"
    }

    $htAst = $ast.Find({
        param($n)
        $n -is [System.Management.Automation.Language.HashtableAst]
    }, $false)

    if (-not $htAst) {
        throw "Could not find root HashtableAst in $Psd1Path"
    }

    $functionsToExport = @()
    $aliasesToExport = @()
    $nestedModules = @()

    foreach ($pair in $htAst.KeyValuePairs) {
        $keyAst = $pair.Item1
        $valAst = $pair.Item2

        $key = (Get-AstStringValues -AstNode $keyAst) -join ''
        if ($key -eq 'FunctionsToExport') {
            $functionsToExport = Get-AstStringValues -AstNode $valAst
        }
        elseif ($key -eq 'AliasesToExport') {
            $aliasesToExport = Get-AstStringValues -AstNode $valAst
        }
        elseif ($key -eq 'NestedModules') {
            $nestedModules = Get-AstStringValues -AstNode $valAst
        }
    }

    return @{
        FunctionsToExport = [string[]]($functionsToExport | Sort-Object -Unique)
        AliasesToExport   = [string[]]($aliasesToExport | Sort-Object -Unique)
        NestedModules     = [string[]]($nestedModules | Sort-Object -Unique)
    }
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "       Win-Debloat AST 5-Way Parity Assertion Engine             " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$psd1File = Join-Path $RootPath "Win-Debloat.psd1"
$psd1File7 = Join-Path $RootPath "Win-Debloat7.psd1"
if (-not (Test-Path -LiteralPath $psd1File)) {
    Write-Error "Win-Debloat.psd1 manifest not found at $psd1File"
    exit 1
}
if (-not (Test-Path -LiteralPath $psd1File7)) {
    Write-Error "Win-Debloat7.psd1 manifest not found at $psd1File7"
    exit 1
}

Write-Host "[1/5] Parsing Win-Debloat.psd1 & Win-Debloat7.psd1 Manifest AST..." -ForegroundColor Gray
$manifestData = Parse-Psd1ManifestAst -Psd1Path $psd1File
$manifestData7 = Parse-Psd1ManifestAst -Psd1Path $psd1File7
$psd1Functions = $manifestData.FunctionsToExport
$psd1Aliases   = $manifestData.AliasesToExport
$nestedModules = $manifestData.NestedModules

Write-Host "  Manifest FunctionsToExport : $($psd1Functions.Count)" -ForegroundColor DarkGray
Write-Host "  Manifest AliasesToExport   : $($psd1Aliases.Count)" -ForegroundColor DarkGray
Write-Host "  Manifest NestedModules     : $($nestedModules.Count)" -ForegroundColor DarkGray

# Check dual manifest parity
if ($manifestData.FunctionsToExport.Count -ne $manifestData7.FunctionsToExport.Count -or
    $manifestData.AliasesToExport.Count -ne $manifestData7.AliasesToExport.Count) {
    Write-Error "Manifest discrepancy detected between Win-Debloat.psd1 and Win-Debloat7.psd1!"
    exit 1
}

# Filesystem module discovery check
$discoveredModules = Get-ChildItem -Path (Join-Path $RootPath "src") -Recurse -Filter "*.psm1" |
    Where-Object { $_.FullName -notmatch '\\(vendor|obj|bin|Extras)\\' } |
    ForEach-Object {
        $_.FullName.Substring($RootPath.Length).TrimStart('\', '/') -replace '\\', '/'
    }

foreach ($disc in $discoveredModules) {
    if ($disc -notin ($nestedModules -replace '\\', '/')) {
        Write-Warning "Discovered module on disk not registered in NestedModules: $disc"
    }
}

$psm1Files = $nestedModules | ForEach-Object { Join-Path $RootPath $_ }

Write-Host "[2/5] Parsing all .psm1 files using [Parser]::ParseInput..." -ForegroundColor Gray

$allDefinedFunctions = [System.Collections.Generic.List[string]]::new()
$allPsm1ExportedFunctions = [System.Collections.Generic.List[string]]::new()
$allPsm1ExportedAliases = [System.Collections.Generic.List[string]]::new()
$moduleReports = [System.Collections.Generic.List[PSCustomObject]]::new()
$syntaxErrors = [System.Collections.Generic.List[string]]::new()

foreach ($file in $psm1Files) {
    if (-not (Test-Path -LiteralPath $file)) {
        $syntaxErrors.Add("File not found: $file")
        continue
    }

    $content = Get-Content -LiteralPath $file -Raw -ErrorAction Stop
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        $syntaxErrors.Add("Syntax errors in $file : $($errors.Message -join '; ')")
    }

    $funcAsts = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $true)

    $definedNames = [string[]]($funcAsts | ForEach-Object { $_.Name } | Sort-Object -Unique)
    $exportData   = Get-ExportModuleMemberExports -Ast $ast
    $setAliases   = Get-SetAliasExports -Ast $ast

    $combinedAliases = [string[]](($exportData.Aliases + $setAliases) | Sort-Object -Unique)

    foreach ($fn in $definedNames) { $allDefinedFunctions.Add($fn) }
    foreach ($fn in $exportData.Functions) { $allPsm1ExportedFunctions.Add($fn) }
    foreach ($al in $combinedAliases) { $allPsm1ExportedAliases.Add($al) }

    $moduleReports.Add([PSCustomObject]@{
        Module           = (Split-Path $file -Leaf)
        DefinedCount     = $definedNames.Count
        ExportedFuncCount= $exportData.Functions.Count
        AliasCount       = $combinedAliases.Count
    })
}

$allDefinedFunctions      = [string[]]($allDefinedFunctions | Sort-Object -Unique)
$allPsm1ExportedFunctions = [string[]]($allPsm1ExportedFunctions | Sort-Object -Unique)
$allPsm1ExportedAliases   = [string[]]($allPsm1ExportedAliases | Sort-Object -Unique)

Write-Host "  Total Defined Functions (AST)       : $($allDefinedFunctions.Count)" -ForegroundColor DarkGray
Write-Host "  Total PSM1 Exported Functions (AST) : $($allPsm1ExportedFunctions.Count)" -ForegroundColor DarkGray
Write-Host "  Total PSM1 Exported Aliases (AST)   : $($allPsm1ExportedAliases.Count)" -ForegroundColor DarkGray

Write-Host "`n[3/5] Evaluating Mathematical Parity Matrix..." -ForegroundColor Gray

$parityViolations = [System.Collections.Generic.List[string]]::new()

if ($syntaxErrors.Count -gt 0) {
    foreach ($err in $syntaxErrors) {
        $parityViolations.Add("Syntax Error: $err")
    }
}

$unexportedInPsm1 = $allDefinedFunctions | Where-Object { $_ -notin $allPsm1ExportedFunctions }
if ($unexportedInPsm1) {
    foreach ($fn in $unexportedInPsm1) {
        $parityViolations.Add("PSM1 Export Parity Mismatch: Function '$fn' is defined in AST but not in Export-ModuleMember -Function")
    }
}

$missingInPsd1 = $allPsm1ExportedFunctions | Where-Object { $_ -notin $psd1Functions }
$extraInPsd1   = $psd1Functions | Where-Object { $_ -notin $allPsm1ExportedFunctions }

if ($missingInPsd1) {
    foreach ($fn in $missingInPsd1) {
        $parityViolations.Add("PSD1 Missing Function: '$fn' is exported in PSM1 AST but absent from Win-Debloat.psd1 FunctionsToExport")
    }
}
if ($extraInPsd1) {
    foreach ($fn in $extraInPsd1) {
        $parityViolations.Add("PSD1 Orphan Function: '$fn' is listed in Win-Debloat.psd1 FunctionsToExport but not exported in any PSM1")
    }
}

$missingAliasesInPsd1 = $allPsm1ExportedAliases | Where-Object { $_ -notin $psd1Aliases }
$extraAliasesInPsd1   = $psd1Aliases | Where-Object { $_ -notin $allPsm1ExportedAliases }

if ($missingAliasesInPsd1) {
    foreach ($al in $missingAliasesInPsd1) {
        $parityViolations.Add("PSD1 Missing Alias: '$al' is exported in PSM1 AST but absent from Win-Debloat.psd1 AliasesToExport")
    }
}
if ($extraAliasesInPsd1) {
    foreach ($al in $extraAliasesInPsd1) {
        $parityViolations.Add("PSD1 Orphan Alias: '$al' is listed in Win-Debloat.psd1 AliasesToExport but not exported in any PSM1")
    }
}

Write-Host "[4/5] Verifying WinDebloat7 / WD7 Backward Compatibility Alias Coverage..." -ForegroundColor Gray

foreach ($fn in $allDefinedFunctions) {
    if ($fn -match '^([A-Za-z]+)-WinDebloat(?!7)([A-Za-z0-9]+)$') {
        $verb = $Matches[1]
        $noun = $Matches[2]
        $expectedAlias7 = "$verb-WinDebloat7$noun"

        $hasPsm1Alias = ($expectedAlias7 -in $allPsm1ExportedAliases)
        $hasPsd1Alias = ($expectedAlias7 -in $psd1Aliases)

        if (-not $hasPsm1Alias -and -not ($fn -in $allPsm1ExportedAliases)) {
            $parityViolations.Add("Alias Coverage Missing: Function '$fn' lacks expected alias '$expectedAlias7' in PSM1 AST exports")
        }
        if (-not $hasPsd1Alias -and -not ($fn -in $psd1Aliases)) {
            $parityViolations.Add("Alias Coverage Missing: Function '$fn' lacks expected alias '$expectedAlias7' in PSD1 AliasesToExport")
        }
    }
}

Write-Host "`n[5/5] AST 5-Way Parity Verification Result" -ForegroundColor Gray
Write-Host "-----------------------------------------------------------------" -ForegroundColor DarkGray

if ($Detailed) {
    $moduleReports | Format-Table -AutoSize | Out-Host
}

Write-Host "  Total AST Defined Functions : $($allDefinedFunctions.Count)"
Write-Host "  Total PSM1 Exported Funcs   : $($allPsm1ExportedFunctions.Count)"
Write-Host "  Total PSD1 FunctionsToExport: $($psd1Functions.Count)"
Write-Host "  Total PSM1 Exported Aliases : $($allPsm1ExportedAliases.Count)"
Write-Host "  Total PSD1 AliasesToExport  : $($psd1Aliases.Count)"
Write-Host "  Parity Violations Detected  : $($parityViolations.Count)" -ForegroundColor $(if ($parityViolations.Count -eq 0) { "Green" } else { "Red" })

if ($parityViolations.Count -gt 0) {
    Write-Host "`n[!] PARITY VIOLATIONS FOUND:" -ForegroundColor Red
    foreach ($violation in $parityViolations) {
        Write-Host "  [FAIL] $violation" -ForegroundColor Red
    }
    Write-Host "`n❌ TEST FAILED: 5-way AST parity was not achieved." -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ SUCCESS: 100% Mathematical Parity Verified Across All 5 AST & Manifest Layers!" -ForegroundColor Green
exit 0
