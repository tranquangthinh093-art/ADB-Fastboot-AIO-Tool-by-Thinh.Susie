\Add-Type -AssemblyName System.Windows.Forms;
Add-Type -AssemblyName System.Drawing;

$dwmCode = @"
using System;
using System.Runtime.InteropServices;
public class DwmApi {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@
Add-Type -TypeDefinition $dwmCode -Language CSharp;

$exePathSelf = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName;
$currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $exePathSelf };
$adbPath = Join-Path $currentDir "adb.exe";
$fastbootPath = Join-Path $currentDir "fastboot.exe";

$cBlack    = [System.Drawing.Color]::Black;
$cWhite    = [System.Drawing.Color]::White;
$cYellow   = [System.Drawing.Color]::Yellow;
$cOrange   = [System.Drawing.Color]::FromArgb(255, 160, 0);
$cSusie    = [System.Drawing.Color]::FromArgb(234, 121, 200);
$cWeird    = [System.Drawing.Color]::FromArgb(100, 220, 255);
$cDarkRed  = [System.Drawing.Color]::FromArgb(90, 0, 30);
$cDarkBox  = [System.Drawing.Color]::FromArgb(15, 15, 15);
$fontGame  = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Bold);
$fontSmall = New-Object System.Drawing.Font("Consolas", 8.5, [System.Drawing.FontStyle]::Bold);
$fontLog   = New-Object System.Drawing.Font("Consolas", 9.5);
$penWhite  = New-Object System.Drawing.Pen($cWhite, 3);
$penSusie  = New-Object System.Drawing.Pen($cSusie, 2);

$script:hpPercent = 100;
$script:hpColor = $cSusie;

function Play-Sfx ($type) {
    $action = [Action]{
        switch ($type) {
            "move"   { [Console]::Beep(440, 20) }
            "select" { [Console]::Beep(660, 35); [Console]::Beep(880, 45) }
            "save"   { [Console]::Beep(523, 40); [Console]::Beep(659, 40); [Console]::Beep(784, 50); [Console]::Beep(1046, 80) }
            "warn"   { [Console]::Beep(220, 70); [Console]::Beep(160, 110) }
            "weird"  { [Console]::Beep(330, 60); [Console]::Beep(247, 60); [Console]::Beep(185, 120) }
        }
    }.GetNewClosure();
    [void][System.Threading.Tasks.Task]::Run($action);
}

$form = New-Object System.Windows.Forms.Form;
$form.Text = "DELTARUNE // ADB & Fastboot AIO - Thinh.Susie";
$form.Size = New-Object System.Drawing.Size(520, 755);
$form.StartPosition = "CenterScreen";
$form.FormBorderStyle = "FixedDialog";
$form.MaximizeBox = $false;
$form.BackColor = $cBlack;
$form.ForeColor = $cWhite;
$form.AllowDrop = $true;

$form.Add_HandleCreated({
    $useDarkMode = 1;
    [void][DwmApi]::DwmSetWindowAttribute($form.Handle, 20, [ref]$useDarkMode, 4);
});

$form.Add_Paint({
    param($s, $e)
    $e.Graphics.DrawRectangle($penWhite, 10, 10, 484, 395);
    $e.Graphics.DrawRectangle($penSusie, 10, 415, 484, 34);
    $e.Graphics.DrawRectangle($penWhite, 10, 458, 484, 245);
});

$lblParty = New-Object System.Windows.Forms.Label;
$lblParty.Text = "SUSIE   LV 2   STATUS: READY";
$lblParty.Location = New-Object System.Drawing.Point(20, 423);
$lblParty.Size = New-Object System.Drawing.Size(270, 18);
$lblParty.Font = $fontGame;
$lblParty.ForeColor = $cSusie;
$form.Controls.Add($lblParty);

$lblHpText = New-Object System.Windows.Forms.Label;
$lblHpText.Text = "HP";
$lblHpText.Location = New-Object System.Drawing.Point(295, 423);
$lblHpText.Size = New-Object System.Drawing.Size(25, 18);
$lblHpText.Font = $fontGame;
$lblHpText.ForeColor = $cYellow;
$form.Controls.Add($lblHpText);

$hpPanel = New-Object System.Windows.Forms.Panel;
$hpPanel.Location = New-Object System.Drawing.Point(325, 424);
$hpPanel.Size = New-Object System.Drawing.Size(158, 16);
$hpPanel.BackColor = $cDarkRed;
$hpPanel.Add_Paint({
    param($s, $e)
    $fillWidth = [int](($hpPanel.Width * $script:hpPercent) / 100);
    if ($fillWidth -gt 0) {
        $brush = New-Object System.Drawing.SolidBrush($script:hpColor);
        $e.Graphics.FillRectangle($brush, 0, 0, $fillWidth, $hpPanel.Height);
        $brush.Dispose();
    }
});
$form.Controls.Add($hpPanel);

