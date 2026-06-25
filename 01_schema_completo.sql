-- =====================================================================
--  NIS2_REGISTRY  —  Schema relazionale completo
--  Project Work L-31 "Sicurezza e compliance NIS2"
--  RDBMS di riferimento: PostgreSQL 16
--
--  Contenuto:
--    - 12 tabelle (5 aree funzionali) in Terza Forma Normale (3NF)
--    - vincoli PK / FK / CHECK / UNIQUE / NOT NULL
--    - indici (compresi indici parziali sul perimetro NIS2)
--    - 3 tabelle di storico + 3 trigger (pattern SCD Type 2)
--    - vista di esportazione ACN_EXPORT_VIEW
--
--  Esecuzione:
--    psql -U nis2_user -d nis2_registry -f 01_schema_completo.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- AREA 1 — ORGANIZZAZIONE
-- ---------------------------------------------------------------------

CREATE TABLE Organizzazione (
    org_id                 SERIAL PRIMARY KEY,
    codice_fiscale         VARCHAR(16)  UNIQUE NOT NULL,
    denominazione          VARCHAR(255) NOT NULL,
    settore_nis            VARCHAR(100) NOT NULL,
    categoria              VARCHAR(20)  NOT NULL
                           CHECK (categoria IN ('essenziale', 'importante')),
    data_registrazione_acn DATE         NOT NULL,
    created_at             TIMESTAMPTZ  DEFAULT NOW()
);
COMMENT ON TABLE  Organizzazione IS 'Soggetti NIS2 registrati presso l''ACN (tabella radice del registro)';
COMMENT ON COLUMN Organizzazione.categoria IS 'Classificazione ACN: essenziale o importante';

-- ---------------------------------------------------------------------
-- AREA 2 — ASSET
-- ---------------------------------------------------------------------

