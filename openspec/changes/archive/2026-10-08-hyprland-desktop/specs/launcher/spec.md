## Purpose

Provides a single keyboard-driven omnibox to find and raise open windows, start applications, and reach other sources such as calculator, clipboard history, files and power actions.

## ADDED Requirements

### Requirement: Omnibox on Ctrl+Space
Ctrl+Space SHALL open a search prompt that filters as the user types and acts on the selected entry with Enter. Escape SHALL close it without action. Ctrl+Space is Cmd+Space on the Kyria in Mac mode, matching Spotlight on macOS; applications no longer receive Ctrl+Space.

#### Scenario: Open and dismiss
- **WHEN** the user presses Ctrl+Space and then Escape
- **THEN** the prompt appears and closes again without side effects

### Requirement: Window switcher on Super+Space
Super+Space SHALL open a searchable list in which each open window is its own entry, identifiable by application and window title. Selecting an entry SHALL raise and focus that window without moving it, including windows behind others and on the other monitor.

#### Scenario: Raise one of two windows of the same app
- **WHEN** two Foot windows are open, the user presses Super+Space, types "foot" and selects the second window's entry
- **THEN** that specific window is brought to front on its monitor and focused, and the pointer moves to it

#### Scenario: Raise a window behind another
- **WHEN** a window is behind the front window on its monitor and the user selects it in the window switcher
- **THEN** it becomes the front window and is focused

### Requirement: Applications as entries
Installed applications SHALL appear as entries; selecting one SHALL start a new instance as a session-managed app. Each application SHALL appear only once (no duplicate host/container entries).

#### Scenario: Start an application
- **WHEN** the user types "zed" and selects the Zed application entry
- **THEN** Zed starts (inside the dev container) and there is only one Zed application entry to choose from

### Requirement: Prefixed sources
The omnibox SHALL offer at least calculator, clipboard history, files and power actions (lock, log out, suspend, reboot, power off) as additional sources, each reachable unambiguously via a prefix.

#### Scenario: Calculator
- **WHEN** the user enters an arithmetic expression, with or without the calculator prefix
- **THEN** the result is shown and can be copied

#### Scenario: Clipboard history
- **WHEN** the user uses the clipboard prefix
- **THEN** recent clipboard entries are listed and selecting one puts it on the clipboard

#### Scenario: Power actions
- **WHEN** the user uses the power prefix and selects "Lock"
- **THEN** the session is locked via the standard lock path
