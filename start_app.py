import os, sys, subprocess, socket, qrcode

# Set UTF-8 encoding for Windows terminal
try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        return s.getsockname()[0]
    except Exception:
        return '127.0.0.1'
    finally:
        s.close()

ip = get_ip()
port = 5050
url = f'http://{ip}:{port}'

print('\n' + '='*60)
print('  🚀 KARMARIDE LIVE SERVER — SCAN TO OPEN ON PHONE')
print('='*60 + '\n')

# Generate local offline QR code matrix
qr = qrcode.QRCode(border=2)
qr.add_data(url)
qr.make(fit=True)
matrix = qr.get_matrix()
for row in matrix:
    line = ''.join('██' if cell else '  ' for cell in row)
    print('  ' + line)

print('\n' + '='*60)
print(f'  📱 Phone URL:  {url}')
print(f'  💻 PC Browser: http://localhost:{port}')
print('='*60 + '\n')
print('Starting Flutter Dev Server (Press "r" for hot-reload, "q" to quit)...\n')
sys.stdout.flush()

# Start flutter web server in CorporatePoolingApp
app_dir = r'C:\Users\shiva\CorporatePoolingApp'
subprocess.run(['flutter.bat', 'run', '-d', 'web-server', '--web-hostname', '0.0.0.0', '--web-port', str(port)], cwd=app_dir, shell=True)
