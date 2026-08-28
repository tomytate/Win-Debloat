using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Reflection;

namespace WinDebloat
{
    /// <summary>
    /// Single-file launcher: extracts the embedded payload and runs Win-Debloat.ps1
    /// under PowerShell 7.6+ (current LTS). If a suitable PowerShell is not installed,
    /// the launcher installs it automatically:
    ///   1. winget (forcing the MSI via --installer-type wix; since 7.6.0 winget
    ///      defaults to the MSIX/Store package, whose sandbox breaks admin tooling
    ///      such as Set-ExecutionPolicy -Scope LocalMachine and WSMan remoting)
    ///   2. Direct MSI download from the official GitHub release as fallback.
    ///
    /// Note: To comply with Windows 11 Smart App Control (SAC), the compiled output
    /// of this launcher MUST be digitally signed with a valid CA or Microsoft Trusted
    /// Signing certificate. Unsigned binaries will be blocked by default.
    /// </summary>
    class Launcher
    {
        // Minimum PowerShell version required by Win-Debloat (#Requires -Version 7.6)
        const int MinMajor = 7;
        const int MinMinor = 6;

        // Pinned fallback MSI release, used only when winget is unavailable or fails.
        // winget always installs the latest stable; bump this constant on new releases.
        const string FallbackMsiVersion = "7.6.5";

        static string DefaultPwshPath
        {
            get { return Environment.ExpandEnvironmentVariables(@"%ProgramFiles%\PowerShell\7\pwsh.exe"); }
        }

        static bool IsAdministrator()
        {
            try
            {
                using (var identity = System.Security.Principal.WindowsIdentity.GetCurrent())
                {
                    var principal = new System.Security.Principal.WindowsPrincipal(identity);
                    return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
                }
            }
            catch { return false; }
        }

        static bool ElevateSelf(string[] args)
        {
            try
            {
                ProcessStartInfo proc = new ProcessStartInfo();
                proc.UseShellExecute = true;
                proc.WorkingDirectory = Environment.CurrentDirectory;
                proc.FileName = Process.GetCurrentProcess().MainModule.FileName;
                proc.Verb = "runas";
                if (args != null && args.Length > 0)
                {
                    proc.Arguments = string.Join(" ", args);
                }
                Process p = Process.Start(proc);
                return p != null;
            }
            catch { return false; }
        }

        static void Main(string[] args)
        {
            try
            {
                // 0. Ensure Administrator Elevation
                if (!IsAdministrator())
                {
                    if (ElevateSelf(args))
                    {
                        return;
                    }
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("⚠️ Win-Debloat requires Administrator privileges.");
                    Console.ResetColor();
                }

                // 1. Ensure PowerShell 7.6+ is available (auto-install if needed)
                string pwshPath = EnsurePowerShell();
                if (pwshPath == null)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("Could not install PowerShell " + MinMajor + "." + MinMinor + "+ automatically.");
                    Console.ResetColor();
                    Console.WriteLine("Press any key to open the download page...");
                    SafeReadKey();
                    Process.Start(new ProcessStartInfo("https://github.com/PowerShell/PowerShell/releases/latest") { UseShellExecute = true });
                    return;
                }

                // 2. Setup Temp Directory
                string tempPath = Path.Combine(Path.GetTempPath(), "WD_" + Guid.NewGuid().ToString().Substring(0, 8));
                Directory.CreateDirectory(tempPath);

                string zipPath = Path.Combine(tempPath, "payload.zip");

                // 3. Extract Embedded Resource
                Assembly assembly = Assembly.GetExecutingAssembly();
                string resourceName = null;

                foreach (string name in assembly.GetManifestResourceNames())
                {
                    if (name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                    {
                        resourceName = name;
                        break;
                    }
                }

                if (resourceName == null)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("Error: Embedded payload.zip not found.");
                    Console.WriteLine("This executable was likely built incorrectly.");
                    Console.ResetColor();
                    SafeReadKey();
                    return;
                }

                using (Stream stream = assembly.GetManifestResourceStream(resourceName))
                using (FileStream fileStream = new FileStream(zipPath, FileMode.Create))
                {
                    stream.CopyTo(fileStream);
                }

                // 4. Prepare PowerShell Command
                string scriptCmd = string.Format(
                    "$progressPreference='SilentlyContinue'; " +
                    "Write-Host '🚀 Initializing Win-Debloat...' -ForegroundColor Cyan; " +
                    "Expand-Archive -LiteralPath '{0}' -DestinationPath '{1}' -Force; " +
                    "Set-Location '{1}'; " +
                    "$entry = if (Test-Path './Win-Debloat.ps1') {{ './Win-Debloat.ps1' }} else {{ './Win-Debloat7.ps1' }}; " +
                    "& $entry {2}",
                    zipPath.Replace("'", "''"), tempPath.Replace("'", "''"), args.Length > 0 ? String.Join(" ", args) : ""
                );

                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = pwshPath;
                string encodedCmd = Convert.ToBase64String(System.Text.Encoding.Unicode.GetBytes(scriptCmd));
                startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand " + encodedCmd;
                startInfo.UseShellExecute = false;

                // 5. Launch
                try
                {
                    Process p = Process.Start(startInfo);
                    if (p != null)
                    {
                        p.WaitForExit();
                    }
                }
                catch (System.ComponentModel.Win32Exception)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("Error: Failed to launch PowerShell.");
                    Console.WriteLine("Tried launching: " + pwshPath);
                    Console.ResetColor();
                    Console.WriteLine("Please restart the application.");
                    SafeReadKey();
                }

