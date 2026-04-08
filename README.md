# XP Bar Enhanced

A World of Warcraft addon that replaces and enhances the default experience bar with richer visuals, quest XP overlays, session statistics, and full color customization.

**Retail only** · Interface 120001 · Version 1.0.7

## Features

- **Multiple Bar Styles** — None (Blizzard default), Classic, Flat, Vertical, Circular, Minimap Ring, and Terminal
- **Quest XP Overlay** — See pending and completed quest XP directly on the bar
- **Session Tracking** — Track XP gained, time played, levels gained, and XP/hour rate
- **Statistics Window** — Detailed breakdown of your leveling progress
- **Reputation & Companion Tracking** — A secondary bar tracks your watched faction; shows companion-specific flavor (level, session gains) when tracking a Delve companion such as Brann
- **Color Customization** — Full control over bar and overlay colors
- **Minimap Button** — Quick access to options and stats
- **Edit Mode Support** — Bars become draggable when Edit Mode is active
- **Animations** — Smooth fill, flash-on-gain, and two-phase level-up animations

## Bar Styles

| Style | Description |
|-------|-------------|
| **None** | Blizzard's default XP bar only |
| **Classic** | Blizzard-style bar with atlas textures and quest overlays |
| **Flat** | Full-width draggable bar with milestone ticks |
| **Vertical** | Vertical bar with falling XP animation |
| **Circular** | Progress ring with configurable size, segments, and scalable center text |
| **Minimap Ring** | XP ring anchored around the minimap with optional button collection |
| **Terminal** | ASCII-style retro bar with phosphor-green progress display |

## Installation

1. Download and extract to your `Interface/AddOns` folder
2. Ensure the folder is named `XPBarEnhanced`
3. Start or reload World of Warcraft

## Slash Commands

| Command | Description |
|---------|-------------|
| `/xpbe` | Show command help |
| `/xpbe options` | Open the options panel |
| `/xpbe stats` | Toggle the statistics window |
| `/xpbe style <none\|classic\|flat\|vertical\|circular\|minimap_ring\|terminal>` | Set the active bar style |
| `/xpbe reps` | Export all faction IDs |
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
- **Reputation / Companion Bar** — Enable the secondary tracked-faction bar; optionally attach it above the XP bar or position it freely; hide the companion bar when outside a Delve
- **Circular Bar** — Ring size (Small/Medium/Large/Huge), segment count, texture style, and optional center text scaling
- **Minimap Ring** — Ring padding, segment count, segment dimensions, and optional minimap button collection
- **Terminal** — Toggle between authentic terminal colors and custom color scheme

## Requirements

- World of Warcraft Retail
- No external dependencies

## Credits

This addon was inspired by the WeakAura from Luxthos [https://wago.io/LuxthosExperienceBar] for the flat bar design.

## License

MIT License — See [LICENSE](LICENSE) for details.
