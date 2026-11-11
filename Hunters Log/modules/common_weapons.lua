-- Hunter's Log : module "common_weapons" (regular weapons and their specials), loaded by K.load_code in init.lua
local imgui = require("imgui")

return function(K)
K.COMMON = { enabled = false, min_hit = 40 }
K.COMMON_UI = { counters_open = false, ids_open = {} }
K.COMMON_WEAPONS = {}

for _, common_name in ipairs({
    "saber", "brand", "buster", "pallasch", "gladius", "sword", "gigush", "breaker", "claymore", "calibur",
    "dagger", "knife", "blade", "edge", "ripper", "partisan", "halbert", "glaive", "berdys", "gungnir",
    "slicer", "spinner", "cutter", "sawcer", "diska", "handgun", "autogun", "lockgun", "railgun", "raygun",
    "rifle", "sniper", "blaster", "beam", "laser", "mechgun", "assault", "repeater", "gatling", "vulcan",
    "shot", "spread", "spred", "cannon", "launcher", "arms", "cane", "stick", "mace", "club",
    "rod", "pole", "pillar", "striker", "wand", "staff", "baton", "scepter",
  }) do
  K.COMMON_WEAPONS[common_name] = true
end

function K.COMMON.apply(tbl)
  K.COMMON.enabled = false
  K.COMMON.min_hit = 40
  if type(tbl) == "table" then
    K.COMMON.enabled = tbl.enabled == true
    local hit = tonumber(tbl.min_hit)
    if hit then K.COMMON.min_hit = math.max(40, math.min(100, math.floor(hit))) end
  end
end

function K.COMMON.serialize()
  return string.format("{enabled=%s,min_hit=%d}", tostring(K.COMMON.enabled), K.COMMON.min_hit)
end

function K.COMMON.accepts(item)
  if not K.COMMON.enabled or not item or not item.weapon or not item.name then return false end
  if not K.COMMON.is_name(item.name) then return false end
  local stats = item.weapon.stats
  local hit = stats and tonumber(stats[6])
  if not hit then return false end
  if item.weapon.untekked then hit = hit + 10 end
  return hit >= K.COMMON.min_hit
end

K.COMMON.SPECIALS = {
  "Draw", "Drain", "Fill", "Gush", "Heart", "Mind", "Soul", "Geist", "Master's", "Lord's",
  "King's", "Charge", "Spirit", "Berserk", "Ice", "Frost", "Freeze", "Blizzard", "Bind", "Hold",
  "Seize", "Arrest", "Heat", "Fire", "Flame", "Burning", "Shock", "Thunder", "Storm", "Tempest",
  "Dim", "Shadow", "Dark", "Hell", "Panic", "Riot", "Havoc", "Chaos", "Devil's", "Demon's",
}

K.COMMON.SPECIAL_NAMES = {}

for _, special in ipairs(K.COMMON.SPECIALS) do
  K.COMMON.SPECIAL_NAMES[string.lower(special)] = true
end

K.COMMON.white = { 1, 1, 1 }

function K.COMMON.is_name(name)
  if type(name) ~= "string" then return false end
  local lower = string.gsub(string.lower(name), "^[%?%s]+", "")
  local prefix, base = string.match(lower, "^(.-)%s*([%w'%-]+)$")
  if not base or not K.COMMON_WEAPONS[base] then return false end
  return prefix == "" or K.COMMON.SPECIAL_NAMES[prefix] == true
end

function K.COMMON.special_info(item)
  local weapon = item and item.weapon
  if type(weapon) ~= "table" then return nil, false end
  local found = false
  local function from_value(value)
    if type(value) == "table" then value = value.name or value.id or value.index end
    if value == nil then return nil end
    found = true
    local number = tonumber(value)
    if number then
      return K.COMMON.SPECIALS[math.floor(number) % 64]
    end
    if type(value) == "string" and value ~= "" and string.lower(value) ~= "none" then return value end
    return nil
  end
  for _, key in ipairs({ "special", "specialName", "special_name", "attribute" }) do
    local name = from_value(weapon[key])
    if name then return name, true end
  end
  if type(item.data) == "table" then
    local name = from_value(item.data[5])
    if name then return name, true end
  end
  return nil, found
end

function K.COMMON.base(name)
  local lower = string.gsub(string.lower(tostring(name)), "^[%?%s]+", "")
  return string.match(lower, "([%w'%-]+)$")
end

function K.COMMON.full_name(item)
  local name = item and item.name
  if type(name) ~= "string" then return name end
  local base = string.gsub(name, "^[%?%s]+", "")
  if not K.COMMON_WEAPONS[string.lower(base)] then return name end
  local special, found = K.COMMON.special_info(item)
  if special then return special .. " " .. base end
  if not found and not K.COMMON.reported and item.weapon then
    K.COMMON.reported = true
    local keys = {}
    for key in pairs(item.weapon) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    K.COMMON.report_text = "Armes communes : special non lisible. Champs de l'arme : " .. table.concat(keys, ", ")
  end
  return base
end

