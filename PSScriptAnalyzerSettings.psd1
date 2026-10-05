@{
    # PSScriptAnalyzer Settings for Win-Debloat
    # Enforces zero-technical-debt static analysis rules across modules and scripts.
    Severity = @('Error', 'Warning')
    IncludeRules = @(
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingEmptyCatchBlock',
        'PSUseApprovedVerbs',
        'PSMissingModuleManifestField',
        'PSReservedCmdletChar',
        'PSReservedParams'
    )
    ExcludeRules = @(
        'PSAvoidUsingPositionalParameters',
        'PSUseDeclaredVarsMoreThanAssignments'
    )
    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
    }
}
