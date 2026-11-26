# Escolaridade dos candidatos e eleição de prefeitos em 2024

Trabalho final de Econometria I (FGV EESP), de João Pedro Dantas e Pedro Vasconcelos.

## Arquivos
- `Codigo_definitivo.R`: código completo. A Parte 1 (comentada) mostra como a base foi construída a partir dos dados brutos do TSE e do IBGE. A Parte 2 roda a análise.
- `base_final.rds`: base final (14.696 candidatos, 19 variáveis), lida direto do repositório pelo código.

## Como reproduzir
1. Abra o `Codigo_definitivo.R` no RStudio (precisa de internet).
2. Instale os pacotes, se preciso: `install.packages(c("car", "lmtest", "AER", "stargazer"))`.
3. Rode tudo (Ctrl + Shift + Enter). As tabelas saem no Console e as figuras são salvas na pasta de trabalho.

## Dados brutos
- TSE (dadosabertos.tse.jus.br), eleições 2024: candidatos, candidatos complementar, votação por candidato, bens, despesas contratadas e tabela de municípios.
- IBGE: PIB dos Municípios (2010-2023).