function Update-HpBar ($percent, $color) {
    $script:hpPercent = $percent;
    $script:hpColor = $color;
    $hpPanel.Invalidate();
}

$txtOutput = New-Object System.Windows.Forms.TextBox;
$txtOutput.Location = New-Object System.Drawing.Point(20, 468);
$txtOutput.Size = New-Object System.Drawing.Size(465, 225);
$txtOutput.Multiline = $true;
$txtOutput.ScrollBars = "Vertical";
$txtOutput.ReadOnly = $true;
$txtOutput.BorderStyle = "None";
$txtOutput.BackColor = $cBlack;
$txtOutput.ForeColor = $cWhite;
$txtOutput.Font = $fontLog;
$txtOutput.Text = "* You encountered ADB & Fastboot AIO Tool!`r`n* Drag & drop APK/IMG/ZIP or select an ACT.`r`n`r`n";
$form.Controls.Add($txtOutput);

function Show-DeltaruneDialog ($titleText, $bodyText, $isWeird = $false) {
    if ($isWeird) { Play-Sfx "weird" } else { Play-Sfx "warn" }
    $dlg = New-Object System.Windows.Forms.Form;
    $dlg.Text = $titleText;
    $dlg.Size = New-Object System.Drawing.Size(430, 215);
    $dlg.StartPosition = "CenterParent";
    $dlg.FormBorderStyle = "None";
    $dlg.BackColor = $cBlack;
    $dlg.ForeColor = $cWhite;

    $borderCol = if ($isWeird) { $cWeird } else { $cWhite };
    $dlg.Add_Paint({
        param($s, $e)
        $pen = New-Object System.Drawing.Pen($borderCol, 3);
        $e.Graphics.DrawRectangle($pen, 2, 2, $dlg.Width - 5, $dlg.Height - 5);
        $pen.Dispose();
    }.GetNewClosure());

    $lblMsg = New-Object System.Windows.Forms.Label;
    $lblMsg.Text = "* " + $bodyText;
    $lblMsg.Location = New-Object System.Drawing.Point(22, 20);
    $lblMsg.Size = New-Object System.Drawing.Size(386, 120);
    $lblMsg.Font = $fontGame;
    $lblMsg.ForeColor = if ($isWeird) { $cWeird } else { $cWhite };
    $dlg.Controls.Add($lblMsg);

    $btnProceed = New-Object System.Windows.Forms.Button;
    $btnProceed.Text = "Proceed";
    $btnProceed.Location = New-Object System.Drawing.Point(65, 155);
    $btnProceed.Size = New-Object System.Drawing.Size(120, 36);
    $btnProceed.FlatStyle = "Flat";
    $btnProceed.FlatAppearance.BorderColor = $cYellow;
    $btnProceed.FlatAppearance.BorderSize = 2;
    $btnProceed.ForeColor = $cYellow;
    $btnProceed.Font = $fontGame;
    $btnProceed.DialogResult = [System.Windows.Forms.DialogResult]::Yes;
    $btnProceed.Add_MouseEnter({ Play-Sfx "move" });
    $dlg.Controls.Add($btnProceed);

    $btnCancel = New-Object System.Windows.Forms.Button;
    $btnCancel.Text = "Do not";
    $btnCancel.Location = New-Object System.Drawing.Point(240, 155);
    $btnCancel.Size = New-Object System.Drawing.Size(120, 36);
    $btnCancel.FlatStyle = "Flat";
    $btnCancel.FlatAppearance.BorderColor = $cWhite;
    $btnCancel.FlatAppearance.BorderSize = 2;
    $btnCancel.ForeColor = $cWhite;
    $btnCancel.Font = $fontGame;
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::No;
    $btnCancel.Add_MouseEnter({ Play-Sfx "move" });
    $dlg.Controls.Add($btnCancel);

    return ($dlg.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::Yes);
}

