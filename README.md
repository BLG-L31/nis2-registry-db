# NIS2_REGISTRY

Registro relazionale per la catalogazione di asset, servizi, dipendenze e
responsabilità aziendali a supporto della compilazione dei profili ACN
nell'ambito della Direttiva NIS2.

Project Work — Corso di Laurea in Informatica per le Aziende Digitali (L-31).

---

## Struttura del repository

```
nis2-registry-db/
├── 01_schema_completo.sql      Schema DDL: 12 tabelle, vincoli, indici,
│                               trigger di versioning, vista di export
├── 02_dati_test.sql            Dataset simulato (3 organizzazioni)
├── 03_query_estrazione.sql     Query per le sezioni del profilo + export CSV
├── valida_e_esporta.py         Validazione integrità (psycopg2) + export CSV
├── registro_nis2.dbml          Sorgente del diagramma ER (per dbdiagram.io)
└── README.md                   Questo file
```

---

## Prerequisiti

- PostgreSQL 16 (o >= 14)
- Python 3.11 con i pacchetti `psycopg2-binary` e `pandas` (solo per lo script di validazione)

---

## Deployment passo passo

### 1. Creare il database e l'utente

Da terminale, accedere a PostgreSQL come superutente ed eseguire:

```sql
CREATE USER nis2_user WITH PASSWORD 'password';
CREATE DATABASE nis2_registry OWNER nis2_user;
```

### 2. Creare lo schema (tabelle, vincoli, indici, trigger, vista)

```bash
psql -U nis2_user -d nis2_registry -f 01_schema_completo.sql
```

### 3. Popolare il dataset di test

```bash
psql -U nis2_user -d nis2_registry -f 02_dati_test.sql
```

### 4. Eseguire le query di estrazione

```bash
psql -U nis2_user -d nis2_registry -f 03_query_estrazione.sql
```

### 5. (Opzionale) Validazione automatica ed export via Python

```bash
pip install psycopg2-binary pandas
python scripts/valida_e_esporta.py
```

Lo script esegue i controlli di integrità/compliance e genera il file
`profilo_acn_energiaitalia.csv`.

---

## Come ottenere il diagramma ER (immagine)

Il diagramma ER è mantenuto come codice nel file `docs/registro_nis2.dbml`
(approccio *diagram-as-code*: il diagramma è versionato insieme allo schema).

1. Aprire <https://dbdiagram.io>
2. Incollare il contenuto di `registro_nis2.dbml`
3. Il diagramma viene generato automaticamente
4. `Export` → PNG / PDF / SVG per ottenere l'immagine

Lo stesso modello può essere ridisegnato in **draw.io** o **Lucidchart**
partendo dalla struttura descritta nel DBML.

---

## Come dimostrare il versioning (SCD Type 2)

Per mostrare che lo storico funziona, modificare un asset e interrogare la
tabella di storico:

```sql
-- Stato iniziale
SELECT asset_id, criticality_level FROM Assets WHERE asset_id = 4;

-- Modifica (innesca il trigger BEFORE UPDATE)
UPDATE Assets SET criticality_level = 5 WHERE asset_id = 4;

-- La versione PRECEDENTE è stata conservata automaticamente
SELECT asset_id, criticality_level, operation, archived_at
FROM   Assets_History WHERE asset_id = 4;
```

Il record archiviato in `Assets_History` riporta il valore precedente
(`criticality_level = 3`), il tipo di operazione (`U`) e la data: è la prova
della tracciabilità storica richiesta dall'ACN.

---

## Note sulla progettazione

- Schema normalizzato in 3NF; relazioni N:M materializzate in tabelle di
  giunzione (`Asset_Service`) o associative (`Dependencies`).
- Multi-tenant: la chiave `org_id` su tutte le tabelle di entità consente di
  gestire più organizzazioni nella stessa istanza.
- Integrità referenziale con politiche `ON DELETE CASCADE` / `ON UPDATE RESTRICT`
  / `ON DELETE SET NULL` a seconda della semantica della relazione.
- Indici parziali sul perimetro NIS2 per accelerare le query di estrazione.
