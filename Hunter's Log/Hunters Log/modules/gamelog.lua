local imgui = require("imgui")

return function(K)
local ADDON_DIR = K.ADDON_DIR
local T, difficulty_labels, difficulty_loc, draw_history_row, fmt_date, get_auto_episode, get_current_floor, get_game_context, lang, load_module, loc, section_color, section_colors, section_labels, set_status, streak_sort
K.GAMELOG = { games = {}, collapsed = {}, cache = nil, filter_section = nil }
function K.GAMELOG.bind(E)
  T = E.T
  difficulty_labels = E.difficulty_labels
  difficulty_loc = E.difficulty_loc
  draw_history_row = E.draw_history_row
  fmt_date = E.fmt_date
  get_auto_episode = E.get_auto_episode
  get_current_floor = E.get_current_floor
  get_game_context = E.get_game_context
  lang = E.lang
  load_module = E.load_module
  loc = E.loc
  section_color = E.section_color
  section_colors = E.section_colors
  section_labels = E.section_labels
  set_status = E.set_status
  streak_sort = E.streak_sort
end

K.GAMELOG.file = ADDON_DIR .. "game_history.lua"
K.GAMELOG.persist = true
K.GAMELOG.dir = ADDON_DIR .. "game_history/"

function K.GAMELOG.prepare_folder()
  local dir = K.GAMELOG.dir
  local function can_write()
    local test_path = dir .. "test_ecriture.tmp"
    local test = io.open(test_path, "w")
    if not test then return false end
    test:close()
    pcall(os.remove, test_path)
    return true
  end
  if not can_write() then
    local windows_folder = (string.gsub(ADDON_DIR .. "game_history", "/", "\\"))
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
  if not can_write() then return end
  K.GAMELOG.file = dir .. "game_history.lua"
end

K.GAMELOG.prepare_folder()
K.QUEST_PTR_ADDR = 0x00A95AA8
K.LOBBY_FLOOR = 15
K.GAMELOG_MAX = 5000
K.GAMELOG_MERGE_SECONDS = 600
K.GAMELOG_DROP_GRACE = 15

