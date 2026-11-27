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
  4. **Tehnologija i AI** – posebno:
     - AI alati i modeli (Claude, GPT, Gemini…) i AI regulativa
     - gadgeti
     - kibernetička sigurnost (napadi, curenja podataka, važne ranjivosti, prevare; posebno u HR)
     - softver i razvoj (programiranje, open source, alati i AI agenti za developere)
     - Big Tech i tržište (Apple, Google, Microsoft, Meta, Nvidia: poslovni potezi, tužbe,
       regulacija tržišnog natjecanja)
     - čipovi i hardver (procesori, GPU-ovi, podatkovni centri, nestašice i cijene memorije)
     - hrvatska digitalna scena (telekomi, internet i 5G, e-Građani, digitalizacija uprave,
       hrvatske IT tvrtke)
     - svemir i znanost (svemirske misije, važni znanstveni proboji vezani uz tehnologiju)
     E-čitače i e-ink ne stavljaj, osim ako je riječ o stvarno velikoj vijesti.
     **Popularnost:** `skupi_vijesti.py` na kraju daje najpopularnije priče s Hacker Newsa
     (bodovi i komentari iz zadnjih ~26 h). Koristi ih kao signal: tema iz profila koja ima
     puno bodova dobiva prednost, a jedna ili dvije najpopularnije IT teme dana mogu ući i ako
     nisu strogo u profilu (u `zasto` napiši da o tome raspravlja IT zajednica). Hacker News
     nije izvor činjenica: činjenice uzmi iz pravih izvora ili pretrage, a ne iz naslova.
- **Vrijeme za Zagreb:** vrlo kratko, prvi redak u "Ukratko" (npr. "Zagreb danas: 2–7 °C,
  kiša poslijepodne. Upozorenje: jaka bura."). Ako nema upozorenja, ne spominji ih.
- **Za kraj** (polje `zanimljivost`, 3–6 rečenica). Vrsta ovisi o danu u tjednu:
  - ponedjeljak i petak: **Pojam dana** – jedan pojam iz današnjih vijesti objašnjen jednostavno
    (npr. trezorski zapisi, ransomware, inflacija jezgre). Tekst počni s "Pojam dana – <pojam>: ".
  - utorak i nedjelja: **Zanimljivost iz znanosti** – neobična, provjerljiva činjenica iz znanosti,
    prirode ili tehnologije. Počni s "Zanimljivost: ".
  - srijeda i subota: **Mozgalica** – kratka zagonetka ili logički zadatak koji se može riješiti
    u glavi. Počni s "Mozgalica: ". Rješenje se NE daje isti dan.
  - četvrtak: **Preporuka za čitanje** – jedna knjiga ili duži članak vezan uz neku temu dana,
    s jednom rečenicom zašto. Počni s "Preporuka za čitanje: ". Preporuči samo djela za koja si
    siguran da postoje (autor i naslov).
  - **Dan nakon mozgalice** (četvrtak i nedjelja): na početak teksta dodaj "Rješenje jučerašnje
    mozgalice: …" (pročitaj jučerašnje izdanje u `izdanja/`), pa tek onda današnji sadržaj.
  Polje `autor` koristi samo ako navodiš citat.

## Ne stavljati

- **MasterChef** – nikakve vijesti ni spomene (čitatelj ne želi spoilere). Ovo vrijedi i za
  "Ukratko" i za zanimljivost.
- **Sport** – nema sportske rubrike. Sportska vijest ulazi samo ako je od šireg javnog
  značaja (npr. veliki uspjeh hrvatske reprezentacije, plasman na SP/EP, olimpijska medalja,
  povijesni rekord ili događaj koji je izašao iz sportskih okvira) i tada ide u "Hrvatska" ili
  "Svijet", najviše jedna dnevno. `skupi_vijesti.py` sport daje kao zaseban popis naslova.
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