CREATE TABLE Assets (
    asset_id               SERIAL PRIMARY KEY,
    org_id                 INTEGER NOT NULL
                           REFERENCES Organizzazione(org_id)
                           ON DELETE CASCADE ON UPDATE RESTRICT,
    asset_name             VARCHAR(100) NOT NULL,
    asset_type             VARCHAR(50)  NOT NULL,
    criticality_level      SMALLINT     NOT NULL
                           CHECK (criticality_level BETWEEN 1 AND 5),
    impatto_riservatezza   VARCHAR(10)
                           CHECK (impatto_riservatezza IN ('alto','medio','basso')),
    impatto_integrita      VARCHAR(10)
                           CHECK (impatto_integrita IN ('alto','medio','basso')),
    impatto_disponibilita  VARCHAR(10)
                           CHECK (impatto_disponibilita IN ('alto','medio','basso')),
    ip_address             INET,
    stato                  VARCHAR(20) NOT NULL DEFAULT 'attivo'
                           CHECK (stato IN ('attivo','dismesso','sospeso')),
    in_perimetro_nis       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at             TIMESTAMPTZ DEFAULT NOW(),
    updated_at             TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE  Assets IS 'Catalogo degli asset (hardware, software, dati, infrastrutture) rilevanti ai fini NIS2';
COMMENT ON COLUMN Assets.criticality_level IS 'Criticità da 1 (bassa) a 5 (critica), scala ACN';

-- ---------------------------------------------------------------------
-- AREA 3 — SERVIZI
-- ---------------------------------------------------------------------

CREATE TABLE Services (
    service_id   SERIAL PRIMARY KEY,
    org_id       INTEGER NOT NULL
                 REFERENCES Organizzazione(org_id)
                 ON DELETE CASCADE ON UPDATE RESTRICT,
    service_name VARCHAR(100) NOT NULL,
    description  TEXT,
    sla          NUMERIC(5,2) CHECK (sla BETWEEN 0 AND 100),
    rto_ore      INTEGER      CHECK (rto_ore > 0),
    rpo_ore      INTEGER      CHECK (rpo_ore > 0),
    stato        VARCHAR(20)  NOT NULL DEFAULT 'attivo'
                 CHECK (stato IN ('attivo','dismesso','sospeso')),
    created_at   TIMESTAMPTZ  DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  DEFAULT NOW()
);
COMMENT ON TABLE  Services IS 'Servizi erogati dall''organizzazione';
COMMENT ON COLUMN Services.sla IS 'SLA di disponibilità garantita, in percentuale (es. 99.9)';
COMMENT ON COLUMN Services.rto_ore IS 'Recovery Time Objective in ore';
COMMENT ON COLUMN Services.rpo_ore IS 'Recovery Point Objective in ore';

-- Tabella di giunzione ASSET <-> SERVICE (relazione molti-a-molti con attributi)
CREATE TABLE Asset_Service (
    asset_id        INTEGER NOT NULL
                    REFERENCES Assets(asset_id)   ON DELETE CASCADE,
    service_id      INTEGER NOT NULL
                    REFERENCES Services(service_id) ON DELETE CASCADE,
    tipo_dipendenza VARCHAR(50) NOT NULL,
    criticita_dip   SMALLINT CHECK (criticita_dip BETWEEN 1 AND 5),
    PRIMARY KEY (asset_id, service_id)
);
COMMENT ON TABLE Asset_Service IS 'Quali asset supportano quali servizi (relazione N:M)';

-- ---------------------------------------------------------------------
-- AREA 4 — FORNITORI
-- ---------------------------------------------------------------------

CREATE TABLE Suppliers (
    supplier_id       SERIAL PRIMARY KEY,
    org_id            INTEGER NOT NULL
                      REFERENCES Organizzazione(org_id)
                      ON DELETE CASCADE ON UPDATE RESTRICT,
    supplier_name     VARCHAR(100) NOT NULL,
    criticality_level SMALLINT NOT NULL
                      CHECK (criticality_level BETWEEN 1 AND 5),
    contact_info      TEXT,
    paese             CHAR(2),
    soggetto_nis2     BOOLEAN DEFAULT FALSE,
    created_at        TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE  Suppliers IS 'Fornitori terzi rilevanti per la supply chain del soggetto NIS2';
COMMENT ON COLUMN Suppliers.paese IS 'Codice ISO 3166-1 alpha-2 (IT, DE, US, ...)';

-- Dipendenze ASSET <-> FORNITORE (con durata contrattuale)
CREATE TABLE Dependencies (
    dependency_id   SERIAL PRIMARY KEY,
    asset_id        INTEGER NOT NULL
                    REFERENCES Assets(asset_id)    ON DELETE CASCADE,
    supplier_id     INTEGER NOT NULL
                    REFERENCES Suppliers(supplier_id) ON DELETE CASCADE,
    dependency_type VARCHAR(50) NOT NULL,
    data_inizio     DATE,
    data_fine       DATE,
    CHECK (data_fine IS NULL OR data_fine >= data_inizio)
);
COMMENT ON TABLE Dependencies IS 'Dipendenze degli asset da fornitori terzi (con periodo contrattuale)';

-- ---------------------------------------------------------------------
-- AREA 5 — GOVERNANCE (responsabili, misure, incidenti)
-- ---------------------------------------------------------------------

CREATE TABLE Responsibilities (
    responsible_id   SERIAL PRIMARY KEY,
    org_id           INTEGER NOT NULL
                     REFERENCES Organizzazione(org_id)
                     ON DELETE CASCADE ON UPDATE RESTRICT,
    asset_id         INTEGER
                     REFERENCES Assets(asset_id) ON DELETE SET NULL,
    responsible_name VARCHAR(100) NOT NULL,
    role             VARCHAR(50)  NOT NULL,
    contact_info     VARCHAR(255),
    created_at       TIMESTAMPTZ  DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  DEFAULT NOW()
);
COMMENT ON TABLE  Responsibilities IS 'Responsabili e punti di contatto; asset_id NULL per ruoli trasversali';
COMMENT ON COLUMN Responsibilities.role IS 'Ruolo organizzativo (CISO, DPO, IT Manager, ...)';

CREATE TABLE Security_Measures (
    measure_id    SERIAL PRIMARY KEY,
    asset_id      INTEGER NOT NULL
                  REFERENCES Assets(asset_id) ON DELETE CASCADE,
    nome_misura   VARCHAR(150) NOT NULL,
    area_nis      VARCHAR(100),   -- una delle 10 aree di misure minime NIS2
    stato_attuazione VARCHAR(20) NOT NULL DEFAULT 'pianificata'
                  CHECK (stato_attuazione IN ('pianificata','in_corso','attuata')),
    data_attuazione DATE,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE Security_Measures IS 'Misure di sicurezza adottate o pianificate, collegate agli asset';

CREATE TABLE Incidents (
    incident_id   SERIAL PRIMARY KEY,
    org_id        INTEGER NOT NULL
                  REFERENCES Organizzazione(org_id) ON DELETE CASCADE,
    asset_id      INTEGER
                  REFERENCES Assets(asset_id) ON DELETE SET NULL,
    descrizione   TEXT NOT NULL,
    gravita       SMALLINT CHECK (gravita BETWEEN 1 AND 5),
    data_rilevazione TIMESTAMPTZ NOT NULL,
    data_notifica_acn TIMESTAMPTZ,
    stato         VARCHAR(20) NOT NULL DEFAULT 'aperto'
                  CHECK (stato IN ('aperto','in_gestione','chiuso')),
    CHECK (data_notifica_acn IS NULL OR data_notifica_acn >= data_rilevazione)
);
COMMENT ON TABLE Incidents IS 'Registro degli incidenti significativi e relativa notifica all''ACN';

-- ---------------------------------------------------------------------
-- TABELLE DI STORICO (pattern SCD Type 2)
-- ---------------------------------------------------------------------

CREATE TABLE Assets_History (
    history_id            SERIAL PRIMARY KEY,
    asset_id              INTEGER,
    org_id                INTEGER,
    asset_name            VARCHAR(100),
    asset_type            VARCHAR(50),
    criticality_level     SMALLINT,
    impatto_riservatezza  VARCHAR(10),
    impatto_integrita     VARCHAR(10),
    impatto_disponibilita VARCHAR(10),
    stato                 VARCHAR(20),
    in_perimetro_nis      BOOLEAN,
    archived_at           TIMESTAMPTZ DEFAULT NOW(),
    operation             CHAR(1),  -- 'U' = Update, 'D' = Delete
    modified_by           VARCHAR(100) DEFAULT CURRENT_USER  -- utente DB che ha eseguito la modifica
);

CREATE TABLE Services_History (
    history_id   SERIAL PRIMARY KEY,
    service_id   INTEGER,
    org_id       INTEGER,
    service_name VARCHAR(100),
    sla          NUMERIC(5,2),
    stato        VARCHAR(20),
    archived_at  TIMESTAMPTZ DEFAULT NOW(),
    operation    CHAR(1),
    modified_by  VARCHAR(100) DEFAULT CURRENT_USER  -- utente DB che ha eseguito la modifica
);

CREATE TABLE Responsibilities_History (
    history_id       SERIAL PRIMARY KEY,
    responsible_id   INTEGER,
    org_id           INTEGER,
    asset_id         INTEGER,
    responsible_name VARCHAR(100),
    role             VARCHAR(50),
    archived_at      TIMESTAMPTZ DEFAULT NOW(),
    operation        CHAR(1),
    modified_by      VARCHAR(100) DEFAULT CURRENT_USER  -- utente DB che ha eseguito la modifica
);

-- =====================================================================
--  INDICI  (accelerano le ricerche più frequenti)
-- =====================================================================

-- FK più sollecitate dai JOIN della vista di esportazione
CREATE INDEX idx_assets_org           ON Assets(org_id);
CREATE INDEX idx_services_org         ON Services(org_id);
CREATE INDEX idx_suppliers_org        ON Suppliers(org_id);
CREATE INDEX idx_resp_org             ON Responsibilities(org_id);
CREATE INDEX idx_dep_asset            ON Dependencies(asset_id);
CREATE INDEX idx_dep_supplier         ON Dependencies(supplier_id);

-- Indici PARZIALI: indicizzano solo le righe nel perimetro NIS2 / attive,
-- riducendo la dimensione dell'indice e accelerando le query di estrazione
CREATE INDEX idx_assets_perimetro     ON Assets(criticality_level)
                                      WHERE in_perimetro_nis = TRUE;
CREATE INDEX idx_assets_attivi        ON Assets(asset_id)
                                      WHERE stato = 'attivo';

-- =====================================================================
--  TRIGGER DI STORICIZZAZIONE  (paradigma delle basi di dati attive)
-- =====================================================================

-- ---- ASSETS ----------------------------------------------------------
CREATE OR REPLACE FUNCTION log_asset_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Assets_History (
        asset_id, org_id, asset_name, asset_type, criticality_level,
        impatto_riservatezza, impatto_integrita, impatto_disponibilita,
        stato, in_perimetro_nis, archived_at, operation, modified_by)
    VALUES (
        OLD.asset_id, OLD.org_id, OLD.asset_name, OLD.asset_type,
        OLD.criticality_level, OLD.impatto_riservatezza,
        OLD.impatto_integrita, OLD.impatto_disponibilita,
        OLD.stato, OLD.in_perimetro_nis, NOW(),
        CASE TG_OP WHEN 'UPDATE' THEN 'U' ELSE 'D' END,
        CURRENT_USER);

    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at := NOW();
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER asset_versioning
    BEFORE UPDATE OR DELETE ON Assets
    FOR EACH ROW EXECUTE FUNCTION log_asset_changes();

-- ---- SERVICES --------------------------------------------------------
CREATE OR REPLACE FUNCTION log_service_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Services_History (
        service_id, org_id, service_name, sla, stato, archived_at, operation, modified_by)
    VALUES (
        OLD.service_id, OLD.org_id, OLD.service_name, OLD.sla, OLD.stato, NOW(),
        CASE TG_OP WHEN 'UPDATE' THEN 'U' ELSE 'D' END,
        CURRENT_USER);

    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at := NOW();
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER service_versioning
    BEFORE UPDATE OR DELETE ON Services
    FOR EACH ROW EXECUTE FUNCTION log_service_changes();

-- ---- RESPONSIBILITIES ------------------------------------------------
CREATE OR REPLACE FUNCTION log_responsibility_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Responsibilities_History (
        responsible_id, org_id, asset_id, responsible_name, role,
        archived_at, operation, modified_by)
    VALUES (
        OLD.responsible_id, OLD.org_id, OLD.asset_id, OLD.responsible_name,
        OLD.role, NOW(),
        CASE TG_OP WHEN 'UPDATE' THEN 'U' ELSE 'D' END,
        CURRENT_USER);

    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at := NOW();
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER responsibility_versioning
    BEFORE UPDATE OR DELETE ON Responsibilities
    FOR EACH ROW EXECUTE FUNCTION log_responsibility_changes();

-- =====================================================================
--  VISTA DI ESPORTAZIONE  ACN_EXPORT_VIEW
-- =====================================================================

CREATE OR REPLACE VIEW ACN_EXPORT_VIEW AS
SELECT
    o.codice_fiscale                 AS cf_organizzazione,
    o.denominazione                  AS organizzazione,
    o.categoria                      AS categoria_nis2,
    a.asset_name                     AS asset_nome,
    a.asset_type                     AS asset_tipologia,
    a.criticality_level              AS criticita,
    a.impatto_riservatezza           AS cia_riservatezza,
    a.impatto_integrita              AS cia_integrita,
    a.impatto_disponibilita          AS cia_disponibilita,
    COALESCE(s.service_name, '')     AS servizio_collegato,
    COALESCE(sup.supplier_name, '')  AS fornitore,
    COALESCE(sup.paese, '')          AS paese_fornitore,
    COALESCE(r.responsible_name, '') AS responsabile,
    COALESCE(r.role, '')             AS ruolo_responsabile,
    COALESCE(r.contact_info, '')     AS contatto_responsabile
FROM Organizzazione o
JOIN Assets a               ON a.org_id        = o.org_id
LEFT JOIN Asset_Service ase ON ase.asset_id    = a.asset_id
LEFT JOIN Services s        ON s.service_id    = ase.service_id
LEFT JOIN Dependencies d    ON d.asset_id      = a.asset_id
LEFT JOIN Suppliers sup     ON sup.supplier_id = d.supplier_id
LEFT JOIN Responsibilities r ON r.asset_id     = a.asset_id
WHERE a.in_perimetro_nis = TRUE
ORDER BY o.denominazione, a.criticality_level DESC, a.asset_name;

COMMENT ON VIEW ACN_EXPORT_VIEW IS 'Vista denormalizzata per la generazione del profilo ACN in CSV';

-- =====================================================================
--  FINE SCHEMA
-- =====================================================================
