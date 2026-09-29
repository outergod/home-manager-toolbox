## Purpose

Defines the GNOME-inspired window model: each monitor holds a stack of full-screen windows, with opt-in half splits, floating dialogs, no user-facing workspaces, and keyboard control of windows and monitors.

## ADDED Requirements

### Requirement: Fixed monitor arrangement
The two BenQ PD3200U monitors SHALL be arranged side by side at native resolution and scale 2, matching their physical placement (the left one currently connected via HDMI, the right one via DisplayPort). Each monitor SHALL be identified by its description (model and serial), not by connector name.

#### Scenario: Monitors survive a cable change
- **WHEN** a monitor is connected through a different port
- **THEN** the arrangement and scale stay the same

### Requirement: One stack per monitor
Each monitor SHALL show exactly one workspace. By default, every tiled window SHALL fill the monitor's usable area (below the bar), with the most recently focused window in front. Opening a new window SHALL put it in front, filling the monitor.

#### Scenario: New window takes over the screen
- **WHEN** a window is open on a monitor and a second tiled window opens there
- **THEN** the new window fills the monitor's usable area in front of the first

#### Scenario: Focusing brings to front
- **WHEN** a window hidden behind another on the same monitor is focused
- **THEN** it is shown in front, filling the monitor

### Requirement: No workspace switching
The user SHALL NOT need to manage or switch workspaces; there SHALL be no workspace keybindings.

#### Scenario: No hidden workspaces
- **WHEN** any window is open
- **THEN** it is on one of the two monitors' stacks

### Requirement: Opt-in half splits
Super+Left and Super+Right SHALL split the current monitor in halves, putting the focused window on the chosen side and the most recently used other window of that monitor on the other side. Super+Up SHALL return the monitor to the full stack. Only halves are supported.

#### Scenario: Split with previous window
- **WHEN** window A is focused on a monitor whose previously focused window is B, and the user presses Super+Left
- **THEN** A occupies the left half and B the right half of that monitor

#### Scenario: Return to stack
- **WHEN** a monitor is split and the user presses Super+Up
- **THEN** the focused window fills the monitor again, with the others behind it

#### Scenario: Split ends when a partner leaves
- **WHEN** one of the two split windows is closed or moved to the other monitor
- **THEN** the remaining windows on that monitor return to the full stack

### Requirement: Dialogs float
Dialogs and other transient or fixed-size windows SHALL float at their own size, centred over their parent or monitor, and SHALL NOT be maximized, fullscreened or tiled.

#### Scenario: File chooser stays a dialog
- **WHEN** an application opens a file chooser, confirmation dialog or authentication prompt
- **THEN** it appears as a floating window at its natural size, not filling the monitor

### Requirement: Moving windows between monitors
Super+Shift+Left and Super+Shift+Right SHALL move the focused window to the monitor in that direction, putting it in front there.

#### Scenario: Move to other monitor
- **WHEN** the user presses Super+Shift+Right on a window on the left monitor
- **THEN** the window appears in front on the right monitor and keeps focus

### Requirement: Focus follows mouse and raising does not move windows
Keyboard focus SHALL follow the mouse pointer. Raising or focusing a window by keyboard or launcher SHALL NOT move it to another monitor; instead the pointer SHALL move to the raised window.

#### Scenario: Raise window on the other monitor
- **WHEN** the pointer is on the left monitor and the user raises a window that lives on the right monitor
- **THEN** the window stays on the right monitor, comes to front there, and the pointer and focus move to it

### Requirement: Window keybindings
Super+Q SHALL close the focused window. Alt+Tab SHALL focus the previously focused window. Super+F SHALL toggle true fullscreen for the focused window. Super with left/right mouse drag SHALL move/resize floating windows.

#### Scenario: Close window
- **WHEN** the user presses Super+Q
- **THEN** the focused window is asked to close

#### Scenario: Toggle between two windows
- **WHEN** the user focuses window A, then window B, then presses Alt+Tab
- **THEN** window A is focused

### Requirement: Fullscreen modes
Normally, windows SHALL leave the bar visible. Applications SHALL be able to enter true fullscreen themselves (e.g. video, games, F11), which hides the bar on that monitor.

#### Scenario: Application goes fullscreen
- **WHEN** an application requests fullscreen
- **THEN** it covers the whole monitor including the bar's area, and leaving fullscreen restores the bar
