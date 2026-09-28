# M3 Niri Quickshell

Single-file Quickshell configuration designed for Niri.

Requires:
- Quickshell 0.3.x
- Niri
- `nmcli` for Wi-Fi status
- `wpctl` for volume status

Optional wallpaper backend:
- `swww`, or
- `awww`

Wallpapers go in `~/Pictures/Wallpapers`.

Run:
```sh
qs -c m3-niri
```

The config intentionally avoids external QML components and local singleton modules so it is
much less sensitive to QML import/module registration issues.

Official Quickshell docs:
https://quickshell.org/docs/v0.3.0/guide/qml-language/
https://quickshell.org/docs/v0.3.0/types/Quickshell/PanelWindow/
https://quickshell.org/docs/v0.3.0/types/Quickshell/PopupWindow/
