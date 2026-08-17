# Desafio Lighthouse — LH Nautical

Solução do desafio de dados da Lighthouse, atuando ponta a ponta: EDA, engenharia de dados (schema + carga em PostgreSQL), análise de clientes, dimensão de calendário, previsão de demanda e sistema de recomendação, com dashboard final.

## Estrutura

```
database/       CSVs brutos fornecidos (nunca editados)
sql/             Queries SQL de cada questão (DuckDB lendo os CSVs diretamente)
src/             Scripts Python de cada questão (geração de schema, carga, forecast, recomendação)
notebooks/       Notebooks de exploração/análise
answers/         Respostas objetivas e explicações escritas, organizadas por questão
dashboard/       Dashboard final (HTML)
```

Convenção: arquivos prefixados com `qN_` correspondem à Questão N do desafio.

## Status

- [x] Questão 1 — EDA da tabela `orders`
- [x] Questão 2 — Geração de `schema.sql`
- [x] Questão 3 — Carga em PostgreSQL
- [x] Questão 4 — Análise de clientes fiéis
- [x] Questão 5 — Dimensão de calendário
- [x] Questão 6 — Previsão de demanda
- [x] Questão 7 — Sistema de recomendação
- [x] Dashboard final

## Como rodar

```bash
pip install -r requirements.txt
```

Questão 1: abrir `notebooks/01_q1_eda_orders.ipynb` ou rodar as queries de `sql/q1_orders_eda.sql` via DuckDB.

Questão 2: `python src/q2_generate_schema.py` lê os 24 CSVs de `database/` e infere tipo/nulidade de cada coluna a partir dos dados reais (sem modelo hardcoded), gerando `sql/q2_schema.sql` (24 tabelas, `id` como PK quando existe). Validado rodando `psql -f sql/q2_schema.sql` em um container `postgres:16-alpine` limpo.

Questão 3: `docker compose up -d` sobe um PostgreSQL local (ver `docker-compose.yml`) e `python src/q3_load_postgres.py` aplica o schema e carrega os 24 CSVs via `COPY` (schema não tem FK, então a ordem de carga não é restrita), validando ao final que a contagem de linhas de cada tabela bate com o respectivo CSV.

Questão 4: `sql/q4_customer_loyalty.sql` (DuckDB, lendo os CSVs diretamente) calcula ticket médio e diversidade de categorias por cliente, filtra os 10 clientes fiéis (diversidade ≥ 13 categorias, maior ticket médio) e identifica a categoria com maior volume de itens comprados nesse grupo.

Questão 5: `sql/q5_calendar_weekday_sales.sql` (DuckDB) constrói uma dimensão de calendário e cruza com as vendas das lojas físicas (`pos`) para achar o dia da semana com pior média de vendas, corrigindo o viés de ignorar dias sem nenhuma venda registrada.

Questão 6: `python src/q6_demand_forecast.py` monta o dataset unificado de vendas mensais da "Bússola de Bordo 702" e gera a previsão baseline (média móvel de 3 meses) para o 1º trimestre de 2026, comparando com o real via MAE.

Questão 7: `python src/q7_recommender.py` constrói a matriz usuário-produto binária, calcula a similaridade de cosseno produto x produto e gera o ranking "quem comprou isso, também levou" para o item de referência.

Dashboard: abrir `dashboard/index.html` direto no navegador (sem servidor, sem dependências externas, com suporte a modo claro/escuro) — consolida os resultados das 7 questões numa única página, com filtros interativos (período, canal, Top N, produto de referência) recalculados em JavaScript a partir de `dashboard/data.js` (dados granulares gerados de `database/*.csv`). Os dois arquivos precisam ficar na mesma pasta. Detalhes de como inicializar em `dashboard/README.md`.

## Material complementar

`notebooks/00_analise_completa.ipynb` — notebook único cobrindo as 7 questões, comentado, com o resultado de cada consulta/gráfico recalculado ao vivo (não é texto colado de uma execução anterior). Não reimplementa a lógica: importa e executa diretamente `sql/q1_orders_eda.sql`, `sql/q4_customer_loyalty.sql`, `sql/q5_calendar_weekday_sales.sql` e os módulos `src/q2_generate_schema.py`, `src/q3_load_postgres.py`, `src/q6_demand_forecast.py`, `src/q7_recommender.py`.

Para reexecutar do zero:

```bash
docker compose up -d   # a célula da Questão 3 carrega de verdade num PostgreSQL local
jupyter nbconvert --to notebook --execute --inplace notebooks/00_analise_completa.ipynb
```

(A Questão 3 é a única célula com uma dependência externa — se o Postgres não estiver no ar, só essa célula falha; o resto do notebook não depende de banco.)

`notebooks/01_q1_eda_orders.ipynb` — versão anterior, focada só na Questão 1.
