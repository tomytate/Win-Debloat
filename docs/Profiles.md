# Profile Configuration Guide

Win-Debloat uses **YAML configuration files** (`.yaml`) to define optimization states. This approach allows for version-controlled, repeatable, and shareable system setups.

## 📂 Profile Location

Default profiles are stored in the `profiles/` directory:
- `conservative.yaml`: Minimal changes.
- `moderate.yaml`: Balanced (Recommended).
- `gaming.yaml`: Aggressive performance tuning.
- `performance.yaml`: Low-latency performance tuning.
- `essentials.yaml`: Software essentials focus.

## 📝 YAML Schema

A profile consists of several sections. Here is the full breakdown.

### 1. Metadata & Inheritance
Information about the profile, parent inheritance (`extends:`), and conditional gates (`when:`).
```yaml
metadata:
  name: "My Custom Gaming Profile"
  version: "1.7.0"
  author: "Tomy Tate"
  description: "Optimized for high-end gaming and streaming"
  extends: "moderate"              # Deep inheritance: inherits baseline and overrides specific keys
  target_os: [ "Windows 10", "Windows 11" ]
  min_build: 19045
  when:                            # Conditional execution gate
    min_ram_gb: 16
    chassis_types: [ "Desktop" ]
```

### 2. Bloatware
Controls removal of pre-installed Appx packages.

```yaml
bloatware:
  # Mode: 'Conservative', 'Moderate', 'Aggressive', or 'None'
  removal_mode: "Moderate"
  
  # List of package names to KEEP (supports wildcards)
  exclude_list:
    - "Microsoft.WindowsStore"
    - "Microsoft.WindowsCalculator"
    - "*Xbox*"
```

### 3. Privacy & AI Fabric
Controls telemetry, AI features, and background process containment.

```yaml
privacy:
  # Level: 'Basic' (Standard) or 'Security' (Strict)
  telemetry_level: "Security"
  
  disable_copilot: true           # Windows 11 AI assistant
  disable_recall: true            # Windows 11 Recall feature
  disable_click_to_do: true       # Windows 11 26H2 Click-to-Do
  disable_ai_fabric: true         # Deactivates background SLM/AI daemons
  disable_advertising_id: true
  disable_activity_history: true
  disable_location_tracking: false # Set true to block location services
```

### 4. Performance & Silicon Optimization
CPU scheduling, DirectStorage, low-latency timers, and GPU optimizations.

```yaml
performance:
  # Power Plan: 'Balanced', 'HighPerformance', 'Ultimate'
  power_plan: "Ultimate"
  visual_effects: "Performance"   # 'Appearance', 'Performance', 'Custom'
  disable_game_bar: false         # Keep false to preserve Game Bar / AMD X3D core parking
  disable_background_apps: true   # Prevents non-essential apps in background
  enable_directstorage_tuning: true # DirectStorage 1.2+ NTFS lookaside & BypassIO
  enable_amd_x3d_safeguards: true   # Preserves 3D V-Cache CPMINCORES core parking
  enable_thread_director: true      # Intel Lion Cove P-core / Skymont LP E-core tuning
  disable_energy_saver_ac_throttling: true # Eliminates CPU AC power throttling
```

### 5. System & QoL
Windows 11 system and interface customization.

```yaml
system:
  disable_fast_startup: true
  prevent_auto_bitlocker: true
  disable_delivery_optimization: true
  disable_storage_sense: false
  no_auto_reboot_updates: true
  no_early_updates: true
  disable_sticky_keys_shortcut: true
  disable_widgets: true
  hide_chat_taskbar: true
  disable_transparency: true
  disable_suggestions: true
  hide_settings_home: true
  hide_phone_link_start: true
  debloat_search: true
```

### 6. Network
DNS and adapter protocol configuration.

```yaml
network:
  dns_servers:
    - "1.1.1.1"
    - "1.0.0.1"
  disable_ipv6: false             # Prefer IPv4 over IPv6
```

### 7. Software
Install (and remove) applications via Winget, Chocolatey, Microsoft Store, or NPM.

```yaml
software:
  package_manager: "Winget"
  install_list:
    - "7zip.7zip"
    - "Mozilla.Firefox"
  uninstall_list:
    - "Microsoft.Teams"
```

## 🛠️ How to Create and Run Profiles

1.  Copy an existing profile (e.g., `profiles\moderate.yaml`).
2.  Rename it to `my-profile.yaml`.
3.  Edit the values in any text editor (VS Code, Notepad).
4.  Run it:
    ```powershell
    # Safe dry-run preview:
    pwsh .\Win-Debloat.ps1 -Profile "profiles\my-profile.yaml" -WhatIf

    # Unattended headless execution:
    pwsh .\Win-Debloat.ps1 -Profile "profiles\my-profile.yaml" -Silent

    # Sysprep / Golden Master image generation:
    pwsh .\Win-Debloat.ps1 -Profile "profiles\my-profile.yaml" -Sysprep -Silent

    # Enterprise deployment via standalone script (Intune / OOBE Shift+F10 / Native PS 5.1 or PS 7+):
    powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-WinDebloat.ps1 -Profile moderate -Silent

    # Universal Zero-Friction root launcher (autodetects PS7+, falls back to PS 5.1):
    .\Run.bat
    ```
