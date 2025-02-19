-- Tabellenbeziehungen:
-- Fahrer N : M GT3
-- Rekorde 1 : 1 Strecke
-- Land 1 : N Strecke

-- Zeige mir alle Strecken in denen ich nicht im Honda NSX Evo eine Rundenzeit gesetzt habe
SELECT s.name
FROM strecke s
WHERE s.id NOT IN (
    -- Subselect
    SELECT r.strecke_id
    FROM rundenzeiten r
    WHERE r.fahrer_id = 1 AND r.gt3_id = 9
);

-- Zeige mir meine Abstände auf die Rundenrekorde in Minuten:Sekunden.Milisekunden an
CREATE VIEW `meine_abstände` AS -- View
SELECT s.name AS Strecke,
    CONCAT( -- Fügt das Ergebnis zusammen
        FLOOR( -- Berechnung der Minuten
            ABS( -- Wert immer Positiv (da ich kein Rekord gesetzt habe, macht das auch Sinn :) )
                (r.minuten * 60000 + r.sekunden * 1000 + r.millisekunden) - (ru.minuten * 60000 + ru.sekunden * 1000 + ru.millisekunden)) / 60000), -- Umwandeln der Minuten in Millisekunden
             ':', LPAD( -- Zur Formatierung der Ergebnisses: Sekunden immer zweistelling und mit führender Null, Millisekunden entsprechend dreistellig 
                    FLOOR(ABS((r.minuten * 60000 + r.sekunden * 1000 + r.millisekunden) - (ru.minuten * 60000 + ru.sekunden * 1000 + ru.millisekunden)) % 60000 / 1000), 2, '0'),
                     '.', LPAD(ABS((r.minuten * 60000 + r.sekunden * 1000 + r.millisekunden) - (ru.minuten * 60000 + ru.sekunden * 1000 + ru.millisekunden)) % 1000, 3, '0') )
                    AS Abstand 
FROM rundenzeiten ru 
JOIN rekorde r ON ru.strecke_id = r.strecke_id -- Mehrfach JOIN
JOIN strecke s ON r.strecke_id = s.id 
WHERE ru.fahrer_id = 1;
SELECT * FROM `meine_abstände`; -- Ausgabe des erstellten Views

-- Zeige mir meine Abstände prozentual zum Rundenrekord an
CREATE VIEW `meine_abstände_in_prozent` AS
SELECT s.name AS Strecke,
    ROUND( -- rundet auf zwei Dezimalstellen
        ABS( -- Berechnung des Prozentsatzes
            r.minuten * 60000 + r.sekunden * 1000 + r.millisekunden -(ru.minuten * 60000 + ru.sekunden * 1000 + ru.millisekunden)
        ) * 100.0 /
        (r.minuten * 60000 + r.sekunden * 1000 + r.millisekunden),2
    ) AS `Abstand_prozent`
FROM rundenzeiten ru
JOIN rekorde r ON ru.strecke_id = r.strecke_id
JOIN dbmodul_project.strecke s ON r.strecke_id = s.id
WHERE ru.fahrer_id = 1;
SELECT * FROM `meine_abstände_in_prozent`

-- Wer hat die meisten Rekorde?
SELECT f.name AS Name, COUNT(r.fahrer_id) AS Anzahl_Rekorde -- COUNT() Funktion
FROM rekorde r 
JOIN fahrer f ON r.fahrer_id = f.id 
GROUP BY f.id 
ORDER BY anzahl_rekorde 
DESC LIMIT 1; 

-- Welches Auto hat die meisten Rekorde?
SELECT g.fahrzeug AS GT3, COUNT(r.gt3_id) AS anzahl_rekorde
FROM gt3 g
JOIN rekorde r ON g.id = r.gt3_id
GROUP BY g.id
HAVING COUNT(r.gt3_id) = (
    SELECT MAX(rekord_anzahl) -- MAX() Funktion
    FROM (
        SELECT COUNT(r2.gt3_id) AS rekord_anzahl
        FROM rekorde r2
        GROUP BY r2.gt3_id
    ) AS subquery -- subquery
);

