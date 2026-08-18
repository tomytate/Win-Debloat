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

### 1. Metadata
Information about the profile itself.
```yaml
metadata:
  name: "My Custom Profile"
  author: "TomyTate"
  description: "Optimization for high-end gaming PC"
  version: "1.0"
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

### 3. Privacy
Controls telemetry and data collection settings.

```yaml
privacy:
  # Level: 'Basic' (Standard) or 'Security' (Strict)
  telemetry_level: "Security"
  
  disable_copilot: true           # Windows 11 AI assistant
  disable_recall: true            # Windows 11 Recall feature
  disable_advertising_id: true
  disable_activity_history: true
  disable_location_tracking: false # Set true to block location services
```

### 4. Performance
System tuning parameters.

```yaml
performance:
  # Power Plan: 'Balanced', 'HighPerformance', 'Ultimate'
  power_plan: "HighPerformance"
  visual_effects: "Performance"   # 'Appearance', 'Performance', 'Custom'
  disable_game_bar: true          # Xbox Game Bar recording
  disable_background_apps: true  # Prevents apps running in background
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

## 🛠️ How to Create a Custom Profile

1.  Copy an existing profile (e.g., `profiles\moderate.yaml`).
2.  Rename it to `my-profile.yaml`.
3.  Edit the values in any text editor (Notepad, VS Code).
4.  Run it:
    ```powershell
    .\Win-Debloat.ps1 -ProfileFile "profiles\my-profile.yaml"
    # Or via the compiled launcher:
    .\Win-Debloat.exe -ProfileFile "profiles\my-profile.yaml" -Unattended
    ```
