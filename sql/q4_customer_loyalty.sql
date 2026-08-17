-- Questão 4 — Análise de clientes fiéis
-- Engine: DuckDB, lendo os CSVs diretamente (mesmo padrão da Questão 1), sem nenhuma
-- tabela intermediária persistida fora desta sessão (as TEMP TABLE abaixo só existem
-- durante a execução do script e servem para não duplicar a lógica entre as consultas).
--
-- Cadeia de chaves usada para ligar um item comprado à sua categoria
-- (é a base da "Diversidade de Categorias" e do ranking de itens por categoria):
--   orders.id              = order_items.order_id            (pedido -> itens do pedido)
--   order_items.product_variant_id = product_variants.id     (item -> variante/SKU vendido)
--   product_variants.product_id    = products.id             (variante -> produto)
--   products.category_id           = categories.id           (produto -> categoria)
--
-- Premissas obrigatórias (enunciado da Questão 4):
--   * Faturamento Total  = SUM(orders.total) por customer_id
--   * Frequência         = COUNT(orders.id) por customer_id (nº de transações/pedidos)
--   * Ticket Médio        = Faturamento Total / Frequência
--   * Diversidade         = COUNT(DISTINCT products.category_id) comprado pelo cliente
--   * Filtro de elite      = diversidade >= 13 categorias distintas
--   * Ranking              = Top 10 por Ticket Médio, desempate por customer_id ASC
-- Nenhum filtro de status foi aplicado a orders.total (o enunciado pede a soma "da coluna
-- total por cliente", sem mencionar exclusão de status cancelled/draft).

-- =========================================================================
-- 1) Item comprado -> categoria (materializa a cadeia de chaves uma única vez)
-- =========================================================================
CREATE OR REPLACE TEMP TABLE items_with_category AS
SELECT
    o.customer_id,
    oi.order_id,
    oi.quantity,
    p.category_id,
    c.name AS category_name
FROM read_csv_auto('database/order_items.csv')      AS oi
JOIN read_csv_auto('database/orders.csv')            AS o  ON o.id  = oi.order_id
JOIN read_csv_auto('database/product_variants.csv')  AS pv ON pv.id = oi.product_variant_id
JOIN read_csv_auto('database/products.csv')          AS p  ON p.id  = pv.product_id
JOIN read_csv_auto('database/categories.csv')         AS c  ON c.id  = p.category_id;

-- =========================================================================
-- 2) Faturamento Total, Frequência e Ticket Médio por cliente (direto de orders)
-- =========================================================================
CREATE OR REPLACE TEMP TABLE customer_orders AS
SELECT
    customer_id,
    ROUND(SUM(total), 2)          AS faturamento_total,
    COUNT(id)                     AS frequencia,
    ROUND(SUM(total) / COUNT(id), 2) AS ticket_medio
FROM read_csv_auto('database/orders.csv')
GROUP BY customer_id;

-- =========================================================================
-- 3) Diversidade de Categorias por cliente
-- =========================================================================
CREATE OR REPLACE TEMP TABLE customer_diversity AS
SELECT
    customer_id,
    COUNT(DISTINCT category_id) AS diversidade_categorias
FROM items_with_category
GROUP BY customer_id;

-- =========================================================================
-- 4) Métricas completas por cliente + Filtro de Elite (diversidade >= 13)
--    + Top 10 por Ticket Médio, desempate por customer_id crescente
-- =========================================================================
CREATE OR REPLACE TEMP TABLE top10_clientes_fieis AS
SELECT
    co.customer_id,
    co.faturamento_total,
    co.frequencia,
    co.ticket_medio,
    cd.diversidade_categorias
FROM customer_orders co
JOIN customer_diversity cd ON cd.customer_id = co.customer_id
WHERE cd.diversidade_categorias >= 13
ORDER BY co.ticket_medio DESC, co.customer_id ASC
LIMIT 10;

-- Questão 4.1 — resultado principal: Ticket Médio + Diversidade dos 10 clientes fiéis
SELECT *
FROM top10_clientes_fieis
ORDER BY ticket_medio DESC, customer_id ASC;

-- =========================================================================
-- 5) Para o grupo dos 10 clientes fiéis: categoria com maior SUM(quantity)
--    O JOIN abaixo é feito contra top10_clientes_fieis (não contra a base inteira de
--    clientes), garantindo que a soma de quantidade reflete apenas os itens comprados
--    por esses 10 clientes — nenhum outro cliente entra na agregação.
-- =========================================================================
SELECT
    iwc.category_id,
    iwc.category_name,
    SUM(iwc.quantity) AS quantidade_total_itens
FROM items_with_category iwc
JOIN top10_clientes_fieis t ON t.customer_id = iwc.customer_id
GROUP BY iwc.category_id, iwc.category_name
ORDER BY quantidade_total_itens DESC;