-- Wo ist mein Abstand am kleinsten / Pace am besten?
SELECT * FROM meine_abstände 
ORDER BY meine_abstände.Abstand ASC -- aufsteigend
Limit 1; 

-- Was sind prozentual meine drei schlechtesten Strecken?
SELECT * FROM meine_abstände_in_prozent 
ORDER BY meine_abstände_in_prozent.Abstand_prozent DESC -- absteigend
LIMIT 3; 

-- Welches Land hat die meisten Strecken?
SELECT l.name AS Land, COUNT(s.id) AS Anzahl_Rennstrecken
FROM land l
JOIN strecke s ON l.id = s.land_id
GROUP BY l.id
ORDER BY Anzahl_Rennstrecken DESC
LIMIT 1;

-- Wieviel unterschiedliche GT3 gibt es
SELECT COUNT(DISTINCT fahrzeug) AS Anzahl_GT3 -- DISTINCT
FROM gt3; 

-- Zeige alle Fahrernamen die mit "M" beginnen
SELECT name FROM fahrer WHERE name LIKE 'M%'; -- LIKE

-- TRIGGER: Wenn eine Zeit in "Rundenzeiten" geändert wird (UPDATE), die schneller als die Zeit auf der jeweiligen Strecke in "Rekorde" ist, soll diese Zeit ebenfalls in "Rekorde" eingefügt werden. 
-- "credit to CHATGPT ;)"
CREATE TRIGGER after_update_rundenzeiten
AFTER UPDATE ON rundenzeiten
FOR EACH ROW
BEGIN
    DECLARE existing_record_minutes INT;
    DECLARE existing_record_seconds INT;
    DECLARE existing_record_milliseconds INT;

    -- Überprüfen, ob ein bestehender Rekord für die gegebene Strecke existiert
    SELECT minuten, sekunden, millisekunden INTO existing_record_minutes, existing_record_seconds, existing_record_milliseconds
    FROM rekorde
    WHERE strecke_id = NEW.strecke_id
    LIMIT 1; -- Nehme den ersten gefundenen Rekord

    -- Wenn ein bestehender Rekord existiert, vergleiche die Zeiten
    IF (existing_record_minutes IS NOT NULL) THEN
        -- Überprüfen, ob die neue Rundenzeit schneller ist
        IF (NEW.minuten < existing_record_minutes) OR
           (NEW.minuten = existing_record_minutes AND NEW.sekunden < existing_record_seconds) OR
           (NEW.minuten = existing_record_minutes AND NEW.sekunden = existing_record_seconds AND NEW.millisekunden < existing_record_milliseconds) THEN

            -- Lösche den bestehenden Rekord für die gegebene Strecke
            DELETE FROM rekorde
            WHERE strecke_id = NEW.strecke_id;

            -- Füge den neuen Rekord mit der neuen Fahrer-ID und GT3-ID ein
            INSERT INTO rekorde (fahrer_id, gt3_id, strecke_id, minuten, sekunden, millisekunden)
            VALUES (NEW.fahrer_id, NEW.gt3_id, NEW.strecke_id, NEW.minuten, NEW.sekunden, NEW.millisekunden);
        END IF;
    END IF;
END;
//

DELIMITER ;
-- TEST
UPDATE rundenzeiten SET minuten = 6, sekunden = 0, millisekunden = 0 WHERE strecke_id = 17;  

-- PROZEDUR: Funktion die neue Zeiten in Rundenzeiten einfügt, diese mit Rekorden vergleicht und wenn schneller in dieser abspeichert.
-- BIIIIIIIG CREDITS to CHATGPT :)
DELIMITER //

