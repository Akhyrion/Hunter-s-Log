local core_mainmenu = require("core_mainmenu")
local lib_items = require("solylib.items.items")
local lib_characters = require("solylib.characters")
local imgui = require("imgui")
local dataFileName = "addons/Hunters Log/data.lua"
local addonDir = "addons/Hunters Log/"
local K = {}
K.ADDON_DIR = addonDir

function K.require_data(name)
  local ok, module = pcall(require, "Hunters Log.data." .. name)
  if ok and type(module) == "table" then return module end
  error("Hunter's Log : missing or invalid data file: data/" .. name .. ".lua (" .. tostring(module) .. ")")
end

function K.load_code(name)
  local ok, loader = pcall(require, "Hunters Log.modules." .. name)
  if ok and type(loader) == "function" then return loader(K) end
  error("Hunter's Log : missing or invalid module: modules/" .. name .. ".lua (" .. tostring(loader) .. ")")
end

K.GAME_DATA = K.require_data("game_data")
K.UI_DATA = K.require_data("ui_data")
K.ITEM_DATA = K.require_data("items")
K.PAGE_CFG = { history = 30, counters = 30, games = 15 }
K.PAGE_CHOICES = { 15, 30, 50 }
K.RARE_YELLOW = false
K.KIND_FILTERS = { "weapon", "armor", "unit", "misc", "other", "common", "veryrare" }
K.KIND_HIDDEN = {}

function K.kinds_apply(text)
  K.KIND_HIDDEN = {}
  for kind in string.gmatch(tostring(text or ""), "[^,]+") do
    for _, known in ipairs(K.KIND_FILTERS) do
      if known == kind then K.KIND_HIDDEN[kind] = true end
    end
  end
end

