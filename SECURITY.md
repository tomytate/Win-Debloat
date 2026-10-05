# Security Policy

## Supported Versions

Only the latest major version is actively supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 1.7.x   | :white_check_mark: |
| 1.6.x   | :white_check_mark: |
| < 1.6   | :x:                |

## 🚨 Antivirus & False Positives

**Win-Debloat-Extras.exe** contains third-party tools (Defender Remover, MAS) that are **intentionally flagged** by Antivirus software as "HackTool" or "PUP" (Potentially Unwanted Program).

*   **This is expected behavior.** These tools modify Windows activation or security components.
*   **Standard Edition (`Win-Debloat.exe`)** is guaranteed to be clean and should **NOT** trigger any warnings.

If you encounter a virus warning:
1.  Verify you are using the **Standard Edition** if you want a clean experience.
2.  Verify the SHA256 Checksum against the one published in the Release Notes.
3.  If the **Standard Edition** triggers a warning, please [report it immediately](https://github.com/tomytate/Win-Debloat/issues) as a False Positive.

## Reporting a Vulnerability

We take the security of **Win-Debloat** seriously. If you discover a security vulnerability in the codebase (e.g., in the PowerShell logic, GUI, or API handling):

1.  **Do NOT open a public issue.**
2.  Use the [GitHub Security Advisory](https://github.com/tomytate/Win-Debloat/security/advisories/new) feature to report it privately.
3.  Provide steps to reproduce the issue.
4.  **Response SLA**: Security vulnerabilities are acknowledged within 48 hours, with triage and patched releases prioritized.

## Supply Chain Security

*   **Dual-Layer Authenticode Signing**: Release executables are signed with Authenticode at two levels: inner PowerShell payload scripts are hashed and signed before embedding, and the outer Win32 PE binary is signed with RFC 3161 timestamps.
*   **SLSA Level 3 Build Provenance**: GitHub Actions generates cryptographic artifact attestations (`actions/attest-build-provenance`) directly in the build pipeline.
*   **SPDX 2.3 Software Bill of Materials (SBOM)**: Every release bundles a machine-readable `win-debloat-sbom.spdx.json` containing SHA256 hashes and component metadata.
*   **Cryptographic Verification**: `SHA256SUMS.txt` is published with every release. The smart bootstrapper enforces a fail-closed cryptographic check before executing.
*   **Zero-Defect AST & Static Analysis**: All PowerShell code passes **PSScriptAnalyzer** and 5-way AST parity assertions with zero errors.

## Network Security & Firewall Loopback Guard

*   **Loopback & RFC Isolation**: All IP addresses fed to Windows Defender Firewall rules are strictly validated by `Test-IsSafeExternalIp`. IPv4-mapped IPv6 addresses (`::ffff:127.0.0.1`) are unmapped and filtered against RFC 1122, RFC 6890, and RFC 1918 specifications.
*   **Zero Localhost Blocking Guarantee**: Neither loopback (`127.0.0.0/8`, `::1`), unspecified (`0.0.0.0/8`), link-local (`169.254.0.0/16`), multicast, broadcast, nor private LAN subnets can ever be added to firewall blocking rules, preventing local RPC, WSL, or loopback service interruption.
*   **Sanitized Offline Cache**: The offline telemetry IP cache (`config/resolved-telemetry-ips.json`) contains only verified external telemetry endpoints.

## Safe Usage

*   Always download releases from the official [GitHub Releases](https://github.com/tomytate/Win-Debloat/releases) page.
*   Avoid downloading from third-party sites.
*   Use the **Standard Edition** for Enterprise/Production environments.
*   Run `Invoke-Pester` on the test suite to verify code integrity after cloning.
