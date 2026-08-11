# Claude Code Remote

Controlá una sesión de Claude Code que corre en tu PC desde una app web en tu celular
(instalable como PWA), incluyendo entrada por voz.

Cómo funciona: en tu PC corre un servidor chiquito que se conecta a sesiones de `tmux`
donde tenés `claude` corriendo. El celular abre una página web que se conecta por
WebSocket a ese servidor y te muestra la terminal en tiempo real (con [xterm.js](https://xtermjs.org/)),
tal cual la verías en tu PC. Podés escribir o dictar por voz, y lo que mandes se
"tipea" directo en esa sesión.

```
Celular (PWA)  <--WebSocket-->  Servidor Node (tu PC)  <--PTY-->  tmux  <-->  claude
```

## 1. Requisitos en tu PC

- Node.js 18+
- [tmux](https://github.com/tmux/tmux/wiki)
- [Claude Code CLI](https://claude.com/claude-code) ya instalado y con sesión iniciada (`claude`)
- Herramientas de compilación nativas (para `node-pty`):
  - Linux: `sudo apt install build-essential python3`
  - macOS: `xcode-select --install`
  - Windows: se recomienda usar WSL

## 2. Instalar y configurar el servidor

```bash
cd server
npm install
cp .env.example .env
```

Editá `server/.env` y generá un token secreto:

```bash
openssl rand -hex 24
```

Pegalo en `AUTH_TOKEN=` dentro de `.env`. Este token es la contraseña que va a pedir
la app del celular — no lo compartas.

## 3. Levantar el servidor

```bash
npm start
```

Por defecto escucha en `http://localhost:3344`. Sirve tanto la API/WebSocket como la
página web del celu (todo desde el mismo puerto).

## 4. Crear una sesión de Claude Code

Podés crearla a mano en tu PC:

```bash
tmux new -s work
claude
# Ctrl+B, D para "detach" y dejarla corriendo en segundo plano
```

O crearla directamente desde la app del celular con el botón **"+ Nueva"** (arranca
`claude` automáticamente dentro de la sesión).

Podés tener varias sesiones de tmux en paralelo (una por proyecto, por ejemplo) y
elegir a cuál conectarte desde la app.

## 5. Exponer el servidor a internet (para acceder desde cualquier lado)

La forma más simple es [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/),
que te da una URL `https://...trycloudflare.com` sin necesidad de abrir puertos en tu router.

```bash
# instalar cloudflared (una vez)
# Linux: https://pkg.cloudflare.com/  |  macOS: brew install cloudflared

cloudflared tunnel --url http://localhost:3344
```

Te va a imprimir una URL pública. Esa es la que vas a poner en la app del celular.

> Nota: con `cloudflared tunnel --url` la URL cambia cada vez que reiniciás el túnel
> (túnel "rápido"). Si querés una URL fija, seguí la guía de Cloudflare para crear un
> túnel con nombre asociado a tu propio dominio.
>
> Alternativa: si preferís no depender de una URL pública, podés usar
> [Tailscale](https://tailscale.com/) instalando la app en la PC y en el celular —
> quedan en una red privada propia sin exponer nada a internet.

## 6. Instalar la app en el celular

1. Abrí la URL del túnel en el navegador del celu (Chrome recomendado).
2. Ingresá la URL del servidor y el token (`AUTH_TOKEN`).
3. Elegí una sesión de la lista (o creá una nueva).
4. Opcional: menú del navegador → **"Agregar a pantalla de inicio"** / **"Instalar app"**
   para que quede como una app normal, con ícono propio.

## 7. Usar el chat de voz

Tocá el botón del micrófono 🎤, dictá tu instrucción, y el texto transcripto aparece
en el campo de texto para que lo revises antes de enviar (tocando ➤ o Enter).

Usa la Web Speech API del navegador:
- **Android + Chrome**: funciona bien, sin configuración extra.
- **iOS + Safari**: el soporte es limitado o inexistente según la versión; si el botón
  aparece deshabilitado, escribí el mensaje directamente.

## Seguridad

- Todo el tráfico va por HTTPS/WSS gracias al túnel (Cloudflare o Tailscale).
- El servidor exige el `AUTH_TOKEN` tanto para listar/crear sesiones como para el
  WebSocket — sin el token correcto, no se puede hacer nada.
- No compartas la URL del túnel ni el token. Si creés que se filtró el token, generá
  uno nuevo en `.env` y reiniciá el servidor.
- Quien tenga el token puede escribir cualquier cosa en tu terminal — es equivalente a
  darle acceso a esa sesión de tu PC. Tratalo con el mismo cuidado que una contraseña.

## Estructura del proyecto

```
server/           servidor Node.js (Express + ws + node-pty)
  server.js
  package.json
  .env.example
public/           app web (PWA) que se sirve al celular
  index.html
  app.js
  style.css
  manifest.json
  sw.js
  icons/icon.svg
```
