-- SASTAVLJENO iz inkapp/src/common.lua i inkapp/src/app.lua (sastavi.py) -- mijenjaj te datoteke.
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

-- Novine: dnevni pregled vijesti na Xteink X4 Pro.
-- Pri otvaranju preuzme današnje izdanje (najnovije.txt s GitHub Pagesa), spremi ga za
-- čitanje bez Wi-Fija i prikaže rubrike stranicu po stranicu. Može postati zaključani ekran.

local W, H = N.W, N.H
local MARGIN = 16
local HEAD_H = 64                 -- traka s naslovom na ekranu za čitanje
local BTN_Y, BTN_H = 728, 60      -- donji gumbi
local BODY_TOP, BODY_BOTTOM = HEAD_H + 10, BTN_Y - 12

local izd = nil                   -- trenutačno izdanje (N.parse)
local sections = {}               -- { {naslov, items}, ... }
local screen = 'home'             -- 'home' ili 'read'
local sec, page = 1, 1
local pages = nil                 -- stranice trenutačne rubrike (računaju se pri crtanju)
local status, busy = nil, false
local cfg = { lock = false }
local last_key, last_key_ms = nil, nil

------------------------------------------------------------------ postavke

local function save_cfg() N.write('postavke.txt', 'lock=' .. (cfg.lock and '1' or '0')) end
local function load_cfg()
  local s = N.read('postavke.txt') or ''
  cfg.lock = s:match('lock=1') ~= nil
end

------------------------------------------------------------------ rubrike za čitanje

