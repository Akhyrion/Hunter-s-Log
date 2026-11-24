local CRATER = {
  { 300000, "Sand Rappy", "Del Rappy", "Pazuzu", "Dorphon Eclair" },
  { 352941, "Astark" },
  { 375000, "Zu", "Dorphon" },
  { 666667, "Yowie" },
  { 789474, "Ze Boota" },
  { 857143, "Ba Boota" },
  { 1000000, "Satellite Lizard", "Boota", "Item box" },
}
local DESERT = {
  { 300000, "Sand Rappy", "Del Rappy", "Pazuzu", "Merissa AA" },
  { 375000, "Girtablulu", "Zu" },
  { 666667, "Yowie" },
  { 857143, "Pyro Goran", "Goran Detonator" },
  { 1000000, "Satellite Lizard", "Goran", "Item box" },
  { 1111111, "Merissa A" },
}
local MINE1 = {
  { 352941, "Baranz" },
  { 500000, "Sinow Blue" },
  { 545455, "Sinow Red" },
  { 857143, "Canabin", "Canune" },
  { 1000000, "Gillchich", "Dubchich", "Item box" },
}
local MINE2 = {
  { 262588, "Baranz" },
  { 372000, "Sinow Blue" },
  { 405818, "Sinow Red" },
  { 637714, "Canabin", "Canune" },
  { 744000, "Gillchich", "Dubchich", "Item box" },
}
local JUNGLE = {
  { 375000, "Gi Gue", "Gibbles", "Mericarol", "Merikle", "Mericus" },
  { 666667, "Sinow Spigell" },
  { 750000, "Sinow Berill" },
  { 857143, "Meriltas", "Zol Gibbon" },
  { 1000000, "Merillia", "Gee", "Ul Gibbon", "Item box" },
}
local TEMPLE = {
  { 300000, "El Rappy", "Love Rappy", "Mil Lily", "Hildetorr" },
  { 375000, "Hildelt" },
  { 750000, "Crimson Assassin" },
  { 857143, "Indi Belra" },
  { 967742, "Merlan" },
  { 1000000, "Arlan", "Del-D", "Ob Lily", "Item box" },
  { 1500000, "Mothvert" },
}
local RUINS2 = {
  { 340909, "Dark Bringer" },
  { 666667, "Bulclaw", "Delsaber", "Dark Gunner" },
  { 857143, "Merlan", "Del-D", "Bulk" },
  { 1000000, "Arlan", "Claw", "Item box" },
}
local RUINS1 = {
  { 666667, "Bulclaw", "Delsaber", "Indi Belra" },
  { 857143, "Merlan", "Del-D", "Bulk" },
  { 1000000, "Arlan", "Claw", "Item box" },
}
local SEABED_LOWER = {
  { 375000, "Delbiter", "Gi Gue", "Gibbles", "Mericarol", "Merikle", "Mericus" },
  { 750000, "Morfos", "Deldepth", "Ill Gill" },
  { 857143, "Dolmdarl", "Sinow Zele", "Recobox", "Del Lily" },
  { 1000000, "Dolmolm", "Sinow Zoa", "Epsilon", "Item box" },
  { 3000000, "Recon" },
}
local SEABED_LOWER_MEGID = {
  { 337500, "Delbiter", "Gi Gue", "Gibbles", "Mericarol", "Merikle", "Mericus" },
  { 675000, "Morfos", "Deldepth", "Ill Gill" },
  { 771429, "Dolmdarl", "Sinow Zele", "Recobox", "Del Lily" },
  { 900000, "Dolmolm", "Sinow Zoa", "Epsilon", "Item box" },
  { 2700000, "Recon" },
}
local DESERT_MEGID = {
  { 270000, "Sand Rappy", "Del Rappy", "Pazuzu", "Merissa AA" },
  { 337500, "Girtablulu", "Zu" },
  { 600000, "Yowie" },
  { 771429, "Pyro Goran", "Goran Detonator" },
  { 900000, "Satellite Lizard", "Goran", "Item box" },
  { 1000000, "Merissa A" },
}

