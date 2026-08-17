"""
Questao 2 - Geracao do schema.sql (PostgreSQL)

Le todos os CSVs de um diretorio, detecta as colunas e o tipo/nulidade de
cada uma a partir dos dados reais (sem amostragem - o arquivo inteiro e
percorrido) e gera um unico sql/q2_schema.sql com um CREATE TABLE por CSV.

Usa apenas biblioteca padrao (csv, re, decimal, pathlib, sys) - sem pandas.

Rodar a partir da raiz do projeto:
    python src/q2_generate_schema.py [diretorio_dos_csvs]
"""

import csv
import re
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CSV_DIR = PROJECT_ROOT / "database"
OUTPUT_PATH = PROJECT_ROOT / "sql" / "q2_schema.sql"

HEADER = """-- Questao 2 - schema.sql (PostgreSQL)
-- Gerado automaticamente por src/q2_generate_schema.py -- NAO EDITAR A MAO.
-- Cada CREATE TABLE foi derivado lendo o CSV correspondente por completo:
--   * tipo de cada coluna inferido por tentativa (BOOLEAN > TIMESTAMP > DATE
--     > INTEGER/BIGINT > NUMERIC(p,s) > VARCHAR(n)/TEXT, nessa ordem);
--   * NOT NULL somente se a coluna nao tiver nenhum valor vazio no CSV;
--   * coluna "id" (quando existe) vira PRIMARY KEY.
-- Limitacao conhecida: deteccao e' puramente estrutural (por arquivo) -- nao
-- infere chaves estrangeiras nem chaves primarias compostas entre tabelas.
"""

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TIMESTAMP_RE = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")
BOOLEAN_VALUES = {"TRUE", "FALSE", "true", "false"}
INT_RE = re.compile(r"^-?\d+$")
NUMERIC_RE = re.compile(r"^-?\d+(\.\d+)?$")

INTEGER_MAX = 2_147_483_647
VARCHAR_STEP = 20
PRECISION_BUFFER = 2
# Acima disso um valor "todo digitos" (ex.: chave de acesso de NF-e, CPF longo)
# e' quase certamente um codigo/identificador, nao um numero para aritmetica --
# tratamos como VARCHAR em vez de estourar BIGINT/NUMERIC.
MAX_NUMERIC_INT_DIGITS = 18


def is_plain_int(value: str) -> bool:
    if not INT_RE.match(value):
        return False
    digits = value.lstrip("-")
    if len(digits) > MAX_NUMERIC_INT_DIGITS:
        return False
    return digits == "0" or digits[0] != "0"


def integer_digit_len(value: str) -> int:
    int_part = value.lstrip("-").partition(".")[0]
    return len(int_part.lstrip("0") or "0")


def has_leading_zero(value: str) -> bool:
    # Zero a esquerda (ex.: CPF "00429721404") e' o sinal mais confiavel de que
    # o valor e' um codigo/identificador, nao um numero -- convertendo para
    # NUMERIC/INTEGER esse zero seria perdido silenciosamente.
    int_part = value.lstrip("-").partition(".")[0]
    return len(int_part) > 1 and int_part[0] == "0"


def decimal_precision_scale(values):
    max_int_digits = 1
    max_scale = 0
    for value in values:
        int_part, _, frac_part = value.lstrip("-").partition(".")
        int_part = int_part.lstrip("0") or "0"
        max_int_digits = max(max_int_digits, len(int_part))
        max_scale = max(max_scale, len(frac_part))
    return max_int_digits + max_scale, max_scale


def infer_column_type(values: list[str]) -> str:
    filled = [v for v in values if v != ""]
    if not filled:
        return "TEXT"

    if all(v in BOOLEAN_VALUES for v in filled):
        return "BOOLEAN"

    if all(TIMESTAMP_RE.match(v) for v in filled):
        return "TIMESTAMP"

    if all(DATE_RE.match(v) for v in filled):
        return "DATE"

    any_leading_zero = any(has_leading_zero(v) for v in filled)

    if not any_leading_zero and all(is_plain_int(v) for v in filled):
        return "INTEGER" if max(abs(int(v)) for v in filled) <= INTEGER_MAX else "BIGINT"

    if (
        not any_leading_zero
        and all(NUMERIC_RE.match(v) for v in filled)
        and max(integer_digit_len(v) for v in filled) <= MAX_NUMERIC_INT_DIGITS
    ):
        try:
            for v in filled:
                Decimal(v)
        except InvalidOperation:
            pass
        else:
            precision, scale = decimal_precision_scale(filled)
            return f"NUMERIC({precision + PRECISION_BUFFER},{scale})"

    max_len = max(len(v) for v in filled)
    if max_len > 255:
        return "TEXT"
    varchar_len = ((max_len // VARCHAR_STEP) + 1) * VARCHAR_STEP
    return f"VARCHAR({varchar_len})"


def read_columns(csv_path: Path):
    with csv_path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        header = next(reader)
        columns = {name: [] for name in header}
        for row in reader:
            for name, value in zip(header, row):
                columns[name].append(value)
    return header, columns


def build_create_table(csv_path: Path) -> str:
    table_name = csv_path.stem
    header, columns = read_columns(csv_path)

    lines = []
    for name in header:
        values = columns[name]
        sql_type = infer_column_type(values)
        not_null = all(v != "" for v in values)

        if name == "id":
            constraint = " PRIMARY KEY"
        elif not_null:
            constraint = " NOT NULL"
        else:
            constraint = ""

        lines.append(f"    {name} {sql_type}{constraint}")

    cols_sql = ",\n".join(lines)
    return f"CREATE TABLE {table_name} (\n{cols_sql}\n);"


def generate_schema(csv_files: list[Path]) -> str:
    drops = "\n".join(
        f"DROP TABLE IF EXISTS {p.stem} CASCADE;" for p in csv_files
    )
    tables = "\n\n".join(build_create_table(p) for p in csv_files)

    return "\n\n".join([HEADER, drops, tables]) + "\n"


def main() -> None:
    csv_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CSV_DIR
    csv_files = sorted(csv_dir.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"Nenhum CSV encontrado em {csv_dir}")

    schema_sql = generate_schema(csv_files)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(schema_sql, encoding="utf-8")
    print(f"Schema gerado em {OUTPUT_PATH} ({len(csv_files)} tabelas, lidas de {csv_dir}).")


if __name__ == "__main__":
    main()
