# Language: de
Funktionalität: SQL Script Executor
  Als System
  Möchte ich SQL Scripts aus Verzeichnissen ausführen
  Damit Datenverarbeitungsschritte automatisiert werden können

  Hintergrund:
    Angenommen eine aktive Datenbankverbindung
    Und ein Script-Verzeichnis "scripts/test"

  Szenario: Erfolgreiche Ausführung eines einzelnen Scripts
    Angenommen ein SQL Script "scripts/test/tripica.sql" mit Inhalt:
      """
      CREATE TEMP TABLE test_table (id INT, name TEXT);
      INSERT INTO test_table VALUES (1, 'Test');
      """
    Wenn ich Scripts im Verzeichnis "scripts/test" ausführe
    Dann sollte die Ausführung erfolgreich sein
    Und die Tabelle "test_table" sollte existieren
    Und sollte 1 Zeile in "test_table" vorhanden sein

  Szenario: Scripts werden alphabetisch sortiert ausgeführt
    Angenommen folgende SQL Scripts:
      | Datei           | Inhalt                        |
      | 02_insert.sql   | INSERT INTO ordered_test VALUES (2); |
      | 01_create.sql   | CREATE TEMP TABLE ordered_test (id INT); |
      | 03_update.sql   | UPDATE ordered_test SET id = 3 WHERE id = 2; |
    Wenn ich Scripts im Verzeichnis "scripts/test" ausführe
    Dann sollten die Scripts in der Reihenfolge ausgeführt werden:
      | 01_create.sql |
      | 02_insert.sql |
      | 03_update.sql |

  Szenario: Ignorierte Systeme werden übersprungen
    Angenommen die ignorierten Systeme: "bookkeeper,legacy"
    Und folgende SQL Scripts:
      | Datei              |
      | tripica.sql        |
      | bookkeeper.sql     |
      | legacy.sql         |
    Wenn ich Scripts im Verzeichnis "scripts/test" ausführe
    Dann sollte nur "tripica.sql" ausgeführt werden
    Und sollten Log-Einträge für ignorierte Systeme existieren

  Szenario: Multi-Statement Scripts werden korrekt geparst
    Angenommen ein SQL Script mit mehreren Statements:
      """
      CREATE TEMP TABLE multi_test (id INT);
      INSERT INTO multi_test VALUES (1);
      INSERT INTO multi_test VALUES (2);
      SELECT COUNT(*) FROM multi_test;
      """
    Wenn ich das Script ausführe
    Dann sollten alle Statements erfolgreich ausgeführt werden
    Und die Tabelle sollte 2 Zeilen enthalten

  Szenario: Fehlerhafte Scripts brechen die Ausführung ab
    Angenommen ein SQL Script mit Syntax-Fehler:
      """
      CREATE TEMP TABLE error_test (id INT);
      INSERT INTO non_existing_table VALUES (1);
      """
    Wenn ich das Script ausführe
    Dann sollte die Ausführung fehlschlagen
    Und die Fehlermeldung sollte "non_existing_table" enthalten

  Szenario: Leere Script-Verzeichnisse werden behandelt
    Angenommen ein leeres Verzeichnis "scripts/empty"
    Wenn ich Scripts im Verzeichnis "scripts/empty" ausführe
    Dann sollte die Ausführung erfolgreich sein
    Und keine Scripts sollten ausgeführt werden

  Szenario: Nicht-SQL Dateien werden ignoriert
    Angenommen ein Verzeichnis mit gemischten Dateien:
      | Datei           | Typ  |
      | valid.sql       | SQL  |
      | README.md       | Text |
      | config.yaml     | YAML |
    Wenn ich Scripts im Verzeichnis ausführe
    Dann sollte nur "valid.sql" ausgeführt werden