local M = {
  techs = {
    grants = { name = "Grants", areas = {
      { ep = 1, floors = { [10] = true }, name = "Ruins 3", groups = {
        { 340909, "Dark Bringer" },
        { 666667, "Bulclaw", "Indi Belra", "Dark Gunner" },
        { 857143, "Merlan", "Del-D", "Gran Sorcerer", "Bulk" },
        { 1000000, "Arlan", "Claw", "Item box" },
      } },
      { ep = 2, floors = { [11] = true, [17] = true }, name = "Seabed Lower", groups = SEABED_LOWER },
      { ep = 4, floors = { [8] = true }, name = "Desert 3", groups = DESERT },
    } },
    megid = { name = "Megid", areas = {
      { ep = 2, floors = { [11] = true, [17] = true }, name = "Seabed Lower", groups = SEABED_LOWER_MEGID },
      { ep = 4, floors = { [8] = true }, name = "Desert 3", groups = DESERT_MEGID },
    } },
    foie = { name = "Foie", areas = {
      { ep = 1, floors = { [9] = true }, name = "Ruins 2", groups = RUINS2 },
      { ep = 2, floors = { [1] = true }, name = "VR Temple Alpha", groups = TEMPLE },
    } },
    gifoie = { name = "Gifoie", areas = {
      { ep = 1, floors = { [8] = true }, name = "Ruins 1", groups = {
        { 666667, "Bulclaw", "Delsaber", "Indi Belra" },
        { 857143, "Merlan", "Del-D", "Gran Sorcerer", "Bulk" },
        { 1000000, "Arlan", "Claw", "Item box" },
      } },
      { ep = 2, floors = { [2] = true }, name = "VR Temple Beta", groups = TEMPLE },
    } },
    rafoie = { name = "Rafoie", areas = {
      { ep = 1, floors = { [7] = true }, name = "Mine 2", groups = MINE2 },
      { ep = 2, floors = { [3] = true }, name = "VR Spaceship Alpha", groups = {
        { 600000, "Pan Arms", "Baranz" },
        { 666667, "Hidoom", "Migium" },
        { 1000000, "Gulgus", "Gulgus-Gue", "Gillchich", "Dubchich", "Item box" },
        { 1200000, "Delsaber" },
      } },
      { ep = 4, floors = { [1] = true }, name = "Crater East", groups = CRATER },
    } },
    barta = { name = "Barta", areas = {
      { ep = 1, floors = { [6] = true }, name = "Mine 1", groups = MINE1 },
      { ep = 2, floors = { [4] = true }, name = "VR Spaceship Beta", groups = {
        { 600000, "Pan Arms" },
        { 666667, "Hidoom", "Migium" },
        { 1000000, "Gulgus", "Gulgus-Gue", "Gillchich", "Dubchich", "Item box" },
        { 1200000, "Delsaber", "Gran Sorcerer" },
      } },
      { ep = 4, floors = { [2] = true }, name = "Crater West", groups = CRATER },
    } },
    gibarta = { name = "Gibarta", areas = {
      { ep = 1, floors = { [5] = true }, name = "Cave 3", groups = {
        { 300000, "Pan Arms" },
        { 500000, "Nano Dragon" },
        { 600000, "Pouilly Slime" },
        { 700000, "Mil Lily", "Migium", "Hidoom" },
        { 900000, "Govulmer" },
        { 1000000, "Vulmer", "Item box" },
        { 1100000, "Pofuilly Slime" },
        { 1200000, "Ob Lily" },
        { 2000000, "Melqueek" },
      } },
      { ep = 2, floors = { [6] = true }, name = "Jungle North", groups = {
        { 400000, "Gi Gue", "Mericarol", "Merikle", "Mericus", "Gibbles" },
        { 700000, "Sinow Spigell" },
        { 800000, "Sinow Berill" },
        { 900000, "Meriltas", "Zol Gibbon" },
        { 1000000, "Merillia", "Gee", "Ul Gibbon", "Item box" },
      } },
      { ep = 4, floors = { [3] = true }, name = "Crater South", groups = {
        { 300000, "Sand Rappy" },
        { 400000, "Dorphon", "Zu", "Astark" },
        { 600000, "Dorphon Eclair", "Del Rappy", "Pazuzu" },
        { 700000, "Yowie" },
        { 800000, "Ze Boota" },
        { 900000, "Ba Boota" },
        { 1000000, "Boota", "Satellite Lizard", "Item box" },
      } },
    } },
    rabarta = { name = "Rabarta", areas = {
      { ep = 1, floors = { [6] = true }, name = "Mine 1", groups = MINE1 },
      { ep = 2, floors = { [7] = true }, name = "Jungle East", groups = JUNGLE },
      { ep = 4, floors = { [4] = true }, name = "Crater North", groups = CRATER },
    } },
    zonde = { name = "Zonde", areas = {
      { ep = 1, floors = { [7] = true }, name = "Mine 2", groups = MINE2 },
      { ep = 2, floors = { [8] = true }, name = "Mountain", groups = JUNGLE },
      { ep = 4, floors = { [5] = true }, name = "Crater Interior", groups = CRATER },
    } },
    gizonde = { name = "Gizonde", areas = {
      { ep = 1, floors = { [8] = true }, name = "Ruins 1", groups = RUINS1 },
      { ep = 2, floors = { [5] = true, [9] = true, [16] = true }, name = "Seaside / CCA", groups = JUNGLE },
      { ep = 4, floors = { [6] = true }, name = "Desert 1", groups = DESERT },
    } },
    razonde = { name = "Razonde", areas = {
      { ep = 1, floors = { [9] = true }, name = "Ruins 2", groups = RUINS2 },
      { ep = 2, floors = { [10] = true }, name = "Seabed Upper", groups = {
        { 375000, "Delbiter" },
        { 750000, "Morfos", "Deldepth" },
        { 857143, "Dolmdarl", "Sinow Zele", "Recobox" },
        { 1000000, "Dolmolm", "Sinow Zoa", "Item box" },
        { 3000000, "Recon" },
      } },
      { ep = 4, floors = { [7] = true }, name = "Desert 2", groups = DESERT },
    } },
  },
}

