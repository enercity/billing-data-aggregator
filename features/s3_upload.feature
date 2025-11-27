# Language: de
Funktionalität: S3 Upload
  Als System
  Möchte ich CSV-Dateien zu S3 hochladen
  Damit Daten für externe Systeme verfügbar sind

  Hintergrund:
    Angenommen eine S3 Bucket "test-bucket" existiert
    Und eine gültige AWS Konfiguration

  Szenario: Erfolgreicher Upload einer einzelnen Datei
    Angenommen eine lokale Datei "/tmp/export/test_results_0000.csv"
    Und ein S3 Prefix "client/prod/2025-11-27"
    Wenn ich die Datei zu S3 hochlade
    Dann sollte der Upload erfolgreich sein
    Und die Datei sollte unter "client/prod/2025-11-27/test_results_0000.csv" existieren

  Szenario: Upload mehrerer Dateien
    Angenommen folgende lokale Dateien:
      | Datei                     |
      | tripica_results_0000.csv  |
      | tripica_results_0001.csv  |
      | bookkeeper_results_0000.csv |
    Wenn ich alle Dateien zu S3 hochlade
    Dann sollten 3 Dateien erfolgreich hochgeladen werden
    Und jede Datei sollte im S3 Bucket existieren

  Szenario: Retry-Mechanismus bei temporären Netzwerkfehlern
    Angenommen ein S3 Service der beim ersten Versuch einen Netzwerkfehler zurückgibt
    Aber beim zweiten Versuch erfolgreich ist
    Wenn ich eine Datei hochlade
    Dann sollte der Upload nach einem Retry erfolgreich sein
    Und es sollte ein Warn-Log mit "Retrying upload" existieren

  Szenario: Exponential Backoff bei Retries
    Angenommen ein S3 Service der mehrfach fehlschlägt
    Wenn ich eine Datei hochlade
    Dann sollten die Retry-Delays exponentiell steigen:
      | Versuch | Delay     |
      | 1       | 0s        |
      | 2       | 2s        |
      | 3       | 4s        |

  Szenario: Upload schlägt nach maximalen Retries fehl
    Angenommen ein S3 Service der immer fehlschlägt
    Wenn ich eine Datei hochlade
    Dann sollte der Upload nach 3 Versuchen fehlschlagen
    Und die Fehlermeldung sollte "failed to upload after 3 attempts" enthalten

  Szenario: Große Dateien werden erfolgreich hochgeladen
    Angenommen eine Datei mit 500 MB Größe
    Wenn ich die Datei zu S3 hochlade
    Dann sollte der Upload erfolgreich sein
    Und die Dateigröße in S3 sollte 500 MB sein

  Szenario: Upload protokolliert Fortschritt
    Angenommen mehrere Dateien zum Upload
    Wenn ich den Upload starte
    Dann sollte für jede Datei ein Log-Eintrag "Uploading to S3" existieren
    Und sollte für jede Datei ein Log-Eintrag "File uploaded to S3" existieren
    Und sollte der S3 Key protokolliert sein

  Szenario: Fehlerhafte Dateipfade werden behandelt
    Angenommen ein nicht existierender Dateipfad "/tmp/non-existing.csv"
    Wenn ich versuche die Datei hochzuladen
    Dann sollte der Upload fehlschlagen
    Und die Fehlermeldung sollte "failed to open file" enthalten

  Szenario: AWS Credentials werden korrekt verwendet
    Angenommen IAM Role Credentials (IRSA)
    Wenn ich eine Datei zu S3 hochlade
    Dann sollten keine statischen Access Keys verwendet werden
    Und die Authentifizierung sollte über STS erfolgen

  Szenario: S3 Bucket Permissions werden validiert
    Angenommen ein S3 Bucket ohne Write-Berechtigung
    Wenn ich versuche eine Datei hochzuladen
    Dann sollte der Upload fehlschlagen
    Und die Fehlermeldung sollte "AccessDenied" enthalten