function K.GAMELOG.clean_name(text)
  if type(text) ~= "string" then return nil end
  text = string.gsub(text, "\t[Cc]%d", "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  if #text < 2 or #text > 60 then return nil end
  if string.find(text, "%c") then return nil end
  return text
end

function K.GAMELOG.read_quest_name()
  if K.GAMELOG.solylib == nil then
    K.GAMELOG.solylib = false
    for _, module_name in ipairs({ "solylib.quests.quests", "solylib.quests" }) do
      local ok, module = pcall(require, module_name)
      if ok and type(module) == "table" and type(module.GetQuestData) == "function" then
        K.GAMELOG.solylib = module
        break
      end
    end
  end
  if K.GAMELOG.solylib then
    local ok, data = pcall(K.GAMELOG.solylib.GetQuestData)
    if ok and type(data) == "table" then
      local name = K.GAMELOG.clean_name(data.name)
      if name then return name end
    end
  end
  local ok, text = pcall(function()
    local quest_ptr = pso.read_u32(K.QUEST_PTR_ADDR)
    if quest_ptr == 0 then return nil end
    local data_ptr = pso.read_u32(quest_ptr + 0x19C)
    if data_ptr == 0 then return nil end
    return pso.read_wstr(data_ptr + 0x18, 0x40)
  end)
  if ok then return K.GAMELOG.clean_name(text) end
  return nil
end

function K.GAMELOG.save()
  K.GAMELOG.rev = (K.GAMELOG.rev or 0) + 1
  if not K.GAMELOG.persist then return end
  pcall(function()
    local file = io.open(K.GAMELOG.file, "w")
    if not file then return end
    file:write("return {\n")
    for _, game in ipairs(K.GAMELOG.games) do
      file:write(string.format("{ name=%s, section=%q, difficulty=%q, episode=%d, start=%d, ended_at=%s, rares=%s, fav=%s },\n",
      game.name and string.format("%q", game.name) or "nil", tostring(game.section or ""), tostring(game.difficulty or ""),
      tonumber(game.episode) or 1, math.floor(tonumber(game.start) or 0),
      game.ended_at and string.format("%d", math.floor(game.ended_at)) or "nil",
      game.rare_names and string.format("%q", game.rare_names) or "nil",
      game.fav and "true" or "nil"))
    end
    file:write("}\n")
    file:close()
  end)
end

function K.GAMELOG.load()
  if not K.GAMELOG.persist then return end
  pcall(function()
    local function read_chunk(path)
      local file = io.open(path, "r")
      if not file then return nil end
      local content = file:read("*all")
      file:close()
      local chunk = loadstring(content)
      if not chunk then return nil end
      local ok, data = pcall(chunk)
      if ok and type(data) == "table" then return data end
      return nil
    end
    local list = read_chunk(K.GAMELOG.file) or {}
    for _, item in ipairs(list) do
      if type(item) == "table" and tonumber(item.start) and #K.GAMELOG.games < K.GAMELOG_MAX then
        K.GAMELOG.games[#K.GAMELOG.games + 1] = {
          name = item.name, section = item.section, difficulty = item.difficulty,
          episode = tonumber(item.episode) or 1, start = tonumber(item.start),
          ended_at = tonumber(item.ended_at) or tonumber(item.start), ended = true,
          rare_names = type(item.rares) == "string" and item.rares or nil,
          fav = item.fav == true or nil,
        }
      end
    end
  end)
end

function K.GAMELOG.quest_ptrs()
  local ok, a, b = pcall(function()
    local quest_ptr = pso.read_u32(K.QUEST_PTR_ADDR)
    if quest_ptr == 0 then return 0, 0 end
    return quest_ptr, pso.read_u32(quest_ptr + 0x19C)
  end)
  if ok then return a or 0, b or 0 end
  return 0, 0
end

function K.GAMELOG.rare_label(name, game)
  local shown = name
  local enemies = load_module("Hunters Log.charts.Enemies")
  if enemies then
    local diff_index
    for index, label in pairs(difficulty_labels) do
      if label == game.difficulty then diff_index = index end
    end
    local entry = (tonumber(game.episode) == 2 and enemies[name .. " E2"]) or enemies[name]
    if diff_index and type(entry) == "table" and entry[diff_index + 1] then
      shown = entry[diff_index + 1]
    end
  end
  return loc(shown)
end

function K.GAMELOG.rare_counts(cur)
  local counts = cur.rare_counts
  if not counts then
    counts = { order = {} }
    for entry in string.gmatch(cur.rare_names or "", "[^,]+") do
      local name, count = string.match(entry, "^(.-)%*(%d+)$")
      name = name or entry
      if not counts[name] then counts.order[#counts.order + 1] = name end
      counts[name] = (counts[name] or 0) + (tonumber(count) or 1)
    end
    cur.rare_counts = counts
  end
  return counts
end

K.GAMELOG.rf = { frame = -1, alive = {}, names = {}, addr = {} }

function K.GAMELOG.rare_rebuild(cur)
  local counts = K.GAMELOG.rare_counts(cur)
  local parts = {}
  for _, name in ipairs(counts.order) do
    parts[#parts + 1] = counts[name] > 1 and (name .. "*" .. counts[name]) or name
  end
  cur.rare_names = #parts > 0 and table.concat(parts, ",") or nil
  K.GAMELOG.dirty = true
end

function K.GAMELOG.rare_flush()
  local rf = K.GAMELOG.rf
  if next(rf.alive) ~= nil then
    local cur = K.GAMELOG.games[1]
    if cur and not cur.ended then
      local counts = K.GAMELOG.rare_counts(cur)
      cur.rare_hw = cur.rare_hw or {}
      cur.rare_kills = cur.rare_kills or {}
      local changed = false
      for fk, alive in pairs(rf.alive) do
        local total = (cur.rare_kills[fk] or 0) + alive
        local peak = cur.rare_hw[fk] or 0
        if total > peak then
          local name = rf.names[fk]
          if not counts[name] then counts.order[#counts.order + 1] = name end
          counts[name] = (counts[name] or 0) + (total - peak)
          cur.rare_hw[fk] = total
          changed = true
        end
      end
      if changed then K.GAMELOG.rare_rebuild(cur) end
    end
  end
  for k in pairs(rf.alive) do rf.alive[k] = nil end
  for k in pairs(rf.names) do rf.names[k] = nil end
  for k in pairs(rf.addr) do rf.addr[k] = nil end
end

function K.GAMELOG.note_rare(key, address, floor)
  local cur = K.GAMELOG.games[1]
  if not cur or cur.ended then return end
  local rf = K.GAMELOG.rf
  local frame = K.U.frame()
  if rf.frame ~= frame then
    K.GAMELOG.rare_flush()
    rf.frame = frame
  end
  local base = string.gsub(key, " E2$", "")
  local fk = (floor or 0) .. ":" .. base
  rf.alive[fk] = (rf.alive[fk] or 0) + 1
  rf.names[fk] = base
  if address then rf.addr[address] = true end
end

function K.GAMELOG.note_rare_kill(key, address, floor)
  local cur = K.GAMELOG.games[1]
  if not cur or cur.ended then return end
  local base = string.gsub(key, " E2$", "")
  local fk = (floor or 0) .. ":" .. base
  cur.rare_kills = cur.rare_kills or {}
  cur.rare_kills[fk] = (cur.rare_kills[fk] or 0) + 1
  local rf = K.GAMELOG.rf
  if address and rf.addr[address] then
    rf.addr[address] = nil
    rf.alive[fk] = math.max(0, (rf.alive[fk] or 1) - 1)
  end
end

function K.GAMELOG.split_resumed(old, final_section)
  local before = {}
  for entry in string.gmatch(old.rare_before or "", "[^,]+") do
    local name, count = string.match(entry, "^(.-)%*(%d+)$")
    before[name or entry] = (before[name or entry] or 0) + (tonumber(count) or 1)
  end
  local counts = K.GAMELOG.rare_counts(old)
  local parts = {}
  for _, name in ipairs(counts.order) do
    local extra = counts[name] - (before[name] or 0)
    if extra > 0 then parts[#parts + 1] = extra > 1 and (name .. "*" .. extra) or name end
  end
  local new_game = {
    name = old.name, section = final_section, difficulty = old.difficulty, episode = old.episode,
    start = old.resumed_at or os.time(), ended = false, qptr = old.qptr, qdata = old.qdata,
    rare_names = #parts > 0 and table.concat(parts, ",") or nil,
    rare_hw = old.rare_hw, rare_kills = old.rare_kills,
  }
  old.rare_names = (old.rare_before ~= "" and old.rare_before) or nil
  old.rare_counts, old.rare_hw, old.rare_kills = nil, nil, nil
  old.ended, old.ended_at = true, old.prev_ended_at or os.time()
  old.loose_resume, old.resumed_at, old.prev_ended_at, old.rare_before = nil, nil, nil, nil
  table.insert(K.GAMELOG.games, 1, new_game)
end

function K.GAMELOG.update()
  if K.U.frame() % 15 ~= 0 then return end
  if K.GAMELOG.rf.frame ~= K.U.frame() then K.GAMELOG.rare_flush() end
  if K.GAMELOG.dirty then
    K.GAMELOG.dirty = false
    K.GAMELOG.save()
  end
  local floor = get_current_floor()
  local lobby_now = K.lobby_candidate(floor)
  local lobby_confirmed = K.is_lobby(floor)
  local valid_floor = (floor ~= nil and floor > 0)
  local in_quest = valid_floor and not lobby_confirmed
  local can_start = valid_floor and not lobby_now
  local now = os.time()
  local games = K.GAMELOG.games
  local cur = games[1]
  local qptr, qdata = K.GAMELOG.quest_ptrs()
  if cur and cur.ended and not cur.lost then
    if cur.qptr and cur.qptr ~= 0 then
      if qptr == 0 or qptr ~= cur.qptr or qdata ~= cur.qdata then cur.lost = true end
    elseif lobby_confirmed then
      cur.lost = true
    end
  end
  if can_start and (not cur or cur.ended) then
    local difficulty_label, section_label = get_game_context()
    local name = K.GAMELOG.read_quest_name()
    local quest_game = cur and cur.qptr and cur.qptr ~= 0
    local same_section = cur and (cur.section == section_label
    or string.find(tostring(cur.section), "(perso)", 1, true) ~= nil
    or string.find(tostring(section_label), "(perso)", 1, true) ~= nil)
    local resume_window = quest_game and K.GAMELOG_MERGE_SECONDS or 7200
    local resumable = cur and cur.ended_at and not cur.lost and now - cur.ended_at <= resume_window
    and same_section and cur.difficulty == difficulty_label
    and ((quest_game and qptr ~= 0 and cur.name == name)
    or ((not quest_game) and qptr == 0))
    if resumable then
      cur.loose_resume = (cur.section ~= section_label) or nil
      cur.prev_ended_at, cur.resumed_at = cur.ended_at, now
      cur.rare_before = cur.rare_names or ""
      K.MAX_SRV_ID, K.PREV_MAX_SRV_ID, K.EMPTY_SINCE = nil, nil, nil
      K.COUNTED_IDS = {}
      cur.ended, cur.ended_at = false, nil
    else
      table.insert(games, 1, {
        name = name, section = section_label, difficulty = difficulty_label,
        episode = get_auto_episode() or K.U.episode(), start = now, ended = false,
        qptr = qptr, qdata = qdata,
      })
      while #games > K.GAMELOG_MAX do
        local removed = false
        for i = #games, 2, -1 do
          if not games[i].fav then
            table.remove(games, i)
            removed = true
            break
          end
        end
        if not removed then break end
      end
      K.MAX_SRV_ID, K.PREV_MAX_SRV_ID, K.EMPTY_SINCE = nil, nil, nil
      K.COUNTED_IDS = {}
      K.KC.session = {}
      K.KC.cache = nil
    end
    K.GAMELOG.save()
  elseif in_quest and cur and not cur.ended then
    local changed = false
    if cur.loose_resume and K.U.section_name() then
      local _, final_section = get_game_context()
      if final_section and not string.find(tostring(final_section), "(perso)", 1, true) then
        if final_section ~= cur.section then
          K.GAMELOG.split_resumed(cur, final_section)
          K.GAMELOG.save()
          return
        end
        cur.loose_resume = nil
      end
    end
    if not cur.name then
      local name = K.GAMELOG.read_quest_name()
      if name then cur.name = name; changed = true end
    end
    if K.U.section_name() and string.find(tostring(cur.section), "(perso)", 1, true) then
      local _, section_label = get_game_context()
      if section_label ~= cur.section then cur.section = section_label; changed = true end
    end
    if changed then K.GAMELOG.save() end
  elseif (not in_quest) and cur and not cur.ended then
    cur.ended, cur.ended_at = true, now
    K.GAMELOG.save()
  end
end

function K.GAMELOG.drops(index)
  local list = {}
  local game = K.GAMELOG.games[index]
  if not game then return list end
  local last_time = game.ended_at and (game.ended_at + K.GAMELOG_DROP_GRACE) or math.huge
  local newer = K.GAMELOG.games[index - 1]
  if newer then last_time = math.min(last_time, newer.start - 1) end
  for position = #K.U.drop_history(), 1, -1 do
    local h = K.U.drop_history()[position]
    local t = tonumber(h.time) or 0
    if t >= game.start and t <= last_time then
      list[#list + 1] = h
    end
  end
  return list
end

function K.GAMELOG.display_name(name, game_episode)
  if lang.code ~= "ja" or type(name) ~= "string" then return name end
  local key = string.gsub(string.lower(name), "^%d+%-%d+%s*:%s*", "")
  key = string.gsub(key, "[^%w]", "")
  local ja = K.QUEST_JA[game_episode or 0] and K.QUEST_JA[game_episode or 0][key]
  if not ja then
    for _, ep in ipairs({ 1, 2, 4 }) do
      if K.QUEST_JA[ep][key] then ja = K.QUEST_JA[ep][key]; break end
    end
  end
  return ja or name
end

function K.GAMELOG.visible(sub_fav)
  local games = K.GAMELOG.games
  local filter = K.GAMELOG.filter_section
  local frame = math.floor(K.U.frame() / 60)
  local vis = K.GAMELOG.vis
  if vis and vis.frame == frame and vis.sub_fav == sub_fav and vis.filter == filter and vis.count == #games and vis.rev == K.GAMELOG.rev then
    return vis
  end
  local indices, fav_games = {}, 0
  for index, game in ipairs(games) do
    if game.fav then fav_games = fav_games + 1 end
    local name = game._sec
    if not name or game._sec_src ~= game.section then
      name = (string.gsub(tostring(game.section or ""), " %(perso%)$", ""))
      game._sec, game._sec_src = name, game.section
    end
    if (not sub_fav or game.fav) and (not filter or name == filter) then
      indices[#indices + 1] = index
    end
  end
  vis = { frame = frame, sub_fav = sub_fav, filter = filter, count = #games, rev = K.GAMELOG.rev, indices = indices, fav_games = fav_games }
  K.GAMELOG.vis = vis
  return vis
end

function K.GAMELOG.short_games(min_seconds)
  local list = {}
  for index, game in ipairs(K.GAMELOG.games) do
    if game.ended and not game.fav and tonumber(game.ended_at) and tonumber(game.start)
      and (game.ended_at - game.start) < min_seconds then
      list[#list + 1] = index
    end
  end
  return list
end

function K.GAMELOG.purge_short(min_seconds)
  local list = K.GAMELOG.short_games(min_seconds)
  for position = #list, 1, -1 do
    local game = K.GAMELOG.games[list[position]]
    K.GAMELOG.collapsed[game.start] = nil
    table.remove(K.GAMELOG.games, list[position])
  end
  if #list > 0 then
    K.GAMELOG.cache = nil
    K.GAMELOG.save()
  end
  return #list
end

K.GAMELOG.PURGE_SECONDS = 30
K.GAMELOG.PURGE_TEXT = {
  fr = { button = "Supprimer < 30 s", ask = "Supprimer %d partie(s) de moins de 30 s ?", yes = "Oui", no = "Non", none = "Aucune partie de moins de 30 s.", done = "%d partie(s) supprimee(s)." },
  en = { button = "Delete < 30 s", ask = "Delete %d game(s) shorter than 30 s?", yes = "Yes", no = "No", none = "No game shorter than 30 s.", done = "%d game(s) deleted." },
  ja = { button = "30秒未満の値を削除する", ask = "30秒未満の%d件を削除しますか？", yes = "はい", no = "いいえ", none = "30秒未満のゲームはありません。", done = "%d件削除しました。" },
}

function K.GAMELOG.draw_purge()
  local text = K.GAMELOG.PURGE_TEXT[K.U.lang.code] or K.GAMELOG.PURGE_TEXT.fr
  if K.GAMELOG.purge_ask then
    imgui.TextColored(1, 0.5, 0.3, 1, string.format(text.ask, K.GAMELOG.purge_ask))
    imgui.SameLine(0, 8)
    if imgui.Button(text.yes .. "##purge_yes") then
      local count = K.GAMELOG.purge_short(K.GAMELOG.PURGE_SECONDS)
      K.GAMELOG.purge_ask = nil
      set_status(string.format(text.done, count))
    end
    imgui.SameLine(0, 8)
    if imgui.Button(text.no .. "##purge_no") then K.GAMELOG.purge_ask = nil end
  elseif imgui.Button(text.button .. "##purge_short") then
    local count = #K.GAMELOG.short_games(K.GAMELOG.PURGE_SECONDS)
    if count == 0 then
      set_status(text.none)
    else
      K.GAMELOG.purge_ask = count
    end
  end
end

function K.GAMELOG.draw()
  K.CLIP.frame_begin("games")
  local games = K.GAMELOG.games
  if #games == 0 then
    imgui.TextDisabled(T("game_none"))
    return
  end
  local fav_games = K.GAMELOG.visible(K.GAMELOG.sub == "fav").fav_games
  local sub_fav = K.GAMELOG.sub == "fav"
  if imgui.Button((not sub_fav and ("[" .. T("sub_all") .. "]") or T("sub_all")) .. "##game_sub_all") then
    K.GAMELOG.sub = "all"
  end
  imgui.SameLine(0, 4)
  local game_fav_label = K.star_text() .. " " .. T("sub_fav") .. " (" .. fav_games .. ")"
  if imgui.Button((sub_fav and ("[" .. game_fav_label .. "]") or game_fav_label) .. "##game_sub_fav") then
    K.GAMELOG.sub = "fav"
  end
  sub_fav = K.GAMELOG.sub == "fav"
  imgui.SameLine(0, 24)
  K.GAMELOG.draw_purge()
  imgui.Separator()
  if sub_fav and fav_games == 0 then
    imgui.TextDisabled(T("fav_none_games"))
    return
  end
  local cache = K.GAMELOG.cache
  if not cache or K.U.frame() - cache.frame >= 300 or cache.rev ~= K.HIST_REV or cache.count ~= #K.U.drop_history() or cache.games ~= #games then
    cache = { frame = K.U.frame(), rev = K.HIST_REV, count = #K.U.drop_history(), games = #games, lists = {} }
    K.GAMELOG.cache = cache
  end
  local label_color = { 1.0, 0.9, 0.2 }
  local function label(text)
    imgui.TextColored(label_color[1], label_color[2], label_color[3], 1, text)
    imgui.SameLine(0, 6)
  end
  imgui.Text(T("game_room"))
  imgui.SameLine(0, 6)
  local function game_history_id_button(label, selected, id, color)
    local text = selected and ("[" .. label .. "]") or label
    local pushed = color and pcall(imgui.PushStyleColor, "Text", color[1], color[2], color[3], 1.0)
    local clicked = imgui.Button(text .. "##game_history_id_" .. id)
    if pushed then pcall(imgui.PopStyleColor) end
    return clicked
  end
  if game_history_id_button(T("streaks_all"), K.GAMELOG.filter_section == nil, "all") then
    K.GAMELOG.filter_section = nil
  end
  for section_index = 0, 9 do
    imgui.SameLine(0, 4)
    local section_name = section_labels[section_index]
    if game_history_id_button(loc(section_name), K.GAMELOG.filter_section == section_name,
      tostring(section_index), section_colors[section_name]) then
      K.GAMELOG.filter_section = (K.GAMELOG.filter_section == section_name) and nil or section_name
    end
  end
  local visible_indices = K.GAMELOG.visible(sub_fav).indices
  local visible_games = #visible_indices
  imgui.TextDisabled(T("games_count", visible_games, #games))
  K.PAGER.reset_on_change("games", tostring(K.GAMELOG.filter_section) .. "|" .. tostring(K.GAMELOG.sub))
  local games_page = K.PAGER.draw("games", visible_games)
  imgui.Separator()
  K.draw_history_header()
  imgui.Separator()
  local now = os.time()
  local first_game, last_game = K.PAGER.range("games", games_page, visible_games)
  for position = first_game, last_game do
    local index = visible_indices[position]
    local game = games[index]
    do
      local drops = cache.lists[index]
      if not drops then
        drops = K.GAMELOG.drops(index)
        cache.lists[index] = drops
      end
      local folded = K.GAMELOG.collapsed[game.start]
      if folded == nil then folded = (#drops == 0) end
      if imgui.Button((folded and "+" or "-") .. "##game_fold_" .. tostring(game.start)) then
        K.GAMELOG.collapsed[game.start] = not folded
      end
      imgui.SameLine(0, 8)
      local fav_id = game._fid
      if not fav_id then
        fav_id = "g" .. tostring(game.start)
        game._fid = fav_id
      end
      if K.fav_button(fav_id, game.fav) then
        game.fav = (not game.fav) or nil
        K.GAMELOG.save()
      end
      imgui.SameLine(0, 8)
      label(T("game_quest"))
      if game.name then
        imgui.Text(K.GAMELOG.display_name(game.name, game.episode))
      else
        imgui.TextDisabled(T("game_quest_unknown"))
      end
      imgui.SameLine(0, 16)
      label(T("game_room"))
      local section_name = string.gsub(tostring(game.section or "?"), " %(perso%)$", "")
      local sr, sg, sb = section_color(section_name)
      imgui.TextColored(sr, sg, sb, 1, tostring(game.section or "?"))
      imgui.SameLine(0, 16)
      label(T("game_difficulty"))
      local diff_color = { 1, 1, 1 }
      for diff_index, name in pairs(difficulty_labels) do
        if name == game.difficulty then diff_color = streak_sort.diff_colors[diff_index] or diff_color end
      end
      imgui.TextColored(diff_color[1], diff_color[2], diff_color[3], 1, difficulty_loc(game.difficulty or "?"))
      imgui.SameLine(0, 16)
      label(T("game_episode"))
      imgui.Text(tostring(game.episode or "?"))
      if game.rare_names and game.rare_names ~= "" then
        imgui.SameLine(0, 16)
        imgui.TextColored(0.10, 0.90, 1.0, 1, T("game_rare"))
        imgui.SameLine(0, 6)
        local shown, extra = {}, 0
        for entry in string.gmatch(game.rare_names, "[^,]+") do
          if #shown < 4 then
            local name, count = string.match(entry, "^(.-)%*(%d+)$")
            shown[#shown + 1] = {
              label = K.GAMELOG.rare_label(name or entry, game),
              count = (name and tonumber(count) > 1) and tonumber(count) or nil,
            }
          else
            extra = extra + 1
          end
        end
        local function char_count(text)
          local n = 0
          for _ in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
          return n
        end
        local offset = 0
        for position, rare in ipairs(shown) do
          if position > 1 then
            imgui.SameLine(0, 0)
            K.rare_text(", ", offset)
            offset = offset + 2
          end
          if position > 1 then imgui.SameLine(0, 0) end
          K.rare_text(rare.label, offset)
          offset = offset + char_count(rare.label)
          if rare.count then
            local suffix = " x" .. rare.count
            imgui.SameLine(0, 0)
            imgui.TextColored(1.0, 0.9, 0.2, 1, suffix)
            offset = offset + char_count(suffix)
          end
        end
        if extra > 0 then
          imgui.SameLine(0, 0)
          K.rare_text(" +" .. extra, offset)
        end
      end
      imgui.Text("    ")
      imgui.SameLine(0, 0)
      label(T("game_start"))
      imgui.Text(fmt_date(game.start))
      imgui.SameLine(0, 16)
      label(T("game_duration"))
      local seconds = math.max(0, math.floor((game.ended_at or now) - game.start))
      imgui.Text(string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60))
      imgui.SameLine(0, 8)
      if game.ended then
        imgui.TextDisabled(T("game_finished"))
      else
        imgui.TextColored(0.4, 1.0, 0.4, 1, T("game_running"))
      end
      imgui.SameLine(0, 16)
      imgui.TextColored(label_color[1], label_color[2], label_color[3], 1, T("game_drops_title", #drops))
      imgui.SameLine(0, 24)
      if K.GAMELOG.confirm == game.start then
        imgui.TextColored(1, 0.5, 0.3, 1, T("game_delete_ask"))
        imgui.SameLine(0, 8)
        if imgui.Button(T("game_delete_yes") .. "##gdel_yes_" .. tostring(game.start)) then
          table.remove(games, index)
          K.GAMELOG.confirm = nil
          K.GAMELOG.cache = nil
          K.GAMELOG.save()
          break
        end
        imgui.SameLine(0, 8)
        if imgui.Button(T("game_delete_no") .. "##gdel_no_" .. tostring(game.start)) then
          K.GAMELOG.confirm = nil
        end
      else
        if imgui.Button("X##gdel_" .. tostring(game.start)) then
          if game.fav then
            set_status(T("fav_protected_game"))
          else
            K.GAMELOG.confirm = game.start
          end
        end
      end
      imgui.Separator()
      if not folded then
        if #drops == 0 then
          imgui.TextDisabled(T("game_no_drops"))
          imgui.Separator()
        else
          for _, h in ipairs(drops) do
            K.CLIP.row(draw_history_row, h)
          end
          K.CLIP.finish()
        end
      end
      imgui.Text("")
    end
  end
end
end
