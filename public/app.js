const $ = (sel) => document.querySelector(sel);

const state = {
  serverUrl: localStorage.getItem('cc_server_url') || '',
  token: localStorage.getItem('cc_token') || '',
  ws: null,
  term: null,
  fitAddon: null,
};

function saveConfig(url, token) {
  state.serverUrl = url.replace(/\/+$/, '');
  state.token = token;
  localStorage.setItem('cc_server_url', state.serverUrl);
  localStorage.setItem('cc_token', state.token);
}

async function fetchSessions() {
  const res = await fetch(`${state.serverUrl}/api/sessions?token=${encodeURIComponent(state.token)}`);
  if (res.status === 401) throw new Error('Token incorrecto');
  if (!res.ok) throw new Error('El servidor no respondió correctamente');
  const data = await res.json();
  return data.sessions;
}

async function createSession(name) {
  const res = await fetch(`${state.serverUrl}/api/sessions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: state.token, name }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Error creando la sesión');
}

function closeConnection() {
  if (state.ws) {
    state.ws.onclose = null;
    state.ws.close();
    state.ws = null;
  }
  if (state.term) {
    state.term.dispose();
    state.term = null;
  }
}

function connectToSession(name) {
  closeConnection();

  const term = new Terminal({
    convertEol: true,
    fontSize: 14,
    theme: { background: '#0d1117', foreground: '#e6edf3' },
    scrollback: 5000,
  });
  const fitAddon = new FitAddon.FitAddon();
  term.loadAddon(fitAddon);
  term.open($('#terminal'));
  fitAddon.fit();
  state.term = term;
  state.fitAddon = fitAddon;

  const wsProto = state.serverUrl.startsWith('https') ? 'wss' : 'ws';
  const base = state.serverUrl.replace(/^https?/, wsProto);
  const wsUrl = `${base}/ws?token=${encodeURIComponent(state.token)}&session=${encodeURIComponent(name)}`;
  const ws = new WebSocket(wsUrl);
  state.ws = ws;

  $('#status').textContent = `Conectando a "${name}"...`;

  ws.onopen = () => {
    $('#status').textContent = `Conectado a "${name}"`;
    ws.send(JSON.stringify({ type: 'resize', cols: term.cols, rows: term.rows }));
  };

  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.type === 'data') term.write(msg.data);
  };

  ws.onclose = () => {
    $('#status').textContent = 'Desconectado';
  };

  ws.onerror = () => {
    $('#status').textContent = 'Error de conexión';
  };

  term.onData((data) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'input', data }));
    }
  });

  const resizeHandler = () => {
    fitAddon.fit();
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'resize', cols: term.cols, rows: term.rows }));
    }
  };
  window.addEventListener('resize', resizeHandler);
}

function sendText(text) {
  const trimmed = text.trim();
  if (!trimmed) return;
  if (state.ws && state.ws.readyState === WebSocket.OPEN) {
    state.ws.send(JSON.stringify({ type: 'input', data: trimmed + '\r' }));
  }
}

/* ---------- Voz ---------- */
let recognition = null;

function setupVoice() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const voiceBtn = $('#voiceBtn');
  if (!SpeechRecognition) {
    voiceBtn.disabled = true;
    voiceBtn.title = 'Reconocimiento de voz no soportado en este navegador (probá con Chrome en Android)';
    return;
  }

  recognition = new SpeechRecognition();
  recognition.lang = 'es-AR';
  recognition.interimResults = true;
  recognition.continuous = false;

  recognition.onresult = (ev) => {
    let text = '';
    for (let i = 0; i < ev.results.length; i++) text += ev.results[i][0].transcript;
    $('#messageInput').value = text;
  };
  recognition.onend = () => voiceBtn.classList.remove('recording');
  recognition.onerror = () => voiceBtn.classList.remove('recording');

  voiceBtn.addEventListener('click', () => {
    if (voiceBtn.classList.contains('recording')) {
      recognition.stop();
      return;
    }
    $('#messageInput').value = '';
    try {
      recognition.start();
      voiceBtn.classList.add('recording');
    } catch {
      // ya estaba escuchando
    }
  });
}

/* ---------- UI wiring ---------- */

$('#sendBtn').addEventListener('click', () => {
  sendText($('#messageInput').value);
  $('#messageInput').value = '';
});

$('#messageInput').addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    $('#sendBtn').click();
  }
});

$('#backBtn').addEventListener('click', () => {
  closeConnection();
  $('#chatScreen').classList.add('hidden');
  $('#sessionScreen').classList.remove('hidden');
});

$('#loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  saveConfig($('#serverUrl').value, $('#tokenInput').value);
  await goToSessions();
});

$('#refreshBtn').addEventListener('click', goToSessions);

$('#createSessionBtn').addEventListener('click', async () => {
  const name = prompt('Nombre para la nueva sesión (ej: proyecto1):');
  if (!name) return;
  try {
    await createSession(name.trim());
    await goToSessions();
  } catch (err) {
    alert('Error: ' + err.message);
  }
});

async function goToSessions() {
  try {
    const sessions = await fetchSessions();
    $('#loginScreen').classList.add('hidden');
    $('#chatScreen').classList.add('hidden');
    $('#sessionScreen').classList.remove('hidden');

    const list = $('#sessionList');
    list.innerHTML = '';
    if (sessions.length === 0) {
      const empty = document.createElement('li');
      empty.className = 'empty';
      empty.textContent = 'No hay sesiones activas. Creá una con "+ Nueva".';
      list.appendChild(empty);
      return;
    }
    sessions.forEach((name) => {
      const li = document.createElement('li');
      li.textContent = name;
      li.addEventListener('click', () => {
        $('#sessionScreen').classList.add('hidden');
        $('#chatScreen').classList.remove('hidden');
        connectToSession(name);
      });
      list.appendChild(li);
    });
  } catch (err) {
    alert('No se pudo conectar: ' + err.message);
    $('#sessionScreen').classList.add('hidden');
    $('#loginScreen').classList.remove('hidden');
  }
}

setupVoice();

if (state.serverUrl && state.token) {
  $('#serverUrl').value = state.serverUrl;
  $('#tokenInput').value = state.token;
  goToSessions().catch(() => {});
}

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
