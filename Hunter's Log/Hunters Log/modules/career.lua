local imgui = require("imgui")

return function(K)
local C = { sub = 1, rev = 0, dirty = false, last_save = 0, ready = false, watch = {}, pending = nil, view = nil, mon = nil }
K.CAREER = C

local FILE = K.ADDON_DIR .. "career.lua"
local MIN_QUEST_SECONDS = 30
local WATCH_MAX = 200
local COL2 = 620
local FONT_SCALE = 1.0
local STATS_COLOR = { 0.5, 0.9, 1.0 }
local SLOTS = { "common_t", "common_u", "rare_t", "rare_u" }
local DIFF_ABBR = { [0] = "N", [1] = "H", [2] = "VH", [3] = "ULT" }

local loc, difficulty_loc, section_color
function C.bind(E)
  loc = E.loc
  difficulty_loc = E.difficulty_loc
  section_color = E.section_color
end

local function L(fr, en, ja)
  local code = K.U.lang.code
  if code == "ja" then return ja end
  if code == "en" then return en end
  return fr
end

function C.tab_label()
  return L("Carrière", "Career", "キャリア")
end

local function new_data()
  return {
    seeded = false, last_start = 0,
    found = { rare = 0, weapon = 0, armor = 0, veryrare = 0 },
    hit = {},     -- [slot] = { name, hit, stats, time }
    quests = {},
    diff_seeded = false,
    runs_seeded = false,
  }
end

local D = new_data()
C.data = D

local function mark()
  C.rev = C.rev + 1
  C.dirty = true
end

local function load_file()
  local f = io.open(FILE, "r")
  if not f then return false end
  local content = f:read("*all")
  f:close()
  local chunk = loadstring(content or "")
  if not chunk then return false end
  local ok, t = pcall(chunk)
  if not ok or type(t) ~= "table" then return false end
  local d = new_data()
  d.seeded = t.seeded == true
  d.last_start = tonumber(t.last_start) or 0
  d.diff_seeded = t.diff_seeded == true
  d.runs_seeded = t.runs_seeded == true
  if type(t.found) == "table" then
    for key in pairs(d.found) do d.found[key] = math.max(0, math.floor(tonumber(t.found[key]) or 0)) end
  end
  if type(t.hit) == "table" then
    for _, slot in ipairs(SLOTS) do
      local r = t.hit[slot]
      if type(r) == "table" and tonumber(r.h) then
        d.hit[slot] = { name = tostring(r.n or "?"), hit = tonumber(r.h), stats = tostring(r.s or ""), time = tonumber(r.t) or 0 }
      end
    end
  end
  if type(t.quests) == "table" then
    for name, r in pairs(t.quests) do
      if type(name) == "string" and type(r) == "table" then
        local items = {}
        if type(r.k) == "table" then
          for section, list in pairs(r.k) do
            if type(section) == "string" and type(list) == "table" then
              for item_name, n in pairs(list) do
                if type(item_name) == "string" and tonumber(n) and tonumber(n) > 0 then
                  items[section] = items[section] or {}
                  items[section][item_name] = math.floor(tonumber(n))
                end
              end
            end
          end
        end
        local runs = {}
        if type(r.r) == "table" then
          for key, n in pairs(r.r) do
            if type(key) == "string" and tonumber(n) and tonumber(n) > 0 then runs[key] = math.floor(tonumber(n)) end
          end
        end
        d.quests[name] = { p = math.max(0, math.floor(tonumber(r.p) or 0)), d = math.max(0, math.floor(tonumber(r.d) or 0)), items = items, runs = runs }
      end
    end
  end
  D = d
  C.data = d
  return true
end

