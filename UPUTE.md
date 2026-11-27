# Upute za dnevno izdanje

Ovo je profil novina i postupak koji dnevni zadatak slijedi svako jutro.
Mijenjaj ovu datoteku ako želiš promijeniti što ulazi u novine.

## Profil čitatelja

- **Jezik:** hrvatski (strane vijesti prevedi i sažmi na hrvatski).
- **Duljina:** 5–10 minuta čitanja, ukupno oko 20–25 vijesti.
- **Stil:** neutralno i činjenično. Uz važnije vijesti dodaj kratko polje
  `zasto` (jedna rečenica: zašto je to važno ili što znači za čitatelja). Nikakvo
  nagađanje ni izmišljanje: piši samo ono što stoji u izvorima.
- **Rubrike, ovim redom:**
  1. **Hrvatska** – politika, društvo, zdravstvo, važne odluke Vlade i Sabora.
  2. **Svijet** – geopolitika, EU, SAD, ratovi, veliki događaji.
  3. **Ekonomija i financije** – posebno: hrvatske tvrtke i startupi (Rimac, Infobip,
     Zagrebačka burza…), nekretnine, kamate, mirovine, porezi, trezorci, osobne financije.
  4. **Tehnologija i AI** – posebno: AI alati i modeli (Claude, GPT, Gemini…), AI regulativa,
     gadgeti, e-čitači i e-ink (Xteink, Kindle, Kobo…).
     **Popularnost:** `skupi_vijesti.py` na kraju daje najpopularnije priče s Hacker Newsa
     (bodovi i komentari iz zadnjih ~26 h). Koristi ih kao signal: tema iz profila koja ima
     puno bodova dobiva prednost, a jedna ili dvije najpopularnije IT teme dana mogu ući i ako
     nisu strogo u profilu (u `zasto` napiši da o tome raspravlja IT zajednica). Hacker News
     nije izvor činjenica: činjenice uzmi iz pravih izvora ili pretrage, a ne iz naslova.
- **Vrijeme za Zagreb:** vrlo kratko, prvi redak u "Ukratko" (npr. "Zagreb danas: 2–7 °C,
  kiša poslijepodne. Upozorenje: jaka bura."). Ako nema upozorenja, ne spominji ih.
- **Za kraj:** jedan kratki citat ili neobična zanimljivost (polje `zanimljivost`),
  po mogućnosti povezana s nečim iz vijesti tog dana. Za citat navedi autora.

## Ne stavljati

- **MasterChef** – nikakve vijesti ni spomene (čitatelj ne želi spoilere). Ovo vrijedi i za
  "Ukratko" i za zanimljivost.
- **Sport** – nema sportske rubrike ni sportskih vijesti.
- **Lifestyle i savjeti** – recepti, zdravlje/prehrana, horoskop, moda, akcije i popusti u
  trgovinama, Black Friday.
- Tračevi i celebrity vijesti samo ako su stvarno značajni; crnu kroniku samo ako je riječ o
  događaju od šireg javnog značaja.

## Postupak

1. `python3 -m pip install -q --ignore-installed pillow` (u oblaku je sistemski Pillow
   pokvaren za python3; obični `pip install` instalira za krivu verziju Pythona).
2. `python3 skupi_vijesti.py > /tmp/vijesti.txt` – skupi RSS vijesti iz zadnjih ~26 sati
   (već filtrira MasterChef, sport i lifestyle) i vremensku prognozu za Zagreb.
   Ako neki izvor ne radi, skripta ga preskoči. Ako ih ne radi većina (npr. greška 403
   "no rule or network setting allows this host"), nadopuni vijesti web pretragom i u
   završnom izvještaju navedi koje domene treba dopustiti u mrežnim postavkama okruženja.
3. Pročitaj `/tmp/vijesti.txt` i odaberi najvažnije vijesti prema profilu. Spoji istu vijest
   iz više izvora u jedan članak. Za svaku rubriku stavi 3–6 članaka; manje važne skupi u
   zadnji članak rubrike s naslovom "Ukratko".
4. Napiši `izdanja/GGGG-MM-DD.json` (današnji datum, Europe/Zagreb) po uzoru na
   postojeća izdanja. Polja:
   - `datum`, `naslov` ("Jutarnji pregled"), `razdoblje` (npr. "Vijesti od 24. studenoga 2026.")
   - `vrijeme` – jedna rečenica o vremenu u Zagrebu
   - `ukratko` – 5 najvažnijih stvari, po jedna rečenica
   - `rubrike` – lista `{naziv, clanci: [{naslov, tekst, zasto?, izvor}]}`
   - `zanimljivost` – `{tekst, autor?}`
5. `python3 napravi_epub.py izdanja/GGGG-MM-DD.json`
6. `python3 napravi_katalog.py`
7. Commit ("Izdanje GGGG-MM-DD") i push na `main`.
