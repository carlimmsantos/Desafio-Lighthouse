-- Questão 1 — EDA inicial da tabela orders
-- Premissas: usar apenas orders.csv, sem nenhum tratamento/limpeza, apenas observar/agregar/descrever.
-- Engine: DuckDB, lendo o CSV diretamente (nenhuma tabela intermediária é criada/persistida).

-- Parte 1 — Visão geral: linhas, colunas e intervalo de datas (created_at)
SELECT
    COUNT(*)                                   AS total_linhas,
    (SELECT COUNT(*)
       FROM (DESCRIBE SELECT * FROM read_csv_auto('database/orders.csv')))
                                                AS total_colunas,
    strftime(MIN(created_at), '%d/%m/%Y %H:%M:%S') AS data_minima,
    strftime(MAX(created_at), '%d/%m/%Y %H:%M:%S') AS data_maxima
FROM read_csv_auto('database/orders.csv');

-- Parte 2 — Estatísticas da coluna total (min, max, média)
SELECT
    MIN(total)              AS total_min,
    MAX(total)              AS total_max,
    ROUND(AVG(total), 2)    AS total_medio,
    COUNT(*) - COUNT(total) AS qtd_nulos_total
FROM read_csv_auto('database/orders.csv');

-- Extra (apoio ao diagnóstico da Parte 3 / Questão 1.3) — checagem de nulos em todas as colunas
SELECT
    COUNT(*) - COUNT(id)               AS nulos_id,
    COUNT(*) - COUNT(order_number)     AS nulos_order_number,
    COUNT(*) - COUNT(channel)          AS nulos_channel,
    COUNT(*) - COUNT(customer_id)      AS nulos_customer_id,
    COUNT(*) - COUNT(salesperson_id)   AS nulos_salesperson_id,
    COUNT(*) - COUNT(location_id)      AS nulos_location_id,
    COUNT(*) - COUNT(status)           AS nulos_status,
    COUNT(*) - COUNT(subtotal)         AS nulos_subtotal,
    COUNT(*) - COUNT(discount_amount)  AS nulos_discount_amount,
    COUNT(*) - COUNT(total)            AS nulos_total,
    COUNT(*) - COUNT(placed_at)        AS nulos_placed_at,
    COUNT(*) - COUNT(created_at)       AS nulos_created_at,
    COUNT(*) - COUNT(updated_at)       AS nulos_updated_at
FROM read_csv_auto('database/orders.csv');

-- Extra — distribuição de status e canais (contexto para o diagnóstico)
SELECT status, COUNT(*) AS qtd
FROM read_csv_auto('database/orders.csv')
GROUP BY status
ORDER BY qtd DESC;

SELECT channel, COUNT(*) AS qtd
FROM read_csv_auto('database/orders.csv')
GROUP BY channel
ORDER BY qtd DESC;

-- Extra — possíveis outliers em total: quartis e limites via IQR (1.5x)
WITH stats AS (
    SELECT
        quantile_cont(total, 0.25) AS q1,
        quantile_cont(total, 0.50) AS mediana,
        quantile_cont(total, 0.75) AS q3
    FROM read_csv_auto('database/orders.csv')
)
SELECT
    ROUND(q1, 2)                        AS q1,
    ROUND(mediana, 2)                   AS mediana,
    ROUND(q3, 2)                        AS q3,
    ROUND(q3 - q1, 2)                   AS iqr,
    ROUND(q1 - 1.5 * (q3 - q1), 2)      AS limite_inferior,
    ROUND(q3 + 1.5 * (q3 - q1), 2)      AS limite_superior
FROM stats;