CREATE PROCEDURE AddRundenzeit(
    IN p_fahrer_id INT,
    IN p_gt3_id INT,
    IN p_strecke_id INT,
    IN p_minuten INT,
    IN p_sekunden INT,
    IN p_millisekunden INT
)
BEGIN
    DECLARE existing_minutes INT;
    DECLARE existing_seconds INT;
    DECLARE existing_milliseconds INT;

    DECLARE rundenzeiten_minutes INT;
    DECLARE rundenzeiten_seconds INT;
    DECLARE rundenzeiten_milliseconds INT;

    -- Überprüfen, ob eine bestehende Rundenzeit für den Fahrer und GT3 existiert
    SELECT minuten, sekunden, millisekunden INTO rundenzeiten_minutes, rundenzeiten_seconds, rundenzeiten_milliseconds
    FROM rundenzeiten
    WHERE fahrer_id = p_fahrer_id AND gt3_id = p_gt3_id AND strecke_id = p_strecke_id
    LIMIT 1;

    -- Überprüfen, ob die neue Rundenzeit schneller ist als die bestehende Rundenzeit
    IF rundenzeiten_minutes IS NULL OR 
       (p_minuten < rundenzeiten_minutes) OR 
       (p_minuten = rundenzeiten_minutes AND p_sekunden < rundenzeiten_seconds) OR
       (p_minuten = rundenzeiten_minutes AND p_sekunden = rundenzeiten_seconds AND p_millisekunden < rundenzeiten_milliseconds) THEN

        -- Lösche die bestehende Rundenzeit für den gleichen Fahrer und GT3
        DELETE FROM rundenzeiten WHERE fahrer_id = p_fahrer_id AND gt3_id = p_gt3_id AND strecke_id = p_strecke_id;

        -- Füge die neue Rundenzeit in die Tabelle rundenzeiten ein
        INSERT INTO rundenzeiten (fahrer_id, gt3_id, strecke_id, minuten, sekunden, millisekunden)
        VALUES (p_fahrer_id, p_gt3_id, p_strecke_id, p_minuten, p_sekunden, p_millisekunden);

        -- Jetzt prüfen, ob die neue Zeit schneller ist als die bestehende Zeit in den Rekorden
        SELECT minuten, sekunden, millisekunden INTO existing_minutes, existing_seconds, existing_milliseconds
        FROM rekorde
        WHERE strecke_id = p_strecke_id
        ORDER BY minuten, sekunden, millisekunden
        LIMIT 1;

        -- Überprüfen, ob die neue Zeit schneller ist als der Rekord
        IF existing_minutes IS NULL OR 
           (p_minuten < existing_minutes) OR 
           (p_minuten = existing_minutes AND p_sekunden < existing_seconds) OR
           (p_minuten = existing_minutes AND p_sekunden = existing_seconds AND p_millisekunden < existing_milliseconds) THEN

            -- Lösche den bestehenden Rekord, wenn die neue Zeit schneller ist
            DELETE FROM rekorde WHERE strecke_id = p_strecke_id;

            -- Füge den neuen Rekord hinzu
            INSERT INTO rekorde (fahrer_id, gt3_id, strecke_id, minuten, sekunden, millisekunden)
            VALUES (p_fahrer_id, p_gt3_id, p_strecke_id, p_minuten, p_sekunden, p_millisekunden);
        END IF;

    ELSE
        -- Wenn die neue Zeit nicht schneller ist, gebe eine Fehlermeldung zurück
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Die neue Rundenzeit ist langsamer oder gleich der bestehenden Rundenzeit und wird nicht akzeptiert.';
    END IF;

END;
//

DELIMITER ;
CALL AddRundenzeit(1, 9, 17, 4, 59, 0); -- Test (schneller als bisher)
CALL AddRundenzeit(1, 9, 17, 9, 0, 0); -- Test (langsamer als bisher) 
CALL AddRundenzeit(1, 1, 17, 8, 40, 500); -- Test (neues Auto) 
