import sys
import os
import datetime
from flask import Flask, render_template, jsonify, request
import firebase_admin
from firebase_admin import credentials, firestore, messaging

# ==============================================================================
# 🛡️ MATIKAN PRINT SAAT JADI .EXE (AMAN --windowed)
# ==============================================================================
if getattr(sys, 'frozen', False):
    sys.stdout = open(os.devnull, 'w')
    sys.stderr = open(os.devnull, 'w')

# ==============================================================================
# PATH HELPER (WAJIB UNTUK PYINSTALLER)
# ==============================================================================
def resource_path(relative_path):
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

# ==============================================================================
# FLASK APP
# ==============================================================================
app = Flask(
    __name__,
    template_folder="templates",
    static_folder="static"
)

# ==============================================================================
# FIREBASE INIT (MINIMAL FIX, BEHAVIOUR TETAP)
# ==============================================================================
db = None
try:
    cred_path = resource_path("service_account.json")
    if not os.path.exists(cred_path):
        cred_path = resource_path("service_account.json")

    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    db = firestore.client()
except Exception as e:
    print("[FATAL] Firebase init gagal:", e)

# ==============================================================================
# ROUTES
# ==============================================================================
@app.route('/')
def index():
    return render_template('index.html')

# ------------------------------------------------------------------------------
# GET JOBS
# ------------------------------------------------------------------------------
@app.route('/api/get_jobs')
def get_jobs():
    if not db:
        return jsonify([])

    try:
        docs = db.collection('laporan_lapangan').order_by(
            'waktu_dibuat', direction=firestore.Query.DESCENDING
        ).get()

        users_ref = db.collection('users').get()
        user_photos = {}
        for u in users_ref:
            udata = u.to_dict()
            user_photos[u.id] = udata.get('foto_base64', None)

        data_list = []
        for doc in docs:
            d = doc.to_dict()

            waktu_obj = d.get('waktu_dibuat')
            waktu_str, jam_str = "-", "-"

            if waktu_obj and hasattr(waktu_obj, 'date'):
                wib_time = waktu_obj + datetime.timedelta(hours=7)
                waktu_str = wib_time.strftime('%Y-%m-%d')
                jam_str = wib_time.strftime('%H:%M')

            selesai_obj = d.get('waktu_selesai')
            jam_selesai_str = None
            if selesai_obj and hasattr(selesai_obj, 'date'):
                wib_selesai = selesai_obj + datetime.timedelta(hours=7)
                jam_selesai_str = wib_selesai.strftime('%H:%M')

            id_pengawas = d.get('id_pengawas')
            foto_pengawas = user_photos.get(id_pengawas)

            data_list.append({
                'id': doc.id,
                'judul': d.get('judul', '-'),
                'deskripsi': d.get('deskripsi', '-'),
                'status': d.get('status_pengerjaan', 'Pending'),
                'urgency': d.get('urgency', 'Normal'),
                'jenis': d.get('jenis_pekerjaan', 'Umum'),
                'lokasi_text': d.get('lokasi_manual', '-'),
                'nama': d.get('nama_pengawas', '-'),
                'jabatan': d.get('jabatan_pengawas', '-'),
                'lokasi_x': d.get('lokasi_x', 0.5),
                'lokasi_y': d.get('lokasi_y', 0.5),
                'foto': d.get('foto_base64', None),
                'foto_pengawas': foto_pengawas,
                'created_via': d.get('created_via', 'mobile'),
                'tanggal': waktu_str,
                'jam_mulai': jam_str,
                'jam_selesai': jam_selesai_str
            })

        return jsonify(data_list)

    except Exception as e:
        print("[ERROR] Fetching Jobs:", e)
        return jsonify([])

