## Purpose

Defines keyboard layouts so the hardware-Dvorak Kyria keyboard works unchanged while other keyboards default to US with switchable Dvorak.

## ADDED Requirements

### Requirement: US default with switchable Dvorak
Keyboards SHALL default to the US layout, and Super+Tab SHALL toggle between US and US Dvorak. The compose key SHALL be the Menu key.

#### Scenario: Toggle layout on a regular keyboard
- **WHEN** the user types on a regular keyboard and presses Super+Tab
- **THEN** subsequent input uses US Dvorak, and pressing Super+Tab again returns to US

### Requirement: Kyria stays on plain US
The splitkb Kyria rev3 SHALL always use the plain US layout, because it produces Dvorak in hardware, regardless of layout toggles.

#### Scenario: Kyria unaffected by toggle
- **WHEN** Super+Tab has switched other keyboards to Dvorak
- **THEN** typing on the Kyria still produces the characters its firmware sends under US
