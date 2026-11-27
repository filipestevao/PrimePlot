# Changelog

All notable changes to PrimePlot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.2.0] - 2026-11-26

### Added
- X and Y error bars from `XError`/`YError` columns, with an optional color override.
- Legend bold-text toggle.
- Optional startup update check in Settings → Advanced, linking to GitHub releases.

### Changed
- New graphs default to 18 px axis titles and 15 px tick numbers.
- Logarithmic and square-root axes use smarter tick placement and minor ticks.

## [0.1.1] - 2026-11-20

### Added
- Window size and position persistence across launches.

### Fixed
- Clean shutdown and store teardown.
- Windows no longer restores a maximized window to its normal size on launch.
- Custom color dialog now shows only the color wheel.

## [0.1.0] - 2026-11-19

### Added
- First Alpha release
- Desktop UI with Property Inspector, Project Explorer, and Data Table
- Zipped `.primeplot` project persistence
- Interactive canvas with zoom, pan, and auto-scaling
- Function engine with mathematical expression parser
- Theme system (PrimePlot, Dark, Light)
- Column management and transforms
- Undo/Redo engine (20 snapshots)
- Figure and data export (PNG, CSV, TSV)
- LaTeX subscripts and superscripts for labels and legends
- Legend customization and advanced styling
- Intelligent axis divisions with nice-numbers algorithm
- Minor tick marks and sub-divisions
- Configurable marker sizing and shapes
- Custom color palettes (create, import, export)
- Keyboard shortcuts with remappable bindings
- Number formatting (Auto, Decimal, Scientific)
- Command palette search bar