-- izdanje -> popis rubrika; svaka rubrika je niz stavki { font, text, indent, gap } ili { rule = true }
local function build_sections()
  sections = {}
  if not izd then return end
  local items = {}
  if izd.vrijeme then
    items[#items + 1] = { font = 'small', text = 'Vrijeme: ' .. izd.vrijeme, gap = 0 }
    items[#items + 1] = { rule = true }
  end
  for _, u in ipairs(izd.ukratko) do
    items[#items + 1] = { font = 'medium', text = '- ' .. u, indent = 0, hang = 18, gap = 10 }
  end
  sections[#sections + 1] = { naslov = 'Ukratko', items = items, count = #izd.ukratko }

  for _, r in ipairs(izd.rubrike) do
    local it = {}
    for k, c in ipairs(r.clanci) do
      if k > 1 then it[#it + 1] = { rule = true } end
      it[#it + 1] = { font = 'large', text = c.naslov or '', gap = 4 }
      if c.tekst then it[#it + 1] = { font = 'medium', text = c.tekst, gap = 6 } end
      if c.zasto then it[#it + 1] = { font = 'small', text = 'Zašto je važno: ' .. c.zasto, indent = 12, gap = 8 } end
      if c.izvor then it[#it + 1] = { font = 'small', text = 'Izvor: ' .. c.izvor, gap = 6 } end
    end
    sections[#sections + 1] = { naslov = r.naziv, items = it, count = #r.clanci }
  end

  if izd.kraj and izd.kraj.tekst then
    local it = { { font = 'medium', text = izd.kraj.tekst, gap = 20 } }
    if izd.kraj.autor then it[#it + 1] = { font = 'medium', text = '- ' .. izd.kraj.autor, indent = 160, gap = 12 } end
    sections[#sections + 1] = { naslov = 'Za kraj', items = it }
  end
end

-- stavke rubrike -> stranice redaka { {y, font, text, x} | {y, rule} }
local function paginate(items)
  local out, cur = {}, {}
  local y = BODY_TOP
  local function new_page()
    out[#out + 1] = cur
    cur, y = {}, BODY_TOP
  end
  for _, it in ipairs(items) do
    if it.rule then
      if #cur > 0 then
        if y + 18 > BODY_BOTTOM then new_page()
        else cur[#cur + 1] = { y = y + 8, rule = true }; y = y + 18 end
      end
    else
      local x = MARGIN + (it.indent or 0)
      local lh = N.line_h(it.font)
      local lines = N.wrap(it.text, it.font, W - x - MARGIN - (it.hang or 0))
      if #cur > 0 then y = y + (it.gap or 0) end
      for i, s in ipairs(lines) do
        if y + lh > BODY_BOTTOM then new_page() end
        cur[#cur + 1] = { y = y, x = (i > 1) and (x + (it.hang or 0)) or x, font = it.font, text = s }
        y = y + lh + 2
      end
    end
  end
  if #cur > 0 or #out == 0 then out[#out + 1] = cur end
  return out
end

------------------------------------------------------------------ preuzimanje

local function keep_wifi() pcall(function() ctx.net:keep_wifi(3 * 60 * 1000) end) end

local function load_cache()
  izd = N.parse(N.read(N.CACHE))
  build_sections()
  pages = nil
end

local function refresh()
  if busy then return end
  if not ctx.net then status = 'Ova verzija nema pristup mreži.'; return end
  busy, status = true, 'Preuzimam današnje novine...'
  keep_wifi()
  local ok, err = pcall(function()
    ctx.net:request({ url = N.URL .. '?v=' .. N.epoch(), method = 'GET', timeout_ms = 30000 }, function(c, resp)
      busy = false
      local okh, e = pcall(function()
        if type(resp) ~= 'table' or type(resp.body) ~= 'string' then
          status = 'Nema veze. Prikazujem spremljeno izdanje.'; return
        end
        local code = tonumber(resp.status) or tonumber(resp.code)
        if code and code >= 400 then status = 'Greška poslužitelja (HTTP ' .. code .. ').'; return end
        local novo = N.parse(resp.body)
        if not novo then status = 'Primljeni podaci nisu valjani.'; return end
        N.write(N.CACHE, resp.body)
        izd = novo
        build_sections()
        pages = nil
        if screen == 'read' and sec > #sections then screen, sec, page = 'home', 1, 1 end
        status = 'Preuzeto u ' .. N.hhmm() .. '.'
      end)
      if not okh then status = 'Greška: ' .. tostring(e):sub(1, 40) end
      pcall(function() ctx:invalidate() end)
    end)
  end)
  if not ok then busy, status = false, 'Ne mogu poslati zahtjev: ' .. tostring(err):sub(1, 30) end
end

------------------------------------------------------------------ zaključani ekran

local function set_lock(on)
  local L = ctx.lockscreen
  if not L then status = 'Ovaj firmware nema zaključani ekran za aplikacije.'; return end
  cfg.lock = on
  save_cfg()
  local okd, isdef = pcall(function() return L:is_default() end)
  if on then
    if not (okd and isdef == true) then pcall(function() L:set_default() end) end
    status = 'Zaključani ekran: novine.'
  else
    if okd and isdef == true then pcall(function() L:clear_default() end) end
    status = 'Zaključani ekran: isključen.'
  end
end

------------------------------------------------------------------ crtanje

local function button(g, x, y, w, h, label, font)
  g:rect(x, y, w, h)
  local f = font or 'medium'
  local tw = N.width(f, label)
  g:text(x + math.max(4, (w - tw) // 2), y + (h - N.line_h(f)) // 2, label, { font = N.font(f) })
end

local function home_rows()
  local rows = {}
  for k, s in ipairs(sections) do
    local extra = s.count and (s.count .. (s.naslov == 'Ukratko' and ' vijesti' or ' članaka')) or ''
    rows[#rows + 1] = { label = s.naslov, extra = extra, sec = k }
  end
  return rows
end

local ROW_Y, ROW_H = 210, 68

local function draw_home(g)
  if not izd then
    g:text(MARGIN, 16, 'Novine', { font = N.font('large') })
    g:line(0, 76, W, 76)
    local y = 120
    for _, s in ipairs(N.wrap('Još nema preuzetog izdanja. Uključi Wi-Fi i dodirni Osvježi.', 'medium', W - 2 * MARGIN)) do
      g:text(MARGIN, y, s, { font = N.font('medium') }); y = y + 30
    end
    return
  end
  g:text(MARGIN, 10, izd.naslov or 'Novine', { font = N.font('large') })
  g:text(MARGIN, 46, N.date_hr(izd.datum), { font = N.font('small') })
  g:line(0, 76, W, 76)
  local y = 88
  if izd.vrijeme then
    local lines = N.wrap(izd.vrijeme, 'small', W - 2 * MARGIN - 16)
    local n = math.min(#lines, 4)
    g:rect(MARGIN, y, W - 2 * MARGIN, n * 22 + 14)
    for i = 1, n do g:text(MARGIN + 8, y + 7 + (i - 1) * 22, lines[i], { font = N.font('small') }) end
  end
  local today = N.today()
  if today and izd.datum < today then
    g:text(MARGIN, ROW_Y - 28, 'Ovo je izdanje od ' .. N.date_short(izd.datum) .. ' - dodirni Osvježi.', { font = N.font('small') })
  end
  for k, r in ipairs(home_rows()) do
    local ry = ROW_Y + (k - 1) * ROW_H
    if ry + ROW_H > BTN_Y - 40 then break end
    g:text(MARGIN + 4, ry + 12, r.label, { font = N.font('large') })
    if r.extra ~= '' then
      g:text(W - MARGIN - N.width('small', r.extra) - 28, ry + 20, r.extra, { font = N.font('small') })
    end
    g:text(W - MARGIN - 16, ry + 12, '>', { font = N.font('large') })
    g:line(MARGIN, ry + ROW_H - 4, W - MARGIN, ry + ROW_H - 4)
  end
end

local function draw_read(g)
  local s = sections[sec]
  if not s then screen = 'home'; return draw_home(g) end
  if not pages then pages = paginate(s.items) end
  if page > #pages then page = #pages end
  button(g, 8, 8, 104, 48, '< Natrag', 'small')
  g:text(124, 16, s.naslov, { font = N.font('large') })
  local pg = page .. '/' .. #pages
  g:text(W - MARGIN - N.width('small', pg), 24, pg, { font = N.font('small') })
  g:line(0, HEAD_H, W, HEAD_H)
  for _, l in ipairs(pages[page]) do
    if l.rule then g:line(MARGIN + 60, l.y, W - MARGIN - 60, l.y)
    else g:text(l.x, l.y, l.text, { font = N.font(l.font) }) end
  end
end

local function bottom_buttons()
  if screen == 'read' then
    local last = pages and page >= #pages
    local next_label = (last and sec < #sections) and 'Dalje: ' .. sections[sec + 1].naslov or 'Sljedeća >'
    return { { '< Prethodna', 'prev' }, { next_label, 'next' } }
  end
  return { { 'Osvježi', 'refresh' }, { cfg.lock and 'Zaklj. ekran: da' or 'Zaklj. ekran: ne', 'lock' } }
end

local function button_rect(k, n)
  local bw = (W - 24 - (n - 1) * 8) // n
  return 12 + (k - 1) * (bw + 8), BTN_Y, bw, BTN_H
end

function on_draw(c, g)
  if not g then return end
  local ok, e = pcall(function()
    g:clear(0)
    if screen == 'read' then draw_read(g) else draw_home(g) end
    local line = status
    if line then g:text(12, BTN_Y - 30, line:sub(1, 60), { font = N.font('small') }) end
    local bs = bottom_buttons()
    for k, b in ipairs(bs) do
      local x, y, bw, bh = button_rect(k, #bs)
      local label = b[1]
      if N.width('medium', label) <= bw - 8 then
        button(g, x, y, bw, bh, label, 'medium')
      else
        if N.width('small', label) > bw - 8 then label = (b[2] == 'next') and 'Sljedeća rubrika >' or label:sub(1, 16) end
        button(g, x, y, bw, bh, label, 'small')
      end
    end
  end)
  if not ok then pcall(function() g:text(8, H - 90, ('Greška crtanja: ' .. tostring(e)):sub(1, 50)) end) end
end

------------------------------------------------------------------ unos

local function open_section(k)
  if not sections[k] then return end
  screen, sec, page, pages, status = 'read', k, 1, nil, nil
end

local function go(dir)
  if screen ~= 'read' then return end
  if not pages then pages = paginate(sections[sec].items) end
  if dir > 0 then
    if page < #pages then page = page + 1
    elseif sec < #sections then open_section(sec + 1)
    else screen = 'home' end
  else
    if page > 1 then page = page - 1
    elseif sec > 1 then
      open_section(sec - 1)
      pages = paginate(sections[sec].items)
      page = #pages
    else screen = 'home' end
  end
end

local function act(what)
  status = nil
  if what == 'refresh' then refresh()
  elseif what == 'lock' then set_lock(not cfg.lock)
  elseif what == 'prev' then go(-1)
  elseif what == 'next' then go(1) end
end

local function tap(x, y)
  local bs = bottom_buttons()
  for k, b in ipairs(bs) do
    local bx, by, bw, bh = button_rect(k, #bs)
    if x >= bx and x < bx + bw and y >= by and y < by + bh then act(b[2]); return end
  end
  if screen == 'read' then
    if y < HEAD_H then
      if x < 120 then screen, status = 'home', nil end
    elseif x < W // 3 then go(-1)
    else go(1) end
  else
    if y >= ROW_Y then
      local k = (y - ROW_Y) // ROW_H + 1
      if sections[k] then open_section(k) end
    end
  end
end

local function key_accepted(ev)
  local ph = ev.phase or ev.action or ev.state
  if ph == 'up' or ph == 'release' or ph == 'released' or ev.pressed == false then return false end
  local okt, t = pcall(function() return ctx.clock:millis() end)
  t = tonumber(ev.time_ms) or (okt and tonumber(t)) or nil
  if t and last_key == ev.key and last_key_ms and t - last_key_ms >= 0 and t - last_key_ms < 250 then return false end
  last_key, last_key_ms = ev.key, t
  return true
end

function on_input(c, ev)
  local handled = true
  local ok, e = pcall(function()
    if type(ev) ~= 'table' then return end
    if ev.type == 'pointer' then
      if ev.phase == 'up' then
        local gst = tostring(ev.gesture or '')
        if screen == 'read' and gst:match('swipe_left') then go(1)
        elseif screen == 'read' and gst:match('swipe_right') then go(-1)
        else tap(ev.x or 0, ev.y or 0) end
      end
    elseif ev.type == 'key' then
      if ev.key == 'back' then
        -- Natrag djeluje na otpuštanje; na početnom ekranu prepušta se sustavu
        if ev.phase ~= 'up' and ev.phase ~= nil then return end
        if screen == 'read' then screen = 'home' else handled = false end
      elseif key_accepted(ev) then
        if ev.key == 'right' or ev.key == 'down' then go(1)
        elseif ev.key == 'left' or ev.key == 'up' then go(-1)
        elseif ev.key == 'ok' and screen == 'home' then open_section(1) end
      end
    end
  end)
  if not ok then status = 'Greška: ' .. tostring(e):sub(1, 40) end
  pcall(function() ctx:invalidate() end)
  return handled
end

function on_load(c)
  local ok, e = pcall(function()
    load_cfg()
    load_cache()
    local today = N.today()
    -- staro ili nikakvo izdanje: odmah preuzmi novo
    if not izd or (today and izd.datum < today) then refresh() end
  end)
  if not ok then status = 'Greška pri pokretanju: ' .. tostring(e):sub(1, 30) end
end

function on_leave()
  pcall(function() ctx.net:keep_wifi(1) end)
end

function on_tick() end
