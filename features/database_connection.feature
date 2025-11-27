# Language: de
Funktionalität: Datenbankverbindung
  Als System
  Möchte ich eine robuste Datenbankverbindung aufbauen
  Damit Daten sicher verarbeitet werden können

  Hintergrund:
    Angenommen eine gültige Konfiguration existiert

  Szenario: Erfolgreiche Datenbankverbindung
    Angenommen ein laufender PostgreSQL Server auf "localhost:5432"
    Und gültige Datenbank-Credentials
    Wenn ich eine Datenbankverbindung aufbaue
    Dann sollte die Verbindung erfolgreich sein
    Und ein Ping sollte erfolgreich sein

  Szenario: Verbindung mit Connection Pool Konfiguration
    Angenommen ein laufender PostgreSQL Server
    Und maximale Verbindungen von "8"
    Und maximale Idle-Verbindungen von "4"
    Wenn ich eine Datenbankverbindung aufbaue
    Dann sollte der Connection Pool "8" maximale Verbindungen haben
    Und sollte der Connection Pool "4" maximale Idle-Verbindungen haben

  Szenario: Retry-Mechanismus bei temporären Verbindungsproblemen
    Angenommen ein PostgreSQL Server der beim ersten Versuch fehlschlägt
    Aber beim zweiten Versuch erfolgreich ist
    Wenn ich eine Datenbankverbindung aufbaue
    Dann sollte die Verbindung nach einem Retry erfolgreich sein
    Und es sollte ein Retry-Log-Eintrag existieren

  Szenario: Verbindung schlägt nach maximalen Retries fehl
    Angenommen ein nicht erreichbarer PostgreSQL Server
    Wenn ich eine Datenbankverbindung aufbaue
    Dann sollte die Verbindung fehlschlagen
    Und die Fehlermeldung sollte "failed to connect after" enthalten
    Und es sollten 5 Retry-Versuche protokolliert sein

  Szenario: Connection Close bereinigt Ressourcen
    Angenommen eine aktive Datenbankverbindung
    Wenn ich die Verbindung schließe
    Dann sollte die Verbindung geschlossen sein
    Und keine offenen Verbindungen sollten existieren
