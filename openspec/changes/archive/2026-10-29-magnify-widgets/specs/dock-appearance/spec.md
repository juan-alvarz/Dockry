# Spec Delta

## MODIFIED Requirements

### Requirement: Magnification
With magnification on, app icons, folders and widgets near the pointer SHALL grow smoothly, the one under it by the magnified size's factor, while the spot under the pointer stays put and the dock's own frame doesn't move. An item longer than an icon SHALL grow fully wherever the pointer is along it. Magnification SHALL ease in and out, and SHALL pause while something is being dragged.

#### Scenario: Pointer over an icon
- **WHEN** magnification is on with 48-point icons and an 80-point magnified size
- **THEN** the icon under the pointer is drawn at 80 points and its neighbors smaller

#### Scenario: Pointer over a widget
- **WHEN** magnification is on with 48-point icons and an 80-point magnified size, and the pointer is over the weather widget
- **THEN** the widget is drawn 80/48 times its normal size and still opens the Weather app when clicked

#### Scenario: Pointer near the end of a wide widget
- **WHEN** the pointer is over the right end of the Spotify widget
- **THEN** the Spotify widget is fully magnified
