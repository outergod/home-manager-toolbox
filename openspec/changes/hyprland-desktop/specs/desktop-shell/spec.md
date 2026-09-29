## Purpose

Defines the desktop shell layer (bar, notifications, system controls, wallpaper, screenshots, clipboard, automount, fallback terminal), how the shell is chosen through a structured tryout, and how its configuration is owned.

## ADDED Requirements

### Requirement: Shell chosen by tryout
The desktop shell and launcher SHALL be chosen by trying DankMaterialShell and Noctalia 5, each combined with its built-in launcher, Vicinae and Walker, against a fixed checklist (Hyprland 0.56 compatibility, lock/polkit/idle guardrails, caffeine, launcher requirements, bar, notifications, screenshots, config ownership, theming). The results and the decision SHALL be recorded in the change's design before the shell phase is complete. Switching between candidates SHALL be possible by a single configuration change and reversible by rollback.

#### Scenario: Switch candidates
- **WHEN** the configured shell candidate is changed and activated
- **THEN** only the newly selected shell and launcher run in the next Hyprland session

#### Scenario: Candidate fails a guardrail
- **WHEN** a candidate cannot disable its own lock screen or polkit agent, or cannot route lock actions to the standard lock path
- **THEN** it is rejected regardless of other criteria

### Requirement: Bar
A bar SHALL be shown at the top of each configured monitor with clock, tray, volume, Bluetooth and network controls, and a caffeine toggle.

#### Scenario: Adjust volume from the bar
- **WHEN** the user interacts with the volume control in the bar
- **THEN** the output volume changes and the new level is shown

#### Scenario: Tray apps
- **WHEN** an application with a tray icon (e.g. Bitwarden, Synology Drive, Steam) is running
- **THEN** its icon appears in the bar's tray and its menu works

### Requirement: Notifications
Notifications SHALL be shown as popups and SHALL support a do-not-disturb mode and a history of recent notifications.

#### Scenario: Do not disturb
- **WHEN** do-not-disturb is enabled and a normal notification arrives
- **THEN** no popup appears, and the notification is available in the history

### Requirement: On-screen feedback for volume and media keys
Volume and media keys SHALL work, including while locked, and volume changes SHALL show on-screen feedback when unlocked.

#### Scenario: Volume key
- **WHEN** the user presses a volume key
- **THEN** the volume changes and an indicator shows the new level

### Requirement: Wallpaper
Each monitor SHALL show a configured wallpaper.

#### Scenario: Wallpaper after login
- **WHEN** the Hyprland session starts
- **THEN** both monitors show the configured wallpaper instead of the Hyprland default

### Requirement: Screenshot UI
Print SHALL open a screenshot interface to capture a region, a window or a whole monitor. Captures SHALL be copied to the clipboard and saved under `~/Pictures/Screenshots`, and SHALL work correctly on both monitors at scale 2.

#### Scenario: Region screenshot
- **WHEN** the user presses Print, selects a region on the right monitor and confirms
- **THEN** exactly that region at full resolution is on the clipboard and saved as a file

### Requirement: Clipboard history
Clipboard contents copied in the Hyprland session SHALL be recorded and retrievable through the omnibox.

#### Scenario: Recall earlier copy
- **WHEN** the user copies text A, then text B, then selects A from clipboard history
- **THEN** A is on the clipboard again

### Requirement: Removable media automount
Removable drives SHALL be mounted automatically when connected in the Hyprland session, without double-mounting when GNOME is in use.

#### Scenario: USB stick
- **WHEN** a USB drive with a supported filesystem is connected
- **THEN** it is mounted and accessible without manual commands

### Requirement: Fallback terminal
A terminal emulator SHALL be available that does not depend on GPU acceleration, so it works when Emacs or GL-dependent apps fail.

#### Scenario: Terminal without GPU stack
- **WHEN** GL-dependent applications fail to start
- **THEN** the fallback terminal still opens

### Requirement: Single owner for every config file
Every configuration file of the desktop SHALL be managed by exactly one of Home Manager or chezmoi, or deliberately left unmanaged. The ownership of the chosen shell's configuration SHALL be decided and recorded after the tryout.

#### Scenario: No ownership conflict
- **WHEN** `home-manager switch` and `chezmoi apply` are run in any order
- **THEN** neither fails or overwrites a file owned by the other