local function save_file()
  local out = {}
  out[#out + 1] = string.format("return {\nseeded=%s,\ndiff_seeded=%s,\nruns_seeded=%s,\nlast_start=%d,\n", tostring(D.seeded), tostring(D.diff_seeded == true), tostring(D.runs_seeded == true), math.floor(D.last_start or 0))
  out[#out + 1] = string.format("found={rare=%d,weapon=%d,armor=%d,veryrare=%d},\nhit={\n",
    D.found.rare, D.found.weapon, D.found.armor, D.found.veryrare)
  for _, slot in ipairs(SLOTS) do
    local r = D.hit[slot]
    if r then
      out[#out + 1] = string.format("%s={n=%q,h=%d,s=%q,t=%d},\n", slot, r.name, math.floor(r.hit), r.stats, math.floor(r.time or 0))
    end
  end
  out[#out + 1] = "},\nquests={\n"
  for name, r in pairs(D.quests) do
    local sections = {}
    for section, list in pairs(r.items or {}) do
      local items = {}
      for item_name, n in pairs(list) do items[#items + 1] = string.format("[%q]=%d", item_name, n) end
      sections[#sections + 1] = string.format("[%q]={%s}", section, table.concat(items, ","))
    end
    local runs = {}
    for key, n in pairs(r.runs or {}) do runs[#runs + 1] = string.format("[%q]=%d", key, n) end
    out[#out + 1] = string.format("[%q]={p=%d,d=%d,k={%s},r={%s}},\n", name, r.p, r.d, table.concat(sections, ","), table.concat(runs, ","))
  end
  out[#out + 1] = "},\n}\n"
  local f = io.open(FILE, "w")
  if not f then return end
  f:write(table.concat(out))
  f:close()
  C.dirty = false
  C.last_save = os.time()
end

local function category(name, kind, stats)
  if kind == "weapon" then
    local filters = K.DATA_FILTERS
    local special = filters and filters.special_items
    if (special and special[string.lower(tostring(name))]) or K.VR.names[K.VR.key(name)] then return "veryrare" end
    if stats then
      local ok, vr = pcall(K.VR.hit_ok, name, stats)
      if ok and vr then return "veryrare" end
    end
    if K.COMMON.is_name(name) then return "common" end
    return "weapon"
  end
  return kind or "other"
end

local function parse_hit(stats)
  if type(stats) ~= "string" then return nil, false end
  local hit = string.match(stats, "%[%-?%d+/%-?%d+/%-?%d+/%-?%d+|(%-?%d+)%]")
  return tonumber(hit), string.find(stats, "UNTEKKED", 1, true) ~= nil
end

local function put_hit(slot, name, hit, stats, time)
  local cur = D.hit[slot]
  if cur and cur.hit >= hit then return false end
  D.hit[slot] = { name = tostring(name), hit = hit, stats = tostring(stats or ""), time = time or os.time() }
  mark()
  return true
end

local function record_hit(name, common, stats, time, key, allow_watch)
  local hit, untekked = parse_hit(stats)
  if not hit then return end
  local slot = (common and "common" or "rare") .. (untekked and "_u" or "_t")
  put_hit(slot, name, hit, stats, time)
  if untekked and key and allow_watch then
    local w = C.watch
    w[#w + 1] = { key = key, name = name, common = common }
    if #w > WATCH_MAX then table.remove(w, 1) end
  end
end

local function count_found(cat, kind, n)
  local f = D.found
  if cat ~= "common" then f.rare = f.rare + n end
  if kind == "weapon" and (cat == "weapon" or cat == "veryrare") then f.weapon = f.weapon + n end
  if kind == "armor" then f.armor = f.armor + n end
  if cat == "veryrare" then f.veryrare = f.veryrare + n end
end

local function quest_entry(name)
  local q = D.quests[name]
  if not q then
    q = { p = 0, d = 0, items = {}, runs = {} }
    D.quests[name] = q
  end
  if not q.items then q.items = {} end
  if not q.runs then q.runs = {} end
  return q
end

local function section_of(section, difficulty)
  local label = tostring(section or "?")
  label = string.gsub(label, "%s*%(perso%)%s*$", "")
  if label == "" then label = "?" end
  local index = -1
  for i, name in pairs(K.GAME_DATA.difficulty_labels) do
    if name == difficulty then index = i end
  end
  return label .. "|" .. tostring(index)
end

local function draw_id_tag(section, diff)
  local r, g, b = 1, 1, 1
  if section_color then r, g, b = section_color(section) end
  imgui.TextColored(r, g, b, 1, loc(section))
  local dc = (K.STREAK and K.STREAK.sort and K.STREAK.sort.diff_colors[diff]) or { 1, 1, 1 }
  imgui.SameLine(0, 6)
  imgui.TextColored(dc[1], dc[2], dc[3], 1, DIFF_ABBR[diff] or "?")
end

local function add_item(items, section, name, n)
  local list = items[section]
  if not list then list = {}; items[section] = list end
  list[name] = (list[name] or 0) + (n or 1)
end

function C.on_drop(h, stats)
  if not C.ready or type(h) ~= "table" then return end
  pcall(function()
    local cat = category(h.name, h.kind, stats)
    count_found(cat, h.kind, 1)
    if h.kind == "weapon" then
      record_hit(h.name, cat == "common", stats, h.time, h.key, true)
    end
    if cat ~= "common" then
      local games = K.GAMELOG and K.GAMELOG.games
      local cur = games and games[1]
      if cur and not cur.ended and cur.name then
        if D.last_start == cur.start then
          local q = quest_entry(cur.name)
          q.d = q.d + 1
          add_item(q.items, section_of(cur.section, cur.difficulty), h.name)
        else
          if not C.pending or C.pending.start ~= cur.start then C.pending = { start = cur.start, n = 0, items = {} } end
          C.pending.n = C.pending.n + 1
          add_item(C.pending.items, section_of(cur.section, cur.difficulty), h.name)
        end
      end
    end
    mark()
  end)
end

-- Best hit of a slot, rebuilt from what is still in the history and in the archive.
local function rebuild_hit_slot(slot)
  D.hit[slot] = nil
  local details = K.U.details()
  for _, h in ipairs(K.U.drop_history()) do
    if h.kind == "weapon" then
      local d = h.key and details[h.key]
      local stats = d and d.stats
      local hit, untekked = parse_hit(stats)
      if hit then
        local common = category(h.name, h.kind, stats) == "common"
        if (common and "common" or "rare") .. (untekked and "_u" or "_t") == slot then
          put_hit(slot, h.name, hit, stats, h.time)
        end
      end
    end
  end
  local archive = K.ARCHIVE
  if archive then
    local from_untekked = string.sub(slot, -2) == "_u"
    local best = from_untekked and archive.best_u or archive.best
    for name, rec in pairs(best or {}) do
      local hit = rec.values and tonumber(rec.values[5])
      local common = K.COMMON.is_name(name)
      if hit and ((common and "common" or "rare") .. (from_untekked and "_u" or "_t")) == slot then
        put_hit(slot, name, hit, string.format("[%d/%d/%d/%d|%d]", rec.values[1], rec.values[2], rec.values[3], rec.values[4], hit), 0)
      end
    end
  end
end

-- A history line was deleted (already removed from the history): undo what it added to the career.
function C.on_delete(h, stats)
  if not C.ready or type(h) ~= "table" then return end
  pcall(function()
    local cat = category(h.name, h.kind, stats)
    count_found(cat, h.kind, -1)
    for key, value in pairs(D.found) do
      if value < 0 then D.found[key] = 0 end
    end
    if h.kind == "weapon" then
      local hit, untekked = parse_hit(stats)
      if hit then
        local slot = (cat == "common" and "common" or "rare") .. (untekked and "_u" or "_t")
        local cur = D.hit[slot]
        if cur and cur.name == tostring(h.name) and cur.hit == hit then rebuild_hit_slot(slot) end
      end
    end
    if cat ~= "common" then
      local games = K.GAMELOG and K.GAMELOG.games or {}
      local t = tonumber(h.time) or 0
      for i, g in ipairs(games) do
        local last = g.ended_at and (g.ended_at + (K.GAMELOG_DROP_GRACE or 15)) or math.huge
        local newer = games[i - 1]
        if newer then last = math.min(last, newer.start - 1) end
        if g.name and g.start <= t and t <= last then
          local q = D.quests[g.name]
          local list = q and q.items and q.items[section_of(g.section, g.difficulty)]
          if list and (list[h.name] or 0) > 0 then
            q.d = math.max(0, q.d - 1)
            list[h.name] = list[h.name] - 1
            if list[h.name] <= 0 then list[h.name] = nil end
          end
          break
        end
      end
    end
    mark()
    save_file()
  end)
end

local function seed()
  local details = K.U.details()
  local hist = K.U.drop_history()
  for _, h in ipairs(hist) do
    local d = h.key and details[h.key]
    local stats = d and d.stats
    local cat = category(h.name, h.kind, stats)
    count_found(cat, h.kind, 1)
    if h.kind == "weapon" then record_hit(h.name, cat == "common", stats, h.time, nil, false) end
  end
  local kinds = K.U.item_kinds()
  local archive = K.ARCHIVE
  if archive then
    for _, rec in ipairs(archive.list) do
      local kind = kinds[rec.name]
      count_found(category(rec.name, kind, nil), kind, math.floor(tonumber(rec.n) or 0))
    end
    for _, pair in ipairs({ { archive.best, "_t" }, { archive.best_u, "_u" } }) do
      for name, rec in pairs(pair[1] or {}) do
        local hit = rec.values and tonumber(rec.values[5])
        if hit then
          local common = K.COMMON.is_name(name)
          put_hit((common and "common" or "rare") .. pair[2], name, hit, string.format("[%d/%d/%d/%d|%d]",
            rec.values[1], rec.values[2], rec.values[3], rec.values[4], hit), 0)
        end
      end
    end
  end
  local games = K.GAMELOG and K.GAMELOG.games or {}
  local sorted = {}
  for _, h in ipairs(hist) do
    local d = h.key and details[h.key]
    if category(h.name, h.kind, d and d.stats) ~= "common" then sorted[#sorted + 1] = tonumber(h.time) or 0 end
  end
  table.sort(sorted)
  local function first_index(t)
    local lo, hi = 1, #sorted + 1
    while lo < hi do
      local mid = math.floor((lo + hi) / 2)
      if sorted[mid] < t then lo = mid + 1 else hi = mid end
    end
    return lo
  end
  for i, g in ipairs(games) do
    if g.name and g.ended and g.ended_at and g.ended_at - g.start >= MIN_QUEST_SECONDS then
      local q = quest_entry(g.name)
      q.p = q.p + 1
      local run_key = section_of(g.section, g.difficulty)
      q.runs[run_key] = (q.runs[run_key] or 0) + 1
      local last = g.ended_at + (K.GAMELOG_DROP_GRACE or 15)
      local newer = games[i - 1]
      if newer then last = math.min(last, newer.start - 1) end
      local idx = first_index(g.start)
      while sorted[idx] and sorted[idx] <= last do
        q.d = q.d + 1
        idx = idx + 1
      end
    end
  end
  local first = games[1]
  if first and first.ended and first.name and first.ended_at and first.ended_at - first.start >= MIN_QUEST_SECONDS then
    D.last_start = first.start
  end
  D.seeded = true
  mark()
  save_file()
end

local function seed_items()
  local details = K.U.details()
  local hist = K.U.drop_history()
  local games = K.GAMELOG and K.GAMELOG.games or {}
  local entries = {}
  for _, h in ipairs(hist) do
    local d = h.key and details[h.key]
    if category(h.name, h.kind, d and d.stats) ~= "common" then entries[#entries + 1] = { t = tonumber(h.time) or 0, name = h.name } end
  end
  table.sort(entries, function(a, b) return a.t < b.t end)
  local function first_index(t)
    local lo, hi = 1, #entries + 1
    while lo < hi do
      local mid = math.floor((lo + hi) / 2)
      if entries[mid].t < t then lo = mid + 1 else hi = mid end
    end
    return lo
  end
  for _, q in pairs(D.quests) do q.items = {}; q.runs = {} end
  for i, g in ipairs(games) do
    if g.name and g.ended and g.ended_at and g.ended_at - g.start >= MIN_QUEST_SECONDS then
      local q = quest_entry(g.name)
      local run_key = section_of(g.section, g.difficulty)
      q.runs[run_key] = (q.runs[run_key] or 0) + 1
      local last = g.ended_at + (K.GAMELOG_DROP_GRACE or 15)
      local newer = games[i - 1]
      if newer then last = math.min(last, newer.start - 1) end
      local idx = first_index(g.start)
      while entries[idx] and entries[idx].t <= last do
        add_item(q.items, section_of(g.section, g.difficulty), entries[idx].name)
        idx = idx + 1
      end
    end
  end
  D.diff_seeded = true
  D.runs_seeded = true
  mark()
  save_file()
end

local function init_watch()
  local details = K.U.details()
  local hist = K.U.drop_history()
  local from = math.max(1, #hist - 400)
  for i = from, #hist do
    local h = hist[i]
    if h.kind == "weapon" and h.key then
      local d = details[h.key]
      if d and d.stats and string.find(d.stats, "UNTEKKED", 1, true) then
        C.watch[#C.watch + 1] = { key = h.key, name = h.name, common = K.COMMON.is_name(h.name) }
      end
    end
  end
end

local function check_watch()
  local details = K.U.details()
  local w = C.watch
  for i = #w, 1, -1 do
    local entry = w[i]
    local d = details[entry.key]
    if not d then
      table.remove(w, i)
    elseif d.stats and not string.find(d.stats, "UNTEKKED", 1, true) then
      local hit = parse_hit(d.stats)
      local current_name = d.name or entry.name
      if hit then put_hit(entry.common and "common_t" or "rare_t", current_name, hit, d.stats, d.time) end
      table.remove(w, i)
    end
  end
end

local function reconcile_names()
  local rec = D.hit and D.hit.common_t
  if not rec or not rec.stats or rec.stats == "" then return end
  local details = K.U.details()
  local hist = K.U.drop_history()
  for i = #hist, 1, -1 do
    local h = hist[i]
    local d = h.key and details[h.key]
    if d and d.stats == rec.stats and d.name and d.name ~= rec.name
      and K.COMMON.is_name(d.name) and K.COMMON.is_name(rec.name)
      and K.COMMON.base(d.name) == K.COMMON.base(rec.name) then
      rec.name = tostring(d.name)
      mark()
      return
    end
  end
end

local function check_quest()
  local games = K.GAMELOG and K.GAMELOG.games
  local cur = games and games[1]
  if not cur or cur.ended or not cur.name then return end
  if D.last_start == cur.start then return end
  if os.time() - cur.start < MIN_QUEST_SECONDS then return end
  D.last_start = cur.start
  local q = quest_entry(cur.name)
  q.p = q.p + 1
  local run_key = section_of(cur.section, cur.difficulty)
  q.runs[run_key] = (q.runs[run_key] or 0) + 1
  if C.pending and C.pending.start == cur.start then
    q.d = q.d + C.pending.n
    for section, list in pairs(C.pending.items or {}) do
      for item_name, n in pairs(list) do add_item(q.items, section, item_name, n) end
    end
  end
  C.pending = nil
  mark()
end

function C.update()
  local frame = K.U.frame()
  if not C.ready then
    if frame < 120 then return end
    pcall(load_file)
    pcall(init_watch)
    pcall(reconcile_names)
    C.ready = true
    if not D.seeded then pcall(seed) end
    if not D.diff_seeded or not D.runs_seeded then pcall(seed_items) end
    return
  end
  if frame % 30 ~= 11 then return end
  pcall(check_quest)
  if #C.watch > 0 then pcall(check_watch) end
  if C.dirty and os.time() - C.last_save >= 10 then save_file() end
end

local RARE_MONSTERS = {
  "Hildeblue", "Al Rappy", "Nar Lily", "Pouilly Slime", "Love Rappy", "St Rappy", "Hallo Rappy",
  "Halo Rappy", "Egg Rappy", "Del Rappy",
}
local RARE_SET
local BOSS_NAMES = {
  "dragon", "derolle", "volopt", "darkfalz", "barbaray", "goldragon", "galgryphon", "olgaflow",
  "saintmillion", "saintmilion", "shambertin", "kondrieu",
}
local BOSS_SET = {}
for _, name in ipairs(BOSS_NAMES) do BOSS_SET[name] = true end
local PARSED = {}

local function parse_key(key)
  local p = PARSED[key]
  if p == nil then
    local diff, _, sec, mon = string.match(key, "^(%d+)|(%d+)|([^|]+)|(.+)$")
    if diff then
      if not RARE_SET then
        RARE_SET = {}
        for _, name in ipairs(RARE_MONSTERS) do RARE_SET[K.KEYALIAS.norm(name)] = true end
      end
      local base = (string.gsub(mon, " E2$", ""))
      local plain = string.gsub(string.lower(base), "[^%w]", "")
      p = { diff = tonumber(diff), sec = sec, mon = mon, rare = RARE_SET[K.KEYALIAS.norm(base)] == true, boss = BOSS_SET[plain] == true }
    else
      p = false
    end
    PARSED[key] = p
  end
  return p
end

local function rebuild_monsters()
  local M = C.mon
  if not M then
    M = { grid = {}, row_total = {}, col_total = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 } }
    for _, sec in ipairs(K.GAME_DATA.section_list) do
      M.grid[sec] = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }
      M.row_total[sec] = 0
    end
    C.mon = M
  end
  for _, sec in ipairs(K.GAME_DATA.section_list) do
    local row = M.grid[sec]
    row[0], row[1], row[2], row[3] = 0, 0, 0, 0
    M.row_total[sec] = 0
  end
  for d = 0, 3 do M.col_total[d] = 0 end
  local total, rare_total, boss_total = 0, 0, 0
  local best_p, best_n, rbest_p, rbest_n, bbest_p, bbest_n = nil, 0, nil, 0, nil, 0
  for key, count in pairs(K.U.kill_totals()) do
    local p = parse_key(key)
    count = tonumber(count) or 0
    if p and count > 0 then
      total = total + count
      if p.rare then
        rare_total = rare_total + count
        if count > rbest_n then rbest_p, rbest_n = p, count end
      end
      if p.boss then
        boss_total = boss_total + count
        if count > bbest_n then bbest_p, bbest_n = p, count end
      end
      if count > best_n then best_p, best_n = p, count end
      local row = M.grid[p.sec]
      if row and row[p.diff] then
        row[p.diff] = row[p.diff] + count
        M.row_total[p.sec] = M.row_total[p.sec] + count
        M.col_total[p.diff] = M.col_total[p.diff] + count
      end
    end
  end
  M.total, M.rare_total, M.boss_total = total, rare_total, boss_total
  M.bbest_p, M.bbest_n = bbest_p, bbest_n
  M.best_p, M.best_n, M.rbest_p, M.rbest_n = best_p, best_n, rbest_p, rbest_n
  M.frame = K.U.frame()
  M.lang = K.U.lang.code
end

local ENEMIES
local function monster_info(p, n)
  if not p then return nil end
  if ENEMIES == nil then
    local ok, mod = pcall(require, "Hunters Log.charts.Enemies")
    ENEMIES = (ok and type(mod) == "table") and mod or false
  end
  local name = ENEMIES and K.KEYALIAS.label(ENEMIES, p.mon, p.diff) or nil
  if name then
    if string.find(p.mon, " E2$") and not string.find(name, " E2$") then name = name .. " E2" end
  else
    name = p.mon
  end
  return { name = loc(name), sec = p.sec, diff = difficulty_loc(K.GAME_DATA.difficulty_labels[p.diff]), di = p.diff, n = n }
end

local function hit_text(r)
  if not r then return "-", "" end
  local stats = string.match(r.stats or "", "%[%-?%d+/%-?%d+/%-?%d+/%-?%d+|%-?%d+%]") or ""
  local grind = string.match(r.stats or "", "%+%d+")
  if grind and stats ~= "" then stats = grind .. " " .. stats end
  local name = K.COMMON.is_name(r.name) and K.COMMON.full_label(r.name) or K.U.iname(r.name)
  return name, stats
end

local function rebuild_view()
  local V = { rev = C.rev, lang = K.U.lang.code, mon_frame = C.mon and C.mon.frame }
  local f = D.found
  V.found = {
    { L("Objets rares trouvés :", "Rare items found:", "レアアイテム入手数:"), tostring(f.rare) },
    { L("Armes rares trouvées :", "Rare weapons found:", "レア武器入手数:"), tostring(f.weapon) },
    { L("Armures / Barriers trouvés :", "Armors / Barriers found:", "防具・バリア入手数:"), tostring(f.armor) },
    { L("Objets très rares trouvés :", "Very rare items found:", "超レア入手数:"), tostring(f.veryrare) },
  }
  V.hits = {}
  local hit_defs = {
    { "common_t", L("Arme commune tekkée :", "Common weapon (tekked):", "コモン武器(鑑定済):") },
    { "common_u", L("Arme commune non tekkée :", "Common weapon (untekked):", "コモン武器(未鑑定):") },
    { "rare_t", L("Arme rare tekkée :", "Rare weapon (tekked):", "レア武器(鑑定済):") },
    { "rare_u", L("Arme rare non tekkée :", "Rare weapon (untekked):", "レア武器(未鑑定):") },
  }
  for i, def in ipairs(hit_defs) do
    local text, stats = hit_text(D.hit[def[1]])
    V.hits[i] = { def[2], text, stats, def[1] }
  end
  local M = C.mon
  V.best = M and monster_info(M.best_p, M.best_n) or nil
  V.rbest = M and monster_info(M.rbest_p, M.rbest_n) or nil
  V.bbest = M and monster_info(M.bbest_p, M.bbest_n) or nil
  local list = {}
  for name, q in pairs(D.quests) do list[#list + 1] = { name = name, p = q.p, d = q.d, items = q.items, runs = q.runs } end
  table.sort(list, function(a, b)
    if a.p ~= b.p then return a.p > b.p end
    if a.d ~= b.d then return a.d > b.d end
    return a.name < b.name
  end)
  V.top = {}
  for i = 1, math.min(15, #list) do
    local q = list[i]
    local shown = q.name
    if K.GAMELOG and K.GAMELOG.display_name then shown = K.GAMELOG.display_name(q.name) or q.name end
    local drops = {}
    for key, list in pairs(q.items or {}) do
      local section, di = string.match(key, "^(.*)|(%-?%d+)$")
      local column = { section = section or key, diff = tonumber(di) or -1, total = 0, items = {} }
      for item_name, n in pairs(list) do
        column.items[#column.items + 1] = { name = item_name, n = n }
        column.total = column.total + n
      end
      table.sort(column.items, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
      end)
      if #column.items > 0 then drops[#drops + 1] = column end
    end
    table.sort(drops, function(a, b)
      if a.total ~= b.total then return a.total > b.total end
      if a.section ~= b.section then return a.section < b.section end
      return a.diff < b.diff
    end)
    local runs = {}
    for key, n in pairs(q.runs or {}) do
      local section, di = string.match(key, "^(.*)|(%-?%d+)$")
      runs[#runs + 1] = { section = section or key, diff = tonumber(di) or -1, n = n }
    end
    table.sort(runs, function(a, b)
      if a.n ~= b.n then return a.n > b.n end
      if a.section ~= b.section then return a.section < b.section end
      return a.diff < b.diff
    end)
    V.top[i] = {
      string.format("%d. %s : ", i, shown),
      string.format("%d %s", q.d, L("drops", "drops", "ドロップ")),
      drops,
      string.format("%d %s", q.p, L("lancées", "started", "回")),
      runs,
    }
  end
  C.view = V
end

local YELLOW = { 1.0, 0.9, 0.2 }

local function label_value(label, value, r, g, b)
  imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, label)
  imgui.SameLine(0, 6)
  imgui.TextColored(r or 1, g or 1, b or 1, 1, value)
end

local function hsv_rgb(h)
  local sector = math.floor(h * 6)
  local f = h * 6 - sector
  local q, t = 1 - f * 0.8, 1 - (1 - f) * 0.8
  sector = sector % 6
  if sector == 0 then return 1, t, 0.2 end
  if sector == 1 then return q, 1, 0.2 end
  if sector == 2 then return 0.2, 1, t end
  if sector == 3 then return 0.2, q, 1 end
  if sector == 4 then return t, 0.2, 1 end
  return 1, 0.2, q
end

local function rainbow_text(text)
  local now = os.clock()
  local index = 0
  for char in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
    local r, g, b = hsv_rgb((now * 0.3 + index * 0.08) % 1)
    if index > 0 then imgui.SameLine(0, 0) end
    imgui.TextColored(r, g, b, 1, char)
    index = index + 1
  end
end

local function draw_monster(m, mode)
  if not m then
    imgui.Text("   -")
    return
  end
  imgui.Text("  ")
  imgui.SameLine(0, 0)
  if mode == "red" then
    imgui.TextColored(1, 0.25, 0.25, 1, m.name)
  elseif mode == "rainbow" then
    rainbow_text(m.name)
  else
    imgui.Text(m.name)
  end
  imgui.SameLine(0, 6)
  imgui.TextColored(0.6, 0.6, 0.6, 1, "|")
  imgui.SameLine(0, 6)
  local r, g, b = section_color(m.sec)
  imgui.TextColored(r, g, b, 1, loc(m.sec))
  imgui.SameLine(0, 6)
  imgui.TextColored(0.6, 0.6, 0.6, 1, "|")
  imgui.SameLine(0, 6)
  local dc = K.STREAK.sort.diff_colors[m.di] or YELLOW
  imgui.TextColored(dc[1], dc[2], dc[3], 1, m.diff)
  imgui.SameLine(0, 6)
  imgui.TextColored(0.6, 0.6, 0.6, 1, "|")
  imgui.SameLine(0, 6)
  imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, tostring(m.n))
end

local function draw_hit_name(e)
  imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, e[1])
  imgui.SameLine(0, 6)
  local record = D.hit[e[4]]
  if record and K.U.kind_color and K.COMMON.draw_name then
    local ok = pcall(function()
      local kind = "weapon"
      local vr_ok, vr = pcall(K.VR.hit_ok, record.name, record.stats)
      if vr_ok and vr then kind = "veryrare" end
      local c = K.U.kind_color(kind, record.name)
      K.COMMON.draw_name(K.U.iname(record.name), c)
    end)
    if ok then return end
  end
  imgui.TextColored(1, 1, 1, 1, e[2])
end

local function draw_hit_stats(e)
  if e[3] == "" then return end
  imgui.SameLine(0, 10)
  local record = D.hit[e[4]]
  local draw = K.U.draw_stats_cell
  if draw and record then
    local stats = record.stats or ""
    if string.sub(e[4], -2) == "_u" and not string.find(stats, "UNTEKKED", 1, true) then stats = "[UNTEKKED] " .. stats end
    if pcall(draw, { name = record.name, stats = stats }) then return end
  end
  imgui.TextColored(STATS_COLOR[1], STATS_COLOR[2], STATS_COLOR[3], 1, e[3])
end

local GRAY = { 0.45, 0.45, 0.45 }

local function draw_drops()
  local V = C.view
  local left_rows = 16
  for i = 1, left_rows do
    if i == 1 then
      imgui.TextColored(0.6, 0.85, 1, 1, L("Records", "Records", "記録"))
    elseif i >= 2 and i <= 5 then
      local e = V.found[i - 1]
      label_value(e[1], e[2], 1, 1, 1)
    elseif i == 6 then
      imgui.TextColored(0.6, 0.85, 1, 1, L("Meilleur hit", "Best hit", "最高ヒット"))
    elseif i >= 7 and i <= 10 then
      local e = V.hits[i - 6]
      draw_hit_name(e)
      draw_hit_stats(e)
    elseif i == 11 then
      imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, L("Monstre le plus tué :", "Most killed monster:", "最多撃破モンスター:"))
    elseif i == 12 then
      draw_monster(V.best)
    elseif i == 13 then
      imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, L("Monstre rare le plus tué :", "Most killed rare monster:", "最多撃破レアモンスター:"))
    elseif i == 14 then
      draw_monster(V.rbest, "rainbow")
    elseif i == 15 then
      imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, L("Boss le plus tué :", "Most killed boss:", "最多撃破ボス:"))
    else
      draw_monster(V.bbest, "red")
    end
    imgui.SameLine(COL2 - 18)
    imgui.TextColored(GRAY[1], GRAY[2], GRAY[3], 1, "|")
    if i == 1 then
      imgui.SameLine(COL2)
      imgui.TextColored(0.6, 0.85, 1, 1, L("Top 15 des quêtes (lancées 30 s+)", "Top 15 quests (started, 30 s+)", "クエスト上位15 (30秒以上)"))
    elseif i >= 2 and i <= 16 then
      local line = V.top[i - 1]
      if line then
        imgui.SameLine(COL2)
        imgui.Text(line[1])
        imgui.SameLine(0, 0)
        imgui.TextColored(0.5, 1, 0.5, 1, line[4])
        if line[5] and #line[5] > 0 and imgui.IsItemHovered() then
          imgui.BeginTooltip()
          for _, run in ipairs(line[5]) do
            draw_id_tag(run.section, run.diff)
            imgui.SameLine(0, 6)
            imgui.Text("x" .. tostring(run.n))
          end
          imgui.EndTooltip()
        end
        imgui.SameLine(0, 0)
        imgui.Text(",")
        imgui.SameLine(0, 5)
        imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, line[2])
        if line[3] and #line[3] > 0 and imgui.IsItemHovered() then
          imgui.BeginTooltip()
          local kinds = K.U.item_kinds()
          local columns = line[3]
          local function width_of(text)
            local ok_w, w = pcall(imgui.CalcTextSize, text)
            return (ok_w and tonumber(w)) or (#text * 7)
          end
          local function item_text(drop)
            local ok_name, shown_name = pcall(K.U.iname, drop.name)
            return tostring(ok_name and shown_name or drop.name) .. " x" .. tostring(drop.n)
          end
          local xs, x, rows = {}, 0, 0
          for c, column in ipairs(columns) do
            xs[c] = x
            local w = width_of(loc(column.section) .. " " .. (DIFF_ABBR[column.diff] or "?"))
            for _, drop in ipairs(column.items) do w = math.max(w, width_of(item_text(drop))) end
            x = x + w + 24
            rows = math.max(rows, #column.items)
          end
          if #columns > 1 then
            for c, column in ipairs(columns) do
              if c > 1 then imgui.SameLine(xs[c]) end
              draw_id_tag(column.section, column.diff)
            end
            imgui.Separator()
          end
          for row = 1, rows do
            for c, column in ipairs(columns) do
              if c > 1 then imgui.SameLine(xs[c]) end
              local drop = column.items[row]
              if drop then
                local ok_color, color = pcall(K.U.kind_color, kinds[drop.name], drop.name)
                if ok_color and type(color) == "table" then
                  imgui.TextColored(color[1], color[2], color[3], 1, item_text(drop))
                else
                  imgui.Text(item_text(drop))
                end
              else
                imgui.Text(" ")
              end
            end
          end
          imgui.EndTooltip()
        end
      end
    end
    if i ~= 11 and i ~= 13 and i ~= 15 then imgui.Separator() end
  end
  if #V.top == 0 then
    imgui.TextDisabled(L("Aucune quête enregistrée pour l'instant.", "No quest recorded yet.", "記録されたクエストはまだありません。"))
  end
end

local function draw_kills()
  local M = C.mon
  local function total_line(label, value, mode)
    imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, label)
    imgui.SameLine(0, 6)
    local text = tostring(value)
    if mode == "rainbow" then
      rainbow_text(text)
    elseif mode == "red" then
      imgui.TextColored(1.0, 0.25, 0.25, 1, text)
    else
      imgui.TextColored(1, 1, 1, 1, text)
    end
  end
  total_line(L("Total monstres tués :", "Total monsters killed:", "総撃破数:"), M.total, nil)
  imgui.Separator()
  total_line(L("Total monstres rares tués :", "Total rare monsters killed:", "レアモンスター総撃破数:"), M.rare_total, "rainbow")
  imgui.Separator()
  total_line(L("Total boss tués :", "Total bosses killed:", "ボス総撃破数:"), M.boss_total, "red")
  imgui.Separator()
  local xs = { 170, 300, 430, 560 }
  imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, "ID")
  for d = 0, 3 do
    imgui.SameLine(xs[d + 1])
    imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, difficulty_loc(K.GAME_DATA.difficulty_labels[d]))
  end
  imgui.SameLine(700)
  imgui.TextColored(YELLOW[1], YELLOW[2], YELLOW[3], 1, "Total")
  imgui.Separator()
  for _, sec in ipairs(K.GAME_DATA.section_list) do
    local r, g, b = section_color(sec)
    imgui.TextColored(r, g, b, 1, loc(sec))
    local row = M.grid[sec]
    for d = 0, 3 do
      imgui.SameLine(xs[d + 1])
      imgui.Text(tostring(row[d]))
    end
    imgui.SameLine(700)
    imgui.Text(tostring(M.row_total[sec]))
  end
  imgui.Separator()
  imgui.Text("Total")
  for d = 0, 3 do
    imgui.SameLine(xs[d + 1])
    imgui.Text(tostring(M.col_total[d]))
  end
  imgui.SameLine(700)
  imgui.Text(tostring(M.total))
end

function C.draw_tab()
  if not C.ready then
    imgui.TextDisabled(L("Chargement...", "Loading...", "読み込み中..."))
    return
  end
  local frame = K.U.frame()
  local M = C.mon
  if not M or not M.frame or frame - M.frame >= 60 or M.frame > frame or M.lang ~= K.U.lang.code then
    rebuild_monsters()
    M = C.mon
  end
  local V = C.view
  if not V or V.rev ~= C.rev or V.lang ~= K.U.lang.code or V.mon_frame ~= M.frame then
    rebuild_view()
    V = C.view
  end
  pcall(imgui.SetWindowFontScale, FONT_SCALE)
  local pushed_spacing = pcall(imgui.PushStyleVar, "ItemSpacing", 8, 7)
  local labels = {
    L("Drops / Quêtes", "Drops / Quests", "ドロップ / クエスト"),
    L("Monstres tués", "Monsters killed", "撃破モンスター"),
  }
  for i = 1, 2 do
    if i > 1 then imgui.SameLine(0, 6) end
    local text = (C.sub == i) and ("[" .. labels[i] .. "]") or labels[i]
    if imgui.Button(text .. "##career_sub_" .. i) then C.sub = i end
  end
  imgui.Separator()
  local ok, err = pcall(function()
    if C.sub == 1 then draw_drops() else draw_kills() end
  end)
  if pushed_spacing then pcall(imgui.PopStyleVar) end
  pcall(imgui.SetWindowFontScale, 1.0)
  if not ok then error(err, 0) end
end

end
