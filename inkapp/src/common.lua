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
