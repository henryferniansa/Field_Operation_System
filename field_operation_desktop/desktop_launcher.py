import webview
import threading
import time
import sys  
# Import aplikasi Flask yang sudah Bapak buat tadi (nama filenya app.py)
from app import app 


def start_server():
    # Menjalankan server Flask di background
    app.run(port=5000)

if __name__ == '__main__':
    # 1. Jalankan Flask di Thread terpisah (biar tidak memblokir aplikasi)
    t = threading.Thread(target=start_server)
    t.daemon = True
    t.start()
    
    # Tunggu sebentar agar server Flask siap
    time.sleep(1)

    # 2. Buka Jendela Desktop (Bukan Browser)
    # Ini akan membuat jendela aplikasi native seperti software biasa
    webview.create_window(
        "Monitoring Dashboard - Field Operations", # Judul Jendela
        "http://127.0.0.1:5000",                   # Alamat Flask
        width=1200,
        height=800,
        resizable=True,
        maximized=True
    )

    # 3. Mulai Aplikasi
    webview.start()
    sys.exit()