/* ═══════════════════════════════════════════════════════════════
   INTERNAL CLOUD WEB - APPLICATION JAVASCRIPT
   Matches exact 3-column dashboard UI with real-time phone sync
   ═══════════════════════════════════════════════════════════════ */

(function () {
  'use strict';

  // ── State ──────────────────────────────────────────────────
  const state = {
    token: localStorage.getItem('internal_cloud_token') || null,
    user: JSON.parse(localStorage.getItem('internal_cloud_user') || 'null'),
    messages: [],
    files: [],
    currentView: 'chat',
    selectedFile: null,
    ws: null,
    networkInfo: null,
    searchDebounce: null,
  };

  // ── DOM Elements ───────────────────────────────────────────
  const el = {
    app: document.getElementById('app'),
    authModal: document.getElementById('authModal'),
    tabLogin: document.getElementById('tabLogin'),
    tabRegister: document.getElementById('tabRegister'),
    formLogin: document.getElementById('formLogin'),
    formRegister: document.getElementById('formRegister'),
    loginError: document.getElementById('loginError'),
    regError: document.getElementById('regError'),
    
    sidebarAvatar: document.getElementById('sidebarAvatar'),
    sidebarUserName: document.getElementById('sidebarUserName'),
    sidebarUserRole: document.getElementById('sidebarUserRole'),
    sidebarStorageText: document.getElementById('sidebarStorageText'),
    sidebarProgressBar: document.getElementById('sidebarProgressBar'),
    
    viewTitle: document.getElementById('viewTitle'),
    netBadgeTop: document.getElementById('netBadgeTop'),
    netBadgeText: document.getElementById('netBadgeText'),
    
    chatStreamContainer: document.getElementById('chatStreamContainer'),
    chatBubblesList: document.getElementById('chatBubblesList'),
    dragDropOverlay: document.getElementById('dragDropOverlay'),
    
    fileUploadInput: document.getElementById('fileUploadInput'),
    btnInputAttach: document.getElementById('btnInputAttach'),
    chatTextInput: document.getElementById('chatTextInput'),
    btnInputSend: document.getElementById('btnInputSend'),
    
    uploadIndicatorStrip: document.getElementById('uploadIndicatorStrip'),
    uploadingName: document.getElementById('uploadingName'),
    uploadingPercentage: document.getElementById('uploadingPercentage'),
    uploadingFill: document.getElementById('uploadingFill'),
    
    selectedFileStrip: document.getElementById('selectedFileStrip'),
    selectedFileName: document.getElementById('selectedFileName'),
    selectedFileSize: document.getElementById('selectedFileSize'),
    selectedFileIcon: document.getElementById('selectedFileIcon'),
    btnRemoveSelectedFile: document.getElementById('btnRemoveSelectedFile'),
    
    globalSearchInput: document.getElementById('globalSearchInput'),
    btnQrModal: document.getElementById('btnQrModal'),
    btnSeeAllFiles: document.getElementById('btnSeeAllFiles'),
    recentFilesList: document.getElementById('recentFilesList'),
    
    storageDonutChart: document.getElementById('storageDonutChart'),
    donutUsedText: document.getElementById('donutUsedText'),
    legendDocVal: document.getElementById('legendDocVal'),
    legendImgVal: document.getElementById('legendImgVal'),
    legendArcVal: document.getElementById('legendArcVal'),
    legendOtherVal: document.getElementById('legendOtherVal'),
    storageBottomText: document.getElementById('storageBottomText'),
    storageBottomPercent: document.getElementById('storageBottomPercent'),
    storageBottomProgress: document.getElementById('storageBottomProgress'),
    
    qrModal: document.getElementById('qrModal'),
    qrImage: document.getElementById('qrImage'),
    lanUrlInput: document.getElementById('lanUrlInput'),
    btnCopyLanUrl: document.getElementById('btnCopyLanUrl'),
    
    lightboxModal: document.getElementById('lightboxModal'),
    lightboxImg: document.getElementById('lightboxImg'),
    lightboxTitle: document.getElementById('lightboxTitle'),
    lightboxDownloadBtn: document.getElementById('lightboxDownloadBtn'),
    lightboxCloseBtn: document.getElementById('lightboxCloseBtn'),
    
    docModal: document.getElementById('docModal'),
    docBadgeLarge: document.getElementById('docBadgeLarge'),
    docBadgeIcon: document.getElementById('docBadgeIcon'),
    docBadgeTag: document.getElementById('docBadgeTag'),
    docModalName: document.getElementById('docModalName'),
    docModalMeta: document.getElementById('docModalMeta'),
    btnDocDownload: document.getElementById('btnDocDownload'),
    btnDocRawOpen: document.getElementById('btnDocRawOpen'),
    
    toastContainer: document.getElementById('toastContainer'),
  };

  // ── Init ───────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', init);

  async function init() {
    setupEventListeners();
    await fetchNetworkInfo();

    if (!state.token) {
      showAuthModal();
    } else {
      await checkAuthSession();
    }
  }

  // ── Event Listeners ────────────────────────────────────────
  function setupEventListeners() {
    // Auth tab switching
    el.tabLogin.addEventListener('click', () => switchAuthTab('login'));
    el.tabRegister.addEventListener('click', () => switchAuthTab('register'));

    // Auth forms
    el.formLogin.addEventListener('submit', handleLogin);
    el.formRegister.addEventListener('submit', handleRegister);

    // QR Modal
    el.btnQrModal.addEventListener('click', showQrModal);

    // Modal Close
    document.querySelectorAll('[data-close]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-close');
        document.getElementById(id)?.classList.add('hidden');
      });
    });

    // Lightbox Close
    el.lightboxCloseBtn.addEventListener('click', () => el.lightboxModal.classList.add('hidden'));

    // Copy LAN URL
    el.btnCopyLanUrl.addEventListener('click', () => {
      navigator.clipboard.writeText(el.lanUrlInput.value);
      showToast('Alamat URL server disalin ke clipboard!', 'success');
    });

    // Sidebar Navigation Menus
    document.querySelectorAll('.nav-item').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        state.currentView = btn.dataset.view;
        updateViewTitle();
        renderMessages();
      });
    });

    // Category Cards in Right Column
    document.querySelectorAll('.cat-card').forEach(card => {
      card.addEventListener('click', () => {
        const cat = card.dataset.cat;
        if (cat === 'document') state.currentView = 'documents';
        else if (cat === 'archive') state.currentView = 'archives';
        else state.currentView = 'all_files';
        
        document.querySelectorAll('.nav-item').forEach(b => {
          b.classList.toggle('active', b.dataset.view === state.currentView);
        });
        updateViewTitle();
        renderMessages();
      });
    });

    el.btnSeeAllFiles.addEventListener('click', () => {
      state.currentView = 'all_files';
      document.querySelectorAll('.nav-item').forEach(b => {
        b.classList.toggle('active', b.dataset.view === 'all_files');
      });
      updateViewTitle();
      renderMessages();
    });

    // Attach File
    el.btnInputAttach.addEventListener('click', () => el.fileUploadInput.click());
    el.fileUploadInput.addEventListener('change', handleFileSelect);
    el.btnRemoveSelectedFile.addEventListener('click', clearSelectedFile);

    // Send Message / Upload
    el.btnInputSend.addEventListener('click', handleSendMessage);
    el.chatTextInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        handleSendMessage();
      }
    });

    // Global Search
    el.globalSearchInput.addEventListener('input', handleSearch);

    // Drag & Drop
    setupDragAndDrop();
  }

  function updateViewTitle() {
    const titles = {
      chat: 'Chat',
      all_files: 'File Saya',
      documents: 'Dokumen',
      archives: 'Arsip',
      favorites: 'Favorit',
      shared: 'Dibagikan ke Saya',
      trash: 'Sampah',
    };
    el.viewTitle.textContent = titles[state.currentView] || 'Chat';
  }

  // ── Drag & Drop ────────────────────────────────────────────
  function setupDragAndDrop() {
    let dragCounter = 0;

    window.addEventListener('dragenter', (e) => {
      e.preventDefault();
      dragCounter++;
      el.dragDropOverlay.classList.add('active');
    });

    window.addEventListener('dragleave', (e) => {
      e.preventDefault();
      dragCounter--;
      if (dragCounter <= 0) {
        dragCounter = 0;
        el.dragDropOverlay.classList.remove('active');
      }
    });

    window.addEventListener('dragover', (e) => e.preventDefault());

    window.addEventListener('drop', (e) => {
      e.preventDefault();
      dragCounter = 0;
      el.dragDropOverlay.classList.remove('active');

      if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
        setSelectedFile(e.dataTransfer.files[0]);
      }
    });
  }

  // ── Network Info & QR ──────────────────────────────────────
  async function fetchNetworkInfo() {
    try {
      const res = await fetch('/api/network/info');
      const data = await res.json();
      state.networkInfo = data;

      const isWlan = data.mode === 'hybrid_wlan';
      el.netBadgeText.textContent = isWlan ? `WLAN ${data.primaryLocalIp}` : 'CLOUD HOSTED';
      
      const serverUrl = data.localUrl || window.location.origin;
      el.lanUrlInput.value = serverUrl;

      // QR Code
      const qrApi = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(serverUrl)}`;
      el.qrImage.src = qrApi;
    } catch (_) {
      el.netBadgeText.textContent = 'ONLINE';
    }
  }

  function showQrModal() {
    el.qrModal.classList.remove('hidden');
  }

  // ── Auth ───────────────────────────────────────────────────
  function showAuthModal() {
    el.authModal.classList.remove('hidden');
  }

  function hideAuthModal() {
    el.authModal.classList.add('hidden');
  }

  function switchAuthTab(tab) {
    if (tab === 'login') {
      el.tabLogin.classList.add('active');
      el.tabRegister.classList.remove('active');
      el.formLogin.classList.remove('hidden');
      el.formRegister.classList.add('hidden');
    } else {
      el.tabLogin.classList.remove('active');
      el.tabRegister.classList.add('active');
      el.formLogin.classList.add('hidden');
      el.formRegister.classList.remove('hidden');
    }
  }

  async function handleLogin(e) {
    e.preventDefault();
    el.loginError.classList.add('hidden');
    const username = document.getElementById('loginUsername').value.trim();
    const password = document.getElementById('loginPassword').value;

    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Login gagal');

      saveSession(data.token, data.user);
      hideAuthModal();
      showToast(`Selamat datang, ${data.user.display_name}!`, 'success');
      await postAuthInit();
    } catch (err) {
      el.loginError.textContent = err.message;
      el.loginError.classList.remove('hidden');
    }
  }

  async function handleRegister(e) {
    e.preventDefault();
    el.regError.classList.add('hidden');
    const display_name = document.getElementById('regDisplayName').value.trim();
    const username = document.getElementById('regUsername').value.trim();
    const password = document.getElementById('regPassword').value;

    try {
      const res = await fetch('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ display_name, username, password }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Pendaftaran gagal');

      saveSession(data.token, data.user);
      hideAuthModal();
      showToast(`Akun berhasil dibuat!`, 'success');
      await postAuthInit();
    } catch (err) {
      el.regError.textContent = err.message;
      el.regError.classList.remove('hidden');
    }
  }

  function saveSession(token, user) {
    state.token = token;
    state.user = user;
    localStorage.setItem('internal_cloud_token', token);
    localStorage.setItem('internal_cloud_user', JSON.stringify(user));
    updateUserUI();
  }

  async function checkAuthSession() {
    try {
      const res = await fetch('/api/auth/me', {
        headers: { Authorization: `Bearer ${state.token}` },
      });
      if (res.ok) {
        const data = await res.json();
        state.user = data.user;
        localStorage.setItem('internal_cloud_user', JSON.stringify(data.user));
        updateUserUI();
        await postAuthInit();
      } else {
        showAuthModal();
      }
    } catch (_) {
      updateUserUI();
      await postAuthInit();
    }
  }

  function updateUserUI() {
    if (!state.user) return;
    const name = state.user.display_name || state.user.username || 'Pengguna';
    el.sidebarUserName.textContent = name;
    el.sidebarUserRole.textContent = `@${state.user.username || 'user'}`;
    el.sidebarAvatar.textContent = name.charAt(0).toUpperCase();
  }

  async function postAuthInit() {
    connectWebSocket();
    await loadData();
  }

  // ── WebSocket Realtime ─────────────────────────────────────
  function connectWebSocket() {
    if (!state.token) return;
    const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${location.host}/ws?token=${encodeURIComponent(state.token)}`;

    try {
      state.ws = new WebSocket(wsUrl);
      state.ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          if (msg.type === 'MESSAGE_CREATED' || msg.type === 'SYNC' || msg.type === 'FILE_UPLOADED') {
            loadData();
            showToast('Pesan / File baru disinkronkan!', 'success');
          }
        } catch (_) {}
      };

      state.ws.onclose = () => {
        setTimeout(connectWebSocket, 3000);
      };
    } catch (_) {}
  }

  // ── Load & Render Data ─────────────────────────────────────
  async function loadData() {
    if (!state.token) return;
    try {
      const [msgRes, filesRes] = await Promise.all([
        fetch('/api/messages?limit=100', { headers: { Authorization: `Bearer ${state.token}` } }),
        fetch('/api/files', { headers: { Authorization: `Bearer ${state.token}` } }),
      ]);

      if (msgRes.ok) {
        const msgData = await msgRes.json();
        state.messages = msgData.messages || [];
      }

      if (filesRes.ok) {
        const fileData = await filesRes.json();
        state.files = fileData.files || [];
      }

      renderMessages();
      renderRecentFiles();
      updateStorageOverview();
    } catch (e) {
      showToast('Gagal memuat data: ' + e.message, 'error');
    }
  }

  function getAuthenticatedFileUrl(fileId, endpoint = 'raw') {
    const tokenParam = state.token ? `?token=${encodeURIComponent(state.token)}` : '';
    return `/api/files/${fileId}/${endpoint}${tokenParam}`;
  }

  function renderMessages() {
    let list = [...state.messages];

    // Filter based on active view
    if (state.currentView === 'documents') {
      list = list.filter(m => m.files && m.files.some(f => f.category === 'document'));
    } else if (state.currentView === 'archives') {
      list = list.filter(m => m.files && m.files.some(f => f.category === 'archive'));
    } else if (state.currentView === 'all_files') {
      list = list.filter(m => m.files && m.files.length > 0);
    }

    if (list.length === 0) {
      el.chatBubblesList.innerHTML = `
        <div class="empty-chat-state">
          <i class="fa-solid fa-cloud-arrow-up"></i>
          <p>Belum ada pesan atau file dalam kategori ini.</p>
        </div>
      `;
      return;
    }

    let html = '';
    const sorted = [...list].reverse();

    sorted.forEach(m => {
      const timeStr = formatTime(m.ts);
      const hasFiles = m.files && m.files.length > 0;

      html += `<div class="chat-bubble-card" id="msg-${m.id}">`;

      if (hasFiles) {
        m.files.forEach(f => {
          const rawUrl = getAuthenticatedFileUrl(f.id, 'raw');
          if (f.category === 'image' || (f.mime && f.mime.startsWith('image/'))) {
            html += `
              <div class="bubble-inner-image" onclick="window.app.openImageLightbox('${f.id}', '${escapeHtml(f.original_name)}')">
                <img src="${rawUrl}" alt="${escapeHtml(f.original_name)}" loading="lazy">
              </div>
            `;
          } else {
            const badge = getBadgeInfo(f.original_name, f.mime, f.category);
            html += `
              <div class="bubble-inner-file" onclick="window.app.openDocModal('${f.id}', '${escapeHtml(f.original_name)}', '${formatBytes(f.size_bytes)}', '${f.mime || ''}', '${f.category || 'document'}')">
                <div class="file-type-icon-box ${badge.cssClass}">
                  <i class="${badge.icon}"></i>
                </div>
                <div class="file-details-col">
                  <div class="file-name-title">${escapeHtml(f.original_name)}</div>
                  <div class="file-size-meta">${formatBytes(f.size_bytes)} • ${badge.tag}</div>
                </div>
              </div>
            `;
          }
        });
      }

      if (m.body && m.body.trim()) {
        html += `<div class="bubble-message-text">${escapeHtml(m.body)}</div>`;
      }

      html += `
        <div class="bubble-footer-time">
          <span>${timeStr}</span>
          <i class="fa-solid fa-check-double"></i>
        </div>
      `;

      html += `</div>`;
    });

    el.chatBubblesList.innerHTML = html;
    scrollToBottom();
  }

  function renderRecentFiles() {
    const recents = state.files.slice(0, 5);
    if (recents.length === 0) {
      el.recentFilesList.innerHTML = `<div class="empty-recent">Belum ada file tersimpan</div>`;
      return;
    }

    let html = '';
    recents.forEach(f => {
      const badge = getBadgeInfo(f.original_name, f.mime, f.category);
      html += `
        <div class="recent-file-item" onclick="window.app.handleFileClick('${f.id}', '${escapeHtml(f.original_name)}', '${f.category}')">
          <div class="recent-icon-box ${badge.cssClass}">
            <i class="${badge.icon}"></i>
          </div>
          <div class="recent-details">
            <div class="recent-title">${escapeHtml(f.original_name)}</div>
            <div class="recent-meta">${formatBytes(f.size_bytes)} • ${badge.tag}</div>
          </div>
          <span class="recent-time">Hari ini</span>
        </div>
      `;
    });

    el.recentFilesList.innerHTML = html;
  }

  function updateStorageOverview() {
    let docBytes = 0;
    let imgBytes = 0;
    let arcBytes = 0;
    let otherBytes = 0;

    state.files.forEach(f => {
      const size = f.size_bytes || 0;
      if (f.category === 'document') docBytes += size;
      else if (f.category === 'image') imgBytes += size;
      else if (f.category === 'archive') arcBytes += size;
      else otherBytes += size;
    });

    const totalBytes = docBytes + imgBytes + arcBytes + otherBytes;
    const maxBytes = 10 * 1024 * 1024 * 1024; // 10 GB limit

    const usedGB = (totalBytes / (1024 * 1024 * 1024)).toFixed(1);
    const percent = Math.min(100, Math.max(1, (totalBytes / maxBytes) * 100));

    el.sidebarStorageText.textContent = `${formatBytes(totalBytes)} dari 10 GB digunakan`;
    el.sidebarProgressBar.style.width = `${percent}%`;

    el.donutUsedText.textContent = `${usedGB} GB`;
    el.legendDocVal.textContent = formatBytes(docBytes);
    el.legendImgVal.textContent = formatBytes(imgBytes);
    el.legendArcVal.textContent = formatBytes(arcBytes);
    el.legendOtherVal.textContent = formatBytes(otherBytes);

    el.storageBottomText.textContent = `${usedGB} GB dari 10 GB digunakan`;
    el.storageBottomPercent.textContent = `${percent.toFixed(0)}%`;
    el.storageBottomProgress.style.width = `${percent}%`;

    const docDeg = totalBytes ? (docBytes / totalBytes) * 360 : 180;
    const imgDeg = totalBytes ? (imgBytes / totalBytes) * 360 : 90;
    const arcDeg = totalBytes ? (arcBytes / totalBytes) * 360 : 45;
    
    const p1 = docDeg;
    const p2 = p1 + imgDeg;
    const p3 = p2 + arcDeg;

    el.storageDonutChart.style.background = `conic-gradient(
      #0d5c4d 0deg ${p1}deg,
      #10b981 ${p1}deg ${p2}deg,
      #6ee7b7 ${p2}deg ${p3}deg,
      #93c5fd ${p3}deg 360deg
    )`;
  }

  // ── File Selection & Send ──────────────────────────────────
  function handleFileSelect(e) {
    if (e.target.files && e.target.files.length > 0) {
      setSelectedFile(e.target.files[0]);
    }
  }

  function setSelectedFile(file) {
    state.selectedFile = file;
    el.selectedFileName.textContent = file.name;
    el.selectedFileSize.textContent = formatBytes(file.size);

    const badge = getBadgeInfo(file.name, file.type, '');
    el.selectedFileIcon.innerHTML = `<i class="${badge.icon}"></i>`;
    el.selectedFileIcon.className = `selected-file-icon ${badge.cssClass}`;

    el.selectedFileStrip.classList.remove('hidden');
    el.chatTextInput.focus();
  }

  function clearSelectedFile() {
    state.selectedFile = null;
    el.fileUploadInput.value = '';
    el.selectedFileStrip.classList.add('hidden');
  }

  async function handleSendMessage() {
    const text = el.chatTextInput.value.trim();
    const file = state.selectedFile;

    if (!text && !file) return;

    if (file) {
      await uploadFileWithProgress(file, text);
    } else {
      await sendTextMessage(text);
    }

    el.chatTextInput.value = '';
    clearSelectedFile();
  }

  async function sendTextMessage(body) {
    try {
      const res = await fetch('/api/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${state.token}`,
        },
        body: JSON.stringify({ body }),
      });
      if (!res.ok) throw new Error('Gagal mengirim pesan');
      await loadData();
    } catch (e) {
      showToast(e.message, 'error');
    }
  }

  function uploadFileWithProgress(file, message) {
    return new Promise((resolve, reject) => {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('message', message || '');

      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/api/upload');
      xhr.setRequestHeader('Authorization', `Bearer ${state.token}`);

      el.uploadingName.innerHTML = `<i class="fa-solid fa-file-arrow-up"></i> Mengunggah "${escapeHtml(file.name)}"...`;
      el.uploadingPercentage.textContent = '0%';
      el.uploadingFill.style.width = '0%';
      el.uploadIndicatorStrip.classList.remove('hidden');

      xhr.upload.onprogress = (event) => {
        if (event.lengthComputable) {
          const percent = Math.round((event.loaded / event.total) * 100);
          el.uploadingPercentage.textContent = `${percent}%`;
          el.uploadingFill.style.width = `${percent}%`;
        }
      };

      xhr.onload = async () => {
        el.uploadIndicatorStrip.classList.add('hidden');
        if (xhr.status >= 200 && xhr.status < 300) {
          showToast(`File "${file.name}" berhasil diunggah & disinkronkan ke HP!`, 'success');
          await loadData();
          resolve();
        } else {
          let err = 'Upload gagal';
          try {
            err = JSON.parse(xhr.responseText).error || err;
          } catch (_) {}
          showToast(err, 'error');
          reject(new Error(err));
        }
      };

      xhr.onerror = () => {
        el.uploadIndicatorStrip.classList.add('hidden');
        showToast('Koneksi terputus saat mengunggah', 'error');
        reject(new Error('Network error'));
      };

      xhr.send(formData);
    });
  }

  // ── Search ─────────────────────────────────────────────────
  function handleSearch() {
    const val = el.globalSearchInput.value.trim().toLowerCase();
    clearTimeout(state.searchDebounce);
    state.searchDebounce = setTimeout(() => {
      if (!val) {
        renderMessages();
        return;
      }
      const filtered = state.messages.filter(m => {
        if (m.body && m.body.toLowerCase().includes(val)) return true;
        if (m.files && m.files.some(f => f.original_name.toLowerCase().includes(val))) return true;
        return false;
      });

      if (filtered.length === 0) {
        el.chatBubblesList.innerHTML = `
          <div class="empty-chat-state">
            <i class="fa-solid fa-magnifying-glass"></i>
            <p>Tidak ada hasil pencarian untuk "${escapeHtml(val)}".</p>
          </div>
        `;
      } else {
        const sorted = [...filtered].reverse();
        let html = '';
        sorted.forEach(m => {
          const timeStr = formatTime(m.ts);
          html += `<div class="chat-bubble-card" id="msg-${m.id}">`;
          if (m.files) {
            m.files.forEach(f => {
              const badge = getBadgeInfo(f.original_name, f.mime, f.category);
              html += `
                <div class="bubble-inner-file" onclick="window.app.openDocModal('${f.id}', '${escapeHtml(f.original_name)}', '${formatBytes(f.size_bytes)}', '${f.mime || ''}', '${f.category}')">
                  <div class="file-type-icon-box ${badge.cssClass}"><i class="${badge.icon}"></i></div>
                  <div class="file-details-col">
                    <div class="file-name-title">${escapeHtml(f.original_name)}</div>
                    <div class="file-size-meta">${formatBytes(f.size_bytes)} • ${badge.tag}</div>
                  </div>
                </div>
              `;
            });
          }
          if (m.body) html += `<div class="bubble-message-text">${escapeHtml(m.body)}</div>`;
          html += `<div class="bubble-footer-time"><span>${timeStr}</span><i class="fa-solid fa-check-double"></i></div></div>`;
        });
        el.chatBubblesList.innerHTML = html;
      }
    }, 250);
  }

  // ── Modals & Lightbox ──────────────────────────────────────
  function openImageLightbox(fileId, fileName) {
    const rawUrl = getAuthenticatedFileUrl(fileId, 'raw');
    const downloadUrl = getAuthenticatedFileUrl(fileId, 'download');
    el.lightboxImg.src = rawUrl;
    el.lightboxTitle.textContent = fileName;
    el.lightboxDownloadBtn.href = downloadUrl;
    el.lightboxModal.classList.remove('hidden');
  }

  function openDocModal(fileId, fileName, sizeLabel, mime, category) {
    const badge = getBadgeInfo(fileName, mime, category);
    el.docBadgeLarge.className = `doc-icon-large ${badge.cssClass}`;
    el.docBadgeIcon.className = badge.icon;
    el.docBadgeTag.textContent = badge.tag;
    el.docModalName.textContent = fileName;
    el.docModalMeta.textContent = `${sizeLabel} • ${badge.tag}`;
    
    el.btnDocDownload.href = getAuthenticatedFileUrl(fileId, 'download');
    el.btnDocRawOpen.href = getAuthenticatedFileUrl(fileId, 'raw');
    el.docModal.classList.remove('hidden');
  }

  function handleFileClick(fileId, fileName, category) {
    if (category === 'image') {
      openImageLightbox(fileId, fileName);
    } else {
      const file = state.files.find(f => f.id === fileId);
      openDocModal(
        fileId,
        fileName,
        file ? formatBytes(file.size_bytes) : '',
        file ? file.mime : '',
        category
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  function getBadgeInfo(fileName, mime, category) {
    const lower = (fileName || '').toLowerCase();
    mime = (mime || '').toLowerCase();

    if (lower.endsWith('.pdf') || mime.includes('pdf')) {
      return { cssClass: 'pdf', icon: 'fa-solid fa-file-pdf', tag: 'PDF' };
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx') || mime.includes('word')) {
      return { cssClass: 'doc', icon: 'fa-solid fa-file-word', tag: 'DOCX' };
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || mime.includes('excel') || mime.includes('spreadsheet')) {
      return { cssClass: 'xls', icon: 'fa-solid fa-file-excel', tag: 'XLSX' };
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || category === 'archive') {
      return { cssClass: 'zip', icon: 'fa-solid fa-box-archive', tag: 'ZIP' };
    }
    if (category === 'image' || mime.startsWith('image/')) {
      return { cssClass: 'img', icon: 'fa-solid fa-image', tag: 'IMG' };
    }
    return { cssClass: 'other', icon: 'fa-solid fa-file-lines', tag: 'FILE' };
  }

  function formatBytes(bytes) {
    bytes = Number(bytes) || 0;
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
  }

  function formatTime(ts) {
    if (!ts) return '';
    const d = new Date(ts);
    return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', hour12: false });
  }

  function scrollToBottom() {
    el.chatStreamContainer.scrollTop = el.chatStreamContainer.scrollHeight;
  }

  function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    const icon = type === 'success' ? 'fa-circle-check' : type === 'error' ? 'fa-circle-exclamation' : 'fa-circle-info';
    toast.innerHTML = `<i class="fa-solid ${icon}"></i> <span>${escapeHtml(message)}</span>`;
    el.toastContainer.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transition = 'opacity 0.3s';
      setTimeout(() => toast.remove(), 300);
    }, 3500);
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Window app export
  window.app = {
    openImageLightbox,
    openDocModal,
    handleFileClick,
  };

})();
