# Language: de
Funktionalität: Konfigurationsverwaltung
  Als System
  Möchte ich Konfiguration aus Umgebungsvariablen laden
  Damit die Anwendung korrekt parametrisiert werden kann

  Hintergrund:
    Angenommen die Umgebung ist sauber

  Szenario: Erfolgreiche Konfiguration mit allen Pflichtfeldern
    Angenommen die folgenden Umgebungsvariablen sind gesetzt:
      | Variable           | Wert                    |
      | BDA_CLIENT_ID      | test-client             |
      | BDA_DB_HOST        | localhost               |
      | BDA_DB_PASSWORD    | secret123               |
      | BDA_S3_BUCKET      | test-bucket             |
    Wenn ich die Konfiguration lade
    Dann sollte die Konfiguration erfolgreich geladen werden
    Und die Client-ID sollte "test-client" sein
    Und der Datenbankhost sollte "localhost" sein
    Und der S3 Bucket sollte "test-bucket" sein

  Szenario: Konfiguration mit Standardwerten
    Angenommen die folgenden Umgebungsvariablen sind gesetzt:
      | Variable           | Wert                    |
      | BDA_CLIENT_ID      | test-client             |
      | BDA_DB_HOST        | localhost               |
      | BDA_DB_PASSWORD    | secret123               |
      | BDA_S3_BUCKET      | test-bucket             |
    Wenn ich die Konfiguration lade
    Dann sollte der Datenbankport "5432" sein
    Und die maximalen Verbindungen sollten "4" sein
    Und die maximalen Idle-Verbindungen sollten "2" sein

  Szenario: Fehlende Pflichtfelder führen zu Validierungsfehler
    Angenommen die folgenden Umgebungsvariablen sind gesetzt:
      | Variable           | Wert                    |
      | BDA_CLIENT_ID      | test-client             |
    Wenn ich die Konfiguration lade und validiere
    Dann sollte die Validierung fehlschlagen
    Und die Fehlermeldung sollte "DB_HOST" enthalten
    Und die Fehlermeldung sollte "DB_PASSWORD" enthalten
    Und die Fehlermeldung sollte "S3_BUCKET" enthalten

  Szenario: Connection String wird korrekt generiert
    Angenommen die folgenden Umgebungsvariablen sind gesetzt:
      | Variable           | Wert                    |
      | BDA_CLIENT_ID      | test-client             |
      | BDA_DB_HOST        | db.example.com          |
      | BDA_DB_PORT        | 5433                    |
      | BDA_DB_NAME        | billing_db              |
      | BDA_DB_USER        | billing_user            |
      | BDA_DB_PASSWORD    | secret123               |
      | BDA_S3_BUCKET      | test-bucket             |
    Wenn ich die Konfiguration lade
    Und ich den Connection String generiere
    Dann sollte der Connection String "host" "db.example.com" enthalten
    Und sollte der Connection String "port" "5433" enthalten
    Und sollte der Connection String "user" "billing_user" enthalten
    Und sollte der Connection String "dbname" "billing_db" enthalten
    Und sollte der Connection String "sslmode=require" enthalten

  Szenario: Environment Detection funktioniert
    Angenommen die folgenden Umgebungsvariablen sind gesetzt:
      | Variable           | Wert                    |
      | BDA_CLIENT_ID      | test-client             |
      | BDA_DB_HOST        | localhost               |
      | BDA_DB_PASSWORD    | secret123               |
      | BDA_S3_BUCKET      | test-bucket             |
    Und die "BDA_ENVIRONMENT" Variable ist nicht gesetzt
    Wenn ich die Konfiguration lade
    Dann sollte die Environment automatisch erkannt werden
