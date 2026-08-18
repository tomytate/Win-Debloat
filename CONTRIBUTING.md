# Contributing to Win-Debloat

Thank you for your interest in contributing to **Win-Debloat**! We welcome improvements, bug fixes, and new features.

## 🤝 Code of Conduct
Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## 🛠️ Development Setup
1. **Prerequisites**:
   - Windows 10/11
   - PowerShell 7.6+
   - VS Code (Recommended) with PowerShell extension
   - Pester 5+ (`Install-Module Pester -Force`)

2. **Clone the repo**:
   ```powershell
   git clone https://github.com/tomytate/Win-Debloat.git
   cd Win-Debloat
   ```

3. **Run Locally**:
   ```powershell
   # TUI Mode (default)
   ./Win-Debloat.ps1

   # GUI Mode
   ./Win-Debloat.ps1 -Gui
   ```

## 🧪 Testing
- We use **Pester 5** for unit and integration testing.
- Run the full test suite before submitting a PR:
  ```powershell
  # Compliance suite (35 tests)
  Invoke-Pester -Path tests/Overall.Tests.ps1 -Output Detailed

  # Unit tests
  Invoke-Pester -Path tests/Unit -Output Detailed
  ```
- Run **PSScriptAnalyzer** for linting:
  ```powershell
  Invoke-ScriptAnalyzer -Path src -Recurse -Severity Error,Warning
  ```
- CI enforces **zero Severity=Error findings**. Three warning categories are accepted by design:
  `PSAvoidUsingWriteHost` (this is an interactive console tool), `PSUseSingularNouns`
  (established public function names), and `PSAvoidOverwritingBuiltInCmdlets` for
  `Write-Log` (a PSScriptAnalyzer compatibility-profile false positive).

## 📦 Adding Software to the Catalog
1. Edit `$Script:EssentialsApps` in `src/modules/Software/Software.psm1`.
2. Provide **both** IDs where available: `@{ Name = "App"; Winget = "Publisher.App"; Choco = "app" }`. Leave one empty (`""`) if the app only exists on one manager. npm-published CLIs may add `Npm = "@scope/package"` (used as last-resort provider; Node.js LTS is auto-provisioned).
3. Validate before committing:
   ```powershell
   ./build/Test-PackageIds.ps1
   ```
   CI re-validates the whole catalog monthly (`validate-packages.yml`) - stale IDs fail the build.

## 📦 Project Structure
```
Win-Debloat/
├── src/
│   ├── core/           # Logger, Config (YAML), Registry, State, Sysprep
│   ├── modules/
│   │   ├── Bloatware/  # App removal engine
│   │   ├── Privacy/    # Telemetry, Hosts blocking, Scheduled Tasks
│   │   ├── Performance/# Power plans, Gaming, Services, Benchmarking, Tweaks
│   │   ├── Network/    # DNS, IPv6, Network diagnostics
│   │   ├── Software/   # Winget/Choco package manager
│   │   ├── Drivers/    # GPU & system driver updates
│   │   ├── Repair/     # SFC, DISM, Network reset
│   │   ├── Features/   # Optional Windows features
│   │   ├── Security/   # SMBv1, PUA protection
│   │   ├── Maintenance/# Scheduled cleanup tasks
│   │   ├── Integrations/# ShutUp10++, AdwCleaner, SDIO
│   │   ├── Extras/     # Defender Remover, MAS (Extras edition only)
│   │   ├── Tweaks/     # AI disablement, UI customization
│   │   └── Windows11/  # Version detection, 25H2 compatibility
│   └── ui/             # TUI (Menu.psm1, Colors.psm1) + GUI (WPF)
├── config/             # services.json, dns.json
├── profiles/           # YAML configuration presets
├── build/              # Build scripts, Chocolatey packaging
├── tests/              # Pester test suites
└── docs/               # Wiki documentation
```

## 📝 Pull Request Guidelines
1. **One feature per PR**: Keep changes focused.
2. **Descriptive Title**: e.g., "Add Firefox Telemetry Blocking".
3. **Verify Safety**: Ensure no critical system components (like Bootloader) are touched.
4. **Update Documentation**: If you change functionality, update relevant docs.
5. **Run Tests**: All Pester tests must pass before merging.
6. **Follow Naming**: Functions must use the `Verb-WinDebloatNoun` naming convention (with `Verb-WinDebloat7Noun` aliases for backward compatibility).

## ⚠️ "Extras" Build Variant
- Code related to **Defender Remover** or **MAS** is located in `src/modules/Extras`.
- The build script (`build/Build-DualRelease.ps1`) automatically handles the inclusion/exclusion of these modules.
- Do **NOT** commit compiled EXEs or large binaries to the repository.

Thank you for helping build the Gold Standard of Windows Optimization!
