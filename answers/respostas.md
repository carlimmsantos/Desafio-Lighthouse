# Respostas — Desafio Lighthouse (LH Nautical)

## Questão 1 — EDA inicial da tabela `orders`

### Parte 1 — Visão geral
- **Quantidade total de linhas:** 48.998
- **Quantidade total de colunas:** 13
- **Intervalo de datas (`created_at`):** 2020-01-01 01:19:28 até 2026-12-31 23:43:09

### Parte 2 — Análise de `total`
- **Valor mínimo:** 32,62
- **Valor máximo:** 127.262,02
- **Valor médio:** 28.704,99

### Questão 1.1 — SQL
Ver `sql/q1_orders_eda.sql` (executado via DuckDB direto sobre `database/orders.csv`, sem nenhuma tabela intermediária, e sem qualquer limpeza/tratamento).

### Questão 1.2 — Validação
**Valor médio registrado em `total`: R$ 28.704,99**

### Questão 1.3 / Parte 3 — Interpretação e diagnóstico de confiabilidade

**Resposta curta ao Sr. Almir: parcialmente. Dá para começar a olhar os números, mas não para decidir sozinho com a tabela `orders` isolada — faltam nulos importantes disfarçados de "normal" e uma data claramente inconsistente.**

**Outliers em `total`:**
Aplicando a regra de outlier por IQR (1,5x), o limite superior fica em ~R$ 82.597. Encontramos **452 pedidos (≈0,9% da base)** acima desse limite, chegando a R$ 127.262,02. Não há valores negativos nem zerados. Dado que a LH Nautical vende itens de alto ticket (motores de popa, lanchas e acessórios náuticos), esses valores altos **provavelmente são vendas legítimas de itens caros**, não erros de digitação — mas isso não pode ser confirmado sem cruzar com `order_items`/`products` para ver se o valor é coerente com os itens do pedido. Recomendo tratar como "outliers a investigar", não descartar de cara.

**Qualidade dos dados (nulos/inconsistências):**
- `salesperson_id` está nulo em **24.131 linhas (≈49%)**. Isso não é necessariamente um erro: 34.342 dos 48.998 pedidos (≈70%) são do canal `ecommerce`, que naturalmente não tem vendedor associado. Ainda assim, é um nulo que precisa ser documentado como "esperado" antes de qualquer análise de performance de vendedores, senão distorce médias por vendedor.
- Todas as outras colunas (`id`, `total`, `status`, `created_at` etc.) estão 100% preenchidas — bom sinal de completude nos campos centrais.
- **Achado mais crítico: a data máxima de `created_at` é 2026-12-31, cerca de 5 meses no futuro em relação à data atual (2026-08-12).** Pedidos com data de criação no futuro são, por definição, inconsistentes — indicam erro de carga/geração de dados ou timestamps de teste/simulação que não deveriam estar misturados com dados reais.
- A tabela também mistura pedidos com `status` = `paid`, `confirmed`, `cancelled` e `draft`. Se a pergunta de negócio for "faturamento", pedidos `cancelled` e `draft` (juntos ≈15% da base) provavelmente não deveriam entrar na soma sem um filtro explícito — hoje a coluna `total` não distingue receita realizada de receita potencial.

**A tabela está pronta para análise?**
Não sozinha. `orders` isolada serve bem para uma leitura exploratória de volume e ordem de grandeza (que foi exatamente o que fizemos aqui), mas para decisões de negócio ela **exige, no mínimo**: (1) filtrar/segmentar por `status` antes de somar receita, (2) investigar os 452 outliers cruzando com `order_items`, e (3) tratar a inconsistência de datas futuras antes de qualquer série temporal. Também exige relacionamento com outras tabelas (`customers`, `order_items`, `payments`) para responder perguntas mais ricas do que agregados simples de `orders`.

---

## Questão 2 — Geração do `schema.sql`

