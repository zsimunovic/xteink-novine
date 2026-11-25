-- SASTAVLJENO iz inkapp/src/common.lua i inkapp/src/lock.lua (sastavi.py) -- mijenjaj te datoteke.
local N = (function()
-- Zajednički dijelovi aplikacije (index.lua) i zaključanog ekrana (lockscreen.lua).
-- sastavi.py ovo stavlja na početak obiju datoteka kao `local N = (function() ... end)()`,
-- jer uređaj ne može učitati druge datoteke iz paketa naredbom require.
--
-- Pravila za Lua na uređaju (Xteink X4 Pro, XTOS Licorice, Lua 5.5):
--   * sve ctx.* funkcije pozivaju se dvotočkom: ctx.storage:read(...)
--   * varijabla for-petlje se ne smije mijenjati unutar petlje
--   * cijeli brojevi mogu biti 32-bitni
--   * po jednom crtanju najviše ~1024 naredbe

local N = {}
N.W, N.H = 480, 800
N.URL = 'https://zsimunovic.github.io/xteink-novine/najnovije.txt'
N.CACHE = 'izdanje.txt'

------------------------------------------------------------------ datoteke

function N.read(name)
  local ok, s = pcall(function() return ctx.storage:read(name) end)
  return (ok and type(s) == 'string') and s or nil
end

function N.write(name, s)
  local ok = pcall(function() ctx.storage:write(name, s) end)
  return ok
end

------------------------------------------------------------------ tekst

-- znakovi koje font uređaja možda nema zamijeni sigurnima
local ZAMJENE = {
  ['\u{2013}'] = '-', ['\u{2014}'] = '-', ['\u{00AB}'] = '"', ['\u{00BB}'] = '"',
  ['\u{201E}'] = '"', ['\u{201C}'] = '"', ['\u{201D}'] = '"', ['\u{2018}'] = "'",
  ['\u{2019}'] = "'", ['\u{2026}'] = '...', ['\u{00A0}'] = ' ', ['\u{2022}'] = '-',
}
function N.clean(s)
  s = tostring(s or '')
  for a, b in pairs(ZAMJENE) do s = s:gsub(a, b) end
  return s
end

-- format najnovije.txt: redci "OZNAKA|vrijednost"
function N.parse(text)
  if type(text) ~= 'string' then return nil end
  local izd = { ukratko = {}, rubrike = {}, kraj = nil }
  local rub, cl = nil, nil
  for line in text:gmatch('[^\n]+') do
    local k, v = line:match('^(%u)|(.*)$')
    if k then
      v = N.clean(v)
      if k == 'D' then izd.datum = v
      elseif k == 'N' then izd.naslov = v
      elseif k == 'R' then izd.razdoblje = v
      elseif k == 'V' then izd.vrijeme = v
      elseif k == 'G' then izd.generirano = v
      elseif k == 'U' then izd.ukratko[#izd.ukratko + 1] = v
      elseif k == 'S' then
        rub = { naziv = v, clanci = {} }
        izd.rubrike[#izd.rubrike + 1] = rub
        cl = nil
      elseif k == 'T' and rub then
        cl = { naslov = v }
        rub.clanci[#rub.clanci + 1] = cl
      elseif k == 'X' and cl then cl.tekst = v
      elseif k == 'Z' and cl then cl.zasto = v
      elseif k == 'I' and cl then cl.izvor = v
      elseif k == 'K' then izd.kraj = izd.kraj or {}; izd.kraj.tekst = v
      elseif k == 'A' then izd.kraj = izd.kraj or {}; izd.kraj.autor = v
      end
    end
  end
  if not izd.datum or not izd.datum:match('^%d%d%d%d%-%d%d%-%d%d$') then return nil end
  return izd
end

------------------------------------------------------------------ datumi

local DANI = { 'nedjelja', 'ponedjeljak', 'utorak', 'srijeda', 'četvrtak', 'petak', 'subota' }
local MJESECI = { 'siječnja', 'veljače', 'ožujka', 'travnja', 'svibnja', 'lipnja', 'srpnja',
                  'kolovoza', 'rujna', 'listopada', 'studenoga', 'prosinca' }

-- "2026-11-25" -> "srijeda, 25. studenoga 2026."
function N.date_hr(datum)
  local y, m, d = tostring(datum or ''):match('^(%d+)-(%d+)-(%d+)')
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if not y or not MJESECI[m] then return tostring(datum or '') end
  local yy, mm = y, m
  if mm < 3 then yy, mm = yy - 1, mm + 12 end
  local k = (d + (13 * (mm + 1)) // 5 + yy + yy // 4 - yy // 100 + yy // 400) % 7   -- Zeller: 0 = subota
  return DANI[(k + 6) % 7 + 1] .. ', ' .. d .. '. ' .. MJESECI[m] .. ' ' .. y .. '.'
end

-- "2026-11-25" -> "25.11."
function N.date_short(datum)
  local _, m, d = tostring(datum or ''):match('^(%d+)-(%d+)-(%d+)')
  if not m then return '' end
  return tonumber(d) .. '.' .. tonumber(m) .. '.'
end

-- današnji datum s uređaja kao "GGGG-MM-DD" (nil ako sat još nije namješten)
function N.today()
  local ok, t = pcall(function() return ctx.clock:now() end)
  if not ok or type(t) ~= 'table' or not tonumber(t.year) or t.valid == false then return nil end
  return string.format('%04d-%02d-%02d', t.year, t.month, t.day)
end

function N.hhmm()
  local ok, t = pcall(function() return ctx.clock:now() end)
  if not ok or type(t) ~= 'table' or not tonumber(t.hour) then return '' end
  return string.format('%02d:%02d', t.hour, tonumber(t.minute) or 0)
end

function N.epoch()
  local ok, t = pcall(function() return ctx.clock:now() end)
  return (ok and type(t) == 'table' and tonumber(t.epoch_sec)) and math.floor(tonumber(t.epoch_sec)) or 0
end

------------------------------------------------------------------ fontovi i prelamanje

function N.font(name) return ctx.fonts and ctx.fonts[name] end

function N.line_h(name)
  local ok, h = pcall(function() return N.font(name).line_height end)
  return (ok and tonumber(h)) or (name == 'large' and 30 or name == 'small' and 20 or 24)
end

function N.width(fname, s)
  local f = N.font(fname)
  local ok, w = pcall(function() return f:measure(s) end)
  if ok and type(w) == 'number' then return w end
  local n = utf8.len(s) or #s
  return n * (fname == 'large' and 15 or fname == 'small' and 10 or 12)
end

-- prelamanje samo na razmacima (%s bi mogao pogoditi drugi bajt nekih slova)
function N.wrap(s, fname, maxw)
  local out = {}
  local line = ''
  for word in tostring(s or ''):gmatch('[^ \t\n]+') do
    local cand = line == '' and word or (line .. ' ' .. word)
    if line ~= '' and N.width(fname, cand) > maxw then
      out[#out + 1] = line
      line = word
    else
      line = cand
    end
  end
  if line ~= '' then out[#out + 1] = line end
  return out
end

return N
end)()

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
