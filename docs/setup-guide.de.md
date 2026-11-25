# Einrichtungsanleitung

*English version: [setup-guide.md](setup-guide.md)*

Die einmalige Einrichtung dauert etwa 10 Minuten. Du brauchst:

- das Addon **The Guild Registrar** (CurseForge),
- einen PC mit Windows, macOS oder Linux,
- auf eurem Discord-Server das Recht **Server verwalten** - oder jemanden, der es hat und einmal einen Link für dich öffnet.

> **Du bist Offizier und dein Gildenmeister hat den Bot schon eingerichtet?** Dann brauchst du keinen eigenen Bot: Schritt 1 ausführen, danach direkt zu [Weitere Offiziere](#7-weitere-offiziere).

## 1. Hilfsprogramm Peasant herunterladen und starten

1. Öffne das [aktuelle Release](https://github.com/Flotomat/TheGuildRegistrar/releases/latest) und lade die Datei für dein System herunter:
   - Windows: `TheGuildRegistrar-Peasant-windows-x64.zip`
   - Mac mit Apple-Chip (M1 und neuer): `TheGuildRegistrar-Peasant-macos-apple-silicon.zip`
   - Mac mit Intel-Chip: `TheGuildRegistrar-Peasant-macos-intel.zip`
   - Linux: `TheGuildRegistrar-Peasant-linux-x64.tar.gz`
2. In einen beliebigen Ordner entpacken und `TheGuildRegistrar-Peasant` starten.
3. **Sicherheitswarnung:** Das Programm ist nicht mit einem kostenpflichtigen Zertifikat signiert, deshalb warnt dein System beim ersten Start.
   - **Windows SmartScreen** („Der Computer wurde durch Windows geschützt“): **Weitere Informationen** → **Trotzdem ausführen**.
   - **macOS** („kann nicht geöffnet werden, da der Entwickler nicht verifiziert werden kann“): Rechtsklick auf die Datei → **Öffnen** → **Öffnen**. Alternativ im Terminal: `xattr -d com.apple.quarantine TheGuildRegistrar-Peasant`.
   - Das Programm ist Open Source; der Quellcode liegt in diesem Repository.
4. Es öffnet sich ein kleines Konsolenfenster und im Browser der Assistent. Lass das Konsolenfenster offen, solange du das Programm benutzt.

## 2. Eigenen Discord-Bot anlegen

1. Öffne das [Discord Developer Portal](https://discord.com/developers/applications) und melde dich mit deinem Discord-Konto an.
2. Klicke auf **New Application**, gib einen Namen ein (z. B. *Guild Registrar*), akzeptiere die Bedingungen und klicke auf **Create**.
3. Klicke links im Menü auf **Bot**.
4. Unter **Privileged Gateway Intents** den Schalter **Server Members Intent** einschalten und **Save Changes** klicken.
   *(Ohne diesen Schalter darf der Bot die Mitgliederliste nicht sehen.)*
5. Optional, aber empfohlen: **Public Bot** ausschalten, damit nur du ihn einladen kannst.
6. **Reset Token** klicken, bestätigen und das Token **kopieren**.
   ⚠️ Das Token ist wie ein Passwort für den Bot. Niemals irgendwo posten.

## 3. Programm verbinden

1. Token in den Assistenten einfügen und **Prüfen & speichern** klicken.
2. Das Programm prüft das Token bei Discord und speichert es geschützt auf deinem PC (Windows: verschlüsselt, macOS: Schlüsselbund, Linux: nur für dich lesbare Datei).
3. Meldet es, dass *Server Members Intent* aus ist: zurück zu Schritt 2.4, speichern und die Seite neu laden.

## 4. Bot auf den Server einladen

1. Im Programm auf **Einladungslink öffnen** klicken.
2. Server auswählen und **Autorisieren** klicken. Der Bot verlangt **keine Rechte** - er sieht nur, was jedes Mitglied in der Mitgliederliste sieht.
3. Hast du das Recht *Server verwalten* nicht, schick den Link an jemanden, der es hat.
4. **Eingeladen - Server neu laden** klicken.

## 5. Exportieren und importieren

1. Server auswählen und **In die Zwischenablage exportieren** klicken.
2. In WoW `/tgr` eingeben (oder über **Optionen → AddOns → The Guild Registrar** öffnen), den Tab **Import** öffnen, ins Textfeld klicken, **Strg+V** (Mac: **Cmd+V**) drücken und **Importieren** klicken.
3. Der Tab **Abgleich** zeigt das Ergebnis.

Der Export wird **nicht in einer Datei gespeichert**: Er liegt nur in der Zwischenablage und auf der Seite des Programms und ist nach dem Beenden weg.

Später aktualisieren: Programm starten → **In die Zwischenablage exportieren** → im Spiel einfügen. Die Schritte 2-4 sind nicht mehr nötig.

## 6. Addon einstellen

**Ziel: Alles wird automatisch zugeordnet.** Ein Discord-Account kann mehrere Charaktere haben - einen Main und seine Twinks. Das Addon findet sie selbst, wenn die Gildendaten ein paar Regeln folgen:

- der **Discord-Name steht in der Offiziersnotiz** (oder öffentlichen Notiz) des Mains, z. B. `DC: Jens`,
- **Twinks** haben einen Twink-Rang oder eine Notiz wie `Twink Wurstinator` (ein Twink, dessen Notiz den Discord-Namen nennt, wird ebenfalls gefunden),
- optional folgen die Discord-Namen einer **Namensregel** wie `Spitzname | Main`.

Welche Notizen gelesen werden, steht im Tab Abgleich über der Liste (*Zuordnung über Charakternamen und: ...*) und lässt sich dort oder im Tab Einstellungen umschalten. Nicht verwendete Notizen werden grau angezeigt. Manuelle Zuweisungen sind der **Ausweichweg** für Einzelfälle (siehe unten) und lassen sich mit anderen Offizieren teilen.

- **Tab Ränge**: jede Discord-Rolle dem passenden Gildenrang zuordnen, Gast-Rollen (z. B. *Gast*, *Austauschschüler*) und Twink-/Alt-Ränge markieren.
- **Tab Einstellungen**: Namensregel (z. B. `Spitzname | Main`), verwendete Notizen, Bezeichnung „Twinks“ oder „Alts“, Twink-Muster, Notiz-Vorlagen und optionale Notiz-Prüfung, ignorierte Wörter, Schwellwerte.
- Im Tab **Abgleich** zeigt die Spalte *Anpassen* (und der Tooltip), was zu ändern ist: Gildenrang, Twink-Kennzeichnung, Gildennotiz, Zuordnung, Discord-Name. Ein Klick auf **+** klappt die Twinks eines Spielers aus.
- **Rechtsklick** auf einen Eintrag (oder einen Twink darunter) zeigt alle Aktionen. Was für den Eintrag nicht passt, ist ausgegraut; der Tooltip sagt, warum.
  - **Zuweisung bestätigen (fest)**: Die Zuweisung ändert sich nicht mehr automatisch.
  - **Bestätigung aufheben**: wieder automatische Zuordnung.
  - **Verbindung zum Discord-Mitglied lösen**: Der Charakter (als Main mit seinen Twinks) wird diesem Discord-Account nicht mehr zugeordnet. Bei einer festen Zuweisung fragt vorher ein Hinweisfenster. Rückgängig über *Manuelle Entscheidungen zurücksetzen*.
  - **Charakter per Name hinzufügen** / **Discord-Mitglied per Name zuweisen**, **Anderen Kandidaten zuordnen**, **Als Twink zuordnen von** / **Als Main markieren**, ignorieren, anflüstern, Notiz-Vorschlag kopieren.
- **Zuweisungen teilen** (Tab Abgleich) erzeugt einen Code mit deinen manuellen Entscheidungen. Gib ihn anderen Offizieren, z. B. als Textdatei in Discord; sie fügen ihn in ihrem Tab **Import** ein und bestätigen. Geteilte Einträge ersetzen ihre eigenen Entscheidungen für dieselben Charaktere. Der Code enthält Discord-Namen und Zuweisungen - gib ihn nur an Personen weiter, die sie sehen dürfen.
- Gildennotizen schreiben und Gildenränge ändern behält WoW: Forever dem Blizzard-Interface vor - das erledigst du im Gildenfenster. Im Addon sind diese Menüpunkte ausgegraut.

## 7. Weitere Offiziere

Damit nicht jeder Offizier einen eigenen Bot braucht, kann der Gildenmeister (oder wer den Bot eingerichtet hat) den Bot mit einem **Einladungscode** teilen. Der Code enthält das Bot-Token, verschlüsselt mit einem Passwort; angezeigt wird das Token nie.

**Gildenmeister - Code erzeugen (einmal pro Offizier oder für alle gemeinsam):**

1. Peasant starten, im Abschnitt **Weitere Offiziere** die Art des Passworts wählen:
   - **Starkes Passwort erzeugen (empfohlen)** - z. B. `K7QF-2MXP-...`, gut zum Kopieren.
   - **Passwort selbst festlegen** - z. B. wenn du es im Sprachchat durchsagen willst. Peasant zeigt dabei grob an, wie stark es ist (Länge, Groß-/Kleinbuchstaben, Ziffern, Sonderzeichen, Vielfalt). Wie stark es sein soll, entscheidest du; bei einem schwachen Passwort fragt Peasant nach.
2. **Einladungscode erzeugen** klicken.
3. Code und Passwort **auf verschiedenen Wegen** weitergeben, z. B. den Code als Discord-Direktnachricht und das Passwort im Sprachchat oder per Flüstern im Spiel. Nie in einen Kanal posten. Peasant speichert weder Code noch Passwort.

**Offizier - Code einlösen:**

1. Peasant herunterladen und starten (Schritt 1).
2. Im Abschnitt **Offizier mit Einladungscode?** Code und Passwort einfügen und **Einlösen** klicken.
3. Fertig - weiter mit Schritt 5 (Exportieren). Der Server ist schon ausgewählt. Das Token wird wie in Schritt 3 geschützt auf deinem PC gespeichert.

**Zugriff entziehen** (z. B. wenn ein Offizier die Gilde verlässt): Token im Developer Portal zurücksetzen (Schritt 2.6), das neue Token in Peasant einfügen und den verbleibenden Offizieren neue Codes geben. Alte Codes funktionieren danach nicht mehr.

Gut zu wissen: Wer einen Code hat, kann den Bot vollständig nutzen - die Mitgliederliste lesen und alles tun, was die Rolle `@everyone` auf eurem Server darf. Gib Codes daher nur an Personen, denen du auch das Token geben würdest.

## Datenschutz

Alle Daten bleiben auf deinem PC; das Projekt hat keinen Server und keine Telemetrie. **Du entscheidest, was mit den Daten deiner Mitglieder geschieht, und bist dafür verantwortlich** (z. B. nach der DSGVO):

- Informiere deine Mitglieder, dass ihre Discord-Namen und Rollen mit der Gildenliste abgeglichen werden - und wer Zugriff hat (z. B. welche Offiziere einen Einladungscode haben).
- Schreibe Discord-Namen bevorzugt in Offiziersnotizen - öffentliche Notizen sieht die ganze Gilde.
- Nutzt du einen Zwischenablageverlauf oder eine Synchronisierung der Zwischenablage, leere sie nach dem Import.
- Lösche die Daten, wenn du sie nicht mehr brauchst: Tab Import → **Importierte Daten löschen** (aktuelle Gilde) oder **Daten aller Gilden löschen** (auch verlassene Gilden; oder `/tgr wipe` eingeben).

Details: [privacy.md](privacy.md#deutsch).

## Probleme und Lösungen

| Problem | Lösung |
|---|---|
| „Discord akzeptiert dieses Token nicht“ | Token auf der Bot-Seite zurücksetzen und das neue einfügen. |
| „Der Bot darf die Mitgliederliste nicht lesen“ | *Server Members Intent* einschalten (Schritt 2.4) und speichern. |
| Kein Server in der Liste | Der Bot wurde noch nicht eingeladen oder auf einen anderen Server. |
| „Kein gültiger Einladungscode“ | Den ganzen Code kopieren - er beginnt mit `TGRK1-`. |
| „Falsches Passwort“ | Passwort prüfen (bei selbst festgelegten Passwörtern auf Groß-/Kleinschreibung achten) oder einen neuen Code anfordern. |
| Offizier: „Token aus deinem Einladungscode ist nicht mehr gültig“ | Der Gildenmeister hat das Token zurückgesetzt - beim Gildenmeister einen neuen Code anfordern. |
| Einfügen in WoW passiert nichts | Erst in das große Textfeld klicken. Das Programm zeigt den Text zusätzlich in einem Feld zum manuellen Kopieren. |
| Viele Mitglieder „nicht zugewiesen“ | Namensregel und Rang-Zuordnung prüfen, Twink-Ränge markieren, Zuordnungen manuell bestätigen. |
| Alles wieder entfernen | Im Addon: Tab Import → **Daten aller Gilden löschen** oder `/tgr wipe` (um auch die Einstellungen zu entfernen, bei beendetem Spiel `WTF/Account/<Account>/SavedVariables/TheGuildRegistrar.lua` löschen). Im Programm **Token entfernen** und den Konfigurationsordner löschen ([privacy.md](privacy.md#deutsch)); im Developer Portal die Anwendung löschen; den Bot vom Server werfen. |
