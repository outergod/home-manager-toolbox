## Purpose

Ensures the Hyprland session is reliably locked on idle, on request and before suspend using the image's password-checking locker, that idle locking can be inhibited deliberately, and that polkit prompts work.

## ADDED Requirements

### Requirement: Single trusted locker
The session SHALL be locked exclusively by the image's `/usr/bin/hyprlock`, and every lock trigger SHALL go through `loginctl lock-session`. No other lock screen (including those built into desktop shells) SHALL be active.

#### Scenario: Only hyprlock locks
- **WHEN** a lock is triggered by any means (idle, keybinding, suspend, shell button)
- **THEN** the lock screen shown is hyprlock and unlocking accepts the user's password

### Requirement: Lock on idle
The session SHALL lock after 15 minutes of inactivity and SHALL turn the displays off after 20 minutes, turning them back on at activity.

#### Scenario: Idle lock
- **WHEN** there is no input for 15 minutes and no idle inhibitor is active
- **THEN** the session is locked

#### Scenario: Displays off after idle
- **WHEN** there is no input for 20 minutes
- **THEN** the displays are turned off, and they turn on again at the next input

### Requirement: Lock on keybinding
Super+L SHALL lock the session.

#### Scenario: Manual lock
- **WHEN** the user presses Super+L
- **THEN** the session is locked

### Requirement: Lock before suspend
The session SHALL be locked before the system suspends, and the first frame shown after resume SHALL be the lock screen.

#### Scenario: Suspend and resume
- **WHEN** the system suspends while the session is unlocked, and later resumes
- **THEN** no desktop content is visible after resume before the lock screen appears

### Requirement: Lock covers all windows
The lock screen SHALL cover every window on every monitor, including fullscreen applications and Steam.

#### Scenario: Lock over fullscreen Steam
- **WHEN** the session locks while Steam or another fullscreen application is showing
- **THEN** only the lock screen is visible on both monitors

### Requirement: Locker crash recovery
If the locker crashes, the session SHALL remain locked and SHALL allow restoring a working lock screen.

#### Scenario: Restore crashed locker
- **WHEN** hyprlock crashes while locked and the user runs `hyprctl --instance 0 eval 'hl.dispatch(hl.dsp.exec_cmd("/usr/bin/hyprlock"))'` from a TTY
- **THEN** a lock screen reappears and the password unlocks the session

### Requirement: Idle inhibition
Idle locking SHALL be inhibited automatically while a window is fullscreen, and SHALL be inhibitable manually through a visible toggle ("caffeine") that shows its state.

#### Scenario: Fullscreen video keeps the session awake
- **WHEN** a window is fullscreen for longer than the idle timeout
- **THEN** the session does not lock and the displays stay on

#### Scenario: Manual caffeine toggle
- **WHEN** the user enables the caffeine toggle and stays idle beyond the timeout
- **THEN** the session does not lock, and after disabling the toggle idle locking resumes

### Requirement: Polkit prompts and keyring
In the Hyprland session, privileged actions SHALL prompt through the image's polkit agent, and the login keyring SHALL be unlocked without an extra prompt.

#### Scenario: Polkit prompt appears
- **WHEN** an application requests a polkit-authorized action
- **THEN** an authentication dialog appears and accepts the user's password

#### Scenario: Keyring unlocked at login
- **WHEN** an application accesses the secret service after login
- **THEN** no keyring unlock prompt appears