**Modelo:** 24 tabelas, cobrindo cadastro (clientes, endereços, fornecedores, locais, funcionários), catálogo (marcas, categorias, produtos, variantes, atributos), vendas (pedidos, itens, pagamentos, notas fiscais), devoluções, compras (pedidos de compra, itens, recebimentos) e estoque (níveis e movimentações).

### Questão 2.1 — Código Python

`src/q2_generate_schema.py` (executar com `python src/q2_generate_schema.py` a partir da raiz do projeto; aceita opcionalmente um diretório de CSVs como argumento, default `database/`). Apenas biblioteca padrão (`csv`, `re`, `decimal`, `pathlib`, `sys`) — sem pandas.

**Como funciona (data-driven, não hardcoded):** o script varre `*.csv` no diretório informado; para cada arquivo, lê o header (nomes de coluna) e **todas** as linhas (não uma amostra) via `csv.reader`, e para cada coluna infere o tipo tentando, nessa ordem: `BOOLEAN` (só `TRUE`/`FALSE`/`t`/`f`) → `TIMESTAMP` (`YYYY-MM-DD HH:MM:SS`) → `DATE` (`YYYY-MM-DD`) → `INTEGER`/`BIGINT` → `NUMERIC(p,s)` → `VARCHAR(n)`/`TEXT`. A nulidade (`NOT NULL`) é `True` só se a coluna nunca aparecer vazia em nenhuma linha do CSV inteiro. A coluna `id`, quando existe, vira `PRIMARY KEY`. O nome de cada tabela é o nome do arquivo sem `.csv`. Reexecutar o script sempre regenera `sql/q2_schema.sql` do zero, lendo os CSVs de novo — o schema é derivado do dado, não de um modelo escrito à mão.

**Duas armadilhas de inferência puramente automática que precisei tratar explicitamente:**
- **Zero à esquerda ⇒ é código, não número.** `customers.tax_id` tem 223 valores como `"00429721404"` (CPF com zero à esquerda). Convertidos para `NUMERIC`/`INTEGER`, esse zero seria perdido silenciosamente (dado corrompido). Qualquer valor com zero à esquerda força a coluna inteira para `VARCHAR`.
- **Dígitos longos demais ⇒ é identificador, não número.** `fiscal_invoices.nfe_access_key` tem 44 dígitos — muito além do que `BIGINT`/`NUMERIC` do Postgres suportam de forma segura (limite de 18 dígitos adotado aqui). Acima desse limite, a coluna vira `VARCHAR`.
- **Quantidades com formato misto** (`order_items` só usa inteiros, mas `stock_movements.quantity`/`product_variants.weight_kg` misturam `"39"` e `"6.120"` na mesma coluna): tratado como `NUMERIC`, com o escopo (precisão/escala) calculado a partir do maior número de casas inteiras/decimais observado, mais uma margem de segurança de 2 dígitos de precisão.

**Limitação assumida (documentada no header do `.sql` gerado):** a detecção é puramente estrutural, por arquivo — não infere chaves estrangeiras (`REFERENCES`) nem chaves primárias compostas entre tabelas (ex.: `variant_attribute_values`, `stock_levels` saem sem PK composta, já que a granularidade da relação não está no CSV isolado). Isso é uma troca deliberada: o enunciado pede detecção de colunas a partir do CSV, e inferir FK exigiria heurística arriscada (ex.: "termina em `_id`") que erraria silenciosamente em casos como `stock_movements.reference_id` (aponta para tabelas diferentes dependendo do `reference_table`).

**Validação:** rodei o script contra `database/` (gera as 24 tabelas a partir dos 24 CSVs), testei a sintaxe das 48 instruções via DuckDB e, por fim, executei de ponta a ponta contra um Postgres real (`docker compose up -d` + `docker exec -i <container> psql -U postgres -d lh_nautical < sql/q2_schema.sql`) — as 24 tabelas foram criadas sem nenhum erro.

---

## Questão 3 — Carga dos CSVs em PostgreSQL

**Código:** `src/q3_load_postgres.py` (executar com `docker compose up -d` seguido de `python src/q3_load_postgres.py`, a partir da raiz do projeto).