local function canon(text)
  local s = string.lower(tostring(text or ""))
  s = string.gsub(s, "[^%w]", "")
  s = string.gsub(s, "dubchich", "dubchic")
  s = string.gsub(s, "gillchich", "gillchic")
  s = string.gsub(s, "gilchic", "gillchic")
  s = string.gsub(s, "uigibbon", "ulgibbon")
  return s
end

function M.area(tech_key, episode, floor)
  local tech = M.techs[tech_key]
  if not tech then return nil end
  for _, area in ipairs(tech.areas) do
    if area.ep == episode and area.floors[floor] then return area end
  end
  return nil
end

function M.candidates(area, monsters, death_keys, enemies, resolve)
  local lookup, box_odds = {}, nil
  for _, group in ipairs(area.groups) do
    for i = 2, #group do
      if group[i] == "Item box" then
        box_odds = group[1]
      else
        lookup[canon(group[i])] = { odds = group[1], name = group[i] }
      end
    end
  end
  local out, seen = {}, {}
  local function consider(key, is_floor_monster)
    if type(key) ~= "string" or key == "" then return end
    local base = string.gsub(key, " E2$", "")
    local row = enemies and (enemies[key] or enemies[base])
    local ultimate = row and row[4] or nil
    local entry = lookup[canon(base)] or (ultimate and lookup[canon(ultimate)])
    if not entry then return end
    local chart_key = key
    if is_floor_monster and resolve then chart_key = resolve(key) or key end
    local display = ultimate or entry.name
    local id = chart_key .. "|" .. display
    if seen[id] then return end
    seen[id] = true
    out[#out + 1] = { key = chart_key, display = display, odds = entry.odds }
  end
  if monsters then
    for i = 1, #monsters, 2 do consider(monsters[i], true) end
  end
  for _, key in ipairs(death_keys or {}) do consider(key, false) end
  return out, box_odds
end

return M
