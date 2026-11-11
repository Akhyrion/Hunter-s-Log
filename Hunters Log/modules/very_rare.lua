-- Hunter's Log : module "very_rare" (very rare items filter), loaded by K.load_code in init.lua
local imgui = require("imgui")

return function(K)
K.VR = {
  names = {}, name_list = {}, rules = {}, rule_list = {}, disabled = {}, version = 0, key_memo = {},
  ui = { name_text = "", rule_text = "", rule_hit = 50, open = { manual = true }, hit = {} },
  presets = {
    names = {
      { cat = "weapon", list = { "Agito (1975)", "Handgun: Milla", "Yasha", "NUG2000-Bazooka", "Lavis Cannon" } },
      { cat = "barrier", list = { "Red Ring", "S-Parts ver2.01" } },
      { cat = "other", list = {
        "Syncesta", "Magic Stone \"Iritista\"", "Parasitic Gene \"Flow\"",
        "Heart of Ancient Saber", "Heart of Angel Harp", "Heart of Blade Dance", "Heart of Chameleon Scythe",
        "Heart of Crazy Tune", "Heart of Daisy Chain", "Heart of DB's Saber", "Heart of Delsaber's Buster",
        "Heart of Diska of Liberator", "Heart of Egg Blaster", "Heart of Flamberge", "Heart of Izmaela",
        "Heart of Laconium Axe", "Heart of Lollipop", "Heart of Partisan of Lightning",
        "Heart of Plantain Huge Fan", "Heart of Rabbit Wand", "Heart of Rianov 303SNR", "Heart of Ruby Bullet",
        "Heart of Samba Maracas", "Heart of Sorcerer's Cane", "Heart of Soul Banish", "Heart of Suppressed Gun",
        "Heart of Tension Blaster", "Heart of The Sigh of a God", "Heart of Twin Chakram",
        "Heart of TypeDS/D.Saber", "Heart of TypeSS/Swords", "Heart of Wok of Akiko's Shop",
        "Heart of Yasminkov 9000M",
      } },
    },
    rules = {
      { "Vjaya", 50 }, { "M&A60 Vise", 50 }, { "Diska of Braveman", 50 }, { "Lame d'Argent", 30 },
      { "Heaven Striker", 30 }, { "Vivienne", 40 }, { "Rambling May", 40 }, { "Daylight Scar", 40 },
      { "L&K38 Combat", 45 }, { "Cannon Rouge", 40 }, { "Yasminkov 9000M", 45 }, { "Spread Needle", 45 },
      { "Frozen Shooter", 40 }, { "Shouren", 45 }, { "Slicer of Fanatic", 45 }, { "Yunchang", 45 },
      { "Monkey King Bar",50 }, { "Girasole",55 }, { "Tyrell's Parasol",50 }, { "Red Sword",55 },
      { "Galatine",30 }, { "Zanba",45 }, { "Ophelie Seize",45 }, { "Asteron Belt",50 }, { "Guren",40 },
      { "Musashi",60 }, { "Holy Ray",50 }, { "Kunai",50 },
    },
  },
}

K.VR.defaults = { names = {}, rules = {} }
K.VR.preset_name_keys, K.VR.preset_rule_keys = {}, {}

function K.VR.key(name)
  local memo = K.VR.key_memo[name]
  if memo then return memo end
  local text = string.lower(tostring(name or ""))
  text = string.gsub(text, "[%(%)]", "")
  text = string.gsub(text, "%s*:%s*", ":")
  text = string.gsub(text, "%s+", " ")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  K.VR.key_memo[name or ""] = text
  return text
end

function K.VR.rebuild()
  K.VR.names, K.VR.rules = {}, {}
  for _, name in ipairs(K.VR.name_list) do
    local key = K.VR.key(name)
    if not K.VR.disabled[key] then K.VR.names[key] = true end
  end
  for _, rule in ipairs(K.VR.rule_list) do
    local key = K.VR.key(rule.name)
    if not K.VR.disabled[key] then K.VR.rules[key] = rule.hit end
  end
  K.VR.version = K.VR.version + 1
  K.BLACKLIST_MEMO = {}
end

