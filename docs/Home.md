# Welcome to the Win-Debloat Wiki!

**Win-Debloat** is a professional-grade Windows 10/11 optimization framework tailored for power users, gamers, and system administrators. Built on **PowerShell 7.6+ LTS**, it prioritizes safety, reversibility, modular configuration, and zero technical debt.

## 🚀 Key Differences

Unlike other debloaters, Win-Debloat focuses on:

1.  **Infrastructure as Code**: All settings are defined in declarative YAML profiles (`profiles/`) with deep inheritance and hardware condition gates.
2.  **Dual-Layer Safety First**: Uses DPAPI-encrypted snapshots paired with human-readable Windows Registry Editor (`rollback.reg`) exports for instant, transparent rollback.
3.  **Zero-Binary & Enterprise Options**: Single-click `Run.bat` UAC trampoline bypassing Smart App Control, standalone Intune/OOBE deployment (`deploy/Deploy-WinDebloat.ps1`), plus native single-file `.exe` launchers.
4.  **Hardware Awareness**: Auto-detects RAM, CPU (AMD 3D V-Cache / Intel Thread Director), and GPU (NVIDIA/AMD) with DirectStorage 1.2+ BypassIO and low-latency TCP congestion tuning.
5.  **AI & Telemetry Eradication**: Neutralizes Windows Recall v2, Copilot, Click-to-Do, Phi-Silica SLMs, and background AI fabrics.
6.  **Mathematical Integrity**: Enforces 100% 5-way AST parity across 239 functions and 268 aliases with a 100% passing 336-test Pester suite.

## 📚 Topics

*   **[Installation Guide](Installation.md)** — Getting started (6 methods: Instant Deploy, Chocolatey, Portable EXE, Run.bat, Enterprise Deploy, Source).
*   **[Features & Capabilities](Features.md)** — Deep dive into all 10 core feature areas.
*   **[Modules Reference](Modules.md)** — Complete reference for all 30 modules, 239 functions, and 268 aliases.
*   **[Profiles Explained](Profiles.md)** — How to customize, create, and deploy `.yaml` configurations.
*   **[About](About.md)** — Philosophy, tech stack, and single-author maintainer.
*   **[Troubleshooting](Troubleshooting.md)** — Restore points, registry exports, logs, and 24H2 DISM fixes.

## 🤝 Community

*   [GitHub Repository](https://github.com/tomytate/Win-Debloat)
*   [Discussions](https://github.com/tomytate/Win-Debloat/discussions)
*   [Report a Bug](https://github.com/tomytate/Win-Debloat/issues)
*   [Contributing Guide](../CONTRIBUTING.md)
*   [Security Policy](../SECURITY.md)
