# Einrichtungsanleitung

*English version: [setup-guide.md](setup-guide.md)*

Die einmalige Einrichtung dauert etwa 10 Minuten. Du brauchst:

- das Addon **The Guild Registrar** (CurseForge),
- einen PC mit Windows, macOS oder Linux,
- auf eurem Discord-Server das Recht **Server verwalten** - oder jemanden, der es hat und einmal einen Link für dich öffnet.

## 1. Begleitprogramm herunterladen und starten

1. Öffne das [aktuelle Release](https://github.com/Flotomat/TheGuildRegistrar/releases/latest) und lade die Datei für dein System herunter:
   - Windows: `TheGuildRegistrar-Companion-windows-x64.zip`
   - Mac mit Apple-Chip (M1 und neuer): `TheGuildRegistrar-Companion-macos-apple-silicon.zip`
   - Mac mit Intel-Chip: `TheGuildRegistrar-Companion-macos-intel.zip`
   - Linux: `TheGuildRegistrar-Companion-linux-x64.tar.gz`
2. In einen beliebigen Ordner entpacken und `TheGuildRegistrar-Companion` starten.
3. **Sicherheitswarnung:** Das Programm ist nicht mit einem kostenpflichtigen Zertifikat signiert, deshalb warnt dein System beim ersten Start.
   - **Windows SmartScreen** („Der Computer wurde durch Windows geschützt“): **Weitere Informationen** → **Trotzdem ausführen**.
   - **macOS** („kann nicht geöffnet werden, da der Entwickler nicht verifiziert werden kann“): Rechtsklick auf die Datei → **Öffnen** → **Öffnen**. Alternativ im Terminal: `xattr -d com.apple.quarantine TheGuildRegistrar-Companion`.
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
2. Das Programm prüft das Token bei Discord und speichert es verschlüsselt auf deinem PC.
3. Meldet es, dass *Server Members Intent* aus ist: zurück zu Schritt 2.4, speichern und die Seite neu laden.

## 4. Bot auf den Server einladen

1. Im Programm auf **Einladungslink öffnen** klicken.
2. Server auswählen und **Autorisieren** klicken. Der Bot verlangt **keine Rechte** - er sieht nur, was jedes Mitglied in der Mitgliederliste sieht.
3. Hast du das Recht *Server verwalten* nicht, schick den Link an jemanden, der es hat.
4. **Eingeladen - Server neu laden** klicken.

## 5. Exportieren und importieren

1. Server auswählen und **In die Zwischenablage exportieren** klicken.
2. In WoW `/tgr` eingeben, den Tab **Import** öffnen, ins Textfeld klicken, **Strg+V** (Mac: **Cmd+V**) drücken und **Importieren** klicken.
3. Der Tab **Abgleich** zeigt das Ergebnis.

Später aktualisieren: Programm starten → **In die Zwischenablage exportieren** → im Spiel einfügen. Die Schritte 2-4 sind nicht mehr nötig.

## 6. Addon einstellen

- **Tab Ränge**: jede Discord-Rolle dem passenden Gildenrang zuordnen, Gast-Rollen (z. B. *Gast*, *Austauschschüler*) und Twink-Ränge markieren.
- **Tab Einstellungen**: Namensregel (z. B. `Spitzname | Main`), verwendete Notizen, Twink-Muster, ignorierte Wörter, Schwellwerte.
- Im Tab **Abgleich** per Rechtsklick Zuordnungen bestätigen, ablehnen oder ändern, Spieler anflüstern oder Gildennotizen schreiben.

## Probleme und Lösungen

| Problem | Lösung |
|---|---|
| „Discord akzeptiert dieses Token nicht“ | Token auf der Bot-Seite zurücksetzen und das neue einfügen. |
| „Der Bot darf die Mitgliederliste nicht lesen“ | *Server Members Intent* einschalten (Schritt 2.4) und speichern. |
| Kein Server in der Liste | Der Bot wurde noch nicht eingeladen oder auf einen anderen Server. |
| Einfügen in WoW passiert nichts | Erst in das große Textfeld klicken. Das Programm zeigt den Text zusätzlich in einem Feld zum manuellen Kopieren. |
| Viele Mitglieder „nicht zugewiesen“ | Namensregel und Rang-Zuordnung prüfen, Twink-Ränge markieren, Zuordnungen manuell bestätigen. |
| Alles wieder entfernen | Im Programm **Token entfernen**, im Developer Portal die Anwendung löschen, den Bot vom Server werfen. |
