# HUNTER'S LOG

**A drop tracker and hunting journal for PSO Ephinea.**

Hunter's Log tracks rare drops and keeps a detailed record of your hunts, kills, games and statistics.

- **Author:** Akhyrion
- **Version:** 1.0
- **Languages:** French, English and Japanese. Switch languages with the **Français / English / 日本語** buttons; your choice is saved.

## Features

- **Drop counters:** counts rare items and Photon Drops, per item and in total. Tekking a weapon does not count it twice.
- **Drop history:** date, item, weapon stats (`[X/X/X/X|X]`), difficulty, area, section ID, monster, kills before the drop and more. Includes search, sorting, favorites and pagination.
- **Drops by section ID:** groups drops by section ID, with search.
- **Bestiary:** kills and drops per monster and area, with search.
- **Game history:** records recent games, including the quest played, section ID and drops obtained during the quest.
- **Career statistics:** lifetime records such as best hit percentages, most-killed monsters, most-played quests, and kills by difficulty and section ID.
- **Kill counter window:** displays kills in the current area and session kills.
- **Drop notifications:** on-screen notifications for drops, with icons, colors and configurable text outline.
- **Very rare filter:** customizable filter, plus support for counting common weapons only when they meet a minimum hit percentage.
- **Export and backups:** export statistics to a text file and automatically back up addon data.
- **Appearance and controls:** themes, adjustable opacity and an assignable hotkey to open or close the addon.

## Requirements

## Requirements

To use Hunter's Log you need three things:

1. **The addon plugin for PSOBB** (the system that lets the game load addons).
   Download it from [Solybum/psobbaddonplugin](https://github.com/Solybum/psobbaddonplugin) (see its [Releases](https://github.com/Solybum/psobbaddonplugin/releases) page) and follow the installation instructions in that repository. If your PSO Ephinea installation already has the addon system working (for example, if other addons already appear in your addon list), you can skip this step.

2. **Microsoft Visual C++ Redistributable for Visual Studio 2015**, required by the addon plugin.
   Download: [Visual C++ Redistributable for Visual Studio 2015](https://www.microsoft.com/en-us/download/details.aspx?id=48145).

3. **The `solylib` library**, required by Hunter's Log.
   Download it from [Solybum/PSOBBMod-Addons](https://github.com/Solybum/PSOBBMod-Addons) (**Code → Download ZIP**), then copy the **`solylib`** folder into your game's `addons` folder.
   If you already use addons such as Item Reader, you most likely already have `solylib`.

## Installation

1. Open the [Releases](../../releases) page and download the latest Hunter's Log release.
2. Extract the downloaded archive.
3. Copy the **`Hunters Log`** folder into your game's `addons` folder. The resulting path should look like this:

   ```text
   ...\addons\Hunters Log\
   ```

   Keep the folder name exactly as **`Hunters Log`**.
4. Start the game and enable **Hunter's Log** in the addon list.
5. Open the addon using the **Hunter's Log** button in the main menu, or use your configured hotkey.

## Repository structure

The GitHub repository is organized like this. The README is at the repository root; the `Hunters Log/` folder is the addon folder players install.

```text
Hunter's Log/
├── README.md             Project presentation (GitHub)
└── Hunters Log/           Addon folder to install
    ├── init.lua           Main addon file
    ├── charts/            Drop rates, enemy and quest data
    ├── data/              Static data and translations
    ├── modules/           Addon modules
    └── LICENSE.txt        MIT license for the addon code
```

The downloadable release should contain the **`Hunters Log/`** addon folder, so players can copy it directly into their game's `addons` directory. The GitHub `README.md` is documentation for the repository and does not need to be placed inside the game's addon folder.

## Your data and updates

Hunter's Log creates its data files and folders automatically when needed. You do not need to create them manually.

Examples of files and folders created by the addon:

- `data.lua` — counters, history and settings.
- `career.lua` — career records and statistics.
- `game_history/` — game history.
- `save/` — automatic backups and backups made before a reset.
- `exports/` — text exports, such as `item_stats_export.txt`.

**When updating:** keep your personal data. Replace the addon's program files and bundled data (`init.lua`, `charts/`, `data/` and `modules/`) with the files from the new release, but do not overwrite or delete your generated data files and folders. If in doubt, make a copy of your entire `Hunters Log` folder before updating.

## Troubleshooting and bug reports

If the addon does not load or something does not work as expected:

1. Check that the folder is named exactly `Hunters Log` and is inside the game's `addons` folder.
2. Check that the Ephinea addon system is enabled and that `solylib` is available.
3. Make a backup of your `Hunters Log` folder before trying a reinstall or changing data files.
4. When reporting a bug, include:
   - the Hunter's Log version;
   - what you were doing;
   - what you expected to happen;
   - what happened instead;
   - any relevant error message.

Please do not share personal save files or private information in a public bug report. If a save file is needed to investigate an issue, contact the author first.

## Credits and data

- Drop rates and enemy data are based on the Ephinea drop chart.
- Hunter's Log is built on `solylib` for the Ephinea addon system.

## License and disclaimer

The addon code is licensed under the **MIT License**; see [`LICENSE`](LICENSE). The license applies to the addon code only.

The drop chart data in the `charts/` folder comes from Ephinea and is not covered by the addon code license. Please refer to Ephinea's terms and policies regarding the use and redistribution of that data.

Hunter's Log is a fan project and is not affiliated with, endorsed by, or sponsored by SEGA or Ephinea.


## Screenshots

### Total Drops

Every rare item and Photon Drop you have found, with quantity, last drop date, and your best tekked and untekked hit percentages. Filter by item type (weapons, armor, units, event/PD, very rare, common weapons) and search by name.

![Hunter's Log - Total Drops](Screenshots/total-drop.png)

### Drop History

A full log of every drop: date, item, weapon stats, difficulty, area, section ID, monster, kills before the drop, drop rate and the DAR / RDR / RER bonuses active at that moment. Star your favorites, filter by item or section ID, and use the color-coded stats scale to spot good rolls quickly.

![Hunter's Log - Drop History](Screenshots/drop-history.png)

### Drops by Section ID

See at a glance what you found with each section ID. Hover an item to get the details of the last 10 drop (date, area, monster, stats, kills). Filter by difficulty and item type.

![Hunter's Log - Drops by Section ID](Screenshots/drop-per-id.png)

### Bestiary

Kills and drops per monster, grouped by area. Each line shows the item, total kills, kills without a drop, the drop rate and how your kill count compares to the expected rate. Filter by section ID, episode, difficulty and area.

![Hunter's Log - Bestiary](Screenshots/bestiary.png)

### Game History

Your recent games, with the quest played, room section ID, difficulty, duration and the drops obtained during the quest. Rare monsters seen are shown, and each game can be expanded to list its drops. Favorite or delete entries as needed.

![Hunter's Log - Game History](Screenshots/history_games.png)

### Career Statistics

Your lifetime records: rare items found, best hits, most-killed monsters, rare monsters and bosses, and your most-played quests. Hover a quest or record for extra details.

![Hunter's Log - Career](Screenshots/Career.png)

### Kill Counter Window

A compact in-game window showing, for the current area, section ID and difficulty: total kills (with session kills in green), kills without a drop, and drops per monster.

![Hunter's Log - Kill Counter](Screenshots/killcounter.png)

### Drop Notifications

An on-screen pop-up appears when you find a rare weapon, showing its name, stats and actual drop rate. Size, opacity, theme, position and text outline are configurable.

![Hunter's Log - Drop pop-up](Screenshots/Pop-up.png)

### Rare Monster Alerts

A separate pop-up warns you when a rare monster appears, with its name and the area it was spotted in.

![Hunter's Log - Rare monster pop-up](Screenshots/Pop-up2.png)
