-- Hunter's Log : module "killcounter" (kill counter window), loaded by K.load_code in init.lua
local imgui = require("imgui")

return function(K)
K.KC = { session = {} }
K.KC.defaults = {
  enabled = false, transparent = false, no_move = false, no_resize = false, no_title = false,
  headers = true, hide_zero = false, hide_menu = false, opacity = 85, scale = 85, pos_x = 2.0, pos_y = 30.0, max_height = 90, hide_scrollbar = false,
}
K.KC.limits = { opacity = { 0, 100 }, scale = { 60, 200 }, pos_x = { 0, 100 }, pos_y = { 0, 100 }, max_height = { 30, 100 } }
K.KC.keys = { "enabled", "transparent", "no_move", "no_resize", "no_title", "headers", "hide_zero", "hide_menu", "opacity", "scale", "pos_x", "pos_y", "max_height", "hide_scrollbar" }
K.KC.cfg = {}
for key, value in pairs(K.KC.defaults) do K.KC.cfg[key] = value end

function K.KC.apply(tbl)
  local cfg = {}
  for key, default in pairs(K.KC.defaults) do
    local value = default
    if type(tbl) == "table" and type(tbl[key]) == type(default) then
      value = tbl[key]
      local limit = K.KC.limits[key]
      if limit then value = math.max(limit[1], math.min(limit[2], value)) end
    end
    cfg[key] = value
  end
  K.KC.cfg = cfg
end

