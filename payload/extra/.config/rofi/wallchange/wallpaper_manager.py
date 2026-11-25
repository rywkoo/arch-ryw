#!/usr/bin/env python3

import json
import os
import subprocess
import sys

from PyQt6.QtCore import Qt, QSize, QThread, pyqtSignal
from PyQt6.QtGui import QPixmap, QIcon
from PyQt6.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QLabel,
    QPushButton,
    QGridLayout,
    QScrollArea,
    QFrame,
    QMessageBox,
    QHBoxLayout,
)

WALL_DIR = os.path.expanduser("~/Pictures/wallpaper")
WALL_SCRIPT = os.path.expanduser("~/.config/rofi/wallchange/rofiwall.sh")
WAL_COLORS = os.path.expanduser("~/.cache/wal/colors.json")

THUMB_W = 320
THUMB_H = 180  # 16:9


def crop_to_fill(pixmap, target_w, target_h):
    """Scale a pixmap to fill target_w x target_h exactly, center-cropping
    any overflow so the aspect ratio is preserved with no letterboxing."""
    if pixmap.isNull():
        return pixmap

    scaled = pixmap.scaled(
        target_w,
        target_h,
        Qt.AspectRatioMode.KeepAspectRatioByExpanding,
        Qt.TransformationMode.SmoothTransformation,
    )

    x = max(0, (scaled.width() - target_w) // 2)
    y = max(0, (scaled.height() - target_h) // 2)

    return scaled.copy(x, y, target_w, target_h)


class ThumbnailLoaderWorker(QThread):
    """Loads and crops wallpaper thumbnails in the background so the
    window can appear instantly instead of blocking on image decode."""

    thumbnail_ready = pyqtSignal(str, QPixmap)
    finished_all = pyqtSignal()

    def __init__(self, file_paths):
        super().__init__()
        self.file_paths = file_paths

    def run(self):
        for path in self.file_paths:
            pixmap = QPixmap(path)
            if not pixmap.isNull():
                cropped = crop_to_fill(pixmap, THUMB_W, THUMB_H)
                self.thumbnail_ready.emit(path, cropped)
        self.finished_all.emit()


class WallpaperWorker(QThread):
    """Runs the wallpaper script in a background thread so the GUI
    never blocks/freezes while it executes."""

    finished_ok = pyqtSignal()
    failed = pyqtSignal(str)

    def __init__(self, image_path):
        super().__init__()
        self.image_path = image_path

    def run(self):
        try:
            subprocess.run(
                [WALL_SCRIPT, self.image_path],
                check=True,
                capture_output=True,
                text=True,
            )
            self.finished_ok.emit()
        except subprocess.CalledProcessError as e:
            detail = e.stderr.strip() if e.stderr else str(e)
            self.failed.emit(detail)
        except Exception as e:
            self.failed.emit(str(e))


class WallpaperButton(QPushButton):
    def __init__(self, image_path, callback):
        super().__init__()

        self.image_path = image_path

        self.setFixedSize(THUMB_W, THUMB_H)
        self.setCursor(Qt.CursorShape.PointingHandCursor)

        self.clicked.connect(
            lambda: callback(self.image_path)
        )

        self.setStyleSheet(
            """
            QPushButton {
                border-radius: 20px;
                border: 2px solid transparent;
                background: #222222;
            }

            QPushButton:hover {
                border: 2px solid #888888;
            }

            QPushButton:disabled {
                border: 2px solid #444444;
            }
            """
        )

    def set_thumbnail(self, cropped_pixmap):
        self.setIcon(QIcon(cropped_pixmap))
        self.setIconSize(QSize(THUMB_W, THUMB_H))


class ColorSwatch(QFrame):
    def __init__(self, color):
        super().__init__()

        self.setFixedSize(40, 40)

        self.setStyleSheet(
            f"""
            background-color: {color};
            border-radius: 10px;
            border: 1px solid rgba(255,255,255,0.15);
            """
        )


class WallpaperManager(QWidget):
    def __init__(self):
        super().__init__()

        self.worker = None
        self.thumbnail_loader = None
        self.button_by_path = {}

        self.setWindowTitle("Wallpaper Manager")
        self.resize(1200, 900)

        self.setStyleSheet(
            """
            QWidget {
                background-color: #121212;
                color: white;
                font-size: 14px;
            }
            """
        )

        main_layout = QVBoxLayout(self)

        title = QLabel("Wallpaper Manager")
        title.setStyleSheet(
            """
            font-size: 24px;
            font-weight: bold;
            padding: 10px;
            """
        )

        main_layout.addWidget(title)

        self.status_label = QLabel("")
        self.status_label.setStyleSheet(
            "color: #aaaaaa; padding: 0 10px 6px 10px;"
        )
        main_layout.addWidget(self.status_label)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)

        self.container = QWidget()
        self.grid = QGridLayout(self.container)

        self.scroll.setWidget(self.container)

        main_layout.addWidget(self.scroll)

        palette_title = QLabel("Pywal Colors")
        palette_title.setStyleSheet(
            """
            font-size: 18px;
            padding-top: 10px;
            """
        )

        main_layout.addWidget(palette_title)

        self.palette_layout = QHBoxLayout()
        main_layout.addLayout(self.palette_layout)

        self.buttons = []

        self.load_wallpapers()
        self.load_palette()

    def load_wallpapers(self):
        row = 0
        col = 0

        if not os.path.exists(WALL_DIR):
            return

        files = sorted(
            [
                f
                for f in os.listdir(WALL_DIR)
                if f.lower().endswith(
                    (".jpg", ".jpeg", ".png", ".webp")
                )
            ]
        )

        full_paths = []

        for filename in files:
            full_path = os.path.join(WALL_DIR, filename)
            full_paths.append(full_path)

            # Create the button immediately, with no thumbnail yet, so
            # the window can show right away. The icon is filled in once
            # the background loader finishes that image.
            btn = WallpaperButton(
                full_path,
                self.apply_wallpaper
            )

            self.grid.addWidget(btn, row, col)
            self.buttons.append(btn)
            self.button_by_path[full_path] = btn

            col += 1

            if col >= 3:
                col = 0
                row += 1

        if full_paths:
            self.thumbnail_loader = ThumbnailLoaderWorker(full_paths)
            self.thumbnail_loader.thumbnail_ready.connect(
                self.on_thumbnail_ready
            )
            self.thumbnail_loader.start()

    def on_thumbnail_ready(self, image_path, cropped_pixmap):
        btn = self.button_by_path.get(image_path)
        if btn is not None:
            btn.set_thumbnail(cropped_pixmap)

    def clear_palette(self):
        while self.palette_layout.count():
            item = self.palette_layout.takeAt(0)

            if item.widget():
                item.widget().deleteLater()

    def load_palette(self):
        self.clear_palette()

        if not os.path.exists(WAL_COLORS):
            return

        try:
            with open(WAL_COLORS, "r") as f:
                data = json.load(f)

            colors = data.get("colors", {})

            for i in range(16):
                color_name = f"color{i}"

                if color_name in colors:
                    self.palette_layout.addWidget(
                        ColorSwatch(colors[color_name])
                    )

        except Exception as e:
            print("Failed to load pywal colors:", e)

    def set_buttons_enabled(self, enabled):
        for btn in self.buttons:
            btn.setEnabled(enabled)

    def apply_wallpaper(self, image_path):
        if self.worker is not None and self.worker.isRunning():
            return  # already applying one, ignore extra clicks

        # Remember where the user was scrolled to, so we can restore it
        # after the disable/re-enable + palette rebuild below.
        self._saved_scroll_pos = self.scroll.verticalScrollBar().value()

        self.set_buttons_enabled(False)
        # Disabling buttons can shift Qt's focus chain and cause the
        # scroll area to jump on its own, so restore right away too.
        self.restore_scroll_pos()

        self.status_label.setText(
            f"Applying {os.path.basename(image_path)}..."
        )
        QApplication.setOverrideCursor(Qt.CursorShape.WaitCursor)

        self.worker = WallpaperWorker(image_path)
        self.worker.finished_ok.connect(self.on_wallpaper_applied)
        self.worker.failed.connect(self.on_wallpaper_failed)
        self.worker.start()

    def restore_scroll_pos(self):
        pos = getattr(self, "_saved_scroll_pos", None)
        if pos is None:
            return

        bar = self.scroll.verticalScrollBar()
        bar.setValue(pos)
        # Re-apply on the next event loop tick too, since the palette
        # rebuild / re-layout can override it within the same call.
        from PyQt6.QtCore import QTimer
        QTimer.singleShot(0, lambda: bar.setValue(pos))

    def on_wallpaper_applied(self):
        QApplication.restoreOverrideCursor()
        self.set_buttons_enabled(True)
        self.status_label.setText("")
        self.load_palette()
        self.restore_scroll_pos()

    def on_wallpaper_failed(self, detail):
        QApplication.restoreOverrideCursor()
        self.set_buttons_enabled(True)
        self.status_label.setText("")
        self.restore_scroll_pos()

        QMessageBox.critical(
            self,
            "Wallpaper Error",
            f"Wallpaper script failed:\n{detail}"
        )


def main():
    app = QApplication(sys.argv)

    window = WallpaperManager()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()