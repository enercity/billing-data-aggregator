# Language: de
Funktionalität: CSV Export
  Als System
  Möchte ich Tabellen als CSV exportieren
  Damit Daten für externe Systeme bereitgestellt werden können

  Hintergrund:
    Angenommen eine aktive Datenbankverbindung
    Und ein Output-Verzeichnis "/tmp/test-export"

  Szenario: Export einer kleinen Tabelle
    Angenommen eine Tabelle "test_results" mit 100 Zeilen
    Wenn ich die Tabelle als CSV exportiere
    Dann sollte 1 CSV-Datei erstellt werden
    Und die Datei sollte 101 Zeilen enthalten (Header + Daten)
    Und die Datei sollte im Format "system_test_results_0000.csv" benannt sein

  Szenario: Große Tabellen werden in Chunks aufgeteilt
    Angenommen eine Tabelle "large_results" mit 2.500.000 Zeilen
    Und eine maximale Chunk-Größe von 1.000.000 Zeilen
    Wenn ich die Tabelle als CSV exportiere
    Dann sollten 3 CSV-Dateien erstellt werden:
      | Datei                          | Zeilen (inkl. Header) |
      | system_large_results_0000.csv  | 1000001               |
      | system_large_results_0001.csv  | 1000001               |
      | system_large_results_0002.csv  | 500001                |

  Szenario: CSV Header enthält alle Spaltennamen
    Angenommen eine Tabelle mit Spalten:
      | Spaltenname   | Typ       |
      | id            | INTEGER   |
      | customer_id   | INTEGER   |
      | amount        | NUMERIC   |
      | created_at    | TIMESTAMP |
    Wenn ich die Tabelle als CSV exportiere
    Dann sollte die erste Zeile die Header enthalten:
      | id | customer_id | amount | created_at |

  Szenario: NULL-Werte werden als leere Strings exportiert
    Angenommen eine Tabelle mit NULL-Werten:
      | id | name  | email      |
      | 1  | Alice | alice@test |
      | 2  | Bob   | NULL       |
      | 3  | NULL  | NULL       |
    Wenn ich die Tabelle als CSV exportiere
    Dann sollte die CSV-Datei enthalten:
      """
      id,name,email
      1,Alice,alice@test
      2,Bob,
      3,,
      """

  Szenario: Spezialzeichen werden korrekt escaped
    Angenommen eine Tabelle mit Spezialzeichen:
      | id | description           |
      | 1  | Text with "quotes"    |
      | 2  | Text with, comma      |
      | 3  | Text with\nnewline    |
    Wenn ich die Tabelle als CSV exportiere
    Dann sollten die Werte korrekt escaped sein

  Szenario: Export protokolliert Fortschritt
    Angenommen eine Tabelle "progress_test" mit 100.000 Zeilen
    Wenn ich die Tabelle als CSV exportiere
    Dann sollte ein Log-Eintrag "Starting CSV export" existieren
    Und sollte ein Log-Eintrag "Export completed" mit Dateianzahl existieren
    Und sollte die Zeilenanzahl protokolliert sein

  Szenario: Output-Verzeichnis wird automatisch erstellt
    Angenommen das Verzeichnis "/tmp/auto-created" existiert nicht
    Wenn ich CSV-Export mit diesem Verzeichnis starte
    Dann sollte das Verzeichnis automatisch erstellt werden
    Und sollte die Berechtigung "0750" haben

  Szenario: Fehlerhafte Queries führen zu aussagekräftigen Fehlern
    Angenommen eine nicht existierende Tabelle "non_existing"
    Wenn ich versuche die Tabelle zu exportieren
    Dann sollte der Export fehlschlagen
    Und die Fehlermeldung sollte "non_existing" enthalten
    Und keine CSV-Datei sollte erstellt werden
