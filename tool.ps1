Add-Type -AssemblyName System.Windows.Forms;
Add-Type -AssemblyName System.Drawing;

$exePathSelf = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName;
$currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $exePathSelf };
$adbPath = Join-Path $currentDir "adb.exe";
$fastbootPath = Join-Path $currentDir "fastboot.exe";

$isDarkMode = $false;
try {
    $themeVal = Get-ItemPropertyValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction Stop;
    if ($themeVal -eq 0) { $isDarkMode = $true; }
} catch {}

$bgForm   = if ($isDarkMode) { [System.Drawing.Color]::FromArgb(32, 32, 32) } else { [System.Drawing.SystemColors]::Control };
$fgText   = if ($isDarkMode) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black };
$bgBtn    = if ($isDarkMode) { [System.Drawing.Color]::FromArgb(50, 50, 50) } else { [System.Drawing.SystemColors]::ControlLight };
$bgInput  = if ($isDarkMode) { [System.Drawing.Color]::FromArgb(45, 45, 45) } else { [System.Drawing.Color]::White };

$form = New-Object System.Windows.Forms.Form;
$form.Text = "ADB & Fastboot AIO Tool by Thinh.Susie";
$form.Size = New-Object System.Drawing.Size(520, 685);
$form.StartPosition = "CenterScreen";
$form.FormBorderStyle = "FixedDialog";
$form.MaximizeBox = $false;
$form.BackColor = $bgForm;
$form.ForeColor = $fgText;

$lblStatus = New-Object System.Windows.Forms.Label;
$lblStatus.Text = "Status: Ready";
$lblStatus.Location = New-Object System.Drawing.Point(20, 395);
$lblStatus.Size = New-Object System.Drawing.Size(185, 18);
$lblStatus.ForeColor = $fgText;
$form.Controls.Add($lblStatus);

$progressBar = New-Object System.Windows.Forms.ProgressBar;
$progressBar.Location = New-Object System.Drawing.Point(210, 395);
$progressBar.Size = New-Object System.Drawing.Size(275, 16);
$progressBar.Style = "Continuous";
$progressBar.Value = 0;
$form.Controls.Add($progressBar);

$txtOutput = New-Object System.Windows.Forms.TextBox;
$txtOutput.Location = New-Object System.Drawing.Point(20, 420);
$txtOutput.Size = New-Object System.Drawing.Size(465, 210);
$txtOutput.Multiline = $true;
$txtOutput.ScrollBars = "Vertical";
$txtOutput.ReadOnly = $true;
$txtOutput.BackColor = if ($isDarkMode) { [System.Drawing.Color]::FromArgb(18, 18, 18) } else { [System.Drawing.Color]::Black };
$txtOutput.ForeColor = [System.Drawing.Color]::Lime;
$txtOutput.Font = New-Object System.Drawing.Font("Consolas", 9.5);
$form.Controls.Add($txtOutput);

function Execute-ProcessWithProgress ($exePath, $arguments, $isMarquee = $false) {
    if (-not (Test-Path $exePath)) {
        $txtOutput.AppendText("Error: File not found at $exePath`r`n`r`n");
        $lblStatus.Text = "Status: File Missing";
        return "";
    }

    $lblStatus.Text = "Status: Processing...";
    if ($isMarquee) {
        $progressBar.Style = "Marquee";
        $progressBar.MarqueeAnimationSpeed = 30;
    } else {
        $progressBar.Style = "Continuous";
        $progressBar.Value = 20;
    }
    [System.Windows.Forms.Application]::DoEvents();

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo;
    $pinfo.FileName = $exePath;
    $pinfo.Arguments = $arguments;
    $pinfo.RedirectStandardOutput = $true;
    $pinfo.RedirectStandardError = $true;
    $pinfo.UseShellExecute = $false;
    $pinfo.CreateNoWindow = $true;

    $process = New-Object System.Diagnostics.Process;
    $process.StartInfo = $pinfo;
    $process.Start() | Out-Null;

    $stdoutTask = $process.StandardOutput.ReadToEndAsync();
    $stderrTask = $process.StandardError.ReadToEndAsync();

    while (-not $process.HasExited) {
        if (-not $isMarquee -and $progressBar.Value -lt 85) {
            $progressBar.Value += 5;
        }
        [System.Windows.Forms.Application]::DoEvents();
        Start-Sleep -Milliseconds 50;
    }

    $process.WaitForExit();
    $outText = $stdoutTask.Result;
    $errText = $stderrTask.Result;

    $progressBar.Style = "Continuous";
    $progressBar.Value = 100;
    $lblStatus.Text = "Status: Completed!";
    [System.Windows.Forms.Application]::DoEvents();

    return ($outText + "`r`n" + $errText).Trim();
}

