# uk's medis – Bauen über GitHub & TestFlight (ohne Mac)

GitHub baut die App auf einem Mac in der Cloud, signiert sie mit deinem
Developer-Account und lädt sie direkt zu TestFlight hoch.

---

## 1. Bundle-ID registrieren (einmalig, ca. 2 Min.)

developer.apple.com → **Certificates, Identifiers & Profiles → Identifiers → +**
- Typ: **App IDs → App**
- Description: `uks medis`
- Bundle ID (Explicit): **`de.uklink.uksmedis`**
- Capabilities: nichts weiter nötig (Push-Hinweise sind lokal) → **Register**

> Andere Bundle-ID gewünscht? Dann auch in `project.yml` bei
> `PRODUCT_BUNDLE_IDENTIFIER` ändern.

## 2. App in App Store Connect anlegen

appstoreconnect.apple.com → **Apps → + → Neue App**
- Plattform: iOS
- Name: `uk's medis` (falls vergeben: z. B. `uk's medis – Plan`)
- Sprache: Deutsch
- Bundle-ID: `de.uklink.uksmedis` auswählen
- SKU: `uksmedis`

## 3. API-Schlüssel erstellen

App Store Connect → **Benutzer und Zugriff → Integrationen → App Store Connect API → Team-Schlüssel → +**
- Name: `GitHub`
- Zugriff: **Admin** (nötig, damit die Signatur-Zertifikate automatisch erstellt werden)
- **.p8-Datei herunterladen** (geht nur einmal!)
- Notieren: **Key ID** und **Issuer ID** (steht oben auf der Seite)

Team ID: developer.apple.com → **Membership details → Team ID**

## 4. GitHub-Repository anlegen

1. github.com → **New repository** → Name `uks-medis` → **Private** → Create
2. **Add file → Upload files** → den kompletten Inhalt dieses Ordners hineinziehen
   (inkl. des Ordners `.github` – unter Windows ggf. „Ausgeblendete Elemente“ einblenden)
3. **Commit changes**

## 5. Geheimnisse hinterlegen

Repository → **Settings → Secrets and variables → Actions → New repository secret**

| Name            | Inhalt                                                     |
|-----------------|------------------------------------------------------------|
| `ASC_KEY_ID`    | Key ID aus Schritt 3                                       |
| `ASC_ISSUER_ID` | Issuer ID aus Schritt 3                                    |
| `ASC_KEY_P8`    | Kompletter Inhalt der .p8-Datei (mit Editor öffnen, alles kopieren, inkl. `-----BEGIN PRIVATE KEY-----`-Zeilen) |
| `APPLE_TEAM_ID` | Deine Team ID (10 Zeichen)                                 |

## 6. Bauen

Repository → **Actions → Build & TestFlight → Run workflow**.
Dauert ca. 10 Minuten. Danach braucht Apple noch 5–30 Minuten zur Verarbeitung.
Jeder spätere Push auf `main` baut automatisch eine neue Version.

## 7. Aufs iPhone

App Store Connect → deine App → **TestFlight → Interne Tests → +** → Gruppe anlegen,
dich selbst als Tester hinzufügen, den Build zuordnen.
Auf dem iPhone die App **TestFlight** öffnen → **uk's medis installieren**.
Beim ersten Start die Mitteilungen erlauben.

TestFlight-Builds laufen 90 Tage – einfach vorher den Workflow neu starten.

---

## Funktionen
- **Heute**: alle Einnahmen nach Morgens/Mittags/Nachmittags/Abends, „Als Nächstes“-Karte,
  Fortschrittsbalken, Abhaken per Tippen, verpasste Einnahmen in Rot.
- **Medikamente**: hinzufügen (+), bearbeiten (antippen), löschen (nach links wischen);
  beliebig viele Uhrzeiten, Dosierung und Hinweis.
- **Push-Erinnerungen**: täglich zu jeder Uhrzeit, auch bei geschlossener App.

## Wenn der Build fehlschlägt
Unter **Actions** den roten Lauf öffnen, den fehlgeschlagenen Schritt aufklappen
und die letzten Zeilen kopieren – damit lässt sich der Fehler schnell beheben.
