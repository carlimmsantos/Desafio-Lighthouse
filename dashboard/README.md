# Dashboard — LH Nautical

Dashboard executivo estático (HTML + JS puro, sem framework/dependência externa) consolidando os resultados das 7 questões do desafio: EDA de `orders`, schema/carga em PostgreSQL, clientes fiéis, pior dia da semana (lojas físicas), previsão de demanda e sistema de recomendação.

## Arquivos

- `index.html` — a página em si (estrutura, estilo e lógica dos gráficos/filtros).
- `data.js` — dados granulares pré-calculados a partir de `database/*.csv`, que alimentam os filtros interativos (período, canal, Top N, produto de referência).

**Os dois arquivos precisam estar na mesma pasta** — `index.html` carrega `data.js` via `<script src="data.js">`.

## Como inicializar

### Opção 1 — abrir direto (mais simples)

Dê duplo clique em `index.html`, ou arraste o arquivo para dentro do navegador. Não precisa de servidor, internet ou instalação — é uma página `file://` autocontida. Funciona em Chrome, Edge e Firefox.

### Opção 2 — servidor local (caso o navegador bloqueie `file://`)

Alguns navegadores/políticas corporativas restringem scripts locais abertos via `file://`. Se `index.html` abrir em branco ou sem os gráficos, suba um servidor simples a partir desta pasta:

```powershell
cd dashboard
python -m http.server 8000
```

Depois acesse `http://localhost:8000` no navegador. `Ctrl+C` no terminal encerra o servidor.

## O que tem em cada seção

| Seção | Conteúdo | Filtro interativo |
|---|---|---|
| Q1 | Distribuição de status dos pedidos, achados de confiabilidade (nulos, data futura, outliers) | Período (data mín/máx do topo da página) |
| Q2/Q3 | Resumo da geração do schema e da carga em PostgreSQL (tabelas criadas, CSVs carregados) | — |
| Q4 | Top 10 clientes fiéis (ticket médio) e categoria mais comprada pelo grupo | Top N de categorias |
| Q5 | Média de vendas por dia da semana (dimensão de calendário) | Canal (pos / ecommerce / todos), período |
| Q6 | Previsão de demanda (média móvel 3m) x real, Q1/2026 | — (recorte fixo do enunciado) |
| Q7 | Top produtos mais similares a um produto de referência | Produto de referência, Top N |

## Como os dados foram gerados

`data.js` é um snapshot calculado uma vez a partir de `database/*.csv` (não é lido dinamicamente do banco). Se os CSVs de origem mudarem, os números do dashboard **não** se atualizam sozinhos — não existe hoje um script que regenere `data.js` automaticamente; foi montado manualmente a partir dos mesmos cálculos de `sql/q1_orders_eda.sql`, `sql/q4_customer_loyalty.sql`, `sql/q5_calendar_weekday_sales.sql`, `src/q6_demand_forecast.py` e `src/q7_recommender.py`. Os números foram conferidos contra a saída desses scripts/queries (ver `answers/respostas.md`).
