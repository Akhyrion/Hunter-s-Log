-- Hunter's Log : module "pagination" (list pages), loaded by K.load_code in init.lua
local imgui = require("imgui")

return function(K)
K.PAGER = { history = 1, counters = 1, counters_common = 1, games = 1, sigs = {},
sizes = { history = K.PAGE_CFG.history, counters = K.PAGE_CFG.counters, counters_common = K.PAGE_CFG.counters, games = K.PAGE_CFG.games } }

function K.PAGER.reset_on_change(key, sig)
  if K.PAGER.sigs[key] ~= sig then
    K.PAGER.sigs[key] = sig
    K.PAGER[key] = 1
  end
end

function K.PAGER.range(key, page, total)
  local size = K.PAGER.sizes[key]
  return (page - 1) * size + 1, math.min(total, page * size)
end

K.CLIP = { ref = {}, active = false, skipped = false }

function K.CLIP.frame_begin(tab)
  local C = K.CLIP
  C.active, C.skipped = false, false
  local ok_s, scroll = pcall(imgui.GetScrollY)
  local ok_w, _, win_h = pcall(imgui.GetWindowSize)
  local ok_c, _, cursor_y = pcall(imgui.GetCursorPos)
  if not (ok_s and ok_w and ok_c and type(scroll) == "number" and type(win_h) == "number" and type(cursor_y) == "number") then return end
  if scroll < 1 then
    C.ref[tab] = cursor_y
    C.scroll, C.win_h, C.model = 0, win_h, "content"
    C.active = true
    return
  end
  local ref = C.ref[tab]
  if not ref then return end
  if math.abs(cursor_y - ref) < 2 then
    C.model = "content"
  elseif math.abs(cursor_y - (ref - scroll)) < 2 then
    C.model = "screen"
  else
    return
  end
  C.scroll, C.win_h = scroll, win_h
  C.active = true
end

function K.CLIP.row(draw, h)
  local C = K.CLIP
  if not C.active then
    draw(h)
    return
  end
  local x, y = imgui.GetCursorPos()
  local row_h = C.row_h
  if row_h then
    local top = (C.model == "content") and y or (y + C.scroll)
    if top + row_h < C.scroll - 60 or top > C.scroll + C.win_h + 60 then
      imgui.SetCursorPos(x, y + row_h)
      C.skipped = true
      return
    end
  end
  draw(h)
  local _, y_after = imgui.GetCursorPos()
  if y_after > y then C.row_h = y_after - y end
end

function K.CLIP.finish()
  if K.CLIP.skipped then
    K.CLIP.skipped = false
    imgui.Text("")
  end
end

K.PAGER.max_pages = 334
K.PAGER.id_cache = {}
K.PAGER.pages_label = {}

function K.PAGER.ids(key)
  local ids = K.PAGER.id_cache[key]
  if not ids then
    ids = { first = "<<##pg_first_" .. key, prev = "<##pg_prev_" .. key, input = "##pg_input_" .. key,
      next = ">##pg_next_" .. key, last = ">>##pg_last_" .. key }
    K.PAGER.id_cache[key] = ids
  end
  return ids
end

K.PAGER.text = {}
K.PAGER.text_page = {}

function K.PAGER.draw(key, total)
  local pages = math.max(1, math.min(K.PAGER.max_pages, math.ceil(total / K.PAGER.sizes[key])))
  local page = math.max(1, math.min(pages, K.PAGER[key]))
  if pages > 1 then
    local ids = K.PAGER.ids(key)
    if imgui.Button(ids.first) then page = 1 end
    imgui.SameLine(0, 4)
    if imgui.Button(ids.prev) then page = page - 1 end
    imgui.SameLine(0, 8)
    imgui.Text(K.U.T("page_short"))
    imgui.SameLine(0, 4)
    if K.PAGER.text_page[key] ~= page then
      K.PAGER.text[key] = tostring(page)
      K.PAGER.text_page[key] = page
    end
    imgui.PushItemWidth(34)
    local _, typed = imgui.InputText(ids.input, K.PAGER.text[key], 3)
    imgui.PopItemWidth()
    local active_ok, active = pcall(imgui.IsItemActive)
    typed = string.gsub(tostring(typed or ""), "%D", "")
    K.PAGER.text[key] = typed
    local number = tonumber(typed)
    local valid = number ~= nil and number >= 1 and number <= pages
    if valid and number ~= page then
      page = number
    elseif not valid and active_ok and not active then
      K.PAGER.text[key] = tostring(page)
    end
    imgui.SameLine(0, 4)
    local pages_text = K.PAGER.pages_label[pages]
    if not pages_text then
      pages_text = "/ " .. pages
      K.PAGER.pages_label[pages] = pages_text
    end
    imgui.Text(pages_text)
    imgui.SameLine(0, 8)
    if imgui.Button(ids.next) then page = page + 1 end
    imgui.SameLine(0, 4)
    if imgui.Button(ids.last) then page = pages end
    page = math.max(1, math.min(pages, page))
  end
  K.PAGER[key] = page
  return page, pages
end

function K.draw_page_size_choice(key, label)
  imgui.Text(label)
  for _, size in ipairs(K.PAGE_CHOICES) do
    imgui.SameLine(0, 12)
    local selected = K.PAGE_CFG[key] == size
    local text = selected and ("[" .. size .. "]") or tostring(size)
    if imgui.Button(text .. "##pgsize_" .. key .. size) and not selected then
      K.PAGE_CFG[key] = size
      K.PAGER.sizes[key] = size
      K.PAGER[key] = 1
      if key == "counters" then
        K.PAGER.sizes.counters_common = size
        K.PAGER.counters_common = 1
      end
      K.U.save_data()
    end
  end
end
end
