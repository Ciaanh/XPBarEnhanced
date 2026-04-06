# Feature: Options and Configuration

User-facing settings, slash commands, and minimap button.

## Settings Panel

Access via `/xpbe options` or minimap button right-click.

### Bar Style

- Style selector dropdown (None, Classic, Flat, Vertical, Circular, Minimap Ring, Terminal)
- Reputation bar style selector (None, Flat)
- Companion bar style selector (None, Flat)

### Display Options

- Text row visibility toggles (top/bottom text)
- Quest XP overlay toggle
- Animation toggle
- Minimap button visibility
- Reset-on-reload toggle (session continuity vs fresh start on `/reload`)

### Color Customization

- XP bar color
- Rested XP color
- Quest XP overlay color
- Per-style color overrides (Terminal phosphor mode)

### Style-Specific Options

- Circular: ring size (Small/Medium/Large/Huge), segment count, texture style, center text scaling
- Minimap Ring: ring padding, segment count, segment dimensions, button collection
- Terminal: authentic colors vs custom scheme

### Secondary Bar Options

- Reset anchor position for reputation/companion bars

## Slash Commands

| Command | Action |
| ------- | ------ |
| `/xpbe` | Show help |
| `/xpbe options` | Open settings |
| `/xpbe stats` | Toggle statistics window |
| `/xpbe style <name>` | Set bar style |
| `/xpbe reset` | Reset all settings |
| `/xpbe resetstats` | Reset session statistics |
| `/xpbe resetcolors` | Reset colors to defaults |

Aliases: `/xpbarenhanced`, `/xpbar`

## Minimap Button

- Left-click: toggle statistics window
- Right-click: open options panel
- Draggable around minimap border

## Architecture

- `core/config/defaults.lua` — Default values for all settings
- `core/config/Config.lua` — Config read/write, migration, side effects
- `core/config/ConfigHelper.lua` — Config access helpers
- `ui/options/Options.lua` — Option change handlers and side-effect dispatch
- `ui/options/OptionsPanel.xml` — Settings panel layout
- `ui/options/OptionMetadata.lua` — Option definitions (type, range, values)
- `ui/MinimapButton.lua` — Minimap button logic
- `core/AddOnCommands.lua` — Slash command registration and dispatch
