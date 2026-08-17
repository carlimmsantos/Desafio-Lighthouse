"""
Questão 6 — Previsão de demanda: baseline de média móvel (3 meses) para
"Bússola de Bordo 702".

Dataset unificado: order_items -> orders (data do pedido) e order_items ->
product_variants -> products (para filtrar pelo produto e confirmar o nome).

Nota de qualidade de dados: products.csv tem DUAS linhas com o nome exato
"Bússola de Bordo 702" (id 74 e id 240) — uma colisão de nome nos dados
sintéticos. Usamos o id 74 porque o id 240 tem created_at em 2026-06-22,
ou seja, o produto "nasceria" no catálogo DEPOIS de todo o período de
treino/teste deste modelo (até 2026-03-31) — não pode ser o produto sobre o
qual o Sr. Almir está pedindo previsão de estoque para o 1º trimestre de 2026.
Ver Questão 6.3 para a explicação completa.

Rodar a partir da raiz do projeto:
    python src/q6_demand_forecast.py
"""

from pathlib import Path

import pandas as pd

DATABASE_DIR = Path(__file__).resolve().parent.parent / "database"

PRODUCT_ID = 74  # "Bússola de Bordo 702" — ver nota de qualidade de dados acima
PRODUCT_NAME = "Bússola de Bordo 702"

TRAIN_END = pd.Period("2025-12", freq="M")
TEST_MONTHS = pd.period_range("2026-01", "2026-03", freq="M")
WINDOW = 3


def load_unified_dataset() -> pd.DataFrame:
    """Junta order_items + orders + product_variants + products, filtrado ao produto alvo."""
    products = pd.read_csv(DATABASE_DIR / "products.csv")
    variants = pd.read_csv(DATABASE_DIR / "product_variants.csv")
    order_items = pd.read_csv(DATABASE_DIR / "order_items.csv")
    orders = pd.read_csv(DATABASE_DIR / "orders.csv", parse_dates=["placed_at"])

    variant_ids = variants.loc[variants["product_id"] == PRODUCT_ID, "id"]

    df = (
        order_items[order_items["product_variant_id"].isin(variant_ids)]
        .merge(orders[["id", "placed_at"]], left_on="order_id", right_on="id")
        .merge(
            variants[["id", "product_id"]],
            left_on="product_variant_id",
            right_on="id",
            suffixes=("", "_variant"),
        )
        .merge(
            products[["id", "name"]],
            left_on="product_id",
            right_on="id",
            suffixes=("", "_product"),
        )
    )
    df["month"] = df["placed_at"].dt.to_period("M")
    return df


def monthly_quantity(df: pd.DataFrame) -> pd.Series:
    """Vendas mensais (soma de order_items.quantity) do produto, uma linha por mês."""
    return df.groupby("month")["quantity"].sum().sort_index()


def moving_average_baseline(monthly: pd.Series, target_months, window: int = WINDOW) -> pd.Series:
    """
    Baseline: para cada mês alvo, prevê a média das `window` observações mensais
    IMEDIATAMENTE ANTERIORES a ele — sempre usando valores reais já observados
    (nunca a própria previsão de um mês anterior), o que caracteriza uma previsão
    walk-forward sem data leakage: a "janela" desliza usando o real conforme ele
    vai se tornando disponível (ex.: a previsão de fevereiro/2026 já pode usar o
    valor REAL de janeiro/2026, pois em fevereiro janeiro já é passado).
    """
    forecasts = {}
    for month in target_months:
        history = monthly[monthly.index < month]
        forecasts[month] = history.tail(window).mean()
    return pd.Series(forecasts, name="previsto")


def seasonal_naive_baseline(monthly: pd.Series, target_months) -> pd.Series:
    """
    Comparação extra (não é o baseline pedido no enunciado, é só para avaliar se
    outro modelo simples se sairia melhor): prevê o mês alvo como o valor REAL do
    mesmo mês um ano antes (ex.: previsão de janeiro/2026 = valor real de
    janeiro/2025). Também não usa nenhum dado do próprio mês-alvo nem posterior.
    """
    forecasts = {}
    for month in target_months:
        same_month_last_year = month - 12
        forecasts[month] = monthly.get(same_month_last_year, float("nan"))
    return pd.Series(forecasts, name="previsto_naive_sazonal")


def mean_absolute_error(actual: pd.Series, forecast: pd.Series) -> float:
    return (actual - forecast).abs().mean()


def main() -> None:
    df = load_unified_dataset()
    monthly = monthly_quantity(df)

    train = monthly[monthly.index <= TRAIN_END]
    print(f"Histórico de treino: {train.index.min()} a {train.index.max()} ({len(train)} meses)")

    actual = monthly.reindex(TEST_MONTHS).fillna(0)

    forecast_ma = moving_average_baseline(monthly, TEST_MONTHS, window=WINDOW)
    forecast_naive = seasonal_naive_baseline(monthly, TEST_MONTHS)

    comparativo = pd.DataFrame({
        "real": actual,
        "media_movel_3m": forecast_ma.round(2),
        "naive_sazonal": forecast_naive.round(2),
    })
    comparativo["erro_media_movel"] = (comparativo["real"] - comparativo["media_movel_3m"]).abs().round(2)
    comparativo["erro_naive_sazonal"] = (comparativo["real"] - comparativo["naive_sazonal"]).abs().round(2)

    print("\nPrevisão (média móvel 3m x naive sazonal) x Real — Q1 2026:")
    print(comparativo.to_string())

    mae_ma = mean_absolute_error(actual, forecast_ma)
    mae_naive = mean_absolute_error(actual, forecast_naive)

    print(f"\nSoma total prevista (média móvel 3m): {round(forecast_ma.sum())}")
    print(f"Soma total prevista (naive sazonal):  {round(forecast_naive.sum())}")
    print(f"Soma total real em Q1 2026: {int(actual.sum())}")
    print(f"\nMAE média móvel 3m:  {mae_ma:.2f}")
    print(f"MAE naive sazonal:   {mae_naive:.2f}")
    melhor = "média móvel 3m" if mae_ma < mae_naive else "naive sazonal"
    print(f"-> Menor erro: {melhor}")

    print(
        "\nLimitações:"
        "\n- Média móvel 3m: indicador DEFASADO — só reage a uma mudança de patamar"
        " depois que ela já entrou na janela, nunca antecipa um pico sazonal (ex.:"
        " janeiro puxa a média de out-dez/2025, meses fracos, e erra o pico de verão)."
        "\n- Naive sazonal: depende de UM único ponto histórico por mês-alvo (ex.:"
        " previsão de jan/2026 = só o valor real de jan/2025) — não suaviza ruído"
        " nenhum, então um mês atípico no ano anterior (promoção, ruptura de"
        " estoque, erro de registro) se propaga inteiro para a previsão."
    )


if __name__ == "__main__":
    main()
