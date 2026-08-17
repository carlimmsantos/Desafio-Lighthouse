-- Questão 5 — Dimensão de calendário: pior dia da semana em vendas (lojas físicas)
-- Engine: DuckDB, lendo database/orders.csv diretamente (mesmo padrão da Questão 1/4).
--
-- Correção do erro do estagiário: um GROUP BY direto em orders só enxerga dias em que
-- HOUVE pelo menos uma venda. Domingos sem nenhuma venda simplesmente não aparecem na
-- tabela, então entram como se não existissem no cálculo da média — em vez de contarem
-- como R$ 0,00, eles são omitidos, e a média (soma / contagem de dias COM venda) fica
-- artificialmente alta. A correção é gerar um calendário com TODOS os dias do período,
-- LEFT JOIN com as vendas, e tratar ausência de venda como valor 0 antes de calcular a média.
--
-- Premissas aplicadas (enunciado da Questão 5):
--   * Período do calendário: de MIN(placed_at) até MAX(placed_at) presentes no arquivo
--     orders.csv (todo o histórico do arquivo, não restrito ao canal pos — a loja é
--     considerada aberta todos os dias desse intervalo, inclusive fins de semana).
--   * Canal: apenas 'pos' (lojas físicas) entra na agregação de vendas.
--   * Dia sem registro em orders = valor de venda 0 (via LEFT JOIN + COALESCE).
--   * "Vendas diárias" = SOMA de orders.total por dia (sem filtro de status — o
--     enunciado não pede para excluir cancelled/draft, ao contrário da Questão 1).
--   * Nome do dia da semana em português, com "-feira" em Segunda a Sexta
--     (Sábado e Domingo não levam "-feira").

WITH bounds AS (
    SELECT
        MIN(CAST(placed_at AS DATE)) AS data_min,
        MAX(CAST(placed_at AS DATE)) AS data_max
    FROM read_csv_auto('database/orders.csv')
),

-- 1) Dimensão de calendário: uma linha por dia do período, com o dia da semana em PT-BR
calendario AS (
    SELECT
        gs::DATE AS data,
        CAST(strftime(gs::DATE, '%w') AS INTEGER) AS dow_num  -- 0=domingo ... 6=sábado
    FROM bounds, generate_series(bounds.data_min, bounds.data_max, INTERVAL 1 DAY) AS t(gs)
),
calendario_dia_semana AS (
    SELECT
        data,
        dow_num,
        CASE dow_num
            WHEN 0 THEN 'Domingo'
            WHEN 1 THEN 'Segunda-feira'
            WHEN 2 THEN 'Terça-feira'
            WHEN 3 THEN 'Quarta-feira'
            WHEN 4 THEN 'Quinta-feira'
            WHEN 5 THEN 'Sexta-feira'
            WHEN 6 THEN 'Sábado'
        END AS dia_semana
    FROM calendario
),

-- 2) Vendas diárias das lojas físicas (channel = 'pos'), agregadas por dia
vendas_pos_diarias AS (
    SELECT
        CAST(placed_at AS DATE) AS data,
        SUM(total) AS valor_venda
    FROM read_csv_auto('database/orders.csv')
    WHERE channel = 'pos'
    GROUP BY CAST(placed_at AS DATE)
),

-- 3) LEFT JOIN calendário x vendas: todo dia do calendário aparece, mesmo sem venda,
--    e COALESCE substitui NULL (dia sem registro) por 0
calendario_vendas AS (
    SELECT
        c.data,
        c.dow_num,
        c.dia_semana,
        COALESCE(v.valor_venda, 0) AS valor_venda
    FROM calendario_dia_semana c
    LEFT JOIN vendas_pos_diarias v ON v.data = c.data
)

-- Questão 5.1 — resultado: média de vendas por dia da semana, ordenada da pior para a melhor
SELECT
    dow_num,
    dia_semana,
    COUNT(*)                                            AS qtd_dias_no_periodo,
    SUM(CASE WHEN valor_venda = 0 THEN 1 ELSE 0 END)    AS dias_sem_venda,
    ROUND(SUM(valor_venda), 2)                          AS soma_vendas,
    ROUND(AVG(valor_venda), 2)                          AS media_vendas_dia
FROM calendario_vendas
GROUP BY dow_num, dia_semana
ORDER BY media_vendas_dia ASC;