function Run-LocalCommand ($toolType, $argsList, $isMarquee = $false) {
    $exeToRun = if ($toolType -eq "adb") { $adbPath } else { $fastbootPath };
    $txtOutput.AppendText(">> Running: $toolType $argsList`r`n");
    
    $result = Execute-ProcessWithProgress $exeToRun $argsList $isMarquee;
    if ([string]::IsNullOrWhiteSpace($result)) {
        $txtOutput.AppendText("Done.`r`n`r`n");
    } else {
        $txtOutput.AppendText("$result`r`n`r`n");
    }
}

function Create-Button ($text, $x, $y, $w, $h, $action) {
    $btn = New-Object System.Windows.Forms.Button;
    $btn.Text = $text;
    $btn.Location = New-Object System.Drawing.Point($x, $y);
    $btn.Size = New-Object System.Drawing.Size($w, $h);
    $btn.BackColor = $bgBtn;
    $btn.ForeColor = $fgText;
    $btn.FlatStyle = "Flat";
    $btn.FlatAppearance.BorderColor = if ($isDarkMode) { [System.Drawing.Color]::FromArgb(80, 80, 80) } else { [System.Drawing.Color]::Gray };
    $btn.Add_Click($action);
    $form.Controls.Add($btn);
}

Create-Button "Check ADB" 20 20 110 35 { Run-LocalCommand "adb" "devices" };
Create-Button "Reboot System" 138 20 110 35 { Run-LocalCommand "adb" "reboot" };
Create-Button "Reboot Recovery" 256 20 110 35 { Run-LocalCommand "adb" "reboot recovery" };
Create-Button "Bootloader" 374 20 111 35 { Run-LocalCommand "adb" "reboot bootloader" };

Create-Button "Reboot Fastbootd" 20 65 110 35 { Run-LocalCommand "adb" "reboot fastboot" };
Create-Button "Check Fastboot" 138 65 110 35 { Run-LocalCommand "fastboot" "devices" };
Create-Button "Fastboot Reboot" 256 65 110 35 { Run-LocalCommand "fastboot" "reboot" };
Create-Button "BL Status" 374 65 111 35 { Run-LocalCommand "fastboot" "getvar unlocked" };

Create-Button "Unlock Bootloader" 20 110 228 34 {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "WARNING: Unlocking the bootloader will ERASE ALL USER DATA on your device!`n`nMake sure OEM Unlocking is enabled in Developer Options and the phone is in Fastboot mode.`n`nContinue to Unlock Bootloader?",
        "Unlock Bootloader Warning",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    );
    if ($confirm -eq "Yes") {
        $txtOutput.AppendText(">> Attempting Bootloader Unlock (check phone screen to confirm)...`r`n");
        $res1 = Execute-ProcessWithProgress $fastbootPath "flashing unlock" $true;
        $txtOutput.AppendText("$res1`r`n");
        if ($res1 -match "unknown command" -or $res1 -match "FAILED") {
            $txtOutput.AppendText(">> Trying legacy OEM unlock command...`r`n");
            $res2 = Execute-ProcessWithProgress $fastbootPath "oem unlock" $true;
            $txtOutput.AppendText("$res2`r`n");
        }
        $txtOutput.AppendText("`r`n");
    }
};

