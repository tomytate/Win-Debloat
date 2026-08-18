# Unit Test Plan

## Goal
Establish a Pester 5.x test suite to automatically verify the stability of the `Win-Debloat` framework.

## Scope
1.  **Core Tests** (`tests/Core.Tests.ps1`)
    *   **Registry**: Mock `Set-ItemProperty` to verify logic without touching real registry. Verify `Export-RegistryKey` argument quoting.
    *   **Config**: Test YAML loading, Schema validation (valid vs invalid profiles), Array normalization.
    *   **Logger**: Verify log rotation checks.

2.  **Module Tests** (`tests/Modules.Tests.ps1`)
    *   **Bloatware**: Verify the specific 25H2 apps are present in the list.
    *   **Privacy**: Verify critical keys (Copilot, Recall) are targeted.
    *   **Version**: Verify 25H2 build checks (26200).

## Execution
Run `Invoke-Pester -Output Detailed` to validate.
