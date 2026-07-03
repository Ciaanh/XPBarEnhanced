# XP Bar Enhanced

A World of Warcraft addon that replaces and enhances the default experience bar with richer visuals, quest XP overlays, session statistics, and full color customization.

**Retail only** · Interface 120007 · Version 1.1.7

## Features

- **Multiple Bar Styles** — None (Blizzard default), Classic, Flat, Vertical, Circular, Minimap Ring, and Terminal
- **Quest XP Overlay** — See pending and completed quest XP directly on the bar
- **Session Tracking** — Track XP gained, time played, levels gained, and XP/hour rate
- **Session Breakdown & Rate Smoothing** — Session stats include quest XP vs other XP totals, with a rolling recent XP/hour rate for faster responsiveness
- **Statistics Window** — Detailed breakdown of your leveling progress
- **Profile System** — Create, rename, delete, and switch between named settings profiles; Blizzard-style dropdown with inline actions and a global shared profile option
- **Bar Size Presets** — Scale the Flat and Vertical bars to Small, Default, Large, or Huge without distorting text or overlays
- **Reputation, Companion, and Housing Tracking** — The secondary bar can track watched faction progress (including Delve companion flavor) or Housing Favor progress for the tracked house
- **Secondary Source Selector** — Choose `Reputation` or `Housing Favor` as the secondary bar source
- **Style-Aware Secondary Bars** — Secondary progress display adapts to the active style (Classic label ticker, Vertical side bar, Circular inner arc, Minimap arc toggle, Terminal single-line phosphor bar)
- **Color Customization** — Full control over bar and overlay colors
- **Minimap Button** — Quick access to options and stats
- **Animations** — Smooth fill, flash-on-gain, and two-phase level-up animations

## Bar Styles

| Style | Description |
| --- | --- |
| **None** | Blizzard's default XP bar only |
| **Classic** | Blizzard-style bar with atlas textures and quest overlays |
| **Flat** | Wide draggable bar with milestone ticks |
| **Vertical** | Vertical bar with animated XP fill |
| **Circular** | Progress ring with configurable size, segments, and scalable center text |
| **Minimap Ring** | XP ring anchored around the minimap with optional button collection |
| **Terminal** | ASCII-style retro bar with phosphor-green progress display |

## Installation

1. Download and extract to your `Interface/AddOns` folder
2. Ensure the folder is named `XPBarEnhanced`
3. Start or reload World of Warcraft

## Slash Commands

| Command | Description |
| --- | --- |
| `/xpbe` | Show command help |
| `/xpbe options` | Open the options panel |
| `/xpbe stats` | Toggle the statistics window |
| `/xpbe changelog` | Show the update changelog |
| `/xpbe style <none\|classic\|flat\|vertical\|circular\|minimap_ring\|terminal>` | Set the active bar style |
| `/xpbe profile` | Show current profile and list available profiles |
| `/xpbe profile global` | Switch to the global shared profile |
| `/xpbe profile use <name>` | Switch to a named profile |
| `/xpbe profile new <name>` | Create and select a new profile |
| `/xpbe profile rename <name>` | Rename the active profile |
| `/xpbe profile delete [name]` | Delete a profile |
| `/xpbe reps` | Export all faction IDs |
| `/xpbe debugevents [on\|off\|show\|reset]` | Toggle and inspect EventBus emit counters |
| `/xpbe reset` | Reset all settings |
| `/xpbe resetstats` | Reset session statistics |
| `/xpbe resetcolors` | Reset colors to defaults |
| `/xpbe help` | Show available commands |

Additional slash aliases: `/xpbarenhanced`, `/xpbar`

## Configuration

Access options via `/xpbe options` or the minimap button. Settings include:

- **Bar Style** — Choose between all available styles
- **Colors** — Customize XP bar, rested XP, quest XP overlays
- **Display** — Toggle text rows, quest overlays, animations, and minimap button
- **Profiles** — Manage named settings profiles; switch per character or use a shared global profile
- **Secondary Progress Bar** — Enable the secondary bar and choose source mode (`Reputation` or `Housing Favor`); optionally attach it above the XP bar or position it freely; hide the Delve companion bar when outside a Delve
- **Session Behavior** — Optional reset of session tracking on `/reload`
- **Circular Bar** — Ring size (Small/Medium/Large/Huge), segment count, texture style, optional center text scaling, and optional full-circle secondary arc
- **Minimap Ring** — Ring padding, segment count, segment dimensions, optional minimap button collection, and optional "start minimap arc expanded" behavior for the reputation arc
- **Terminal** — Toggle between authentic terminal colors and custom color scheme

## Requirements

- World of Warcraft Retail
- No external dependencies

## Development Notes

- Event ownership guidance: see docs/event-ownership.md
- Manual release validation: see docs/qa-checklist.md

## Credits

This addon was inspired by the WeakAura from Luxthos [https://wago.io/LuxthosExperienceBar] for the flat bar design.

## License

MIT License — See [LICENSE](LICENSE) for details.
