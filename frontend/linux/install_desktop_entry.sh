#!/usr/bin/env bash
# Copyright (C) 2026 Filipe Estevão
# This program is licensed under the GPLv3. See LICENSE for details.

# Install or refresh a per-user launcher entry and hicolor icon for a built
# Linux bundle. This is what lets KDE (and other Wayland compositors) resolve
# the taskbar icon by application id instead of showing a generic icon.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
frontend_dir="$(dirname "$script_dir")"
bundle="${1:-}"

if [[ -z "$bundle" ]]; then
  for candidate in \
    "$frontend_dir/build/linux/x64/debug/bundle" \
    "$frontend_dir/build/linux/x64/release/bundle"; do
    if [[ -x "$candidate/PrimePlot" ]]; then
      bundle="$candidate"
      break
    fi
  done
fi

if [[ -z "$bundle" || ! -x "$bundle/PrimePlot" ]]; then
  echo "usage: $0 [path-to-linux-bundle]" >&2
  echo "Build first with: flutter build linux --debug" >&2
  exit 1
fi

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
desktop_dir="$data_home/applications"
icon_dir="$data_home/icons/hicolor/512x512/apps"
icon_src="$bundle/share/icons/hicolor/512x512/apps/com.primeplot.frontend.png"
desktop_src="$bundle/share/applications/com.primeplot.frontend.desktop"

if [[ ! -f "$icon_src" || ! -f "$desktop_src" ]]; then
  echo "Bundle is missing desktop integration files: $bundle" >&2
  exit 1
fi

install -d "$desktop_dir" "$icon_dir"
install -m 644 "$icon_src" "$icon_dir/com.primeplot.frontend.png"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
sed "s|^Exec=.*|Exec=\"$bundle/PrimePlot\"|" "$desktop_src" > "$tmp"
install -m 644 "$tmp" "$desktop_dir/com.primeplot.frontend.desktop"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop_dir/com.primeplot.frontend.desktop" || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$desktop_dir" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$data_home/icons/hicolor" 2>/dev/null || true
fi

printf 'Installed %s\n' "$desktop_dir/com.primeplot.frontend.desktop"
