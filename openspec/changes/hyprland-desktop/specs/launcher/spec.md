## Purpose

Provides a single keyboard-driven omnibox to find and raise open windows, start applications, and reach other sources such as calculator, clipboard history, files and power actions.

## ADDED Requirements

### Requirement: Omnibox on Super+Space
Super+Space SHALL open a search prompt that filters as the user types and acts on the selected entry with Enter. Escape SHALL close it without action.

#### Scenario: Open and dismiss
- **WHEN** the user presses Super+Space and then Escape
- **THEN** the prompt appears and closes again without side effects

### Requirement: Open windows as entries
Each open window SHALL appear as its own entry, identifiable by application and window title, ranked above application entries for the same query. Selecting it SHALL raise and focus that window without moving it.

#### Scenario: Raise one of two windows of the same app
- **WHEN** two Firefox windows are open and the user types "fire" and selects the second window's entry
- **THEN** that specific window is brought to front on its monitor and focused

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
