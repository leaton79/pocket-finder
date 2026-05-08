# Pocket Finder

Pocket Finder is a macOS-first desktop file-explorer widget. It sits on the
desktop layer like a desktop companion, defaults to the user's Desktop folder,
and provides quick file browsing, opening, moving, renaming, folder creation,
Trash-only deletion, search, sorting, and common-folder switching.

The app is built with SwiftPM, SwiftUI, and narrow AppKit bridges. SwiftUI owns
the shell and styling, while AppKit handles the macOS-specific desktop window,
native table selection, drag/drop, Finder reveal, and default-app opening.

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Swift 6-compatible toolchain

Check your toolchain:

```bash
swift --version
```

## Run

From the project root:

```bash
./script/build_and_run.sh
```

This builds a debug app bundle in `dist/DesktopFileWidget.app` and launches it
in the background so it appears on the desktop layer rather than in front of
your active apps.

## Package and Install Locally

```bash
./script/package_app.sh
./script/install_app.sh
```

`package_app.sh` creates a release `.app` bundle at `dist/Pocket Finder.app`
and ad-hoc signs it for local use on this Mac. `install_app.sh` copies it to
`/Applications` when writable, otherwise to `~/Applications`.

After install, launch it from Finder, Spotlight, Launchpad, or:

```bash
open -g -n "/Applications/Pocket Finder.app"
```

## Checks

```bash
swift test
swift build
```

## Current Features

- Desktop-layer widget window.
- Bottom-left screen placement.
- Desktop default folder.
- Folder selector for Desktop, Downloads, Documents, Home, and mounted volumes.
- Native file/folder list with icons and metadata.
- Sort by name, date, type, and size.
- Search visible items.
- Open folders in-widget.
- Open files with the system default app.
- Command double-click reveals items in Finder.
- Rename files and folders.
- Move files and folders without overwriting existing destination items.
- Create folders.
- Move to Trash only, with confirmation.
- Multi-select with native table selection behavior.
- Drag selected files/folders as move/delete operations.
- Light, dark, and system themes.
- Header close and minimize controls. Minimize collapses the desktop widget into
  a small strip because the app runs as a desktop accessory without a standard
  Dock minimize target.

## Common Workflows

### Browse Folders

Double-click a folder row to open it inside the widget. Use the back, forward,
and parent-folder buttons beside the folder selector to navigate.

### Reveal in Finder

Hold Command and double-click a row to reveal it in Finder.

### Move Files

Select one or more rows, then drag from a selected row to move them to another
destination that accepts file moves. You can also use the context menu and choose
`Move...`.

### Copy Files

Copy is intended as a keyboard workflow. Select files, then use Finder-style
copy/paste from the destination context where supported. Dragging from Pocket
Finder advertises move/delete operations rather than copy.

### Delete Files

Use the context menu and choose `Move to Trash`. Permanent delete is not
implemented.

## macOS Folder Permissions

macOS protects Desktop, Documents, and Downloads. On first launch, Pocket Finder
may ask for access. Allow access so the widget can list your Desktop files.

If you previously denied access or the widget shows a permission error:

1. Open `System Settings`.
2. Go to `Privacy & Security`.
3. Open `Files and Folders`.
4. Enable Desktop, Documents, and Downloads for `Pocket Finder`.
5. If `Pocket Finder` is not listed, open `Full Disk Access`, add
   `/Applications/Pocket Finder.app`, and enable it.
6. Quit and reopen Pocket Finder.

## Project Structure

- `Sources/DesktopFileWidgetApp`: macOS app shell, SwiftUI views, AppKit window/table bridges.
- `Sources/DesktopFileWidgetCore`: file models, sorting, and filesystem operations.
- `Tests/DesktopFileWidgetCoreTests`: core behavior tests.
- `script/build_and_run.sh`: debug build and launch helper.
- `script/package_app.sh`: release `.app` bundle creation and ad-hoc signing.
- `script/install_app.sh`: local install helper.

## Distribution Notes

The packaged app is ad-hoc signed for local use on your Mac. It is not notarized
and is not ready for public distribution outside your own machines without a
Developer ID signing identity and notarization workflow.

## License

This project is licensed under the GNU General Public License v3.0. See
[LICENSE](LICENSE).

## Typography

Rows request Roboto when the font is installed on the system. If Roboto is
unavailable, the app falls back to the native rounded system font for
readability. Roboto is not bundled in v1 to keep the app dependency-free and
because SwiftPM GUI app font bundling is better handled once a signed app bundle
pipeline exists.