function Execute-ProcessWithProgress ($exePath, $arguments) {
    if (-not (Test-Path $exePath)) {
        $txtOutput.AppendText("* Error: File not found at $exePath`r`n`r`n");
        $lblParty.Text = "SUSIE   LV 2   STATUS: ERROR";
        $lblParty.ForeColor = $cYellow;
        Update-HpBar 15 $cYellow;
        return "";
    }

    $lblParty.Text = "SUSIE   LV 2   STATUS: ACTING...";
    $lblParty.ForeColor = $cSusie;
    Update-HpBar 30 $cOrange;
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
    [void]$process.Start();

    $stdoutTask = $process.StandardOutput.ReadToEndAsync();
    $stderrTask = $process.StandardError.ReadToEndAsync();

    $prog = 30;
    while (-not $process.HasExited) {
        if ($prog -lt 90) {
            $prog += 4;
            Update-HpBar $prog $cOrange;
        }
        [System.Windows.Forms.Application]::DoEvents();
        Start-Sleep -Milliseconds 50;
    }

    $process.WaitForExit();
    $outText = $stdoutTask.Result;
    $errText = $stderrTask.Result;
    $combined = ($outText + "`r`n" + $errText).Trim();

    if ($process.ExitCode -ne 0 -or $combined -match "error:|failed|cannot") {
        $lblParty.Text = "SUSIE   LV 2   STATUS: HURT!";
        $lblParty.ForeColor = $cYellow;
        Update-HpBar 25 $cYellow;
    } else {
        $lblParty.Text = "SUSIE   LV 2   STATUS: READY";
        $lblParty.ForeColor = $cSusie;
        Update-HpBar 100 $cSusie;
    }
    [System.Windows.Forms.Application]::DoEvents();

    return $combined;
}

function Run-LocalCommand ($toolType, $argsList) {
    $exeToRun = if ($toolType -eq "adb") { $adbPath } else { $fastbootPath };
    $txtOutput.AppendText("* Susie used $toolType $argsList!`r`n");
    
    $result = Execute-ProcessWithProgress $exeToRun $argsList;
    if ([string]::IsNullOrWhiteSpace($result)) {
        $txtOutput.AppendText("* Done.`r`n`r`n");
    } else {
        $txtOutput.AppendText("$result`r`n`r`n");
    }
    return $result;
}

