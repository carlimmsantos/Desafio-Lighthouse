"""
Questão 7 — Sistema de recomendação: "quem comprou isso, também levou..."

Constrói uma matriz de interação Usuário x Produto (binária: comprou/não comprou),
calcula a similaridade de cosseno produto x produto e gera o ranking dos produtos
mais similares a um item de referência.

Rodar a partir da raiz do projeto:
    python src/q7_recommender.py
"""

from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity

DATABASE_DIR = Path(__file__).resolve().parent.parent / "database"

REFERENCE_PRODUCT_NAME = "Motor de Popa 1949"
TOP_N = 5


def load_customer_product_purchases() -> pd.DataFrame:
    """
    Junta orders -> order_items -> product_variants -> products para obter,
    para cada linha de compra, o par (customer_id, product_id). A granularidade
    é produto (não variante/SKU): duas variantes do mesmo produto contam como
    o mesmo item comprado, pois a recomendação é "produto", não "SKU".
    """
    orders = pd.read_csv(DATABASE_DIR / "orders.csv", usecols=["id", "customer_id"])
    order_items = pd.read_csv(DATABASE_DIR / "order_items.csv", usecols=["order_id", "product_variant_id"])
    variants = pd.read_csv(DATABASE_DIR / "product_variants.csv", usecols=["id", "product_id"])
    products = pd.read_csv(DATABASE_DIR / "products.csv", usecols=["id", "name"])

    df = (
        order_items
        .merge(orders, left_on="order_id", right_on="id", suffixes=("", "_order"))
        .merge(variants, left_on="product_variant_id", right_on="id", suffixes=("", "_variant"))
        .merge(products, left_on="product_id", right_on="id", suffixes=("", "_product"))
    )
    return df[["customer_id", "product_id", "name"]]


def build_user_item_matrix(purchases: pd.DataFrame) -> pd.DataFrame:
    """
    Matriz Usuário x Produto: linhas = customer_id, colunas = product_id,
    célula = 1 se o cliente comprou o produto ao menos uma vez, 0 caso contrário.
    Quantidade comprada é ignorada (presença/ausência apenas) — por isso
    `drop_duplicates` antes de pivotar: cada par (cliente, produto) conta uma
    única vez, não importa quantas linhas de order_items geraram esse par.
    """
    pares_unicos = purchases[["customer_id", "product_id"]].drop_duplicates()
    pares_unicos["comprou"] = 1

    matrix = pares_unicos.pivot(index="customer_id", columns="product_id", values="comprou")
    return matrix.fillna(0).astype(int)


def compute_product_similarity(user_item_matrix: pd.DataFrame) -> pd.DataFrame:
    """
    Similaridade de cosseno entre produtos, calculada sobre os vetores-coluna da
    matriz usuário-item (cada produto é representado pelo conjunto de clientes
    que o compraram). Transpõe a matriz para que cosine_similarity compare
    produto x produto (em vez de cliente x cliente).
    """
    product_vectors = user_item_matrix.T  # linhas = produtos, colunas = clientes
    sim = cosine_similarity(product_vectors.values)
    return pd.DataFrame(sim, index=product_vectors.index, columns=product_vectors.index)


def top_similar_products(
    similarity: pd.DataFrame,
    product_id_to_name: dict,
    reference_product_id: int,
    top_n: int = TOP_N,
) -> pd.DataFrame:
    """Ranking dos top_n produtos mais similares ao produto de referência (exclui ele mesmo)."""
    scores = similarity.loc[reference_product_id].drop(index=reference_product_id)
    top = scores.sort_values(ascending=False).head(top_n)
    return pd.DataFrame({
        "product_id": top.index,
        "product_name": [product_id_to_name[pid] for pid in top.index],
        "similaridade_cosseno": top.values.round(4),
    })


def main() -> None:
    purchases = load_customer_product_purchases()
    product_id_to_name = purchases.drop_duplicates("product_id").set_index("product_id")["name"].to_dict()

    reference_matches = purchases.loc[purchases["name"] == REFERENCE_PRODUCT_NAME, "product_id"]
    if reference_matches.nunique() != 1:
        raise ValueError(f"Esperava 1 product_id único para '{REFERENCE_PRODUCT_NAME}', achei: {reference_matches.unique()}")
    reference_product_id = int(reference_matches.iloc[0])

    user_item_matrix = build_user_item_matrix(purchases)
    print(f"Matriz usuário-item: {user_item_matrix.shape[0]} clientes x {user_item_matrix.shape[1]} produtos")

    similarity = compute_product_similarity(user_item_matrix)

    ranking = top_similar_products(similarity, product_id_to_name, reference_product_id, TOP_N)

    print(f"\nProduto de referência: '{REFERENCE_PRODUCT_NAME}' (product_id={reference_product_id})")
    print(f"\nTop {TOP_N} produtos mais similares (similaridade de cosseno):")
    print(ranking.to_string(index=False))

    print(f"\nMaior similaridade: '{ranking.iloc[0]['product_name']}' (score={ranking.iloc[0]['similaridade_cosseno']:.4f})")


if __name__ == "__main__":
    main()
