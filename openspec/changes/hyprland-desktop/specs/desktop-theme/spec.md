## Purpose

Gives the Hyprland desktop a coherent, dark look across the compositor, shell, lock screen, terminal and applications, with a single owner for theming decisions.

## ADDED Requirements

### Requirement: Coherent look
Window borders, the bar/shell, the lock screen, the fallback terminal and GTK/Qt applications SHALL use one consistent dark colour scheme, font set and cursor theme.

#### Scenario: Lock screen matches desktop
- **WHEN** the session locks
- **THEN** the lock screen uses the same colour scheme and fonts as the desktop shell

#### Scenario: Applications follow dark preference
- **WHEN** a GTK or Qt application is opened in the Hyprland session
- **THEN** it uses the dark variant and the configured cursor theme

### Requirement: Single theming owner
Theme files for GTK, Qt and terminals SHALL be written by only one mechanism: either the Nix-defined palette or the chosen shell's theme generator.

#### Scenario: No theme fight
- **WHEN** the shell regenerates its colours and `home-manager switch` runs afterwards
- **THEN** neither overwrites or breaks theme files owned by the other

### Requirement: Bar placement
The bar SHALL be shown on a configurable selection of monitors (one or both).

#### Scenario: Bar on chosen monitors
- **WHEN** the bar is configured for a set of monitors
- **THEN** it appears on exactly those monitors

### Requirement: Optional bar reveal over fullscreen
If enabled, moving the pointer to the top edge of a monitor with a fullscreen non-game window SHALL reveal the bar temporarily; games SHALL be excluded.

#### Scenario: Reveal over fullscreen video
- **WHEN** a video player is fullscreen and the pointer touches the top edge
- **THEN** the bar appears until the pointer leaves it

#### Scenario: No reveal over games
- **WHEN** a game is fullscreen and the pointer touches the top edge
- **THEN** the bar does not appear
