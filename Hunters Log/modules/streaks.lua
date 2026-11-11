local imgui = require("imgui")

return function(K)
local streak_id_choice = 0
local KEYALIAS, MONSTER_INFO, T, ZONES, clip, difficulty_labels, difficulty_modules, floor_names, format_luck, format_odds, get_auto_episode, get_rare_keys, get_section_index, kind_color, lang, load_module, loc, no_detail_items, parse_odds, section_color, section_colors, section_labels
local function bind_locals(E)
  KEYALIAS = E.KEYALIAS
  MONSTER_INFO = E.MONSTER_INFO
  T = E.T
  ZONES = E.ZONES
  clip = E.clip
  difficulty_labels = E.difficulty_labels
  difficulty_modules = E.difficulty_modules
  floor_names = E.floor_names
  format_luck = E.format_luck
  format_odds = E.format_odds
  get_auto_episode = E.get_auto_episode
  get_rare_keys = E.get_rare_keys
  get_section_index = E.get_section_index
  kind_color = E.kind_color
  lang = E.lang
  load_module = E.load_module
  loc = E.loc
  no_detail_items = E.no_detail_items
  parse_odds = E.parse_odds
  section_color = E.section_color
  section_colors = E.section_colors
  section_labels = E.section_labels
end

local streak_sort = { key = "name", desc = false, search = "", search_applied = "", search_pending_frame = -1000, ids = {}, eps = { all = true }, diffs = {},
episode_color = { 0.4, 0.65, 1.0 },
diff_colors = { [0] = { 0.3, 1.0, 0.3 }, [1] = { 1.0, 0.9, 0.2 }, [2] = { 1.0, 0.6, 0.1 }, [3] = { 1.0, 0.25, 0.25 } } }

function streak_sort.sig(set)
  local sig = set.all and "A" or ""
  for index = 0, 9 do
    if set[index] then sig = sig .. tostring(index) .. "," end
  end
  return sig
end

function streak_sort.ids_sig()
  return streak_sort.sig(streak_sort.ids) .. "|" .. streak_sort.sig(streak_sort.eps) .. "|" .. streak_sort.sig(streak_sort.diffs)
end

