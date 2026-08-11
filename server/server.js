require('dotenv').config();

const express = require('express');
const http = require('http');
const path = require('path');
const { execFile } = require('child_process');
const WebSocket = require('ws');
const pty = require('node-pty');

const PORT = process.env.PORT || 3344;
const AUTH_TOKEN = process.env.AUTH_TOKEN;

if (!AUTH_TOKEN) {
  console.error('ERROR: falta AUTH_TOKEN. Copiá server/.env.example a server/.env y completalo.');
  process.exit(1);
}

const SESSION_NAME_RE = /^[a-zA-Z0-9_-]{1,64}$/;

function listTmuxSessions() {
  return new Promise((resolve) => {
    execFile('tmux', ['list-sessions', '-F', '#{session_name}'], (err, stdout) => {
      if (err) return resolve([]); // sin sesiones o tmux server no corriendo
      resolve(stdout.split('\n').map((s) => s.trim()).filter(Boolean));
    });
  });
}

function sessionExists(name, sessions) {
  return sessions.includes(name);
}

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'public')));

function checkToken(token) {
  return typeof token === 'string' && token.length > 0 && token === AUTH_TOKEN;
}

app.get('/api/sessions', async (req, res) => {
  if (!checkToken(req.query.token)) return res.status(401).json({ error: 'unauthorized' });
  res.json({ sessions: await listTmuxSessions() });
});

app.post('/api/sessions', async (req, res) => {
  if (!checkToken(req.body.token)) return res.status(401).json({ error: 'unauthorized' });

  const name = String(req.body.name || '').trim();
  if (!SESSION_NAME_RE.test(name)) {
    return res.status(400).json({ error: 'Nombre inválido (solo letras, números, - y _)' });
  }

  const sessions = await listTmuxSessions();
  if (sessionExists(name, sessions)) {
    return res.status(409).json({ error: 'Ya existe una sesión con ese nombre' });
  }

  execFile('tmux', ['new-session', '-d', '-s', name, 'claude'], (err) => {
    if (err) return res.status(500).json({ error: 'No se pudo crear la sesión: ' + err.message });
    res.json({ ok: true });
  });
});

const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws' });

wss.on('connection', async (ws, req) => {
  const url = new URL(req.url, 'http://localhost');
  const token = url.searchParams.get('token');
  const session = url.searchParams.get('session');

  if (!checkToken(token)) {
    ws.close(4001, 'unauthorized');
    return;
  }

  const sessions = await listTmuxSessions();
  if (!session || !sessionExists(session, sessions)) {
    ws.close(4004, 'session not found');
    return;
  }

  const term = pty.spawn('tmux', ['attach-session', '-t', session], {
    name: 'xterm-256color',
    cols: 100,
    rows: 30,
    cwd: process.env.HOME,
    env: process.env,
  });

  const onData = term.onData((data) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'data', data }));
    }
  });

  const onExit = term.onExit(() => {
    if (ws.readyState === WebSocket.OPEN) ws.close();
  });

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (msg.type === 'input' && typeof msg.data === 'string') {
      term.write(msg.data);
    } else if (msg.type === 'resize' && Number.isFinite(msg.cols) && Number.isFinite(msg.rows)) {
      try {
        term.resize(Math.max(1, msg.cols), Math.max(1, msg.rows));
      } catch {
        // ignorar resize inválido
      }
    }
  });

  ws.on('close', () => {
    onData.dispose();
    onExit.dispose();
    term.kill();
  });
});

server.listen(PORT, () => {
  console.log(`Claude Code Remote Control escuchando en http://localhost:${PORT}`);
  console.log('Exponelo a internet con, por ejemplo: cloudflared tunnel --url http://localhost:' + PORT);
});
