-- Zaključani ekran za Novine: datum, vrijeme u Zagrebu i "Ukratko" iz zadnjeg preuzetog izdanja.
--
-- U verziji iz InkApp Storea/Studija zaključani ekran nema mrežu: prikazuje ono što je aplikacija
-- zadnje preuzela. Ako firmware ipak da ctx.net (API 2.26 uz "net": true u manifestu), novo
-- izdanje se preuzme i dok je uređaj zaključan, čim se promijeni dan.

local W, H = N.W, N.H
local M = 20
local pending = false
local asked = false

local function draw_lines(g, lines, y, font, x, max_y)
  local lh = N.line_h(font) + 2
  for _, s in ipairs(lines) do
    if y + lh > max_y then return y, true end
    g:text(x, y, s, { font = N.font(font) })
    y = y + lh
  end
  return y, false
end

function on_draw(c, g)
  if not g then return end
  local ok, err = pcall(function()
    g:clear(0)
    local izd = N.parse(N.read(N.CACHE))
    if not izd then
      g:text(M, 360, 'Novine', { font = N.font('large') })
      g:text(M, 400, 'Otvori aplikaciju da preuzme izdanje.', { font = N.font('medium') })
      return
    end
    g:text(M, 18, 'NOVINE', { font = N.font('large') })
    local d = N.date_hr(izd.datum)
    g:text(W - M - N.width('small', d), 26, d, { font = N.font('small') })
    g:line(M, 62, W - M, 62)
    g:line(M, 65, W - M, 65)
    local y = 80
    if izd.vrijeme then
      y = draw_lines(g, N.wrap(izd.vrijeme, 'small', W - 2 * M), y, 'small', M, 200)
      y = y + 8
      g:line(M, y, W - M, y)
      y = y + 14
    end
    local max_y = H - 60
    for _, u in ipairs(izd.ukratko) do
      local lines = N.wrap(u, 'medium', W - 2 * M - 20)
      if y + N.line_h('medium') > max_y then break end
      g:text(M, y, '-', { font = N.font('medium') })
      local cut
      y, cut = draw_lines(g, lines, y, 'medium', M + 20, max_y)
      if cut then break end
      y = y + 12
    end
    local today = N.today()
    local foot = (today and izd.datum < today)
      and ('Izdanje od ' .. N.date_short(izd.datum) .. ' - otvori Novine za novo.')
      or 'Ostatak u aplikaciji Novine.'
    g:line(M, H - 50, W - M, H - 50)
    g:text(M, H - 40, foot, { font = N.font('small') })
  end)
  if not ok then pcall(function() g:text(10, H - 30, ('Greška: ' .. tostring(err)):sub(1, 45)) end) end
  if not pending then pcall(function() ctx.lock:done() end) end
end

-- novo izdanje dok je ekran zaključan, samo ako firmware tu daje mrežu
local function try_refresh()
  if asked or not ctx.net then return end
  asked = true
  local ok, job = pcall(function()
    return ctx.net:request({ url = N.URL .. '?v=' .. N.epoch(), method = 'GET', timeout_ms = 30000 }, function(c, resp)
      pending = false
      pcall(function()
        if type(resp) == 'table' and type(resp.body) == 'string' and N.parse(resp.body) then
          N.write(N.CACHE, resp.body)
        end
      end)
      pcall(function() ctx:invalidate() end)
    end)
  end)
  pending = ok and job ~= nil
end

function on_load()
  pcall(function()
    local izd = N.parse(N.read(N.CACHE))
    local today = N.today()
    if today and (not izd or izd.datum < today) then try_refresh() end
    pcall(function() ctx.lock:set_interval(3600) end)
  end)
end

function on_tick() end
function on_input() return false end
