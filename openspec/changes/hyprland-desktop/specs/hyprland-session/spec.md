## Purpose

Defines how the Hyprland session is configured from Home Manager and integrated with uwsm, which components come from the image versus Nix, and how Hyprland-only services stay out of the GNOME fallback session.

## ADDED Requirements

### Requirement: Clean Hyprland configuration
The Hyprland configuration SHALL be generated from the Home Manager flake in Hyprland 0.56's Lua format and SHALL load without configuration errors.

#### Scenario: Session starts without config errors
- **WHEN** the user logs in via SDDM into "Hyprland (uwsm-managed)" after `home-manager switch`
- **THEN** `hyprctl configerrors` reports no errors

#### Scenario: Config edits apply without re-login
- **WHEN** the Hyprland configuration is changed and activated
- **THEN** the running session reloads it without the user logging out

### Requirement: Image-provided session components
Hyprland, hyprlock, hypridle, xdg-desktop-portal-hyprland, uwsm and hyprpolkitagent SHALL be used from the image. The Home Manager configuration MUST NOT install any of them from Nix, and MUST NOT install any Nix-built binary that checks user passwords.

#### Scenario: No Nix copies of image components
- **WHEN** the Home Manager profile is inspected after activation
- **THEN** it contains no hyprland, hyprlock, hypridle, xdg-desktop-portal-hyprland, uwsm or hyprpolkitagent binaries, and no lock screen or polkit agent

### Requirement: Hyprland-only services are scoped to the Hyprland session
Every user service that exists only for the Hyprland desktop (idle daemon, polkit agent, bar/shell, launcher daemon, clipboard history, automount, etc.) SHALL start only in the Hyprland session and SHALL NOT start in the GNOME session.

#### Scenario: Services run in Hyprland
- **WHEN** the user logs into the Hyprland session
- **THEN** the Hyprland-only services are active

#### Scenario: GNOME stays untouched
- **WHEN** the user logs into the GNOME session
- **THEN** none of the Hyprland-only services are running, and GNOME's own polkit agent handles authentication

### Requirement: Session-managed app launching
Applications launched from Hyprland (keybindings, launcher) SHALL run as uwsm-managed units, so they are part of the session and stop with it.

#### Scenario: Launched app belongs to the session
- **WHEN** an application is started from a keybinding or the launcher
- **THEN** it runs in its own user unit under the graphical session slices

### Requirement: Autostart
In the Hyprland session, Bitwarden, Synology Drive and Steam SHALL start at login using their existing installations. Vesktop SHALL NOT start at login in either session. Autostart entries restricted to other desktops SHALL NOT start in Hyprland.

#### Scenario: Wanted apps autostart
- **WHEN** the user logs into Hyprland
- **THEN** Bitwarden, Synology Drive and Steam are started, each from its single existing installation

#### Scenario: Vesktop does not autostart
- **WHEN** the user logs into Hyprland or GNOME
- **THEN** Vesktop is not started automatically

### Requirement: GNOME fallback remains usable
Nothing in this configuration SHALL prevent logging into the GNOME session, so that a broken Hyprland configuration can be repaired from GNOME.

#### Scenario: Recovery from a broken Hyprland config
- **WHEN** a Hyprland configuration change breaks the Hyprland session
- **THEN** the user can log into GNOME and roll back to the previous Home Manager generation
