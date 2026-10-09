## MODIFIED Requirements

### Requirement: Fixed monitor arrangement
The BenQ PD3200U SHALL run at native resolution and scale 2. It SHALL be identified by its description (model and serial), not by connector name. Any other display, such as a laptop panel or an external screen on another machine using this configuration, SHALL be placed automatically next to the connected ones, at its preferred mode, without configuration.

#### Scenario: Monitors survive a cable change
- **WHEN** the BenQ is connected through a different port
- **THEN** its resolution and scale stay the same

#### Scenario: Another display connects
- **WHEN** a display other than the BenQ connects
- **THEN** it is placed next to the connected monitors at its preferred mode and holds a stack of its own

### Requirement: One stack per monitor
Each connected monitor SHALL show exactly one workspace. By default, every tiled window SHALL fill the monitor's usable area (below the bar), with the most recently focused window in front. Opening a new window SHALL put it in front, filling the monitor. Closing the focused window SHALL bring the most recently focused remaining window of that monitor to the front, regardless of the order the windows were opened in.

#### Scenario: New window takes over the screen
- **WHEN** a window is open on a monitor and a second tiled window opens there
- **THEN** the new window fills the monitor's usable area in front of the first

#### Scenario: Focusing brings to front
- **WHEN** a window hidden behind another on the same monitor is focused
- **THEN** it is shown in front, filling the monitor

#### Scenario: Closing the front window shows the previous one
- **WHEN** windows A, B and C are open on a monitor, in any order of opening, the user focuses A, then B, then C, and closes C
- **THEN** B is in front and focused, not A or any other window on that monitor

### Requirement: No workspace switching
The user SHALL NOT need to manage or switch workspaces; there SHALL be no workspace keybindings.

#### Scenario: No hidden workspaces
- **WHEN** any window is open
- **THEN** it is on the stack of a connected monitor

#### Scenario: No hidden workspaces after monitor changes
- **WHEN** monitors have disconnected and reconnected, in any combination, and the session has settled
- **THEN** every open window is on the stack of a connected monitor, and no monitor shows an empty extra workspace while windows exist

## ADDED Requirements

### Requirement: Stacks survive monitor changes
When a monitor disconnects while another one stays connected, its windows SHALL join the stack of a remaining monitor, keeping their order of use relative to the windows already there. When the last monitor disconnects, for example because its input is switched to another machine or it goes into standby, and a monitor connects again, all windows SHALL be on that monitor's stack, with the most recently used window in front and focused. A monitor that connects while another one is already connected SHALL start with an empty stack; windows SHALL NOT move to it on their own.

#### Scenario: One of two monitors disconnects
- **WHEN** two monitors are connected and one of them disconnects
- **THEN** its windows join the remaining monitor's stack in their order of use, so the most recently used window of both stacks is in front and focused

#### Scenario: The only monitor leaves and returns
- **WHEN** only one monitor is connected, window A is focused, and the monitor's input is switched to another machine and back
- **THEN** A is in front and focused, and every other window is in the stack behind it

#### Scenario: A monitor connects next to another
- **WHEN** one monitor is connected with windows on it and a second monitor connects
- **THEN** the second monitor shows an empty stack, and the windows stay on the first monitor until moved with Super+Shift+Left/Right
