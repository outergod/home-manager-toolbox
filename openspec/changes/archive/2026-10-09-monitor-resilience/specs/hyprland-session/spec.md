## MODIFIED Requirements

### Requirement: Clean Hyprland configuration
The Hyprland configuration SHALL be generated from the Home Manager flake in Hyprland 0.56's Lua format and SHALL load without configuration errors. Its scripts SHALL NOT raise errors at runtime, including while monitors disconnect and reconnect.

#### Scenario: Session starts without config errors
- **WHEN** the user logs in via SDDM into "Hyprland (uwsm-managed)" after `home-manager switch`
- **THEN** `hyprctl configerrors` reports no errors

#### Scenario: Config edits apply without re-login
- **WHEN** the Hyprland configuration is changed and activated
- **THEN** the running session reloads it without the user logging out

#### Scenario: Monitor changes raise no errors
- **WHEN** the only monitor disconnects and reconnects (input switched away and back, or standby), or one of two monitors disconnects
- **THEN** no error message appears and `hyprctl configerrors` reports no errors
