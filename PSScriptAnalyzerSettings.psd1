@{
    # PSScriptAnalyzer Settings for Win-Debloat
    # Enforces zero-technical-debt static analysis rules across modules and scripts.
    Severity = @('Error', 'Warning')
    IncludeRules = @(
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingWMICmdlet',
        'PSMissingModuleManifestField',
        'PSReservedCmdletChar',
        'PSReservedParams'
    )
    ExcludeRules = @(
        'PSAvoidUsingPositionalParameters',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingEmptyCatchBlock'
    )
    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
    }
}
