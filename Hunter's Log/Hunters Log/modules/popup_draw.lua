local imgui = require("imgui")

return function(K)
local PERFECT_ARMOR_STATS, T, clip, get_current_tab, heat_color, hsv_to_rgb, iname, item_category, kind_color, lang, loc, parse_weapon_stats, save_data, section_color, set_status, get_window_open
function K.POPUP.bind(E)
  PERFECT_ARMOR_STATS = E.PERFECT_ARMOR_STATS
  T = E.T
  clip = E.clip
  get_current_tab = E.get_current_tab
  heat_color = E.heat_color
  hsv_to_rgb = E.hsv_to_rgb
  iname = E.iname
  item_category = E.item_category
  kind_color = E.kind_color
  lang = E.lang
  loc = E.loc
  parse_weapon_stats = E.parse_weapon_stats
  save_data = E.save_data
  section_color = E.section_color
  set_status = E.set_status
  get_window_open = E.get_window_open
end

function K.POPUP.measure(segs, scale)
  local total = 0
  for _, s in ipairs(segs) do
    local ok, w = pcall(imgui.CalcTextSize, s[1])
    s.w = ((ok and tonumber(w)) or (#s[1] * 7)) * scale
    total = total + s.w
  end
  return total
end

function K.POPUP.draw_line(segs, y, width, alpha, outline, thick)
  local total = 0
  for _, s in ipairs(segs) do total = total + s.w end
  local x0 = math.max(0, (width - total) / 2)
  if thick > 0 then
    local d = thick * 0.7
    local offsets = { { -thick, 0 }, { thick, 0 }, { 0, -thick }, { 0, thick }, { -d, -d }, { d, -d }, { -d, d }, { d, d } }
    for _, o in ipairs(offsets) do
      local x = x0
      for _, s in ipairs(segs) do
        imgui.SetCursorPos(x + o[1], y + o[2])
        imgui.TextColored(outline[1], outline[2], outline[3], alpha, s[1])
        x = x + s.w
      end
    end
  end
  local x = x0
  for _, s in ipairs(segs) do
    imgui.SetCursorPos(x, y)
    imgui.TextColored(s[2], s[3], s[4], alpha, s[1])
    x = x + s.w
  end
end

function K.POPUP.stats_segments(cur)
  local stats = tostring(cur.stats or "")
  local grind, values = parse_weapon_stats(stats)
  if values then
    local segs = {}
    if string.find(stats, "UNTEKKED", 1, true) then
      segs[#segs + 1] = { "[U] ", 1, 0.2, 0.2 }
    end
    if grind and grind > 0 then
      segs[#segs + 1] = { "+" .. tostring(grind) .. " ", 1, 1, 1 }
    end
    segs[#segs + 1] = { "[", 1, 1, 1 }
    for i = 1, 5 do
      local r, g, b = heat_color(values[i])
      segs[#segs + 1] = { tostring(values[i]), r, g, b }
      segs[#segs + 1] = { (i < 4 and "/") or (i == 4 and "|") or "]", 1, 1, 1 }
    end
    return segs
  end
  local dfp, evp = string.match(stats, "DFP:%s*%+(%d+)%s*|%s*EVP:%s*%+(%d+)")
  if dfp and evp then
    dfp, evp = tonumber(dfp), tonumber(evp)
    local limits = PERFECT_ARMOR_STATS[string.lower(tostring(cur.name or ""))]
    local segs = {}
    local function add_limit(value, maximum)
      if maximum ~= nil then
        local label = "[" .. value .. "/" .. maximum .. "]"
        if value == maximum then
          segs[#segs + 1] = { label, 1.0, 0.9, 0.2 }
        else
          segs[#segs + 1] = { label, 1, 1, 1 }
        end
      else
        segs[#segs + 1] = { "[" .. tostring(value) .. "]", 1, 1, 1 }
      end
    end
    add_limit(dfp, limits and limits.dfp or nil)
    segs[#segs + 1] = { " ", 1, 1, 1 }
    add_limit(evp, limits and limits.evp or nil)
    local slots = tonumber(string.match(stats, "%[(%d+)S%]"))
    if slots then
      segs[#segs + 1] = { " ", 1, 1, 1 }
      if slots == 4 then
        segs[#segs + 1] = { "[4S]", 1.0, 0.9, 0.2 }
      else
        segs[#segs + 1] = { "[" .. tostring(slots) .. "S]", 1, 1, 1 }
      end
    end
    return segs
  end
  if stats == "" or stats == "N/A" or stats == "Sans attributs particuliers" then return nil end
  if cur.kind == "weapon" or cur.kind == "armor" then
    return { { clip(stats, 44), 1, 1, 1 } }
  end
  return nil
end

function K.POPUP.rect(x, y, w, h, r, g, b, a)
  if w < 1 or h < 1 or a <= 0.001 then return true end
  if type(imgui.ProgressBar) ~= "function" then return false end
  local pushed = 0
  local function push(name, cr, cg, cb, ca)
    if pcall(imgui.PushStyleColor, name, cr, cg, cb, ca) then pushed = pushed + 1 end
  end
  push("FrameBg", 0, 0, 0, 0)
  push("PlotHistogram", r, g, b, a)
  push("Text", 0, 0, 0, 0)
  push("Border", 0, 0, 0, 0)
  imgui.SetCursorPos(x, y)
  local ok = pcall(imgui.ProgressBar, 1.0, w, h, "")
  if not ok then ok = pcall(imgui.ProgressBar, 1.0, w, h) end
  for _ = 1, pushed do pcall(imgui.PopStyleColor) end
  return ok
end

K.POPUP.icons = K.UI_DATA.icons

function K.POPUP.draw_icon(icon, x, y, cell, alpha, mirror)
  local ok_all = true
  for ry, row in ipairs(icon.rows) do
    if mirror then row = string.reverse(row) end
    local cx = 1
    while cx <= #row do
      local ch = string.sub(row, cx, cx)
      local last = cx
      while last < #row and string.sub(row, last + 1, last + 1) == ch do last = last + 1 end
      local c = icon.colors[ch]
      if c then
        ok_all = K.POPUP.rect(x + (cx - 1) * cell, y + (ry - 1) * cell, (last - cx + 1) * cell, cell, c[1], c[2], c[3], alpha) and ok_all
      end
      cx = last + 1
    end
  end
  return ok_all
end

function K.POPUP.tekk_segments(cur)
  local stats = tostring(cur.stats or "")
  if not string.find(stats, "UNTEKKED", 1, true) then return nil end
  local special = K.COMMON.split(tostring(cur.name))
  if not special then return nil end
  local segs = {}
  local range = K.COMMON.tekk_range(special)
  if range and #range > 1 then
    segs[#segs + 1] = { T("popup_tekk"), 1, 1, 1 }
    for index, name in ipairs(range) do
      local rgb = K.COMMON.special_color(name)
      segs[#segs + 1] = { K.COMMON.special_label(name), rgb[1], rgb[2], rgb[3] }
      if index < #range then segs[#segs + 1] = { " / ", 1, 1, 1 } end
    end
  end
  local _, values = parse_weapon_stats(stats)
  if values and values[5] then
    segs[#segs + 1] = { ((#segs > 0) and T("popup_hitmax") or T("popup_hitmax_alone")) .. tostring(values[5] + 10), 1, 1, 1 }
  end
  if #segs == 0 then return nil end
  return segs
end

function K.POPUP.draw()
  local P, C = K.POPUP, K.POPUP.cfg
  local now = os.clock()
  if P.pos_changed and now - P.pos_changed > 1 then
    P.pos_changed = nil
    save_data()
  end
  local cur, alpha
  if P.preview and get_window_open() and get_current_tab() == "popup" then
    cur, alpha = P.preview_sample or P.preview_entry, 1
  else
    local function base_duration(entry)
      return (entry and entry.rare) and C.rare_duration or C.duration
    end
    local duration = (#P.queue > 0) and math.min(3, base_duration(P.current)) or base_duration(P.current)
    if P.current and now - P.current.started >= duration then P.current = nil end
    if not P.current and #P.queue > 0 then
      P.current = table.remove(P.queue, 1)
      P.current.started = now
    end
    cur = P.current
    if not cur then return end
    duration = (#P.queue > 0) and math.min(3, base_duration(cur)) or base_duration(cur)
    local age = now - cur.started
    alpha = math.max(0, math.min(1, age / 0.6, (duration - age) / 0.6))
  end
  local theme = P.themes[cur.rare and C.rare_theme or C.theme] or P.themes[1]
  local c1, c2 = theme.c1, theme.c2
  if theme.id_color then
    local r, g, b = section_color(cur.section)
    c1, c2 = { r * 0.55, g * 0.55, b * 0.55 }, { r, g, b }
  end
  local pulse = C.shine and (0.5 + 0.5 * math.sin(now * 5)) or 0.5
  local bg_r = c1[1] + (c2[1] - c1[1]) * pulse
  local bg_g = c1[2] + (c2[2] - c1[2]) * pulse
  local bg_b = c1[3] + (c2[3] - c1[3]) * pulse
  local opacity = C.opacity / 100
  local name_segs, stats_segs, rate_segs, tekk_segs
  if cur.rare then
    name_segs = {}
    local char_index = 0
    for char in string.gmatch(tostring(cur.name), "[%z\1-\127\194-\244][\128-\191]*") do
      local phase = (now * 0.23 + char_index * 0.09) % 1
      local wave = math.abs(phase * 2 - 1)
      local cr, cg, cb = hsv_to_rgb((0.78 + 0.37 * wave) % 1, 0.85, 1.0)
      name_segs[#name_segs + 1] = { char, cr, cg, cb }
      char_index = char_index + 1
    end
    if C.rare_zone and cur.line2 and cur.line2 ~= "" then
      stats_segs = { { clip(tostring(cur.line2), 44), 1, 1, 1 } }
    end
  else
    name_segs = K.COMMON.name_segments(iname(cur.name))
    stats_segs = C.show_stats and K.POPUP.stats_segments(cur) or nil
    local rate_text = C.show_rate and cur.rate and tostring(cur.rate) ~= "" and clip(tostring(cur.rate), 40) or nil
    rate_segs = rate_text and { { rate_text, 1, 1, 1 } } or nil
    tekk_segs = C.show_stats and K.POPUP.tekk_segments(cur) or nil
  end
  local s = C.scale / 100
  local f = C.font / 100
  local name_scale, other_scale = 1.25 * s * f, 1.0 * s * f
  local ok_lh, lh = pcall(imgui.GetTextLineHeight)
  lh = (ok_lh and tonumber(lh)) or 16
  local pad, gap = 8 * s, 3 * s
  local name_w = K.POPUP.measure(name_segs, name_scale)
  local needed = name_w
  local icon, icon_cell, icon_w, icon_h, icon_gap
  if C.show_icon and P.bars_ok ~= false and type(imgui.ProgressBar) == "function" then
    local list = P.icons[cur.kind]
    if list then
      local choice = C[cur.kind .. "_icon"] or 0
      if choice == 0 then
        if cur.kind == "weapon" then
          choice = P.weapon_icon_index[cur.wclass or ""] or 1
        else
          choice = P.armor_icon_index[cur.wclass or ""] or 2
        end
      end
      icon = list[choice] or list[1]
    end
    if icon then
      icon_cell = math.max(1, math.floor(lh * name_scale / #icon.rows))
      icon_w, icon_h = #icon.rows[1] * icon_cell, #icon.rows * icon_cell
      icon_gap = 8 * s
      needed = name_w + 2 * (icon_w + icon_gap)
    end
  end
  if stats_segs then needed = math.max(needed, K.POPUP.measure(stats_segs, other_scale)) end
  if rate_segs then needed = math.max(needed, K.POPUP.measure(rate_segs, other_scale)) end
  if tekk_segs then needed = math.max(needed, K.POPUP.measure(tekk_segs, other_scale)) end
  local border = math.floor(C.border)
  local width = math.max(220 * s, needed + pad * 2 + 8)
  local height = pad * 2 + 4 + lh * name_scale
  if stats_segs then height = height + gap + lh * other_scale end
  if rate_segs then height = height + gap + lh * other_scale end
  if tekk_segs then height = height + gap + lh * other_scale end
  width, height = math.ceil(width), math.ceil(height)
  local ok_ds, dw, dh = pcall(imgui.GetDisplaySize)
  if not (ok_ds and tonumber(dw) and tonumber(dh)) then dw, dh = 1280, 720 end
  local x = math.floor(math.max(0, math.min(dw - width, dw * C.pos_x / 100 - width / 2)) + 0.5)
  local y = math.floor(math.max(0, math.min(dh - height, dh * C.pos_y / 100)) + 0.5)
  imgui.SetNextWindowSize(width, height, "Always")
  local place = C.locked or not cur.placed or P.force_place or math.abs(width - (P.last_width or 0)) > 0.5
  imgui.SetNextWindowPos(x, y, place and "Always" or "FirstUseEver")
  local use_bars = C.render == 2 and P.bars_ok ~= false
  local pushed_colors, pushed_vars = 0, 0
  local function push_color(name, r, g, b, a)
    local ok = pcall(imgui.PushStyleColor, name, r, g, b, a)
    if ok then pushed_colors = pushed_colors + 1 end
    return ok
  end
  local function push_var(name, ...)
    local ok = pcall(imgui.PushStyleVar, name, ...)
    if ok then pushed_vars = pushed_vars + 1 end
    return ok
  end
  if use_bars then
    push_color("WindowBg", 0, 0, 0, 0)
    push_var("WindowPadding", 0, 0)
    push_var("WindowRounding", 0)
    push_var("FrameRounding", 0)
  else
    push_color("WindowBg", bg_r, bg_g, bg_b, opacity * alpha)
    push_color("Border", theme.border[1], theme.border[2], theme.border[3], opacity * alpha)
    push_var("WindowBorderSize", border)
    push_var("WindowRounding", 8 * s)
  end
  local title = "Hunter's Log Drop Popup##drop_popup"
  local flags = { "NoTitleBar", "NoResize", "NoScrollbar", "NoCollapse", "NoSavedSettings" }
  if C.locked then flags[#flags + 1] = "NoMove" end
  local extra = nil
  if use_bars and not P.nobg_failed then
    extra = "NoBackground"
  elseif not use_bars and border > 0 and not P.showborders_failed then
    extra = "ShowBorders"
  end
  local status
  if extra then
    local flags2 = {}
    for i, v in ipairs(flags) do flags2[i] = v end
    flags2[#flags2 + 1] = extra
    local ok_begin, st = pcall(imgui.Begin, title, nil, flags2)
    if ok_begin then
      status = st
    else
      if extra == "NoBackground" then P.nobg_failed = true else P.showborders_failed = true end
      status = imgui.Begin(title, nil, flags)
    end
  else
    status = imgui.Begin(title, nil, flags)
  end
  if status then
    if not place then
      local ok_wp, wx, wy = pcall(imgui.GetWindowPos)
      if ok_wp and tonumber(wx) and tonumber(wy) and math.abs(wx - x) + math.abs(wy - y) > 1.0 then
        C.pos_x = math.max(0, math.min(100, (wx + width / 2) / dw * 100))
        C.pos_y = math.max(0, math.min(100, wy / dh * 100))
        P.pos_changed = now
      end
    end
    local ok, err = pcall(function()
      if use_bars then
        local a = opacity * alpha
        local bc = theme.border
        local inset = math.max(0, border - 1)
        local ok_bars = K.POPUP.rect(inset, inset, width - inset * 2, height - inset * 2, bg_r, bg_g, bg_b, a)
        if border > 0 then
          ok_bars = K.POPUP.rect(0, 0, width, border, bc[1], bc[2], bc[3], a) and ok_bars
          ok_bars = K.POPUP.rect(0, height - border, width, border, bc[1], bc[2], bc[3], a) and ok_bars
          ok_bars = K.POPUP.rect(0, border, border, height - border * 2, bc[1], bc[2], bc[3], a) and ok_bars
          ok_bars = K.POPUP.rect(width - border, border, border, height - border * 2, bc[1], bc[2], bc[3], a) and ok_bars
        end
        if not ok_bars then P.bars_ok = false end
      end
      local black = { 0, 0, 0 }
      local thick = C.outline * 0.5 * math.max(0.75, s)
      local ty = pad + 2
      imgui.SetWindowFontScale(name_scale)
      local name_outline
      if cur.rare then
        name_outline = black
      else
        name_outline = (C.black_outline or K.COMMON.is_name(cur.name)) and black or kind_color(cur.vr and "veryrare" or cur.kind, cur.name)
      end
      K.POPUP.draw_line(name_segs, ty, width, alpha, name_outline, thick)
      if icon then
        local x0 = math.max(0, (width - name_w) / 2)
        local iy = math.floor(ty + (lh * name_scale - icon_h) / 2 + 0.5)
        local lx = math.floor(math.max(0, x0 - icon_gap - icon_w) + 0.5)
        local rx = math.floor(math.min(width - icon_w, x0 + name_w + icon_gap) + 0.5)
        K.POPUP.draw_icon(icon, lx, iy, icon_cell, alpha, false)
        K.POPUP.draw_icon(icon, rx, iy, icon_cell, alpha, true)
      end
      ty = ty + lh * name_scale
      imgui.SetWindowFontScale(other_scale)
      if stats_segs then
        ty = ty + gap
        K.POPUP.draw_line(stats_segs, ty, width, alpha, black, thick)
        ty = ty + lh * other_scale
      end
      if tekk_segs then
        ty = ty + gap
        K.POPUP.draw_line(tekk_segs, ty, width, alpha, black, thick)
        ty = ty + lh * other_scale
      end
      if rate_segs then
        ty = ty + gap
        K.POPUP.draw_line(rate_segs, ty, width, alpha, black, thick)
      end
    end)
    pcall(imgui.SetWindowFontScale, 1.0)
    if not ok and not P.error_shown then
      P.error_shown = true
      set_status("Pop-up : " .. tostring(err), true)
    end
  end
  imgui.End()
  cur.placed = true
  P.last_width = width
  P.force_place = false
  for _ = 1, pushed_vars do pcall(imgui.PopStyleVar) end
  for _ = 1, pushed_colors do pcall(imgui.PopStyleColor) end
end

function K.POPUP.stepper(label_key, key, suffix, divisor)
  local C = K.POPUP.cfg
  local limit = K.POPUP.limits[key]
  local changed = false
  local shown = divisor and string.format("%g", C[key] / divisor) or tostring(C[key])
  imgui.Text(T(label_key) .. shown .. suffix)
  imgui.SameLine(300)
  if imgui.Button("-##pp_" .. key) then
    C[key] = math.max(limit[1], C[key] - limit[3])
    changed = true
  end
  imgui.SameLine(0, 4)
  if imgui.Button("+##pp_" .. key) then
    C[key] = math.min(limit[2], C[key] + limit[3])
    changed = true
  end
  return changed
end

function K.POPUP.draw_drops_tab()
  local P, C = K.POPUP, K.POPUP.cfg
  local changed = false
  local function checkbox(label, key)
    local c
    c, C[key] = imgui.Checkbox(label .. "##pp_" .. key, C[key])
    if c then changed = true end
  end
  checkbox(T("popup_enable"), "enabled")
  imgui.SameLine(0, 24)
  if imgui.Button(T("popup_test") .. "##pp_test") then
    K.POPUP.test()
  end
  imgui.SameLine(0, 24)
  P.preview = select(2, imgui.Checkbox(T("popup_preview") .. "##pp_preview", P.preview))
  imgui.Separator()
  imgui.TextColored(1, 0.85, 0.3, 1, T("popup_sec_look"))
  if K.POPUP.stepper("popup_size", "scale", " %") then changed = true end
  if K.POPUP.stepper("popup_font", "font", " %") then changed = true end
  if K.POPUP.stepper("popup_opacity", "opacity", " %") then changed = true end
  if K.POPUP.stepper("popup_border", "border", " px") then changed = true end
  if K.POPUP.stepper("popup_outline", "outline", " px", 2) then changed = true end
  checkbox(T("popup_black_outline"), "black_outline")
  checkbox(T("popup_shine"), "shine")
  imgui.Text(T("popup_theme"))
  for index, theme in ipairs(P.themes) do
    imgui.SameLine(0, 6)
    local c = theme.c2
    local pushed = 0
    if pcall(imgui.PushStyleColor, "Button", c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, 1.0) then
      pushed = pushed + 1
    end
    if pcall(imgui.PushStyleColor, "ButtonHovered", c[1], c[2], c[3], 1.0) then pushed = pushed + 1 end
    if pcall(imgui.PushStyleColor, "ButtonActive", c[1], c[2], c[3], 1.0) then pushed = pushed + 1 end
    local name = theme[lang.code] or theme.fr
    if imgui.Button(((C.theme == index) and ("[" .. name .. "]") or name) .. "##pp_theme" .. index) then
      C.theme = index
      changed = true
    end
    for _ = 1, pushed do pcall(imgui.PopStyleColor) end
  end
  imgui.Separator()
  imgui.TextColored(1, 0.85, 0.3, 1, T("popup_sec_content"))
  checkbox(T("popup_show_stats"), "show_stats")
  imgui.SameLine(0, 24)
  checkbox(T("popup_show_rate"), "show_rate")
  imgui.SameLine(0, 24)
  checkbox(T("popup_show_icon"), "show_icon")
  for _, kind in ipairs({ "weapon", "armor" }) do
    imgui.Text(T("popup_icon_" .. kind))
    for index = 0, #P.icons[kind] do
      imgui.SameLine(0, 6)
      local icon = P.icons[kind][index]
      local name = icon and (icon.name[lang.code] or icon.name.fr) or T("popup_icon_auto")
      local label = (C[kind .. "_icon"] == index) and ("[" .. name .. "]") or name
      if imgui.Button(label .. "##pp_icon_" .. kind .. index) then
        C[kind .. "_icon"] = index
        local sample
        if kind == "weapon" then
          sample = (index == 1 and P.preview_melee) or (index == 2 and P.preview_rod) or P.preview_entry
        else
          sample = (index == 1 and P.preview_barrier) or P.preview_armor
        end
        P.preview_sample = sample
        K.POPUP.test(sample)
        changed = true
      end
    end
  end
  imgui.Text(T("popup_kinds"))
  for _, kind in ipairs(P.kind_keys) do
    imgui.SameLine(0, 12)
    local col = kind_color(kind)
    local pushed = pcall(imgui.PushStyleColor, "Text", col[1], col[2], col[3], 1.0)
    local c
    c, C.kinds[kind] = imgui.Checkbox(T("kind_" .. kind) .. "##pp_kind_" .. kind, C.kinds[kind])
    if c then changed = true end
    if pushed then pcall(imgui.PopStyleColor) end
  end
  imgui.Separator()
  imgui.TextColored(1, 0.85, 0.3, 1, T("popup_sec_pos"))
  checkbox(T("popup_lock"), "locked")
  imgui.SameLine(0, 24)
  if imgui.Button(T("popup_recenter") .. "##pp_recenter") then
    C.pos_x = K.POPUP.defaults.pos_x
    C.pos_y = K.POPUP.defaults.pos_y
    P.force_place = true
    changed = true
  end
  imgui.TextDisabled(T("popup_hint"))
  if K.POPUP.stepper("popup_duration", "duration", " s") then changed = true end
  imgui.Separator()
  imgui.Text(T("popup_render"))
  local modes = { { 2, "popup_render_bars" }, { 1, "popup_render_win" } }
  for _, mode in ipairs(modes) do
    imgui.SameLine(0, 6)
    local label = T(mode[2])
    if imgui.Button(((C.render == mode[1]) and ("[" .. label .. "]") or label) .. "##pp_render" .. mode[1]) then
      C.render = mode[1]
      P.bars_ok, P.nobg_failed, P.showborders_failed = nil, nil, nil
      changed = true
    end
  end
  imgui.TextDisabled(T("popup_render_hint"))
  imgui.Separator()
  if os.time() <= P.confirm_until then
    if imgui.Button(T("popup_reset_ask") .. "##pp_reset") then
      K.POPUP.apply(nil)
      P.confirm_until = 0
      changed = true
    end
  else
    if imgui.Button(T("popup_reset") .. "##pp_reset") then
      P.confirm_until = os.time() + K.CONFIRM_SECONDS
    end
  end
  if changed then save_data() end
end

function K.POPUP.draw_rare_tab()
  local P, C = K.POPUP, K.POPUP.cfg
  local changed = false
  local function checkbox(label, key)
    local c
    c, C[key] = imgui.Checkbox(label .. "##pp_" .. key, C[key])
    if c then changed = true end
  end
  checkbox(T("rare_enable"), "rare_enabled")
  imgui.SameLine(0, 24)
  if imgui.Button(T("popup_test") .. "##pp_rare_test") then
    K.POPUP.test_rare()
  end
  imgui.TextDisabled(T("rare_hint"))
  imgui.Separator()
  imgui.TextColored(1, 0.85, 0.3, 1, T("popup_sec_content"))
  checkbox(T("rare_show_zone"), "rare_zone")
  imgui.Separator()
  imgui.TextColored(1, 0.85, 0.3, 1, T("popup_sec_look"))
  imgui.Text(T("popup_theme"))
  for index, theme in ipairs(P.themes) do
    imgui.SameLine(0, 6)
    local c = theme.c2
    local pushed = 0
    if pcall(imgui.PushStyleColor, "Button", c[1] * 0.8, c[2] * 0.8, c[3] * 0.8, 1.0) then
      pushed = pushed + 1
    end
    if pcall(imgui.PushStyleColor, "ButtonHovered", c[1], c[2], c[3], 1.0) then pushed = pushed + 1 end
    if pcall(imgui.PushStyleColor, "ButtonActive", c[1], c[2], c[3], 1.0) then pushed = pushed + 1 end
    local name = theme[lang.code] or theme.fr
    if imgui.Button(((C.rare_theme == index) and ("[" .. name .. "]") or name) .. "##pp_rare_theme" .. index) then
      C.rare_theme = index
      changed = true
    end
    for _ = 1, pushed do pcall(imgui.PopStyleColor) end
  end
  if K.POPUP.stepper("popup_duration", "rare_duration", " s") then changed = true end
  if changed then save_data() end
end

function K.POPUP.draw_tab()
  local P = K.POPUP
  local sub = P.subtab or "drops"
  local entries = { { "drops", T("popup_sub_drops") }, { "rare", T("popup_sub_rare") } }
  for index, entry in ipairs(entries) do
    if index > 1 then imgui.SameLine(0, 4) end
    local label = (sub == entry[1]) and ("[" .. entry[2] .. "]") or entry[2]
    if imgui.Button(label .. "##pp_sub_" .. entry[1]) then
      P.subtab = entry[1]
      sub = entry[1]
    end
  end
  imgui.Separator()
  if sub == "rare" then
    K.POPUP.draw_rare_tab()
  else
    K.POPUP.draw_drops_tab()
  end
end

end
