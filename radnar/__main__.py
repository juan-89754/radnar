"""
Radnar - BeeWare/Toga entry point.

This module launches the Django development server inside a Toga WebView,
allowing the Django app to run as a native Android application.
"""

import os
import sys
import threading

import toga
from toga.style import Pack
from toga.style.pack import COLUMN


def start_django_server():
    """Start the Django development server in a background thread."""
    # Ensure the project root is on sys.path so Django can find 'config.settings'
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if project_root not in sys.path:
        sys.path.insert(0, project_root)

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

    from django.core.management import execute_from_command_line

    execute_from_command_line(["manage", "runserver", "127.0.0.1:8080", "--noreload"])


class RadnarApp(toga.App):
    """Main Toga application that wraps the Django app in a WebView."""

    def startup(self):
        # Start Django server in a daemon thread
        server_thread = threading.Thread(target=start_django_server, daemon=True)
        server_thread.start()

        # Create main window with a WebView pointing to Django
        self.main_window = toga.MainWindow(title=self.formal_name)

        webview = toga.WebView(
            url="http://127.0.0.1:8080/",
            style=Pack(flex=1),
        )

        box = toga.Box(
            children=[webview],
            style=Pack(direction=COLUMN, flex=1),
        )

        self.main_window.content = box
        self.main_window.show()


def main():
    return RadnarApp(
        "Radnar App",
        app_id="com.radnar",
    )