K.COMMON.FAMILIES = K.GAME_DATA.common_families

K.COMMON.SPECIAL_COLOR = {
  ["charge"] = { 0.91, 0.91, 0.00 },
  ["spirit"] = { 0.96, 0.73, 0.07 },
  ["berserk"] = { 0.91, 0.96, 0.09 },
}

K.COMMON.SPECIAL_INFO = {}

for _, family in ipairs(K.COMMON.FAMILIES) do
  local count = 0
  for grade = 1, 4 do
    if family.grades[grade] then count = count + 1 end
  end
  local index = 0
  for grade = 1, 4 do
    local special = family.grades[grade]
    if special then
      index = index + 1
      local f = index / count
      K.COMMON.SPECIAL_INFO[string.lower(special)] = {
        name = special, family = family, grade = grade,
        color = { 1 - f * (1 - family.base[1]), 1 - f * (1 - family.base[2]), 1 - f * (1 - family.base[3]) },
      }
    end
  end
end

function K.COMMON.special_color(special)
  local key = string.lower(tostring(special))
  if K.COMMON.SPECIAL_COLOR[key] then return K.COMMON.SPECIAL_COLOR[key] end
  local info = K.COMMON.SPECIAL_INFO[key]
  return info and info.color or K.COMMON.white
end

function K.COMMON.tekk_range(special)
  local info = K.COMMON.SPECIAL_INFO[string.lower(tostring(special))]
  if not info then return nil end
  if info.family.fixed then return { info.name } end
  local list = {}
  for grade = info.grade - 1, info.grade + 1 do
    local name = info.family.grades[grade]
    if name then list[#list + 1] = name end
  end
  return list
end

function K.COMMON.split(text)
  if type(text) ~= "string" then return nil end
  local first, rest = string.match(text, "^(%S+)%s+(.+)$")
  if first and K.COMMON.SPECIAL_INFO[string.lower(first)] and K.COMMON.is_name(text) then
    return first, rest
  end
  return nil
end

function K.COMMON.family_tooltip(special)
  local info = K.COMMON.SPECIAL_INFO[string.lower(tostring(special))]
  if not info then return end
  imgui.BeginTooltip()
  for grade = 1, 4 do
    local name = info.family.grades[grade]
    if name then
      local rgb = K.COMMON.special_color(name)
      imgui.TextColored(rgb[1], rgb[2], rgb[3], 1, (grade == info.grade) and ("> " .. K.COMMON.special_label(name)) or ("   " .. K.COMMON.special_label(name)))
    end
  end
  imgui.EndTooltip()
end

function K.COMMON.draw_name(shown, color)
  local special, rest = K.COMMON.split(shown)
  if not special then
    imgui.TextColored(color[1], color[2], color[3], 1, shown)
    return
  end
  local special_rgb = K.COMMON.special_color(special)
  imgui.TextColored(special_rgb[1], special_rgb[2], special_rgb[3], 1, K.COMMON.special_label(special))
  if imgui.IsItemHovered() then K.COMMON.family_tooltip(special) end
  imgui.SameLine(0, 4)
  imgui.TextColored(color[1], color[2], color[3], 1, K.COMMON.base_label(rest))
end

function K.COMMON.name_segments(text)
  local special, rest = K.COMMON.split(text)
  if not special then return { { text, 1, 1, 1 } } end
  local special_rgb = K.COMMON.special_color(special)
  return { { K.COMMON.special_label(special) .. " ", special_rgb[1], special_rgb[2], special_rgb[3] }, { K.COMMON.base_label(rest), 1, 1, 1 } }
end

function K.COMMON.special_label(special)
  if K.U.lang.code == "ja" then
    local specials = K.U.JA_NAMES.weapon_specials
    return specials and specials[special] or special
  end
  return special
end

function K.COMMON.base_label(base)
  return K.U.iname(base)
end

function K.COMMON.full_label(name)
  local special, rest = K.COMMON.split(tostring(name))
  if special then
    return K.COMMON.special_label(special) .. " " .. K.COMMON.base_label(rest)
  end
  return K.U.iname(name)
end
function K.COMMON.rename_after_tekk(key, item, item_details, drop_history, item_counts, item_kinds)
  local details = item_details[key]
  if not details or not K.COMMON.is_name(details.name) or not K.COMMON.is_name(item.name) then
    return false
  end
  local new_name = K.COMMON.full_name(item)
  if new_name == details.name or not K.COMMON.is_name(new_name) then return false end
  local old_name = details.name
  details.name = new_name
  for _, entry in ipairs(drop_history) do
    if entry.key == key then entry.name = new_name end
  end
  K.HIST_REV = K.HIST_REV + 1
  if (item_counts[old_name] or 0) > 0 then
    item_counts[old_name] = item_counts[old_name] - 1
    if item_counts[old_name] <= 0 then item_counts[old_name] = nil end
  end
  item_counts[new_name] = (item_counts[new_name] or 0) + 1
  item_kinds[new_name] = item_kinds[new_name] or item_kinds[old_name] or "weapon"
  return true
end
end
