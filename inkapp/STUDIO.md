# InkApp "Novine" – upute za InkApp AI Studio

Ovdje je sve što treba da aplikaciju napraviš u [InkApp AI Studiju](https://xtapp-ai.xteink.cc/developer)
i instaliraš je na svoj X4 Pro.

## Prije početka

1. Napravi Xteink račun u aplikaciji **XTEINK** na mobitelu (ako ga nemaš).
2. Na <https://xtapp-ai.xteink.cc/developer> se prijavi istim računom i klikni **Apply for Developer Access**.
3. Kad dobiješ odobrenje, otvori Studio i napravi novi projekt.

## Korak 1: zalijepi ovaj opis u Studio

Studio radi s opisom na engleskom najbolje, a tekst u aplikaciji ostaje na hrvatskom.
Kopiraj cijeli blok:

```text
Build an e-paper news reader app called "Novine" (Croatian for "Newspaper") for the X4 Pro (480x800 portrait). All UI text must be in Croatian, exactly as given below.

DATA
- On open, download https://zsimunovic.github.io/xteink-novine/najnovije.txt with a GET request (append "?v=<epoch seconds>" to avoid caches, timeout 30 s, keep Wi-Fi up for 3 minutes while the app is open).
- Download only when there is no saved edition or the saved edition's date (D line) is older than today's date on the device. Also offer a manual "Osvježi" button.
- Save the downloaded text to app storage as "izdanje.txt" and always draw from the saved copy, so the app works offline.
- The file is UTF-8 text, one record per line, "TAG|value":
  D = date YYYY-MM-DD, N = edition title, R = period covered, V = weather for Zagreb (one sentence),
  G = generated timestamp, U = one "Ukratko" headline (repeats, usually 5),
  S = start of a section (section name), T = article title, X = article text,
  Z = "why it matters" sentence (optional), I = sources (optional),
  K = closing quote or fun fact, A = author of K (optional).
  T/X/Z/I lines belong to the most recent S section. Ignore unknown tags. Reject the file if the D line is missing.
- Replace characters the device font may lack: en/em dash -> "-", « » „ " " -> '"', ' ' -> "'", … -> "...".

HOME SCREEN
- Top: edition title (large), below it the date in Croatian, e.g. "srijeda, 25. studenoga 2026." (weekday + day + month in genitive + year), then a horizontal line.
- A framed box with the weather sentence (small font, up to 4 lines).
- If the saved edition is older than today: small line "Ovo je izdanje od 25.11. - dodirni Osvježi."
- A list of tappable rows (68 px high, separated by thin lines): "Ukratko" (with "5 vijesti" on the right), then one row per section with "N članaka" on the right, then "Za kraj" if K exists. Each row ends with ">".
- Status line above the buttons (e.g. "Preuzimam današnje novine...", "Preuzeto u 07:05.", "Nema veze. Prikazujem spremljeno izdanje.").
- Two framed buttons at the bottom: "Osvježi" and "Zaklj. ekran: da/ne" (toggles the app as the lock screen).

READING SCREEN (one per section)
- Header: framed "< Natrag" button, the section name (large), page "2/5" on the right, line below.
- Body flows text with word wrap on spaces and splits it into pages:
  article title in large font, article text in medium font, "Zašto je važno: ..." in small font slightly indented,
  "Izvor: ..." in small font, and a short centered line between articles.
  The "Ukratko" section shows the weather sentence first, then each headline as "- text" with a hanging indent.
  "Za kraj" shows the K text and "- author" right-aligned below it.
- Bottom buttons: "< Prethodna" and "Sljedeća >". On the last page of a section the right button says "Dalje: <next section>" (or "Sljedeća rubrika >" if too long) and opens the next section.
- Tap the left third of the body for the previous page, anywhere else in the body for the next page. Swipe left/right also pages. Side buttons: right/down = next, left/up = previous. Back returns to the home screen.

LOCK SCREEN (when enabled)
- "NOVINE" (large) on the left, the Croatian date on the right, a double line below.
- The weather sentence (small), a line, then the Ukratko headlines as "- text" (medium) until the screen is full.
- Footer: "Ostatak u aplikaciji Novine." or, if the saved edition is older than today, "Izdanje od 25.11. - otvori Novine za novo."
- It only reads the saved "izdanje.txt"; refresh it every hour.

STYLE
- Black on white, thin lines and frames, no large filled black areas (e-ink ghosting).
- Keep each screen well under 1000 draw commands.
```

## Korak 2: ako Studio dopušta uređivanje koda

Gotov i testiran kod je u mapi [`novine/`](novine/):

| datoteka | što je |
|---|---|
| `manifest.json` | ime, dozvola `net`, zaključani ekran |
| `index.lua` | aplikacija |
| `lockscreen.lua` | zaključani ekran |
| `icon.png` | ikona 96×96 |

Ako Studio prikazuje kod koji je napisao i dopušta izmjene, možeš zamijeniti njegov `index.lua` i
`lockscreen.lua` ovima. Kod je napisan prema API-ju koji je dokumentirala zajednica
([touch-licorice-apps](https://github.com/omer-faruq-xteink/touch-licorice-apps)), pa se nazivi u
Studiju mogu malo razlikovati. U tom slučaju je sigurniji opis iz koraka 1.

## Korak 3: isprobaj i instaliraj

1. U pregledu u Studiju provjeri početni ekran, jednu rubriku i listanje.
2. Klikni instalaciju na uređaj ("Install on your X4 Pro").
3. Na uređaju otvori **Novine**. Prvi put treba Wi-Fi da se izdanje preuzme.
4. Ako želiš novine na zaključanom ekranu, dodirni **Zaklj. ekran: ne** i potvrdi. U postavkama
   uređaja *Display → Off wallpaper* mora biti **Default**.

Objava u Store nije potrebna za vlastitu upotrebu.

## Za razvoj

- Mijenja se `src/` (`common.lua`, `app.lua`, `lock.lua`), a zatim se `python3 inkapp/sastavi.py`
  složi `novine/index.lua` i `novine/lockscreen.lua`.
- Testovi s lažnim uređajem: `pip install lupa && python3 inkapp/test_novine.py`.
- Pregled ekrana u PNG-u: `python3 inkapp/pregled.py inkapp/pregled` (treba i Pillow).
- Podatke aplikaciji daje `najnovije.txt`, koji `napravi_katalog.py` piše svako jutro.
