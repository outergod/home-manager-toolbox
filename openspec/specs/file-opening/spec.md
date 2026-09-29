# file-opening Specification

## Purpose

Ensures `xdg-open` opens the file the user named, including relative paths, in the default application (native or flatpak), from the Hyprland session and from the nix container.

## Requirements

### Requirement: Relative paths resolve against the caller's directory
In the Hyprland session, `xdg-open <relative path>` SHALL open the file at that path relative to the working directory of the process that ran `xdg-open`, regardless of whether the default handler is a native application or a flatpak.

#### Scenario: Flatpak handler, relative path
- **WHEN** the user runs `xdg-open Screencast.mp4` in `~/Videos/Screencasts` and the default video handler is a flatpak (e.g. Showtime)
- **THEN** the handler opens `~/Videos/Screencasts/Screencast.mp4`

#### Scenario: Native handler, relative path
- **WHEN** the user runs `xdg-open notes.txt` in a directory other than `$HOME` and the default handler is a native application
- **THEN** the handler opens `notes.txt` from that directory

#### Scenario: Relative path with subdirectories and dot segments
- **WHEN** the user runs `xdg-open ../Pictures/a.png` or `xdg-open ./sub/a.png`
- **THEN** the file at that path relative to the working directory is opened

### Requirement: Same behaviour from the nix container
`xdg-open` run inside the `nix` distrobox container SHALL open relative paths against the working directory it was run in, with the same result as on the host.

#### Scenario: Relative path from the container
- **WHEN** the user runs `xdg-open Screencast.mp4` inside the container in `~/Videos/Screencasts`, while logged into Hyprland
- **THEN** the host's default handler opens `~/Videos/Screencasts/Screencast.mp4`

### Requirement: File names are passed through intact
Resolving a relative path SHALL NOT alter the file name. Names with spaces, non-ASCII characters, or characters that are special in URIs (such as `#`, `%`, `?`) SHALL open the file with exactly that name.

#### Scenario: Name with spaces and special characters
- **WHEN** the user runs `xdg-open 'Clip #1 (50%).mp4'` in the directory containing that file
- **THEN** the handler opens that file

### Requirement: Missing files are not opened elsewhere
If a relative path does not name an existing file in the working directory, `xdg-open` SHALL NOT open a file of the same name from any other directory, and SHALL exit with a non-zero status.

#### Scenario: Missing file with a namesake in HOME
- **WHEN** `~/foo.txt` exists and the user runs `xdg-open foo.txt` in a directory that has no `foo.txt`
- **THEN** `~/foo.txt` is not opened and `xdg-open` exits with a non-zero status

### Requirement: Other arguments unchanged
Absolute paths, `file://` URIs and non-file URIs (e.g. `https://`, `mailto:`) SHALL be opened as before this change.

#### Scenario: Absolute path
- **WHEN** the user runs `xdg-open /home/<user>/Videos/Screencasts/Screencast.mp4`
- **THEN** the default handler opens that file

#### Scenario: Web URL
- **WHEN** the user runs `xdg-open https://example.org`
- **THEN** the default browser opens that URL

### Requirement: Image's xdg-utils untouched
The image's `xdg-utils` installation SHALL NOT be modified or replaced system-wide.

#### Scenario: Image files unchanged
- **WHEN** the system's `/usr/bin/xdg-open` is inspected after activation
- **THEN** it is the image's unmodified file

### Requirement: GNOME fallback keeps opening files
In the GNOME fallback session, `xdg-open` SHALL still open files, including relative paths, in the default application.

#### Scenario: Relative path in GNOME
- **WHEN** the user logs into GNOME and runs `xdg-open` with a relative path
- **THEN** the file from the working directory is opened in the default application