                // 6. Cleanup
                try
                {
                    Directory.Delete(tempPath, true);
                }
                catch { /* Ignore cleanup errors */ }

            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Launcher Error: " + ex.Message);
                Console.ResetColor();
                SafeReadKey();
            }
        }

        static void SafeReadKey()
        {
            try
            {
                if (Environment.UserInteractive && !Console.IsInputRedirected)
                {
                    Console.ReadKey();
                }
            }
            catch { /* Ignore when no interactive console is attached */ }
        }

        /// <summary>
        /// Returns the path to a pwsh.exe meeting the minimum version, installing or
        /// upgrading PowerShell automatically when necessary. Returns null on failure.
        /// </summary>
        static string EnsurePowerShell()
        {
            string pwsh = ResolvePwsh();
            if (pwsh != null) return pwsh;

            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("⚡ PowerShell " + MinMajor + "." + MinMinor + "+ (LTS) not found.");
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("🚀 Installing the latest PowerShell " + MinMajor + "." + MinMinor + " automatically...");
            Console.ResetColor();

            // Attempt 1: winget install (forced MSI - the MSIX default is sandboxed)
            if (RunWinget("install --id Microsoft.PowerShell --source winget --installer-type wix " +
                          "--accept-source-agreements --accept-package-agreements --silent --disable-interactivity"))
            {
                pwsh = ResolvePwsh();
                if (pwsh != null) { ReportInstalled(pwsh); return pwsh; }
            }

            // Attempt 2: an older PowerShell 7 may already be installed - upgrade it
            if (RunWinget("upgrade --id Microsoft.PowerShell --source winget " +
                          "--accept-source-agreements --accept-package-agreements --silent --disable-interactivity"))
            {
                pwsh = ResolvePwsh();
                if (pwsh != null) { ReportInstalled(pwsh); return pwsh; }
            }

            // Attempt 3: direct MSI download from the official GitHub release
            Console.WriteLine("winget unavailable or failed. Downloading the official MSI package...");
            if (InstallViaMsi())
            {
                pwsh = ResolvePwsh();
                if (pwsh != null) { ReportInstalled(pwsh); return pwsh; }
            }

            return null;
        }

        static void ReportInstalled(string pwshPath)
        {
            Version v = GetPwshVersion(pwshPath);
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("✅ PowerShell " + (v != null ? v.ToString() : "7") + " ready! Launching Win-Debloat...");
            Console.ResetColor();
        }

        /// <summary>
        /// Finds a pwsh.exe that satisfies the minimum version: PATH first, then the
        /// default machine-wide install location (PATH is stale right after install).
        /// </summary>
        static string ResolvePwsh()
        {
            Version v = GetPwshVersion("pwsh.exe");
            if (IsSufficient(v)) return "pwsh.exe";

            string[] candidatePaths = new string[]
            {
                DefaultPwshPath,
                Environment.ExpandEnvironmentVariables(@"%ProgramW6432%\PowerShell\7\pwsh.exe"),
                Environment.ExpandEnvironmentVariables(@"%LOCALAPPDATA%\Microsoft\PowerShell\7\pwsh.exe")
            };

            foreach (string candidate in candidatePaths)
            {
                if (!string.IsNullOrEmpty(candidate) && File.Exists(candidate))
                {
                    v = GetPwshVersion(candidate);
                    if (IsSufficient(v)) return candidate;
                }
            }

            return null;
        }

        static bool IsSufficient(Version v)
        {
            if (v == null) return false;
            return v.Major > MinMajor || (v.Major == MinMajor && v.Minor >= MinMinor);
        }

        /// <summary>
        /// Queries a pwsh executable for its engine version. Returns null if the
        /// executable is missing or the output cannot be parsed.
        /// </summary>
        static Version GetPwshVersion(string exePath)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = exePath;
                psi.Arguments = "-NoProfile -NoLogo -Command \"$PSVersionTable.PSVersion.ToString()\"";
                psi.UseShellExecute = false;
                psi.RedirectStandardOutput = true;
                psi.CreateNoWindow = true;

                using (Process p = Process.Start(psi))
                {
                    string output = p.StandardOutput.ReadToEnd().Trim();
                    p.WaitForExit(15000);

                    // Strip prerelease suffixes like "7.7.0-preview.2"
                    int dash = output.IndexOf('-');
                    if (dash > 0) output = output.Substring(0, dash);

                    Version v;
                    if (Version.TryParse(output, out v)) return v;
                }
            }
            catch { /* pwsh missing or not runnable */ }

            return null;
        }

        static bool RunWinget(string arguments)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "cmd.exe";
                psi.Arguments = "/c winget " + arguments;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = false;

                Process p = Process.Start(psi);
                p.WaitForExit();
                return p.ExitCode == 0;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Downloads the pinned PowerShell MSI (x64/arm64) from the official GitHub
        /// release and installs it machine-wide with PATH registration.
        /// </summary>
        static bool InstallViaMsi()
        {
            string msiPath = null;
            try
            {
                // Detect OS architecture (launcher may run as a 32-bit process on x64)
                string arch = Environment.GetEnvironmentVariable("PROCESSOR_ARCHITEW6432");
                if (string.IsNullOrEmpty(arch)) arch = Environment.GetEnvironmentVariable("PROCESSOR_ARCHITECTURE");
                string msiArch = (arch != null && arch.Equals("ARM64", StringComparison.OrdinalIgnoreCase)) ? "arm64" : "x64";

                string url = string.Format(
                    "https://github.com/PowerShell/PowerShell/releases/download/v{0}/PowerShell-{0}-win-{1}.msi",
                    FallbackMsiVersion, msiArch);

                msiPath = Path.Combine(Path.GetTempPath(), string.Format("PowerShell-{0}-win-{1}.msi", FallbackMsiVersion, msiArch));

                Console.WriteLine("Downloading " + url);
                ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
                using (WebClient client = new WebClient())
                {
                    client.Headers.Add("User-Agent", "Win-Debloat-Launcher");
                    client.DownloadFile(url, msiPath);
                }

                Console.WriteLine("Installing PowerShell " + FallbackMsiVersion + " (this may take a minute)...");
                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "msiexec.exe";
                psi.Arguments = string.Format("/package \"{0}\" /passive ADD_PATH=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1", msiPath);
                psi.UseShellExecute = true; // allow UAC elevation prompt if needed

                Process p = Process.Start(psi);
                p.WaitForExit();

                // 0 = success, 3010 = success but reboot required
                return p.ExitCode == 0 || p.ExitCode == 3010;
            }
            catch (Exception ex)
            {
                Console.WriteLine("MSI install failed: " + ex.Message);
                return false;
            }
            finally
            {
                try { if (msiPath != null && File.Exists(msiPath)) File.Delete(msiPath); }
                catch { /* ignore cleanup errors */ }
            }
        }
    }
}