Create-Button "Relock Bootloader" 256 110 229 34 {
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "DANGER: Relocking the bootloader will ERASE ALL USER DATA and may BRICK your device if custom ROM/root/recovery is installed!`n`nOnly relock on 100% stock firmware.`n`nContinue to Relock Bootloader?",
        "Relock Bootloader Danger",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Stop
    );
    if ($confirm -eq "Yes") {
        $txtOutput.AppendText(">> Attempting Bootloader Relock (check phone screen to confirm)...`r`n");
        $res1 = Execute-ProcessWithProgress $fastbootPath "flashing lock" $true;
        $txtOutput.AppendText("$res1`r`n");
        if ($res1 -match "unknown command" -or $res1 -match "FAILED") {
            $txtOutput.AppendText(">> Trying legacy OEM lock command...`r`n");
            $res2 = Execute-ProcessWithProgress $fastbootPath "oem lock" $true;
            $txtOutput.AppendText("$res2`r`n");
        }
        $txtOutput.AppendText("`r`n");
    }
};

Create-Button "Install APK..." 20 154 120 38 {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog;
    $dialog.Filter = "Android Package (*.apk)|*.apk";
    if ($dialog.ShowDialog() -eq "OK") {
        $apkPath = $dialog.FileName;
        $txtOutput.AppendText(">> Installing: $apkPath`r`n");
        $res = Execute-ProcessWithProgress $adbPath "install -r `"$apkPath`"" $true;
        $txtOutput.AppendText("$res`r`n`r`n");
    }
};

Create-Button "ADB Sideload (.zip)..." 150 154 145 38 {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog;
    $dialog.Filter = "Zip Package (*.zip)|*.zip";
    if ($dialog.ShowDialog() -eq "OK") {
        $zipPath = $dialog.FileName;
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Make sure your device is in ADB Sideload mode in Recovery.`n`nSideload this package?`n$zipPath",
            "Confirm ADB Sideload",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Information
        );
        if ($confirm -eq "Yes") {
            $txtOutput.AppendText(">> Sideloading: $zipPath`r`n");
            $res = Execute-ProcessWithProgress $adbPath "sideload `"$zipPath`"" $true;
            $txtOutput.AppendText("$res`r`n`r`n");
        }
    }
};

$cmbPartition = New-Object System.Windows.Forms.ComboBox;
$cmbPartition.Location = New-Object System.Drawing.Point(305, 161);
$cmbPartition.Size = New-Object System.Drawing.Size(80, 25);
$cmbPartition.DropDownStyle = "DropDownList";
$cmbPartition.BackColor = $bgInput;
$cmbPartition.ForeColor = $fgText;
[void]$cmbPartition.Items.AddRange(@("recovery", "boot", "init_boot", "vbmeta", "system"));
$cmbPartition.SelectedIndex = 0;
$form.Controls.Add($cmbPartition);

Create-Button "Flash (.img)" 390 154 95 38 {
    $part = $cmbPartition.SelectedItem.ToString();
    $dialog = New-Object System.Windows.Forms.OpenFileDialog;
$dialog.Filter = "Disk Image (.img)|.img";
if ($dialog.ShowDialog() -eq "OK") {
$imgPath = $dialog.FileName;
$confirm = [System.Windows.Forms.MessageBox]::Show(
"Are you sure you want to flash this file to [$part] partition?nn$imgPath",
"Confirm Fastboot Flash",
[System.Windows.Forms.MessageBoxButtons]::YesNo,
[System.Windows.Forms.MessageBoxIcon]::Warning
);
if ($confirm -eq "Yes") {
$txtOutput.AppendText(">> Flashing [$part]: $imgPathrn");
$res = Execute-ProcessWithProgress $fastbootPath "flash $part "$imgPath"" $true;
$txtOutput.AppendText("$resrnrn");
}
}
};
$lblWifi = New-Object System.Windows.Forms.Label;
$lblWifi.Text = "ADB Wi-Fi (IP:Port):";
$lblWifi.Location = New-Object System.Drawing.Point(20, 207);
$lblWifi.Size = New-Object System.Drawing.Size(115, 22);
$lblWifi.ForeColor = $fgText;
$form.Controls.Add($lblWifi);
$txtWifi = New-Object System.Windows.Forms.TextBox;
$txtWifi.Text = "192.168.1.x:5555";
$txtWifi.Location = New-Object System.Drawing.Point(140, 204);
$txtWifi.Size = New-Object System.Drawing.Size(165, 24);
$txtWifi.BackColor = $bgInput;
$txtWifi.ForeColor = $fgText;
$form.Controls.Add($txtWifi);
Create-Button "Connect" 315 202 80 26 {
$ip = $txtWifi.Text.Trim();
if (-not [string]::IsNullOrWhiteSpace($ip)) {
Run-LocalCommand "adb" "connect $ip";
}
};
Create-Button "Disconnect" 405 202 80 26 {
Run-LocalCommand "adb" "disconnect";
};
Create-Button "Enable TCP/IP 5555 (Requires USB)" 20 237 225 32 {
Run-LocalCommand "adb" "tcpip 5555";
};
Create-Button "Get Device Wi-Fi IP" 260 237 225 32 {
$txtOutput.AppendText(">> Checking Wi-Fi IP address...rn");
$res = Execute-ProcessWithProgress $adbPath "shell ip route" $false;
$txtOutput.AppendText("$resrnrn");
if ($res -match 'src\s+([0-9]+.[0-9]+.[0-9]+.[0-9]+)') {
$detectedIp = $matches.Item(1);
$txtWifi.Text = ($detectedIp + ":5555");
$txtOutput.AppendText(">> Auto-filled IP: " + $detectedIp + ":5555rnrn");
}
};
$lblShell = New-Object System.Windows.Forms.Label;
$lblShell.Text = "ADB Shell Cmd:";
$lblShell.Location = New-Object System.Drawing.Point(20, 285);
$lblShell.Size = New-Object System.Drawing.Size(115, 22);
$lblShell.ForeColor = $fgText;
$form.Controls.Add($lblShell);
$txtShell = New-Object System.Windows.Forms.TextBox;
$txtShell.Text = "getprop ro.product.model";
$txtShell.Location = New-Object System.Drawing.Point(140, 282);
$txtShell.Size = New-Object System.Drawing.Size(255, 24);
$txtShell.BackColor = $bgInput;
$txtShell.ForeColor = $fgText;
$form.Controls.Add($txtShell);
Create-Button "Run Shell" 405 280 80 26 {
$cmd = $txtShell.Text.Trim();
if (-not [string]::IsNullOrWhiteSpace($cmd)) {
Run-LocalCommand "adb" "shell $cmd";
}
};
Create-Button "Open ADB Shell" 20 318 225 30 {
if (-not (Test-Path $adbPath)) {
$txtOutput.AppendText("Error: adb.exe not found.rnrn");
return;
}
Start-Process cmd.exe -ArgumentList "/k "$adbPath" shell";
};
Create-Button "Open Command Prompt (CMD)" 260 318 225 30 {
Start-Process cmd.exe -WorkingDirectory $currentDir;
};
Create-Button "Clear Log" 20 358 465 28 {
$txtOutput.Clear();
$progressBar.Value = 0;
$lblStatus.Text = "Status: Ready";
};
$form.Add_FormClosing({
if (Test-Path $adbPath) {
& $adbPath kill-server 2>&1 | Out-Null;
}
});
[void]$form.ShowDialog();