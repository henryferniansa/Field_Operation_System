import sys
import os
import datetime
import queue
from flask import Flask, render_template, jsonify, request, Response
import firebase_admin
from firebase_admin import credentials, firestore

# ==============================================================================
# MATIKAN PRINT SAAT EXE
# ==============================================================================
if getattr(sys, 'frozen', False):
    sys.stdout = open(os.devnull, 'w')
    sys.stderr = open(os.devnull, 'w')

# ==============================================================================
# PATH HELPER
# ==============================================================================
def resource_path(relative_path):
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

# ==============================================================================
# FLASK
# ==============================================================================
app = Flask(__name__, template_folder="templates", static_folder="static")

# ==============================================================================
# FIREBASE INIT
# ==============================================================================
db = None
try:
    cred_path = resource_path("field_operation_desktop/service_account.json")
    if not os.path.exists(cred_path):
        cred_path = resource_path("service_account.json")

    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    db = firestore.client()
    print("🔥 Firebase Connected")

except Exception as e:
    print("[FATAL] Firebase init gagal:", e)

# ==============================================================================
# GLOBAL CACHE
# ==============================================================================
date_cache = {}          # Cache per tanggal
listeners = []           # SSE clients
user_photo_cache = {}    # Cache foto pengawas
today_listener = None
TODAY_KEY = None

# ==============================================================================
# LOAD USER PHOTOS (1x SAJA)
# ==============================================================================
def load_user_photos():
    global user_photo_cache
    if not db:
        return

    users = db.collection('users').stream()
    temp = {}
    for u in users:
        temp[u.id] = u.to_dict().get('foto_base64')

    user_photo_cache = temp

# ==============================================================================
# SERIALIZE
# ==============================================================================
def serialize_doc(doc):
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

    return {
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
        'created_via': d.get('created_via', 'mobile'),
        'foto': d.get('foto_base64', None),  # 🔥 FIX FOTO JOB
        'foto_pengawas': user_photo_cache.get(d.get('id_pengawas')),
        'tanggal': waktu_str,
        'jam_mulai': jam_str,
        'jam_selesai': jam_selesai_str,
        '_timestamp': waktu_obj
    }

# ==============================================================================
# REALTIME LISTENER HANYA UNTUK HARI INI
# ==============================================================================
def on_today_snapshot(col_snapshot, changes, read_time):
    global date_cache

    temp_list = []
    for doc in col_snapshot:
        temp_list.append(serialize_doc(doc))

    temp_list.sort(
        key=lambda x: x["_timestamp"] or datetime.datetime.min,
        reverse=True
    )

    for item in temp_list:
        item.pop("_timestamp", None)

    date_cache[TODAY_KEY] = temp_list

    for q in listeners:
        q.put("update")

def start_today_listener():
    global TODAY_KEY

    # Hari ini dalam WIB
    now_wib = datetime.datetime.utcnow() + datetime.timedelta(hours=7)
    wib_start = now_wib.replace(hour=0, minute=0, second=0, microsecond=0)

    # Konversi ke UTC
    utc_start = wib_start - datetime.timedelta(hours=7)
    utc_end = utc_start + datetime.timedelta(days=1)

    TODAY_KEY = wib_start.strftime("%Y-%m-%d")

    db.collection('laporan_lapangan') \
        .where('waktu_dibuat', '>=', utc_start) \
        .where('waktu_dibuat', '<', utc_end) \
        .order_by('waktu_dibuat', direction=firestore.Query.DESCENDING) \
        .limit(300) \
        .on_snapshot(on_today_snapshot)
# ==============================================================================
# GET DATA BY DATE (CACHE + FIRESTORE)
# ==============================================================================
def get_data_by_date(date_str):
    if date_str in date_cache:
        return date_cache[date_str]

    # 🔥 Konversi tanggal WIB ke UTC
    wib_start = datetime.datetime.strptime(date_str, "%Y-%m-%d")
    utc_start = wib_start - datetime.timedelta(hours=7)
    utc_end = utc_start + datetime.timedelta(days=1)

    docs = db.collection('laporan_lapangan') \
        .where('waktu_dibuat', '>=', utc_start) \
        .where('waktu_dibuat', '<', utc_end) \
        .order_by('waktu_dibuat', direction=firestore.Query.DESCENDING) \
        .limit(300) \
        .stream()

    temp_list = []
    for doc in docs:
        temp_list.append(serialize_doc(doc))

    temp_list.sort(
        key=lambda x: x["_timestamp"] or datetime.datetime.min,
        reverse=True
    )

    for item in temp_list:
        item.pop("_timestamp", None)

    date_cache[date_str] = temp_list
    return temp_list
# ==============================================================================
# ROUTES
# ==============================================================================
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/get_jobs')
def get_jobs():
    date_str = request.args.get('date')

    if not date_str:
        date_str = TODAY_KEY

    return jsonify(get_data_by_date(date_str))

@app.route('/api/stream')
def stream_events():
    def event_stream(q):
        yield "data: init\n\n"
        try:
            while True:
                msg = q.get()
                yield f"data: {msg}\n\n"
        except GeneratorExit:
            listeners.remove(q)

    q = queue.Queue()
    listeners.append(q)
    return Response(event_stream(q), mimetype="text/event-stream")

# ==============================================================================
# ADD JOB
# ==============================================================================
@app.route('/api/add_job', methods=['POST'])
def add_job():
    data = request.json
    try:
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
            'jabatan_pengawas': "Admin Pusat",
            'lokasi_x': float(data.get('lokasi_x', 0.5)),
            'lokasi_y': float(data.get('lokasi_y', 0.5)),
            'foto_base64': None
        }

        db.collection('laporan_lapangan').add(doc_data)
        return jsonify({'status': 'success'})

    except Exception as e:
        print("[ERROR] Add Job:", e)
        return jsonify({'status': 'error'})

# ==============================================================================
# EDIT JOB
# ==============================================================================
@app.route('/api/edit_job', methods=['POST'])
def edit_job():
    data = request.json
    try:
        job_id = data.get('id')

        update_data = {
            'judul': data['judul'],
            'deskripsi': data['deskripsi'],
            'urgency': data['urgency'],
            'jenis_pekerjaan': data['jenis'],
            'lokasi_manual': data['lokasi_text'],
            'lokasi_x': float(data.get('lokasi_x', 0.5)),
            'lokasi_y': float(data.get('lokasi_y', 0.5))
        }

        db.collection('laporan_lapangan').document(job_id).update(update_data)
        return jsonify({'status': 'success'})

    except Exception as e:
        print("[ERROR] Edit Job:", e)
        return jsonify({'status': 'error'})

# ==============================================================================
# DELETE JOB
# ==============================================================================
@app.route('/api/delete_job/<job_id>', methods=['DELETE'])
def delete_job(job_id):
    try:
        db.collection('laporan_lapangan').document(job_id).delete()
        return jsonify({'status': 'success'})
    except Exception as e:
        print("[ERROR] Delete Job:", e)
        return jsonify({'status': 'error'})

# ==============================================================================
# STARTUP
# ==============================================================================
if db:
    load_user_photos()
    start_today_listener()

if __name__ == '__main__':
    app.run(debug=True, port=5000)