function streak_sort.list(set, all_values)
  local out = {}
  for _, value in ipairs(all_values) do
    if set.all or set[value] then out[#out + 1] = value end
  end
  return out
end

function streak_sort.toggle(name, value)
  local set = streak_sort[name]
  if set.all then
    streak_sort[name] = { [value] = true }
  elseif set[value] then
    set[value] = nil
  else
    set[value] = true
  end
end

local WIKI_KINDS = {}

do
  local lists = K.GAME_DATA.wiki_kinds
  for kind, names in pairs(lists) do
    for _, n in ipairs(names) do WIKI_KINDS[n] = kind end
  end
end

local streak_cache = {
  frame = -1000, id_choice = -1, sort = false,
  rows = {}, state = "no_game", difficulty = "", episode = "", section = "",
}

local function streak_percent_of(text)
  return tonumber(string.match(tostring(text or ""), "%(([%d%.]+)%%%)"))
end

local function streak_odds(data, offset)
  local rdr_mult = (K.U.rdr() and K.U.rdr() > 0) and (K.U.rdr() / 100) or nil
  local dar_mult = (K.U.dar() and K.U.dar() > 0) and (K.U.dar() / 100) or nil
  local dar_base = streak_percent_of(data[offset + 2])
  local rare_base = streak_percent_of(data[offset + 3])
  if dar_base and rare_base and dar_base > 0 and rare_base > 0 then
    local dar_eff = math.min(100, math.floor(dar_base * (dar_mult or 1) + 1e-9))
    local rare_eff = math.min(100, rare_base * (rdr_mult or 1))
    if dar_eff > 0 and rare_eff > 0 then
      return 10000 / (dar_eff * rare_eff)
    end
  end
  local base = parse_odds(data[offset + 4])
  if base then
    return base / ((rdr_mult or 1) * (dar_mult or 1))
  end
  return nil
end

K.DROP_KEY_MEMO = {}

function K.drop_name_key(name)
  if type(name) ~= "string" then return (string.gsub(KEYALIAS.norm(name), " e2$", "")) end
  local memo = K.DROP_KEY_MEMO[name]
  if memo then return memo end
  memo = (string.gsub(KEYALIAS.norm(name), " e2$", ""))
  K.DROP_KEY_MEMO[name] = memo
  return memo
end

local function rebuild_streak_cache()
  streak_cache.frame = K.U.frame()
  streak_cache.id_choice = streak_id_choice
  streak_cache.zone_choice = ZONES.choice
  streak_cache.sort = streak_sort.key .. (streak_sort.desc and "-" or "+") .. "|" .. (streak_sort.search_applied or "")
  streak_cache.rows = {}
  streak_cache.state = "no_game"
  local query = string.lower(tostring(streak_sort.search_applied or ""))
  streak_cache.query = query
  local difficulty_list = streak_sort.list(streak_sort.diffs, { 0, 1, 2, 3 })
  if #difficulty_list == 0 then
    local ok, game_difficulty = pcall(pso.read_u32, K.DIFFICULTY_ADDR)
    if ok and difficulty_labels[game_difficulty] then
      difficulty_list = { game_difficulty }
    end
  end
  if #difficulty_list == 0 then return end
  local searching = (query ~= "")
  streak_cache.searching = searching
  local scanned_episodes = streak_sort.list(streak_sort.eps, { 1, 2, 4 })
  if #scanned_episodes == 0 then
    scanned_episodes = { get_auto_episode() or K.U.episode() }
  end
  local all_episodes = (#scanned_episodes > 1)
  local section_list = {}
  if searching then
    scanned_episodes = { 1, 2, 4 }
    for index = 0, 9 do section_list[#section_list + 1] = index end
  else
    for _, index in ipairs(streak_sort.list(streak_sort.ids, { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 })) do
      section_list[#section_list + 1] = index
    end
    if #section_list == 0 then
      local section_index = get_section_index()
      if not section_index or not section_labels[section_index] then return end
      section_list[1] = section_index
    end
  end
  local show_section = searching or #section_list > 1 or #difficulty_list > 1
  local section_text
  if searching or streak_sort.ids.all then
    section_text = T("streaks_all")
  else
    local section_names = {}
    for _, index in ipairs(section_list) do
      section_names[#section_names + 1] = loc(section_labels[index])
    end
    section_text = table.concat(section_names, " + ")
  end
  streak_cache.show_section = show_section
  streak_cache.show_diff = (#difficulty_list > 1)
  streak_cache.ids_sig = streak_sort.ids_sig()
  local zone_all = (ZONES.choice ~= nil and ZONES.choice == #ZONES.list + 1)
  local zone_sel = (ZONES.choice and not zone_all) and ZONES.list[ZONES.choice] or nil
  local zone_monsters = nil
  if zone_sel then
    scanned_episodes = { zone_sel.ep }
    all_episodes = false
    zone_monsters = ZONES.monsters(zone_sel, true)
  elseif zone_all then
    scanned_episodes = { 1, 2, 4 }
    all_episodes = true
    zone_monsters = {}
  end
  local difficulty_text
  if streak_sort.diffs.all then
    difficulty_text = T("streaks_all")
  else
    local difficulty_names = {}
    for _, value in ipairs(difficulty_list) do
      difficulty_names[#difficulty_names + 1] = loc(difficulty_labels[value])
    end
    difficulty_text = table.concat(difficulty_names, " + ")
  end
  local episode_text
  if streak_sort.eps.all then
    episode_text = T("streaks_all")
  else
    local episode_names = {}
    for _, value in ipairs(scanned_episodes) do episode_names[#episode_names + 1] = tostring(value) end
    episode_text = table.concat(episode_names, " + ")
  end
  streak_cache.difficulty = difficulty_text
  if zone_sel or zone_all then
    streak_cache.episode = zone_sel and tostring(zone_sel.ep) or T("streaks_all")
    streak_cache.section = section_text
  elseif searching then
    streak_cache.episode = T("streaks_all")
    streak_cache.section = section_text
  else
    streak_cache.episode = episode_text
    streak_cache.section = section_text
  end
  local base_key = table.concat({
    tostring(searching), table.concat(difficulty_list, ","), table.concat(scanned_episodes, ","),
    table.concat(section_list, ","), tostring(ZONES.choice), tostring(#K.U.drop_history()),
    tostring(K.U.rdr()), tostring(K.U.dar()),
  }, "|")
  K.streak_bases = K.streak_bases or {}
  local base = K.streak_bases[base_key]
  local kills_ver = K.KILLS_VER or 0
  local base_age = base and (K.U.frame() - base.frame) or 0
  local rows, zone_ranks
  if base and ((base.ver == kills_ver and base_age < 600) or base_age < (searching and 300 or 60)) then
    rows, zone_ranks = base.rows, base.zone_ranks
  else
    local enemies = load_module("Hunters Log.charts.Enemies")
    local event_rappy_set = {}
    for _, alias in ipairs(K.EVENT_RAPPIES) do event_rappy_set[K.drop_name_key(alias)] = true end
    local drop_index
    local cached_index = K.STREAK_DROP_INDEX
    if cached_index and cached_index.rev == K.HIST_REV and cached_index.count == #K.U.drop_history() then
      drop_index = cached_index.index
    else
      drop_index = {}
      for _, h in ipairs(K.U.drop_history()) do
        local monster = h.kills_monster or h.source
        if monster then
          local index_key = tostring(h.name) .. "|" .. tostring(h.section) .. "|" .. tostring(h.difficulty) .. "|" .. K.drop_name_key(monster)
          local zones = drop_index[index_key]
          if not zones then
            zones = {}
            drop_index[index_key] = zones
          end
          zones[#zones + 1] = h.zone
        end
      end
      for _, rec in ipairs(K.ARCHIVE.list) do
        if rec.monster ~= "" then
          local index_key = rec.name .. "|" .. rec.section .. "|" .. rec.difficulty .. "|" .. K.drop_name_key(rec.monster)
          local zones = drop_index[index_key]
          if not zones then
            zones = {}
            drop_index[index_key] = zones
          end
          for _ = 1, rec.n do zones[#zones + 1] = rec.zone end
        end
      end
      K.STREAK_DROP_INDEX = { rev = K.HIST_REV, count = #K.U.drop_history(), index = drop_index }
    end
    local boss_keys = MONSTER_INFO.boss_keys
    local rare_keys = get_rare_keys()
    rows = {}
    zone_ranks = { [1] = {}, [2] = {}, [4] = {} }
    for rank_index, zone_entry in ipairs(ZONES.list) do
      local rank_map = zone_ranks[zone_entry.ep]
      for monster_key in pairs(ZONES.monsters(zone_entry, true)) do
        local norm_key = KEYALIAS.norm(monster_key)
        rank_map[norm_key] = rank_map[norm_key] or {}
        local rank_list = rank_map[norm_key]
        if rank_list[#rank_list] ~= rank_index then
          rank_list[#rank_list + 1] = rank_index
        end
      end
    end
    for _, difficulty in ipairs(difficulty_list) do
      local modules = difficulty_modules[difficulty]
      local rares = modules and load_module(modules.rares)
      if rares then
        for _, scan_ep in ipairs(scanned_episodes) do
          local zone_set = {}
          for _, zone_name in pairs(floor_names[scan_ep] or {}) do zone_set[zone_name] = true end
          if zone_sel then
            zone_set = {}
            for _, floor_name in ipairs(zone_sel.floors) do zone_set[floor_name] = true end
          elseif zone_all then
            zone_monsters = ZONES.all_monsters(scan_ep)
          end
          for _, section_index in ipairs(section_list) do
            local section_label = section_labels[section_index]
            local offset = section_index * 4
            local prefix = tostring(difficulty) .. "|" .. tostring(scan_ep) .. "|" .. section_label .. "|"
            local candidates = {}
            if zone_monsters then
              for key in pairs(zone_monsters) do
                candidates[#candidates + 1] = { key, tonumber(K.U.kill_totals()[prefix .. key]) or 0 }
              end
            elseif searching then
              for key in pairs(rares) do
                if MONSTER_INFO.episode_of(key) == scan_ep then
                  candidates[#candidates + 1] = { key, tonumber(K.U.kill_totals()[prefix .. key]) or 0 }
                end
              end
            else
              for total_key, total in pairs(K.U.kill_totals()) do
                if string.sub(total_key, 1, #prefix) == prefix and tonumber(total) and total > 0 then
                  candidates[#candidates + 1] = { string.sub(total_key, #prefix + 1), total }
                end
              end
            end
            do
              local merged, merged_index = {}, {}
              for _, candidate in ipairs(candidates) do
                local resolved = KEYALIAS.resolve(rares, candidate[1])
                if not merged_index[resolved] then
                  merged_index[resolved] = true
                  merged[#merged + 1] = { resolved, KEYALIAS.total(prefix, resolved, rares) }
                end
              end
              candidates = merged
            end
            for _, candidate in ipairs(candidates) do
              local key, total = candidate[1], candidate[2]
              local primary_row = nil
              local data = rares[key]
              local item = data and data[offset + 1]
              local odds_value = nil
              if item and item ~= "" and data then
                odds_value = streak_odds(data, offset)
              else
                local extra_info = ZONES.extra[key]
                if extra_info then
                  item = extra_info[1]
                  odds_value = extra_info[2]
                end
              end
              if zone_monsters and not (item and item ~= "" and (odds_value or 0) > 0) then
                local plain_name = KEYALIAS.label(enemies, key, difficulty) or key
                if true then
                  local plain_shown = plain_name
                  local plain_tag = (all_episodes and not searching and not show_section) and ("[E" .. tostring(scan_ep) .. "]") or nil
                  rows[#rows + 1] = {
                    drops = 0, rare = (KEYALIAS.is_rare(rare_keys, key) or ZONES.extra[key] ~= nil), boss = boss_keys[key],
                    name = plain_shown, lname = string.lower(plain_name), zkey = key, zrank = 999, ep_tag = plain_tag, item = "-", since = 0, total = total, episode = scan_ep,
                    sec = section_index, section = section_label, diff = difficulty,
                    expected = 0, ratio = 0, chance = 0, norare = true,
                  }
                end
              end
              if item and item ~= "" then
                local odds = odds_value
                if odds and odds > 0 then
                  local display = KEYALIAS.label(enemies, key, difficulty) or key
                  if true then
                    local since = math.max(0, total - KEYALIAS.mark(prefix, key, item, rares))
                    local shown_name = display
                    local shown_tag = (all_episodes and not searching and not show_section) and ("[E" .. tostring(scan_ep) .. "]") or nil
                    local drops = 0
                    local zones = drop_index[item .. "|" .. section_label .. "|" .. difficulty_labels[difficulty] .. "|" .. K.drop_name_key(display)]
                    if zones then
                      for _, zone in ipairs(zones) do
                        if zone_set[zone] then drops = drops + 1 end
                      end
                    end
                    primary_row = {
                      drops = drops, rare = (KEYALIAS.is_rare(rare_keys, key) or ZONES.extra[key] ~= nil), boss = boss_keys[key],
                      name = shown_name, lname = string.lower(display), litem = string.lower(item), zkey = key, zrank = 999, ep_tag = shown_tag, item = item, since = since, total = total, episode = scan_ep,
                      sec = section_index, section = section_label, diff = difficulty,
                      expected = odds, ratio = since / odds,
                      chance = 1 - (1 - 1 / odds) ^ since,
                    }
                    rows[#rows + 1] = primary_row
                  end
                end
              end
              if event_rappy_set[K.drop_name_key(key)] then
                local love_data = rares[KEYALIAS.resolve(rares, "Love Rappy")]
                local love_item = love_data and love_data[offset + 1]
                local love_odds = (love_item and love_item ~= "") and streak_odds(love_data, offset) or nil
                if love_odds and love_odds > 0 and string.lower(love_item) ~= string.lower(tostring(item or "")) then
                  local display = KEYALIAS.label(enemies, key, difficulty) or key
                  local since = math.max(0, total - KEYALIAS.mark(prefix, key, love_item, rares))
                  local love_tag = (all_episodes and not searching and not show_section) and ("[E" .. tostring(scan_ep) .. "]") or nil
                  local drops = 0
                  local zones = drop_index[love_item .. "|" .. section_label .. "|" .. difficulty_labels[difficulty] .. "|" .. K.drop_name_key(display)]
                  if zones then
                    for _, zone in ipairs(zones) do
                      if zone_set[zone] then drops = drops + 1 end
                    end
                  end
                  if primary_row then
                    primary_row.second = {
                      item = love_item, litem = string.lower(love_item), since = since, drops = drops,
                      expected = love_odds, ratio = since / love_odds,
                      chance = 1 - (1 - 1 / love_odds) ^ since,
                    }
                  else
                    rows[#rows + 1] = {
                      drops = drops, rare = true, boss = boss_keys[key],
                      name = display, lname = string.lower(display), litem = string.lower(love_item), zkey = key, zrank = 999, ep_tag = love_tag, item = love_item, since = since, total = total, episode = scan_ep,
                      sec = section_index, section = section_label, diff = difficulty,
                      expected = love_odds, ratio = since / love_odds,
                      chance = 1 - (1 - 1 / love_odds) ^ since,
                    }
                  end
                end
              end
            end
          end
        end
      end
    end
    K.streak_bases[base_key] = { key = base_key, frame = K.U.frame(), ver = kills_ver, rows = rows, zone_ranks = zone_ranks }
    local base_count, oldest_key, oldest_frame = 0, nil, nil
    for other_key, other in pairs(K.streak_bases) do
      base_count = base_count + 1
      if not oldest_frame or other.frame < oldest_frame then oldest_key, oldest_frame = other_key, other.frame end
    end
    if base_count > 3 and oldest_key then K.streak_bases[oldest_key] = nil end
  end
  if query ~= "" then
    local filtered = {}
    for _, row in ipairs(rows) do
      if string.find(row.lname, query, 1, true) or (row.litem and string.find(row.litem, query, 1, true))
        or (row.second and string.find(row.second.litem, query, 1, true)) then
        filtered[#filtered + 1] = row
      end
    end
    rows = filtered
  end
  do
    local expanded = {}
    for _, row in ipairs(rows) do
      local ranks = zone_ranks[row.episode] and zone_ranks[row.episode][KEYALIAS.norm(row.zkey)]
      if zone_sel then
        row.zrank = ZONES.choice
        expanded[#expanded + 1] = row
      elseif not ranks then
        row.zrank = 999
        expanded[#expanded + 1] = row
      elseif zone_all and #ranks > 1 and streak_sort.key == "name" then
        for _, rank in ipairs(ranks) do
          local copy = {}
          for field, value in pairs(row) do copy[field] = value end
          copy.zrank = rank
          expanded[#expanded + 1] = copy
        end
      else
        row.zrank = ranks[1]
        expanded[#expanded + 1] = row
      end
    end
    rows = expanded
  end
  local sort_key, sort_desc = streak_sort.key, streak_sort.desc
  table.sort(rows, function(a, b)
    if sort_key == "name" and a.zrank ~= b.zrank then
      if sort_desc then return a.zrank > b.zrank end
      return a.zrank < b.zrank
    end
    local x, y = a[sort_key], b[sort_key]
    if type(x) == "string" then x = string.lower(x) end
    if type(y) == "string" then y = string.lower(y) end
    if x ~= y then
      if sort_desc then return x > y end
      return x < y
    end
    if a.ratio ~= b.ratio then return a.ratio > b.ratio end
    if a.name ~= b.name then return a.name < b.name end
    if a.sec ~= b.sec then return a.sec < b.sec end
    if a.episode ~= b.episode then return a.episode < b.episode end
    return (a.diff or 0) < (b.diff or 0)
  end)
  streak_cache.rows = rows
  streak_cache.state = (#rows > 0) and "ok" or "none"
end

local function streak_color(ratio)
  if ratio < 0.5 then return 0.6, 0.9, 0.6 end
  if ratio < 1 then return 1.0, 1.0, 1.0 end
  if ratio < 2 then return 1.0, 0.85, 0.3 end
  return 1.0, 0.4, 0.4
end

local function draw_streaks_tab()
  if streak_sort.search_pending_frame and K.U.frame() - streak_sort.search_pending_frame >= 3
    and streak_sort.search_applied ~= streak_sort.search then
    streak_sort.search_applied = streak_sort.search or ""
  end
  local applied_sort_key = streak_sort.key .. (streak_sort.desc and "-" or "+") .. "|" .. (streak_sort.search_applied or "")
  local refresh_interval = (streak_sort.search_applied ~= "") and 300 or 60
  if streak_cache.ids_sig ~= streak_sort.ids_sig() or streak_cache.zone_choice ~= ZONES.choice
    or streak_cache.sort ~= applied_sort_key
    or K.U.frame() - streak_cache.frame >= refresh_interval then
    rebuild_streak_cache()
  end
  local function sub_button(label, selected, id, color)
    local text = selected and ("[" .. label .. "]") or label
    local pushed = color and pcall(imgui.PushStyleColor, "Text", color[1], color[2], color[3], 1.0)
    local clicked = imgui.Button(text .. "##" .. id)
    if pushed then pcall(imgui.PopStyleColor) end
    return clicked
  end
  local game_index = get_section_index()
  imgui.Text(T("streaks_id"))
  imgui.SameLine(0, 4)
  local ids_selected = next(streak_sort.ids) ~= nil
  if sub_button(T("streaks_current"), not ids_selected, "streak_id_auto") then
    streak_sort.ids = {}
  end
  for index = 0, 9 do
    imgui.SameLine(0, 4)
    local label = loc(section_labels[index])
    if game_index == index then
      label = label .. "*"
    end
    if sub_button(label, streak_sort.ids[index] == true, "streak_id_" .. index, section_colors[section_labels[index]]) then
      streak_sort.toggle("ids", index)
    end
  end
  imgui.SameLine(0, 4)
  if sub_button(T("streaks_all"), streak_sort.ids.all == true, "streak_id_all") then
    streak_sort.ids = { all = true }
  end
  if ids_selected then
    imgui.SameLine(0, 4)
    if imgui.Button("X##streak_ids_clear") then
      streak_sort.ids = {}
    end
  end
  imgui.Text(T("streaks_episode"))
  imgui.SameLine(0, 4)
  local eps_selected = next(streak_sort.eps) ~= nil
  if sub_button(T("streaks_current"), not eps_selected, "streak_ep_auto") then
    streak_sort.eps = {}
  end
  for _, ep_value in ipairs({ 1, 2, 4 }) do
    imgui.SameLine(0, 4)
    if sub_button(tostring(ep_value), streak_sort.eps[ep_value] == true, "streak_ep_" .. ep_value) then
      streak_sort.toggle("eps", ep_value)
    end
  end
  imgui.SameLine(0, 4)
  if sub_button(T("streaks_all"), streak_sort.eps.all == true, "streak_ep_all") then
    streak_sort.eps = { all = true }
  end
  if eps_selected then
    imgui.SameLine(0, 4)
    if imgui.Button("X##streak_eps_clear") then
      streak_sort.eps = {}
    end
  end
  imgui.SameLine(0, 24)
  imgui.Text(T("streaks_difficulty"))
  imgui.SameLine(0, 4)
  local diffs_selected = next(streak_sort.diffs) ~= nil
  if sub_button(T("streaks_current"), not diffs_selected, "streak_df_auto") then
    streak_sort.diffs = {}
  end
  for index = 0, 3 do
    imgui.SameLine(0, 4)
    if sub_button(loc(difficulty_labels[index]), streak_sort.diffs[index] == true, "streak_df_" .. index, streak_sort.diff_colors[index]) then
      streak_sort.toggle("diffs", index)
    end
  end
  imgui.SameLine(0, 4)
  if sub_button(T("streaks_all"), streak_sort.diffs.all == true, "streak_df_all") then
    streak_sort.diffs = { all = true }
  end
  if diffs_selected then
    imgui.SameLine(0, 4)
    if imgui.Button("X##streak_diffs_clear") then
      streak_sort.diffs = {}
    end
  end
  imgui.Text(T("streaks_zone"))
  imgui.SameLine(0, 4)
  local zone_labels = { T("zone_none") }
  for _, entry in ipairs(ZONES.list) do
    zone_labels[#zone_labels + 1] = string.format("E%d  %s", entry.ep, loc(entry.zone))
  end
  zone_labels[#zone_labels + 1] = T("zone_all")
  local zone_current = (ZONES.choice or 0) + 1
  local width_pushed = pcall(imgui.PushItemWidth, 170)
  local combo_ok, combo_a, combo_b = pcall(imgui.Combo, "##streak_zone", zone_current, zone_labels, #zone_labels)
  if width_pushed then pcall(imgui.PopItemWidth) end
  if combo_ok then
    local new_index = (type(combo_a) == "number" and combo_a) or (type(combo_b) == "number" and combo_b) or nil
    if new_index and new_index ~= zone_current then
      ZONES.choice = (new_index > 1) and (new_index - 1) or nil
    end
  else
    if imgui.Button("<##streak_zone_prev") then
      if not ZONES.choice then ZONES.choice = #ZONES.list + 1
      elseif ZONES.choice <= 1 then ZONES.choice = nil
      else ZONES.choice = ZONES.choice - 1 end
    end
    imgui.SameLine(0, 4)
    imgui.Text(zone_labels[zone_current])
    imgui.SameLine(0, 4)
    if imgui.Button(">##streak_zone_next") then
      if not ZONES.choice then ZONES.choice = 1
      elseif ZONES.choice >= #ZONES.list + 1 then ZONES.choice = nil
      else ZONES.choice = ZONES.choice + 1 end
    end
  end
  if ZONES.choice then
    imgui.SameLine(0, 4)
    if imgui.Button("X##streak_zone_clear") then
      ZONES.choice = nil
    end
    imgui.TextDisabled(T("streaks_zone_note"))
  end
  if streak_cache.state ~= "no_game" then
    imgui.Text(streak_cache.section)
    imgui.SameLine(0, 8)
    imgui.TextDisabled(T("streaks_context", loc(streak_cache.difficulty), streak_cache.episode))
  end
  imgui.SameLine(0, 24)
  imgui.TextDisabled(T("streaks_game_mark"))
  imgui.TextDisabled(T("streaks_note"))
  imgui.TextDisabled(T("streaks_hint"))
  if streak_cache.searching then
    imgui.TextDisabled(T("streaks_search_all"))
  end
  imgui.Text(T("streaks_search"))
  imgui.SameLine(0, 6)
  imgui.PushItemWidth(190)
  local _, new_search = imgui.InputText("##streak_search", streak_sort.search or "", 64)
  new_search = new_search or ""
  if new_search ~= (streak_sort.search or "") then
    streak_sort.search = new_search
    streak_sort.search_pending_frame = K.U.frame()
  end
  imgui.PopItemWidth()
  imgui.SameLine(0, 4)
  if imgui.Button("X##streak_search_clear") then
    streak_sort.search = ""
    streak_sort.search_applied = ""
    streak_sort.search_pending_frame = -1000
  end
  imgui.SameLine(0, 24)
  local sort_titles = {
    name = "col_monster", item = "col_item", total = "streaks_col_total", since = "streaks_col_since",
    expected = "streaks_col_expected", ratio = "streaks_col_ratio", drops = "streaks_col_drops",
  }
  imgui.Text(T("streaks_sort_label", T(sort_titles[streak_sort.key] or "streaks_col_ratio"),
  T(streak_sort.desc and "sort_desc" or "sort_asc")))
  imgui.SameLine(0, 8)
  if imgui.Button(T("sort_reset") .. "##streak_sort_reset") then
    streak_sort.key = "name"
    streak_sort.desc = false
  end
  imgui.Separator()
  if streak_cache.state == "no_game" then
    imgui.TextDisabled(T("streaks_no_game"))
    return
  elseif streak_cache.state == "none" then
    imgui.TextDisabled(T(streak_cache.query ~= "" and "streaks_no_result" or "streaks_none"))
    return
  end
  local function header(x, label_key, help_key, sort_key)
    if x > 0 then
      imgui.SameLine(x)
    end
    local label = T(label_key)
    if streak_sort.key == sort_key then
      label = label .. (streak_sort.desc and " v" or " ^")
    end
    if imgui.Button(label .. "##sort_" .. sort_key) then
      local default_desc = (sort_key ~= "name" and sort_key ~= "item")
      if streak_sort.key ~= sort_key then
        streak_sort.key = sort_key
        streak_sort.desc = default_desc
      elseif streak_sort.desc == default_desc then
        streak_sort.desc = not default_desc
      else
        streak_sort.key = "name"
        streak_sort.desc = false
      end
    end
    if imgui.IsItemHovered() then
      imgui.BeginTooltip()
      if help_key then
        imgui.Text(T(help_key))
      end
      imgui.TextDisabled(T("sort_tip"))
      imgui.EndTooltip()
    end
  end
  local dx = streak_cache.show_section and (streak_cache.show_diff and 140 or 120) or 0
  header(0, "col_monster", nil, "name")
  header(190 + dx, "col_item", nil, "item")
  header(400 + dx, "streaks_col_total", "streaks_help_total", "total")
  header(490 + dx, "streaks_col_since", "streaks_help_since", "since")
  header(615 + dx, "streaks_col_expected", "streaks_help_expected", "expected")
  header(730 + dx, "streaks_col_ratio", "streaks_help_ratio", "ratio")
  header(800 + dx, "streaks_col_drops", "streaks_help_drops", "drops")
  imgui.Separator()
  K.STREAK_SEARCH_MAX_ROWS = K.STREAK_SEARCH_MAX_ROWS or 60
  local total_rows = #streak_cache.rows
  local shown = total_rows
  if streak_cache.searching and shown > K.STREAK_SEARCH_MAX_ROWS then
    shown = K.STREAK_SEARCH_MAX_ROWS
  end
  local function draw_second(row)
    local s = row.second
    local learned = K.U.item_kinds()[s.item]
    if no_detail_items[string.lower(s.item)] then
      learned = "misc"
    elseif not learned or learned == "other" then
      learned = WIKI_KINDS[string.lower(s.item)] or "weapon"
    end
    local c = kind_color(learned, s.item)
    local sr, sg, sb = streak_color(s.ratio)
    imgui.TextDisabled(K.KC.L("2e drop", "2nd drop", "2つ目のドロップ"))
    imgui.TextColored(c[1], c[2], c[3], 1, K.COMMON.full_label(s.item) .. " (1/" .. format_odds(s.expected) .. ")")
    imgui.Text(K.KC.L("Sans drop : ", "No drop: ", "ドロップなし: ") .. math.floor(s.since))
    imgui.TextColored(sr, sg, sb, 1, format_luck(s.ratio))
    imgui.Text(K.KC.L("Drops : ", "Drops: ", "ドロップ: ") .. s.drops)
  end
  local last_zrank = nil
  for i = 1, shown do
    local row = streak_cache.rows[i]
    local r, g, b = streak_color(row.ratio)
    if streak_sort.key == "name" and row.zrank ~= last_zrank then
      if last_zrank ~= nil then
        imgui.Separator()
      end
      last_zrank = row.zrank
      local zone_entry = ZONES.list[row.zrank]
      local zone_title = zone_entry and string.format("E%d  %s", zone_entry.ep, loc(zone_entry.zone)) or T("zone_other")
      imgui.TextColored(1.0, 0.85, 0.4, 1, "--- " .. zone_title .. " ---")
    end
    local name_text = clip(loc(row.name), streak_cache.show_section and 16 or (row.ep_tag and 19 or 24))
    local name_hovered
    if row.rare then
      name_hovered = K.rare_text(name_text)
    else
      if row.boss then
        imgui.TextColored(1.0, 0.25, 0.25, 1, name_text)
      else
        imgui.Text(name_text)
      end
      name_hovered = imgui.IsItemHovered()
    end
    if row.ep_tag then
      imgui.SameLine(0, 4)
      imgui.TextColored(streak_sort.episode_color[1], streak_sort.episode_color[2], streak_sort.episode_color[3], 1, row.ep_tag)
    end
    if streak_cache.show_section then
      local sr, sg, sb = section_color(row.section)
      imgui.SameLine(0, 6)
      imgui.TextColored(sr, sg, sb, 1, loc(row.section))
      imgui.SameLine(0, 6)
      imgui.TextColored(streak_sort.episode_color[1], streak_sort.episode_color[2], streak_sort.episode_color[3], 1, "E" .. tostring(row.episode))
      if streak_cache.show_diff then
        imgui.SameLine(0, 6)
        local dc = streak_sort.diff_colors[row.diff or 0] or streak_sort.diff_colors[3]
        imgui.TextColored(dc[1], dc[2], dc[3], 1, loc(difficulty_labels[row.diff or 0]))
      end
    end
    if name_hovered and not row.norare then
      imgui.BeginTooltip()
      imgui.Text(T("streaks_tip_item", K.COMMON.full_label(row.item), format_odds(row.expected)))
      imgui.Text(T("streaks_tip_total", math.floor(row.total)))
      if row.second then
        imgui.Separator()
        draw_second(row)
      end
      imgui.EndTooltip()
    end
    if row.norare then
      imgui.SameLine(190 + dx)
      imgui.TextDisabled("-")
      imgui.SameLine(400 + dx)
      imgui.TextColored(1.0, 0.9, 0.2, 1, tostring(math.floor(row.total)))
      imgui.SameLine(490 + dx)
      imgui.TextDisabled("-")
      imgui.SameLine(615 + dx)
      imgui.TextDisabled("-")
      imgui.SameLine(730 + dx)
      imgui.TextDisabled("-")
      imgui.SameLine(800 + dx)
      imgui.TextDisabled("-")
    else
      imgui.SameLine(190 + dx)
      local learned = K.U.item_kinds()[row.item]
      if no_detail_items[string.lower(row.item)] then
        learned = "misc"
      elseif not learned or learned == "other" then
        learned = WIKI_KINDS[string.lower(row.item)] or "weapon"
      end
      local item_color = kind_color(learned, row.item)
      imgui.TextColored(item_color[1], item_color[2], item_color[3], 1, clip(K.COMMON.full_label(row.item), row.second and 24 or 26))
      if row.second then
        local hov = imgui.IsItemHovered()
        imgui.SameLine(0, 4)
        local mr, mg, mb = streak_color(row.second.ratio)
        imgui.TextColored(mr, mg, mb, 1, "+")
        hov = hov or imgui.IsItemHovered()
        if hov then
          imgui.BeginTooltip()
          draw_second(row)
          imgui.EndTooltip()
        end
      end
      imgui.SameLine(400 + dx)
      imgui.TextColored(1.0, 0.9, 0.2, 1, tostring(math.floor(row.total)))
      imgui.SameLine(490 + dx)
      imgui.Text(tostring(math.floor(row.since)))
      imgui.SameLine(615 + dx)
      local expected_text = row.exp_text
      if not expected_text or row.exp_lang ~= lang.code then
        if row.expected >= 100 then
          local truncated = math.floor(row.expected * 10) / 10
          expected_text = string.format("%.1f", truncated)
          expected_text = string.gsub(expected_text, "%.0$", "")
        else
          expected_text = format_odds(row.expected)
        end
        if lang.code == "fr" then
          expected_text = string.gsub(expected_text, "%.", ",")
        end
        row.exp_text, row.exp_lang = expected_text, lang.code
      end
      imgui.Text("1/" .. expected_text)
      imgui.SameLine(730 + dx)
      imgui.TextColored(r, g, b, 1, format_luck(row.ratio))
      imgui.SameLine(800 + dx)
      if row.drops > 0 then
        imgui.TextColored(1.0, 0.25, 0.25, 1, tostring(row.drops))
      else
        imgui.Text("0")
      end
    end
  end
  if shown < total_rows then
    imgui.Separator()
    imgui.TextDisabled(T("streaks_limited", shown, total_rows))
  end
end

K.STREAK = { sort = streak_sort, color = streak_color, odds = streak_odds, wiki_kinds = WIKI_KINDS, draw_tab = draw_streaks_tab, bind = bind_locals }
end
