## Purpose

Makes the `nix` distrobox dev container ready at login so container-hosted applications like Emacs and Zed start on first use in any session, and keeps exactly one launcher entry per such application.

## ADDED Requirements

### Requirement: Container ready at login
The `nix` distrobox container SHALL be started and fully initialized automatically after the user logs in, in both the Hyprland and GNOME sessions, without the user entering it manually.

#### Scenario: Emacs works on first launch after boot
- **WHEN** the user boots, logs in, and launches Emacs from the launcher without having entered the container
- **THEN** Emacs starts inside the container

#### Scenario: Zed works on first launch after boot
- **WHEN** the user boots, logs in, and launches Zed from the launcher
- **THEN** Zed starts inside the container

### Requirement: Container start does not block the desktop
Starting the container SHALL NOT delay the graphical session becoming usable.

#### Scenario: Desktop usable during container start
- **WHEN** the container is still initializing after login
- **THEN** the desktop, bar and launcher are already usable

### Requirement: One launcher entry per container app
Emacs and Zed SHALL each have exactly one application entry, the one that runs them inside the container. Host-profile duplicates SHALL NOT appear.

#### Scenario: Emacs client entry uses the container
- **WHEN** the user launches "Emacs Client" with no Emacs server running
- **THEN** an Emacs server is started inside the container and a new frame opens; later launches reuse that server

#### Scenario: No duplicate Zed entry
- **WHEN** the user searches for "Zed" in the launcher or GNOME overview
- **THEN** exactly one Zed application entry is shown, and it launches Zed in the container