function K.kinds_serialize()
  local hidden = {}
  for _, kind in ipairs(K.KIND_FILTERS) do
    if K.KIND_HIDDEN[kind] then hidden[#hidden + 1] = kind end
  end
  return table.concat(hidden, ",")
end
K.LOWER_NAMES = setmetatable({}, { __index = function(memo, text)
  local lowered = string.lower(text)
  rawset(memo, text, lowered)
  return lowered
end })

K.HCOLS = {
  { id = "fav", w = 30, fixed = true }, { id = "date", w = 90 }, { id = "item", w = 162, fixed = true }, { id = "stats", w = 175 },
  { id = "difficulty", w = 72 }, { id = "zone", w = 152 }, { id = "id", w = 104 },
  { id = "monster", w = 135 }, { id = "kills", w = 122 }, { id = "rate", w = 123 },
  { id = "bonus", w = 165 }, { id = "delete", w = 60 },
}
K.HIDDEN_COLS = {}
K.HCOL_X = {}
K.HFIRST = true

function K.refresh_hcols()
  local x = 0
  K.HCOL_X = {}
  for _, col in ipairs(K.HCOLS) do
    if not K.HIDDEN_COLS[col.id] then
      K.HCOL_X[col.id] = x
      x = x + col.w
    end
  end
end

function K.hcol_apply(text)
  K.HIDDEN_COLS = {}
  for id in string.gmatch(tostring(text or ""), "[^,]+") do
    for _, col in ipairs(K.HCOLS) do
      if col.id == id and not col.fixed then K.HIDDEN_COLS[id] = true end
    end
  end
  K.refresh_hcols()
end

function K.hcol_serialize()
  local hidden = {}
  for _, col in ipairs(K.HCOLS) do
    if K.HIDDEN_COLS[col.id] then hidden[#hidden + 1] = col.id end
  end
  return table.concat(hidden, ",")
end

K.refresh_hcols()
K.CONFIRM_SECONDS = 10
K.STATUS_SECONDS = 8
K.POPUP = { queue = {}, current = nil, preview = false, confirm_until = 0 }
K.POPUP.kind_keys = { "weapon", "armor", "unit", "mag", "misc", "other", "veryrare" }

K.POPUP.defaults = {
  enabled = true,
  scale = 100,
  font = 100,
  locked = false,
  opacity = 95,
  theme = 1,
  pos_x = 50,
  pos_y = 12,
  duration = 6,
  border = 3,
  outline = 1,
  black_outline = false,
  show_stats = true,
  show_rate = true,
  show_icon = true,
  weapon_icon = 0,
  armor_icon = 0,
  shine = true,
  render = 2,
  rare_enabled = true,
  rare_theme = 3,
  rare_duration = 6,
  rare_zone = true,
  kinds = { weapon = true, armor = true, unit = true, mag = true, misc = true, other = true, veryrare = true },
}

K.POPUP.limits = {
  scale = { 50, 200, 10 }, font = { 50, 300, 10 }, opacity = { 10, 100, 5 }, theme = { 1, 9, 1 },
  duration = { 2, 20, 1 }, render = { 1, 2, 1 }, rare_theme = { 1, 9, 1 }, rare_duration = { 2, 20, 1 },
  border = { 0, 8, 1 }, outline = { 0, 6, 1 }, weapon_icon = { 0, 3, 1 }, armor_icon = { 0, 3, 1 },
}

K.POPUP.themes = K.UI_DATA.popup_themes

K.POPUP.preview_entry = {
  name = "Rambling May", kind = "weapon", wclass = "gun", rate = "1/311", section = "Bluefull",
  stats = "[UNTEKKED - A identifier] +5 [0/0/20/0|25]",
}

function K.POPUP.copy_defaults()
  local copy = { kinds = {} }
  for key, value in pairs(K.POPUP.defaults) do
    if key ~= "kinds" then copy[key] = value end
  end
  for _, kind in ipairs(K.POPUP.kind_keys) do copy.kinds[kind] = K.POPUP.defaults.kinds[kind] end
  return copy
end

K.POPUP.cfg = K.POPUP.copy_defaults()

function K.POPUP.apply(tbl)
  local cfg = K.POPUP.copy_defaults()
  if type(tbl) == "table" then
    for key, default in pairs(K.POPUP.defaults) do
      if key == "kinds" then
        if type(tbl.kinds) == "table" then
          for _, kind in ipairs(K.POPUP.kind_keys) do
            if type(tbl.kinds[kind]) == "boolean" then cfg.kinds[kind] = tbl.kinds[kind] end
          end
        end
      elseif type(tbl[key]) == type(default) then
        local value = tbl[key]
        local limit = K.POPUP.limits[key]
        if limit then
          value = math.floor(math.max(limit[1], math.min(limit[2], value)))
        elseif key == "pos_x" or key == "pos_y" then
          value = math.max(0, math.min(100, value))
        end
        cfg[key] = value
      end
    end
  end
  K.POPUP.cfg = cfg
end

function K.POPUP.serialize()
  local cfg = K.POPUP.cfg
  local parts = {}
  for _, key in ipairs({ "enabled", "locked", "scale", "font", "opacity", "theme", "pos_x", "pos_y", "duration", "border", "outline", "black_outline", "show_icon", "weapon_icon", "armor_icon", "show_stats", "show_rate", "shine", "render", "rare_enabled", "rare_theme", "rare_duration", "rare_zone" }) do
    local value = cfg[key]
    if key == "pos_x" or key == "pos_y" then value = string.format("%.3f", value) end
    parts[#parts + 1] = key .. "=" .. tostring(value)
  end
  local kinds = {}
  for _, kind in ipairs(K.POPUP.kind_keys) do
    kinds[#kinds + 1] = kind .. "=" .. tostring(cfg.kinds[kind])
  end
  parts[#parts + 1] = "kinds={" .. table.concat(kinds, ",") .. "}"
  return "{" .. table.concat(parts, ",") .. "}"
end

K.load_code("killcounter")
K.load_code("career")
K.load_code("common_weapons")

local window_open = false
local hide_title_bar = false
local bg_opacity = 100
local bg_theme = 1
K.load_code("streaks")

local current_tab = "counters"
local filter_item = nil
local filter_id = nil
local search_item_text = ""
local search_id_text = ""
local kill_totals = {}
local kill_marks = {}
local kills_dirty = false
K.SEARCH_BOX_WIDTH = 150
local episode = 1
local seen_items = {}
local item_counts = {}
local item_details = {}
local item_kinds = {}
local drop_history = {}
K.HIST_REV = 0
local total_global = 0
local frame_counter = 0
local confirm_reset = false
local confirm_reset_until = 0
local pending_delete_item = nil
local pending_delete_until = 0
local ui_status = { text = nil, expire = 0, is_error = false }
local lang = { code = "fr" }
K.U = { lang = lang, frame = function() return frame_counter end, details = function() return item_details end }
K.U.item_kinds = function() return item_kinds end
K.U.kill_totals = function() return kill_totals end
K.U.drop_history = function() return drop_history end

K.HISTORY_LIMIT = 5000

function K.archive_new()
  return { list = {}, map = {}, best = {}, best_u = {}, best_a = {} }
end

K.ARCHIVE = K.archive_new()

function K.parse_armor_stats(stats)
  stats = tostring(stats or "")
  local dfp, evp = string.match(stats, "DFP:%s*%+(%d+)%s*|%s*EVP:%s*%+(%d+)")
  if not dfp then return nil end
  return tonumber(dfp), tonumber(evp), tonumber(string.match(stats, "%[(%d+)S%]")) or 0
end

function K.consider_best_armor(tbl, name, dfp, evp, slots)
  local current = tbl[name]
  if not current
    or dfp > current.dfp
    or (dfp == current.dfp and evp > current.evp)
    or (dfp == current.dfp and evp == current.evp and slots > current.slots) then
    tbl[name] = { dfp = dfp, evp = evp, slots = slots }
  end
end

function K.archive_best(h)
  local d = h.key and item_details[h.key]
  if not d then return end
  local stats = tostring(d.stats or "")
  local adfp, aevp, aslots = K.parse_armor_stats(stats)
  if adfp then
    K.consider_best_armor(K.ARCHIVE.best_a, tostring(h.name), adfp, aevp, aslots)
    return
  end
  local n, a, m, dd, hit = string.match(stats, "%[(%-?%d+)/(%-?%d+)/(%-?%d+)/(%-?%d+)|(%-?%d+)%]")
  if not n then return end
  local values = { tonumber(n), tonumber(a), tonumber(m), tonumber(dd), tonumber(hit) }
  local grind = tonumber(string.match(stats, "%+(%d+)")) or 0
  local tbl = string.find(stats, "UNTEKKED", 1, true) and K.ARCHIVE.best_u or K.ARCHIVE.best
  local name = tostring(h.name)
  local current = tbl[name]
  local sum = values[1] + values[2] + values[3] + values[4]
  if not current or values[5] > current.values[5] or (values[5] == current.values[5] and sum > current.sum) then
    tbl[name] = { grind = grind, values = values, sum = sum }
  end
end

function K.archive_add(h)
  local monster = h.kills_monster or h.source
  local key = table.concat({ tostring(h.name), tostring(h.section), tostring(h.difficulty), tostring(monster or ""), tostring(h.zone) }, "|")
  local rec = K.ARCHIVE.map[key]
  if not rec then
    rec = { name = tostring(h.name), section = tostring(h.section), difficulty = tostring(h.difficulty),
      monster = monster and tostring(monster) or "", zone = tostring(h.zone), n = 0 }
    K.ARCHIVE.map[key] = rec
    K.ARCHIVE.list[#K.ARCHIVE.list + 1] = rec
  end
  rec.n = rec.n + 1
end

function K.archive_load(list, best_list)
  K.ARCHIVE = K.archive_new()
  if type(best_list) == "table" then
    for _, rec in ipairs(best_list) do
      if type(rec) == "table" and rec.armor and type(rec.name) == "string" and tonumber(rec.dfp) and tonumber(rec.evp) then
        K.consider_best_armor(K.ARCHIVE.best_a, rec.name, tonumber(rec.dfp), tonumber(rec.evp), tonumber(rec.slots) or 0)
      end
      if type(rec) == "table" and type(rec.name) == "string" and tonumber(rec.n) and tonumber(rec.a) and tonumber(rec.m)
        and tonumber(rec.d) and tonumber(rec.h) then
        local values = { tonumber(rec.n), tonumber(rec.a), tonumber(rec.m), tonumber(rec.d), tonumber(rec.h) }
        local tbl = rec.pending and K.ARCHIVE.best_u or K.ARCHIVE.best
        tbl[rec.name] = { grind = tonumber(rec.grind) or 0, values = values, sum = values[1] + values[2] + values[3] + values[4] }
      end
    end
  end
  if type(list) ~= "table" then return end
  for _, rec in ipairs(list) do
    if type(rec) == "table" and type(rec.name) == "string" and tonumber(rec.n) and rec.n > 0 then
      local key = table.concat({ rec.name, tostring(rec.section), tostring(rec.difficulty), tostring(rec.monster or ""), tostring(rec.zone) }, "|")
      if not K.ARCHIVE.map[key] then
        local item = { name = rec.name, section = tostring(rec.section), difficulty = tostring(rec.difficulty),
          monster = tostring(rec.monster or ""), zone = tostring(rec.zone), n = math.floor(rec.n) }
        K.ARCHIVE.map[key] = item
        K.ARCHIVE.list[#K.ARCHIVE.list + 1] = item
      end
    end
  end
end

function K.trim_history()
  local excess = #drop_history - K.HISTORY_LIMIT
  if excess <= 0 then return false end
  local kept, removed, last = {}, 0, #drop_history
  for index, h in ipairs(drop_history) do
    if removed < excess and index < last and not h.fav then
      removed = removed + 1
      K.archive_add(h)
      K.archive_best(h)
      if h.key then item_details[h.key] = nil end
    else
      kept[#kept + 1] = h
    end
  end
  if removed == 0 then return false end
  drop_history = kept
  K.HIST_REV = K.HIST_REV + 1
  return true
end
K.U.episode = function() return episode end
K.HOTKEY = { vk = nil, capturing = false }
local TEXTS = K.require_data("texts")
for key, value in pairs({
  sub_all = { fr = "Tout", en = "All", ja = "すべて" },
  sub_fav = { fr = "Favoris", en = "Favorites", ja = "お気に入り" },
  fav_add = { fr = "Ajouter aux favoris", en = "Add to favorites", ja = "お気に入りに追加" },
  fav_remove = { fr = "Retirer des favoris", en = "Remove from favorites", ja = "お気に入りから削除" },
  fav_none = { fr = "Aucun favori pour l'instant : clique sur l'etoile d'une ligne pour en ajouter.",
    en = "No favorites yet: click the star on a row to add one.", ja = "お気に入りはまだありません。行の星をクリックして追加できます。" },
  fav_none_games = { fr = "Aucune partie en favori : clique sur l'etoile d'une partie pour l'ajouter.",
    en = "No favorite game yet: click the star on a game to add it.", ja = "お気に入りの試合はまだありません。試合の星をクリックして追加できます。" },
  fav_protected = { fr = "Entree en favori : retire l'etoile avant de la supprimer.",
    en = "Favorite entry: remove the star before deleting it.", ja = "お気に入りの項目です。削除する前に星を外してください。" },
  fav_protected_game = { fr = "Partie en favori : retire l'etoile avant de la supprimer.",
    en = "Favorite game: remove the star before deleting it.", ja = "お気に入りの試合です。削除する前に星を外してください。" },
}) do
  if not TEXTS[key] then TEXTS[key] = value end
end

local function T(key, ...)
  local entry = TEXTS[key]
  local text = entry and (entry[lang.code] or entry.fr) or key
  if select("#", ...) > 0 then
    return string.format(text, ...)
  end
  return text
end

local JA_NAMES = K.require_data("ja_names")

local function iname(name)
  name = tostring(name == nil and "" or name)
  if lang.code ~= "ja" then return name end
  local base, suffix = string.match(name, "^(.-)%s*(%(%d+%))$")
  local ja = JA_NAMES.items[string.lower(name)]
  if ja then return ja end
  if base and JA_NAMES.items[string.lower(base)] then
    return JA_NAMES.items[string.lower(base)] .. suffix
  end
  return name
end
K.U.T, K.U.JA_NAMES, K.U.iname = T, JA_NAMES, iname

-- When the game itself runs in Japanese, item names come back in Japanese: convert them to the English names used by every filter and table.
local function en_item_name(name)
  if type(name) ~= "string" or not string.find(name, "[\128-\255]") then return name end
  local en = JA_NAMES.reverse[name]
  if en then return en end
  local base, suffix = string.match(name, "^(.-)%s*(%(%d+%))$")
  if base and JA_NAMES.reverse[base] then return JA_NAMES.reverse[base] .. " " .. suffix end
  return name
end

local function fix_item_names(list)
  for _, item in pairs(list) do
    if type(item) == "table" and item.name then item.name = en_item_name(item.name) end
  end
end

function JA_NAMES.loc(text)
  local function one(p)
    if JA_NAMES.zones[p] then return JA_NAMES.zones[p] end
    local game_name = K.monster_text and K.monster_text(p)
    if game_name then return game_name end
    local mbase, msuffix = string.match(p, "^(.-)( %[%E%d%])$")
    if not mbase then mbase, msuffix = string.match(p, "^(.-)( E%d)$") end
    local n = string.match(p, "^Etage (%d+)$")
    if n then return "フロア" .. n end
    p = string.gsub(p, "Caisse %(", "ボックス (")
    p = string.gsub(p, " %(perso%)", " (自分)")
    return p
  end
  if JA_NAMES.zones[text] then return JA_NAMES.zones[text] end
  return (string.gsub(text, "[^/]+", function(part)
    local lead, core, trail = string.match(part, "^(%s*)(.-)(%s*)$")
    return lead .. one(core) .. trail
  end))
end

local function loc(text)
  text = tostring(text == nil and "" or text)
  if lang.code == "ja" then
    if text == "Lobby" then return "ロビー" end
    return JA_NAMES.loc(text)
  end
  if lang.code ~= "en" then return text end
  if text == "Inconnu" or text == "Inconnue" then return "Unknown" end
  if text == "Zone Inconnue" then return "Unknown area" end
  text = string.gsub(text, "^Etage ", "Floor ")
  text = string.gsub(text, "Caisse %(", "Box (")
  text = string.gsub(text, " %(perso%)", " (own)")
  return text
end

K.DATA_FILTERS = K.ITEM_DATA.filters
local blacklisted_items = K.DATA_FILTERS.blacklisted_items
local blacklisted_patterns = K.DATA_FILTERS.blacklisted_patterns
local no_detail_items = K.DATA_FILTERS.no_detail_items
local floor_names = K.GAME_DATA.floor_names

local ZONES = {
  choice = nil,
  learned = {},
  list = {},
  seed = K.GAME_DATA.zone_monsters,
}

ZONES.extra = {
  ["Hallo Rappy"] = { "Jack-O'-Lantern", 8 / 7 },
  ["St Rappy"] = { "Christmas Present", 8 / 7 },
}

ZONES.extra_by_item = {}

for monster_key, info in pairs(ZONES.extra) do
  ZONES.extra_by_item[string.lower(info[1])] = monster_key
end

ZONES.extra["Halo Rappy"] = ZONES.extra["Hallo Rappy"]
ZONES.extra["St. Rappy"] = ZONES.extra["St Rappy"]
ZONES.groups = K.GAME_DATA.zone_groups

ZONES.all_entries = {}
local bestiary_hidden = K.GAME_DATA.bestiary_hidden_zones or {}

for _, zone_ep in ipairs({ 1, 2, 4 }) do
  for _, group in ipairs(ZONES.groups[zone_ep]) do
    local entry = { ep = zone_ep, zone = group[1], floors = group[2] }
    ZONES.all_entries[#ZONES.all_entries + 1] = entry
    if not (bestiary_hidden[zone_ep] and bestiary_hidden[zone_ep][group[1]]) then
      ZONES.list[#ZONES.list + 1] = entry
    end
  end
end

function ZONES.all_monsters(ep)
  local set = {}
  for _, entry in ipairs(ZONES.list) do
    if entry.ep == ep then
      for key in pairs(ZONES.monsters(entry)) do set[key] = true end
    end
  end
  return set
end

function ZONES.group_of(ep, floor_name)
  for _, entry in ipairs(ZONES.all_entries) do
    if entry.ep == ep then
      for _, name in ipairs(entry.floors) do
        if name == floor_name then return entry.zone end
      end
    end
  end
  return nil
end

function ZONES.learn(ep, floor, key)
  local zone = floor_names[ep] and floor_names[ep][floor]
  if not zone or not key then return end
  local now_clock = os.clock()
  local stamp = tostring(ep) .. "|" .. tostring(floor)
  if ZONES.stamp ~= stamp then
    ZONES.stamp = stamp
    ZONES.stamp_time = now_clock
  end
  if now_clock - (ZONES.stamp_time or 0) < 8 then return end
  if K.quest_zone_seed(ep, ZONES.group_of(ep, zone)) then return end
  if not K.is_random_quest() then
    for _, entry in ipairs(ZONES.all_entries) do
      if entry.ep == ep and ZONES.seed_only(entry) then
        for _, floor_name in ipairs(entry.floors) do
          if floor_name == zone then return end
        end
      end
    end
  end
  local learned_key = tostring(ep) .. "|" .. zone .. "|" .. key
  if not ZONES.learned[learned_key] then
    ZONES.learned[learned_key] = true
    kills_dirty = true
    K.KILLS_VER = (K.KILLS_VER or 0) + 1
  end
end

function ZONES.seed_floors(ep)
  ZONES.seed_cache = ZONES.seed_cache or {}
  if not ZONES.seed_cache[ep] then
    local index = {}
    for floor_name, list in pairs(ZONES.seed[ep] or {}) do
      for key in string.gmatch(list, "[^,]+") do
        index[key] = index[key] or {}
        index[key][floor_name] = true
      end
    end
    ZONES.seed_cache[ep] = index
  end
  return ZONES.seed_cache[ep]
end

function K.quest_key()
  local game = K.GAMELOG and K.GAMELOG.games and K.GAMELOG.games[1]
  local name = game and not game.lost and game.name
  if type(name) ~= "string" then return nil end
  local cache = K.QUEST_KEY_CACHE
  if not cache or cache.name ~= name then
    cache = { name = name, key = (string.gsub(string.lower(name), "[^%w]", "")) }
    K.QUEST_KEY_CACHE = cache
  end
  return cache.key
end

function K.quest_zone_seed(ep, zone)
  local seeds = K.GAME_DATA.quest_zone_seeds
  local list = seeds and seeds[ep] and seeds[ep][zone]
  if not list then return nil end
  local key = K.quest_key()
  if not key then return nil end
  for _, item in ipairs(list) do
    if string.find(key, item.pattern, 1, true) then return item.monsters end
  end
  return nil
end

function K.is_random_quest()
  local game = K.GAMELOG and K.GAMELOG.games and K.GAMELOG.games[1]
  local name = game and not game.lost and game.name
  if type(name) ~= "string" then return false end
  local cache = K.RANDOM_QUEST_CACHE
  if not cache or cache.name ~= name then
    local normalized = string.gsub(string.lower(name), "[^%w]", "")
    local found = false
    for _, pattern in ipairs(K.GAME_DATA.random_quests or {}) do
      if string.find(normalized, pattern, 1, true) then found = true break end
    end
    cache = { name = name, value = found }
    K.RANDOM_QUEST_CACHE = cache
  end
  return cache.value
end

function ZONES.seed_only(entry)
  local zones = K.GAME_DATA.bestiary_seed_only
  return zones and zones[entry.ep] and zones[entry.ep][entry.zone] or false
end

function ZONES.monsters(entry, base_only)
  local set = {}
  local quest_seed = K.quest_zone_seed(entry.ep, entry.zone)
  if quest_seed then
    for key in string.gmatch(quest_seed, "[^,]+") do set[key] = true end
    return set
  end
  local seed_only = base_only and ZONES.seed_only(entry)
  local quest_zone = bestiary_hidden[entry.ep] and bestiary_hidden[entry.ep][entry.zone]
  quest_zone = quest_zone or K.is_random_quest()
  for _, floor_name in ipairs(entry.floors) do
    local seeded = ZONES.seed[entry.ep] and ZONES.seed[entry.ep][floor_name]
    if seeded then
      for key in string.gmatch(seeded, "[^,]+") do set[key] = true end
    end
    local prefix = tostring(entry.ep) .. "|" .. floor_name .. "|"
    for learned_key in pairs(seed_only and {} or ZONES.learned) do
      if string.sub(learned_key, 1, #prefix) == prefix then
        local monster = string.sub(learned_key, #prefix + 1)
        local owners = ZONES.seed_floors(entry.ep)[monster]
        if quest_zone or not owners or owners[floor_name] then
          set[monster] = true
        end
      end
    end
  end
  return set
end

local kind_list = K.GAME_DATA.kind_list
local kind_colors = K.UI_DATA.kind_colors
local kind_order = {}

for index, kind in ipairs(kind_list) do
  kind_order[kind] = index
end

local special_items = K.DATA_FILTERS.special_items

K.load_code("very_rare")

for _, group in ipairs(K.VR.presets.names) do
  for _, name in ipairs(group.list) do
    K.VR.defaults.names[#K.VR.defaults.names + 1] = name
    K.VR.preset_name_keys[K.VR.key(name)] = true
  end
end
for _, rule in ipairs(K.VR.presets.rules) do
  K.VR.defaults.rules[#K.VR.defaults.rules + 1] = { rule[1], rule[2] }
  K.VR.preset_rule_keys[K.VR.key(rule[1])] = true
end

local special_glow = { 0.35, 0.9, 1.0 }

local function hsv_to_rgb(h, s, v)
  local sector = math.floor(h * 6)
  local f = h * 6 - sector
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  sector = sector % 6
  if sector == 0 then return v, t, p end
  if sector == 1 then return q, v, p end
  if sector == 2 then return p, v, t end
  if sector == 3 then return p, q, v end
  if sector == 4 then return t, p, v end
  return v, p, q
end

local function item_category(kind, name)
  if name and (special_items[string.lower(tostring(name))] or K.VR.names[K.VR.key(name)]) then return "veryrare" end
  return kind or "other"
end

function K.rare_text(text, offset)
  if K.RARE_YELLOW then
    imgui.TextColored(1.0, 0.9, 0.2, 1, text)
    return imgui.IsItemHovered()
  end
  return K.warm_rainbow_text(text, offset)
end

function K.warm_rainbow_text(text, offset)
  local now = os.clock()
  local index = 0
  local hovered = false
  offset = offset or 0
  for char in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
    local phase = (now * 0.23 + (index + offset) * 0.09) % 1
    local wave = math.abs(phase * 2 - 1)
    local r, g, b = hsv_to_rgb((0.78 + 0.37 * wave) % 1, 0.85, 1.0)
    if index > 0 then imgui.SameLine(0, 0) end
    imgui.TextColored(r, g, b, 1, char)
    if imgui.IsItemHovered() then hovered = true end
    index = index + 1
  end
  return hovered
end

function K.glow_color(name)
  local now = os.clock()
  local offset = 0
  if name then
    local text = tostring(name)
    for i = 1, math.min(#text, 12) do offset = offset + string.byte(text, i) end
    offset = (offset % 97) / 97
  end
  local pulse = 0.5 + 0.5 * math.sin(now * 3.5)
  local r, g, b = hsv_to_rgb((now * 0.25 + offset) % 1, 0.75 - 0.35 * pulse, 0.90 + 0.10 * pulse)
  special_glow[1], special_glow[2], special_glow[3] = r, g, b
  return special_glow
end

function K.armor_is_perfect(name, dfp, evp)
  local limits = K.ITEM_DATA.armor_stats[string.lower(tostring(name or ""))]
  if limits == nil or limits.dfp == nil or limits.evp == nil then return false end
  if limits.dfp == 0 and limits.evp == 0 then return false end
  return dfp == limits.dfp and evp == limits.evp
end

function K.armor_sort_metric(name, rec)
  local tier = 0
  if K.armor_is_perfect(name, rec.dfp, rec.evp) then
    tier = 2
  else
    local limits = K.ITEM_DATA.armor_stats[string.lower(tostring(name or ""))]
    if limits and limits.dfp and limits.dfp > 0 and rec.dfp == limits.dfp then tier = 1 end
  end
  return tier * 1000000000 + rec.dfp * 1000000 + rec.evp * 1000 + rec.slots
end

local function kind_color(kind, name)
  if (kind == nil or kind == "weapon") and K.COMMON.is_name(name) then
    return K.COMMON.white
  end
  if kind == "veryrare" or (name and (special_items[string.lower(tostring(name))] or K.VR.names[K.VR.key(name)])) then
    return K.glow_color(name)
  end
  return kind_colors[kind] or kind_colors.other
end
K.U.kind_color = kind_color

local section_list = K.GAME_DATA.section_list

local section_colors = K.UI_DATA.section_colors

local function section_key(label)
  label = tostring(label or "")
  for _, name in ipairs(section_list) do
    if string.find(label, name, 1, true) then return name end
  end
  return nil
end

local function section_color(label)
  local c = section_colors[section_key(label)] or { 0.85, 0.85, 0.85 }
  return c[1], c[2], c[3]
end

local function classify_item(item, name)
  if item then
    if item.weapon then return "weapon" end
    if item.unit then return "unit" end
    if item.mag then return "mag" end
    if item.armor then return "armor" end
  end
  if no_detail_items[string.lower(name or "")] then return "misc" end
  return "other"
end

local function guess_kind(stats, name)
  stats = stats or ""
  if name == "Special Weapon (Untekted)"
    or string.find(stats, "UNTEKKED", 1, true)
    or string.find(stats, "%[%d+/%d+/%d+/%d+|%d+%]") then
    return "weapon"
  end
  if string.find(stats, "DFP", 1, true) or string.find(stats, "%[%dS%]") then
    return "armor"
  end
  if no_detail_items[string.lower(name or "")] then return "misc" end
  return "other"
end

local function fmt_date(t)
  if type(t) ~= "number" or t <= 0 then return "?" end
  local ok, text = pcall(os.date, "%d/%m/%Y %H:%M:%S", t)
  return ok and text or "?"
end

local function fmt_short(t)
  if type(t) ~= "number" or t <= 0 then return "?" end
  local ok, text = pcall(os.date, "%d/%m %H:%M", t)
  return ok and text or "?"
end

K.UNTEKKED_PREFIX = "[UNTEKKED - \195\128 identifier] "

local function load_data()
  local result = {
    total_global = 0, item_counts = {}, item_details = {}, item_kinds = {}, drop_history = {},
    hide_title_bar = false, episode = 1, bg_opacity = 100, bg_theme = 1, hotkey_vk = nil,
    kill_totals = {}, kill_marks = {}, zone_seen = {}, language = "fr",
    page_history = 30, page_counters = 30, page_games = 15, hist_hidden = "", hist_kinds_hidden = "", rare_yellow = false,
  }
  local file = io.open(dataFileName, "r")
  if file then
    local content = file:read("*all")
    file:close()
    local chunk = loadstring(content)
    if chunk then
      local success, data = pcall(chunk)
      if success and type(data) == "table" then
        result.total_global = data.total_global or 0
        result.item_counts = data.item_counts or {}
        result.item_details = data.item_details or {}
        result.item_kinds = data.item_kinds or {}
        result.hide_title_bar = data.hide_title_bar or false
        result.popup = type(data.popup) == "table" and data.popup or nil
        result.common = type(data.common) == "table" and data.common or nil
        result.kc = type(data.kc) == "table" and data.kc or nil
        result.vr = type(data.vr) == "table" and data.vr or nil
        result.pos_near = tonumber(data.pos_near)
        result.episode = data.episode or 1
        result.bg_opacity = math.max(0, math.min(100, tonumber(data.bg_opacity) or 100))
        result.bg_theme = math.max(1, math.min(7, math.floor(tonumber(data.bg_theme) or 1)))
        result.hotkey_vk = tonumber(data.hotkey_vk) and math.max(1, math.min(254, math.floor(tonumber(data.hotkey_vk)))) or nil
        result.hist_hidden = type(data.hist_hidden) == "string" and data.hist_hidden or ""
        result.hist_kinds_hidden = type(data.hist_kinds_hidden) == "string" and data.hist_kinds_hidden or ""
        result.rare_yellow = data.rare_yellow == true
        for field, default in pairs({ page_history = 30, page_counters = 30, page_games = 15 }) do
          local value = tonumber(data[field])
          result[field] = (value == 15 or value == 30 or value == 50) and value or default
        end
        if data.language == "fr" or data.language == "en" or data.language == "ja" then
          result.language = data.language
        end
        if type(data.kill_totals) == "table" then
          result.kill_totals = data.kill_totals
        end
        if type(data.kill_marks) == "table" then
          result.kill_marks = data.kill_marks
        end
        if type(data.zone_seen) == "table" then
          result.zone_seen = data.zone_seen
        end
        if type(data.archive) == "table" then
          result.archive = data.archive
        end
        if type(data.archive_best) == "table" then
          result.archive_best = data.archive_best
        end
        if type(data.drop_history) == "table" then
          for _, entry in ipairs(data.drop_history) do
            if type(entry) == "table" then
              table.insert(result.drop_history, entry)
            end
          end
        end
        if data.fmt == 2 and type(data.S) == "table" and type(data.H) == "table" then
          local S = data.S
          local function str(v)
            if type(v) == "number" then return S[v] end
            return v
          end
          for _, e in ipairs(data.H) do
            if type(e) == "table" then
              local time = e[1] or 0
              local h = {
                time = time, name = str(e[2]) or "Item", kind = str(e[3]) or "other",
                zone = str(e[4]) or "Inconnue", difficulty = str(e[5]) or "Inconnue",
                section = str(e[6]) or "Inconnu", source = str(e[7]) or "Inconnu",
                rate = str(e[8]) or "",
              }
              if e[9] then h.drr = e[9] end
              if e[10] then h.dar = e[10] end
              if e[11] then h.rer = e[11] end
              if e[12] then h.rare = true end
              local fav_code = tonumber(e[18]) or 0
              if fav_code % 2 == 1 then h.fav = true end
              if fav_code >= 2 then h.vrdone = true end
              if e[13] then
                h.kills = e[13]
                h.kills_monster = str(e[14])
                h.kills_expected = e[15]
              end
              local key = e[16]
              if type(key) == "number" then
                key = "floor_" .. string.format("%d", key) .. "_" .. string.format("%d", time)
              end
              if key then
                h.key = key
                if e[17] then
                  local stats = str(e[17]) or "N/A"
                  if string.sub(stats, 1, 1) == "~" then
                    stats = K.UNTEKKED_PREFIX .. string.sub(stats, 2)
                  end
                  result.item_details[key] = {
                    name = h.name, stats = stats, zone = h.zone, source = h.source,
                    difficulty = h.difficulty, section = h.section,
                    item_id = string.match(key, "^floor_(%d+)_") or "", time = time,
                  }
                end
              end
              table.insert(result.drop_history, h)
            end
          end
          if type(data.X) == "table" then
            for key, d in pairs(data.X) do
              if type(d) == "table" then result.item_details[key] = d end
            end
          end
        end
      end
    end
  end
  return result
end

local function save_data(kills_only)
  local file = io.open(dataFileName, "w")
  if file then
    local SAVE = K.SAVE_STATE
    if not SAVE then
      SAVE = { gen = 1, strings = {}, quoted = {}, index = {} }
      K.SAVE_STATE = SAVE
    end
    local function intern(text)
      text = tostring(text or "")
      local n = SAVE.index[text]
      if not n then
        n = #SAVE.strings + 1
        SAVE.strings[n] = text
        SAVE.quoted[n] = string.format("%q", text)
        SAVE.index[text] = n
      end
      return n
    end
    local lines, used_keys
    if kills_only and SAVE.lines and SAVE.hist == drop_history and SAVE.count == #drop_history
      and SAVE.rev == K.HIST_REV and os.time() - SAVE.time < 60 then
      lines, used_keys = SAVE.lines, SAVE.used_keys
    else
      if #SAVE.strings > 2 * #drop_history + 5000 then
        SAVE.gen = SAVE.gen + 1
        SAVE.strings, SAVE.quoted, SAVE.index = {}, {}, {}
      end
      lines = {}
      used_keys = {}
      for _, h in ipairs(drop_history) do
        local details = h.key and item_details[h.key] or nil
        local raw_stats = details and details.stats or nil
        local c = h._s
        if c and c[2] == SAVE.gen and c[3] == h.name and c[4] == h.kills and c[5] == h.kills_monster
          and c[6] == h.kills_expected and c[7] == raw_stats and c[8] == h.kind and c[9] == ((h.fav and 1 or 0) + (h.vrdone and 2 or 0)) then
          lines[#lines + 1] = c[1]
        else
          local time = math.floor(tonumber(h.time) or 0)
          local f = {}
          f[1] = string.format("%d", time)
          f[2] = tostring(intern(h.name or "Item"))
          f[3] = tostring(intern(h.kind or "other"))
          f[4] = tostring(intern(h.zone or "Inconnue"))
          f[5] = tostring(intern(h.difficulty or "Inconnue"))
          f[6] = tostring(intern(h.section or "Inconnu"))
          f[7] = tostring(intern(h.source or "Inconnu"))
          f[8] = tostring(intern(h.rate or ""))
          f[9] = tonumber(h.drr) and string.format("%d", math.floor(tonumber(h.drr) + 0.5)) or "nil"
          f[10] = tonumber(h.dar) and string.format("%d", math.floor(tonumber(h.dar) + 0.5)) or "nil"
          f[11] = tonumber(h.rer) and string.format("%d", math.floor(tonumber(h.rer) + 0.5)) or "nil"
          f[12] = h.rare and "1" or "nil"
          if tonumber(h.kills) then
            f[13] = string.format("%d", math.floor(tonumber(h.kills)))
            f[14] = h.kills_monster and tostring(intern(h.kills_monster)) or "nil"
            f[15] = tonumber(h.kills_expected) and string.format("%.2f", tonumber(h.kills_expected)) or "nil"
          else
            f[13], f[14], f[15] = "nil", "nil", "nil"
          end
          f[16], f[17] = "nil", "nil"
          if h.key then
            local id, key_time = string.match(tostring(h.key), "^floor_(%d+)_(%d+)$")
            if id and tonumber(key_time) == time then
              f[16] = id
            else
              f[16] = string.format("%q", tostring(h.key))
            end
            if details then
              local stats = tostring(details.stats or "N/A")
              if string.sub(stats, 1, #K.UNTEKKED_PREFIX) == K.UNTEKKED_PREFIX then
                stats = "~" .. string.sub(stats, #K.UNTEKKED_PREFIX + 1)
              end
              f[17] = tostring(intern(stats))
            end
          end
          local fav_code = (h.fav and 1 or 0) + (h.vrdone and 2 or 0)
          f[18] = fav_code > 0 and tostring(fav_code) or "nil"
          local last = 18
          while last > 8 and f[last] == "nil" do last = last - 1 end
          local line = "{" .. table.concat(f, ",", 1, last) .. "},"
          h._s = { line, SAVE.gen, h.name, h.kills, h.kills_monster, h.kills_expected, raw_stats, h.kind, fav_code }
          lines[#lines + 1] = line
        end
        if details then used_keys[h.key] = true end
      end
      SAVE.lines, SAVE.used_keys, SAVE.hist, SAVE.count, SAVE.rev, SAVE.time =
        lines, used_keys, drop_history, #drop_history, K.HIST_REV, os.time()
    end
    file:write("return {\n")
    file:write("fmt=2,\n")
    file:write(string.format("total_global=%d,\n", total_global))
    file:write(string.format("hide_title_bar=%s,\n", tostring(hide_title_bar)))
    file:write("popup=" .. K.POPUP.serialize() .. ",\n")
    file:write("kc=" .. K.KC.serialize() .. ",\n")
    file:write("common=" .. K.COMMON.serialize() .. ",\n")
    file:write("vr=" .. K.VR.serialize() .. ",\n")
    file:write("pos_near=" .. tostring(math.min(K.POS_NEAR or 0, K.POS_CALIBRATION or 2)) .. ",\n")
    file:write(string.format("episode=%d,\n", episode))
    file:write(string.format("bg_opacity=%d,\n", bg_opacity))
    file:write(string.format("bg_theme=%d,\n", bg_theme))
    file:write(string.format("language=%q,\n", lang.code))
    file:write(string.format("page_history=%d,\npage_counters=%d,\npage_games=%d,\n", K.PAGE_CFG.history, K.PAGE_CFG.counters, K.PAGE_CFG.games))
    file:write(string.format("hist_hidden=%q,\nhist_kinds_hidden=%q,\nrare_yellow=%s,\n", K.hcol_serialize(), K.kinds_serialize(), tostring(K.RARE_YELLOW)))
    if K.HOTKEY.vk then file:write(string.format("hotkey_vk=%d,\n", K.HOTKEY.vk)) end
    file:write("item_counts={\n")
    for name, count in pairs(item_counts) do
      file:write(string.format("[%q]=%d,\n", tostring(name), count))
    end
    file:write("},\nitem_kinds={\n")
    for name, kind in pairs(item_kinds) do
      file:write(string.format("[%q]=%q,\n", tostring(name), tostring(kind)))
    end
    file:write("},\nkill_totals={\n")
    for key, value in pairs(kill_totals) do
      file:write(string.format("[%q]=%d,\n", tostring(key), math.floor(tonumber(value) or 0)))
    end
    file:write("},\nkill_marks={\n")
    for key, value in pairs(kill_marks) do
      file:write(string.format("[%q]=%d,\n", tostring(key), math.floor(tonumber(value) or 0)))
    end
    file:write("},\nzone_seen={\n")
    for key in pairs(ZONES.learned) do
      file:write(string.format("[%q]=true,\n", tostring(key)))
    end
    file:write("},\narchive={\n")
    for _, rec in ipairs(K.ARCHIVE.list) do
      file:write(string.format("{ name = %q, section = %q, difficulty = %q, monster = %q, zone = %q, n = %d },\n",
        rec.name, rec.section, rec.difficulty, rec.monster, rec.zone, rec.n))
    end
    file:write("},\narchive_best={\n")
    for pending, tbl in pairs({ [false] = K.ARCHIVE.best, [true] = K.ARCHIVE.best_u }) do
      for name, rec in pairs(tbl) do
        file:write(string.format("{ name = %q, pending = %s, grind = %d, n = %d, a = %d, m = %d, d = %d, h = %d },\n",
          name, tostring(pending), rec.grind, rec.values[1], rec.values[2], rec.values[3], rec.values[4], rec.values[5]))
      end
    end
    for name, rec in pairs(K.ARCHIVE.best_a) do
      file:write(string.format("{ name = %q, armor = true, dfp = %d, evp = %d, slots = %d },\n", name, rec.dfp, rec.evp, rec.slots))
    end
    file:write("},\n")
    file:write("X={\n")
    for id, details in pairs(item_details) do
      if not used_keys[id] then
        file:write(string.format("[%q]={ name = %q, stats = %q, zone = %q, source = %q, difficulty = %q, section = %q, item_id = %q, time = %d },\n",
        tostring(id),
        tostring(details.name or "Item"),
        tostring(details.stats or "N/A"),
        tostring(details.zone or "Inconnue"),
        tostring(details.source or "Inconnu"),
        tostring(details.difficulty or "Inconnue"),
        tostring(details.section or "Inconnu"),
        tostring(details.item_id or ""),
        details.time or 0))
      end
    end
    file:write("},\n")
    file:write("S={\n")
    for i = 1, #SAVE.strings do
      file:write(SAVE.quoted[i], ",\n")
    end
    file:write("},\nH={\n")
    for _, line in ipairs(lines) do
      file:write(line, "\n")
    end
    file:write("},\n}\n")
    file:close()
  end
end
K.U.save_data = save_data

local function prepare_loaded_data()
  for key, d in pairs(item_details) do
    if not d.time then
      d.time = tonumber(string.match(tostring(key), "_(%d+)$")) or 0
    end
  end
  for _, d in pairs(item_details) do
    local kind = guess_kind(d.stats, d.name)
    if kind ~= "other" and d.name and not item_kinds[d.name] then
      item_kinds[d.name] = kind
    end
  end
  for name, _ in pairs(item_counts) do
    if not item_kinds[name] then
      item_kinds[name] = no_detail_items[string.lower(name)] and "misc" or "other"
    end
  end
  for name, kind in pairs(item_kinds) do
    if kind == "other" and no_detail_items[string.lower(tostring(name))] then item_kinds[name] = "misc" end
  end
  for _, h in ipairs(drop_history) do
    if h.kind == "other" and no_detail_items[string.lower(tostring(h.name))] then h.kind = "misc" end
  end
  local known = {}
  for _, h in ipairs(drop_history) do
    if h.key then known[h.key] = true end
  end
  local added = false
  for key, d in pairs(item_details) do
    if not known[key] then
      table.insert(drop_history, {
        time = d.time or 0,
        name = d.name or "Item",
        kind = item_kinds[d.name] or guess_kind(d.stats, d.name),
        zone = d.zone or "Inconnue",
        difficulty = d.difficulty or "Inconnue",
        section = d.section or "Inconnu",
        source = d.source or "Inconnu",
        key = key,
      })
      added = true
    end
  end
  if added then
    table.sort(drop_history, function(a, b)
      if (a.time or 0) == (b.time or 0) then
        return tostring(a.key or "") < tostring(b.key or "")
      end
      return (a.time or 0) < (b.time or 0)
    end)
  end
  K.trim_history()
end

do
  local loaded = load_data()
  total_global = loaded.total_global
  item_counts = loaded.item_counts
  item_details = loaded.item_details
  item_kinds = loaded.item_kinds
  drop_history = loaded.drop_history
  hide_title_bar = loaded.hide_title_bar
  K.POPUP.apply(loaded.popup)
  K.COMMON.apply(loaded.common)
  K.KC.apply(loaded.kc)
  K.VR.apply(loaded.vr)
  K.POS_NEAR = loaded.pos_near or 0
  episode = loaded.episode
  bg_opacity = loaded.bg_opacity
  bg_theme = loaded.bg_theme
  lang.code = loaded.language
  K.PAGE_CFG.history = loaded.page_history
  K.PAGE_CFG.counters = loaded.page_counters
  K.PAGE_CFG.games = loaded.page_games
  K.hcol_apply(loaded.hist_hidden)
  K.kinds_apply(loaded.hist_kinds_hidden)
  K.RARE_YELLOW = loaded.rare_yellow
  K.HOTKEY.vk = loaded.hotkey_vk
  kill_totals = loaded.kill_totals
  kill_marks = loaded.kill_marks
  K.archive_load(loaded.archive, loaded.archive_best)
  ZONES.learned = loaded.zone_seen or {}
  seen_items = {}
  prepare_loaded_data()
end

local function set_status(text, is_error)
  ui_status.text = text
  ui_status.expire = os.time() + K.STATUS_SECONDS
  ui_status.is_error = is_error or false
end

local history_delete_confirm = { entry = nil, expire = 0 }

local function delete_history_entry(target)
  if target and target.fav then
    set_status(T("fav_protected"))
    return false
  end
  for i = #drop_history, 1, -1 do
    if drop_history[i] == target then
      local detail = target.key and item_details[target.key]
      local stats = detail and detail.stats
      table.remove(drop_history, i)
      K.HIST_REV = K.HIST_REV + 1
      K.CAREER.on_delete(target, stats)
      local name = target.name
      if item_counts[name] and item_counts[name] > 0 then
        item_counts[name] = item_counts[name] - 1
        total_global = math.max(0, total_global - 1)
        if item_counts[name] == 0 then item_counts[name] = nil end
      end
      if target.key then item_details[target.key] = nil end
      save_data()
      set_status(T("entry_deleted", tostring(name)))
      return true
    end
  end
  return false
end

local save_prefix = nil

local function get_save_prefix()
  if save_prefix then return save_prefix end
  local dir = addonDir .. "save/"
  local function can_write()
    local test_path = dir .. "test_ecriture.tmp"
    local test = io.open(test_path, "w")
    if not test then return false end
    test:close()
    pcall(os.remove, test_path)
    return true
  end
  if not can_write() then
    local windows_folder = (string.gsub(addonDir .. "save", "/", "\\"))
    pcall(function() pso.create_directory(dir) end)
    if not can_write() then
      pcall(function()
        local ffi = require("ffi")
        pcall(ffi.cdef, "int CreateDirectoryA(const char *lpPathName, void *lpSecurityAttributes);")
        ffi.C.CreateDirectoryA(windows_folder, nil)
      end)
    end
    if not can_write() then
      pcall(os.execute, 'mkdir "' .. windows_folder .. '"')
    end
  end
  if can_write() then
    save_prefix = dir
  else
    save_prefix = addonDir .. "save_"
  end
  return save_prefix
end

local function copy_file(from_path, to_path)
  local input = io.open(from_path, "rb")
  if not input then return false end
  local content = input:read("*all")
  input:close()
  local output = io.open(to_path, "wb")
  if not output then return false end
  output:write(content)
  output:close()
  return true
end

local function auto_save_data()
  local now = os.time()
  if K.AUTO_SAVE_LAST and now - K.AUTO_SAVE_LAST < 60 then return end
  K.AUTO_SAVE_LAST = now
  pcall(copy_file, dataFileName, get_save_prefix() .. "auto_save.lua")
end

local function backup_before_reset()
  local ok, saved = pcall(function()
    save_data()
    local stamp = os.date("%Y%m%d_%H%M%S")
    return copy_file(dataFileName, get_save_prefix() .. "avant_remise_a_zero_" .. stamp .. ".lua")
  end)
  return ok and saved == true
end

local function reset_all()
  local saved = backup_before_reset()
  item_counts = {}
  item_details = {}
  item_kinds = {}
  drop_history = {}
  K.ARCHIVE = K.archive_new()
  K.HIST_REV = K.HIST_REV + 1
  total_global = 0
  save_data()
  if saved then
    set_status(T("reset_ok"))
  else
    set_status(T("reset_nobackup"))
  end
  return true
end

local function delete_item(name)
  local kept, fav_keys, fav_kept, removed_entries = {}, {}, 0, {}
  for _, h in ipairs(drop_history) do
    if h.name == name and h.fav then
      fav_kept = fav_kept + 1
      if h.key then fav_keys[h.key] = true end
      kept[#kept + 1] = h
    elseif h.name == name then
      local detail = h.key and item_details[h.key]
      removed_entries[#removed_entries + 1] = { h = h, stats = detail and detail.stats }
      if h.key then item_details[h.key] = nil end
    else
      kept[#kept + 1] = h
    end
  end
  local removed = math.max(0, (item_counts[name] or 0) - fav_kept)
  drop_history = kept
  K.HIST_REV = K.HIST_REV + 1
  for _, removed_entry in ipairs(removed_entries) do K.CAREER.on_delete(removed_entry.h, removed_entry.stats) end
  for key, d in pairs(item_details) do
    if d.name == name and not fav_keys[key] then
      item_details[key] = nil
    end
  end
  if fav_kept > 0 then
    item_counts[name] = fav_kept
  else
    item_counts[name] = nil
    item_kinds[name] = nil
  end
  total_global = math.max(0, total_global - removed)
  save_data()
  set_status(T("deleted", tostring(name), removed))
end

local bg_themes = K.UI_DATA.bg_themes

local function push_bg(percent)
  local theme = bg_themes[bg_theme] or bg_themes[1]
  local pushed = 0
  if pcall(imgui.PushStyleColor, "TextDisabled", 1.0, 1.0, 1.0, 1.0) then
    pushed = pushed + 1
  end
  if not (percent >= 100 and bg_theme == 1) then
    if pcall(imgui.PushStyleColor, "WindowBg", theme[1], theme[2], theme[3], percent / 100) then
      pushed = pushed + 1
    end
  end
  local button_colors = {
    { "Button", theme.button },
    { "ButtonHovered", theme.hover },
    { "ButtonActive", theme.active },
  }
  for _, entry in ipairs(button_colors) do
    local color = entry[2]
    if color and pcall(imgui.PushStyleColor, entry[1], color[1], color[2], color[3], 1.0) then
      pushed = pushed + 1
    end
  end
  return pushed
end

local function pop_bg(pushed)
  for _ = 1, (tonumber(pushed) or 0) do
    pcall(imgui.PopStyleColor)
  end
end

local function draw_theme_selector()
  imgui.Text(T("bg_theme"))
  imgui.SameLine(0, 4)
  if imgui.Button("<##bg_theme_prev") then
    bg_theme = bg_theme - 1
    if bg_theme < 1 then
      bg_theme = #bg_themes
    end
    save_data()
  end
  imgui.SameLine(0, 4)
  imgui.Text(T((bg_themes[bg_theme] or bg_themes[1])[4]))
  imgui.SameLine(0, 4)
  if imgui.Button(">##bg_theme_next") then
    bg_theme = bg_theme + 1
    if bg_theme > #bg_themes then
      bg_theme = 1
    end
    save_data()
  end
end

local function button_func()
  window_open = not window_open
end

function K.HOTKEY.name(vk)
  if not vk then return T("hotkey_none") end
  if vk >= 112 and vk <= 123 then return "F" .. tostring(vk - 111) end
  if (vk >= 48 and vk <= 57) or (vk >= 65 and vk <= 90) then return string.char(vk) end
  if vk >= 96 and vk <= 105 then return "Num" .. tostring(vk - 96) end
  local names = {
    [8] = "Backspace", [9] = "Tab", [13] = "Enter", [19] = "Pause", [32] = "Space", [33] = "PageUp", [34] = "PageDown",
    [35] = "End", [36] = "Home", [37] = "Left", [38] = "Up", [39] = "Right", [40] = "Down", [45] = "Insert",
    [106] = "Num*", [107] = "Num+", [109] = "Num-", [110] = "Num.", [111] = "Num/", [144] = "NumLock", [145] = "ScrollLock",
    [186] = ";", [187] = "=", [188] = ",", [189] = "-", [190] = ".", [191] = "/", [192] = "`", [219] = "[", [220] = "\\", [221] = "]", [222] = "'",
  }
  return names[vk] or ("VK" .. tostring(vk))
end

function K.HOTKEY.supported()
  return type(imgui.IsKeyPressed) == "function"
end

function K.HOTKEY.poll()
  local vk = K.HOTKEY.vk
  if not vk or K.HOTKEY.capturing or not K.HOTKEY.supported() then return end
  if window_open and type(imgui.IsAnyItemActive) == "function" then
    local ok_active, active = pcall(imgui.IsAnyItemActive)
    if ok_active and active then return end
  end
  local ok, pressed = pcall(imgui.IsKeyPressed, vk, false)
  if ok and pressed then
    window_open = not window_open
  end
end

K.HOTKEY.SKIP = { [1] = true, [2] = true, [4] = true, [5] = true, [6] = true, [16] = true, [17] = true, [18] = true,
[91] = true, [92] = true, [93] = true, [160] = true, [161] = true, [162] = true, [163] = true, [164] = true, [165] = true }

function K.HOTKEY.draw_button()
  imgui.SameLine(0, 16)
  if not K.HOTKEY.supported() then
    imgui.TextDisabled(T("hotkey_unsupported"))
    return
  end
  if K.HOTKEY.capturing then
    if imgui.Button(T("hotkey_capture") .. "##hotkey_btn") then
      K.HOTKEY.capturing = false
      return
    end
    for vk = 8, 254 do
      if not K.HOTKEY.SKIP[vk] then
        local ok, pressed = pcall(imgui.IsKeyPressed, vk, false)
        if ok and pressed then
          if vk == 27 then
          elseif vk == 46 or vk == 8 then
            K.HOTKEY.vk = nil
            save_data()
          else
            K.HOTKEY.vk = vk
            save_data()
          end
          K.HOTKEY.capturing = false
          break
        end
      end
    end
  else
    if imgui.Button(T("hotkey_btn", K.HOTKEY.name(K.HOTKEY.vk)) .. "##hotkey_btn") then
      K.HOTKEY.capturing = true
    end
    if imgui.IsItemHovered() then
      imgui.BeginTooltip()
      imgui.Text(T("hotkey_tip"))
      imgui.EndTooltip()
    end
  end
end

K.EPISODE_ADDR = 0x00A9B1C8

local function get_auto_episode()
  local ok, value = pcall(pso.read_u32, K.EPISODE_ADDR)
  if not ok then return nil end
  if value == 0 then return 1 end
  if value == 1 then return 2 end
  if value == 2 then return 4 end
  return nil
end

local function get_current_zone()
  local ok, floor = pcall(lib_characters.GetCurrentFloorSelf)
  if ok and type(floor) == "number" then
    local auto_episode = get_auto_episode()
    if auto_episode then
      episode = auto_episode
    end
    local names = floor_names[episode] or floor_names[1]
    return names[floor] or ("Etage " .. tostring(floor))
  end
  return "Zone Inconnue"
end

K.DIFFICULTY_ADDR = 0x00A9CD68

local difficulty_modules = K.GAME_DATA.difficulty_modules
local floor_groups = K.GAME_DATA.floor_groups
local box_keys = K.GAME_DATA.box_keys
local custom_floor_monsters = K.GAME_DATA.custom_floor_monsters
local module_cache = {}

local function load_module(name)
  if module_cache[name] == nil then
    local ok, module = pcall(require, name)
    if ok and type(module) == "table" then
      module_cache[name] = module
    else
      module_cache[name] = false
    end
  end
  return module_cache[name] or nil
end

local function parse_odds(text)
  local value = string.match(tostring(text or ""), "1/([%d%.]+)")
  return tonumber(value)
end

local function format_odds(value)
  local text = string.format("%.2f", value)
  text = string.gsub(text, "%.?0+$", "")
  return text
end


local difficulty_labels = K.GAME_DATA.difficulty_labels

local function difficulty_loc(value)
  value = tostring(value or "Inconnue")
  if lang.code == "ja" then
    local ja_difficulties = {
      ["Normal"] = "ノーマル",
      ["Hard"] = "ハード",
      ["Very Hard"] = "ベリーハード",
      ["Ultimate"] = "アルティメット",
      ["Inconnue"] = "不明",
      ["Unknown"] = "不明",
    }
    return ja_difficulties[value] or value
  elseif lang.code == "en" and value == "Inconnue" then
    return "Unknown"
  end
  return value
end

local section_labels = K.GAME_DATA.section_labels

K.SIDE_MESSAGE_OFFSET = 0x006AECC8
local game_section_name = nil
K.U.section_name = function() return game_section_name end
local game_rdr_percent = nil
local game_dar_percent = nil
local game_rer_percent = nil
local game_message_text = ""
K.U.rdr = function() return game_rdr_percent end
K.U.dar = function() return game_dar_percent end

function K.read_side_text()
  local ptr = pso.read_u32(pso.base_address + K.SIDE_MESSAGE_OFFSET)
  if ptr ~= 0 then
    return pso.read_wstr(ptr + 0x14, 0xFF)
  end
  return ""
end

local function update_game_section()
  local ok, text = pcall(K.read_side_text)
  if not ok or type(text) ~= "string" then return end
  if text == K.SIDE_LAST_TEXT then return end
  K.SIDE_LAST_TEXT = text
  local id_index = string.find(text, "ID", 1, true)
  local drop_index = string.find(text, "Drop", 1, true)
  if id_index and drop_index and drop_index > id_index and string.find(text, "Rare", 1, true) then
    local name = string.match(string.sub(text, id_index + 2, drop_index - 1), "%a+")
    local clean = (string.gsub(text, "\tC%d", ""))
    game_message_text = clean
    local rare = tonumber(string.match(text, "Rare%s*:?%s*(%d+%.?%d*)"))
    if rare and rare > 0 and rare < 10000 then
      game_rdr_percent = rare
    end
    local dar = tonumber(string.match(clean, "[Dd]rop%s*:?%s*(%d+%.?%d*)"))
    if dar and dar > 0 and dar < 10000 then
      game_dar_percent = dar
    end
    local rer = tonumber(string.match(clean, "[Ee]nem%a*%s*:?%s*(%d+%.?%d*)"))
    if rer and rer > 0 and rer < 10000 then
      game_rer_percent = rer
    end
    for _, label in pairs(section_labels) do
      if label == name then
        game_section_name = name
        return
      end
    end
  end
end

function K.section_index_by_label(name)
  local map = K.SECTION_BY_LABEL
  if not map then
    map = {}
    for index, label in pairs(section_labels) do map[label] = index end
    K.SECTION_BY_LABEL = map
  end
  return map[name]
end

function K.read_player_section()
  return lib_characters.GetPlayerSectionID(lib_characters.GetSelf())
end

local function get_section_index()
  if game_section_name then
    local index = K.section_index_by_label(game_section_name)
    if index then return index, true end
  end
  local ok, value = pcall(K.read_player_section)
  if ok and type(value) == "number" and section_labels[value] then
    return value, false
  end
  return nil, false
end

local function get_game_context()
  local ok_diff, difficulty_value = pcall(pso.read_u32, K.DIFFICULTY_ADDR)
  local difficulty_label = (ok_diff and difficulty_labels[difficulty_value]) or "Inconnue"
  local section_label = "Inconnu"
  local section_index, from_game = get_section_index()
  if section_index then
    section_label = section_labels[section_index]
    if not from_game then
      section_label = section_label .. " (perso)"
    end
  end
  return difficulty_label, section_label
end

local function get_current_floor()
  local frame_id = K.frame_id
  if frame_id and K.floor_frame == frame_id then return K.floor_value end
  local ok, floor = pcall(lib_characters.GetCurrentFloorSelf)
  local value = nil
  if ok and type(floor) == "number" then
    value = floor
  end
  K.floor_frame = frame_id
  K.floor_value = value
  return value
end

local rare_keys_cache = nil

local function get_rare_keys()
  if rare_keys_cache then return rare_keys_cache end
  local set = {}
  local extra = load_module("Hunters Log.charts.Enemies Extra")
  if extra then
    for _, list in pairs(extra) do
      if type(list) == "table" then
        for _, rare_key in ipairs(list) do
          if rare_key ~= "" then
            set[rare_key] = true
          end
        end
      end
    end
  end
  if next(set) == nil then
    for _, key in ipairs({
        "Al Rappy", "Hildeblue", "Nar Lily", "Pouilly Slime", "Hidoom", "Migium", "Bulk",
        "Nar Lily E2", "Love Rappy", "St. Rappy", "Halo Rappy", "Egg Rappy",
        "Hildeblue E2", "Hidoom E2", "Migium E2", "Del Rappy", "Pazuzu",
        "Dorphon Eclair", "Merissa AA", "Kondrieu",
      }) do
      set[key] = true
    end
  end
  for _, key in ipairs({ "Pan Arms", "Migium", "Hidoom", "Bulk" }) do
    set[key] = nil
    set[key .. " E2"] = nil
  end
  rare_keys_cache = set
  return set
end

K.EVENT_RAPPIES = { "Halo Rappy", "Hallo Rappy", "St. Rappy", "St Rappy", "Egg Rappy" }
K.IGNORE_IMPOSSIBLE_DROPS = true
K.IMPOSSIBLE = "__impossible__"
K.CHART_ITEMS = {}

function K.chart_items(difficulty, modules)
  local set = K.CHART_ITEMS[difficulty]
  if set then return set end
  local rares = load_module(modules.rares)
  if not rares then return nil end
  local boxes = load_module(modules.boxes)
  set = {}
  for _, data in pairs(rares) do
    if type(data) == "table" then
      for section = 0, 9 do
        local name = data[section * 4 + 1]
        if type(name) == "string" and name ~= "" then set[string.lower(name)] = true end
      end
    end
  end
  if boxes then
    for _, box in pairs(boxes) do
      if type(box) == "table" then
        local per_row = box[0] or 0
        for section = 0, 9 do
          local start = section * per_row * 2
          for n = 0, per_row - 1 do
            local name = box[start + n * 2 + 1]
            if type(name) == "string" and name ~= "" then set[string.lower(name)] = true end
          end
        end
      end
    end
  end
  K.CHART_ITEMS[difficulty] = set
  return set
end

-- True when the item is listed in the drop chart of another difficulty (so it is a known rare, just not obtainable in this one).
function K.chart_items_elsewhere(difficulty, lname)
  for other, modules in pairs(difficulty_modules) do
    if other ~= difficulty then
      local set = K.chart_items(other, modules)
      if set and set[lname] then return true end
    end
  end
  return false
end

local function find_drop_source(item_name, floor, is_weapon)
  if not item_name or not floor or string.find(item_name, "%?") then
    return "Inconnu"
  end
  local extra_key = ZONES.extra_by_item[string.lower(item_name)]
  if extra_key then
    local extra_odds = ZONES.extra[extra_key][2]
    return extra_key, "1/" .. format_odds(extra_odds), nil, nil, nil, extra_key, { extra_key, odds = { [extra_key] = extra_odds } }
  end
  local ok, result, rates, drr_used, dar_used, rer_used, rare_text, candidate_keys = pcall(function()
    local difficulty = pso.read_u32(K.DIFFICULTY_ADDR)
    local modules = difficulty_modules[difficulty]
    local section_index = get_section_index()
    if not modules or type(section_index) ~= "number" or section_index < 0 or section_index > 9 then
      return nil
    end
    local lname = string.lower(item_name)
    local best = {}
    local best_text = {}
    local best_dar = {}
    local best_rare_rate = {}
    local rare_names = {}
    local best_key = {}
    local function add(name, odds, text, dar_text, rare_rate_text, is_rare_enemy, monster_key)
      odds = odds or 1000000000
      if best[name] == nil or odds < best[name] then
        best[name] = odds
        best_text[name] = text
        best_dar[name] = dar_text
        best_rare_rate[name] = rare_rate_text
        rare_names[name] = is_rare_enemy or nil
        best_key[name] = monster_key
      end
    end
    local rares = load_module(modules.rares)
    local enemies = load_module("Hunters Log.charts.Enemies")
    local quests = load_module("Hunters Log.charts.Quests")
    local group = floor_groups[episode] and floor_groups[episode][floor]
    local monsters = custom_floor_monsters[episode] and custom_floor_monsters[episode][floor]
    if not monsters then
      monsters = group and quests and quests["Quest"] and quests["Quest"][group]
    end
    if rares and monsters then
      local offset = section_index * 4
      for i = 1, #monsters, 2 do
        local orig_key = monsters[i]
        local key = (K.KEYALIAS and orig_key ~= "" and K.KEYALIAS.resolve(rares, orig_key)) or orig_key
        local data = rares[key]
        if key ~= "" and data and string.lower(data[offset + 1] or "") == lname then
          local display = key
          local names_row = enemies and (enemies[orig_key] or enemies[key])
          if names_row and names_row[difficulty + 1] then
            display = names_row[difficulty + 1]
          end
          add(display, parse_odds(data[offset + 4]), data[offset + 4],
          data[offset + 2], data[offset + 3], get_rare_keys()[key], key)
        end
      end
    end
    if rares and K.RECENT_DEATHS then
      local offset = section_index * 4
      for _, death in ipairs(K.RECENT_DEATHS) do
        if frame_counter - death.frame <= K.death_window(death.key) then
          local base = string.gsub(death.key, " E2$", "")
          for _, variant in ipairs({ death.key, base, base .. " E2" }) do
            local data = rares[variant]
            if data and string.lower(data[offset + 1] or "") == lname then
              local display = variant
              if enemies and enemies[variant] and enemies[variant][difficulty + 1] then
                display = enemies[variant][difficulty + 1]
              end
              add(display, parse_odds(data[offset + 4]), data[offset + 4],
              data[offset + 2], data[offset + 3], get_rare_keys()[variant], death.key)
              break
            end
          end
        end
      end
    end
    local box_key = box_keys[episode] and box_keys[episode][floor]
    local boxes = load_module(modules.boxes)
    local box = box_key and boxes and boxes[box_key]
    if box then
      local per_row = box[0] or 0
      local start = section_index * per_row * 2
      for n = 0, per_row - 1 do
        local box_item = box[start + n * 2 + 1]
        if box_item and string.lower(box_item) == lname then
          add("Caisse (" .. box_key .. ")", parse_odds(box[start + n * 2 + 2]), box[start + n * 2 + 2])
        end
      end
    end
    local names = {}
    for name, _ in pairs(best) do
      table.insert(names, name)
    end
    if #names == 0 then
      if K.IGNORE_IMPOSSIBLE_DROPS and monsters then
        local known = K.chart_items(difficulty, modules)
        if known and known[lname] then return K.IMPOSSIBLE end
        if not is_weapon and K.chart_items_elsewhere(difficulty, lname) then return K.IMPOSSIBLE end
      end
      return nil
    end
    table.sort(names, function(a, b)
      if best[a] == best[b] then return a < b end
      return best[a] < best[b]
    end)
    local rdr_mult = (game_rdr_percent and game_rdr_percent > 0) and (game_rdr_percent / 100) or nil
    local dar_mult = (game_dar_percent and game_dar_percent > 0) and (game_dar_percent / 100) or nil
    local function percent_of(text)
      return tonumber(string.match(tostring(text or ""), "%(([%d%.]+)%%%)"))
    end
    local rate_list = {}
    local rate_by_name = {}
    local rare_list = {}
    local odds_by_key = {}
    for _, name in ipairs(names) do
      local base = parse_odds(best_text[name])
      local dar_base = percent_of(best_dar[name])
      local rare_base = percent_of(best_rare_rate[name])
      local odds = nil
      if dar_base and rare_base and dar_base > 0 and rare_base > 0 then
        local dar_eff = math.min(100, math.floor(dar_base * (dar_mult or 1) + 1e-9))
        local rare_eff = math.min(100, rare_base * (rdr_mult or 1))
        odds = 10000 / (dar_eff * rare_eff)
      elseif base then
        odds = base / ((rdr_mult or 1) * (dar_mult or 1))
      end
      rate_list[#rate_list + 1] = odds and ("1/" .. format_odds(odds)) or "?"
      rate_by_name[name] = rate_list[#rate_list]
      if odds and best_key[name] then
        odds_by_key[best_key[name]] = odds
      end
      if rare_names[name] then
        rare_list[#rare_list + 1] = name
      end
    end
    local key_list = {}
    for _, name in ipairs(names) do
      if best_key[name] then
        key_list[#key_list + 1] = best_key[name]
      end
    end
    do
      local love_found, love_odds = false, nil
      for _, listed in ipairs(key_list) do
        if listed == "Love Rappy" then love_found = true; love_odds = odds_by_key[listed]; break end
      end
      if love_found then
        for _, alias in ipairs(K.EVENT_RAPPIES) do
          key_list[#key_list + 1] = alias
          if love_odds then odds_by_key[alias] = love_odds end
        end
      end
    end
    key_list.odds = odds_by_key
    for _, name in ipairs(names) do
      if string.sub(name, 1, 8) == "Caisse (" then
        key_list.box = { name = name, rate = rate_by_name[name] }
        break
      end
    end
    return table.concat(names, " / "), table.concat(rate_list, " / "),
    rdr_mult and game_rdr_percent or nil, dar_mult and game_dar_percent or nil, game_rer_percent,
    (#rare_list > 0) and table.concat(rare_list, " / ") or nil, key_list
  end)
  if ok and result then
    return result, rates, drr_used, dar_used, rer_used, rare_text, candidate_keys
  end
  return "Inconnu", nil, nil, nil, nil, nil, nil
end

K.ENTITY_POINTER_CODE = 0x007B4BA0
K.ENTITY_COUNT_ADDR = 0x00AAE164
K.PLAYER_COUNT_ADDR = 0x00AAE168
K.MONSTER_ID_OFFSET = 0x378
K.MONSTER_HP_OFFSET = 0x334
K.MONSTER_STATE_OFFSET = 0x32E
K.MONSTER_DEROLLE_HP_OFFSET = 0x6B4
K.MONSTER_BARBARAY_HP_OFFSET = 0x704
K.LILY_SLAIN_STATE = 0xA
K.DUBCHIC_RECOUNT_FRAMES = 45
K.DUBWITCH_LINK_FRAMES = 240
K.DEATH_WINDOW_SECONDS = { classic = 2, boss = 15, final = 35 }

K.BOSS_WINDOW_CLASS = {
  dragon = "boss", derolle = "boss", volopt = "boss", galgryphon = "boss", barbaray = "boss", goldragon = "boss",
  darkfalz = "final", olgaflow = "final", saintmillion = "final", saintmilion = "final", shambertin = "final", kondrieu = "final",
}

function K.death_window(key)
  local lower = string.lower(tostring(key or ""))
  local class = "classic"
  if string.find(lower, "rappy", 1, true) then
    class = "final"
  else
    local norm = string.gsub(lower, " e2$", "")
    norm = string.gsub(norm, "[^%w]", "")
    class = K.BOSS_WINDOW_CLASS[norm] or "classic"
  end
  return K.DEATH_WINDOW_SECONDS[class] * (K.FPS or 60)
end

local monster_chart_keys = K.GAME_DATA.monster_chart_keys
K.MONSTER_ALT = K.GAME_DATA.monster_alt
K.MON_CACHE = {}

function K.monster_norm(text)
  local normalized = string.lower(text)
  normalized = string.gsub(normalized, "[%.']", "")
  normalized = string.gsub(normalized, "%s+", " ")
  return normalized
end

K.MONSTER_IDS = {}

for monster_id, monster_key in pairs(monster_chart_keys) do
  K.MONSTER_IDS[K.monster_norm(monster_key)] = monster_id
end

K.MONSTER_IDS["halo rappy"] = 80
K.MONSTER_IDS["saint-million"] = 106

function K.monster_text(text)
  if K.UNITXT == nil then
    local ok, module = pcall(require, "solylib.unitxt")
    K.UNITXT = (ok and type(module) == "table" and type(module.GetMonsterName) == "function") and module or false
  end
  if not K.UNITXT then return nil end
  local cached = K.MON_CACHE[text]
  if cached then return cached end
  local core, tail = text, ""
  local stripped, tag = string.match(core, "^(.-)(%s*%[E%d%])$")
  if not stripped then stripped, tag = string.match(core, "^(.-)(%s+E%d)$") end
  if stripped then core, tail = stripped, tag end
  local key = K.monster_norm(core)
  local id, ultimate = K.MONSTER_ALT[key], true
  if not id then id, ultimate = K.MONSTER_IDS[key], false end
  if not id then return nil end
  local function read(is_ultimate)
    local ok, result = pcall(K.UNITXT.GetMonsterName, id, is_ultimate)
    if ok and type(result) == "string" and result ~= "" and result ~= "Unknown" then return result end
    return nil
  end
  local name = read(ultimate) or (ultimate and read(false) or nil)
  if not name then return nil
  end
  name = name .. tail
  K.MON_CACHE[text] = name
  return name
end

local episode2_variants = K.GAME_DATA.episode2_variants

local KEYALIAS = { rares_maps = setmetatable({}, { __mode = "k" }), kill_names = nil }

function KEYALIAS.norm(key)
  local text = string.lower(tostring(key or ""))
  local e2 = string.find(text, " e2$") ~= nil
  text = string.gsub(text, " e2$", "")
  text = string.gsub(text, "[%-_']", " ")
  text = string.gsub(text, "h", "")
  text = string.gsub(text, "ll", "l")
  text = string.gsub(text, "%s+", " ")
  return text .. (e2 and " e2" or "")
end

function KEYALIAS.map_of(file_table)
  local map = KEYALIAS.rares_maps[file_table]
  if not map then
    map = {}
    for file_key in pairs(file_table) do
      if type(file_key) == "string" then map[KEYALIAS.norm(file_key)] = file_key end
    end
    KEYALIAS.rares_maps[file_table] = map
  end
  return map
end

KEYALIAS.synonyms = { ["gulgus"] = "Savage Wolf E2", ["gulgus gue"] = "Barbarous Wolf E2" }
KEYALIAS.synonyms_back = { ["savage wolf e2"] = "Gulgus", ["barbarous wolf e2"] = "Gulgus-Gue" }

function KEYALIAS.resolve(file_table, key)
  if type(file_table) ~= "table" or file_table[key] ~= nil then return key end
  local map = KEYALIAS.map_of(file_table)
  local norm = KEYALIAS.norm(key)
  if map[norm] then return map[norm] end
  local other = KEYALIAS.synonyms[norm] or KEYALIAS.synonyms_back[norm]
  if other then
    if file_table[other] ~= nil then return other end
    return map[KEYALIAS.norm(other)] or key
  end
  return key
end

K.KEYALIAS = KEYALIAS
K.RARES_BY_PREFIX = {}

function KEYALIAS.rares_for_prefix(prefix)
  if prefix ~= nil then
    local cached = K.RARES_BY_PREFIX[prefix]
    if cached ~= nil then return cached or nil end
  end
  local difficulty = tonumber(string.match(tostring(prefix or ""), "^(%d+)|"))
  local modules = difficulty and difficulty_modules[difficulty]
  local result = modules and load_module(modules.rares) or nil
  if prefix ~= nil and result then K.RARES_BY_PREFIX[prefix] = result end
  return result
end

function KEYALIAS.kill_name_map()
  if not KEYALIAS.kill_names then
    local map = {}
    for id, name in pairs(monster_chart_keys) do
      map[KEYALIAS.norm(name)] = name
      if episode2_variants[id] then
        map[KEYALIAS.norm(name .. " E2")] = name .. " E2"
      end
    end
    KEYALIAS.kill_names = map
  end
  return KEYALIAS.kill_names
end

function KEYALIAS.spellings(rares, key)
  local list, seen = {}, {}
  local function add(name)
    if name and not seen[name] then
      seen[name] = true
      list[#list + 1] = name
    end
  end
  add(key)
  add(KEYALIAS.resolve(rares, key))
  add(KEYALIAS.kill_name_map()[KEYALIAS.norm(key)])
  local other = KEYALIAS.synonyms[KEYALIAS.norm(key)] or KEYALIAS.synonyms_back[KEYALIAS.norm(key)]
  if other then
    add(other)
    add(KEYALIAS.resolve(rares, other))
    add(KEYALIAS.kill_name_map()[KEYALIAS.norm(other)])
  end
  return list
end

function KEYALIAS.total(prefix, key, rares)
  local sum = 0
  for _, name in ipairs(KEYALIAS.spellings(rares, key)) do
    sum = sum + (tonumber(kill_totals[prefix .. name]) or 0)
  end
  return sum
end

function KEYALIAS.mark(prefix, key, item, rares)
  local best = 0
  for _, name in ipairs(KEYALIAS.spellings(rares, key)) do
    local value = tonumber(kill_marks[prefix .. name .. "|" .. tostring(item)]) or 0
    if value > best then best = value end
  end
  return best
end

function KEYALIAS.label(enemies, key, difficulty)
  if type(enemies) ~= "table" then return nil end
  local entry = enemies[key] or enemies[KEYALIAS.resolve(enemies, key)]
  return type(entry) == "table" and entry[difficulty + 1] or nil
end

KEYALIAS.classic = {}

for _, name in ipairs({ "Pan Arms", "Migium", "Hidoom", "Bulk" }) do
  KEYALIAS.classic[KEYALIAS.norm(name)] = true
  KEYALIAS.classic[KEYALIAS.norm(name .. " E2")] = true
end

function KEYALIAS.is_rare(rare_keys, key)
  if KEYALIAS.classic[KEYALIAS.norm(key)] then return false end
  return rare_keys[key] == true
end

local BOSS = {
  keys = {
    [46] = "Vol Opt", [47] = "Dark Falz", [76] = "Gol Dragon", [77] = "Gal Gryphon", [78] = "Olga Flow",
    [106] = "Saint Million", [107] = "Shambertin", [108] = "Kondrieu",
  },
  phases = { [46] = 5, [47] = 3, [78] = 2 },
  merge_seconds = { [47] = 10 },
  gone_by_id = { [47] = 45 },
  main_entity = { [46] = true, [106] = true, [107] = true, [108] = true },
  hpmax = {},
  state = {},
  gone_seconds = 8,
}

function K.boss_is_main(address, monster_id)
  local mine = BOSS.hpmax[address]
  if not mine or mine.max <= 0 then return nil end
  if monster_id == 106 or monster_id == 107 or monster_id == 108 then
    if mine.max < 5000 then return false end
    for other_address, other in pairs(BOSS.hpmax) do
      if other_address ~= address and other.id == monster_id and other.max >= 5000
        and frame_counter - other.frame < 1800 and (other.index or 0) < (mine.index or 0) then
        return false
      end
    end
  end
  for _, other in pairs(BOSS.hpmax) do
    if other.id == monster_id and other.max > mine.max and frame_counter - other.frame < 1800 then
      return false
    end
  end
  return true
end

local entity_array = 0
local alive_seen = {}
local slain_entities = {}
local dubchic_seen = {}
local prev_present = {}
local dubchic_dead = {}
local dubwitch_death_frame = -1000000
local dubwitch_seen = {}
local recent_deaths = {}
K.RECENT_DEATHS = recent_deaths
K.SLIME_SEEN = {}
-- Lilies (Poison / Nar-Mil / Del) that can disappear below 25% HP without ever reaching 0 HP or the slain state.
K.LILY_SEEN = {}
K.SLIME_MIN_LIFE = 30
K.RARE_ID_CACHE = {}

function K.rare_key_for(monster_id, ep, rares_now)
  local cache_key = (tonumber(ep) or 1) * 1000 + monster_id
  local value = K.RARE_ID_CACHE[cache_key]
  if value == nil then
    value = false
    local base = monster_chart_keys[monster_id]
    if base then
      local key = base
      if ep == 2 and episode2_variants[monster_id] then key = key .. " E2" end
      key = KEYALIAS.resolve(rares_now, key)
      local rare_keys = get_rare_keys()
      if rare_keys[key] or rare_keys[base] then value = key end
    end
    K.RARE_ID_CACHE[cache_key] = value
  end
  return value or nil
end

K.DEATH_RADIUS = 25
K.SPAWN_DEATH_RADIUS = 150 -- wider radius for monsters whose drop appears away from the corpse (Chaos Sorcerer...)
K.RAPPY_DEATH_RADIUS = 200
K.POS_NEAR = K.POS_NEAR or 0
K.POS_CALIBRATION = 2
K.SURE_FAR_RADIUS = 300 -- beyond this distance an item is rejected even before the position check is calibrated

function K.entity_pos(address)
  local ok, x, z = pcall(function()
    return pso.read_f32(address + 0x38), pso.read_f32(address + 0x40)
  end)
  if ok and type(x) == "number" and type(z) == "number" and x == x and z == z and (x ~= 0 or z ~= 0) then
    return x, z
  end
  return nil
end

function K.item_pos(item)
  if type(item) ~= "table" then return nil end
  local x, z = tonumber(item.x or item.posX), tonumber(item.z or item.posZ)
  if x and z then return x, z end
  if item.address then return K.entity_pos(item.address) end
  return nil
end

K.SPAWN_DROP_KEYS = {
  chaossorcerer = true, gransorcerer = true, grandsorcerer = true, delbiter = true,
  chaosbringer = true, darkbringer = true, zu = true, pazuzu = true, dorphon = true, dorphoneclair = true,
}

function K.death_class(key)
  local lower = string.lower(tostring(key or ""))
  if string.find(lower, "rappy", 1, true) then return "rappy" end
  local norm = string.gsub(lower, " e2$", "")
  norm = string.gsub(norm, "[^%w]", "")
  if K.BOSS_WINDOW_CLASS and K.BOSS_WINDOW_CLASS[norm] then return "boss" end
  if K.SPAWN_DROP_KEYS[norm] then return "spawn" end
  return "classic"
end

function K.death_capacity(key)
  local class = K.death_class(key)
  if class == "boss" then return 3 end
  if class == "rappy" then return 2 end
  return 1
end

function K.death_ok(death)
  return frame_counter - death.frame <= K.death_window(death.key) and (death.used or 0) < K.death_capacity(death.key)
end

function K.pick_death(candidate_keys, item, item_name)
  if type(candidate_keys) ~= "table" or #candidate_keys == 0 then return nil end
  local allowed = {}
  for _, key in ipairs(candidate_keys) do allowed[key] = true end
  local ix, iz = K.item_pos(item)
  local best, best_dist, far, far_dist = nil, nil, false, nil
  local duplicate = false
  for i = #recent_deaths, 1, -1 do
    local death = recent_deaths[i]
    if item_name and allowed[death.key] and K.death_ok(death) and K.death_class(death.key) == "rappy"
      and death.names and death.names[item_name] then
      duplicate = true
    elseif allowed[death.key] and K.death_ok(death) then
      local dist = nil
      local class = K.death_class(death.key)
      if ix and death.x and class ~= "boss" then
        local dx, dz = ix - death.x, iz - death.z
        dist = math.sqrt(dx * dx + dz * dz)
      end
      local radius = K.DEATH_RADIUS
      if class == "spawn" then
        radius = K.SPAWN_DEATH_RADIUS
      elseif class == "rappy" then
        radius = K.RAPPY_DEATH_RADIUS
      end
      if dist and dist > radius then
        far = true
        far_dist = far_dist and math.min(far_dist, dist) or dist
      elseif not best or (dist and (not best_dist or dist < best_dist)) then
        best, best_dist = death, dist
      end
    end
  end
  if best then
    if best_dist then K.POS_NEAR = K.POS_NEAR + 1 end
    return best
  end
  if far then
    if K.POS_NEAR >= K.POS_CALIBRATION or (far_dist and far_dist > K.SURE_FAR_RADIUS) then return nil, "far" end
  end
  if duplicate then return nil, "duplicate" end
  return nil
end

function K.claim_death(death, item_name)
  if not death then return end
  death.used = (death.used or 0) + 1
  if item_name then
    death.names = death.names or {}
    death.names[item_name] = true
  end
end

local PENDING = { list = {}, window = 600 }
K.PREFIX_CACHE = {}

local function kill_context_prefix()
  local ok, difficulty = pcall(pso.read_u32, K.DIFFICULTY_ADDR)
  if not ok or not difficulty_labels[difficulty] then return nil end
  local section_index = get_section_index()
  if not section_index or not section_labels[section_index] then return nil end
  local ep = get_auto_episode() or episode
  local tag = difficulty * 10000 + ep * 100 + section_index
  local prefix = K.PREFIX_CACHE[tag]
  if not prefix then
    prefix = tostring(difficulty) .. "|" .. tostring(ep) .. "|" .. section_labels[section_index] .. "|"
    K.PREFIX_CACHE[tag] = prefix
  end
  return prefix, ep
end

local function register_kill(prefix, ep, floor, key)
  local total_key = prefix .. key
  kill_totals[total_key] = (kill_totals[total_key] or 0) + 1
  K.KC.session[total_key] = (K.KC.session[total_key] or 0) + 1
  kills_dirty = true
  K.KILLS_VER = (K.KILLS_VER or 0) + 1
  ZONES.learn(ep, floor, key)
  recent_deaths[#recent_deaths + 1] = { frame = frame_counter, key = key }
  if #recent_deaths > 40 then
    table.remove(recent_deaths, 1)
  end
  if PENDING.resolve then PENDING.resolve(key) end
end

K.LOBBY_DELAY = 3
K.GOL_DRAGON_ID = 76

function K.gol_dragon_present()
  local ok, found = pcall(function()
    if entity_array == 0 then
      entity_array = pso.read_u32(K.ENTITY_POINTER_CODE + 2)
      if entity_array == 0 then return false end
    end
    local player_count = pso.read_u32(K.PLAYER_COUNT_ADDR)
    local entity_count = pso.read_u32(K.ENTITY_COUNT_ADDR)
    if entity_count <= 0 or entity_count > 3000 then return false end
    for index = 1, entity_count do
      local address = pso.read_u32(entity_array + 4 * (index - 1 + player_count))
      if address ~= 0 and pso.read_u32(address + K.MONSTER_ID_OFFSET) == K.GOL_DRAGON_ID then
        return true
      end
    end
    return false
  end)
  return ok and found == true
end

K.arena_seen = false

function K.lobby_candidate(floor)
  if floor ~= K.LOBBY_FLOOR then K.arena_seen = false; return false end
  if K.gol_dragon_present() then K.arena_seen = true; return false end
  if K.arena_seen then
    local qptr = 0
    pcall(function() qptr = pso.read_u32(K.QUEST_PTR_ADDR) or 0 end)
    if qptr ~= 0 then return false end
    K.arena_seen = false
  end
  return true
end

function K.is_lobby(floor)
  if not K.lobby_candidate(floor) then
    K.lobby_since = nil
    return false
  end
  local now = os.time()
  K.lobby_since = K.lobby_since or now
  return now - K.lobby_since >= K.LOBBY_DELAY
end

K.RAREPOP = { announced = {}, last_key_time = {}, floor = nil, cooldown = 12 }

function K.RAREPOP.reset()
  K.RAREPOP.floor = nil
  K.RAREPOP.announced = {}
end

function K.RAREPOP.track_floor(floor)
  if K.RAREPOP.floor ~= floor then
    K.RAREPOP.floor = floor
    K.RAREPOP.announced = {}
  end
end

function K.RAREPOP.seen(address, rare_name, floor, ep)
  local R = K.RAREPOP
  if R.announced[address] then return end
  R.announced[address] = true
  local cfg = K.POPUP.cfg
  if not cfg.rare_enabled then return end
  local base = (string.gsub(rare_name, " E2$", ""))
  local now = os.clock()
  local last = R.last_key_time[base]
  if last and now - last < R.cooldown then return end
  R.last_key_time[base] = now
  local ok_diff, diff_value = pcall(pso.read_u32, K.DIFFICULTY_ADDR)
  local game = { difficulty = ok_diff and difficulty_labels[diff_value] or nil, episode = ep }
  local ok_name, shown = pcall(K.GAMELOG.rare_label, base, game)
  if not ok_name or type(shown) ~= "string" or shown == "" then shown = loc(base) end
  local zone = floor_names[ep] and floor_names[ep][floor]
  K.POPUP.push_rare(shown, zone and loc(zone) or nil)
end

function K.update_kills_body()
  local floor = get_current_floor()
  if not floor or floor == 0 or K.is_lobby(floor) then
    alive_seen = {}
    slain_entities = {}
    dubchic_seen = {}
    dubchic_dead = {}
    prev_present = {}
    K.SLIME_SEEN = {}
    K.LILY_SEEN = {}
    dubwitch_seen = {}
    BOSS.state = {}
    BOSS.hpmax = {}
    K.RAREPOP.reset()
    return
  end
  K.RAREPOP.track_floor(floor)
  if entity_array == 0 then
    entity_array = pso.read_u32(K.ENTITY_POINTER_CODE + 2)
    if entity_array == 0 then return end
  end
  local prefix, ep = kill_context_prefix()
  if not prefix then return end
  local rares_now = KEYALIAS.rares_for_prefix(prefix)
  local player_count = pso.read_u32(K.PLAYER_COUNT_ADDR)
  local entity_count = pso.read_u32(K.ENTITY_COUNT_ADDR)
  if entity_count <= 0 or entity_count > 3000 then return end
  local present = K.PRESENT_SPARE or {}
  K.PRESENT_SPARE = nil
  for address in pairs(present) do present[address] = nil end
  local id0_now = {}
  local boss_seen_now = {}
  for index = 1, entity_count do
    local address = pso.read_u32(entity_array + 4 * (index - 1 + player_count))
    if address ~= 0 then
      present[address] = true
      local slain_id = slain_entities[address]
      if slain_id then
        local current_id = pso.read_u32(address + K.MONSTER_ID_OFFSET)
        local reused = current_id ~= slain_id
        local chart_name = monster_chart_keys[current_id]
        local is_rappy = chart_name and string.find(chart_name, "Rappy", 1, true) ~= nil
        if not reused and not is_rappy and current_id ~= 13 and current_id ~= 14 and current_id ~= 83 and current_id ~= 45 and current_id ~= 73 then
          reused = pso.read_u16(address + K.MONSTER_HP_OFFSET) > 0
        end
        if reused then
          slain_entities[address] = nil
          alive_seen[address] = nil
          slain_id = nil
        end
      end
      if not slain_id then
        local monster_id = pso.read_u32(address + K.MONSTER_ID_OFFSET)
        if BOSS.keys[monster_id] then
          boss_seen_now[monster_id] = true
        end
        if BOSS.main_entity[monster_id] then
          local max_hp = pso.read_u16(address + 0x2BC)
          local info = BOSS.hpmax[address]
          if not info or info.id ~= monster_id then
            info = { id = monster_id, max = 0 }
            BOSS.hpmax[address] = info
          end
          if max_hp > 0 then info.max = max_hp end
          info.frame = frame_counter
          info.index = index
        end
        if monster_id == 0 and pso.read_u16(address + K.MONSTER_HP_OFFSET) > 0 then
          id0_now[address] = true
        end
        local base_key = monster_chart_keys[monster_id]
        if base_key then
          local rare_name = K.rare_key_for(monster_id, ep, rares_now)
          local hp_offset = K.MONSTER_HP_OFFSET
          if monster_id == 45 then
            hp_offset = K.MONSTER_DEROLLE_HP_OFFSET
          elseif monster_id == 73 then
            hp_offset = K.MONSTER_BARBARAY_HP_OFFSET
          end
          local hp = pso.read_u16(address + hp_offset)
          if rare_name and (hp > 0 or BOSS.keys[monster_id]) then
            K.GAMELOG.note_rare(rare_name, address, floor)
            K.RAREPOP.seen(address, rare_name, floor, ep)
          end
          local slain = (hp == 0)
          if monster_id == 49 then
            dubwitch_seen[address] = floor
          end
          if monster_id == 13 or monster_id == 14 or monster_id == 83 then
            slain = slain or pso.read_u16(address + K.MONSTER_STATE_OFFSET) == K.LILY_SLAIN_STATE
          end
          if monster_id == 24 then
            dubchic_seen[address] = floor
            slain = false
          end
          if (monster_id == 45 or monster_id == 73) and index ~= 1 then
            slain = false
          end
          if hp > 0 then
            alive_seen[address] = true
            if (monster_id == 19 or monster_id == 20) and not K.SLIME_SEEN[address] then
              K.SLIME_SEEN[address] = { floor = floor, id = monster_id, frame = frame_counter, index = index }
            end
            if monster_id == 13 or monster_id == 14 or monster_id == 83 then
              local lily = K.LILY_SEEN[address]
              if not lily or lily.id ~= monster_id then
                lily = { floor = floor, id = monster_id }
                K.LILY_SEEN[address] = lily
              end
              lily.hp, lily.max = hp, pso.read_u16(address + 0x2BC)
            end
          end
          if slain and alive_seen[address] then
            slain_entities[address] = monster_id
            if K.SLIME_SEEN[address] then
              K.SLIME_SEEN[address] = nil
            end
            K.LILY_SEEN[address] = nil
            local repeated_boss_phase = false
            if BOSS.keys[monster_id] then
              local bst = BOSS.state[monster_id]
              if not bst or bst.floor ~= floor then
                bst = { floor = floor, last = os.time() }
                BOSS.state[monster_id] = bst
              end
              local merged = false
              local merge_window = BOSS.merge_seconds[monster_id]
              local death_time = os.time()
              if merge_window and bst.last_death and death_time - bst.last_death < merge_window then
                merged = true
              end
              bst.last_death = death_time
              local main_state = nil
              if BOSS.main_entity[monster_id] then
                main_state = K.boss_is_main(address, monster_id)
              end
              if not merged then
                bst.deaths = (bst.deaths or 0) + 1
              end
              if merged and not bst.counted then
                repeated_boss_phase = true
              elseif bst.counted then
                repeated_boss_phase = true
              elseif main_state ~= nil then
                if main_state then
                  bst.counted = true
                else
                  repeated_boss_phase = true
                end
              elseif bst.deaths >= (BOSS.phases[monster_id] or 1) then
                bst.counted = true
              else
                repeated_boss_phase = true
              end
              if bst.counted and not repeated_boss_phase then
                set_status(T("boss_kill", base_key))
              end
            end
            local key = base_key
            if ep == 2 and episode2_variants[monster_id] then
              key = key .. " E2"
            end
            key = KEYALIAS.resolve(rares_now, key)
            local total_key = prefix .. key
            if not repeated_boss_phase then
              kill_totals[total_key] = (kill_totals[total_key] or 0) + 1
              K.KC.session[total_key] = (K.KC.session[total_key] or 0) + 1
              kills_dirty = true
              K.KILLS_VER = (K.KILLS_VER or 0) + 1
            end
            ZONES.learn(ep, floor, key)
            if rare_name then K.GAMELOG.note_rare_kill(rare_name, address, floor) end
            local death_x, death_z = K.entity_pos(address)
            recent_deaths[#recent_deaths + 1] = { frame = frame_counter, key = key, x = death_x, z = death_z }
            if #recent_deaths > 40 then
              table.remove(recent_deaths, 1)
            end
            if PENDING.resolve then PENDING.resolve(key) end
            if monster_id == 49 then
              dubwitch_death_frame = frame_counter
            end
          end
        end
      end
    end
  end
  local now_s = os.time()
  for boss_id, boss_key in pairs(BOSS.keys) do
    local st = BOSS.state[boss_id]
    if boss_seen_now[boss_id] then
      if st and st.floor ~= floor then st = nil end
      if not st then st = { floor = floor, counted = false } end
      st.last = now_s
      BOSS.state[boss_id] = st
    elseif st then
      if st.floor ~= floor then
        BOSS.state[boss_id] = nil
      elseif not st.counted and now_s - st.last >= (BOSS.gone_by_id[boss_id] or BOSS.gone_seconds)
        and not (BOSS.phases[boss_id] and not BOSS.main_entity[boss_id] and (st.deaths or 0) > 0) then
        st.counted = true
        local total_key = prefix .. boss_key
        kill_totals[total_key] = (kill_totals[total_key] or 0) + 1
        K.KC.session[total_key] = (K.KC.session[total_key] or 0) + 1
        kills_dirty = true
        K.KILLS_VER = (K.KILLS_VER or 0) + 1
        ZONES.learn(ep, floor, boss_key)
        recent_deaths[#recent_deaths + 1] = { frame = frame_counter, key = boss_key }
        if #recent_deaths > 40 then
          table.remove(recent_deaths, 1)
        end
        if PENDING.resolve then PENDING.resolve(boss_key) end
        set_status(T("boss_kill", boss_key))
      end
    end
  end
  if next(dubchic_seen) ~= nil then
    for address, _ in pairs(id0_now) do
      dubwitch_seen[address] = floor
    end
  end
  if next(dubchic_seen) ~= nil or next(dubwitch_seen) ~= nil then
    local others_prev, others_gone = 0, 0
    for address, _ in pairs(prev_present) do
      if not dubchic_seen[address] then
        others_prev = others_prev + 1
        if not present[address] then
          others_gone = others_gone + 1
        end
      end
    end
    local transition = (others_prev >= 3 and others_gone * 2 >= others_prev)
    local dubchic_key = KEYALIAS.resolve(rares_now, ep == 2 and "Dubchic E2" or "Dubchic")
    local dubwitch_key = KEYALIAS.resolve(rares_now, ep == 2 and "Dubwitch E2" or "Dubwitch")
    for address, seen_floor in pairs(dubwitch_seen) do
      if not present[address] then
        dubwitch_seen[address] = nil
        local counted = (seen_floor == floor) and not transition
        if counted then
          dubwitch_death_frame = frame_counter
          register_kill(prefix, ep, floor, dubwitch_key)
          for dub_address, dub_floor in pairs(dubchic_seen) do
            local counted_at = dubchic_dead[dub_address]
            if dub_floor == floor and (counted_at == nil or frame_counter - counted_at > K.DUBCHIC_RECOUNT_FRAMES) then
              dubchic_dead[dub_address] = frame_counter
              register_kill(prefix, ep, floor, dubchic_key)
            end
          end
        end
      end
    end
    for address, seen_floor in pairs(dubchic_seen) do
      if not present[address] then
        local already = (type(dubchic_dead[address]) == "number")
        dubchic_seen[address] = nil
        dubchic_dead[address] = nil
        local counted = (not already) and (seen_floor == floor) and not transition
        if counted then
          register_kill(prefix, ep, floor, dubchic_key)
          if frame_counter - dubwitch_death_frame > K.DUBWITCH_LINK_FRAMES then
            dubwitch_death_frame = frame_counter
            register_kill(prefix, ep, floor, dubwitch_key)
          end
        end
      end
    end
  end
  if next(K.SLIME_SEEN) ~= nil then
    local others_prev, others_gone = 0, 0
    for address in pairs(prev_present) do
      if not K.SLIME_SEEN[address] then
        others_prev = others_prev + 1
        if not present[address] then others_gone = others_gone + 1 end
      end
    end
    local slime_transition = others_prev >= 3 and others_gone * 2 >= others_prev
    for address, info in pairs(K.SLIME_SEEN) do
      if not present[address] then
        K.SLIME_SEEN[address] = nil
        local lived = frame_counter - info.frame
        if info.floor == floor and not slime_transition and not slain_entities[address] and lived >= K.SLIME_MIN_LIFE then
          local key = monster_chart_keys[info.id]
          if ep == 2 and episode2_variants[info.id] then key = key .. " E2" end
          register_kill(prefix, ep, floor, KEYALIAS.resolve(rares_now, key))
        end
      end
    end
  end
  if next(K.LILY_SEEN) ~= nil then
    local others_prev, others_gone = 0, 0
    for address in pairs(prev_present) do
      if not K.LILY_SEEN[address] then
        others_prev = others_prev + 1
        if not present[address] then others_gone = others_gone + 1 end
      end
    end
    local lily_transition = others_prev >= 3 and others_gone * 2 >= others_prev
    for address, info in pairs(K.LILY_SEEN) do
      if not present[address] then
        K.LILY_SEEN[address] = nil
        if info.floor == floor and not lily_transition and not slain_entities[address] and info.max > 0 and info.hp * 4 <= info.max then
          local key = monster_chart_keys[info.id]
          if ep == 2 and episode2_variants[info.id] then key = key .. " E2" end
          register_kill(prefix, ep, floor, KEYALIAS.resolve(rares_now, key))
        end
      end
    end
  end
  K.PRESENT_SPARE = prev_present
  prev_present = present
  for address, _ in pairs(alive_seen) do
    if not present[address] then
      alive_seen[address] = nil
    end
  end
  for address, _ in pairs(slain_entities) do
    if not present[address] then
      slain_entities[address] = nil
    end
  end
  for address, _ in pairs(K.RAREPOP.announced) do
    if not present[address] then
      K.RAREPOP.announced[address] = nil
    end
  end
end

local function update_kills()
  pcall(K.update_kills_body)
end

local function find_killed_monster(candidate_keys)
  if type(candidate_keys) ~= "table" or #candidate_keys == 0 then return nil end
  local allowed = {}
  for _, key in ipairs(candidate_keys) do
    allowed[key] = true
  end
  for i = #recent_deaths, 1, -1 do
    local death = recent_deaths[i]
    if allowed[death.key] and frame_counter - death.frame <= K.death_window(death.key) then
      return death.key
    end
  end
  for i = #recent_deaths, 1, -1 do
    local death = recent_deaths[i]
    if allowed[death.key] and frame_counter - death.frame <= math.max(PENDING.window, K.death_window(death.key)) then
      return death.key
    end
  end
  if #candidate_keys == 1 then
    return candidate_keys[1]
  end
  return nil
end

local function register_drop_kills(monster_key, item_name)
  if not monster_key then return nil end
  local prefix = kill_context_prefix()
  if not prefix then return nil end
  local total_key = prefix .. monster_key
  local mark_key = total_key .. "|" .. tostring(item_name)
  local rares_for_kills = KEYALIAS.rares_for_prefix(prefix)
  local total = KEYALIAS.total(prefix, monster_key, rares_for_kills)
  local kills = total - KEYALIAS.mark(prefix, monster_key, item_name, rares_for_kills)
  kill_marks[mark_key] = total
  kills_dirty = true
  K.KILLS_VER = (K.KILLS_VER or 0) + 1
  local display = monster_key
  local difficulty_index = tonumber(string.match(prefix, "^(%d+)|"))
  local enemies = load_module("Hunters Log.charts.Enemies")
  if enemies and difficulty_index and enemies[monster_key] and enemies[monster_key][difficulty_index + 1] then
    display = enemies[monster_key][difficulty_index + 1]
  end
  if kills <= 0 then return nil end
  return kills, display
end

PENDING.resolve = function(death_key)
  local i = 1
  while i <= #PENDING.list do
    local p = PENDING.list[i]
    if frame_counter - p.frame > PENDING.window then
      table.remove(PENDING.list, i)
    elseif p.keys[death_key] and not p.entry.kills then
      local kills, display = register_drop_kills(death_key, p.name)
      if kills then
        p.entry.kills = kills
        p.entry.kills_monster = display
        p.entry.kills_expected = p.odds and p.odds[death_key] or nil
        K.HIST_REV = K.HIST_REV + 1
        save_data()
      end
      table.remove(PENDING.list, i)
    else
      i = i + 1
    end
  end
end

local whitelisted_items = K.DATA_FILTERS.whitelisted_items
K.BLACKLIST_MEMO = {}

local function is_blacklisted(name)
  if not name then return true end
  local memo = K.BLACKLIST_MEMO[name]
  if memo ~= nil then return memo end
  local result = false
  local lower_name = string.lower(name)
  if string.find(name, "[\128-\255]") then
    result = true
  elseif whitelisted_items[lower_name] or K.VR.names[K.VR.key(name)] or K.VR.rules[K.VR.key(name)] then
    result = false
  elseif blacklisted_items[lower_name] then
    result = true
  else
    for _, pattern in ipairs(blacklisted_patterns) do
      if string.find(lower_name, pattern, 1, true) then
        result = true
        break
      end
    end
  end
  K.BLACKLIST_MEMO[name] = result
  return result
end

local function extract_item_stats(item)
  if not item then return "N/A" end
  local parts = {}
  if item.weapon then
    if item.weapon.untekked then
      table.insert(parts, "[UNTEKKED - À identifier]")
    end
    if item.weapon.grind and item.weapon.grind > 0 then
      table.insert(parts, "+" .. tostring(item.weapon.grind))
    end
    if item.weapon.stats then
      local st = item.weapon.stats
      table.insert(parts, string.format("[%d/%d/%d/%d|%d]",
      st[2] or 0, st[3] or 0, st[4] or 0, st[5] or 0, st[6] or 0))
    end
  elseif item.armor then
    if item.armor.dfp or item.armor.evp then
      local def_str = string.format("[DFP: +%d | EVP: +%d]", item.armor.dfp or 0, item.armor.evp or 0)
      table.insert(parts, def_str)
    end
    if item.armor.slots then
      table.insert(parts, string.format("[%dS]", item.armor.slots))
    end
  end
  if #parts == 0 then
    return "Sans attributs particuliers"
  end
  return table.concat(parts, " ")
end

local inventory_last_seen = {}
K.INV_FIRST_SEEN = {}
K.INV_FIRST_READ = false
K.KNOWN_INVENTORY_SECONDS = 300

local function refresh_inventory_ids()
  local ok, inventory = pcall(lib_items.GetInventory, lib_items.Me)
  if not ok or type(inventory) ~= "table" or type(inventory.items) ~= "table" then
    return
  end
  local now = os.time()
  local initial = not K.INV_FIRST_READ
  K.INV_FIRST_READ = true
  for _, inv_item in ipairs(inventory.items) do
    if inv_item.id then
      local id = tostring(inv_item.id)
      inventory_last_seen[id] = now
      if K.INV_FIRST_SEEN[id] == nil then
        K.INV_FIRST_SEEN[id] = initial and 0 or now
      end
    end
  end
end

local function was_in_inventory(id)
  local last = inventory_last_seen[tostring(id)]
  return last ~= nil and (os.time() - last) <= K.KNOWN_INVENTORY_SECONDS
end

K.DUPLICATE_WINDOW_SECONDS = 1200
local floor_keys_now = {}

local function has_recent_death(candidate_keys)
  if type(candidate_keys) ~= "table" or #candidate_keys == 0 then return false end
  local allowed = {}
  for _, key in ipairs(candidate_keys) do
    allowed[key] = true
  end
  for i = #recent_deaths, 1, -1 do
    local death = recent_deaths[i]
    if allowed[death.key] and K.death_ok(death) then return true end
  end
  return false
end

local function inventory_key_set()
  local set = {}
  local ok, inventory = pcall(lib_items.GetInventory, lib_items.Me)
  if ok and type(inventory) == "table" and type(inventory.items) == "table" then
    for _, inv_item in ipairs(inventory.items) do
      if inv_item.id then
        set["floor_" .. tostring(inv_item.id)] = true
      end
    end
  end
  return set
end

local function find_counted_duplicate(display_name, stats_text, section_label, now)
  local current_section = section_key(section_label)
  local inventory = nil
  for i = #drop_history, 1, -1 do
    local h = drop_history[i]
    if now - (tonumber(h.time) or 0) > K.DUPLICATE_WINDOW_SECONDS then break end
    local details = h.key and item_details[h.key] or nil
    if h.name == display_name and details and details.stats == stats_text then
      local old_id = string.match(tostring(h.key), "^(floor_%d+)_")
      if old_id then
        inventory = inventory or inventory_key_set()
        local vanished = not floor_keys_now[old_id] and not inventory[old_id]
        local section_changed = current_section ~= nil and section_key(h.section) ~= current_section
        if vanished or section_changed then
          return h
        end
      end
    end
  end
  return nil
end

function K.POPUP.push(entry, stats_text, force, wclass)
  local cfg = K.POPUP.cfg
  if not entry then return end
  local vr = (entry.kind == "weapon" and K.VR.hit_ok(entry.name, stats_text)) or nil
  if not force then
    if not cfg.enabled then return end
    local category = vr and "veryrare" or item_category(entry.kind, entry.name)
    if cfg.kinds[category] == false then return end
  end
  local queue = K.POPUP.queue
  queue[#queue + 1] = { name = entry.name, kind = entry.kind, wclass = wclass, rate = entry.rate, section = entry.section, stats = stats_text, vr = vr }
  while #queue > 6 do table.remove(queue, 1) end
end

K.POPUP.preview_armor = {
  name = "Dragon Frame", kind = "armor", wclass = "armor", rate = "1/2048", section = "Bluefull",
  stats = "[DFP: +14 | EVP: +10] [4S]",
}

K.POPUP.preview_melee = {
  name = "Test (corps a corp)", kind = "weapon", wclass = "melee", rate = "1/311", section = "Bluefull",
  stats = "+5 [35/0/0/0|20]",
}

K.POPUP.preview_rod = {
  name = "Test (baton)", kind = "weapon", wclass = "rod", rate = "1/311", section = "Bluefull",
  stats = "[0/0/0/50|0]",
}

K.POPUP.preview_barrier = {
  name = "Red Ring", kind = "armor", wclass = "barrier", rate = "1/2048", section = "Bluefull",
  stats = "[DFP: +80 | EVP: +25]",
}

K.POPUP.preview_veryrare = {
  name = "Heaven Punisher", kind = "weapon", wclass = "gun", rate = "1/4096", section = "Bluefull",
  stats = "+0 [0/0/0/0|0]",
}

K.POPUP.samples = { K.POPUP.preview_entry, K.POPUP.preview_melee, K.POPUP.preview_rod, K.POPUP.preview_armor, K.POPUP.preview_barrier, K.POPUP.preview_veryrare }
K.POPUP.weapon_icon_index = { melee = 1, rod = 2, gun = 3 }
K.POPUP.armor_icon_index = { barrier = 1, armor = 2 }
K.DATA_WEAPONS = K.ITEM_DATA.weapon_types
K.POPUP.GUN_NAMES = K.DATA_WEAPONS.gun
K.POPUP.ROD_NAMES = K.DATA_WEAPONS.rod
K.POPUP.NAME_CLASS = {}

for _, n in ipairs(K.POPUP.GUN_NAMES) do K.POPUP.NAME_CLASS[n] = "gun" end

for _, n in ipairs(K.POPUP.ROD_NAMES) do K.POPUP.NAME_CLASS[n] = "rod" end

function K.POPUP.item_class(item, shown_name, kind)
  local names = { string.lower(tostring(shown_name or "")), string.lower(tostring(type(item) == "table" and item.name or "")) }
  local function trimmed(text)
    text = string.gsub(text, "^%s+", "")
    return (string.gsub(text, "%s+$", ""))
  end
  local function word(name, w) return string.find(name, "%f[%w]" .. w .. "%f[%W]") ~= nil end
  if kind == "armor" then
    if type(item) == "table" then
      local d1, d2
      if type(item.data) == "table" then
        d1, d2 = tonumber(item.data[1]), tonumber(item.data[2])
      elseif tonumber(item.hex) then
        d1, d2 = math.floor(item.hex / 65536) % 256, math.floor(item.hex / 256) % 256
      end
      if d1 == 1 and d2 == 2 then return "barrier" end
      if d1 == 1 and d2 == 1 then return "armor" end
    end
    for _, name in ipairs(names) do
      if word(name, "barrier") or word(name, "shield") or word(name, "merge") then return "barrier" end
    end
    return nil
  end
  for _, name in ipairs(names) do
    name = trimmed(name)
    if K.POPUP.NAME_CLASS[name] then return K.POPUP.NAME_CLASS[name] end
  end
  for _, name in ipairs(names) do
    if word(name, "handgun") or word(name, "rifle") or word(name, "mechgun") then return "gun" end
    if word(name, "cane") or word(name, "rod") or word(name, "wand") then return "rod" end
  end
  return nil
end

function K.POPUP.test(sample)
  local P = K.POPUP
  if not sample then
    P.test_index = (P.test_index or 0) % #P.samples + 1
    sample = P.samples[P.test_index]
  end
  P.push(sample, sample.stats, true, sample.wclass)
end

function K.POPUP.push_rare(name, zone, force)
  local cfg = K.POPUP.cfg
  if not force and not cfg.rare_enabled then return end
  local queue = K.POPUP.queue
  queue[#queue + 1] = { name = name, kind = "rare_monster", rare = true, line2 = zone }
  while #queue > 6 do table.remove(queue, 1) end
end

K.POPUP.rare_samples = {
  { "Al Rappy", "Forest 1" }, { "Hildeblue", "Caves 2" }, { "Pouilly Slime", "Seabed Upper" },
}

function K.POPUP.test_rare()
  local P = K.POPUP
  P.rare_test_index = (P.rare_test_index or 0) % #P.rare_samples + 1
  local sample = P.rare_samples[P.rare_test_index]
  P.push_rare(loc(sample[1]), loc(sample[2]), true)
end

K.WAITING = {}
K.ITEM_POLL_FRAMES = 2
K.FLOOR_KEYS = {}
K.FLOOR_KEYS_COUNT = 0

function K.floor_key(raw_id)
  local key = K.FLOOR_KEYS[raw_id]
  if not key then
    if K.FLOOR_KEYS_COUNT > 3000 then
      K.FLOOR_KEYS = {}
      K.FLOOR_KEYS_COUNT = 0
    end
    key = "floor_" .. tostring(raw_id)
    K.FLOOR_KEYS[raw_id] = key
    K.FLOOR_KEYS_COUNT = K.FLOOR_KEYS_COUNT + 1
  end
  return key
end

function K.recent_death_in_set(set)
  for i = #recent_deaths, 1, -1 do
    local death = recent_deaths[i]
    if set[death.key] and K.death_ok(death) then return true end
  end
  return false
end

K.SERVER_ID_BASE = 0x810000
K.COUNTED_IDS = {}
K.FORCED = {}

local function process_floor_item(item)
  if not item or not item.name then return end
  local item_name = item.name
  local raw_id = item.id or item.index or item_name
  local item_key = K.floor_key(raw_id)
  if seen_items[item_key] then return end
  local my_floor = get_current_floor()
  local remote_floor = (type(item.floorNumber) == "number" and my_floor and item.floorNumber ~= my_floor)
    and item.floorNumber or nil
  local waiting_entry = K.WAITING[item_key]
  if waiting_entry and waiting_entry.set and not K.recent_death_in_set(waiting_entry.set) then
    if not K.FORCED[item_key] then
      return
    end
  end
  if item.mag then
    seen_items[item_key] = true
    return
  end
  if K.COMMON.enabled and K.COMMON.is_name(item_name) then
    if not K.COMMON.accepts(item) then return end
  elseif is_blacklisted(item_name) then
    return
  end
  do
    seen_items[item_key] = true
    local item_floor = remote_floor or my_floor
    if item_floor == 0 then
      return
    end
    local num_id = tonumber(item.id)
    if num_id and not waiting_entry and not K.FORCED[item_key] then
      if num_id < K.SERVER_ID_BASE then
        return
      end
      if K.PREV_MAX_SRV_ID and num_id < K.PREV_MAX_SRV_ID then
        return
      end
      local counted = K.COUNTED_IDS[item_name]
      if counted then
        local ok_players, players = pcall(pso.read_u32, K.PLAYER_COUNT_ADDR)
        local window = ok_players and type(players) == "number" and players - 1 or 0
        if window >= 1 and window <= 3 then
          for _, counted_id in ipairs(counted) do
            if counted_id ~= num_id and math.abs(counted_id - num_id) <= window then
              return
            end
          end
        end
      end
    end
    -- Non-weapon item (Cell of Mag, armor, unit, misc...) that was in our own inventory a moment ago:
    -- the player put it down himself, it is not a drop. (Weapons have their own check below.)
    if not item.weapon and not K.FORCED[item_key] and was_in_inventory(item.id) then
      return
    end
    -- Rare weapons are never dropped with grind or already identified: such an item was dropped by a player.
    -- Common weapons can legitimately drop with grind and already identified (items dropped by players are already filtered by their ID).
    if item.weapon and not K.COMMON.is_name(item_name) and (((item.weapon.grind or 0) > 0)
      or (item.weapon.untekked == false and not was_in_inventory(item.id))) then
      return
    end
    local display_name = item_name
    if K.COMMON.enabled and K.COMMON.is_name(item_name) then
      display_name = K.COMMON.full_name(item)
      if K.COMMON.report_text then
        set_status(K.COMMON.report_text, true)
        K.COMMON.report_text = nil
      end
    elseif string.find(display_name, "%?") then
      display_name = "Special Weapon (Untekted)"
    end
    local now = os.time()
    local zone_name = get_current_zone()
    if remote_floor then
      local floors = floor_names[episode] or floor_names[1]
      zone_name = floors[remote_floor] or ("Etage " .. tostring(remote_floor))
    end
    local difficulty_label, section_label = get_game_context()
    local source, rate, drr, dar, rer, rare, candidate_keys = find_drop_source(item_name, item_floor, item.weapon ~= nil)
    if source == K.IMPOSSIBLE then
      K.WAITING[item_key] = nil
      return
    end
    if remote_floor and not item.weapon and (source == nil or source == "Inconnu") then
      return
    end
    if not remote_floor and type(candidate_keys) == "table" and candidate_keys.box and not has_recent_death(candidate_keys) then
      source, rate, rare = candidate_keys.box.name, candidate_keys.box.rate, nil
      candidate_keys = nil
    end
    if not remote_floor and type(candidate_keys) == "table" and #candidate_keys > 0
      and not has_recent_death(candidate_keys) and not K.FORCED[item_key] then
      seen_items[item_key] = nil
      if not K.WAITING[item_key] then
        local window = PENDING.window
        local set = {}
        for _, candidate in ipairs(candidate_keys) do
          window = math.max(window, K.death_window(candidate))
          set[candidate] = true
        end
        K.WAITING[item_key] = { item = item, keys = candidate_keys, frame = frame_counter, window = window, set = set }
      end
      set_status(T("no_death_yet", display_name))
      return
    end
    K.WAITING[item_key] = nil
    local pick_record, pick_state
    if not remote_floor then pick_record, pick_state = K.pick_death(candidate_keys, item, display_name) end
    if pick_state == "duplicate" and not K.FORCED[item_key] then
      set_status(T("duplicate_ignored", display_name))
      return
    end
    if pick_state == "far" and not K.FORCED[item_key] then
      set_status(T("drop_far", display_name), true)
      return
    end
    local stats_text = extract_item_stats(item)
    if not has_recent_death(candidate_keys) and find_counted_duplicate(display_name, stats_text, section_label, now) then
      set_status(T("duplicate_ignored", display_name))
      return
    end
    K.FORCED[item_key] = nil
    total_global = total_global + 1
    K.claim_death(pick_record, display_name)
    local killed_key = nil
    if not remote_floor then
      killed_key = pick_record and pick_record.key or find_killed_monster(candidate_keys)
    elseif type(candidate_keys) == "table" and #candidate_keys > 0 then
      for _, candidate in ipairs(candidate_keys) do
        if candidate == source then killed_key = candidate break end
      end
      killed_key = killed_key or find_killed_monster(candidate_keys)
    end
    local kills, kills_monster = register_drop_kills(killed_key, display_name)
    local kills_expected = nil
    if kills and killed_key and type(candidate_keys) == "table" and candidate_keys.odds then
      kills_expected = candidate_keys.odds[killed_key]
    end
    local pending_keys = nil
    if not remote_floor and not kills and type(candidate_keys) == "table" and #candidate_keys > 0 then
      pending_keys = {}
      for _, candidate in ipairs(candidate_keys) do pending_keys[candidate] = true end
    end
    local kind = classify_item(item, display_name)
    local detail_key = nil
    if not no_detail_items[string.lower(display_name)] then
      detail_key = item_key .. "_" .. tostring(now)
      item_details[detail_key] = {
        name = display_name,
        stats = stats_text,
        zone = zone_name,
        difficulty = difficulty_label,
        section = section_label,
        source = source,
        item_id = tostring(item.id or ""),
        time = now
      }
    end
    item_counts[display_name] = (item_counts[display_name] or 0) + 1
    if not item_kinds[display_name] or kind ~= "other" then
      item_kinds[display_name] = kind
    end
    table.insert(drop_history, {
      time = now,
      name = display_name,
      kind = kind,
      zone = zone_name,
      difficulty = difficulty_label,
      section = section_label,
      source = source,
      rate = rate,
      drr = drr,
      dar = dar,
      rer = rer,
      rare = (rare ~= nil) or nil,
      kills = kills,
      kills_monster = kills_monster,
      kills_expected = kills_expected,
      key = detail_key,
    })
    if pending_keys then
      PENDING.list[#PENDING.list + 1] = {
        frame = frame_counter, entry = drop_history[#drop_history], name = display_name,
        keys = pending_keys, odds = candidate_keys.odds,
      }
    end
    if remote_floor then
      set_status("Drop hors etage : " .. tostring(display_name) .. " (" .. tostring(zone_name) .. ")")
    end
    do
      local counted_id = tonumber(item.id)
      if counted_id and counted_id >= K.SERVER_ID_BASE then
        local list = K.COUNTED_IDS[item_name]
        if not list then list = {}; K.COUNTED_IDS[item_name] = list end
        list[#list + 1] = counted_id
        if #list > 12 then table.remove(list, 1) end
      end
    end
    K.CAREER.on_drop(drop_history[#drop_history], stats_text)
    K.POPUP.push(drop_history[#drop_history], stats_text, false, K.POPUP.item_class(item, display_name, kind))
    K.HIST_REV = K.HIST_REV + 1
    K.trim_history()
    save_data()
    auto_save_data()
  end
end

local missing_since = {}
K.FORGET_AFTER_SECONDS = 30

local function prune_seen_items(on_floor)
  local now = os.time()
  local missing = {}
  for key, _ in pairs(seen_items) do
    if on_floor[key] then
      missing_since[key] = nil
    else
      table.insert(missing, key)
    end
  end
  if #missing == 0 then return end
  local ok, inventory = pcall(lib_items.GetInventory, lib_items.Me)
  if not ok or type(inventory) ~= "table" or type(inventory.items) ~= "table" then
    return
  end
  local in_inventory = {}
  for _, inv_item in ipairs(inventory.items) do
    if inv_item.id then
      in_inventory["floor_" .. tostring(inv_item.id)] = true
    end
  end
  for _, key in ipairs(missing) do
    if in_inventory[key] then
      missing_since[key] = nil
    elseif not missing_since[key] then
      missing_since[key] = now
    elseif now - missing_since[key] >= K.FORGET_AFTER_SECONDS then
      seen_items[key] = nil
      missing_since[key] = nil
    end
  end
end

local function track_items()
  if frame_counter % K.ITEM_POLL_FRAMES ~= 0 then return end
  if lib_items and type(lib_items.GetItemList) == "function" then
    local floor_items
    if type(lib_items.GetMultiFloorItemList) == "function" then
      local ok_multi, multi = pcall(lib_items.GetMultiFloorItemList, false)
      if ok_multi and type(multi) == "table" then floor_items = multi end
    end
    floor_items = floor_items or lib_items.GetItemList(lib_items.NoOwner, false)
    if floor_items then
      fix_item_names(floor_items)
      local on_floor = {}
      for _, item in pairs(floor_items) do
        if item.id then
          on_floor[K.floor_key(item.id)] = true
        end
      end
      floor_keys_now = on_floor
      local srv_count, cur_max = 0, 0
      for _, item in pairs(floor_items) do
        local n = tonumber(item.id)
        if n and n >= K.SERVER_ID_BASE then
          srv_count = srv_count + 1
          if n > cur_max then cur_max = n end
        end
      end
      K.PREV_MAX_SRV_ID = K.MAX_SRV_ID
      for _, item in pairs(floor_items) do
        process_floor_item(item)
      end
      if srv_count > 0 then
        K.EMPTY_SINCE = nil
        if not K.MAX_SRV_ID or cur_max > K.MAX_SRV_ID then K.MAX_SRV_ID = cur_max end
      else
        K.EMPTY_SINCE = K.EMPTY_SINCE or os.time()
        local quest_game = K.GAMELOG and K.GAMELOG.games[1]
        if os.time() - K.EMPTY_SINCE >= 15 and not (quest_game and not quest_game.ended) then K.MAX_SRV_ID = nil end
      end
      for waiting_key, waiting in pairs(K.WAITING) do
        if frame_counter - waiting.frame > waiting.window then
          K.WAITING[waiting_key] = nil
          if on_floor[waiting_key] then seen_items[waiting_key] = true end
        elseif not on_floor[waiting_key] and has_recent_death(waiting.keys) then
          process_floor_item(waiting.item)
          K.WAITING[waiting_key] = nil
        end
      end
      if frame_counter % 30 == 0 then
        prune_seen_items(on_floor)
      end
    end
  end
end

local function is_pending(details)
  return string.find(details.stats or "", "UNTEKKED", 1, true) ~= nil
end

K.TEKK_PREV = {}
K.TEKK_NEW = {}
K.TEKK_STATE = {}
K.TEKK_LOST_WINDOW = 900

function K.in_current_game(details)
  local game = K.GAMELOG and K.GAMELOG.games[1]
  if not game or not game.start then return true end
  return (tonumber(details.time) or 0) >= game.start - 5 or details.adopted == game.start
end

function K.adopt_old_pending(items)
  local game = K.GAMELOG and K.GAMELOG.games[1]
  if not game or not game.start then return end
  local olds = {}
  local tracked = {}
  for _, d in pairs(item_details) do
    if is_pending(d) then
      if K.in_current_game(d) then
        if d.item_id then tracked[tostring(d.item_id)] = true end
      else
        olds[#olds + 1] = d
      end
    end
  end
  if #olds == 0 then return end
  table.sort(olds, function(a, b) return (tonumber(a.time) or 0) < (tonumber(b.time) or 0) end)
  local function signature_of_details(d)
    local stats = tostring(d.stats or "")
    local grind = tonumber(string.match(stats, "%+(%d+)")) or 0
    local n, a, m, dk = string.match(stats, "%[(%d+)/(%d+)/(%d+)/(%d+)|%-?%d+%]")
    if not n then return nil end
    return grind .. ":" .. n .. ":" .. a .. ":" .. m .. ":" .. dk
  end
  for _, item in ipairs(items) do
    local weapon = item.weapon
    if weapon and weapon.untekked ~= false and item.id and weapon.stats and not tracked[tostring(item.id)] then
      local st = weapon.stats
      local signature = (tonumber(weapon.grind) or 0) .. ":" .. (st[2] or 0) .. ":" .. (st[3] or 0) .. ":" .. (st[4] or 0) .. ":" .. (st[5] or 0)
      for index, d in ipairs(olds) do
        local same_name = (d.name == item.name) or (d.name == "Special Weapon (Untekted)")
          or (K.COMMON.is_name(d.name) and K.COMMON.is_name(item.name) and K.COMMON.base(d.name) == K.COMMON.base(item.name))
        if same_name and signature_of_details(d) == signature then
          d.item_id = tostring(item.id)
          d.adopted = game.start
          table.remove(olds, index)
          break
        end
      end
    end
  end
end

local function update_tekked_stats()
  local now = os.time()
  local TEKKED_REFRESH_WINDOW = 120
  local PENDING_REFRESH_WINDOW = math.huge
  local function window_of(details)
    return is_pending(details) and PENDING_REFRESH_WINDOW or TEKKED_REFRESH_WINDOW
  end
  local needs_work = false
  local key_id_memo = K.TEKK_KEY_ID
  if not key_id_memo then
    key_id_memo = {}
    K.TEKK_KEY_ID = key_id_memo
  end
  for key, details in pairs(item_details) do
    local key_id = key_id_memo[key]
    if key_id == nil then
      key_id = string.match(tostring(key), "^floor_(%d+)_") or false
      key_id_memo[key] = key_id
    end
    if key_id and details.item_id ~= key_id and not (details.adopted and K.in_current_game(details)) then
      details.item_id = key_id
    end
    local recent = now - (tonumber(details.time) or 0) <= window_of(details)
    if not recent then
      details.refresh = nil
    elseif details.refresh or is_pending(details) then
      needs_work = true
    end
  end
  if not needs_work then
    K.TEKK_PREV = nil
    return
  end
  local ok, inventory = pcall(lib_items.GetInventory, lib_items.Me)
  if not ok or type(inventory) ~= "table" or type(inventory.items) ~= "table" then
    return
  end
  fix_item_names(inventory.items)
  K.adopt_old_pending(inventory.items)
  local newest_time_by_id = {}
  local newest_detail_by_id = {}
  for _, d in pairs(item_details) do
    local id = tostring(d.item_id or "")
    local t = tonumber(d.time) or 0
    if id ~= "" and t > (newest_time_by_id[id] or 0) then
      newest_time_by_id[id] = t
      newest_detail_by_id[id] = d
    end
  end
  local changed = false
  local updated_names = {}
  local inv_weapon_by_id = {}
  for _, item in ipairs(inventory.items) do
    if item.weapon and item.id then inv_weapon_by_id[tostring(item.id)] = item end
  end
  for detail_key, details in pairs(item_details) do
    local inv_id = details.item_id
    local item = inv_id ~= nil and inv_weapon_by_id[inv_id] or nil
    if item then
      local recent = now - (tonumber(details.time) or 0) <= window_of(details)
      local is_newest = (tonumber(details.time) or 0) >= (newest_time_by_id[inv_id] or 0)
      if recent and is_newest and K.in_current_game(details) then
        local same_name = (details.name == item.name) or (details.name == "Special Weapon (Untekted)")
        or (K.COMMON.is_name(details.name) and K.COMMON.is_name(item.name)
        and K.COMMON.base(details.name) == K.COMMON.base(item.name))
        if same_name then
          local tekked_now = (item.weapon.untekked == false)
          if details.refresh or (is_pending(details) and tekked_now) then
            details.stats = extract_item_stats(item)
            details.refresh = nil
            K.COMMON.rename_after_tekk(detail_key, item, item_details, drop_history, item_counts, item_kinds)
            changed = true
            updated_names[#updated_names + 1] = tostring(item.name)
          end
        end
      end
    end
  end
  local inv_by_id = {}
  for _, item in ipairs(inventory.items) do
    if item.id then
      inv_by_id[tostring(item.id)] = item
      if K.INV_FIRST_SEEN[tostring(item.id)] == nil then K.INV_FIRST_SEEN[tostring(item.id)] = now end
    end
  end
  local function appeared_after(details, id)
    local first = K.INV_FIRST_SEEN[tostring(id)]
    return first == nil or first >= (tonumber(details.time) or 0) - 5
  end
  local function names_match(details, item)
    return details.name == item.name or details.name == "Special Weapon (Untekted)"
    or item.name == "Special Weapon (Untekted)" or details.name == K.COMMON.full_name(item)
    or (K.COMMON.is_name(details.name) and K.COMMON.is_name(item.name)
    and K.COMMON.base(details.name) == K.COMMON.base(item.name))
  end
  local function is_tracked(details)
    local did = details.item_id and tostring(details.item_id) or ""
    return did ~= "" and is_pending(details) and (tonumber(details.time) or 0) >= (newest_time_by_id[did] or 0)
      and K.in_current_game(details)
  end
  local function apply_match(key, item)
    local details = item_details[key]
    details.stats = extract_item_stats(item)
    K.COMMON.rename_after_tekk(key, item, item_details, drop_history, item_counts, item_kinds)
    details.item_id = tostring(item.id)
    details.refresh = nil
    K.TEKK_STATE[key] = nil
    K.TEKK_NEW[tostring(item.id)] = nil
    changed = true
    updated_names[#updated_names + 1] = tostring(item.name)
  end
  for key, details in pairs(item_details) do
    if not is_pending(details) then
      K.TEKK_STATE[key] = nil
    elseif is_tracked(details) then
      local inv_item = inv_by_id[tostring(details.item_id)]
      local state = K.TEKK_STATE[key]
      if inv_item then
        if inv_item.weapon and inv_item.weapon.untekked ~= false and names_match(details, inv_item) then
          K.TEKK_STATE[key] = { seen = true }
        elseif state then
          K.TEKK_STATE[key] = nil
        end
      elseif state and state.seen and not state.lost_at then
        state.lost_at = now
      end
    end
  end
  for key in pairs(K.TEKK_STATE) do
    if not item_details[key] then K.TEKK_STATE[key] = nil end
  end
  if K.TEKK_PREV then
    for id, item in pairs(inv_by_id) do
      if item.weapon and item.weapon.untekked == false and not K.TEKK_NEW[id] then
        local before = K.TEKK_PREV[id]
        if before == nil or before == "u" then
          local newest = newest_detail_by_id[id]
          local fresh_drop = newest and not is_pending(newest) and now - (tonumber(newest.time) or 0) <= K.TEKK_LOST_WINDOW
          if not fresh_drop then K.TEKK_NEW[id] = now end
        end
      end
    end
  end
  for id, t in pairs(K.TEKK_NEW) do
    local item = inv_by_id[id]
    if not item or not item.weapon or item.weapon.untekked ~= false or now - t > K.TEKK_LOST_WINDOW then
      K.TEKK_NEW[id] = nil
    end
  end
  for id in pairs(K.TEKK_NEW) do
    local item = inv_by_id[id]
    local best_key, best_lost = nil, nil
    for key, details in pairs(item_details) do
      local state = K.TEKK_STATE[key]
      if state and state.lost_at and now - state.lost_at <= K.TEKK_LOST_WINDOW
        and is_tracked(details) and names_match(details, item) and appeared_after(details, id) and not item.equipped
        and (not best_lost or state.lost_at < best_lost) then
        best_key, best_lost = key, state.lost_at
      end
    end
    if best_key then apply_match(best_key, item) end
  end
  do
    local fresh_by_name = {}
    for id in pairs(K.TEKK_NEW) do
      local item = inv_by_id[id]
      fresh_by_name[item.name] = fresh_by_name[item.name] or {}
      table.insert(fresh_by_name[item.name], item)
    end
    for _, items in pairs(fresh_by_name) do
      if #items == 1 then
        local candidates = {}
        for key, details in pairs(item_details) do
          local did = details.item_id and tostring(details.item_id)
          if is_tracked(details) and not inv_by_id[did] and names_match(details, items[1])
            and appeared_after(details, items[1].id) and not items[1].equipped
            and now - (tonumber(details.time) or 0) <= 21600 then
            table.insert(candidates, key)
          end
        end
        if #candidates == 1 then apply_match(candidates[1], items[1]) end
      end
    end
  end
  local snapshot = {}
  for id, item in pairs(inv_by_id) do
    snapshot[id] = (item.weapon and item.weapon.untekked ~= false) and "u" or "t"
  end
  K.TEKK_PREV = snapshot
  if changed then
    K.HIST_REV = K.HIST_REV + 1
    save_data()
    if #updated_names > 0 then
      set_status(T("tekk_updated", table.concat(updated_names, ", ")))
    end
  end
end

local function open_export_file(name)
  local exportDir = addonDir .. "exports/"
  pcall(function() pso.create_directory(exportDir) end)
  local filename = exportDir .. name
  local file = io.open(filename, "w")
  if not file then
    filename = addonDir .. name
    file = io.open(filename, "w")
  end
  return file, filename
end

local function export_to_file()
  local file, filename = open_export_file("item_stats_export.txt")
  if file then
    file:write(T("export_title") .. "\n")
    file:write(T("export_total", total_global) .. "\n\n")
    local sorted_counts = {}
    for name, count in pairs(item_counts) do
      table.insert(sorted_counts, { name = name, count = count })
    end
    table.sort(sorted_counts, function(a, b) return a.name < b.name end)
    file:write(T("export_summary") .. "\n")
    for _, entry in ipairs(sorted_counts) do
      file:write(string.format("%s : x%d\n", entry.name, entry.count))
    end
    local history_by_key = {}
    for _, h in ipairs(drop_history) do
      if h.key then history_by_key[h.key] = h end
    end
    local sorted_details = {}
    local hist_of = {}
    for key, details in pairs(item_details) do
      if not no_detail_items[string.lower(details.name or "")] then
        hist_of[details] = history_by_key[key]
        table.insert(sorted_details, details)
      end
    end
    table.sort(sorted_details, function(a, b)
      if a.name == b.name then
        if (a.time or 0) ~= (b.time or 0) then
          return (a.time or 0) < (b.time or 0)
        end
        return (a.stats or "") < (b.stats or "")
      end
      return a.name < b.name
    end)
    file:write("\n" .. T("export_detail") .. "\n")
    file:write(T("export_columns") .. "\n")
    for _, details in ipairs(sorted_details) do
      local stats = tostring(details.stats or "N/A")
      stats = string.gsub(stats, "%[UNTEKKED[^%]]*%]", "[UNTEKKED]")
      local h = hist_of[details]
      local rate_text = "-"
      if h and h.rate and h.rate ~= "" then
        rate_text = h.rate
        local bonus = {}
        if tonumber(h.dar) then
          bonus[#bonus + 1] = "DAR " .. tostring(math.floor(tonumber(h.dar) + 0.5)) .. "%"
        end
        if tonumber(h.drr) then
          bonus[#bonus + 1] = "RDR " .. tostring(math.floor(tonumber(h.drr) + 0.5)) .. "%"
        end
        if h.rare and tonumber(h.rer) then
          bonus[#bonus + 1] = "RER " .. tostring(math.floor(tonumber(h.rer) + 0.5)) .. "%"
        end
        if #bonus > 0 then
          rate_text = rate_text .. " (" .. table.concat(bonus, " / ") .. ")"
        end
      end
      local kills_text = (h and tonumber(h.kills)) and tostring(math.floor(tonumber(h.kills))) or "-"
      file:write(string.format("- %s | %s | %s | %s | %s | %s | %s | %s | %s\n",
      details.name or loc("Inconnu"), fmt_date(details.time), loc(details.difficulty or "Inconnue"), loc(details.section or "Inconnu"),
      loc(details.zone or "Inconnue"), loc(details.source or "Inconnu"), stats, rate_text, kills_text))
    end
    file:close()
    return filename
  end
  return nil
end

local function clip(text, max_len)
  text = tostring(text or "")
  if not string.find(text, "[\128-\255]") then
    if string.len(text) > max_len then
      return string.sub(text, 1, max_len - 1) .. "~"
    end
    return text
  end
  local width, stops, i, n = 0, {}, 1, string.len(text)
  while i <= n do
    local b = string.byte(text, i)
    local len = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
    width = width + ((len >= 3) and 2 or 1)
    stops[#stops + 1] = { i + len - 1, width }
    i = i + len
  end
  if width <= max_len then return text end
  local cut = 0
  for _, stop in ipairs(stops) do
    if stop[2] <= max_len - 1 then cut = stop[1] else break end
  end
  return string.sub(text, 1, cut) .. "~"
end

local function fmt_pct(value)
  local number = tonumber(value)
  if not number then return "?" end
  return tostring(math.floor(number + 0.5)) .. "%"
end

local function cycle_filter(list, current, step)
  local idx = 0
  for i, value in ipairs(list) do
    if value == current then
      idx = i
      break
    end
  end
  idx = (idx + step) % (#list + 1)
  if idx == 0 then return nil end
  return list[idx]
end

local heat_stops = K.UI_DATA.heat_stops

local function heat_color(value)
  value = math.max(0, math.min(100, tonumber(value) or 0))
  for i = 2, #heat_stops do
    local a, b = heat_stops[i - 1], heat_stops[i]
    if value <= b[1] then
      local t = (value - a[1]) / (b[1] - a[1])
      return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
    end
  end
  local last = heat_stops[#heat_stops]
  return last[2], last[3], last[4]
end

local function parse_weapon_stats(stats)
  stats = tostring(stats or "")
  local n, a, m, d, h = string.match(stats, "%[(%-?%d+)/(%-?%d+)/(%-?%d+)/(%-?%d+)|(%-?%d+)%]")
  if not n then return nil end
  local grind = tonumber(string.match(stats, "%+(%d+)")) or 0
  return grind, { tonumber(n), tonumber(a), tonumber(m), tonumber(d), tonumber(h) }
end

local function draw_weapon_stats(grind, values)
  local hovered = false
  if grind and grind > 0 then
    imgui.Text("+" .. tostring(grind))
    hovered = hovered or imgui.IsItemHovered()
    imgui.SameLine(0, 4)
  end
  imgui.Text("[")
  hovered = hovered or imgui.IsItemHovered()
  for i = 1, 5 do
    imgui.SameLine(0, 0)
    local r, g, b = heat_color(values[i])
    imgui.TextColored(r, g, b, 1, tostring(values[i]))
    hovered = hovered or imgui.IsItemHovered()
    imgui.SameLine(0, 0)
    if i < 4 then
      imgui.Text("/")
    elseif i == 4 then
      imgui.Text("|")
    else
      imgui.Text("]")
    end
    hovered = hovered or imgui.IsItemHovered()
  end
  return hovered
end

local function draw_weapon_entry(grind, values, pending)
  local hovered = false
  if pending then
    imgui.TextColored(1, 0.2, 0.2, 1, "[U]")
    hovered = imgui.IsItemHovered()
    imgui.SameLine(0, 4)
  end
  return draw_weapon_stats(grind, values) or hovered
end

local PERFECT_ARMOR_STATS = K.ITEM_DATA.armor_stats

function K.armor_stat_segs(stats, name)
  if type(stats) ~= "string" then return nil end
  local dfp, evp = string.match(stats, "DFP:%s*%+(%d+)%s*|%s*EVP:%s*%+(%d+)")
  if not dfp or not evp then return nil end
  dfp, evp = tonumber(dfp), tonumber(evp)
  local limits = PERFECT_ARMOR_STATS[string.lower(tostring(name or ""))]
  local segs = {}
  local function add(value, maximum)
    if maximum ~= nil then
      local perfect = value == maximum
      segs[#segs + 1] = { "[" .. value .. "/" .. maximum .. "]", 1, perfect and 0.9 or 1, perfect and 0.2 or 1 }
    else
      segs[#segs + 1] = { "[" .. value .. "]", 1, 1, 1 }
    end
  end
  add(dfp, limits and limits.dfp or nil)
  segs[#segs + 1] = { " ", 1, 1, 1 }
  add(evp, limits and limits.evp or nil)
  local slots = tonumber(string.match(stats, "%[(%d+)S%]"))
  if slots then
    segs[#segs + 1] = { " ", 1, 1, 1 }
    if slots == 4 then
      segs[#segs + 1] = { "[4S]", 1.0, 0.9, 0.2 }
    else
      segs[#segs + 1] = { "[" .. slots .. "S]", 1, 1, 1 }
    end
  end
  return segs
end

local function draw_stats_cell(details)
  if not details then
    imgui.TextDisabled("-")
    return false
  end
  local pending = is_pending(details)
  local grind, values = parse_weapon_stats(details.stats)
  if values then
    return draw_weapon_entry(grind, values, pending)
  elseif pending then
    imgui.TextColored(1, 0.2, 0.2, 1, "[U]")
    return imgui.IsItemHovered()
  elseif not details.stats or details.stats == "" or details.stats == "N/A" or details.stats == "Sans attributs particuliers" then
    imgui.TextDisabled("-")
    return false
  end
  local dfp, evp = string.match(details.stats, "DFP:%s*%+(%d+)%s*|%s*EVP:%s*%+(%d+)")
  if dfp and evp then
    dfp, evp = tonumber(dfp), tonumber(evp)
    local item_name_key = string.lower(tostring(details.name or ""))
    local limits = PERFECT_ARMOR_STATS[item_name_key]
    local hovered = false
    local function draw_limit(value, maximum)
      local label
      if maximum ~= nil then
        label = "[" .. value .. "/" .. maximum .. "]"
        if value == maximum then
          imgui.TextColored(1.0, 0.9, 0.2, 1, label)
        else
          imgui.Text(label)
        end
      else
        label = "[" .. tostring(value) .. "]"
        imgui.Text(label)
      end
      hovered = hovered or imgui.IsItemHovered()
    end
    draw_limit(dfp, limits and limits.dfp or nil)
    imgui.SameLine(0, 4)
    draw_limit(evp, limits and limits.evp or nil)
    local slots = string.match(details.stats, "%[(%d+)S%]")
    if slots then
      imgui.SameLine(0, 4)
      if tonumber(slots) == 4 then
        imgui.TextColored(1.0, 0.9, 0.2, 1, "[4S]")
      else
        imgui.Text("[" .. slots .. "S]")
      end
      hovered = hovered or imgui.IsItemHovered()
    end
    return hovered
  end
  imgui.Text(clip(details.stats, 28))
  return imgui.IsItemHovered()
end

local counters_cache = nil
K.U.draw_stats_cell = draw_stats_cell

function K.draw_armor_entry(name, rec)
  local limits = PERFECT_ARMOR_STATS[string.lower(tostring(name or ""))]
  local function draw_limit(value, maximum)
    local label = maximum ~= nil and ("[" .. value .. "/" .. maximum .. "]") or ("[" .. value .. "]")
    if maximum ~= nil and value == maximum then
      imgui.TextColored(1.0, 0.9, 0.2, 1, label)
    else
      imgui.Text(label)
    end
  end
  draw_limit(rec.dfp, limits and limits.dfp or nil)
  imgui.SameLine(0, 4)
  draw_limit(rec.evp, limits and limits.evp or nil)
  if rec.slots and rec.slots > 0 then
    imgui.SameLine(0, 4)
    if rec.slots == 4 then
      imgui.TextColored(1.0, 0.9, 0.2, 1, "[4S]")
    else
      imgui.Text("[" .. rec.slots .. "S]")
    end
  end
end

local function consider_best(tbl, name, grind, v)
  local current = tbl[name]
  local sum = v[1] + v[2] + v[3] + v[4]
  if not current
    or v[5] > current.values[5]
    or (v[5] == current.values[5] and sum > current.sum) then
    tbl[name] = { grind = grind, values = v, sum = sum }
  end
end

local function rebuild_counters_cache()
  local last_seen, best, best_u, best_a = {}, {}, {}, {}
  local name_set = {}
  local id_counts, id_totals, id_unknown = {}, {}, 0
  for _, h in ipairs(drop_history) do
    last_seen[h.name] = h.time
    name_set[h.name] = true
    local d = h.key and item_details[h.key] or nil
    if d then
      local grind, v = parse_weapon_stats(d.stats)
      if v then
        consider_best(is_pending(d) and best_u or best, h.name, grind, v)
      else
        local adfp, aevp, aslots = K.parse_armor_stats(d.stats)
        if adfp then K.consider_best_armor(best_a, h.name, adfp, aevp, aslots) end
      end
    end
    local sid = section_key(h.section)
    if sid then
      id_counts[sid] = id_counts[sid] or {}
      id_counts[sid][h.name] = (id_counts[sid][h.name] or 0) + 1
      id_totals[sid] = (id_totals[sid] or 0) + 1
    else
      id_unknown = id_unknown + 1
    end
  end
  for _, rec in ipairs(K.ARCHIVE.list) do
    local sid = section_key(rec.section)
    if sid then
      id_counts[sid] = id_counts[sid] or {}
      id_counts[sid][rec.name] = (id_counts[sid][rec.name] or 0) + rec.n
      id_totals[sid] = (id_totals[sid] or 0) + rec.n
    else
      id_unknown = id_unknown + rec.n
    end
  end
  for name, rec in pairs(K.ARCHIVE.best) do consider_best(best, name, rec.grind, rec.values) end
  for name, rec in pairs(K.ARCHIVE.best_u) do consider_best(best_u, name, rec.grind, rec.values) end
  for name, rec in pairs(K.ARCHIVE.best_a) do K.consider_best_armor(best_a, name, rec.dfp, rec.evp, rec.slots) end
  local id_lists = {}
  for sid, counts in pairs(id_counts) do
    local list = {}
    for name, count in pairs(counts) do
      table.insert(list, { name = name, count = count, kind = item_kinds[name] or "other" })
    end
    table.sort(list, function(a, b)
      local ka = kind_order[item_category(a.kind, a.name)] or 99
      local kb = kind_order[item_category(b.kind, b.name)] or 99
      if ka ~= kb then return ka < kb end
      return string.lower(a.name) < string.lower(b.name)
    end)
    id_lists[sid] = list
  end
  local history_names = {}
  for name, _ in pairs(name_set) do
    table.insert(history_names, name)
  end
  table.sort(history_names, function(a, b) return string.lower(a) < string.lower(b) end)
  counters_cache = {
    count = #drop_history, frame = frame_counter, rev = K.HIST_REV,
    history_names = history_names,
    last_seen = last_seen, best = best, best_u = best_u, best_a = best_a,
    id_lists = id_lists, id_totals = id_totals, id_unknown = id_unknown,
  }
end

local function draw_reset_block()
  if confirm_reset and os.time() > confirm_reset_until then
    confirm_reset = false
  end
  if not confirm_reset then
    if imgui.Button(T("reset_button")) then
      confirm_reset = true
      confirm_reset_until = os.time() + K.CONFIRM_SECONDS
    end
  else
    imgui.TextColored(1, 0.5, 0.3, 1, T("reset_confirm", total_global))
    if imgui.Button(T("reset_cancel")) then
      confirm_reset = false
    end
    imgui.SameLine(0, 12)
    if imgui.Button(T("reset_yes")) then
      confirm_reset = false
      reset_all()
    end
  end
end

local function draw_delete_cell(item_name)
  if pending_delete_item == item_name and os.time() <= pending_delete_until then
    imgui.TextColored(1, 0.5, 0.3, 1, T("delete_confirm"))
    imgui.SameLine(0, 8)
    if imgui.Button(T("yes") .. "##delyes_" .. item_name) then
      pending_delete_item = nil
      delete_item(item_name)
    end
    imgui.SameLine(0, 4)
    if imgui.Button(T("no") .. "##delno_" .. item_name) then
      pending_delete_item = nil
    end
  else
    if imgui.Button("X##del_" .. item_name) then
      pending_delete_item = item_name
      pending_delete_until = os.time() + K.CONFIRM_SECONDS
    end
  end
end

local function tab_button(label, tab_id)
  local text = (current_tab == tab_id) and ("[" .. label .. "]") or label
  if imgui.Button(text .. "##tab_" .. tab_id) then
    current_tab = tab_id
  end
end

local function hover_full_text(full_text, shown_text)
  if full_text and full_text ~= "" and tostring(full_text) ~= shown_text and imgui.IsItemHovered() then
    imgui.BeginTooltip()
    imgui.Text(tostring(full_text))
    imgui.EndTooltip()
  end
end

local function split_slash_list(text)
  local list = {}
  local source = tostring(text or "")
  local start = 1
  while true do
    local first, last = string.find(source, " / ", start, true)
    if not first then
      list[#list + 1] = string.sub(source, start)
      break
    end
    list[#list + 1] = string.sub(source, start, first - 1)
    start = last + 1
  end
  return list
end

local function draw_source_tooltip(h, hovered)
  local source = tostring(h.source or "")
  if hovered == nil then hovered = imgui.IsItemHovered() end
  if source == "" or source == "Inconnu" or not hovered then return end
  local names = split_slash_list(source)
  local rates = split_slash_list(h.rate)
  if #names <= 1 and string.len(source) <= 17 and string.len(tostring(h.rate or "")) <= 16 then
    return
  end
  imgui.BeginTooltip()
  for index, name in ipairs(names) do
    local rate_text = (#rates == #names) and rates[index] or nil
    if rate_text and rate_text ~= "" then
      imgui.Text(loc(name) .. " : " .. rate_text)
    else
      imgui.Text(loc(name))
    end
  end
  if #rates ~= #names and h.rate and h.rate ~= "" then
    imgui.TextDisabled(T("rate_prefix") .. tostring(h.rate))
  end
  imgui.EndTooltip()
end

local function expected_kills_of(h)
  local expected = tonumber(h.kills_expected)
  if expected and expected > 0 then return expected end
  local names = split_slash_list(h.source)
  local rates = split_slash_list(h.rate)
  local index = nil
  if h.kills_monster then
    for i, name in ipairs(names) do
      if name == h.kills_monster then
        index = i
        break
      end
    end
  end
  if not index and #rates == 1 then
    index = 1
  end
  if not index then return nil end
  return tonumber(string.match(rates[index] or "", "1/([%d%.]+)"))
end

local function format_luck(ratio)
  local text
  if ratio < 0.1 then
    text = string.format("%.2f", ratio)
  elseif ratio < 10 then
    text = string.format("%.1f", ratio)
  else
    text = string.format("%.0f", ratio)
  end
  if lang.code == "fr" then
    text = (string.gsub(text, "%.", ","))
  end
  return "x" .. text
end

local MONSTER_INFO = {
  boss_keys = {
    ["Dragon"] = true, ["De Rol Le"] = true, ["Vol Opt"] = true, ["Dark Falz"] = true,
    ["Gol Dragon"] = true, ["Barba Ray"] = true, ["Olga Flow"] = true, ["Gal Gryphon"] = true,
    ["Saint Million"] = true, ["Shambertin"] = true, ["Kondrieu"] = true,
  },
  region_episode = {
    ["Forest"] = 1, ["Cave"] = 1, ["Mine"] = 1, ["Ruins"] = 1,
    ["VR Temple"] = 2, ["VR Spaceship"] = 2, ["CCA"] = 2, ["Jungle"] = 2, ["Seabed"] = 2, ["Tower"] = 2,
    ["Crater"] = 4, ["Desert"] = 4, ["Sub Desert"] = 4,
  },
  names = nil, episodes = nil,
}

function MONSTER_INFO.is_boss_name(name)
  if not MONSTER_INFO.names then
    local enemies = load_module("Hunters Log.charts.Enemies")
    local set = {}
    for key in pairs(MONSTER_INFO.boss_keys) do
      set[string.lower(key)] = true
      local list = enemies and enemies[key]
      if type(list) == "table" then
        for _, shown in ipairs(list) do set[string.lower(tostring(shown))] = true end
      end
    end
    if not enemies then return set[string.lower(tostring(name or ""))] == true end
    MONSTER_INFO.names = set
  end
  return MONSTER_INFO.names[string.lower(tostring(name or ""))] == true
end

function MONSTER_INFO.episode_of(key)
  if not MONSTER_INFO.episodes then
    local map = {}
    local quests = load_module("Hunters Log.charts.Quests")
    local regions = quests and quests["Quest"]
    if type(regions) == "table" then
      for region, list in pairs(regions) do
        local region_ep = MONSTER_INFO.region_episode[region]
        if region_ep and type(list) == "table" then
          for i = 1, #list, 2 do map[list[i]] = region_ep end
        end
      end
    end
    MONSTER_INFO.episodes = map
  end
  local known = MONSTER_INFO.episodes[key]
  if known then return known end
  if string.sub(key, -3) == " E2" then return 2 end
  return 1
end

function K.hcol_begin()
  K.HFIRST = true
end

function K.hcol_at(id)
  local x = K.HCOL_X[id]
  if not x then return false end
  if K.HFIRST then
    K.HFIRST = false
  else
    imgui.SameLine(x)
  end
  return true
end

function K.star_text()
  if K.STAR_TEXT then return K.STAR_TEXT end
  local star = "\226\152\133"
  local text = "*"
  local ok_star, w_star = pcall(imgui.CalcTextSize, star)
  local ok_q, w_q = pcall(imgui.CalcTextSize, "?")
  if ok_star and ok_q and tonumber(w_star) and tonumber(w_q) and tonumber(w_star) ~= tonumber(w_q) then
    text = star
  end
  K.STAR_TEXT = text
  return text
end

K.STAR_CELL = 1.5

K.STAR_RECTS = {
  { 4, 0, 1, 1 }, { 3, 1, 3, 1 }, { 0, 2, 9, 1 }, { 1, 3, 7, 1 }, { 2, 4, 5, 2 },
  { 1, 6, 3, 1 }, { 5, 6, 3, 1 }, { 1, 7, 2, 1 }, { 6, 7, 2, 1 },
}

function K.draw_star(x, y, cell, r, g, b)
  for _, rect in ipairs(K.STAR_RECTS) do
    if not K.POPUP.rect(x + rect[1] * cell, y + rect[2] * cell, rect[3] * cell, rect[4] * cell, r, g, b, 1) then
      return false
    end
  end
  return true
end

function K.fav_button(id, is_fav)
  K.FAV_HOVER = K.FAV_HOVER or {}
  local ok_pos, px, py = pcall(imgui.GetCursorPos)
  local width, height = 24, 20
  local drawn = false
  if ok_pos and tonumber(px) and tonumber(py) and K.POPUP and K.POPUP.rect then
    local cell = K.STAR_CELL
    local sx = px + (width - 9 * cell) / 2
    local sy = py + (height - 8 * cell) / 2
    local r, g, b
    if is_fav then
      r, g, b = 1.0, 0.85, 0.10
    else
      r, g, b = 0.42, 0.42, 0.46
    end
    if K.FAV_HOVER[id] then
      r, g, b = math.min(1, r + 0.2), math.min(1, g + 0.2), math.min(1, b + 0.2)
    end
    drawn = K.draw_star(sx, sy, cell, r, g, b)
    imgui.SetCursorPos(px, py)
  end
  local pushed = 0
  if drawn then
    for _, name in ipairs({ "Button", "ButtonHovered", "ButtonActive", "Border" }) do
      if pcall(imgui.PushStyleColor, name, 0, 0, 0, 0) then pushed = pushed + 1 end
    end
  else
    local shade = is_fav and 1.0 or 0.55
    if pcall(imgui.PushStyleColor, "Text", shade, is_fav and 0.85 or 0.55, is_fav and 0.1 or 0.55, 1.0) then pushed = 1 end
  end
  local clicked
  if drawn then
    clicked = imgui.Button("##fav_" .. id, width, height)
  else
    clicked = imgui.Button(K.star_text() .. "##fav_" .. id)
  end
  for _ = 1, pushed do pcall(imgui.PopStyleColor) end
  local hovered = imgui.IsItemHovered()
  K.FAV_HOVER[id] = hovered or nil
  if hovered then
    imgui.BeginTooltip()
    imgui.Text(T(is_fav and "fav_remove" or "fav_add"))
    imgui.EndTooltip()
  end
  return clicked
end

function K.fav_count()
  local cached = K.FAV_COUNT
  if not cached or cached.rev ~= K.HIST_REV or cached.count ~= #drop_history then
    local n = 0
    for _, h in ipairs(drop_history) do
      if h.fav then n = n + 1 end
    end
    cached = { rev = K.HIST_REV, count = #drop_history, n = n }
    K.FAV_COUNT = cached
  end
  return cached.n
end

function K.hcol_label(id)
  if id == "fav" then return K.star_text() end
  if id == "date" then return T("col_date") end
  if id == "item" then return T("col_item") end
  if id == "stats" then return T("col_stats") end
  if id == "difficulty" then return T("col_difficulty") end
  if id == "zone" then return T("col_zone") end
  if id == "id" then return "ID" end
  if id == "monster" then return T("col_monster") end
  if id == "kills" then return T("col_kills") end
  if id == "rate" then return T("col_rate") end
  if id == "bonus" then return T("col_bonus") end
  return T("col_delete")
end

function K.draw_history_header()
  K.hcol_begin()
  for _, col in ipairs(K.HCOLS) do
    if K.hcol_at(col.id) then imgui.TextDisabled(K.hcol_label(col.id)) end
  end
end

function K.row_id(h, field, prefix)
  local id = h[field]
  if not id then
    id = prefix .. tostring(h)
    h[field] = id
  end
  return id
end

local function draw_history_row(h)
  local c = kind_color(K.VR.entry_kind(h), h.name)
  if h._perf == nil then
    local row_details = h.key and item_details[h.key] or nil
    local adfp, aevp = K.parse_armor_stats(row_details and row_details.stats)
    if adfp then h._perf = K.armor_is_perfect(h.name, adfp, aevp) end
  end
  if h._perf then c = K.glow_color(h.name) end
  local r, g, b = section_color(h.section)
  K.hcol_begin()
  if K.hcol_at("fav") then
    local fav_id = h._fid
    if not fav_id then
      fav_id = "h" .. tostring(h)
      h._fid = fav_id
    end
    if K.fav_button(fav_id, h.fav) then
      h.fav = (not h.fav) or nil
      K.HIST_REV = K.HIST_REV + 1
      save_data()
    end
  end
  if K.hcol_at("date") then
    if h._dt_src ~= h.time or h._dt_lang ~= lang.code then
      h._dt_text, h._dt_src, h._dt_lang = fmt_short(h.time), h.time, lang.code
    end
    imgui.Text(h._dt_text)
  end
  if K.hcol_at("item") then
    K.COMMON.draw_name(clip(iname(h.name), 22), c)
    hover_full_text(K.COMMON.full_label(h.name), clip(K.COMMON.full_label(h.name), 22))
  end
  if K.hcol_at("stats") then
    local row_details = h.key and item_details[h.key] or nil
    local stats_hovered = draw_stats_cell(row_details)
    if stats_hovered and row_details and row_details.stats and row_details.stats ~= "" then
      imgui.BeginTooltip()
      imgui.Text(T("stats_prefix") .. tostring(row_details.stats))
      imgui.TextDisabled(T("stats_legend"))
      imgui.EndTooltip()
    end
  end
  if K.hcol_at("difficulty") then
    imgui.Text(clip(difficulty_loc(h.difficulty), 10))
  end
  if K.hcol_at("zone") then
    imgui.Text(clip(loc(h.zone), 20))
    hover_full_text(loc(h.zone), clip(loc(h.zone), 20))
  end
  if K.hcol_at("id") then
    imgui.TextColored(r, g, b, 1, clip(loc(h.section), 12))
    hover_full_text(loc(h.section), clip(loc(h.section), 12))
  end
  if K.hcol_at("monster") then
    local source_hovered = nil
    if h.rare then
      source_hovered = K.rare_text(clip(loc(h.source), 17))
    elseif MONSTER_INFO.is_boss_name(h.kills_monster or h.source) then
      imgui.TextColored(1.0, 0.25, 0.25, 1, clip(loc(h.source), 17))
    else
      imgui.Text(clip(loc(h.source), 17))
    end
    draw_source_tooltip(h, source_hovered)
  end
  if K.hcol_at("kills") then
    if tonumber(h.kills) then
      local kills_value = tonumber(h.kills)
      local expected = expected_kills_of(h)
      local ratio = expected and (kills_value / expected) or nil
      local kills_hovered = false
      imgui.Text(tostring(math.floor(kills_value)))
      kills_hovered = imgui.IsItemHovered()
      if ratio then
        imgui.SameLine(0, 6)
        if ratio < 1 then
          imgui.TextColored(0.4, 1.0, 0.4, 1, format_luck(ratio))
        else
          imgui.TextColored(1.0, 0.4, 0.4, 1, format_luck(ratio))
        end
        kills_hovered = kills_hovered or imgui.IsItemHovered()
      end
      if kills_hovered and (h.kills_monster or ratio) then
        imgui.BeginTooltip()
        if h.kills_monster then
          imgui.Text(T("kills_tooltip", tostring(h.kills_monster), loc(h.section)))
        end
        if ratio then
          imgui.Text(T("luck_expected", string.format("%.0f", expected)))
          if ratio < 1 then
            imgui.TextColored(0.4, 1.0, 0.4, 1, T("luck_good"))
          else
            imgui.TextColored(1.0, 0.4, 0.4, 1, T("luck_bad"))
          end
        end
        imgui.EndTooltip()
      end
    else
      imgui.TextDisabled("-")
    end
  end
  if K.hcol_at("rate") then
    if h.rate and h.rate ~= "" then
      imgui.TextColored(r, g, b, 1, clip(h.rate, 16))
    else
      imgui.TextDisabled("-")
    end
    draw_source_tooltip(h)
  end
  if K.hcol_at("bonus") then
    if tonumber(h.drr) or tonumber(h.dar) then
      local bonus_hovered = false
      imgui.Text((tonumber(h.dar) and fmt_pct(h.dar) or "-") .. " | " .. fmt_pct(h.drr))
      bonus_hovered = imgui.IsItemHovered()
      local show_rer = h.rare and tonumber(h.rer)
      if show_rer then
        imgui.SameLine(0, 0)
        imgui.Text(" | ")
        bonus_hovered = bonus_hovered or imgui.IsItemHovered()
        imgui.SameLine(0, 0)
        imgui.TextColored(1.0, 0.65, 0.15, 1, fmt_pct(h.rer))
        bonus_hovered = bonus_hovered or imgui.IsItemHovered()
      end
      if bonus_hovered then
        imgui.BeginTooltip()
        imgui.Text("DAR : " .. (tonumber(h.dar) and fmt_pct(h.dar) or T("unknown_lower")))
        imgui.Text("RDR : " .. fmt_pct(h.drr))
        if show_rer then
          imgui.Text("RER : " .. fmt_pct(h.rer))
        end
        imgui.EndTooltip()
      end
    else
      imgui.TextDisabled("-")
    end
  end
  if K.hcol_at("delete") then
    if history_delete_confirm.entry == h and os.time() <= history_delete_confirm.expire then
      if imgui.Button(K.row_id(h, "_did_ok", "OK?##hdel")) then
        history_delete_confirm.entry = nil
        delete_history_entry(h)
      end
    else
      if imgui.Button(K.row_id(h, "_did_x", "X##hdel")) then
        if h.fav then
          set_status(T("fav_protected"))
        else
          history_delete_confirm.entry = h
          history_delete_confirm.expire = os.time() + 3
        end
      end
    end
  end
  imgui.Separator()
end

K.load_code("gamelog")
K.GAMELOG.bind({ T = T, difficulty_labels = difficulty_labels, difficulty_loc = difficulty_loc, draw_history_row = draw_history_row, fmt_date = fmt_date, get_auto_episode = get_auto_episode, get_current_floor = get_current_floor, get_game_context = get_game_context, lang = lang, load_module = load_module, loc = loc, section_color = section_color, section_colors = section_colors, section_labels = section_labels, set_status = set_status, streak_sort = K.STREAK.sort })

function K.autofav()
  if frame_counter % 30 ~= 0 then return end
  local changed = false
  for _, h in ipairs(drop_history) do
    if not h.vrdone and K.VR.entry_kind(h) == "veryrare" then
      h.vrdone = true
      h.fav = true
      changed = true
      local t = tonumber(h.time) or 0
      for index, game in ipairs(K.GAMELOG.games) do
        local last_time = game.ended_at and (game.ended_at + K.GAMELOG_DROP_GRACE) or math.huge
        local newer = K.GAMELOG.games[index - 1]
        if newer then last_time = math.min(last_time, newer.start - 1) end
        if t >= game.start and t <= last_time then
          game.fav = true
          K.GAMELOG.games_changed = true
          break
        end
      end
    end
  end
  if changed then
    K.HIST_REV = K.HIST_REV + 1
    K.FAV_COUNT = nil
  end
  if K.GAMELOG.games_changed then
    K.GAMELOG.games_changed = nil
    K.GAMELOG.save()
  end
end

K.GAMELOG.load()

local function run_background_tasks()
  K.frame_id = (K.frame_id or 0) + 1
  if not K.is_lobby(get_current_floor()) then
    update_game_section()
  end
  update_kills()
  K.GAMELOG.update()
  K.CAREER.update()
  K.autofav()
  if frame_counter % 10 == 0 then
    refresh_inventory_ids()
  end
  track_items()
  frame_counter = frame_counter + 1
  do
    local fps_now = os.time()
    if not K.FPS_T0 then
      K.FPS_T0, K.FPS_F0 = fps_now, frame_counter
    elseif fps_now - K.FPS_T0 >= 5 then
      local measured = (frame_counter - K.FPS_F0) / (fps_now - K.FPS_T0)
      if measured >= 10 and measured <= 240 then K.FPS = measured end
      K.FPS_T0, K.FPS_F0 = fps_now, frame_counter
    end
  end
  if frame_counter % 30 == 0 then
    update_tekked_stats()
  end
  if kills_dirty and frame_counter % 300 == 0 then
    kills_dirty = false
    save_data(true)
  end
end

local function draw_id_item_tooltip(item_name, sid, count, entry_filter)
  local list = {}
  for i = #drop_history, 1, -1 do
    local h = drop_history[i]
    if h.name == item_name and (sid == nil or section_key(h.section) == sid)
      and (entry_filter == nil or entry_filter(h)) then
      list[#list + 1] = h
    end
  end
  if #list == 0 then return end
  imgui.BeginTooltip()
  imgui.Text(string.format("%s - %s (x%d)", K.COMMON.full_label(item_name), tostring(sid or T("tip_all_ids")), tonumber(count) or #list))
  imgui.Separator()
  local shown = math.min(#list, 10)
  for i = 1, shown do
    local h = list[i]
    local details = h.key and item_details[h.key] or nil
    local line = fmt_short(h.time) .. "  " .. clip(loc(h.zone), 18) .. "  " .. clip(loc(h.source), 22)
    if sid == nil then
      line = line .. "  " .. clip(tostring(h.section or ""), 10)
    end
    local segs, weapon
    if details and details.stats and details.stats ~= "" and details.stats ~= "N/A"
      and details.stats ~= "Sans attributs particuliers" then
      segs = K.armor_stat_segs(details.stats, details.name or item_name)
      if segs then
        line = line .. "  "
      else
        local grind, values = parse_weapon_stats(details.stats)
        if values then
          weapon = { grind, values, is_pending(details) }
          line = line .. "  "
        else
          line = line .. "  " .. details.stats
        end
      end
    end
    imgui.Text(line)
    if weapon then
      imgui.SameLine(0, 0)
      draw_weapon_entry(weapon[1], weapon[2], weapon[3])
    end
    if segs then
      for _, seg in ipairs(segs) do
        imgui.SameLine(0, 0)
        imgui.TextColored(seg[2], seg[3], seg[4], 1, seg[1])
      end
    end
    if tonumber(h.kills) then
      imgui.SameLine(0, 0)
      imgui.Text("  (" .. tostring(math.floor(tonumber(h.kills))) .. " kills)")
    end
  end
  if #list > shown then
    imgui.TextDisabled(T("more_older", #list - shown))
  end
  imgui.EndTooltip()
end

K.load_code("pagination")

local function draw_counters_tab()
  local changed
  local legend_count = 0
  for _, kind in ipairs(kind_list) do
    if kind ~= "mag" then
      if legend_count > 0 then
        imgui.SameLine(0, 8)
      end
      local c = kind_color(kind)
      imgui.TextColored(c[1], c[2], c[3], 1, T("kind_" .. kind))
      legend_count = legend_count + 1
    end
  end
  imgui.Separator()
  imgui.Text(T("search_item"))
  imgui.SameLine(0, 6)
  imgui.PushItemWidth(K.SEARCH_BOX_WIDTH)
  changed, search_item_text = imgui.InputText("##search_item_counters", search_item_text, 64)
  imgui.PopItemWidth()
  imgui.SameLine(0, 4)
  if imgui.Button("X##search_item_counters_clear") then
    search_item_text = ""
  end
  K.COUNTERS_KIND_HIDDEN = K.COUNTERS_KIND_HIDDEN or {}
  local KH = K.COUNTERS_KIND_HIDDEN
  imgui.SameLine(0, 24)
  for index, kind in ipairs(K.KIND_FILTERS) do
    if index > 1 then imgui.SameLine(0, 4) end
    local color = KH[kind] and { 0.40, 0.40, 0.40 } or (kind == "common" and K.COMMON.white) or kind_color(kind)
    local pushed = pcall(imgui.PushStyleColor, "Text", color[1], color[2], color[3], 1.0)
    local clicked = imgui.Button(T("filter_kind_" .. kind) .. "##counters_kind_" .. kind)
    if pushed then pcall(imgui.PopStyleColor) end
    if clicked then KH[kind] = (not KH[kind]) or nil end
  end
  imgui.SameLine(0, 8)
  if imgui.Button("X##counters_kind_reset") then
    K.COUNTERS_KIND_HIDDEN = {}
    KH = K.COUNTERS_KIND_HIDDEN
  end
  local kind_sig = {}
  for _, kind in ipairs(K.KIND_FILTERS) do if KH[kind] then kind_sig[#kind_sig + 1] = kind end end
  kind_sig = table.concat(kind_sig, ",")
  imgui.Separator()
  local last_seen = counters_cache.last_seen
  local best = counters_cache.best
  local best_u = counters_cache.best_u
  local best_a = counters_cache.best_a or {}
  local names = {}
  local counters_query = string.lower(search_item_text or "")
  for name, _ in pairs(item_counts) do
    if item_kinds[name] ~= "mag" and not KH[K.name_category(name)]
      and (counters_query == "" or string.find(string.lower(name), counters_query, 1, true)) then
      table.insert(names, name)
    end
  end
  K.CSORT = K.CSORT or { key = "kind", desc = false }
  local sort_key, sort_desc = K.CSORT.key, K.CSORT.desc
  local function sort_metric(name)
    if sort_key == "qty" then return item_counts[name] or 0 end
    if sort_key == "last" then return last_seen[name] or 0 end
    local rec = (sort_key == "tek" and best[name]) or (sort_key == "untek" and best_u[name]) or nil
    if rec then return rec.values[5] * 10000 + (rec.sum or 0) end
    local armor_rec = sort_key == "armor" and best_a[name] or nil
    if armor_rec then return K.armor_sort_metric(name, armor_rec) end
    return nil
  end
  table.sort(names, function(a, b)
    if sort_key == "kind" then
      local ka = kind_order[item_category(item_kinds[a], a)] or 99
      local kb = kind_order[item_category(item_kinds[b], b)] or 99
      local result
      if ka ~= kb then result = ka < kb else result = string.lower(a) < string.lower(b) end
      if sort_desc then return not result end
      return result
    end
    local ma, mb = sort_metric(a), sort_metric(b)
    if ma ~= mb then
      if ma == nil then return false end
      if mb == nil then return true end
      if sort_desc then return ma > mb end
      return ma < mb
    end
    return string.lower(a) < string.lower(b)
  end)
  local common_names, rare_names = {}, {}
  for _, listed_name in ipairs(names) do
    if K.COMMON.is_name(listed_name) then
      table.insert(common_names, listed_name)
    else
      table.insert(rare_names, listed_name)
    end
  end
  K.PAGER.reset_on_change("counters", counters_query .. "|" .. sort_key .. tostring(sort_desc) .. "|" .. kind_sig)
  local counters_page = K.PAGER.draw("counters", #rare_names)
  local function sort_header(label, key)
    local text = label
    if K.CSORT.key == key then text = text .. (K.CSORT.desc and " v" or " ^") end
    if imgui.Button(text .. "##csort_" .. key) then
      if K.CSORT.key == key then
        K.CSORT.desc = not K.CSORT.desc
      else
        K.CSORT.key = key
        K.CSORT.desc = (key ~= "kind")
      end
    end
  end
  imgui.Text(" ")
  imgui.SameLine(495)
  sort_header(T("col_best_armor"), "armor")
  sort_header(T("col_item"), "kind")
  imgui.SameLine(260)
  sort_header(T("col_qty"), "qty")
  imgui.SameLine(320)
  sort_header(T("col_last_drop"), "last")
  imgui.SameLine(495)
  sort_header(T("col_best_tekked"), "tek")
  imgui.SameLine(690)
  sort_header(T("col_best_untekked"), "untek")
  imgui.SameLine(900)
  imgui.TextDisabled(T("col_delete"))
  imgui.Separator()
  local function draw_counter_row(item_name)
    local count = item_counts[item_name]
    local c = kind_color(item_kinds[item_name], item_name)
    K.COMMON.draw_name(clip(iname(item_name), 34), c)
    if imgui.IsItemHovered() then
      draw_id_item_tooltip(item_name, nil, count)
    end
    imgui.SameLine(260)
    imgui.TextColored(0.2, 1, 0.2, 1, tostring(count))
    if imgui.IsItemHovered() then
      draw_id_item_tooltip(item_name, nil, count)
    end
    imgui.SameLine(320)
    imgui.TextDisabled(last_seen[item_name] and fmt_short(last_seen[item_name]) or "-")
    imgui.SameLine(495)
    local best_weapon = best[item_name]
    if best_weapon then
      draw_weapon_entry(best_weapon.grind, best_weapon.values, false)
    elseif best_a[item_name] then
      K.draw_armor_entry(item_name, best_a[item_name])
    else
      imgui.TextDisabled("-")
    end
    imgui.SameLine(690)
    local best_untekked = best_u[item_name]
    if best_untekked then
      draw_weapon_entry(best_untekked.grind, best_untekked.values, true)
    else
      imgui.TextDisabled("-")
    end
    imgui.SameLine(900)
    draw_delete_cell(item_name)
    imgui.Separator()
  end
  do
    local first, last = K.PAGER.range("counters", counters_page, #rare_names)
    for position = first, last do draw_counter_row(rare_names[position]) end
  end
  if #common_names > 0 then
    local common_total = 0
    for _, listed_name in ipairs(common_names) do
      common_total = common_total + (item_counts[listed_name] or 0)
    end
    local common_open = K.COMMON_UI.counters_open or counters_query ~= ""
    if imgui.Button((common_open and "-" or "+") .. "##common_group") then
      K.COMMON_UI.counters_open = not K.COMMON_UI.counters_open
    end
    imgui.SameLine(0, 6)
    imgui.TextColored(1, 1, 1, 1, T("common_group", common_total, #common_names))
    if common_open then
      K.PAGER.reset_on_change("counters_common", counters_query)
      local common_page = K.PAGER.draw("counters_common", #common_names)
      local first, last = K.PAGER.range("counters_common", common_page, #common_names)
      for position = first, last do draw_counter_row(common_names[position]) end
    end
  end
  if #names == 0 then
    imgui.TextDisabled((counters_query ~= "" or kind_sig ~= "") and T("no_item_found") or T("waiting_drops"))
  end
end

function K.entry_category(h)
  local name = h.name
  local kind = K.VR.entry_kind(h) or item_kinds[name] or "other"
  if kind == "weapon" and K.COMMON.is_name(name) then return "common" end
  return item_category(kind, name)
end

function K.name_category(name)
  local kind = item_kinds[name] or "other"
  if kind == "weapon" and K.COMMON.is_name(name) then return "common" end
  return item_category(kind, name)
end

function K.kind_filter_button(kind)
  local color
  if K.KIND_HIDDEN[kind] then
    color = { 0.40, 0.40, 0.40 }
  elseif kind == "common" then
    color = K.COMMON.white
  else
    color = kind_color(kind)
  end
  local pushed = pcall(imgui.PushStyleColor, "Text", color[1], color[2], color[3], 1.0)
  local clicked = imgui.Button(T("filter_kind_" .. kind) .. "##kind_filter_" .. kind)
  if pushed then pcall(imgui.PopStyleColor) end
  return clicked
end

function K.entry_visible(h)
  local category = K.entry_category(h)
  if category == "mag" then return false end
  return not K.KIND_HIDDEN[category]
end

local function draw_history_tab()
  K.CLIP.frame_begin("history")
  local changed
  local fav_only = K.HIST_SUB == "fav"
  if imgui.Button((not fav_only and ("[" .. T("sub_all") .. "]") or T("sub_all")) .. "##hist_sub_all") then
    K.HIST_SUB = "all"
  end
  imgui.SameLine(0, 4)
  local fav_label = K.star_text() .. " " .. T("sub_fav") .. " (" .. K.fav_count() .. ")"
  if imgui.Button((fav_only and ("[" .. fav_label .. "]") or fav_label) .. "##hist_sub_fav") then
    K.HIST_SUB = "fav"
  end
  fav_only = K.HIST_SUB == "fav"
  imgui.Separator()
  imgui.Text(T("filter_item"))
  imgui.SameLine(0, 6)
  if imgui.Button("<##filter_item_prev") then
    filter_item = cycle_filter(counters_cache.history_names, filter_item, -1)
  end
  imgui.SameLine(0, 4)
  if imgui.Button(">##filter_item_next") then
    filter_item = cycle_filter(counters_cache.history_names, filter_item, 1)
  end
  imgui.SameLine(0, 4)
  if imgui.Button(T("all") .. "##filter_item_all") then
    filter_item = nil
  end
  imgui.SameLine(0, 8)
  if filter_item then
    local fc = kind_color(item_kinds[filter_item], filter_item)
    imgui.TextColored(fc[1], fc[2], fc[3], 1, clip(K.COMMON.full_label(filter_item), 30))
  else
    imgui.TextDisabled(T("all_paren"))
  end
  imgui.SameLine(0, 24)
  imgui.Text(T("search"))
  imgui.SameLine(0, 6)
  imgui.PushItemWidth(K.SEARCH_BOX_WIDTH)
  changed, search_item_text = imgui.InputText("##search_item_history", search_item_text, 64)
  imgui.PopItemWidth()
  imgui.SameLine(0, 4)
  if imgui.Button("X##search_item_history_clear") then
    search_item_text = ""
  end
  imgui.Text(T("filter_id"))
  imgui.SameLine(0, 6)
  if imgui.Button("<##filter_id_prev") then
    filter_id = cycle_filter(section_list, filter_id, -1)
  end
  imgui.SameLine(0, 4)
  if imgui.Button(">##filter_id_next") then
    filter_id = cycle_filter(section_list, filter_id, 1)
  end
  imgui.SameLine(0, 4)
  if imgui.Button(T("all") .. "##filter_id_all") then
    filter_id = nil
  end
  imgui.SameLine(0, 8)
  if filter_id then
    local fr, fg, fb = section_color(filter_id)
    imgui.TextColored(fr, fg, fb, 1, loc(filter_id))
  else
    imgui.TextDisabled(T("all_paren"))
  end
  imgui.SameLine(0, 24)
  imgui.Text(T("search"))
  imgui.SameLine(0, 6)
  imgui.PushItemWidth(K.SEARCH_BOX_WIDTH)
  changed, search_id_text = imgui.InputText("##search_id_history", search_id_text, 32)
  imgui.PopItemWidth()
  imgui.SameLine(0, 4)
  if imgui.Button("X##search_id_history_clear") then
    search_id_text = ""
  end
  imgui.SameLine(0, 24)
  for index, kind in ipairs(K.KIND_FILTERS) do
    if index > 1 then imgui.SameLine(0, 4) end
    if K.kind_filter_button(kind) then
      K.KIND_HIDDEN[kind] = (not K.KIND_HIDDEN[kind]) or nil
      save_data()
    end
  end
  imgui.SameLine(0, 8)
  if imgui.Button("X##kind_filters_reset") then
    K.KIND_HIDDEN = {}
    save_data()
  end
  imgui.Separator()
  local hq = K.HIST_Q
  if not hq then
    hq = { live_item = "", live_id = "", item = "", id = "", frame = 0 }
    K.HIST_Q = hq
  end
  local live_item, live_id = search_item_text or "", search_id_text or ""
  if hq.live_item ~= live_item or hq.live_id ~= live_id then
    hq.live_item, hq.live_id, hq.frame = live_item, live_id, frame_counter
  end
  if hq.item ~= live_item or hq.id ~= live_id then
    if (live_item == "" and live_id == "") or frame_counter - hq.frame >= 6 then
      hq.item, hq.id = live_item, live_id
    end
  end
  local item_query = string.lower(hq.item)
  local id_query = string.lower(hq.id)
  local mask = 0
  for index, kind in ipairs(K.KIND_FILTERS) do
    if K.KIND_HIDDEN[kind] then mask = mask + 2 ^ index end
  end
  local memo = K.HIST_SIG
  if not memo or memo.filter_item ~= filter_item or memo.filter_id ~= filter_id or memo.mask ~= mask
    or memo.vr ~= K.VR.version or memo.fav_only ~= fav_only then
    local kinds_sig = K.kinds_serialize()
    memo = { filter_item = filter_item, filter_id = filter_id, mask = mask, vr = K.VR.version, fav_only = fav_only,
      kinds_sig = kinds_sig,
      sig_base = table.concat({ tostring(filter_item), tostring(filter_id), kinds_sig, tostring(K.VR.version), tostring(fav_only) }, "|") }
    K.HIST_SIG = memo
  end
  local kinds_sig, sig_base = memo.kinds_sig, memo.sig_base
  if memo.item_query ~= item_query or memo.id_query ~= id_query then
    memo.item_query, memo.id_query = item_query, id_query
    memo.sig = sig_base .. "|" .. item_query .. "|" .. id_query
  end
  local sig = memo.sig
  K.PAGER.reset_on_change("history", sig)
  local cache = K.PAGER.cache_history
  if not cache or cache.sig ~= sig or cache.count ~= #drop_history or cache.rev ~= K.HIST_REV or frame_counter - cache.frame >= 600 then
    local source = nil
    if cache and cache.sig_base == sig_base and cache.count == #drop_history and cache.rev == K.HIST_REV and frame_counter - cache.frame < 600
      and string.sub(item_query, 1, #cache.item_query) == cache.item_query
      and string.sub(id_query, 1, #cache.id_query) == cache.id_query then
      source = cache.list
    end
    local list = {}
    local function consider(h)
      if (not fav_only or h.fav)
        and (not filter_item or h.name == filter_item)
        and (not filter_id or section_key(h.section) == filter_id)
        and (item_query == "" or string.find(K.LOWER_NAMES[h.name or ""], item_query, 1, true))
        and (id_query == "" or string.find(K.LOWER_NAMES[tostring(h.section or "")], id_query, 1, true))
        and K.entry_visible(h) then
        list[#list + 1] = h
      end
    end
    if source then
      for _, h in ipairs(source) do consider(h) end
    else
      for i = #drop_history, 1, -1 do consider(drop_history[i]) end
    end
    cache = { sig = sig, sig_base = sig_base, item_query = item_query, id_query = id_query,
      count = #drop_history, rev = K.HIST_REV, frame = frame_counter, list = list }
    K.PAGER.cache_history = cache
  end
  local all_rows = cache.list
  local filtered = (filter_item ~= nil) or (filter_id ~= nil) or (item_query ~= "") or (id_query ~= "") or kinds_sig ~= "" or fav_only
  local history_page = K.PAGER.draw("history", #all_rows)
  local rows = {}
  do
    local first, last = K.PAGER.range("history", history_page, #all_rows)
    for position = first, last do rows[#rows + 1] = all_rows[position] end
  end
  imgui.Text(T("last_drops", #all_rows, filtered and T("matching_filters") or "", #drop_history))
  imgui.SameLine(420)
  imgui.TextDisabled(T("stats_scale"))
  for _, v in ipairs({ 0, 25, 50, 75, 100 }) do
    imgui.SameLine(0, 8)
    local r, g, b = heat_color(v)
    imgui.TextColored(r, g, b, 1, tostring(v))
  end
  imgui.Separator()
  K.draw_history_header()
  imgui.Separator()
  if #rows == 0 then
    imgui.TextDisabled((fav_only and K.fav_count() == 0) and T("fav_none") or (filtered and T("no_drop_filters") or T("empty")))
  end
  for _, h in ipairs(rows) do
    K.CLIP.row(draw_history_row, h)
  end
  K.CLIP.finish()
end

local function draw_ids_tab()
  K.IDS_PAGE = K.IDS_PAGE or 1
  for index, page in ipairs({ 1, 2, "all" }) do
    if index > 1 then imgui.SameLine(0, 4) end
    local label = page == 1 and "ID 1-5" or page == 2 and "ID 6-10" or T("all")
    if page == K.IDS_PAGE then label = "[" .. label .. "]" end
    if imgui.Button(label .. "##ids_page_" .. tostring(page)) then K.IDS_PAGE = page end
  end
  K.IDS_DIFF = K.IDS_DIFF or { mode = "all", set = {} }
  K.IDS_KIND_HIDDEN = K.IDS_KIND_HIDDEN or {}
  K.IDS_Q = K.IDS_Q or { item = nil, text = "" }
  local DF, KH, Q = K.IDS_DIFF, K.IDS_KIND_HIDDEN, K.IDS_Q
  local function sub_button(label, selected, id, color)
    local text = selected and ("[" .. label .. "]") or label
    local pushed = color and pcall(imgui.PushStyleColor, "Text", color[1], color[2], color[3], 1.0)
    local clicked = imgui.Button(text .. "##" .. id)
    if pushed then pcall(imgui.PopStyleColor) end
    return clicked
  end
  local diff_colors = K.STREAK.sort.diff_colors
  imgui.SameLine(0, 24)
  imgui.Text(T("streaks_difficulty"))
  imgui.SameLine(0, 4)
  if sub_button(T("streaks_current"), DF.mode == "auto", "ids_df_auto") then
    DF.mode, DF.set = "auto", {}
  end
  for index = 0, 3 do
    imgui.SameLine(0, 4)
    local label = difficulty_labels[index]
    if sub_button(difficulty_loc(label), DF.mode == "set" and DF.set[label] == true, "ids_df_" .. index, diff_colors[index]) then
      if DF.mode ~= "set" then DF.mode, DF.set = "set", {} end
      DF.set[label] = (not DF.set[label]) or nil
      if next(DF.set) == nil then DF.mode = "all" end
    end
  end
  imgui.SameLine(0, 4)
  if sub_button(T("streaks_all"), DF.mode == "all", "ids_df_all") then
    DF.mode, DF.set = "all", {}
  end
  imgui.Text(T("filter_item"))
  imgui.SameLine(0, 6)
  if imgui.Button("<##ids_item_prev") then Q.item = cycle_filter(counters_cache.history_names, Q.item, -1) end
  imgui.SameLine(0, 4)
  if imgui.Button(">##ids_item_next") then Q.item = cycle_filter(counters_cache.history_names, Q.item, 1) end
  imgui.SameLine(0, 4)
  if imgui.Button(T("all") .. "##ids_item_all") then Q.item = nil end
  imgui.SameLine(0, 8)
  if Q.item then
    local fc = kind_color(item_kinds[Q.item], Q.item)
    imgui.TextColored(fc[1], fc[2], fc[3], 1, clip(K.COMMON.full_label(Q.item), 30))
  else
    imgui.TextDisabled(T("all_paren"))
  end
  imgui.SameLine(0, 24)
  imgui.Text(T("search"))
  imgui.SameLine(0, 6)
  imgui.PushItemWidth(K.SEARCH_BOX_WIDTH)
  local _, new_text = imgui.InputText("##ids_search_item", Q.text, 64)
  Q.text = new_text
  imgui.PopItemWidth()
  imgui.SameLine(0, 4)
  if imgui.Button("X##ids_search_clear") then Q.text = "" end
  imgui.SameLine(0, 24)
  for index, kind in ipairs(K.KIND_FILTERS) do
    if index > 1 then imgui.SameLine(0, 4) end
    local color = KH[kind] and { 0.40, 0.40, 0.40 } or (kind == "common" and K.COMMON.white) or kind_color(kind)
    local pushed = pcall(imgui.PushStyleColor, "Text", color[1], color[2], color[3], 1.0)
    local clicked = imgui.Button(T("filter_kind_" .. kind) .. "##ids_kind_" .. kind)
    if pushed then pcall(imgui.PopStyleColor) end
    if clicked then KH[kind] = (not KH[kind]) or nil end
  end
  imgui.SameLine(0, 8)
  if imgui.Button("X##ids_kind_reset") then K.IDS_KIND_HIDDEN = {}; KH = K.IDS_KIND_HIDDEN end
  imgui.Separator()
  local diff_ok_set
  if DF.mode == "auto" then
    local ok_diff, value = pcall(pso.read_u32, K.DIFFICULTY_ADDR)
    local label = ok_diff and difficulty_labels[value] or nil
    diff_ok_set = { [label or "?"] = true }
  elseif DF.mode == "set" then
    diff_ok_set = DF.set
  end
  local query = string.lower(Q.text or "")
  local diff_sig = {}
  if diff_ok_set then for label in pairs(diff_ok_set) do diff_sig[#diff_sig + 1] = label end end
  table.sort(diff_sig)
  local kind_sig = {}
  for _, kind in ipairs(K.KIND_FILTERS) do if KH[kind] then kind_sig[#kind_sig + 1] = kind end end
  local sig = table.concat({ tostring(counters_cache), DF.mode, table.concat(diff_sig, ","), table.concat(kind_sig, ","),
    tostring(Q.item), query, tostring(K.VR.version) }, "|")
  if not K.IDS_VIEW or K.IDS_VIEW.sig ~= sig then
    local function entry_ok(h)
      if diff_ok_set and not diff_ok_set[tostring(h.difficulty or "Inconnue")] then return false end
      if Q.item and h.name ~= Q.item then return false end
      if query ~= "" and not string.find(K.LOWER_NAMES[h.name or ""], query, 1, true) then return false end
      return not KH[K.entry_category(h)]
    end
    local merged, totals, unknown = {}, {}, 0
    local function add(sid, name, n)
      if sid then
        merged[sid] = merged[sid] or {}
        merged[sid][name] = (merged[sid][name] or 0) + n
        totals[sid] = (totals[sid] or 0) + n
      else
        unknown = unknown + n
      end
    end
    for _, h in ipairs(drop_history) do
      if entry_ok(h) then add(section_key(h.section), h.name, 1) end
    end
    for _, rec in ipairs(K.ARCHIVE.list) do
      if entry_ok({ name = rec.name, difficulty = rec.difficulty }) then add(section_key(rec.section), rec.name, rec.n) end
    end
    local lists = {}
    for sid, counts in pairs(merged) do
      local list = {}
      for name, n in pairs(counts) do
        table.insert(list, { name = name, count = n, kind = item_kinds[name] or "other" })
      end
      table.sort(list, function(a, b)
        local ka = kind_order[item_category(a.kind, a.name)] or 99
        local kb = kind_order[item_category(b.kind, b.name)] or 99
        if ka ~= kb then return ka < kb end
        if a.count ~= b.count then return a.count > b.count end
        return string.lower(a.name) < string.lower(b.name)
      end)
      lists[sid] = list
    end
    K.IDS_VIEW = { sig = sig, lists = lists, totals = totals, unknown = unknown, entry_ok = entry_ok }
  end
  K.IDS_FILTER_FN = K.IDS_VIEW.entry_ok
  local id_lists, id_totals, id_unknown = K.IDS_VIEW.lists, K.IDS_VIEW.totals, K.IDS_VIEW.unknown
  local per_band, step, name_len = 5, 190, 20
  local band_first, band_last = 1, 10
  if K.IDS_PAGE == 1 then band_last = 5 elseif K.IDS_PAGE == 2 then band_first = 6 end
  local id_views = {}
  for _, view_sid in ipairs(section_list) do
    local source_list = id_lists[view_sid]
    if source_list then
      local view, commons, common_count = {}, {}, 0
      for _, entry in ipairs(source_list) do
        if K.COMMON.is_name(entry.name) then
          common_count = common_count + entry.count
          table.insert(commons, entry)
        else
          table.insert(view, entry)
        end
      end
      if #commons > 0 then
        local group_open = K.COMMON_UI.ids_open[view_sid]
        table.insert(view, { name = T("common_group_ids"), kind = "weapon", count = common_count, group = true, sid = view_sid, open = group_open })
        if group_open then
          for _, entry in ipairs(commons) do table.insert(view, entry) end
        end
      end
      id_views[view_sid] = view
    end
  end
  for band_start = band_first, band_last, per_band do
    for col = 0, per_band - 1 do
      local sid = section_list[band_start + col]
      local r, g, b = section_color(sid)
      if col > 0 then
        imgui.SameLine(col * step)
      end
      imgui.TextColored(r, g, b, 1, string.format("%s (%d)", loc(sid), id_totals[sid] or 0))
    end
    imgui.Separator()
    local max_rows = 0
    for col = 0, per_band - 1 do
      local list = id_views[section_list[band_start + col]]
      if list and #list > max_rows then
        max_rows = #list
      end
    end
    if max_rows == 0 then
      imgui.TextDisabled(T("no_drop"))
    end
    for row = 1, max_rows do
      for col = 0, per_band - 1 do
        local list = id_views[section_list[band_start + col]]
        local entry = list and list[row]
        if col > 0 then
          imgui.SameLine(col * step)
        end
        if entry then
          if entry.group then
            if imgui.Button((entry.open and "-" or "+") .. "##ids_group_" .. tostring(entry.sid)) then
              K.COMMON_UI.ids_open[entry.sid] = (not entry.open) or nil
            end
            imgui.SameLine(0, 6)
            imgui.TextColored(1, 1, 1, 1, string.format("x%d %s", entry.count, entry.name))
          else
            local c = kind_color(entry.kind, entry.name)
            imgui.TextColored(c[1], c[2], c[3], 1, string.format("x%d", entry.count))
            imgui.SameLine(0, 4)
            K.COMMON.draw_name(clip(iname(entry.name), name_len), c)
            if imgui.IsItemHovered() then
              draw_id_item_tooltip(entry.name, section_list[band_start + col], entry.count, K.IDS_FILTER_FN)
            end
          end
        else
          imgui.Text(" ")
        end
      end
    end
    imgui.Separator()
  end
  if id_unknown > 0 then
    imgui.TextDisabled(T("unknown_id_drops", id_unknown))
  end
end

local function draw_language_buttons()
  local labels = { fr = "Français", en = "English", ja = "日本語" }
  for index, code in ipairs({ "fr", "en", "ja" }) do
    if index > 1 then
      imgui.SameLine(0, 4)
    end
    local label = labels[code] or code
    if lang.code == code then
      label = "[" .. label .. "]"
    end
    if imgui.Button(label .. "##lang_" .. code) and lang.code ~= code then
      lang.code = code
      save_data()
    end
  end
  K.HOTKEY.draw_button()
end

K.QUEST_JA = JA_NAMES.quests

local function draw_help_line(line, continuation)
  local pos, first = 1, true
  while pos <= #line do
    local _, dot_b = string.find(line, ". ", pos, true)
    local _, jp_b = string.find(line, "\227\128\130", pos, true)
    local stop = #line
    if dot_b and (not jp_b or dot_b < jp_b) then
      stop = dot_b
    elseif jp_b then
      stop = jp_b
    end
    local chunk = string.sub(line, pos, stop)
    pos = stop + 1
    local head, tail = nil, chunk
    local colon = (not continuation) and string.find(chunk, ":", 1, true)
    if colon then
      local label = string.sub(chunk, 1, colon - 1)
      local _, opens = string.gsub(label, "%(", "")
      local _, closes = string.gsub(label, "%)", "")
      if #label <= 60 and opens == closes and not string.find(label, "[=,]") then
        head = string.sub(chunk, 1, colon)
        tail = string.sub(chunk, colon + 1)
      end
    end
    if not first then imgui.SameLine(0, 0) end
    first = false
    if head then
      imgui.TextColored(1.0, 0.9, 0.2, 1, head)
      if tail ~= "" then imgui.SameLine(0, 0) end
    end
    if tail ~= "" then
      imgui.TextColored(0.75, 0.9, 1.0, 1, tail)
    end
  end
end

function K.help_wrap_width()
  local ok, width = pcall(imgui.GetWindowSize)
  if ok and type(width) == "number" and width > 300 then return math.min(1000, math.floor(width - 60)) end
  return 1000
end

function K.help_text_width(text)
  local ok, width = pcall(imgui.CalcTextSize, text)
  if ok and type(width) == "number" then return width end
  return #text * 7
end

function K.help_wrap(line, max_width)
  local tokens, pos = {}, 1
  while pos <= #line do
    local byte = string.byte(line, pos)
    local stop
    if byte >= 0xC0 then
      stop = pos + (byte >= 0xF0 and 3 or byte >= 0xE0 and 2 or 1)
    else
      local _, found = string.find(line, "^[^%s\128-\255]*%s*", pos)
      stop = math.max(found or pos, pos)
    end
    tokens[#tokens + 1] = string.sub(line, pos, stop)
    pos = stop + 1
  end
  local pieces, current = {}, ""
  for _, token in ipairs(tokens) do
    local candidate = current .. token
    if current ~= "" and K.help_text_width(candidate) > max_width then
      pieces[#pieces + 1] = current
      current = token
    else
      current = candidate
    end
  end
  if current ~= "" then pieces[#pieces + 1] = current end
  return pieces
end

local function draw_help_tab()
  local pages = {
    { "general", T("help_page_general") },
    { "counters", T("tab_counters") },
    { "history", T("tab_history") },
    { "ids", T("tab_ids") },
    { "streaks", T("tab_streaks") },
    { "game", T("tab_game") },
    { "popup", T("tab_popup") },
    { "icons", T("help_page_icons") },
  }
  local page = K.STREAK.sort.help_page or "general"
  for index, entry in ipairs(pages) do
    if index > 1 then imgui.SameLine(0, 4) end
    local label = (page == entry[1]) and ("[" .. entry[2] .. "]") or entry[2]
    if imgui.Button(label .. "##help_" .. entry[1]) then
      K.STREAK.sort.help_page = entry[1]
      page = entry[1]
    end
  end
  imgui.Separator()
  local max_width = K.help_wrap_width()
  local cache_key = page .. "|" .. lang.code .. "|" .. max_width
  local cache = K.HELP_CACHE
  if not cache or cache.key ~= cache_key then
    cache = { key = cache_key, lines = {} }
    local first_line = true
    for help_line in string.gmatch(T("help_" .. page), "[^\n]+") do
      if first_line then
        cache.lines[#cache.lines + 1] = { text = help_line, title = true }
        first_line = false
      else
        for index, piece in ipairs(K.help_wrap(help_line, max_width)) do
          cache.lines[#cache.lines + 1] = { text = piece, continuation = index > 1 }
        end
      end
    end
    K.HELP_CACHE = cache
  end
  for _, entry in ipairs(cache.lines) do
    if entry.title then
      imgui.TextColored(1.0, 0.9, 0.4, 1, entry.text)
    else
      draw_help_line(entry.text, entry.continuation)
    end
  end
end

K.STREAK.bind({ KEYALIAS = KEYALIAS, MONSTER_INFO = MONSTER_INFO, T = T, ZONES = ZONES, clip = clip, difficulty_labels = difficulty_labels, difficulty_modules = difficulty_modules, floor_names = floor_names, format_luck = format_luck, format_odds = format_odds, get_auto_episode = get_auto_episode, get_rare_keys = get_rare_keys, get_section_index = get_section_index, kind_color = kind_color, lang = lang, load_module = load_module, loc = loc, no_detail_items = no_detail_items, parse_odds = parse_odds, section_color = section_color, section_colors = section_colors, section_labels = section_labels })

K.load_code("popup_draw")
K.POPUP.bind({ PERFECT_ARMOR_STATS = PERFECT_ARMOR_STATS, T = T, clip = clip, get_current_tab = function() return current_tab end,
  heat_color = heat_color, hsv_to_rgb = hsv_to_rgb, iname = iname, item_category = item_category, kind_color = kind_color,
  lang = lang, loc = loc, parse_weapon_stats = parse_weapon_stats, save_data = save_data, section_color = section_color,
  set_status = set_status, get_window_open = function() return window_open end })
K.CAREER.bind({ loc = loc, difficulty_loc = difficulty_loc, section_color = section_color })
K.KC.bind({ KEYALIAS = KEYALIAS, MONSTER_INFO = MONSTER_INFO, T = T, ZONES = ZONES, clip = clip, difficulty_labels = difficulty_labels,
  difficulty_modules = difficulty_modules, get_drop_history = function() return drop_history end, format_luck = format_luck,
  format_odds = format_odds, get_current_floor = get_current_floor, get_current_zone = get_current_zone, get_rare_keys = get_rare_keys,
  get_section_index = get_section_index, kill_context_prefix = kill_context_prefix, lang = lang, load_module = load_module, loc = loc,
  save_data = save_data, section_color = section_color, streak_color = K.STREAK.color, streak_odds = K.STREAK.odds, streak_sort = K.STREAK.sort,
  item_color = function(item)
    local learned = item_kinds[item]
    if no_detail_items[string.lower(item)] then
      learned = "misc"
    elseif not learned or learned == "other" then
      learned = K.STREAK.wiki_kinds[string.lower(item)] or "weapon"
    end
    return kind_color(learned, item)
  end })

K.draw_options_tab = function()
  imgui.Text(T("opacity") .. tostring(bg_opacity))
  imgui.SameLine(0, 8)
  if imgui.Button("-##opacity") then
    bg_opacity = math.max(0, bg_opacity - 5)
    save_data()
  end
  imgui.SameLine(0, 4)
  if imgui.Button("+##opacity") then
    bg_opacity = math.min(100, bg_opacity + 5)
    save_data()
  end
  local rare_changed
  rare_changed, K.RARE_YELLOW = imgui.Checkbox(T("rare_yellow") .. "##rare_yellow", K.RARE_YELLOW)
  if rare_changed then save_data() end
  local changed
  changed, hide_title_bar = imgui.Checkbox(T("hide_title"), hide_title_bar)
  if changed then
    save_data()
  end
  draw_theme_selector()
  local common_changed
  common_changed, K.COMMON.enabled = imgui.Checkbox(T("common_enable") .. "##common_enable", K.COMMON.enabled)
  imgui.SameLine(0, 12)
  imgui.Text(T("common_min_hit") .. tostring(K.COMMON.min_hit) .. " %")
  imgui.SameLine(0, 8)
  if imgui.Button("-##common_hit") then
    K.COMMON.min_hit = math.max(40, K.COMMON.min_hit - 5)
    common_changed = true
  end
  imgui.SameLine(0, 4)
  if imgui.Button("+##common_hit") then
    K.COMMON.min_hit = math.min(100, K.COMMON.min_hit + 5)
    common_changed = true
  end
  if common_changed then
    save_data()
  end
  imgui.Separator()
  K.draw_vr_options()
  imgui.Separator()
  K.KC.draw_options()
  imgui.Separator()
  imgui.TextColored(0.75, 0.85, 1.0, 1, T("hist_columns_title"))
  local shown_columns = 0
  for _, col in ipairs(K.HCOLS) do
    if not col.fixed then
      if shown_columns % 5 ~= 0 then imgui.SameLine(0, 14) end
      local toggled, visible = imgui.Checkbox(K.hcol_label(col.id) .. "##hcol_" .. col.id, not K.HIDDEN_COLS[col.id])
      if toggled then
        K.HIDDEN_COLS[col.id] = (not visible) or nil
        K.refresh_hcols()
        save_data()
      end
      shown_columns = shown_columns + 1
    end
  end
  imgui.Separator()
  imgui.TextColored(0.75, 0.85, 1.0, 1, T("page_sizes_title"))
  K.draw_page_size_choice("counters", T("tab_counters"))
  K.draw_page_size_choice("history", T("tab_history"))
  K.draw_page_size_choice("games", T("tab_game"))
  imgui.Spacing()
  imgui.Spacing()
  imgui.Separator()
  draw_reset_block()
end

K.present_body = function()
  run_background_tasks()
  K.HOTKEY.poll()
  K.POPUP.draw()
  K.KC.draw()
  if not window_open then return end
  imgui.SetNextWindowPos(200, 200, 'FirstUseEver')
  imgui.SetNextWindowSize(1315, 560, 'FirstUseEver')
  local window_flags = {}
  if hide_title_bar then
    table.insert(window_flags, "NoTitleBar")
  end
  table.insert(window_flags, "HorizontalScrollbar")
  local bg_pushed = push_bg(bg_opacity)
  local status
  status, window_open = imgui.Begin("Hunter's Log Tracker##tableau4", window_open, window_flags)
  if status then
    imgui.TextColored(1, 0.2, 0.2, 1, T("total_found", total_global))
    imgui.SameLine(300)
    local auto_episode = get_auto_episode()
    if auto_episode then
      imgui.Text(T("episode") .. tostring(auto_episode) .. " (auto)")
    elseif imgui.Button(T("episode") .. tostring(episode)) then
      if episode == 1 then
        episode = 2
      elseif episode == 2 then
        episode = 4
      else
        episode = 1
      end
      save_data()
    end
    imgui.SameLine(560)
    draw_language_buttons()
    local zone_text = (get_current_floor() == K.LOBBY_FLOOR and K.lobby_since ~= nil) and "Lobby" or get_current_zone()
    imgui.Text(T("zone_current") .. loc(zone_text))
    imgui.SameLine(300)
    local window_difficulty, window_section = get_game_context()
    local sr, sg, sb = section_color(window_section)
    imgui.Text(T("difficulty") .. loc(window_difficulty) .. " | ID :")
    imgui.SameLine(0, 4)
    imgui.TextColored(sr, sg, sb, 1, loc(window_section))
    imgui.SameLine(0, 16)
    imgui.Text("DAR : " .. fmt_pct(game_dar_percent) .. " | RDR : " .. fmt_pct(game_rdr_percent) .. " | RER : " .. fmt_pct(game_rer_percent))
    if imgui.IsItemHovered() then
      imgui.BeginTooltip()
      imgui.Text(T("rates_legend"))
      imgui.Text(T("game_message"))
      if game_message_text ~= "" then
        imgui.Text(clip(game_message_text, 140))
      else
        imgui.TextDisabled(T("no_message"))
      end
      imgui.EndTooltip()
    end
    imgui.Separator()
    tab_button(T("tab_counters"), "counters")
    imgui.SameLine(0, 6)
    tab_button(T("tab_history"), "history")
    imgui.SameLine(0, 6)
    tab_button(T("tab_ids"), "ids")
    imgui.SameLine(0, 6)
    tab_button(T("tab_streaks"), "streaks")
    imgui.SameLine(0, 6)
    tab_button(T("tab_game"), "game")
    imgui.SameLine(0, 6)
    tab_button(K.CAREER.tab_label(), "career")
    imgui.SameLine(0, 6)
    tab_button(T("tab_popup"), "popup")
    imgui.SameLine(0, 6)
    local accent_pushed = 0
    if pcall(imgui.PushStyleColor, "Button", 0.62, 0.42, 0.05, 1.0) then
      accent_pushed = accent_pushed + 1
    end
    if pcall(imgui.PushStyleColor, "ButtonHovered", 0.80, 0.56, 0.10, 1.0) then
      accent_pushed = accent_pushed + 1
    end
    if pcall(imgui.PushStyleColor, "ButtonActive", 0.95, 0.68, 0.15, 1.0) then
      accent_pushed = accent_pushed + 1
    end
    tab_button(T("tab_help"), "help")
    for _ = 1, accent_pushed do pcall(imgui.PopStyleColor) end
    imgui.SameLine(0, 6)
    tab_button(T("tab_options"), "options")
    imgui.SameLine(0, 6)
    if imgui.Button(T("export_button")) then
      local path = export_to_file()
      if path then
        set_status(T("export_ok", path))
      else
        set_status(T("export_failed"), true)
      end
    end
    if ui_status.text and os.time() <= ui_status.expire then
      if ui_status.is_error then
        imgui.TextColored(1, 0.5, 0.3, 1, ui_status.text)
      else
        imgui.TextColored(0.5, 1, 0.5, 1, ui_status.text)
      end
    end
    imgui.Separator()
    local counters_needed = (current_tab == "counters" or current_tab == "history" or current_tab == "ids")
    if not counters_cache
      or (counters_needed and (counters_cache.rev ~= K.HIST_REV or counters_cache.count ~= #drop_history
        or frame_counter - counters_cache.frame >= 600)) then
      rebuild_counters_cache()
    end
    if current_tab == "counters" then
      draw_counters_tab()
    elseif current_tab == "history" then
      draw_history_tab()
    elseif current_tab == "streaks" then
      K.STREAK.draw_tab()
    elseif current_tab == "game" then
      K.GAMELOG.draw()
    elseif current_tab == "career" then
      K.CAREER.draw_tab()
    elseif current_tab == "popup" then
      K.POPUP.draw_tab()
    elseif current_tab == "help" then
      draw_help_tab()
    elseif current_tab == "options" then
      K.draw_options_tab()
    else
      draw_ids_tab()
    end
  end
  imgui.End()
  pop_bg(bg_pushed)
end

local present = K.present_body

local function init()
  if core_mainmenu then
    core_mainmenu.add_button("Hunter's Log", button_func)
  end
  return {
    name = "Hunter's Log",
    author = "Akhyrion",
    version = "1.0",
    description = "Tracker avec filtres d'unités, zones de drop et statut Tekked.",
    present = present,
    toggleable = true,
    enabled = true,
  }
end

return {
  __addon = {
    init = init
  }
}