function Create-Button ($text, $x, $y, $w, $h, $action, $styleType = "normal", $useSmallFont = $false) {
    $btn = New-Object System.Windows.Forms.Button;
    $btn.Text = $text;
    $btn.Location = New-Object System.Drawing.Point($x, $y);
    $btn.Size = New-Object System.Drawing.Size($w, $h);
    $btn.BackColor = $cBlack;
    
    $baseColor = switch ($styleType) {
        "danger" { $cSusie }
        "weird"  { $cWeird }
        "save"   { $cYellow }
        default  { $cOrange }
    };
    
    $btn.ForeColor = $baseColor;
    $btn.Font = if ($useSmallFont) { $fontSmall } else { $fontGame };
    $btn.FlatStyle = "Flat";
    $btn.FlatAppearance.BorderSize = 2;
$btn.FlatAppearance.BorderColor = $baseColor;
$btn.FlatAppearance.MouseOverBackColor = $cDarkBox;
$btn.Tag = $baseColor;
$btn.Add_MouseEnter({
Play-Sfx "move";
$this.ForeColor = $cYellow;
$this.FlatAppearance.BorderColor = $cYellow;
});
$btn.Add_MouseLeave({
$this.ForeColor = $this.Tag;
$this.FlatAppearance.BorderColor = $this.Tag;
});
$btn.Add_Click({
if ($styleType -ne "save") { Play-Sfx "select"; }
& $action;
}.GetNewClosure());
$form.Controls.Add($btn);
}
Create-Button "Check ADB" 20 22 110 35 { [void](Run-LocalCommand "adb" "devices -l") };
Create-Button "Reboot Sys" 138 22 110 35 { [void](Run-LocalCommand "adb" "reboot") };
Create-Button "Recovery" 256 22 110 35 { [void](Run-LocalCommand "adb" "reboot recovery") };
Create-Button "Bootloader" 374 22 110 35 { [void](Run-LocalCommand "adb" "reboot bootloader") };
Create-Button "Fastbootd" 20 65 110 35 { [void](Run-LocalCommand "adb" "reboot fastboot") };
Create-Button "Check FB" 138 65 110 35 { [void](Run-LocalCommand "fastboot" "devices") };
Create-Button "FB Reboot" 256 65 110 35 { [void](Run-LocalCommand "fastboot" "reboot") };
Create-Button "BL Status" 374 65 110 35 { [void](Run-LocalCommand "fastboot" "getvar all") };
Create-Button "UNLOCK BOOTLOADER" 20 108 228 35 {
if (Show-DeltaruneDialog "WARNING" "Unlocking the bootloader will ERASE ALL DATA on your device.rnrnAre you sure you want to continue?") {
[void](Run-LocalCommand "fastboot" "flashing unlock");
}
} "danger";
Create-Button "RELOCK BOOTLOADER" 256 108 228 35 {
if (Show-DeltaruneDialog "WARNING" "Relocking the bootloader may BRICK your device if modified firmware is installed.rnrnProceed anyway?") {
[void](Run-LocalCommand "fastboot" "flashing lock");
}
} "danger";
Create-Button "Check Slot" 20 151 110 35 {
[void](Run-LocalCommand "fastboot" "getvar current-slot");
};
Create-Button "Slot A (Normal)" 138 151 168 35 {
if (Show-DeltaruneDialog "SAVE FILE 1" "Switch active partition to SLOT A (Normal Route)?") {
[void](Run-LocalCommand "fastboot" "--set-active=a");
}
};
Create-Button "Slot B (Weird)" 314 151 170 35 {
if (Show-DeltaruneDialog "WEIRD ROUTE" "Switch active partition to SLOT B (Weird Route)?rnrnProceed?" $true) {
[void](Run-LocalCommand "fastboot" "--set-active=b");
}
} "weird";
$cmbPart = New-Object System.Windows.Forms.ComboBox;
$cmbPart.Location = New-Object System.Drawing.Point(256, 200);
$cmbPart.Size = New-Object System.Drawing.Size(110, 28);
$cmbPart.Font = $fontGame;
$cmbPart.BackColor = $cBlack;
$cmbPart.ForeColor = $cWhite;
$cmbPart.FlatStyle = "Flat";
[void]$cmbPart.Items.AddRange(@("recovery", "boot", "init_boot", "vbmeta", "vendor_boot", "system", "super"));
$cmbPart.SelectedIndex = 0;
$form.Controls.Add($cmbPart);
Create-Button "Install APK" 20 194 110 35 {
$ofd = New-Object System.Windows.Forms.OpenFileDialog;
$ofd.Filter = "APK Files (.apk)|.apk";
if ($ofd.ShowDialog() -eq "OK") {
[void](Run-LocalCommand "adb" ('install -r "' + $ofd.FileName + '"'));
}
};
Create-Button "ADB Sideload" 138 194 110 35 {
$ofd = New-Object System.Windows.Forms.OpenFileDialog;
$ofd.Filter = "ZIP Packages (.zip)|.zip";
if ($ofd.ShowDialog() -eq "OK") {
[void](Run-LocalCommand "adb" ('sideload "' + $ofd.FileName + '"'));
}
};
Create-Button "Flash IMG" 374 194 110 35 {
$ofd = New-Object System.Windows.Forms.OpenFileDialog;
$ofd.Filter = "Image Files (.img)|.img";
if ($ofd.ShowDialog() -eq "OK") {
$part = $cmbPart.Text;
if (Show-DeltaruneDialog "FLASH IMAGE" "Flash $($ofd.SafeFileName) to [$part] partition?rnrnProceed?") {
[void](Run-LocalCommand "fastboot" ('flash ' + $part + ' "' + $ofd.FileName + '"'));
}
}
};
$lblWifi = New-Object System.Windows.Forms.Label;
$lblWifi.Text = "WI-FI IP:";
$lblWifi.Location = New-Object System.Drawing.Point(20, 244);
$lblWifi.Size = New-Object System.Drawing.Size(75, 20);
$lblWifi.Font = $fontSmall;
$lblWifi.ForeColor = $cWhite;
$form.Controls.Add($lblWifi);
$txtIp = New-Object System.Windows.Forms.TextBox;
$txtIp.Text = "192.168.1.x:5555";
$txtIp.Location = New-Object System.Drawing.Point(98, 241);
$txtIp.Size = New-Object System.Drawing.Size(170, 24);
$txtIp.Font = $fontSmall;
$txtIp.BackColor = $cBlack;
$txtIp.ForeColor = $cYellow;
$txtIp.BorderStyle = "FixedSingle";
$txtIp.Add_KeyDown({
param($s, $e)
if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
$e.SuppressKeyPress = $true;
Play-Sfx "select";
[void](Run-LocalCommand "adb" "connect $($txtIp.Text)");
}
});
$form.Controls.Add($txtIp);
Create-Button "Connect" 276 237 100 30 {
[void](Run-LocalCommand "adb" "connect $($txtIp.Text)");
} "normal" $true;
Create-Button "Disconnect" 384 237 100 30 {
[void](Run-LocalCommand "adb" "disconnect $($txtIp.Text)");
} "normal" $true;
Create-Button "Enable TCP/IP 5555" 20 273 228 30 {
[void](Run-LocalCommand "adb" "tcpip 5555");
};
Create-Button "Get Wi-Fi IP" 256 273 228 30 {
$out = Run-LocalCommand "adb" "shell ip route";
if ($out -match "src\s+(\d+.\d+.\d+.\d+)") {
$txtIp.Text = $Matches + ":5555";
$txtOutput.AppendText("* Auto-filled IP: $($txtIp.Text)rnrn");
}
};
$lblShell = New-Object System.Windows.Forms.Label;
$lblShell.Text = "SHELL CMD:";
$lblShell.Location = New-Object System.Drawing.Point(20, 316);
$lblShell.Size = New-Object System.Drawing.Size(80, 20);
$lblShell.Font = $fontSmall;
$lblShell.ForeColor = $cWhite;
$form.Controls.Add($lblShell);
$txtCmd = New-Object System.Windows.Forms.TextBox;
$txtCmd.Text = "getprop ro.product.model";
$txtCmd.Location = New-Object System.Drawing.Point(103, 313);
$txtCmd.Size = New-Object System.Drawing.Size(273, 24);
$txtCmd.Font = $fontSmall;
$txtCmd.BackColor = $cBlack;
$txtCmd.ForeColor = $cYellow;
$txtCmd.BorderStyle = "FixedSingle";
$txtCmd.Add_KeyDown({
param($s, $e)
if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
$e.SuppressKeyPress = $true;
if (-not [string]::IsNullOrWhiteSpace($txtCmd.Text)) {
Play-Sfx "select";
[void](Run-LocalCommand "adb" "shell $($txtCmd.Text)");
}
}
});
$form.Controls.Add($txtCmd);
Create-Button "ACT" 384 309 100 30 {
if (-not [string]::IsNullOrWhiteSpace($txtCmd.Text)) {
[void](Run-LocalCommand "adb" "shell $($txtCmd.Text)");
}
};
Create-Button "Open CMD" 20 352 148 38 {
Start-Process "cmd.exe" -ArgumentList ('/k cd /d "' + $currentDir + '"');
};
Create-Button "SAVE" 176 352 148 38 {
$sfd = New-Object System.Windows.Forms.SaveFileDialog;
$sfd.Filter = "Text Log (.txt)|.txt";
$sfd.FileName = "Deltarune_ADB_Log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt";
if ($sfd.ShowDialog() -eq "OK") {
[System.IO.File]::WriteAllText($sfd.FileName, $txtOutput.Text);
Play-Sfx "save";
$txtOutput.AppendText("* File saved.rnrn");
}
} "save";
Create-Button "MERCY (Clear)" 332 352 152 38 {
$txtOutput.Text = "* You spared the log output.rn* Select an ACT to begin.rnrn";
$lblParty.Text = "SUSIE   LV 2   STATUS: READY";
$lblParty.ForeColor = $cSusie;
Update-HpBar 100 $cSusie;
};
$form.Add_DragEnter({
param($s, $e)
if ($e.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
$e.Effect = [Windows.Forms.DragDropEffects]::Copy;
}
});
$form.Add_DragDrop({
param($s, $e)
$files = $e.Data.GetData([Windows.Forms.DataFormats]::FileDrop);
if ($files.Count -gt 0) {
$filePath = $files;
$ext = [System.IO.Path]::GetExtension($filePath).ToLower();
$fileName = [System.IO.Path]::GetFileName($filePath);
if ($ext -eq ".apk") {
if (Show-DeltaruneDialog "ITEM FOUND" "Install dropped APK [$fileName]?rnrnProceed?") {
[void](Run-LocalCommand "adb" ('install -r "' + $filePath + '"'));
}
} elseif ($ext -eq ".zip") {
if (Show-DeltaruneDialog "ITEM FOUND" "Sideload dropped ZIP [$fileName]?rnrnProceed?") {
[void](Run-LocalCommand "adb" ('sideload "' + $filePath + '"'));
}
} elseif ($ext -eq ".img") {
$part = $cmbPart.Text;
if (Show-DeltaruneDialog "ITEM FOUND" "Flash dropped IMG [$fileName] to [$part]?rnrnProceed?") {
[void](Run-LocalCommand "fastboot" ('flash ' + $part + ' "' + $filePath + '"'));
}
} else {
Play-Sfx "warn";
$txtOutput.AppendText("* Unsupported item: $fileName (Only .apk, .zip, .img)rnrn");
}
}
});
[void]$form.ShowDialog();