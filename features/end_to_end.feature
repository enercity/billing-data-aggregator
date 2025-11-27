# Language: de
Funktionalität: End-to-End Datenverarbeitung
  Als System
  Möchte ich den kompletten Datenverarbeitungs-Workflow ausführen
  Damit Billing-Daten aggregiert und exportiert werden

  Hintergrund:
    Angenommen eine vollständige Systemkonfiguration
    Und eine Octopus DWH Datenbank mit Testdaten
    Und ein S3 Bucket für Exports

  Szenario: Erfolgreicher Komplett-Workflow für Tripica
    Angenommen das System "tripica" ist konfiguriert
    Und Rohdaten für Tripica existieren in der Datenbank
    Wenn ich den Aggregator starte
    Dann sollten folgende Schritte erfolgreich ausgeführt werden:
      | Schritt                    |
      | Init Scripts ausführen     |
      | Tripica Processor läuft    |
      | CSV Export erstellen       |
      | S3 Upload durchführen      |
      | Archive Scripts ausführen  |
    Und die CSV-Dateien sollten in S3 existieren
    Und die temporären Tabellen sollten aufgeräumt sein

  Szenario: Multi-System Verarbeitung (Tripica + Bookkeeper)
    Angenommen die Systeme "tripica,bookkeeper" sind konfiguriert
    Wenn ich den Aggregator starte
    Dann sollten beide Systeme verarbeitet werden
    Und für jedes System sollten CSV-Dateien existieren:
      | System     | Dateien                        |
      | tripica    | tripica_results_*.csv          |
      | bookkeeper | bookkeeper_results_*.csv       |

  Szenario: Fehler in einem System stoppt die Verarbeitung
    Angenommen das System "tripica" ist konfiguriert
    Aber ein Fehler tritt im Init Script auf
    Wenn ich den Aggregator starte
    Dann sollte die Verarbeitung fehlschlagen
    Und kein CSV Export sollte durchgeführt werden
    Und kein S3 Upload sollte stattfinden
    Und die Fehlermeldung sollte "Initialization failed" enthalten

  Szenario: Ignorierte Systeme werden übersprungen
    Angenommen die konfigurierten Systeme sind "tripica,bookkeeper,legacy"
    Aber "legacy" ist in den ignorierten Systemen
    Wenn ich den Aggregator starte
    Dann sollten nur Tripica und Bookkeeper verarbeitet werden
    Und keine Dateien für "legacy" sollten erstellt werden

  Szenario: Performance bei großen Datenmengen
    Angenommen 5 Millionen Zeilen in der Tripica Source-Tabelle
    Wenn ich den Aggregator starte
    Dann sollte die Verarbeitung innerhalb von 10 Minuten abgeschlossen sein
    Und die CSV-Dateien sollten korrekt gechunkt sein (max 1M Zeilen pro Datei)
    Und alle Daten sollten exportiert sein

  Szenario: Transaktionale Konsistenz bei Fehlern
    Angenommen eine Datenbankverbindung die während der Verarbeitung abbricht
    Wenn ich den Aggregator starte
    Dann sollte die Verarbeitung fehlschlagen
    Und bereits gestartete Transaktionen sollten zurückgerollt werden
    Und keine inkonsistenten Daten sollten exportiert werden

  Szenario: Monitoring und Logging
    Angenommen eine erfolgreiche Verarbeitung
    Wenn ich die Logs analysiere
    Dann sollten folgende Metriken protokolliert sein:
      | Metrik                      | Vorhanden |
      | Verarbeitungsdauer          | Ja        |
      | Anzahl verarbeiteter Zeilen | Ja        |
      | Anzahl generierter Dateien  | Ja        |
      | S3 Upload Größe             | Ja        |
    Und alle Logs sollten im JSON-Format vorliegen
    Und kritische Fehler sollten ERROR-Level haben

  Szenario: Wiederholbarkeit und Idempotenz
    Angenommen eine erfolgreiche Verarbeitung wurde durchgeführt
    Wenn ich den Aggregator erneut mit denselben Daten starte
    Dann sollte die Verarbeitung erfolgreich sein
    Und die Ergebnisse sollten identisch sein
    Und neue S3-Dateien sollten die alten überschreiben

  Szenario: Cleanup nach erfolgreicher Verarbeitung
    Angenommen eine erfolgreiche Verarbeitung
    Wenn die Archive Scripts ausgeführt wurden
    Dann sollten temporäre Tabellen gelöscht sein
    Und intermediate Tabellen sollten bereinigt sein
    Und nur die finalen Result-Tabellen sollten existieren
