import streamlit as st
import sqlite3
import os
import io
import time
import uuid
import hashlib
from datetime import datetime
import pandas as pd
from PIL import Image

# ═══════════════════════════════════════════════════════════════
# PAGE CONFIG
# ═══════════════════════════════════════════════════════════════
st.set_page_config(
    page_title="Internal Cloud - Web App",
    page_icon="☁️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ═══════════════════════════════════════════════════════════════
# CUSTOM CSS (Exact Pine Green #064e43 Theme & Clean Aesthetics)
# ═══════════════════════════════════════════════════════════════
st.markdown("""
<style>
    /* Global Styles */
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap');
    
    html, body, [class*="css"] {
        font-family: 'Plus Jakarta Sans', sans-serif;
    }
    
    /* Sidebar Styling */
    [data-testid="stSidebar"] {
        background-color: #064e43 !important;
        color: #ffffff !important;
    }
    
    [data-testid="stSidebar"] * {
        color: #e6fffa !important;
    }
    
    [data-testid="stSidebar"] .stButton > button {
        background-color: #0b594d !important;
        color: #ffffff !important;
        border: 1px solid rgba(255,255,255,0.1) !important;
        border-radius: 8px !important;
        width: 100% !important;
        font-weight: 600 !important;
    }
    
    [data-testid="stSidebar"] .stButton > button:hover {
        background-color: #0e6356 !important;
        border-color: #34d399 !important;
    }

    /* Chat bubble cards */
    .chat-bubble {
        background-color: #e2f7db;
        border-radius: 12px;
        padding: 12px 16px;
        margin-bottom: 12px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06);
        color: #111827;
        border-left: 4px solid #059669;
    }
    
    .chat-meta {
        font-size: 11px;
        color: #6b7280;
        margin-top: 4px;
        text-align: right;
    }
    
    .file-chip {
        display: flex;
        align-items: center;
        gap: 10px;
        background: #ffffff;
        padding: 10px 14px;
        border-radius: 8px;
        margin-bottom: 8px;
        border: 1px solid #e5e7eb;
    }
    
    .status-badge {
        background: #0b594d;
        padding: 10px;
        border-radius: 8px;
        border: 1px solid rgba(255,255,255,0.15);
        margin-bottom: 16px;
    }
</style>
""", unsafe_allow_html=True)

# ═══════════════════════════════════════════════════════════════
# DATABASE & STORAGE INITIALIZATION
# ═══════════════════════════════════════════════════════════════
DATA_DIR = os.path.join(os.path.dirname(__file__), "server", "data")
UPLOADS_DIR = os.path.join(DATA_DIR, "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)
DB_PATH = os.path.join(DATA_DIR, "internal-cloud.db")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            display_name TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            body TEXT,
            ts INTEGER NOT NULL
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS files (
            id TEXT PRIMARY KEY,
            message_id TEXT,
            user_id TEXT NOT NULL,
            original_name TEXT NOT NULL,
            stored_name TEXT NOT NULL,
            mime TEXT,
            size_bytes INTEGER NOT NULL,
            category TEXT NOT NULL,
            ts INTEGER NOT NULL,
            quarantined INTEGER DEFAULT 0
        )
    """)
    conn.commit()
    conn.close()

init_db()

def hash_pass(p):
    return hashlib.sha256(p.encode()).hexdigest()

def get_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

# ═══════════════════════════════════════════════════════════════
# SESSION STATE & AUTH
# ═══════════════════════════════════════════════════════════════
if "user" not in st.session_state:
    st.session_state.user = None

def get_category(filename, mime=""):
    ext = filename.lower().split(".")[-1] if "." in filename else ""
    if ext in ["jpg", "jpeg", "png", "gif", "webp", "bmp"] or mime.startswith("image/"):
        return "image"
    elif ext in ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv"]:
        return "document"
    elif ext in ["zip", "rar", "7z", "tar", "gz"]:
        return "archive"
    return "other"

# ═══════════════════════════════════════════════════════════════
# AUTH SCREEN
# ═══════════════════════════════════════════════════════════════
if not st.session_state.user:
    st.markdown("<h1 style='text-align: center; color: #064e43;'>☁️ Internal Cloud</h1>", unsafe_allow_html=True)
    st.markdown("<p style='text-align: center; color: #4b5563;'>Penyimpanan & Transfer File Berbasis Chat antara PC dan HP</p>", unsafe_allow_html=True)
    
    col_l, col_m, col_r = st.columns([1, 2, 1])
    with col_m:
        tab_login, tab_reg = st.tabs(["🔑 Masuk", "📝 Daftar Akun"])
        
        with tab_login:
            with st.form("login_form"):
                u = st.text_input("Username", key="l_user")
                p = st.text_input("Password", type="password", key="l_pass")
                submitted = st.form_submit_button("Masuk ke Akun", use_container_width=True)
                
                if submitted:
                    conn = get_db()
                    user = conn.execute("SELECT * FROM users WHERE username = ?", (u.strip(),)).fetchone()
                    conn.close()
                    
                    if user and (user["password_hash"] == hash_pass(p) or user["password_hash"] == p):
                        st.session_state.user = dict(user)
                        st.success(f"Selamat datang, {user['display_name']}!")
                        st.rerun()
                    else:
                        st.error("Username atau password salah!")

        with tab_reg:
            with st.form("reg_form"):
                d_name = st.text_input("Nama Tampilan", placeholder="Nama Lengkap Anda")
                new_u = st.text_input("Username Baru", placeholder="Minimal 3 karakter")
                new_p = st.text_input("Password Baru", type="password", placeholder="Minimal 4 karakter")
                reg_sub = st.form_submit_button("Buat Akun Baru", use_container_width=True)
                
                if reg_sub:
                    if len(new_u) < 3 or len(new_p) < 4 or not d_name:
                        st.error("Lengkapi semua data dengan benar!")
                    else:
                        conn = get_db()
                        try:
                            uid = str(uuid.uuid4())
                            conn.execute(
                                "INSERT INTO users (id, username, password_hash, display_name, created_at) VALUES (?, ?, ?, ?, ?)",
                                (uid, new_u.strip(), hash_pass(new_p), d_name.strip(), int(time.time() * 1000))
                            )
                            conn.commit()
                            st.session_state.user = {
                                "id": uid,
                                "username": new_u.strip(),
                                "display_name": d_name.strip()
                            }
                            st.success("Akun berhasil dibuat!")
                            conn.close()
                            st.rerun()
                        except Exception as e:
                            st.error(f"Username sudah digunakan atau error: {e}")
                            conn.close()
    st.stop()

# ═══════════════════════════════════════════════════════════════
# SIDEBAR NAVIGATION & STATS
# ═══════════════════════════════════════════════════════════════
user = st.session_state.user
conn = get_db()

# Calculate storage
total_bytes = conn.execute("SELECT SUM(size_bytes) as total FROM files WHERE user_id = ?", (user["id"],)).fetchone()["total"] or 0
total_mb = total_bytes / (1024 * 1024)
total_gb = total_bytes / (1024 * 1024 * 1024)
max_gb = 10.0
used_percent = min(100.0, max(1.0, (total_gb / max_gb) * 100))

with st.sidebar:
    st.markdown("### ☁️ Internal Cloud")
    st.markdown(f"""
    <div class='status-badge'>
        <div style='font-size: 13px; font-weight: 700; color: #34d399;'>🟢 Online (Streamlit Cloud)</div>
        <div style='font-size: 12px; margin-top: 4px;'>{total_mb:.1f} MB dari 10 GB digunakan</div>
    </div>
    """, unsafe_allow_html=True)
    st.progress(used_percent / 100.0)
    
    st.markdown("---")
    menu = st.radio(
        "Navigasi",
        ["💬 Chat & File Stream", "📁 File Saya (Semua)", "📄 Dokumen", "🖼️ Gambar", "📦 Arsip", "📊 Statistik Penyimpanan"],
        index=0
    )
    
    st.markdown("---")
    st.markdown(f"**👤 {user.get('display_name', 'Pengguna')}**\n\n`@{user.get('username', 'user')}`")
    if st.button("🚪 Logout", use_container_width=True):
        st.session_state.user = None
        st.rerun()

# ═══════════════════════════════════════════════════════════════
# MAIN CONTENT AREA
# ═══════════════════════════════════════════════════════════════
if menu == "💬 Chat & File Stream":
    st.subheader("💬 Chat & Pengiriman File Realtime")
    st.caption("Kirim file dan pesan di sini. File langsung disinkronkan ke HP dan cloud.")
    
    # ── Upload Box ──
    with st.expander("📎 Kirim File Baru atau Pesan", expanded=True):
        col_up1, col_up2 = st.columns([2, 1])
        with col_up1:
            msg_text = st.text_input("Pesan Keterangan", placeholder="Contoh: laporan keuangan, dokumen QA, foto...", key="chat_msg_input")
        with col_up2:
            uploaded_file = st.file_uploader("Pilih File", type=None, key="chat_file_upload")
        
        if st.button("🚀 Kirim ke Cloud & HP", use_container_width=True, type="primary"):
            if msg_text or uploaded_file:
                mid = str(uuid.uuid4())
                ts = int(time.time() * 1000)
                conn.execute(
                    "INSERT INTO messages (id, user_id, body, ts) VALUES (?, ?, ?, ?)",
                    (mid, user["id"], msg_text or "", ts)
                )
                
                if uploaded_file:
                    fid = str(uuid.uuid4())
                    ext = uploaded_file.name.split(".")[-1] if "." in uploaded_file.name else ""
                    stored_name = f"{fid}.{ext}" if ext else fid
                    dest_path = os.path.join(UPLOADS_DIR, stored_name)
                    
                    with open(dest_path, "wb") as f:
                        f.write(uploaded_file.getbuffer())
                    
                    size_b = len(uploaded_file.getbuffer())
                    cat = get_category(uploaded_file.name, uploaded_file.type or "")
                    
                    conn.execute(
                        """INSERT INTO files (id, message_id, user_id, original_name, stored_name, mime, size_bytes, category, ts)
                           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                        (fid, mid, user["id"], uploaded_file.name, stored_name, uploaded_file.type or "application/octet-stream", size_b, cat, ts)
                    )
                
                conn.commit()
                st.success("File / Pesan berhasil dikirim!")
                st.rerun()

    # ── Chat Stream Render ──
    st.markdown("### Riwayat Chat & File")
    messages = conn.execute("SELECT * FROM messages WHERE user_id = ? ORDER BY ts DESC LIMIT 50", (user["id"],)).fetchall()
    
    if not messages:
        st.info("Belum ada pesan atau file. Mulai kirim file menggunakan formulir di atas!")
    
    for m in messages:
        m_files = conn.execute("SELECT * FROM files WHERE message_id = ?", (m["id"],)).fetchall()
        t_str = datetime.fromtimestamp(m["ts"] / 1000).strftime("%d/%m/%Y %H:%M")
        
        with st.container():
            st.markdown(f"<div class='chat-bubble'>", unsafe_allow_html=True)
            
            # Show files attached
            for f in m_files:
                f_path = os.path.join(UPLOADS_DIR, f["stored_name"])
                f_size_kb = f["size_bytes"] / 1024
                
                st.markdown(f"**📎 {f['original_name']}** `({f_size_kb:.1f} KB • {f['category'].upper()})`")
                
                if os.path.exists(f_path):
                    with open(f_path, "rb") as file_bytes:
                        data_b = file_bytes.read()
                        
                        col_btn1, col_btn2 = st.columns([1, 4])
                        with col_btn1:
                            st.download_button(
                                label="⬇️ Unduh File",
                                data=data_b,
                                file_name=f["original_name"],
                                mime=f["mime"],
                                key=f"dl_{f['id']}"
                            )
                        
                        # Live preview for images & excel
                        if f["category"] == "image":
                            st.image(data_b, caption=f["original_name"], use_column_width=False, width=320)
                        elif f["original_name"].endswith(".xlsx") or f["original_name"].endswith(".xls") or f["original_name"].endswith(".csv"):
                            try:
                                if f["original_name"].endswith(".csv"):
                                    df = pd.read_csv(io.BytesIO(data_b))
                                else:
                                    df = pd.read_excel(io.BytesIO(data_b))
                                with st.expander(f"📊 Preview Isi Spreadsheet: {f['original_name']}"):
                                    st.dataframe(df.head(20), use_container_width=True)
                            except Exception:
                                pass
                else:
                    st.warning("File tersimpan di cloud storage.")
            
            if m["body"]:
                st.write(m["body"])
            
            st.markdown(f"<div class='chat-meta'>{t_str} • Terkirim ✓✓</div></div>", unsafe_allow_html=True)

elif menu in ["📁 File Saya (Semua)", "📄 Dokumen", "🖼️ Gambar", "📦 Arsip"]:
    cat_filter = None
    if menu == "📄 Dokumen": cat_filter = "document"
    elif menu == "🖼️ Gambar": cat_filter = "image"
    elif menu == "📦 Arsip": cat_filter = "archive"
    
    st.subheader(menu)
    
    query = "SELECT * FROM files WHERE user_id = ?"
    params = [user["id"]]
    if cat_filter:
        query += " AND category = ?"
        params.append(cat_filter)
    query += " ORDER BY ts DESC"
    
    files = conn.execute(query, params).fetchall()
    
    if not files:
        st.info(f"Belum ada file di kategori {menu}.")
    else:
        for f in files:
            f_path = os.path.join(UPLOADS_DIR, f["stored_name"])
            t_str = datetime.fromtimestamp(f["ts"] / 1000).strftime("%d/%m/%Y %H:%M")
            f_size_kb = f["size_bytes"] / 1024
            
            with st.container():
                c1, c2, c3 = st.columns([3, 1, 1])
                with c1:
                    st.markdown(f"#### 📄 {f['original_name']}")
                    st.caption(f"{f_size_kb:.1f} KB • Kategori: {f['category']} • Diunggah: {t_str}")
                with c2:
                    if os.path.exists(f_path):
                        with open(f_path, "rb") as fb:
                            st.download_button("⬇️ Unduh", fb.read(), file_name=f["original_name"], key=f"f_dl_{f['id']}")
                with c3:
                    if f["category"] == "image" and os.path.exists(f_path):
                        st.image(f_path, width=80)
                st.markdown("---")

elif menu == "📊 Statistik Penyimpanan":
    st.subheader("📊 Statistik & Rincian Cloud Storage")
    
    doc_b = conn.execute("SELECT SUM(size_bytes) as total FROM files WHERE user_id = ? AND category = 'document'", (user["id"],)).fetchone()["total"] or 0
    img_b = conn.execute("SELECT SUM(size_bytes) as total FROM files WHERE user_id = ? AND category = 'image'", (user["id"],)).fetchone()["total"] or 0
    arc_b = conn.execute("SELECT SUM(size_bytes) as total FROM files WHERE user_id = ? AND category = 'archive'", (user["id"],)).fetchone()["total"] or 0
    other_b = conn.execute("SELECT SUM(size_bytes) as total FROM files WHERE user_id = ? AND category = 'other'", (user["id"],)).fetchone()["total"] or 0
    
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("📄 Dokumen", f"{doc_b / (1024*1024):.2f} MB")
    col2.metric("🖼️ Gambar", f"{img_b / (1024*1024):.2f} MB")
    col3.metric("📦 Arsip", f"{arc_b / (1024*1024):.2f} MB")
    col4.metric("📁 Total Digunakan", f"{total_mb:.2f} MB")
    
    st.markdown("### Diagram Distribusi File")
    chart_data = pd.DataFrame({
        "Kategori": ["Dokumen", "Gambar", "Arsip", "Lainnya"],
        "Ukuran (MB)": [doc_b / (1024*1024), img_b / (1024*1024), arc_b / (1024*1024), other_b / (1024*1024)]
    })
    st.bar_chart(chart_data.set_index("Kategori"))

conn.close()
