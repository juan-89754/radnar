"""
Radnar - BeeWare/Toga entry point.

This module launches the Django development server inside a Toga WebView,
allowing the Django app to run as a native Android application.
"""

import asyncio
import os
import socket
import sys
import threading

import toga
from toga.style import Pack
from toga.style.pack import COLUMN

SPLASH_HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      background-color: #0f172a;
      color: #ffffff;
      font-family: system-ui, -apple-system, sans-serif;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      text-align: center;
    }
    .spinner {
      border: 4px solid rgba(255, 255, 255, 0.1);
      width: 44px;
      height: 44px;
      border-radius: 50%;
      border-left-color: #38bdf8;
      animation: spin 0.8s linear infinite;
      margin-bottom: 20px;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    h2 { font-weight: 600; margin: 0 0 8px 0; font-size: 1.2rem; }
    p { color: #94a3b8; font-size: 0.85rem; margin: 0; }
  </style>
</head>
<body>
  <div class="spinner"></div>
  <h2>Iniciando Radnar...</h2>
  <p>Cargando servidor embebido de Django</p>
</body>
</html>"""

ERROR_HTML = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      background-color: #0f172a;
      color: #ef4444;
      font-family: system-ui, -apple-system, sans-serif;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      padding: 20px;
      text-align: center;
      box-sizing: border-box;
    }
    h2 { font-weight: 600; margin: 0 0 8px 0; }
    p { color: #cbd5e1; font-size: 0.9rem; }
  </style>
</head>
<body>
  <h2>Error al iniciar Radnar</h2>
  <p>El servidor interno de Django no respondió a tiempo en 127.0.0.1:8080.</p>
</body>
</html>"""


def start_django_server():
    """Start the Django development server in a background thread."""
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if project_root not in sys.path:
        sys.path.insert(0, project_root)

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

    try:
        from django.core.management import execute_from_command_line

        # Run database migrations automatically on startup
        print("[Radnar] Verificando e instalando migraciones de Django...")
        try:
            execute_from_command_line(["manage", "migrate", "--noinput"])
            print("[Radnar] Migraciones listas.")
        except Exception as err:
            print(f"[Radnar] Aviso en migraciones: {err}", file=sys.stderr)

        print("[Radnar] Iniciando servidor Django en 127.0.0.1:8080...")
        execute_from_command_line(["manage", "runserver", "127.0.0.1:8080", "--noreload"])
    except Exception as e:
        print(f"[Radnar] Error crítico en el servidor Django: {e}", file=sys.stderr)


class RadnarApp(toga.App):
    """Main Toga application that wraps the Django app in a WebView."""

    def startup(self):
        # Create WebView initialized with Splash HTML
        self.webview = toga.WebView(style=Pack(flex=1))
        self.webview.set_content("http://127.0.0.1:8080/", SPLASH_HTML)

        box = toga.Box(
            children=[self.webview],
            style=Pack(direction=COLUMN, flex=1),
        )

        self.main_window = toga.MainWindow(title=self.formal_name)
        self.main_window.content = box
        self.main_window.show()

        # Start Django server in daemon thread
        server_thread = threading.Thread(target=start_django_server, daemon=True)
        server_thread.start()

        # Start async polling task to redirect WebView once server is ready
        self.add_background_task(self.check_server_and_redirect)

    async def check_server_and_redirect(self, app, **kwargs):
        """Poll port 8080 until Django accepts connections, then load app URL."""
        target_url = "http://127.0.0.1:8080/"
        max_attempts = 60  # Try for up to 30 seconds

        for attempt in range(max_attempts):
            try:
                # Test TCP connection to local port 8080
                with socket.create_connection(("127.0.0.1", 8080), timeout=0.5):
                    print(f"[Radnar] Servidor activo detectado tras {attempt * 0.5:.1f}s.")
                    await asyncio.sleep(0.2)
                    self.webview.url = target_url
                    return
            except OSError:
                await asyncio.sleep(0.5)

        print("[Radnar] Timeout: No se pudo conectar con el servidor Django.", file=sys.stderr)
        self.webview.set_content("http://127.0.0.1:8080/", ERROR_HTML)


def main():
    return RadnarApp(
        "Radnar App",
        app_id="com.radnar",
    )