function K.VR.apply(tbl)
  K.VR.name_list, K.VR.rule_list, K.VR.disabled = {}, {}, {}
  local source = tbl
  if type(source) ~= "table" then
    source = { names = K.VR.defaults.names, rules = K.VR.defaults.rules }
  end
  if type(source.names) == "table" then
    for _, name in ipairs(source.names) do
      if type(name) == "string" and K.VR.key(name) ~= "" then
        K.VR.name_list[#K.VR.name_list + 1] = name
      end
    end
  end
  if type(source.rules) == "table" then
    for _, rule in ipairs(source.rules) do
      if type(rule) == "table" and type(rule[1]) == "string" and K.VR.key(rule[1]) ~= "" then
        local hit = math.max(0, math.min(100, math.floor(tonumber(rule[2]) or 50)))
        K.VR.rule_list[#K.VR.rule_list + 1] = { name = rule[1], hit = hit }
      end
    end
  end
  if type(source.off) == "table" then
    for _, name in ipairs(source.off) do
      if type(name) == "string" then K.VR.disabled[K.VR.key(name)] = true end
    end
  end
  K.VR.rebuild()
end

function K.VR.serialize()
  local names, rules = {}, {}
  for _, name in ipairs(K.VR.name_list) do names[#names + 1] = string.format("%q", name) end
  for _, rule in ipairs(K.VR.rule_list) do
    rules[#rules + 1] = string.format("{%q,%d}", rule.name, rule.hit)
  end
  local off = {}
  for key in pairs(K.VR.disabled) do off[#off + 1] = string.format("%q", key) end
  table.sort(off)
  return "{names={" .. table.concat(names, ",") .. "},rules={" .. table.concat(rules, ",") .. "},off={" .. table.concat(off, ",") .. "}}"
end

function K.VR.hit_from_stats(stats)
  if type(stats) ~= "string" then return nil end
  local hit = tonumber(string.match(stats, "%[[%-%d]+/[%-%d]+/[%-%d]+/[%-%d]+|(%d+)%]"))
  if not hit then return nil end
  if string.find(stats, "UNTEKKED", 1, true) or string.sub(stats, 1, 1) == "~" then hit = hit + 10 end
  return hit
end

function K.VR.hit_ok(name, stats)
  local need = K.VR.rules[K.VR.key(name)]
  if not need then return false end
  local hit = K.VR.hit_from_stats(stats)
  return hit ~= nil and hit >= need
end

function K.VR.entry_kind(h)
  if h.kind ~= "weapon" or not K.VR.rules[K.VR.key(h.name)] then return h.kind end
  local details = h.key and K.U.details()[h.key]
  if details and K.VR.hit_ok(h.name, details.stats) then return "veryrare" end
  return h.kind
end

function K.VR.set_active(name, on)
  local key = K.VR.key(name)
  K.VR.disabled[key] = (not on) or nil
end

function K.VR.set_name(name, on)
  local V = K.VR
  local key = V.key(name)
  V.disabled[key] = nil
  local found = false
  for i = #V.name_list, 1, -1 do
    if V.key(V.name_list[i]) == key then
      if on and not found then
        found = true
      else
        table.remove(V.name_list, i)
      end
    end
  end
  if on and not found then V.name_list[#V.name_list + 1] = name end
end

function K.VR.set_rule(name, hit, on, keep_state)
  local V = K.VR
  local key = V.key(name)
  if not keep_state then V.disabled[key] = nil end
  local found = false
  for i = #V.rule_list, 1, -1 do
    local rule = V.rule_list[i]
    if V.key(rule.name) == key then
      if on and not found then
        found = true
        rule.hit = hit
      else
        table.remove(V.rule_list, i)
      end
    end
  end
  if on and not found then V.rule_list[#V.rule_list + 1] = { name = name, hit = hit } end
end

K.VR.apply(nil)
function K.draw_vr_options()
  local V = K.VR
  local changed = false
  local _
  local function trim(text)
    text = string.gsub(tostring(text or ""), "^%s+", "")
    return (string.gsub(text, "%s+$", ""))
  end
  local function text_width(text)
    local ok, w = pcall(imgui.CalcTextSize, text)
    if ok and type(w) == "number" then return w end
    return #tostring(text) * 7
  end
  local line_h = 16
  local ok_h, h = pcall(imgui.GetTextLineHeight)
  if ok_h and type(h) == "number" then line_h = h end
  local on_c = K.U.kind_color("veryrare", "vr")

  local c = on_c
  imgui.TextColored(c[1], c[2], c[3], 1, K.U.T("vr_title"))
  imgui.TextDisabled(K.U.T("vr_hint"))

  imgui.Text(K.U.T("vr_add_name"))
  imgui.SameLine(0, 6)
  imgui.PushItemWidth(K.SEARCH_BOX_WIDTH)
  _, V.ui.name_text = imgui.InputText("##vr_name_input", V.ui.name_text, 64)
  imgui.PopItemWidth()
  imgui.SameLine(0, 4)
  if imgui.Button(K.U.T("vr_add") .. "##vr_name_add") then
    local text = trim(V.ui.name_text)
    if text ~= "" then
      V.set_name(text, true)
      changed = true
    end
    V.ui.name_text = ""
  end
  imgui.Text(K.U.T("vr_add_rule"))
  imgui.SameLine(0, 6)
  imgui.PushItemWidth(K.SEARCH_BOX_WIDTH)
  _, V.ui.rule_text = imgui.InputText("##vr_rule_input", V.ui.rule_text, 64)
  imgui.PopItemWidth()
  imgui.SameLine(0, 8)
  imgui.Text(tostring(V.ui.rule_hit) .. " %")
  imgui.SameLine(0, 6)
  if imgui.Button("-##vr_new_m") then V.ui.rule_hit = math.max(0, V.ui.rule_hit - 5) end
  imgui.SameLine(0, 4)
  if imgui.Button("+##vr_new_p") then V.ui.rule_hit = math.min(100, V.ui.rule_hit + 5) end
  imgui.SameLine(0, 8)
  if imgui.Button(K.U.T("vr_add") .. "##vr_rule_add") then
    local text = trim(V.ui.rule_text)
    if text ~= "" then
      V.set_rule(text, V.ui.rule_hit, true)
      changed = true
    end
    V.ui.rule_text = ""
  end
  imgui.Separator()

  local pushed = 0
  if pcall(imgui.PushStyleVar, "FramePadding", 4, 1) then pushed = pushed + 1 end
  if pcall(imgui.PushStyleVar, "ItemSpacing", 8, 2) then pushed = pushed + 1 end

  local function fold_header(id, title, extra)
    local open = V.ui.open[id]
    if imgui.Button((open and "-" or "+") .. "##vr_fold_" .. id) then V.ui.open[id] = not open end
    imgui.SameLine(0, 6)
    imgui.Text(title)
    if open and extra then extra() end
    return open
  end
  local function name_label(text, active)
    imgui.SameLine(0, 6)
    text = K.U.iname(text)
    if active then imgui.TextColored(on_c[1], on_c[2], on_c[3], 1, text) else imgui.TextDisabled(text) end
  end
  local function hit_controls(shown, ctrl_x, id)
    imgui.SameLine(ctrl_x, 0)
    imgui.Text(tostring(shown) .. "+")
    imgui.SameLine(0, 8)
    local delta
    if imgui.Button("-##vr_h_m" .. id) then delta = -5 end
    imgui.SameLine(0, 4)
    if imgui.Button("+##vr_h_p" .. id) then delta = 5 end
    return delta
  end

  local avail = 900
  do
    local ok_w, win_w = pcall(imgui.GetWindowSize)
    if ok_w and type(win_w) == "number" and win_w > 100 then avail = win_w end
  end
  avail = avail - 40
  local function grid(count, colw, max_cols, draw)
    local ncols = math.max(1, math.min(max_cols, math.floor(avail / colw)))
    for i = 1, count do
      local col = (i - 1) % ncols
      if col > 0 then imgui.SameLine(col * colw, 0) end
      draw(i, col * colw)
    end
  end
  local check_w = line_h + 14

  for _, group in ipairs(V.presets.names) do
    local cat = group.cat
    local total, on = #group.list, 0
    for _, name in ipairs(group.list) do
      if V.names[V.key(name)] then on = on + 1 end
    end
    local title = string.format("%s (%d/%d)", K.U.T("vr_cat_" .. cat), on, total)
    local open = fold_header("n_" .. cat, title, function()
      imgui.SameLine(0, 10)
      if imgui.Button(K.U.T("vr_all") .. "##vr_all_" .. cat) then
        for _, name in ipairs(group.list) do V.set_name(name, true) end
        changed = true
      end
      imgui.SameLine(0, 4)
      if imgui.Button(K.U.T("vr_none") .. "##vr_none_" .. cat) then
        for _, name in ipairs(group.list) do V.set_name(name, false) end
        changed = true
      end
    end)
    if open then
      local widest = 0
      for _, name in ipairs(group.list) do widest = math.max(widest, text_width(K.U.iname(name))) end
      grid(#group.list, widest + check_w + 24, 3, function(index)
        local name = group.list[index]
        local active = V.names[V.key(name)] == true
        local toggled, value = imgui.Checkbox("##vrn_" .. cat .. index, active)
        if toggled then
          V.set_name(name, value)
          changed = true
        end
        name_label(name, active)
      end)
    end
  end

  local manual_names, manual_rules = {}, {}
  for _, name in ipairs(V.name_list) do
    if not V.preset_name_keys[V.key(name)] then manual_names[#manual_names + 1] = name end
  end
  for _, rule in ipairs(V.rule_list) do
    if not V.preset_rule_keys[V.key(rule.name)] then manual_rules[#manual_rules + 1] = rule end
  end

  do
    local entries = {}
    for _, rule in ipairs(V.presets.rules) do entries[#entries + 1] = { name = rule[1], hit = rule[2] } end
    for _, rule in ipairs(manual_rules) do entries[#entries + 1] = { name = rule.name, hit = rule.hit, manual = true } end
    local total, on, widest = #entries, 0, 0
    for _, e in ipairs(entries) do
      if V.rules[V.key(e.name)] then on = on + 1 end
      widest = math.max(widest, text_width(K.U.iname(e.name)))
    end
    local title = string.format("%s (%d/%d)", K.U.T("vr_col_hit"), on, total)
    local open = fold_header("rules", title, function()
      imgui.SameLine(0, 10)
      if imgui.Button(K.U.T("vr_all") .. "##vr_all_rules") then
        for _, e in ipairs(entries) do
          local key = V.key(e.name)
          if e.manual then
            V.set_active(e.name, true)
          else
            V.set_rule(e.name, V.rules[key] or V.ui.hit[key] or e.hit, true)
          end
        end
        changed = true
      end
      imgui.SameLine(0, 4)
      if imgui.Button(K.U.T("vr_none") .. "##vr_none_rules") then
        for _, e in ipairs(entries) do
          if e.manual then V.set_active(e.name, false) else V.set_rule(e.name, e.hit, false) end
        end
        changed = true
      end
    end)
    if open then
      local ctrl_w = text_width("100+") + text_width("+") * 2 + 52
      local name_w = widest + check_w + 16
      grid(total, name_w + ctrl_w + 50, 3, function(index, off)
        local e = entries[index]
        local key = V.key(e.name)
        local current = V.rules[key]
        local shown = current or V.ui.hit[key] or e.hit
        local toggled, value = imgui.Checkbox("##vrr_" .. index, current ~= nil)
        if toggled then
          if e.manual then V.set_active(e.name, value) else V.set_rule(e.name, shown, value) end
          changed = true
        end
        name_label(e.name, current ~= nil)
        local delta = hit_controls(shown, off + name_w, "p" .. index)
        if delta then
          shown = math.max(0, math.min(100, shown + delta))
          V.ui.hit[key] = shown
          if e.manual or current ~= nil then V.set_rule(e.name, shown, true, e.manual) end
          changed = true
        end
        if e.manual then
          imgui.SameLine(0, 8)
          if imgui.Button("X##vr_rule_x" .. index) then
            V.set_rule(e.name, shown, false)
            changed = true
          end
        end
      end)
    end
  end

  if #manual_names > 0 then
    local title = string.format("%s (%d)", K.U.T("vr_manual"), #manual_names)
    if fold_header("manual", title) then
      local widest = 0
      for _, name in ipairs(manual_names) do widest = math.max(widest, text_width(K.U.iname(name))) end
      grid(#manual_names, widest + check_w + 70, 3, function(index)
        local name = manual_names[index]
        local active = V.names[V.key(name)] == true
        local toggled, value = imgui.Checkbox("##vrm_n" .. index, active)
        if toggled then
          V.set_active(name, value)
          changed = true
        end
        name_label(name, active)
        imgui.SameLine(0, 8)
        if imgui.Button("X##vr_name_x" .. index) then
          V.set_name(name, false)
          changed = true
        end
      end)
    end
  end


  for _ = 1, pushed do pcall(imgui.PopStyleVar) end

  if changed then
    V.rebuild()
    K.U.save_data()
  end
end
end
