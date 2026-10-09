# keyboard-input Specification

## Purpose

Defines keyboard layouts so keyboards whose firmware decides the layout, and synthetic keyboards whose keystrokes assume US, stay on plain US, while other keyboards default to US with switchable Dvorak.

## Requirements

### Requirement: US default with switchable Dvorak
Keyboards SHALL default to the US layout, and Super+Tab SHALL toggle between US and US Dvorak. Each press SHALL put every keyboard the toggle reaches on the same layout, including keyboards that were on different layouts before. The compose key SHALL be the Menu key.

#### Scenario: Toggle layout on a regular keyboard
- **WHEN** the user types on a regular keyboard and presses Super+Tab
- **THEN** subsequent input uses US Dvorak, and pressing Super+Tab again returns to US

#### Scenario: Keyboards that drifted apart come back together
- **WHEN** toggleable keyboards are on different layouts, e.g. a keyboard reconnected on US while the others were on Dvorak, and the user presses Super+Tab
- **THEN** all toggleable keyboards are on the same layout

### Requirement: Firmware-layout keyboards stay on plain US
The splitkb Kyria rev3 and the Drop Preonic SHALL always use the plain US layout, regardless of layout toggles, because their firmware decides the layout: the Kyria always produces Dvorak, and the Preonic switches between US and Dvorak itself.

#### Scenario: Kyria unaffected by toggle
- **WHEN** Super+Tab has switched other keyboards to Dvorak
- **THEN** typing on the Kyria still produces the characters its firmware sends under US

#### Scenario: Preonic unaffected by toggle
- **WHEN** Super+Tab has switched other keyboards to Dvorak
- **THEN** typing on the Preonic still produces the characters its firmware sends under US

### Requirement: Synthetic keyboards stay on US
The virtual keyboard through which the launcher pastes and expands snippets SHALL always use the plain US layout, regardless of layout toggles, so the keystrokes it sends produce the characters and shortcuts the launcher intends.

#### Scenario: Paste from clipboard history while on Dvorak
- **WHEN** Super+Tab has switched keyboards to Dvorak and the user pastes an item from the launcher's clipboard history into an app
- **THEN** the item is inserted into the app
