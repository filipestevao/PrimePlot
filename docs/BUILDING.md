# Build from Source

PrimePlot is currently in alpha, so there are no pre-built binaries yet. Build it from source using the steps below.

## Prerequisites

- **[Rust](https://www.rust-lang.org/tools/install)** — install via `rustup` (recommended):
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  ```
- **[Flutter](https://docs.flutter.dev/get-started/install)** — follow the official installation guide for your platform and make sure `flutter doctor` reports no blocking issues.

## Build steps

1. Clone the repository:
   ```bash
   git clone https://github.com/filipestevao/PrimePlot.git
   cd PrimePlot
   ```
2. Enter the `frontend` directory:
   ```bash
   cd frontend
   ```
3. Build for your platform:

   **Linux**
   ```bash
   flutter build linux
   ```

   On first launch the Linux build registers a per-user launcher entry and icon under `$XDG_DATA_HOME` (default `~/.local/share`), so the taskbar icon resolves by application id on Wayland even when only the copied bundle folder is present. If the home directory is read-only or you prefer manual registration, run from `frontend`:
   ```bash
   ./linux/install_desktop_entry.sh
   ```
   Re-run the script after switching build modes or moving the bundle.

   **Windows**
   ```bash
   flutter build windows
   ```

   **macOS**
   ```bash
   flutter build macos
   ```

4. Once the build finishes, the compiled application will be available under `build/<platform>/` inside the `frontend` folder (e.g. `build/linux/x64/release/bundle`).

> [!NOTE]
> Since the project is under active development, build steps and requirements may change without notice until a first stable release is tagged.
