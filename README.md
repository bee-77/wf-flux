# Bokeltsen Blagen – Garmin Watch Face

Ein Garmin Connect IQ Watch Face für den Bokeltsen Blagen Sportclub.

**Autor:** beejay
**Version:** 1.0.0
**Min. API Level:** 3.2.0
**App-ID:** 7a05f90d-a657-485c-9337-87ea0c266f11

---

## Features

- **Uhrzeit** – 12h oder 24h (Militärformat), mit orangem Glow-Effekt
- **Datum & Herzfrequenz** – kombiniert in einer Zeile
- **Zwei konfigurierbare Slots** (oben links/rechts):
  - Wetter mit Icon und Bezeichnung
  - Kalorien
  - Schritte inkl. Tagesziel (grün + durchgestrichen wenn erreicht)
  - Stockwerke
  - Aktive Minuten
- **Zwei Themes** – AMOLED-Schwarz und Orange/Hell
- **Slogan** – „ALLES KANN. NICHTS MUSS!"
- **Sleep-Modus** – gedimmte Uhrzeitanzeige
- **Wetter-Icons** – Sonne, Wolken, Regen, Schnee, Nebel, Gewitter (2 Größen)

---

## Unterstützte Geräte (~55 Modelle)

### Running
FR165, FR165M, FR255/M/S/SM, FR265/S, FR570 42/47mm, FR955, FR965, FR970

### Outdoor
Approach S50, S70 42/47mm, D2 Air X10, D2 Mach 1/2,
Descent MK3 43/51mm, Enduro 3, Epix 2, Epix 2 Pro 42/47/51mm,
Fenix 6/6S,
Fenix 7/S/X, 7 Pro/SPro/XPro, 7 Pro/XPro NoWiFi,
Fenix 8 43/47mm, 8 Pro 47mm, 8 Solar 47/51mm, Fenix E,
Instinct 3 AMOLED 45/50mm, Instinct 3 Solar 45mm, Instinct Crossover AMOLED,
MARQ 2, MARQ 2 Aviator

### Wellness
Venu SQ2/M, Venu 3/S, Venu 4 41/45mm, Vivoactive 5, Venu X1, Vivoactive 6

---

## Projektstruktur

```
Watchface-BBs/
├── manifest.xml                  # App-Konfiguration & Gerätliste
├── monkey.jungle                 # Build-Konfiguration & Launcher-Icon-Pfade
├── source/
│   ├── SportFaceApp.mc           # App-Einstiegspunkt & Settings-Callback
│   └── SportFaceView.mc          # Watch Face Logik & Zeichnung
├── resources/
│   ├── drawables/
│   │   ├── background*.png       # Hintergrundbilder (9 Größen x 2 Themes)
│   │   ├── ic_*.png              # Icons Wetter/Schritte/Herz (je 2 Größen)
│   │   ├── launcher_icon.png     # App-Icon (260px Basis)
│   │   └── drawables.xml
│   ├── strings/strings.xml       # Texte (DE/EN)
│   └── settings/
│       ├── settings.xml          # Einstellungs-UI
│       └── properties.xml        # Standard-Werte
├── resources-38/ bis resources-70/ # Gerätespezifische Launcher-Icons
└── store-assets/                 # Store-Icon, Screenshots, Beschreibungen
```

---

## Einstellungen

| Setting | Optionen | Standard |
|---|---|---|
| Theme | AMOLED Schwarz / Orange Hell | Schwarz |
| Zeitformat | 12h / 24h (Militär) | 24h |
| Slot oben links | Wetter / Kalorien / Schritte / Stockwerke / Akt. Minuten | Wetter |
| Slot oben rechts | Wetter / Kalorien / Schritte / Stockwerke / Akt. Minuten | Schritte |

Einstellungen sind direkt auf der Uhr zugänglich:
**Einstellungen > Aussehen > Zifferblätter** oder **UP-Taste gedrückt halten** (ab Firmware 10+)

---

## Entwicklung

### Voraussetzungen
- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) 4.0+
- Visual Studio Code + Monkey C Extension

### Simulator starten
In VS Code: `Cmd+Shift+P` > **Monkey C: Run Current Project** > Gerät wählen (z. B. `fenix7`)

### Auf Uhr laden (Sideload)
1. Uhr per USB verbinden
2. `Monkey C: Build for Device` > `.prg` erzeugen
3. `.prg`-Datei in `GARMIN/Apps/` auf der Uhr kopieren

---

## Lizenz

Privates Projekt – Bokeltsen Blagen Sportclub. Alle Rechte vorbehalten.
