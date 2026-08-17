"""
Questão 3 — Carga dos CSVs em PostgreSQL

Aplica sql/q2_schema.sql (recriando as tabelas do zero) e carrega os CSVs de
database/ nas tabelas correspondentes via COPY (psycopg2.copy_expert) — muito
mais rápido que INSERT linha a linha para os ~370 mil registros da base.

O schema gerado pela Questão 2 (src/q2_generate_schema.py) não declara chaves
estrangeiras, então não existe ordem de dependência entre tabelas a respeitar
aqui — os CSVs são carregados na mesma ordem (alfabética) em que o gerador de
schema os descobre, um por arquivo.

Parâmetros de conexão vêm de variáveis de ambiente (com defaults para o
Postgres local subido por `docker compose up -d`, ver docker-compose.yml):
    PGHOST=localhost  PGPORT=5432  PGDATABASE=lh_nautical
    PGUSER=postgres   PGPASSWORD=postgres

Rodar a partir da raiz do projeto:
    docker compose up -d
    python src/q3_load_postgres.py
"""

import os
from pathlib import Path

import psycopg2

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = PROJECT_ROOT / "sql" / "q2_schema.sql"
DATABASE_DIR = PROJECT_ROOT / "database"

LOAD_ORDER = [p.stem for p in sorted(DATABASE_DIR.glob("*.csv"))]

DB_PARAMS = {
    "host": os.environ.get("PGHOST", "localhost"),
    "port": os.environ.get("PGPORT", "5432"),
    "dbname": os.environ.get("PGDATABASE", "lh_nautical"),
    "user": os.environ.get("PGUSER", "postgres"),
    "password": os.environ.get("PGPASSWORD", "postgres"),
}


def apply_schema(conn) -> None:
    schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(schema_sql)
    conn.commit()


def count_csv_rows(csv_path: Path) -> int:
    with open(csv_path, "r", encoding="utf-8") as f:
        return sum(1 for _ in f) - 1  # desconta o header


def load_table(conn, table: str) -> int:
    csv_path = DATABASE_DIR / f"{table}.csv"
    with conn.cursor() as cur, open(csv_path, "r", encoding="utf-8", newline="") as f:
        cur.copy_expert(
            f"COPY {table} FROM STDIN WITH (FORMAT csv, HEADER true, NULL '')",
            f,
        )
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        (row_count,) = cur.fetchone()
    conn.commit()
    return row_count


def main() -> None:
    conn = psycopg2.connect(**DB_PARAMS)
    try:
        print(f"Aplicando schema em {DB_PARAMS['dbname']}@{DB_PARAMS['host']}:{DB_PARAMS['port']}...")
        apply_schema(conn)

        print(f"Carregando {len(LOAD_ORDER)} tabelas...")
        divergences = []
        for table in LOAD_ORDER:
            csv_rows = count_csv_rows(DATABASE_DIR / f"{table}.csv")
            db_rows = load_table(conn, table)
            status = "OK" if db_rows == csv_rows else "DIVERGENTE"
            if status == "DIVERGENTE":
                divergences.append(table)
            print(f"  {table:<28} {db_rows:>7} linhas carregadas (CSV: {csv_rows}) [{status}]")

        if divergences:
            raise RuntimeError(f"Divergência de contagem nas tabelas: {divergences}")
    finally:
        conn.close()

    print("Carga concluída com sucesso — contagem de linhas bate com todos os CSVs.")


if __name__ == "__main__":
    main()
