HUNTER'S LOG
============

An addon for PSO Ephinea that tracks your rare drops and keeps a detailed
history of everything you find.

Author: Akhyrion
Version: 1.0
Languages: French, English, Japanese (switch with the FR / EN / JP buttons,
your choice is saved).


FEATURES
--------
- Drop counters: counts rare items and PDs, per item and in total.
  Tekking a weapon does not count it twice.
- History: date, item, stats (shown as [X/X/X/X|X]), difficulty, zone,
  section ID, monster, kills before the drop, and more.
  Search, sort, favorites, paging.
- Drop by ID: drops grouped by section ID, with search.
- Bestiary: kills and drops per monster, by zone, with search.
- Game history: the last games with the quest played, section ID and the
  drops obtained during the quest.
- Career: lifetime records and statistics (best hits, most killed monsters,
  most played quests, kills per difficulty and section ID).
- Kill counter window: kills of the current zone, with session kills.
- Drop pop-up: on-screen notification for each drop, with icons, colors and
  a configurable text outline.
- Very rare filter (customizable) and common weapons counted only above a
  minimum hit %.
- Export to a text file, automatic backup of your data, themes and
  adjustable opacity.
- Assignable hotkey to open / close the addon (button next to FR / EN / JP).


REQUIREMENTS
------------
- PSO Ephinea with the addon system enabled.
- The solylib library (included with the standard Ephinea addons).


INSTALLATION
------------
1. Copy the "Hunters Log" folder into the "addons" folder of your game:
   ...\addons\Hunters Log\
   (the folder must be named exactly "Hunters Log").
2. Start the game and open the addon list, then enable "Hunter's Log".
3. Open the addon with the "Hunter's Log" button of the main menu
   (or with your hotkey).

Folder content:

   Hunters Log/
     init.lua      main file
     charts/       drop rates, enemies and quests data
     data/         static data and translations
     modules/      addon modules


FILES CREATED BY THE ADDON
--------------------------
Created automatically in the addon folder, nothing to add by hand:

- data.lua        your counters, history and settings.
- career.lua      your career records and statistics.
- game_history/   history of your games.
- save/           automatic backup (auto_save.lua) and backups made before
                  a reset.
- exports/        text export (item_stats_export.txt).

To keep your data when updating, only replace init.lua, charts/, data/ and
modules/, and leave the files above untouched.


CREDITS
-------
- Drop rates and enemy data come from the Ephinea drop chart.
- Built on solylib for the Ephinea addon system.

License: MIT (see LICENSE.txt). The license covers the addon code only.
The drop chart data in the charts/ folder comes from Ephinea.

This addon is a fan project and is not affiliated with SEGA or Ephinea.
