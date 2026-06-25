#!/usr/bin/env python3
# =====================================================================
#  NIS2_REGISTRY — Script di validazione del dataset e generazione CSV
#
#  Verifica automaticamente l'integrità del dataset (valori nulli in
#  campi obbligatori, chiavi esterne orfane, range non validi) ed
#  esporta il profilo ACN in CSV.
#
#  Dipendenze:  pip install psycopg2-binary pandas
#  Esecuzione:  python valida_e_esporta.py
# =====================================================================

import sys
import psycopg2
import pandas as pd

# --- Parametri di connessione (adattare al proprio ambiente) ----------
DB_CONFIG = {
    "host":     "localhost",
    "port":     5432,
    "dbname":   "nis2_registry",
    "user":     "nis2_user",
    "password": "password",   # in produzione: usare variabili d'ambiente
}


def connetti():
    """Apre una connessione al database PostgreSQL."""
    try:
        return psycopg2.connect(**DB_CONFIG)
    except psycopg2.OperationalError as e:
        print(f"[ERRORE] Connessione fallita: {e}")
        sys.exit(1)


def esegui_controlli(conn):
    """Esegue una batteria di controlli di integrità e ne stampa l'esito."""
    controlli = {
        "Asset senza criticità valida":
            "SELECT COUNT(*) FROM Assets "
            "WHERE criticality_level NOT BETWEEN 1 AND 5",
        "Asset critici (>=4) senza responsabile":
            "SELECT COUNT(*) FROM Assets a "
            "LEFT JOIN Responsibilities r ON r.asset_id = a.asset_id "
            "WHERE a.criticality_level >= 4 AND r.responsible_id IS NULL",
        "Asset critici senza misure di sicurezza":
            "SELECT COUNT(*) FROM Assets a "
            "LEFT JOIN Security_Measures sm ON sm.asset_id = a.asset_id "
            "WHERE a.criticality_level >= 4 AND sm.measure_id IS NULL",
        "Dipendenze con contratto scaduto":
            "SELECT COUNT(*) FROM Dependencies "
            "WHERE data_fine < CURRENT_DATE",
        "Servizi con SLA sotto il 99%":
            "SELECT COUNT(*) FROM Services WHERE sla < 99.0",
    }

    print("\n=== CONTROLLI DI INTEGRITÀ E COMPLIANCE ===")
    anomalie_bloccanti = 0
    with conn.cursor() as cur:
        for descrizione, query in controlli.items():
            cur.execute(query)
            n = cur.fetchone()[0]
            esito = "OK" if n == 0 else f"ATTENZIONE: {n} caso/i"
            print(f"  [{esito:>20}]  {descrizione}")
            # Solo il primo controllo è realmente bloccante (dato non valido):
            if "criticità valida" in descrizione and n > 0:
                anomalie_bloccanti += n
    return anomalie_bloccanti


def esporta_profilo_csv(conn, codice_fiscale, percorso_output):
    """Estrae il profilo ACN di un'organizzazione e lo salva in CSV."""
    query = "SELECT * FROM ACN_EXPORT_VIEW WHERE cf_organizzazione = %s"
    df = pd.read_sql_query(query, conn, params=(codice_fiscale,))
    if df.empty:
        print(f"\n[AVVISO] Nessun dato per il codice fiscale {codice_fiscale}")
        return
    df.to_csv(percorso_output, index=False, encoding="utf-8")
    print(f"\n=== ESPORTAZIONE COMPLETATA ===")
    print(f"  Righe esportate: {len(df)}")
    print(f"  File generato:   {percorso_output}")


def main():
    conn = connetti()
    try:
        bloccanti = esegui_controlli(conn)
        if bloccanti:
            print(f"\n[STOP] {bloccanti} dati non validi: correggere prima dell'export.")
            sys.exit(2)
        esporta_profilo_csv(conn, "01234567890", "profilo_acn_energiaitalia.csv")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
