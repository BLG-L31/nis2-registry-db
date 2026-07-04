-- =====================================================================
--  NIS2_REGISTRY  —  Dataset simulato di test
--  Tre organizzazioni fittizie (energia, trasporti, servizi digitali)
--  Esecuzione (dopo lo schema):
--    psql -U nis2_user -d nis2_registry -f 02_dati_test.sql
-- =====================================================================

-- ---- ORGANIZZAZIONI --------------------------------------------------
INSERT INTO Organizzazione (codice_fiscale, denominazione, settore_nis, categoria, data_registrazione_acn) VALUES
('01234567890', 'EnergiaItalia S.p.A.',    'Energia',          'essenziale', '2024-10-01'),
('09876543210', 'TrasportiVeloci S.r.l.',  'Trasporti',        'essenziale', '2024-11-15'),
('05551112223', 'CloudServizi S.p.A.',     'Servizi digitali', 'importante', '2025-01-20');

-- ---- ASSET (org 1 = EnergiaItalia) -----------------------------------
INSERT INTO Assets (org_id, asset_name, asset_type, criticality_level,
                    impatto_riservatezza, impatto_integrita, impatto_disponibilita, ip_address) VALUES
(1, 'Server ERP',         'Hardware', 5, 'medio', 'alto', 'alto',  '10.0.1.10'),
(1, 'Database Clienti',   'Database', 5, 'alto',  'alto', 'alto',  '10.0.1.20'),
(1, 'SCADA Centrale',     'OT',       5, 'medio', 'alto', 'alto',  '10.0.2.5'),
(1, 'Portale Web',        'Software', 3, 'basso', 'medio','medio', '10.0.1.30'),
(1, 'Postazioni Lavoro',  'Hardware', 2, 'basso', 'basso','basso', NULL);

-- ---- ASSET (org 2 = TrasportiVeloci) ---------------------------------
INSERT INTO Assets (org_id, asset_name, asset_type, criticality_level,
                    impatto_riservatezza, impatto_integrita, impatto_disponibilita) VALUES
(2, 'Sistema Biglietteria', 'Software', 4, 'medio', 'alto', 'alto'),
(2, 'Database Tratte',      'Database', 4, 'medio', 'alto', 'medio');

-- ---- ASSET (org 3 = CloudServizi) ------------------------------------
INSERT INTO Assets (org_id, asset_name, asset_type, criticality_level,
                    impatto_riservatezza, impatto_integrita, impatto_disponibilita) VALUES
(3, 'Cluster Kubernetes', 'Infrastruttura', 5, 'alto', 'alto', 'alto'),
(3, 'API Gateway',        'Software',       4, 'medio','alto', 'alto');

-- ---- SERVIZI ---------------------------------------------------------
INSERT INTO Services (org_id, service_name, description, sla, rto_ore, rpo_ore) VALUES
(1, 'Gestione Ordini',     'Servizio ERP interno',          99.90, 4, 1),
(1, 'Distribuzione Energia','Erogazione rete elettrica',    99.99, 2, 1),
(2, 'Vendita Biglietti',   'Biglietteria online',           99.50, 6, 2),
(3, 'Hosting Applicativo', 'PaaS per clienti terzi',        98.50, 8, 4);

-- ---- GIUNZIONE ASSET <-> SERVIZI -------------------------------------
INSERT INTO Asset_Service (asset_id, service_id, tipo_dipendenza, criticita_dip) VALUES
(1, 1, 'hosting',        5),
(2, 1, 'dati',           5),
(3, 2, 'controllo_rete', 5),
(6, 3, 'hosting',        4),
(8, 4, 'hosting',        5),
(9, 4, 'rete',           4);

-- ---- FORNITORI -------------------------------------------------------
INSERT INTO Suppliers (org_id, supplier_name, criticality_level, contact_info, paese, soggetto_nis2) VALUES
(1, 'CloudProvider S.r.l.', 5, 'info@cloudprovider.it', 'IT', TRUE),
(1, 'HWVendor GmbH',        4, 'sales@hwvendor.de',     'DE', FALSE),
(2, 'TicketTech S.p.A.',    4, 'support@tickettech.it', 'IT', FALSE),
(3, 'DataCenter EU',        5, 'noc@datacenter.eu',     'IE', TRUE);

-- ---- DIPENDENZE ASSET <-> FORNITORI ----------------------------------
INSERT INTO Dependencies (asset_id, supplier_id, dependency_type, data_inizio, data_fine) VALUES
(1, 2, 'Hardware Supply',     '2023-01-01', '2026-12-31'),
(2, 1, 'Cloud Infrastructure','2024-01-01', '2027-01-01'),
(6, 3, 'Software Maintenance','2024-06-01', '2025-05-31'),  -- contratto scaduto (caso limite)
(8, 4, 'Cloud Infrastructure','2025-02-01', NULL);          -- a tempo indeterminato

-- ---- RESPONSABILI ----------------------------------------------------
INSERT INTO Responsibilities (org_id, asset_id, responsible_name, role, contact_info) VALUES
(1, 1,    'Mario Rossi',    'IT Manager', 'mario.rossi@energiaitalia.it'),
(1, 2,    'Luca Bianchi',   'DPO',        'luca.bianchi@energiaitalia.it'),
(1, NULL, 'Anna Verdi',     'CISO',       'anna.verdi@energiaitalia.it'),   -- ruolo trasversale
(2, 6,    'Paolo Neri',     'IT Manager', 'paolo.neri@trasportiveloci.it'),
(3, 8,    'Sara Gialli',    'CISO',       'sara.gialli@cloudservizi.it');

-- ---- MISURE DI SICUREZZA ---------------------------------------------
INSERT INTO Security_Measures (asset_id, nome_misura, area_nis, stato_attuazione, data_attuazione) VALUES
(2, 'Cifratura dati a riposo',      'Crittografia',          'attuata',   '2024-09-01'),
(3, 'Segmentazione rete OT/IT',     'Sicurezza delle reti',  'in_corso',  NULL),
(1, 'Backup giornaliero',           'Continuità operativa',  'attuata',   '2024-08-15');
-- (l'asset 4 "Portale Web" resta volutamente privo di misure: caso limite per i test)

-- ---- INCIDENTI -------------------------------------------------------
INSERT INTO Incidents (org_id, asset_id, descrizione, gravita, data_rilevazione, data_notifica_acn, stato) VALUES
(1, 4, 'Tentativo di accesso non autorizzato al portale web', 3, '2026-03-10 08:30+01', '2026-03-10 14:00+01', 'chiuso'),
(2, 6, 'Indisponibilità temporanea biglietteria',            2, '2026-04-02 19:15+02', NULL,                  'in_gestione');