**Como funciona:**
- Conecta via `psycopg2` usando parâmetros de variáveis de ambiente (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`), com defaults que já batem com o Postgres local do `docker-compose.yml` do projeto.
- Reaplica `sql/q2_schema.sql` (recria as 24 tabelas do zero — idempotente, graças ao `DROP ... CASCADE` da Questão 2).
- Carrega cada CSV com `COPY ... FROM STDIN` (via `copy_expert`), muito mais rápido que `INSERT` linha a linha para os ~430 mil registros da base (destaque: `order_items` com 147.320 linhas e `stock_movements` com 115.312). `NULL ''` no `COPY` só instrui o Postgres a interpretar campo vazio do CSV como `NULL` — não é remoção/tratamento de dado, é a semântica padrão de parsing de CSV, e nenhuma outra limpeza (nulos, caracteres especiais) é aplicada, como pedia o enunciado.
- A ordem de carga vem da mesma descoberta de arquivos do `src/q2_generate_schema.py` (`sorted(glob("*.csv"))`) — não depende de ordem de dependência entre tabelas porque o schema gerado na Questão 2 não declara chaves estrangeiras (`REFERENCES`), então não há restrição de "tabela pai antes da filha" a respeitar aqui.
- Ao final de cada tabela, compara `COUNT(*)` no banco com a contagem de linhas do CSV de origem e falha (`RuntimeError`) se houver qualquer divergência — a carga só é considerada "concluída com sucesso" se 100% das linhas dos 24 CSVs foram inseridas.

**Ajuste feito durante a validação (pós-reescrita da Questão 2):** quando o `src/q2_generate_schema.py` foi reescrito para ler os CSVs de fato em vez de usar um modelo Python hardcoded, o `src/q3_load_postgres.py` quebrou — ele importava `TABLES` desse módulo (`from q2_generate_schema import TABLES`) só para saber a ordem de carga que respeitasse FKs, lista que deixou de existir na nova versão data-driven. Corrigido trocando essa importação por descoberta direta dos CSVs em `database/`, já que o schema novo não tem FK para ordenar.

**Validação:** carga executada de ponta a ponta em um Postgres local (`docker compose up -d` com `postgres:16-alpine`) — as 24 tabelas carregaram com contagem de linhas idêntica à dos CSVs, e conferi que acentos/caracteres especiais chegam intactos no banco (ex.: `employees.full_name` = "Maria Luísa Rodrigues").

### Questão 3.2 — Validação

**Total de linhas somadas de `customers` + `orders` + `order_items` + `payments`:**

| Tabela | Linhas |
|---|---|
| customers | 2.000 |
| orders | 48.998 |
| order_items | 147.320 |
| payments | 53.546 |
| **Total** | **251.864** |

**Resposta: 251864**

---

## Questão 4 — Análise de clientes fiéis

### Questão 4.1 — Código SQL

Ver `sql/q4_customer_loyalty.sql` (DuckDB, lendo os CSVs diretamente, mesmo padrão da Questão 1). O script monta 4 tabelas temporárias em sequência — `items_with_category` (item → categoria), `customer_orders` (faturamento/frequência/ticket médio), `customer_diversity` (diversidade) e `top10_clientes_fieis` (filtro de elite + ranking) — e duas consultas finais reaproveitam essas tabelas em vez de repetir a lógica.

**Top 10 clientes fiéis (ticket médio, diversidade ≥ 13 categorias):**

| # | customer_id | Faturamento Total | Frequência | Ticket Médio | Diversidade |
|---|---|---|---|---|---|
| 1 | 22 | 1.087.838,44 | 26 | 41.839,94 | 14 |
| 2 | 1477 | 916.262,58 | 22 | 41.648,30 | 14 |
| 3 | 929 | 1.082.775,89 | 26 | 41.645,23 | 14 |
| 4 | 1116 | 655.737,20 | 16 | 40.983,58 | 14 |
| 5 | 1691 | 815.471,30 | 20 | 40.773,57 | 14 |
| 6 | 774 | 726.127,99 | 18 | 40.340,44 | 14 |
| 7 | 1470 | 1.040.553,09 | 26 | 40.021,27 | 14 |
| 8 | 1599 | 997.616,46 | 25 | 39.904,66 | 14 |
| 9 | 965 | 677.297,78 | 17 | 39.841,05 | 14 |
| 10 | 1722 | 1.146.455,22 | 29 | 39.532,94 | 14 |

Curiosamente, todos os 10 clientes fiéis têm exatamente **14 categorias distintas** (o máximo possível na base, já que `categories.csv` tem 15 categorias no total) — o filtro de elite (≥13) já isola naturalmente o topo da distribuição de diversidade antes mesmo de olhar o ticket médio.

**Categoria com maior `SUM(quantity)` entre esses 10 clientes:** `Hélices` (category_id 8), com **492 itens** — a mais vendida em volume dentro do grupo de elite, à frente de Coletes Salva-Vidas (393) e Eletrônica Náutica (392).

### Questão 4.2 — Explicação

**Como cheguei nas categorias mais vendidas (mapeamento da cadeia de chaves):**
Não existe uma coluna `category_id` direto em `order_items` — é preciso atravessar 4 tabelas para ligar um item comprado à sua categoria:
`order_items.order_id → orders.id` (para saber de quem é o pedido) e, em paralelo, `order_items.product_variant_id → product_variants.id → product_variants.product_id → products.id → products.category_id → categories.id`. Materializei essa cadeia uma única vez na tabela temporária `items_with_category` (um JOIN de 5 tabelas) para não repetir a lógica nas duas consultas seguintes — tanto a diversidade quanto a soma de quantidade por categoria são derivadas dela.

**Lógica de filtro de diversidade mínima:**
Agrupei `items_with_category` por `customer_id` e apliquei `COUNT(DISTINCT category_id)` — a contagem é de categorias *distintas*, não de itens ou pedidos, então um cliente que comprou 50 itens da mesma categoria conta diversidade 1, não 50. Guardei o resultado em `customer_diversity` e só depois apliquei `WHERE diversidade_categorias >= 13` ao juntar com as métricas de faturamento/ticket médio — o filtro de elite é aplicado *depois* de calcular a diversidade completa de cada cliente, nunca antes (senão o `COUNT(DISTINCT ...)` ficaria truncado).

**Como garanti que a contagem de itens refletisse apenas os Top 10:**
A soma de `quantity` por categoria não é feita sobre a base inteira de clientes — a consulta final faz `JOIN items_with_category iwc ... JOIN top10_clientes_fieis t ON t.customer_id = iwc.customer_id`, ou seja, um **INNER JOIN contra a tabela já materializada com exatamente os 10 clientes** selecionados pelo ranking (filtro de elite + `ORDER BY ticket_medio DESC, customer_id ASC LIMIT 10`). Como o JOIN é por `customer_id` e `top10_clientes_fieis` tem exatamente 10 linhas, qualquer item de um cliente fora desse grupo é descartado automaticamente antes do `SUM(quantity)` — não há risco de vazamento de outros clientes nem de duplicar linhas, já que a relação `top10_clientes_fieis.customer_id` é única (uma linha por cliente).

**Validação:** confirmei que não há empate entre o 10º (ticket médio 39.532,94) e o 11º colocado (39.508,14) na fronteira do corte — o critério de desempate por `customer_id` crescente está implementado no `ORDER BY`, mas não chegou a ser necessário neste conjunto de dados.

---

## Questão 5 — Dimensão de calendário: pior dia da semana (lojas físicas)

### Questão 5.1 — Código SQL

Ver `sql/q5_calendar_weekday_sales.sql` (DuckDB, lendo `database/orders.csv` diretamente). O script gera a dimensão de calendário com `generate_series` entre `MIN(placed_at)` e `MAX(placed_at)` do arquivo, mapeia cada data para o dia da semana em português, agrega vendas diárias do canal `pos`, faz `LEFT JOIN` do calendário com as vendas e usa `COALESCE(v.valor_venda, 0)` para tratar dias sem registro como venda zero.

**Resultado (abordagem correta, com calendário completo):**

| Dia da semana | Dias no período | Dias sem venda | Média de vendas/dia |
|---|---|---|---|
| **Quinta-feira** | 366 | 20 | **R$ 157.154,32** ← pior |
| Domingo | 365 | 12 | R$ 157.616,13 |
| Segunda-feira | 365 | 7 | R$ 158.241,15 |
| Sábado | 365 | 11 | R$ 164.858,27 |
| Terça-feira | 365 | 8 | R$ 166.118,83 |
| Sexta-feira | 365 | 10 | R$ 170.193,68 |
| Quarta-feira | 366 | 10 | R$ 173.605,44 |

**Resposta ao Sr. Almir:** o pior dia da semana é **Quinta-feira**, com média de R$ 157.154,32/dia — mas está tecnicamente empatado com Domingo (R$ 157.616,13) e Segunda-feira (R$ 158.241,15): as três médias ficam dentro de uma faixa de ~0,7% uma da outra, um intervalo pequeno demais para afirmar com confiança que só um dia é "o pior". Antes de fechar a loja num dia específico, eu recomendaria olhar a variância/desvio-padrão diário desses três dias, não só a média pontual.

**Comparação com o método do estagiário** (`GROUP BY` direto em `orders`, ignorando dias sem venda — reproduzido para fins de diagnóstico, não é a resposta final):

| Dia da semana | Dias *com* venda | Média "ingênua" |
|---|---|---|
| Quarta-feira | 356 | R$ 178.481,99 |
| Sexta-feira | 355 | R$ 174.987,87 |
| Sábado | 354 | R$ 169.980,98 |
| Terça-feira | 357 | R$ 169.841,38 |
| Quinta-feira | 346 | R$ 166.238,38 |
| Domingo | 353 | R$ 162.974,19 |
| Segunda-feira | 358 | **R$ 161.335,26** ← "pior" (errado) |

O ranking muda completamente: o método ingênuo aponta Segunda-feira como pior e teria escondido Quinta-feira do radar — exatamente o viés descrito no cenário (dias sem venda somem da média em vez de contarem como zero).

### Questão 5.2 — Explicação

**Por que usar uma tabela de datas em vez de agrupar direto em `orders`:**
`orders` só contém uma linha por *pedido que aconteceu*. Um dia em que a loja física abriu e não vendeu nada simplesmente não gera nenhuma linha — não existe um "pedido de valor zero" registrado. Um `GROUP BY` direto na tabela de vendas calcula a média como `SOMA / COUNT(dias com pelo menos um pedido)`, e esse denominador já exclui os dias de venda zero por construção. A única forma de forçar esses dias a entrarem no cálculo é ter, de antemão, uma lista independente e completa de todas as datas do período (a dimensão de calendário) e fazer `LEFT JOIN` a partir dela — assim todo dia do calendário aparece no resultado, e o `COALESCE(valor_venda, 0)` garante que a ausência de pedido vire zero explícito em vez de sumir da agregação.

**O que aconteceria com a média se um dia da semana tivesse muitos dias sem venda:**
A média ficaria artificialmente **inflada para cima**, exatamente o erro do estagiário. Como o `COUNT` do `GROUP BY` ingênuo só soma dias com venda, quanto mais dias "vazios" um dia da semana tiver, menor o denominador em relação ao numerador real — a média deixa de refletir "quanto a loja vende, em média, em cada Domingo" e passa a refletir "quanto a loja vende, em média, nos Domingos em que ela vendeu algo", o que é uma pergunta diferente e sistematicamente mais otimista. No limite, um dia da semana com 90% dos dias zerados teria sua média calculada sobre só os 10% de dias bons, escondendo exatamente o problema que a Diretoria quer enxergar para decidir se vale a pena manter a loja aberta.

---

## Questão 6 — Previsão de demanda: baseline de média móvel (Bússola de Bordo 702)

**Nota de qualidade de dados (antes de tudo):** `products.csv` tem **duas linhas com o nome exato "Bússola de Bordo 702"** — id 74 (`created_at` 2025-01-27) e id 240 (`created_at` 2026-06-22). É uma colisão de nome nos dados sintéticos, não uma variação de SKU. Usei o **id 74**, porque o id 240 só "nasceria" no catálogo em junho/2026 — depois de todo o período de treino e teste deste modelo (até 31/03/2026) — logo não pode ser o produto sobre o qual o Sr. Almir está pedindo previsão de estoque para o 1º trimestre de 2026.

### Questão 6.1 — Código Python

Ver `src/q6_demand_forecast.py` (executar com `python src/q6_demand_forecast.py`). Principais etapas:
- `load_unified_dataset()`: junta `order_items` → `orders` (data do pedido) → `product_variants` → `products`, filtrando pelas variantes do produto alvo.
- `monthly_quantity()`: agrega `SUM(order_items.quantity)` por mês (`placed_at` truncado para `YYYY-MM`).
- `moving_average_baseline()`: **o baseline pedido no enunciado** — para cada mês de teste, prevê a média dos 3 meses **imediatamente anteriores**, usando sempre valores reais já observados (nunca a própria previsão).
- `seasonal_naive_baseline()`: **comparação extra** (não é o entregável pedido, foi feita para testar empiricamente se um modelo alternativo simples se saía melhor) — prevê o mês alvo como o valor real do mesmo mês um ano antes (ex.: previsão de jan/2026 = valor real de jan/2025).
- `mean_absolute_error()`: MAE entre previsto e real no 1º trimestre de 2026, calculado para os dois modelos.

**Resultado (previsto x real, Q1 2026) — os dois modelos lado a lado:**

| Mês | Real | Média móvel 3m | Erro (méd. móvel) | Naive sazonal | Erro (naive sazonal) |
|---|---|---|---|---|---|
| Jan/2026 | 69 | 25,33 | 43,67 | 25 | 44 |
| Fev/2026 | 42 | 39,67 | 2,33 | 21 | 21 |
| Mar/2026 | 45 | 41,67 | 3,33 | 70 | 25 |
| **Total** | **156** | **106,67** | — | **116** | — |

**MAE média móvel 3m = 16,44 unidades/mês.**
**MAE naive sazonal = 30,00 unidades/mês.**

**A média móvel venceu — e isso contraria a hipótese inicial** de que um modelo sazonal simples resolveria o problema do pico de janeiro. Olhando a série histórica de janeiros do produto (2020 a 2025: 22, 13, 4, 15, 20, 25), nenhum ano anterior teve um janeiro perto de 69 — o salto de 2026 é atípico mesmo em relação ao padrão sazonal dos anos anteriores, não só em relação à média móvel recente. Um naive sazonal (que aposta tudo em um único ponto do ano anterior) herda esse ruído inteiro e erra tanto quanto ou mais que a média móvel nos 3 meses.

**5a. O baseline é adequado para esse produto?**
Parcialmente, e a comparação com o naive sazonal reforça isso em vez de contradizer. Para Fevereiro e Março o erro da média móvel é pequeno (2,33 e 3,33 unidades — bem abaixo de 10% do valor real), mas em Janeiro o modelo erra feio: previu 25,33 e o real foi 69 (erro de 63%). O motivo é sazonalidade: dezembro/2025 teve só 14 unidades (o mês mais fraco do trimestre anterior), e uma média móvel simples arrasta esse valor baixo para a previsão de janeiro — exatamente o mês em que a demanda historicamente dispara (verão, alta temporada náutica, o mesmo padrão que já tinha estourado o estoque de Coletes Salva-Vidas no cenário do Sr. Almir). Testamos se um modelo sazonal simples resolveria isso e **não resolveu** (MAE quase o dobro) — o problema de janeiro/2026 não é só "a média móvel não vê sazonalidade", é que a demanda desse mês específico quebrou o próprio padrão sazonal histórico do produto. Para decisão de compra de estoque, nenhum dos dois baselines é confiável sozinho para o mês de pico — ambos "sentem" a virada tarde demais ou apostam errado num único ponto de referência.

**5b. Limitação do método:**
Média móvel é um indicador **defasado** (lagging): ela só reage a uma mudança de patamar depois que essa mudança já aconteceu e entrou na janela — nunca antecipa uma virada de tendência ou um pico sazonal. É por isso que Fevereiro/Março (meses em que a média já "absorveu" o valor real de janeiro) ficam bons, mas janeiro (que depende só do passado de baixa) fica ruim. Cogitamos que um componente sazonal explícito resolveria isso, mas o teste com naive sazonal mostrou o oposto: **um modelo sazonal ingênuo é frágil a ruído** — como se apoia em um único ponto histórico por mês-alvo, um ano atípico (2025, aparentemente um janeiro fraco para este produto) se propaga inteiro para a previsão. O caminho mais robusto seria um modelo que combine tendência recente **e** sazonalidade suavizada por múltiplos anos (ex.: Holt-Winters, ou a média de "mesmo mês nos últimos N anos" em vez de um único ano) — não um naive sazonal de ponto único.

### Questão 6.2 — Validação

**Soma total da previsão para o 1º trimestre de 2026 (arredondada): 107**

(25,33 + 39,67 + 41,67 = 106,67 → 107)

### Questão 6.3 — Explicação

**Como o baseline foi construído:**
Para cada mês do período de teste (Jan, Fev, Mar de 2026), a previsão é a **média aritmética simples das 3 observações mensais imediatamente anteriores** na série de vendas mensais do produto (`quantity` somada por mês). Por exemplo, a previsão de janeiro/2026 é a média de outubro, novembro e dezembro de 2025; a de fevereiro/2026 é a média de novembro/2025, dezembro/2025 e janeiro/2026.

**Como evitei data leakage:**
A janela de 3 meses é sempre construída com `monthly[monthly.index < month]` — ou seja, só entram no cálculo os meses estritamente **anteriores** ao mês que está sendo previsto, nunca o próprio mês nem meses futuros. Importante: a previsão de fevereiro/2026 usa o valor **real** de janeiro/2026 (não a previsão que o modelo fez para janeiro) — isso é uma previsão *walk-forward* legítima, não vazamento, porque em fevereiro/2026 o valor real de janeiro/2026 já é passado e estaria disponível na prática (o mês fechou). O que nunca acontece é o modelo "espiar" o valor do próprio mês-alvo ou de meses posteriores a ele.

**Uma limitação do modelo proposto:**
Além de ser um indicador defasado (não antecipa mudanças de patamar, como discutido no item 5b), a média móvel de 3 meses dá **peso igual** aos 3 meses da janela e ignora completamente qualquer padrão sazonal de anos anteriores — ela não "sabe" que janeiro costuma ser mês de pico. Um histórico de 65 meses (2020–2025) estava disponível e não foi aproveitado para captar esse padrão anual. Testamos isso na prática comparando com um naive sazonal (mesmo mês do ano anterior) e o resultado foi pior (MAE 30,00 vs. 16,44) — o que não significa que sazonalidade seja irrelevante, mas sim que capturá-la exige mais que um único ano de referência: um modelo que suavize o componente sazonal por vários anos (não um ponto único) provavelmente superaria os dois baselines testados aqui.

---

## Questão 7 — Sistema de recomendação ("quem comprou isso, também levou...")

### Questão 7.1 — Código Python

Ver `src/q7_recommender.py` (executar com `python src/q7_recommender.py`). Bibliotecas usadas: `pandas`, `numpy` (via pandas/sklearn) e `sklearn.metrics.pairwise.cosine_similarity`. Etapas:
- `load_customer_product_purchases()`: junta `order_items → orders` (para saber o cliente) e `order_items → product_variants → products` (para saber o produto), na granularidade de **produto**, não de variante/SKU.
- `build_user_item_matrix()`: `drop_duplicates(["customer_id", "product_id"])` antes de pivotar — garante presença/ausência (1/0), ignorando quantidade e repetição de compra — e pivota para uma matriz 2000 clientes × 500 produtos.
- `compute_product_similarity()`: transpõe a matriz (produto vira linha, cliente vira coluna) e aplica `cosine_similarity` produto × produto.
- `top_similar_products()`: ordena a linha do produto de referência por similaridade decrescente, remove ele mesmo, retorna os top 5.

**Resultado (Top 5 produtos mais similares a "Motor de Popa 1949"):**

| # | Produto | Similaridade de cosseno | Clientes em comum |
|---|---|---|---|
| 1 | Motor de Popa 5331 | 0,2566 | 106 |
| 2 | Cabo Náutico 2105 | 0,2562 | 103 |
| 3 | Vela Mestra 1913 | 0,2558 | 100 |
| 4 | Cabo Náutico 9048 | 0,2393 | 99 |
| 5 | GPS Plotter 6249 | 0,2377 | 98 |

("Motor de Popa 1949" tem 397 compradores distintos, de um total de 2.000 clientes na base.)

### Questão 7.2 — Validação

**Produto com maior similaridade ao "Motor de Popa 1949": Motor de Popa 5331** (similaridade de cosseno = 0,2566).

### Questão 7.3 — Explicação

**Como a matriz foi construída:**
Linhas = `customer_id`, colunas = `product_id`. Para chegar no par (cliente, produto), atravessei a cadeia `orders.customer_id` (quem comprou) e `order_items.product_variant_id → product_variants.product_id` (o que foi comprado, na granularidade de produto — duas variantes/SKUs do mesmo produto contam como o mesmo item). Antes de pivotar, apliquei `drop_duplicates(["customer_id", "product_id"])`, então a célula é sempre 1 (comprou ao menos uma vez) ou 0 (nunca comprou) — quantidade e número de pedidos são descartados de propósito, como pedia o enunciado.

**O que significa a similaridade de cosseno nesse contexto:**
Cada produto é representado por um vetor binário de 2.000 posições (uma por cliente), com 1 nas posições dos clientes que o compraram. A similaridade de cosseno mede o **cosseno do ângulo entre dois desses vetores** — na prática, para vetores binários isso equivale a quão proporcionalmente parecido é o público que compra os dois produtos: se todo cliente que compra o produto A também compra o produto B (e vice-versa), o cosseno tende a 1; se os dois públicos quase não se sobrepõem, tende a 0. Diferente de uma simples contagem de clientes em comum, o cosseno normaliza pelo tamanho de cada vetor (quantos compradores cada produto tem no total), então um produto de nicho com poucos compradores não é injustamente penalizado frente a um produto muito popular.

**Uma limitação desse método:**
Com 2.000 clientes e 500 produtos, cada produto tem em média ~271 compradores — a base é bastante densa, e mesmo os pares mais similares aqui ficam com cosseno em torno de 0,25 (não perto de 1). Isso é sintoma de um problema conhecido de recomendação por co-ocorrência: quando muitos produtos são comprados por muitos clientes diferentes "meio que por acaso" (alta popularidade geral, base sintética sem um padrão forte de afinidade), o sinal de similaridade genuína fica diluído em ruído estatístico — dois motores populares podem parecer "similares" só porque ambos são amplamente comprados, não porque exista uma relação real de complementaridade (como a "defensa" do cenário da Marina). Esse método também sofre de **cold-start**: um produto novo, sem histórico de compra, tem vetor todo-zero e não pode ser comparado a nada até acumular vendas.

---

*Questões 1 a 7 do desafio respondidas. Falta apenas o dashboard final consolidando os resultados.*
