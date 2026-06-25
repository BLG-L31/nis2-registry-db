-- =====================================================================
--  NIS2_REGISTRY  —  Query di estrazione per le sezioni del profilo ACN
-- =====================================================================

-- 1) Elenco asset critici per organizzazione (criticità >= 4)
SELECT o.denominazione, a.asset_name, a.asset_type, a.criticality_level
FROM   Assets a
JOIN   Organizzazione o ON o.org_id = a.org_id
WHERE  a.in_perimetro_nis = TRUE AND a.criticality_level >= 4
ORDER  BY o.denominazione, a.criticality_level DESC;

-- 2) Servizi erogati e asset che li supportano
SELECT s.service_name, s.sla, a.asset_name, ase.tipo_dipendenza
FROM   Services s
JOIN   Asset_Service ase ON ase.service_id = s.service_id
JOIN   Assets a          ON a.asset_id     = ase.asset_id
ORDER  BY s.service_name;

-- 3) Dipendenze da fornitori terzi, con evidenza dei contratti scaduti
SELECT sup.supplier_name, sup.paese, a.asset_name,
       d.dependency_type, d.data_fine,
       CASE WHEN d.data_fine < CURRENT_DATE THEN 'SCADUTO' ELSE 'attivo' END AS stato_contratto
FROM   Dependencies d
JOIN   Suppliers sup ON sup.supplier_id = d.supplier_id
JOIN   Assets a      ON a.asset_id      = d.asset_id
ORDER  BY stato_contratto, sup.supplier_name;

-- 4) Punti di contatto (responsabili) per ruolo
SELECT o.denominazione, r.role, r.responsible_name, r.contact_info
FROM   Responsibilities r
JOIN   Organizzazione o ON o.org_id = r.org_id
ORDER  BY o.denominazione, r.role;

-- 5) Asset critici PRIVI di misure di sicurezza (controllo di compliance)
SELECT o.denominazione, a.asset_name, a.criticality_level
FROM   Assets a
JOIN   Organizzazione o ON o.org_id = a.org_id
LEFT JOIN Security_Measures sm ON sm.asset_id = a.asset_id
WHERE  a.criticality_level >= 4 AND sm.measure_id IS NULL;

-- 6) Servizi con SLA inferiore al 99% (potenziali punti deboli)
SELECT o.denominazione, s.service_name, s.sla
FROM   Services s
JOIN   Organizzazione o ON o.org_id = s.org_id
WHERE  s.sla < 99.0
ORDER  BY s.sla ASC;

-- 7) Incidenti notificati negli ultimi 12 mesi
SELECT o.denominazione, i.descrizione, i.gravita, i.data_rilevazione, i.stato
FROM   Incidents i
JOIN   Organizzazione o ON o.org_id = i.org_id
WHERE  i.data_rilevazione >= NOW() - INTERVAL '12 months'
ORDER  BY i.data_rilevazione DESC;

-- =====================================================================
--  ESPORTAZIONE DEL PROFILO ACN IN CSV
-- =====================================================================
-- Da eseguire dal client psql. \COPY scrive un file sul disco LOCALE.
-- Sostituire il codice fiscale con quello dell'organizzazione desiderata.

\COPY (SELECT * FROM ACN_EXPORT_VIEW WHERE cf_organizzazione = '01234567890') \
  TO 'profilo_acn_energiaitalia.csv' \
  WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');

-- Per esportare TUTTE le organizzazioni in un unico file:
-- \COPY (SELECT * FROM ACN_EXPORT_VIEW) TO 'profilo_acn_completo.csv'
--   WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');
