using System;
using System.Diagnostics;
using System.IO;
using System.Net;

namespace WinDebloat
{
    /// <summary>
    /// Folder launcher: runs Win-Debloat.ps1 from the same directory under
    /// PowerShell 7.6+ (current LTS), auto-installing PowerShell when missing
    /// (winget MSI first, direct MSI download as fallback).
    ///
    /// Note: This executable wrapper is deliberately left unsigned to remain a free,
    /// open-source project. Windows 11 Smart App Control (SAC) and Microsoft Defender
    /// SmartScreen may block this file. Users must explicitly allow it, or run the
    /// .ps1 directly.
    /// </summary>
    class Launcher
    {
        // Minimum PowerShell version required by Win-Debloat (#Requires -Version 7.6)
        const int MinMajor = 7;
        const int MinMinor = 6;

        // Pinned fallback MSI release, used only when winget is unavailable or fails.
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

                string scriptName = "Win-Debloat.ps1";
                string scriptPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, scriptName);

                if (!File.Exists(scriptPath))
                {
                    string fallbackScript = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Win-Debloat7.ps1");
                    if (File.Exists(fallbackScript))
                    {
                        scriptName = "Win-Debloat7.ps1";
                        scriptPath = fallbackScript;
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("Error: " + scriptName + " not found in the current directory.");
                        Console.WriteLine("Please ensure the exe is in the same folder as the script.");
                        SafeReadKey();
                        return;
                    }
                }

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

                string extraArgs = (args != null && args.Length > 0) ? " " + string.Join(" ", args) : "";
                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = pwshPath;
                startInfo.Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\"{1}", scriptPath, extraArgs);
                startInfo.UseShellExecute = false;

                Process p = Process.Start(startInfo);
                if (p != null) p.WaitForExit();
            }
            catch (Exception ex)
            {
                Console.WriteLine("An unexpected error occurred: " + ex.Message);
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

        static string EnsurePowerShell()
        {
            string pwsh = ResolvePwsh();
            if (pwsh != null) return pwsh;

            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("PowerShell " + MinMajor + "." + MinMinor + "+ (LTS) not found.");
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Installing the latest PowerShell " + MinMajor + "." + MinMinor + " automatically...");
            Console.ResetColor();

            // winget install, forced MSI (the MSIX default is sandboxed and unsuitable
            // for admin tooling), then upgrade for pre-existing older installs.
            if (RunWinget("install --id Microsoft.PowerShell --source winget --installer-type wix " +
                          "--accept-source-agreements --accept-package-agreements --silent --disable-interactivity"))
            {
                pwsh = ResolvePwsh();
                if (pwsh != null) return pwsh;
            }

            if (RunWinget("upgrade --id Microsoft.PowerShell --source winget " +
                          "--accept-source-agreements --accept-package-agreements --silent --disable-interactivity"))
            {
                pwsh = ResolvePwsh();
                if (pwsh != null) return pwsh;
            }

            Console.WriteLine("winget unavailable or failed. Downloading the official MSI package...");
            if (InstallViaMsi())
            {
                pwsh = ResolvePwsh();
                if (pwsh != null) return pwsh;
            }

            return null;
        }

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

        static bool InstallViaMsi()
        {
            string msiPath = null;
            try
            {
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
                psi.UseShellExecute = true;

                Process p = Process.Start(psi);
                p.WaitForExit();

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