# ------------------------------------------------------------------------------
# ADD JOB + NOTIFICATION
# ------------------------------------------------------------------------------
@app.route('/api/add_job', methods=['POST'])
def add_job():
    if not db:
        return jsonify({'status': 'error', 'msg': 'Database Error'})

    data = request.json

    try:
        loc_x = float(data.get('lokasi_x', 0.5))
        loc_y = float(data.get('lokasi_y', 0.5))

        doc_data = {
            'judul': data['judul'],
            'deskripsi': data['deskripsi'],
            'urgency': data['urgency'],
            'jenis_pekerjaan': data['jenis'],
            'lokasi_manual': data['lokasi_text'],
            'status_pengerjaan': 'Pending',
            'created_via': 'desktop',
            'waktu_dibuat': datetime.datetime.utcnow(),
            'id_pengawas': "",
            'nama_pengawas': "-",
            'badge_pengawas': "-",
            'jabatan_pengawas': "Admin Pusat",
            'lokasi_x': loc_x,
            'lokasi_y': loc_y,
            'foto_base64': None
        }

        db.collection('laporan_lapangan').add(doc_data)

        # ---------------- NOTIFIKASI ----------------
        try:
            users_ref = db.collection('users').stream()
            unique_tokens = set()

            for user in users_ref:
                token = user.to_dict().get('fcm_token')
                if token and len(str(token)) > 10:
                    unique_tokens.add(token)

            tokens_list = list(unique_tokens)

            if tokens_list:
                notif_title = "Pekerjaan Baru Masuk"
                if data['urgency'] == 'Urgent':
                    notif_title = "[URGENT] Pekerjaan Baru!"

                msg = messaging.MulticastMessage(
                    notification=messaging.Notification(
                        title=notif_title,
                        body=f"{data['judul']} - {data['lokasi_text']}"
                    ),
                    webpush=messaging.WebpushConfig(
                        notification=messaging.WebpushNotification(
                            title=notif_title,
                            body=f"{data['judul']} - {data['lokasi_text']}",
                            icon='/icons/Icon-192.png',
                            require_interaction=True
                        ),
                        fcm_options=messaging.WebpushFCMOptions(
                            link='https://field-operation-mobile.web.app/'
                        )
                    ),
                    android=messaging.AndroidConfig(
                        priority='high',
                        notification=messaging.AndroidNotification(
                            sound='default',
                            click_action='FLUTTER_NOTIFICATION_CLICK'
                        )
                    ),
                    tokens=tokens_list
                )

                messaging.send_each_for_multicast(msg)

        except Exception as notif_error:
            print("[WARN] Gagal kirim notifikasi:", notif_error)

        return jsonify({'status': 'success'})

    except Exception as e:
        print("[ERROR] Add Job:", e)
        return jsonify({'status': 'error'})

# ------------------------------------------------------------------------------
# EDIT JOB
# ------------------------------------------------------------------------------
@app.route('/api/edit_job', methods=['POST'])
def edit_job():
    if not db:
        return jsonify({'status': 'error'})

    data = request.json
    try:
        job_id = data.get('id')
        loc_x = float(data.get('lokasi_x', 0.5))
        loc_y = float(data.get('lokasi_y', 0.5))

        update_data = {
            'judul': data['judul'],
            'deskripsi': data['deskripsi'],
            'urgency': data['urgency'],
            'jenis_pekerjaan': data['jenis'],
            'lokasi_manual': data['lokasi_text'],
            'lokasi_x': loc_x,
            'lokasi_y': loc_y
        }

        db.collection('laporan_lapangan').document(job_id).update(update_data)
        return jsonify({'status': 'success'})

    except Exception as e:
        print("[ERROR] Edit Job:", e)
        return jsonify({'status': 'error'})

# ------------------------------------------------------------------------------
# DELETE JOB
# ------------------------------------------------------------------------------
@app.route('/api/delete_job/<job_id>', methods=['DELETE'])
def delete_job(job_id):
    if not db:
        return jsonify({'status': 'error'})

    try:
        db.collection('laporan_lapangan').document(job_id).delete()
        return jsonify({'status': 'success'})
    except Exception as e:
        print("[ERROR] Delete Job:", e)
        return jsonify({'status': 'error'})

# ==============================================================================
# LOCAL RUN (OPTIONAL)
# ==============================================================================
if __name__ == '__main__':
    app.run(debug=True, port=5000)
