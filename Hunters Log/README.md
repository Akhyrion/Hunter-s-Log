# HUNTER'S LOG

A drop tracker and hunting journal for PSO Ephinea.

**Author:** Akhyrion  
**Version:** 1.0  
**Languages:** French, English and Japanese.

## FEATURES

- Rare item and Photon Drop counters.
- Detailed drop history with weapon stats and drop information.
- Drops grouped by Section ID.
- Bestiary with monster kills and drops.
- Game history with quests and drops.
- Career records and lifetime statistics.
- Current zone kill counter.
- Customizable drop notifications.
- Customizable very rare item filter and minimum hit filter.
- Text export and automatic backups.
- Customizable themes, opacity and hotkey.

## INSTALLATION

1. Copy the `Hunters Log` folder into your game's `addons` folder:

   `...\addons\Hunters Log\`

2. Make sure the folder is named exactly `Hunters Log`.
3. Start PSO Ephinea and enable Hunter's Log in the addon list.
4. Open the addon using the Hunter's Log button in the main menu or your configured hotkey.

## REQUIREMENTS

- PSO Ephinea with the addon system enabled.
- `solylib`, included with the standard Ephinea addons.

## DATA AND BACKUPS

Hunter's Log automatically creates its own data files and folders.

These include:

- `data.lua` — Counters, history and settings.
- `career.lua` — Career records and statistics.
- `game_history/` — Game history.
- `save/` — Automatic backups and reset backups.
- `exports/` — Text exports.

**IMPORTANT: UPDATING**

To update Hunter's Log, replace only the following files and folders:

- `init.lua`
- `charts/`
- `data/`
- `modules/`

Keep your personal data files and folders untouched to preserve your history, statistics and settings.

Always make a backup of your `Hunters Log` folder before updating.

## CREDITS

- Drop rates and enemy data are based on the Ephinea drop chart.
- Built on `solylib` for the Ephinea addon system.

## LICENSE

The addon code is licensed under the MIT License. See `LICENSE.txt`.

The drop chart data in the `charts/` folder comes from Ephinea and is not covered by the addon code license.

Hunter's Log is a fan project and is not affiliated with SEGA or Ephinea.