function K.KC.serialize()
  local parts = {}
  for _, key in ipairs(K.KC.keys) do
    local value = K.KC.cfg[key]
    if key == "pos_x" or key == "pos_y" then value = string.format("%.1f", value) end
    parts[#parts + 1] = key .. "=" .. tostring(value)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local item_color
local KEYALIAS, MONSTER_INFO, T, ZONES, clip, difficulty_labels, difficulty_modules, get_drop_history, format_luck, format_odds, get_current_floor, get_current_zone, get_rare_keys, get_section_index, kill_context_prefix, lang, load_module, loc, save_data, section_color, streak_color, streak_odds, streak_sort
function K.KC.bind(E)
  KEYALIAS = E.KEYALIAS
  item_color = E.item_color
  MONSTER_INFO = E.MONSTER_INFO
  T = E.T
  ZONES = E.ZONES
  clip = E.clip
  difficulty_labels = E.difficulty_labels
  difficulty_modules = E.difficulty_modules
  get_drop_history = E.get_drop_history
  format_luck = E.format_luck
  format_odds = E.format_odds
  get_current_floor = E.get_current_floor
  get_current_zone = E.get_current_zone
  get_rare_keys = E.get_rare_keys
  get_section_index = E.get_section_index
  kill_context_prefix = E.kill_context_prefix
  lang = E.lang
  load_module = E.load_module
  loc = E.loc
  save_data = E.save_data
  section_color = E.section_color
  streak_color = E.streak_color
  streak_odds = E.streak_odds
  streak_sort = E.streak_sort
end

function K.KC.L(fr, en, ja)
  if lang.code == "ja" then return ja end
  if lang.code == "en" then return en end
  return fr
end

function K.KC.build()
  local prefix, ep = kill_context_prefix()
  if not prefix then return nil end
  local difficulty = tonumber(string.match(prefix, "^(%d+)|"))
  local section_label = string.match(prefix, "^%d+|%d+|([^|]+)|")
  local section_index = get_section_index()
  if not difficulty or not section_label or not section_index then return nil end
  local zone_name = get_current_zone()
  local function find_entry(name)
    for _, zone in ipairs(ZONES.all_entries) do
      if zone.ep == ep then
        for _, floor_name in ipairs(zone.floors) do
          if floor_name == name then return zone end
        end
      end
    end
    return nil
  end
  local entry = find_entry(zone_name)
  local game = K.GAMELOG.games[1]
  if entry then
    K.KC.last = { game = game, ep = ep, zone = zone_name }
  else
    local last = K.KC.last
    if get_current_floor() == 0 and last and last.game == game and last.ep == ep and not (game and game.lost) then
      zone_name = last.zone
      entry = find_entry(zone_name)
    end
  end
  local result = { zone = zone_name, section = section_label, difficulty = difficulty, rows = {}, has_zone = entry ~= nil }
  local modules = difficulty_modules[difficulty]
  local rares = modules and load_module(modules.rares)
  if not entry or not rares then return result end
  local enemies = load_module("Hunters Log.charts.Enemies")
  local rare_keys = get_rare_keys()
  local boss_keys = MONSTER_INFO.boss_keys
  local zone_set = {}
  for _, other in ipairs(ZONES.all_entries) do
    if other.ep == ep then
      for _, floor_name in ipairs(other.floors) do zone_set[floor_name] = true end
    end
  end
  local event_set = {}
  for _, alias in ipairs(K.EVENT_RAPPIES or {}) do event_set[K.drop_name_key(alias)] = true end
  local difficulty_label = difficulty_labels[difficulty]
  local history = get_drop_history()
  local count_key = table.concat({ tostring(K.HIST_REV), #history, tostring(section_label), tostring(difficulty_label), tostring(ep) }, "|")
  local drop_count
  local cached_count = K.KC_DROP_CACHE
  if cached_count and cached_count.key == count_key and cached_count.history == history then
    drop_count = cached_count.counts
  else
    drop_count = {}
    for _, h in ipairs(history) do
      local monster = h.kills_monster or h.source
      if monster and zone_set[h.zone] and h.section == section_label and h.difficulty == difficulty_label then
        local index_key = tostring(h.name) .. "|" .. K.drop_name_key(monster)
        drop_count[index_key] = (drop_count[index_key] or 0) + 1
      end
    end
    K.KC_DROP_CACHE = { key = count_key, history = history, counts = drop_count }
  end
  local offset = section_index * 4
  local seen = {}
  for key in pairs(ZONES.monsters(entry, not K.is_random_quest())) do
    local resolved = KEYALIAS.resolve(rares, key)
    if not seen[resolved] then
      seen[resolved] = true
      local total = KEYALIAS.total(prefix, resolved, rares)
      if total > 0 or not K.KC.cfg.hide_zero then
        local session = 0
        for _, name in ipairs(KEYALIAS.spellings(rares, resolved)) do
          session = session + (K.KC.session[prefix .. name] or 0)
        end
        local data = rares[resolved]
        local item = data and data[offset + 1]
        local odds
        if item and item ~= "" and data then
          odds = streak_odds(data, offset)
        else
          item = nil
        end
        if not item or not odds or odds <= 0 then
          local extra = ZONES.extra[resolved]
          if extra then item, odds = extra[1], extra[2] else item, odds = nil, nil end
        end
        local display = KEYALIAS.label(enemies, resolved, difficulty) or resolved
        local row = {
          name = display, lname = string.lower(display), total = total, session = session,
          rare = (KEYALIAS.is_rare(rare_keys, resolved) or ZONES.extra[resolved] ~= nil),
          boss = boss_keys[resolved],
        }
        if item and odds and odds > 0 then
          row.item = item
          row.expected = odds
          row.since = math.max(0, total - KEYALIAS.mark(prefix, resolved, item, rares))
          row.ratio = row.since / odds
          row.chance = 1 - (1 - 1 / odds) ^ row.since
          row.drops = drop_count[item .. "|" .. K.drop_name_key(display)] or 0
          if event_set[K.drop_name_key(resolved)] then
            local love_data = rares[KEYALIAS.resolve(rares, "Love Rappy")]
            local love_item = love_data and love_data[offset + 1]
            local love_odds = (love_item and love_item ~= "") and streak_odds(love_data, offset) or nil
            if love_odds and love_odds > 0 and string.lower(love_item) ~= string.lower(item) then
              local since2 = math.max(0, total - KEYALIAS.mark(prefix, resolved, love_item, rares))
              row.second = {
                item = love_item, expected = love_odds, since = since2, ratio = since2 / love_odds,
                drops = drop_count[love_item .. "|" .. K.drop_name_key(display)] or 0,
              }
            end
          end
        end
        result.rows[#result.rows + 1] = row
      end
    end
  end
  table.sort(result.rows, function(a, b)
    if a.lname ~= b.lname then return a.lname < b.lname end
    return tostring(a.item) < tostring(b.item)
  end)
  return result
end

function K.KC.draw_second(row)
  local s = row.second
  local c = item_color and item_color(s.item) or { 1, 1, 1 }
  local sr, sg, sb = streak_color(s.ratio)
  imgui.TextDisabled(K.KC.L("2e drop", "2nd drop", "2つ目のドロップ"))
  imgui.TextColored(c[1], c[2], c[3], 1, K.COMMON.full_label(s.item) .. " (1/" .. format_odds(s.expected) .. ")")
  imgui.Text(K.KC.L("Sans drop : ", "No drop: ", "ドロップなし: ") .. math.floor(s.since))
  imgui.TextColored(sr, sg, sb, 1, format_luck(s.ratio))
  imgui.Text(K.KC.L("Drops : ", "Drops: ", "ドロップ: ") .. s.drops)
end

function K.KC.draw_body(s)
  local C = K.KC.cfg
  local data = K.KC.cache and K.KC.cache.data
  local function tw(text)
    local ok, w = pcall(imgui.CalcTextSize, text)
    if ok and type(w) == "number" then return w end
    return #text * 7 * s
  end
  if not data then
    imgui.TextDisabled(K.KC.L("Aucune partie en cours", "No game in progress", "ゲーム中ではありません"))
    return
  end
  local gap = 14 * s
  local titles = {
    K.KC.L("Monstre", "Monster", "モンスター"), K.KC.L("Kills", "Kills", "キル"),
    K.KC.L("Sans drop", "No drop", "ドロップなし"), K.KC.L("Drops", "Drops", "ドロップ"),
  }
  local w1, w2, w3, w4 = 0, 0, 0, 0
  if C.headers then w1, w2, w3, w4 = tw(titles[1]), tw(titles[2]), tw(titles[3]), tw(titles[4]) end
  for _, row in ipairs(data.rows) do
    row.shown = clip(loc(row.name), 32)
    row.kills_text = tostring(math.floor(row.total)) .. " (+" .. tostring(math.floor(row.session)) .. ")"
    w1 = math.max(w1, tw(row.shown))
    w2 = math.max(w2, tw(row.kills_text) + 4)
    if row.item then
      row.since_text = tostring(math.floor(row.since))
      row.luck_text = format_luck(row.ratio)
      w3 = math.max(w3, tw(row.since_text .. " " .. row.luck_text) + (row.second and tw(" +") or 0))
      w4 = math.max(w4, tw(tostring(row.drops)))
    end
  end
  local c1 = w1 * 1.06 + gap
  local c2 = c1 + w2 + gap
  local c3 = c2 + w3 + gap
  local table_w = c3 + w4
  local half_bar = tw("|") / 2
  local xs1, xs2, xs3 = c1 - gap / 2 - half_bar, c2 - gap / 2 - half_bar, c3 - gap / 2 - half_bar
  local function sep(x)
    imgui.SameLine(x)
    imgui.TextColored(0.45, 0.5, 0.6, 1, "|")
  end
  local zone_text = loc(data.zone)
  local section_text = loc(data.section)
  local diff_text = loc(difficulty_labels[data.difficulty])
  local header_w = tw(zone_text) + tw(section_text) + tw(diff_text) + 2 * gap
  local win_w = table_w + 10
  local pad = (win_w - header_w) / 2 - 5
  local space_w = math.max(1, tw(" "))
  local pad_n = math.floor(pad / space_w)
  if pad_n > 0 then
    imgui.Text(string.rep(" ", pad_n))
    imgui.SameLine(0, 0)
  end
  imgui.TextColored(1.0, 0.85, 0.4, 1, zone_text)
  imgui.SameLine(0, gap)
  local sr, sg, sb = section_color(data.section)
  imgui.TextColored(sr, sg, sb, 1, section_text)
  imgui.SameLine(0, gap)
  local dc = streak_sort.diff_colors[data.difficulty] or streak_sort.diff_colors[3]
  imgui.TextColored(dc[1], dc[2], dc[3], 1, diff_text)
  if C.headers then
    imgui.TextDisabled(titles[1])
    sep(xs1)
    imgui.SameLine(c1)
    imgui.TextDisabled(titles[2])
    sep(xs2)
    imgui.SameLine(c2)
    imgui.TextDisabled(titles[3])
    sep(xs3)
    imgui.SameLine(c3)
    imgui.TextDisabled(titles[4])
  end
  imgui.Separator()
  if #data.rows == 0 then
    imgui.TextDisabled(K.KC.L("Aucun monstre dans cette zone", "No monsters in this area", "このエリアにモンスターはいません"))
    return
  end
  for row_index, row in ipairs(data.rows) do
    if K.KC.row_limit and row_index > K.KC.row_limit then
      imgui.TextDisabled("+" .. tostring(#data.rows - K.KC.row_limit) .. " ...")
      break
    end
    local hovered
    if row.rare then
      hovered = K.rare_text(row.shown)
    else
      if row.boss then
        imgui.TextColored(1.0, 0.25, 0.25, 1, row.shown)
      else
        imgui.Text(row.shown)
      end
      hovered = imgui.IsItemHovered()
    end
    if hovered and row.item then
      imgui.BeginTooltip()
      imgui.Text(T("streaks_tip_item", K.COMMON.full_label(row.item), format_odds(row.expected)))
      imgui.Text(T("streaks_tip_total", math.floor(row.total)))
      if row.second then
        imgui.Separator()
        K.KC.draw_second(row)
      end
      imgui.EndTooltip()
    end
    sep(xs1)
    imgui.SameLine(c1)
    imgui.TextColored(1.0, 0.9, 0.2, 1, tostring(math.floor(row.total)))
    imgui.SameLine(0, 4)
    imgui.TextColored(0.3, 1.0, 0.3, 1, "(+" .. tostring(math.floor(row.session)) .. ")")
    sep(xs2)
    imgui.SameLine(c2)
    if row.item then
      local r, g, b = streak_color(row.ratio)
      imgui.Text(row.since_text)
      imgui.SameLine(0, 4)
      imgui.TextColored(r, g, b, 1, row.luck_text)
      if row.second then
        imgui.SameLine(0, 4)
        local mr, mg, mb = streak_color(row.second.ratio)
        imgui.TextColored(mr, mg, mb, 1, "+")
        if imgui.IsItemHovered() then
          imgui.BeginTooltip()
          K.KC.draw_second(row)
          imgui.EndTooltip()
        end
      end
      sep(xs3)
      imgui.SameLine(c3)
      if row.drops > 0 then
        imgui.TextColored(1.0, 0.25, 0.25, 1, tostring(row.drops))
      else
        imgui.Text("0")
      end
    else
      imgui.TextDisabled("-")
      sep(xs3)
      imgui.SameLine(c3)
      imgui.TextDisabled("-")
    end
  end
end

function K.KC.menu_open()
  if K.KC.menu_lib == nil then
    local ok, lib = pcall(require, "solylib.menu")
    K.KC.menu_lib = (ok and type(lib) == "table") and lib or false
  end
  local lib = K.KC.menu_lib
  if not lib then return false end
  local function check(name)
    local fn = lib[name]
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn)
    return ok and value == true
  end
  return check("IsMenuOpen") or check("IsSymbolChatOpen") or check("IsMenuUnavailable")
end

function K.KC.draw()
  local C = K.KC.cfg
  if not C.enabled then return end
  if C.hide_menu and K.KC.menu_open() then return end
  if K.is_lobby(get_current_floor()) then return end
  local cache = K.KC.cache
  if not cache or K.U.frame() - cache.frame >= 15 then
    local ok, built = pcall(K.KC.build)
    cache = { frame = K.U.frame(), data = ok and built or nil }
    K.KC.cache = cache
  end
  if not cache.data or not cache.data.has_zone then return end
  local s = C.scale / 100
  local ok_ds, dw, dh = pcall(imgui.GetDisplaySize)
  if not (ok_ds and tonumber(dw) and tonumber(dh)) then dw, dh = 1280, 720 end
  local x = math.floor(dw * C.pos_x / 100 + 0.5)
  local y = math.floor(dh * C.pos_y / 100 + 0.5)
  local place = C.no_move or not K.KC.placed or K.KC.force_place
  K.KC.force_place = false
  imgui.SetNextWindowPos(x, y, place and "Always" or "FirstUseEver")
  imgui.SetNextWindowSize(math.floor(330 * s), math.floor(220 * s), "FirstUseEver")
  local pushed = 0
  local function push_color(name, r, g, b, a)
    if pcall(imgui.PushStyleColor, name, r, g, b, a) then pushed = pushed + 1 end
  end
  local alpha = C.transparent and 0 or (C.opacity / 100)
  push_color("WindowBg", 0.06, 0.06, 0.06, alpha)
  push_color("Border", 0, 0, 0, alpha)
  if C.transparent then
    push_color("TitleBg", 0, 0, 0, 0)
    push_color("TitleBgActive", 0, 0, 0, 0)
    push_color("TitleBgCollapsed", 0, 0, 0, 0)
  end
  local pushed_vars = 0
  local function push_var(name, a, b)
    if pcall(imgui.PushStyleVar, name, a, b) then pushed_vars = pushed_vars + 1 end
  end
  push_var("WindowPadding", 7, 5)
  push_var("ItemSpacing", 6, 4)
  K.KC.row_limit = nil
  if C.no_resize then
    local max_h = math.max(math.floor(100 * s), math.floor(dh * C.max_height / 100 - y))
    local ok_constraints = pcall(imgui.SetNextWindowSizeConstraints, 0, 0, dw, max_h)
    if not ok_constraints then
      local ok_lh, line_h = pcall(imgui.GetTextLineHeightWithSpacing)
      if not (ok_lh and tonumber(line_h)) then line_h = 18 * s end
      K.KC.row_limit = math.max(3, math.floor(max_h / (line_h * s)) - 3)
    end
  end
  local flags = { "NoCollapse", "NoSavedSettings" }
  if C.no_title then flags[#flags + 1] = "NoTitleBar" end
  if C.hide_scrollbar then flags[#flags + 1] = "NoScrollbar" end
  if C.no_move then flags[#flags + 1] = "NoMove" end
  if C.no_resize then
    flags[#flags + 1] = "NoResize"
    flags[#flags + 1] = "AlwaysAutoResize"
  end
  local title = "Hunter's Log Kill Counter##kill_counter"
  local ok_begin, status = pcall(imgui.Begin, title, nil, flags)
  if not ok_begin then
    local safe = {}
    for _, flag in ipairs(flags) do
      if flag ~= "AlwaysAutoResize" and flag ~= "NoScrollbar" then safe[#safe + 1] = flag end
    end
    status = imgui.Begin(title, nil, safe)
  end
  if status then
    pcall(imgui.SetWindowFontScale, s)
    local ok, err = pcall(K.KC.draw_body, s)
    if not ok then imgui.TextColored(1, 0.4, 0.3, 1, tostring(err)) end
    pcall(imgui.SetWindowFontScale, 1.0)
    if not place then
      local ok_wp, wx, wy = pcall(imgui.GetWindowPos)
      if ok_wp and tonumber(wx) and tonumber(wy) and math.abs(wx - x) + math.abs(wy - y) > 1.0 then
        C.pos_x = math.max(0, math.min(100, wx / dw * 100))
        C.pos_y = math.max(0, math.min(100, wy / dh * 100))
        K.KC.pos_changed = os.time()
      end
    end
    K.KC.placed = true
  end
  imgui.End()
  for _ = 1, pushed_vars do pcall(imgui.PopStyleVar) end
  for _ = 1, pushed do pcall(imgui.PopStyleColor) end
  if K.KC.pos_changed and os.time() - K.KC.pos_changed >= 2 then
    K.KC.pos_changed = nil
    save_data()
  end
end

function K.KC.draw_options()
  local C = K.KC.cfg
  local L = K.KC.L
  imgui.TextColored(0.75, 0.85, 1.0, 1, L("Fenetre compteur de kills (zone actuelle)", "Kill counter window (current area)", "キルカウンターウィンドウ (現在のエリア)"))
  local function check(key, fr, en, ja)
    local changed, value = imgui.Checkbox(L(fr, en, ja) .. "##kc_" .. key, C[key])
    if changed then
      C[key] = value
      save_data()
    end
  end
  local function stepper(key, label, small, big, suffix)
    imgui.Text(label .. " " .. string.format("%.0f", C[key]) .. suffix)
    local limit = K.KC.limits[key]
    local function move(delta)
      C[key] = math.max(limit[1], math.min(limit[2], C[key] + delta))
      K.KC.force_place = true
      save_data()
    end
    imgui.SameLine(0, 8)
    if imgui.Button("--##kc_" .. key) then move(-big) end
    imgui.SameLine(0, 2)
    if imgui.Button("-##kc_" .. key) then move(-small) end
    imgui.SameLine(0, 2)
    if imgui.Button("+##kc_" .. key) then move(small) end
    imgui.SameLine(0, 2)
    if imgui.Button("++##kc_" .. key) then move(big) end
  end
  check("enabled", "Afficher la fenetre compteur de kills", "Show the kill counter window", "キルカウンターウィンドウを表示")
  check("transparent", "Mode transparent (texte seul, sans fond)", "Transparent mode (text only, no background)", "透明モード (背景なし)")
  check("no_move", "Position verrouillee (No Move)", "Lock position (No Move)", "位置を固定 (No Move)")
  check("no_resize", "Taille verrouillee, s'adapte au contenu (No Resize)", "Lock size, fits the content (No Resize)", "サイズを固定、内容に合わせる (No Resize)")
  check("hide_scrollbar", "Masquer la barre de defilement (defiler avec la molette)", "Hide the scrollbar (scroll with the mouse wheel)", "スクロールバーを隠す (マウスホイールでスクロール)")
  check("no_title", "Masquer la barre de titre", "Hide the title bar", "タイトルバーを隠す")
  check("headers", "Afficher les titres de colonnes", "Show column titles", "列タイトルを表示")
  check("hide_zero", "Masquer les monstres a 0 kill", "Hide monsters with 0 kills", "キル0のモンスターを隠す")
  check("hide_menu", "Masquer avec le menu du jeu (Hide with menu)", "Hide with the game menu", "ゲームメニューを開くと隠す")
  stepper("opacity", L("Opacite du fond", "Background opacity", "背景の不透明度"), 5, 20, " %")
  stepper("scale", L("Taille du texte", "Text size", "文字サイズ"), 5, 20, " %")
  stepper("max_height", L("Hauteur max (taille verrouillee)", "Max height (locked size)", "最大の高さ (サイズ固定時)"), 5, 20, " %")
  imgui.Text(L("Position (% de l'ecran, coin haut gauche)", "Position (% of screen, top-left corner)", "位置 (画面の%、左上)"))
  stepper("pos_x", "X", 1, 5, " %")
  stepper("pos_y", "Y", 1, 5, " %")
  local function place(button, px, py)
    if imgui.Button(button) then
      C.pos_x, C.pos_y = px, py
      K.KC.force_place = true
      save_data()
    end
  end
  place(L("Haut gauche", "Top left", "左上") .. "##kc_tl", 1, 4)
  imgui.SameLine(0, 4)
  place(L("Haut droite", "Top right", "右上") .. "##kc_tr", 78, 4)
  imgui.SameLine(0, 4)
  place(L("Bas gauche", "Bottom left", "左下") .. "##kc_bl", 1, 70)
  imgui.SameLine(0, 4)
  place(L("Bas droite", "Bottom right", "右下") .. "##kc_br", 78, 70)
  imgui.SameLine(0, 4)
  place(L("Centre", "Center", "中央") .. "##kc_c", 35, 35)
  imgui.TextDisabled(L("Deverrouillez la position pour deplacer la fenetre a la souris.", "Unlock the position to drag the window with the mouse.", "位置の固定を解除すると、マウスで移動できます。"))
  if imgui.Button(L("Remettre la session a zero", "Reset the session", "セッションをリセット") .. "##kc_reset") then
    K.KC.session = {}
    K.KC.cache = nil
  end
  imgui.TextDisabled(L("Le nombre vert (+N) = les kills de la quete en cours (remis a zero a chaque nouvelle quete).", "Green number (+N) = kills of the current quest (reset at each new quest).", "緑の数字 (+N) = 現在のクエストのキル数 (新しいクエストごとにリセット)。"))
end
end
