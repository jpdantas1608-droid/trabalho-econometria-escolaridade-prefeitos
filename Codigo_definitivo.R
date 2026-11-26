# Trabalho de Econometria I - Escolaridade e eleição de prefeitos em 2024
# Pedro Vasconcelos e João Pedro Dantas
# Código definitivo
#
# COMO RODAR
# 1. Deixe este arquivo e a base_final.rds na mesma pasta
# 2. No RStudio: Session > Set Working Directory > To Source File Location
#    (ou abra o arquivo .Rproj da pasta, que já faz isso)
# 3. Rode tudo. A Parte 1 está comentada e não precisa ser rodada
#
# PARTE 1 (comentada): construção da base_final.rds a partir dos dados brutos
# Fica aqui para mostrar como a base foi montada. Para refazer a base do zero, baixe os arquivos abaixo
# numa pasta "Dados brutos", tire os # da Parte 1 e rode
# TSE (https://dadosabertos.tse.jus.br), eleições 2024:
#   consulta_cand_2024_BRASIL.csv, consulta_cand_complementar_2024_BRASIL.csv,
#   votacao_candidato_munzona_2024_BRASIL.csv, bem_candidato_2024_BRASIL.csv,
#   despesas_contratadas_candidatos_2024_BRASIL.csv, municipio_tse_ibge.csv
# IBGE (PIB dos Municípios): pib_municipios_2010_2023.xlsx
# ============================================================================================
#
#
# # Pacotes necessários
# # install.packages("readxl") # Só precisa rodar uma vez
# library(readxl)
#
#
#
# # Candidatos
# cand <- read.csv2("Dados brutos/consulta_cand_2024_BRASIL.csv", fileEncoding = "latin1", colClasses = "character")
# cand <- subset(cand, CD_CARGO == "11" & CD_TIPO_ELEICAO == "2") # Só prefeitos da eleição ordinária
#
# # Quem foi ao 2º turno aparece duas vezes, ficamos com a linha do 2º turno
# cand <- cand[order(cand$NR_TURNO, decreasing = TRUE), ]
# cand <- cand[!duplicated(cand$SQ_CANDIDATO), ]
# nrow(cand)
#
# cand$eleito <- ifelse(cand$DS_SIT_TOT_TURNO == "ELEITO", 1, 0) # Variável dependente
#
# cand <- cand[, c("SQ_CANDIDATO", "SG_UF", "SG_UE", "NM_UE", "SG_PARTIDO", "CD_GENERO", "CD_GRAU_INSTRUCAO",
#                  "CD_COR_RACA", "CD_OCUPACAO", "DS_OCUPACAO", "eleito")]
#
#
# # Informações complementares (reeleição, idade, bens e prestação de contas)
# comp <- read.csv2("Dados brutos/consulta_cand_complementar_2024_BRASIL.csv", fileEncoding = "latin1", colClasses = "character")
# comp <- comp[, c("SQ_CANDIDATO", "ST_REELEICAO", "NR_IDADE_DATA_POSSE", "ST_DECLARAR_BENS", "ST_PREST_CONTAS")]
# comp <- comp[!duplicated(comp$SQ_CANDIDATO), ]
#
# base <- merge(cand, comp, by = "SQ_CANDIDATO", all.x = TRUE)
#
#
# # Votos válidos no 1º turno
# vot <- read.csv2("Dados brutos/votacao_candidato_munzona_2024_BRASIL.csv", fileEncoding = "latin1", colClasses = "character")
# vot <- subset(vot, CD_CARGO == "11" & NR_TURNO == "1")
# vot$votos <- as.numeric(vot$QT_VOTOS_NOMINAIS_VALIDOS)
# votos <- aggregate(votos ~ SQ_CANDIDATO, data = vot, FUN = sum) # Soma dos votos de todas as zonas
#
# base <- merge(base, votos, by = "SQ_CANDIDATO", all.x = TRUE)
# base$votos[is.na(base$votos)] <- 0
#
#
# # População: candidatos com votos válidos, em municípios com 1 eleito
# base <- subset(base, votos > 0)
#
# eleitos_mun <- aggregate(eleito ~ SG_UE, data = base, FUN = sum)
# table(eleitos_mun$eleito) # Municípios com 0 eleitos tiveram a eleição anulada
# names(eleitos_mun)[2] <- "n_eleitos"
# base <- merge(base, eleitos_mun, by = "SG_UE", all.x = TRUE)
# base <- subset(base, n_eleitos == 1)
# nrow(base)
#
# # Número de candidatos por município
# base$um <- 1
# n_cand <- aggregate(um ~ SG_UE, data = base, FUN = sum)
# names(n_cand)[2] <- "n_candidatos"
# base <- merge(base, n_cand, by = "SG_UE", all.x = TRUE)
#
#
# # Patrimônio (soma dos bens declarados)
# bens <- read.csv2("Dados brutos/bem_candidato_2024_BRASIL.csv", fileEncoding = "latin1", colClasses = "character")
# bens$valor <- as.numeric(gsub(",", ".", bens$VR_BEM_CANDIDATO))
# patrimonio <- aggregate(valor ~ SQ_CANDIDATO, data = bens, FUN = sum)
# names(patrimonio)[2] <- "patrimonio"
#
# base <- merge(base, patrimonio, by = "SQ_CANDIDATO", all.x = TRUE)
# base$patrimonio[is.na(base$patrimonio) & base$ST_DECLARAR_BENS == "N"] <- 0 # Declarou não ter bens
#
#
# # Gasto de campanha (soma das despesas contratadas)
# # O arquivo é muito grande, então lemos só as colunas que vamos usar
# arq <- "Dados brutos/despesas_contratadas_candidatos_2024_BRASIL.csv"
# nomes <- names(read.csv2(arq, fileEncoding = "latin1", nrows = 1))
# classes <- ifelse(nomes %in% c("SQ_CANDIDATO", "SQ_DESPESA", "VR_DESPESA_CONTRATADA"), "character", "NULL")
# desp <- read.csv2(arq, fileEncoding = "latin1", colClasses = classes)
# desp$valor <- as.numeric(gsub(",", ".", desp$VR_DESPESA_CONTRATADA))
#
# # Cada nota fiscal (SQ_DESPESA) aparece em várias linhas, uma por item, então somamos todas as linhas
# gasto <- aggregate(valor ~ SQ_CANDIDATO, data = desp, FUN = sum)
# names(gasto)[2] <- "gasto"
# rm(desp, vot, bens) # Liberando memória
#
# base <- merge(base, gasto, by = "SQ_CANDIDATO", all.x = TRUE)
# base$gasto[is.na(base$gasto) & base$ST_PREST_CONTAS == "S"] <- 0 # Prestou contas e não teve despesa
#
#
# # PIB per capita do município em 2023
# mun <- read.csv2("Dados brutos/municipio_tse_ibge.csv", fileEncoding = "latin1", colClasses = "character")
# mun <- mun[, c("CD_MUNICIPIO_TSE", "CD_MUNICIPIO_IBGE")]
# base <- merge(base, mun, by.x = "SG_UE", by.y = "CD_MUNICIPIO_TSE", all.x = TRUE)
#
# pib <- as.data.frame(read_excel("Dados brutos/pib_municipios_2010_2023.xlsx"))
# pib <- subset(pib, Ano == 2023)
# pib <- pib[, c(7, 40)] # Código do município e PIB per capita
# names(pib) <- c("CD_MUNICIPIO_IBGE", "pib_pc")
# pib$CD_MUNICIPIO_IBGE <- as.character(pib$CD_MUNICIPIO_IBGE)
#
# base <- merge(base, pib, by = "CD_MUNICIPIO_IBGE", all.x = TRUE)
#
#
# # Organizando as variáveis
# base$idade <- as.numeric(base$NR_IDADE_DATA_POSSE)
# base$mulher <- ifelse(base$CD_GENERO == "4", 1, 0)
# base$reeleicao <- ifelse(base$ST_REELEICAO == "S", 1, 0)
#
# # Escolaridade (2 = lê e escreve, 3 = fund. incompleto, 4 = fund. completo, 5 = médio incompleto,
# # 6 = médio completo, 7 = superior incompleto, 8 = superior completo)
# base$escol <- as.numeric(base$CD_GRAU_INSTRUCAO)
# base$escol[base$escol < 0] <- NA # Não divulgável
#
# # Cor/raça (1 = branca, 2 = preta, 3 = parda, 4 = amarela, 5 = indígena, 6 = não informado)
# base$cor <- as.numeric(base$CD_COR_RACA)
#
# # Ocupação em grupos (códigos de ocupação do TSE)
# politica <- c(275, 278, 277, 276, 201, 203, 291) # prefeito, vereador, deputado, senador, cargo em comissão
# empresario <- c(257, 169, 125, 206, 303, 301, 237, 170, 411, 402, 403, 413) # empresário, comerciante, administrador, gerente...
# nivel_superior <- c(131, 111, 101, 124, 115, 113, 117, 112, 134, 103, 114, 132, 121, 102,
#                     264, 263, 222, 255, 133, 104, 107, 118, 123, 127, 159, 200, 271) # advogado, médico, engenheiro...
# educacao <- c(265, 266, 142, 143, 230, 235, 144) # professores, pedagogo, diretor de escola
# setor_publico <- c(298, 297, 296, 922, 233, 232, 921, 292, 213, 293, 109, 258, 295) # servidores, policiais, militares
# agro <- c(601, 234, 602, 606, 153, 604, 227) # agricultor, produtor agropecuário, pecuarista...
#
# base$ocup <- as.numeric(base$CD_OCUPACAO)
# base$ocupacao <- 7 # Outros
# base$ocupacao[base$ocup %in% politica] <- 1
# base$ocupacao[base$ocup %in% empresario] <- 2
# base$ocupacao[base$ocup %in% nivel_superior] <- 3
# base$ocupacao[base$ocup %in% educacao] <- 4
# base$ocupacao[base$ocup %in% setor_publico] <- 5
# base$ocupacao[base$ocup %in% agro] <- 6
#
# # Nomes finais das variáveis
# names(base)[names(base) == "SQ_CANDIDATO"] <- "id"
# names(base)[names(base) == "SG_UF"] <- "uf"
# names(base)[names(base) == "SG_UE"] <- "municipio"
# names(base)[names(base) == "NM_UE"] <- "nome_mun"
# names(base)[names(base) == "CD_MUNICIPIO_IBGE"] <- "cod_ibge"
# names(base)[names(base) == "SG_PARTIDO"] <- "partido"
# names(base)[names(base) == "ocup"] <- "ocupacao_tse"
#
#
# # Conferindo a base
# nrow(base)
# sum(duplicated(base$id))
# table(aggregate(eleito ~ municipio, data = base, FUN = sum)$eleito) # Todo município deve ter 1 eleito
# table(base$escol)
# table(base$cor)
# table(base$ocupacao)
# summary(base$idade)
# colSums(is.na(base))
#
#
# # Salvando a base final
# base_final <- base[, c("id", "uf", "municipio", "nome_mun", "cod_ibge", "eleito",
#                        "escol", "idade", "mulher", "reeleicao", "cor", "partido", "ocupacao", "ocupacao_tse",
#                        "patrimonio", "gasto", "pib_pc", "n_candidatos", "votos")]
#
# saveRDS(base_final, "base_final.rds")

# ============================================================================================
# PARTE 2: análise descritiva, regressões, testes e robustez
# ============================================================================================
# Pacotes necessários
# install.packages(c("car", "lmtest", "AER", "stargazer")) # Só precisa rodar uma vez
library(car)
library(lmtest)
library(AER)
library(stargazer)

# Lendo a base final (gerada pela Parte 1) direto do repositório do GitHub (precisa de internet)
base <- readRDS(url("https://raw.githubusercontent.com/jpdantas1608-droid/trabalho-econometria-escolaridade-prefeitos/main/base_final.rds"))

# Tirando os candidatos sem PIB per capita do município (são 2)
# Sem isso, a regressão 1 (que não usa o PIB) teria 2 observações a mais que as outras,
# e as colunas da tabela não seriam comparáveis. Filtrando aqui, toda a análise usa a mesma amostra
sum(is.na(base$pib_pc)) # Quantos candidatos não têm PIB per capita
base[is.na(base$pib_pc), c("municipio", "nome_mun", "eleito")] # Quem são (conferir se algum município fica sem eleito)
base <- subset(base, !is.na(pib_pc))
nrow(base) # Número de candidatos depois do filtro


# Criando novas colunas na base
base$idade2 <- base$idade^2 # Idade ao quadrado
base$lpatrimonio <- log(base$patrimonio + 1) # Log do patrimônio (somando um para não criar missings quando o valor é zero)
base$lgasto <- log(base$gasto + 1) # Log do gasto de campanha (somando um pelo mesmo motivo)
base$lpib_pc <- log(base$pib_pc) # Log do PIB per capita do município

# Criando dummies para quem não informou patrimônio ou gasto e colocando o log igual a zero, para não perder ninguém da base
base$patr_na <- ifelse(is.na(base$patrimonio), 1, 0)
base$lpatrimonio[is.na(base$lpatrimonio)] <- 0
base$gasto_na <- ifelse(is.na(base$gasto), 1, 0)
base$lgasto[is.na(base$lgasto)] <- 0
base$gasto_zero <- ifelse(base$gasto == 0 & !is.na(base$gasto), 1, 0) # Dummy para quem declarou gasto zero (o log trata mal o zero)

# Criando colunas de dummy para cada nível de escolaridade (o ensino médio fica de fora, é a referência)
base$fund <- ifelse(base$escol <= 4, 1, 0) # Lê e escreve ou fundamental
base$medio <- ifelse(base$escol == 5 | base$escol == 6, 1, 0)
base$sup_inc <- ifelse(base$escol == 7, 1, 0)
base$sup_comp <- ifelse(base$escol == 8, 1, 0)

# Criando colunas de dummy para cada uma das cores (branca é a referência)
base$branca <- ifelse(base$cor == 1, 1, 0)
base$preta <- ifelse(base$cor == 2, 1, 0)
base$parda <- ifelse(base$cor == 3, 1, 0)
base$outras_cor <- ifelse(base$cor >= 4, 1, 0) # Amarela, indígena e não informado juntas, porque são poucos candidatos

# Criando colunas de dummy para cada grupo de ocupação (empresário e comércio é a referência)
base$oc_politica <- ifelse(base$ocupacao == 1, 1, 0)
base$oc_empresario <- ifelse(base$ocupacao == 2, 1, 0)
base$oc_superior <- ifelse(base$ocupacao == 3, 1, 0)
base$oc_educacao <- ifelse(base$ocupacao == 4, 1, 0)
base$oc_publico <- ifelse(base$ocupacao == 5, 1, 0)
base$oc_agro <- ifelse(base$ocupacao == 6, 1, 0)
base$oc_outros <- ifelse(base$ocupacao == 7, 1, 0)

# Estado e partido como fator, para o lm() criar uma dummy para cada um sozinho
# No partido tiramos espaços e símbolos dos nomes (ex.: "PC do B" vira "PCdoB"), senão o teste de hipótese não lê o nome
base$partido <- gsub("[^A-Za-z]", "", base$partido)
base$partido <- as.factor(base$partido)
base$uf <- as.factor(base$uf)


# ANÁLISE DESCRITIVA

nrow(base) # Número de candidatos
length(unique(base$municipio)) # Número de municípios
mean(base$n_candidatos) # Em média, quantos candidatos cada candidato enfrenta na sua disputa

# Médias e desvios-padrão das principais variáveis
vars <- c("eleito", "sup_comp", "idade", "mulher", "reeleicao", "patrimonio", "gasto", "pib_pc", "n_candidatos")
summary(base[, vars])
sapply(base[, vars], mean, na.rm = TRUE) # Médias
sapply(base[, vars], sd, na.rm = TRUE) # Desvios-padrão

# Quantos candidatos há em cada nível de escolaridade
table(base$escol)
prop.table(table(base$escol)) # Em proporção

# Proporção de eleitos em cada grupo
aggregate(eleito ~ escol, data = base, FUN = mean)
aggregate(eleito ~ cor, data = base, FUN = mean)
aggregate(eleito ~ mulher, data = base, FUN = mean)
aggregate(eleito ~ reeleicao, data = base, FUN = mean)

# Em cada grupo de ocupação: proporção com superior completo e proporção de eleitos
aggregate(cbind(sup_comp, eleito) ~ ocupacao, data = base, FUN = mean)
table(base$ocupacao)

# Comparando quem informou e quem não informou o patrimônio
aggregate(cbind(eleito, sup_comp, reeleicao) ~ patr_na, data = base, FUN = mean)
table(base$patr_na)

# Correlações entre as principais variáveis (só com quem informou patrimônio e gasto)
completos <- subset(base, patr_na == 0 & gasto_na == 0)
cor(completos[, c("eleito", "sup_comp", "idade", "mulher", "reeleicao", "lpatrimonio", "lgasto")])

# Gráficos
hist(base$idade, main = "Idade dos candidatos", xlab = "Idade (anos)", ylab = "Candidatos")
hist(base$lpatrimonio[base$patr_na == 0], main = "Patrimônio declarado", xlab = "Log do patrimônio + 1", ylab = "Candidatos")


# TABELAS E GRÁFICOS PARA O TRABALHO

# Tabela 1: médias das variáveis para todos os candidatos, para os eleitos e para os não eleitos
vars_t1 <- c("sup_comp", "sup_inc", "medio", "fund", "idade", "mulher", "branca", "preta", "parda",
             "reeleicao", "patr_na", "gasto_zero", "n_candidatos")
todos <- sapply(base[, vars_t1], mean)
eleitos <- sapply(base[base$eleito == 1, vars_t1], mean)
nao_eleitos <- sapply(base[base$eleito == 0, vars_t1], mean)
tabela1 <- data.frame(Todos = todos, Eleitos = eleitos, Nao_eleitos = nao_eleitos)

# Patrimônio e gasto entram pela mediana (a média é puxada por poucos valores enormes)
tabela1["patrimonio_mediana", ] <- c(median(base$patrimonio, na.rm = TRUE),
                                     median(base$patrimonio[base$eleito == 1], na.rm = TRUE),
                                     median(base$patrimonio[base$eleito == 0], na.rm = TRUE))
tabela1["gasto_mediana", ] <- c(median(base$gasto, na.rm = TRUE),
                                median(base$gasto[base$eleito == 1], na.rm = TRUE),
                                median(base$gasto[base$eleito == 0], na.rm = TRUE))
tabela1["candidatos", ] <- c(nrow(base), sum(base$eleito == 1), sum(base$eleito == 0))
rownames(tabela1) <- c("Superior completo", "Superior incompleto", "Ensino médio", "Fundamental", "Idade",
                       "Mulher", "Branca", "Preta", "Parda", "Concorre à reeleição", "Patrimônio não informado",
                       "Gasto zero", "Candidatos no município", "Patrimônio (mediana)", "Gasto (mediana)",
                       "Número de candidatos")
colnames(tabela1) <- c("Todos", "Eleitos", "Não eleitos")
round(tabela1, 3)

# Tabela 2: perfil dos candidatos em cada nível de escolaridade
base$nivel <- ifelse(base$fund == 1, "1 Fundamental", ifelse(base$medio == 1, "2 Médio",
              ifelse(base$sup_inc == 1, "3 Sup. incompleto", "4 Sup. completo")))
tabela2 <- aggregate(cbind(eleito, mulher, reeleicao, idade, n_candidatos) ~ nivel, data = base, FUN = mean)
tabela2$candidatos <- as.numeric(table(base$nivel))
tabela2$lpib_medio <- aggregate(lpib_pc ~ nivel, data = base, FUN = mean)$lpib_pc
tabela2

# Figura 1: proporção de eleitos por escolaridade
barplot(100 * tabela2$eleito, names.arg = c("Fundamental", "Médio", "Sup. incompleto", "Sup. completo"),
        main = "Candidatos eleitos por escolaridade", ylab = "% eleitos", ylim = c(0, 50), col = "gray70")
abline(h = 100 * mean(base$eleito), lty = 2) # Linha tracejada: média de todos os candidatos
dev.copy(png, "Figura1_eleitos_escolaridade.png", width = 1600, height = 1000, res = 200) # Mostra no Plots e salva o que está na tela
dev.off()

# Figura 2: proporção de candidatos com superior completo por faixa de PIB per capita do município
base$faixa_pib <- cut(base$pib_pc, quantile(base$pib_pc, seq(0, 1, 0.2), na.rm = TRUE),
                      labels = c("1º (mais pobres)", "2º", "3º", "4º", "5º (mais ricos)"), include.lowest = TRUE)
sup_pib_tab <- aggregate(cbind(sup_comp, n_candidatos) ~ faixa_pib, data = base, FUN = mean)
sup_pib_tab
barplot(100 * sup_pib_tab$sup_comp, names.arg = sup_pib_tab$faixa_pib,
        main = "Superior completo por quintil de PIB per capita",
        ylab = "% com superior completo", xlab = "Quintil de PIB per capita", ylim = c(0, 80), col = "gray70")
dev.copy(png, "Figura2_superior_pib.png", width = 1600, height = 1000, res = 200) # Mostra no Plots e salva o que está na tela
dev.off()

# Figura 3: proporção de eleitos com e sem superior completo, conforme o número de candidatos na disputa
base$n_cand_grupo <- ifelse(base$n_candidatos >= 5, 5, base$n_candidatos)
fig3 <- aggregate(eleito ~ sup_comp + n_cand_grupo, data = subset(base, n_candidatos >= 2), FUN = mean)
fig3_matriz <- matrix(100 * fig3$eleito, nrow = 2) # Linhas: sem e com superior completo
fig3_matriz
barplot(fig3_matriz, beside = TRUE, names.arg = c("2", "3", "4", "5 ou mais"),
        legend.text = c("Sem superior completo", "Com superior completo"), args.legend = list(x = "topright", bty = "n"),
        main = "Candidatos eleitos, por número de candidatos na disputa",
        xlab = "Candidatos no município", ylab = "% eleitos", ylim = c(0, 60), col = c("gray80", "gray40"))
dev.copy(png, "Figura3_eleitos_ncandidatos.png", width = 1600, height = 1000, res = 200) # Mostra no Plots e salva o que está na tela
dev.off()

# Figura 4: matriz de correlação entre as principais variáveis (só quem informou patrimônio e gasto)
vars_cor <- c("eleito", "sup_comp", "idade", "mulher", "preta", "parda", "reeleicao",
              "lpatrimonio", "lgasto", "n_candidatos", "lpib_pc")
nomes_cor <- c("Eleito", "Sup. completo", "Idade", "Mulher", "Preta", "Parda", "Reeleição",
               "Log patrimônio", "Log gasto", "Nº candidatos", "Log PIB pc")
m_cor <- cor(subset(base, patr_na == 0 & gasto_na == 0)[, vars_cor])
k <- length(vars_cor)
# Mapa de calor: quanto mais forte a cor, maior a correlação (azul negativa, vermelho positiva)
par(mar = c(8, 8, 3, 2))
image(1:k, 1:k, m_cor[, k:1], zlim = c(-1, 1), col = hcl.colors(21, "Blue-Red 3", rev = TRUE),
      axes = FALSE, xlab = "", ylab = "", main = "Matriz de correlação")
axis(1, at = 1:k, labels = nomes_cor, las = 2)
axis(2, at = 1:k, labels = rev(nomes_cor), las = 1)
text(rep(1:k, k), rep(1:k, each = k), round(m_cor[, k:1], 2), cex = 0.8) # Valores dentro de cada quadrado
dev.copy(png, "Figura4_correlacao.png", width = 1800, height = 1600, res = 200) # Mostra no Plots e salva o que está na tela
dev.off()
par(mar = c(5, 4, 4, 2) + 0.1) # Volta as margens ao padrão, para as próximas figuras não herdarem as da Figura 4

# Proporção de candidatos com superior completo conforme o número de candidatos na disputa
aggregate(sup_comp ~ n_cand_grupo, data = base, FUN = mean)

# Chance base: se todos os candidatos de uma disputa fossem iguais, cada um teria chance 1/n de vencer
base$chance_base <- 1 / base$n_candidatos
aggregate(cbind(eleito, chance_base, n_candidatos) ~ sup_comp, data = base, FUN = mean) # Taxa observada x taxa esperada

# Arredondando as medianas de patrimônio e gasto para reais inteiros
tabela1[c("Patrimônio (mediana)", "Gasto (mediana)"), ] <- round(tabela1[c("Patrimônio (mediana)", "Gasto (mediana)"), ])

# Tabela 1 para o Overleaf
stargazer(round(tabela1, 3), summary = FALSE, type = "text", decimal.mark = ",", digit.separator = ".")


# REGRESSÕES - MODELO DE PROBABILIDADE LINEAR
# Seguindo a orientação da professora: no lugar das 5.528 dummies de município, controlamos por
# dummies de estado (UF) e características do município que já estão na base: PIB per capita e número de candidatos

# Interação do superior completo com o log do PIB per capita, para a regressão 7
# Na regressão 7, o coeficiente de sup_comp sozinho é o efeito com log do PIB = 0 (sem leitura); o efeito é lido nos percentis abaixo
base$sup_pib <- base$sup_comp * base$lpib_pc

# Regressão 1: só escolaridade, sem nenhum controle
reg1 <- lm(eleito ~ fund + sup_inc + sup_comp, data = base)
summary(reg1)
bptest(reg1) # Teste de heterocedasticidade - BP. Aqui não rejeita a 5% (p = 0,052); a evidência está na regressão 4
coeftest(reg1, vcov. = vcovHC(reg1, type = "HC1")) # Erros-padrão robustos

# Regressão 2: acrescentando estado, PIB per capita e número de candidatos (características da disputa)
reg2 <- lm(eleito ~ fund + sup_inc + sup_comp + lpib_pc + n_candidatos + uf, data = base)
coeftest(reg2, vcov. = vcovHC(reg2, type = "HC1"))

# Regressão 3: acrescentando idade, gênero e cor
reg3 <- lm(eleito ~ fund + sup_inc + sup_comp + lpib_pc + n_candidatos + uf
           + idade + idade2 + mulher + preta + parda + outras_cor, data = base)
coeftest(reg3, vcov. = vcovHC(reg3, type = "HC1"))

# Regressão 4: acrescentando reeleição, patrimônio e partido. Essa é a nossa especificação principal
f4 <- "eleito ~ fund + sup_inc + sup_comp + lpib_pc + n_candidatos + uf + idade + idade2 + mulher + preta + parda + outras_cor + reeleicao + lpatrimonio + patr_na + partido"
reg4 <- lm(as.formula(f4), data = base)
summary(reg4)
bptest(reg4) # Teste de heterocedasticidade - BP. Rejeitamos H0 de homocedasticidade, como a teoria prevê

# Teste de heterocedasticidade - White
resid2 <- resid(reg4)^2 # Resíduos ao quadrado
yhat <- predict(reg4) # Valor predito pelo modelo
yhat2 <- predict(reg4)^2 # Valor predito pelo modelo ao quadrado
summary(lm(resid2 ~ yhat + yhat2)) # Olhando o teste F desta regressão, rejeitamos homocedasticidade, confirmando a teoria

V4 <- vcovHC(reg4, type = "HC1")
coeftest(reg4, vcov. = V4)[c("fund", "sup_inc", "sup_comp", "lpib_pc", "n_candidatos", "idade", "idade2", "mulher",
                             "preta", "parda", "outras_cor", "reeleicao", "lpatrimonio", "patr_na"), ] # Sem estados e partidos

# Regressão 5: principal + ocupação (pode ser um caminho pelo qual a escolaridade age, por isso fica separada)
reg5 <- lm(as.formula(paste(f4, "+ oc_politica + oc_superior + oc_educacao + oc_publico + oc_agro + oc_outros")), data = base)
coeftest(reg5, vcov. = vcovHC(reg5, type = "HC1"))

# Regressão 6: principal + gasto de campanha (gasto e vitória se determinam juntos, por isso fica separada)
reg6 <- lm(as.formula(paste(f4, "+ lgasto + gasto_na + gasto_zero")), data = base)
coeftest(reg6, vcov. = vcovHC(reg6, type = "HC1"))

# Regressão 7: principal + interação do superior completo com o PIB per capita
reg7 <- lm(as.formula(paste(f4, "+ sup_pib")), data = base)
V7 <- vcovHC(reg7, type = "HC1")
coeftest(reg7, vcov. = V7)["sup_pib", ]


# TESTES DE HIPÓTESE CONJUNTOS (na regressão 4, corrigindo por heterocedasticidade)

h01 <- c("fund = 0", "sup_inc = 0", "sup_comp = 0") # A escolaridade importa, no conjunto?
linearHypothesis(reg4, h01, vcov. = V4)

h02 <- c("sup_comp = sup_inc") # Ter o diploma é diferente de ter só começado a faculdade?
linearHypothesis(reg4, h02, vcov. = V4)

h03 <- c("preta = 0", "parda = 0", "outras_cor = 0") # A cor importa?
linearHypothesis(reg4, h03, vcov. = V4)

h04 <- names(coef(reg4))[grepl("partido", names(coef(reg4)))] # Nomes dos coeficientes de partido
h04 <- paste(h04, "= 0") # O partido importa?
linearHypothesis(reg4, h04, vcov. = V4)


# Efeito marginal do superior completo em municípios pobres (10%), medianos (50%) e ricos (90%)
pib_mun <- base$lpib_pc[!duplicated(base$municipio)] # Um valor de PIB por município
percentis <- quantile(pib_mun, c(0.10, 0.50, 0.90), na.rm = TRUE)
coef(reg7)["sup_comp"] + coef(reg7)["sup_pib"] * percentis

# Testando se o efeito do superior completo é significativo no município pobre (10%), mediano (50%) e rico (90%)
h05 <- paste0("sup_comp + ", percentis[1], "*sup_pib = 0")
linearHypothesis(reg7, h05, vcov. = V7)
h06 <- paste0("sup_comp + ", percentis[2], "*sup_pib = 0")
linearHypothesis(reg7, h06, vcov. = V7)
h07 <- paste0("sup_comp + ", percentis[3], "*sup_pib = 0")
linearHypothesis(reg7, h07, vcov. = V7)


# Efeito marginal da idade na probabilidade de ser eleito aos 30, 50 e 70 anos
coef(reg4)["idade"] + 2*coef(reg4)["idade2"]*c(30, 50, 70)

h08 <- c("idade + 100*idade2 = 0") # O efeito marginal da idade aos 50 anos é significativo?
linearHypothesis(reg4, h08, vcov. = V4)

h09 <- c("idade = 0", "idade2 = 0") # A idade importa, no conjunto?
linearHypothesis(reg4, h09, vcov. = V4)


# Problema do MPL: quantas probabilidades previstas ficam abaixo de 0 ou acima de 1
prev <- predict(reg4)
summary(prev)
sum(prev < 0)
sum(prev > 1)


# FORMA FUNCIONAL - MPL, PROBIT E LOGIT (mesmas variáveis da regressão 4)

probit1 <- glm(as.formula(f4), family = binomial(link = "probit"), data = base)
coeftest(probit1, vcov. = vcovHC(probit1, type = "HC1"))

logit1 <- glm(as.formula(f4), family = binomial(link = "logit"), data = base)
coeftest(logit1, vcov. = vcovHC(logit1, type = "HC1"))

# Candidato típico: homem, branco, 50 anos, ensino médio, não é prefeito, patrimônio e PIB na média,
# disputa com 3 candidatos em Minas Gerais, do partido com mais candidatos
cand0 <- data.frame(fund = 0, sup_inc = 0, sup_comp = 0, idade = 50, idade2 = 50^2,
                    mulher = 0, preta = 0, parda = 0, outras_cor = 0, reeleicao = 0,
                    lpatrimonio = mean(base$lpatrimonio[base$patr_na == 0]), patr_na = 0,
                    lpib_pc = mean(base$lpib_pc, na.rm = TRUE), n_candidatos = 3, uf = "MG",
                    partido = names(which.max(table(base$partido))))

# Efeito marginal: probabilidade com a característica menos probabilidade sem ela (todo o resto igual)

# Superior completo
cand1 <- cand0
cand1$sup_comp <- 1
ef_sup <- c(predict(reg4, cand1) - predict(reg4, cand0),
            predict(probit1, cand1, type = "response") - predict(probit1, cand0, type = "response"),
            predict(logit1, cand1, type = "response") - predict(logit1, cand0, type = "response"))

# Mulher
cand1 <- cand0
cand1$mulher <- 1
ef_mulher <- c(predict(reg4, cand1) - predict(reg4, cand0),
               predict(probit1, cand1, type = "response") - predict(probit1, cand0, type = "response"),
               predict(logit1, cand1, type = "response") - predict(logit1, cand0, type = "response"))

# Reeleição
cand1 <- cand0
cand1$reeleicao <- 1
ef_reel <- c(predict(reg4, cand1) - predict(reg4, cand0),
             predict(probit1, cand1, type = "response") - predict(probit1, cand0, type = "response"),
             predict(logit1, cand1, type = "response") - predict(logit1, cand0, type = "response"))

efeitos <- rbind(ef_sup, ef_mulher, ef_reel)
colnames(efeitos) <- c("MPL", "Probit", "Logit")
rownames(efeitos) <- c("Superior completo", "Mulher", "Reeleição")
round(100 * efeitos, 2) # Em pontos percentuais

# Pseudo-R2: quanto o modelo melhora o ajuste em relação a um modelo só com constante
1 - probit1$deviance / probit1$null.deviance # Pseudo-R2 do probit
1 - logit1$deviance / logit1$null.deviance # Pseudo-R2 do logit

# Efeito marginal médio (AME): média, nos 14.694 candidatos, da diferença entre a probabilidade prevista
# com e sem a característica, mantendo o resto igual ao de cada candidato. Não depende do candidato típico
# No MPL, o AME é o próprio coeficiente

# Superior completo contra ensino médio (zerando fund e sup_inc nos dois cenários, senão surgem perfis impossíveis)
d1 <- base
d0 <- base
d1$fund <- 0; d1$sup_inc <- 0; d1$sup_comp <- 1
d0$fund <- 0; d0$sup_inc <- 0; d0$sup_comp <- 0
ame_sup <- c(coef(reg4)["sup_comp"],
             mean(predict(probit1, d1, type = "response") - predict(probit1, d0, type = "response")),
             mean(predict(logit1, d1, type = "response") - predict(logit1, d0, type = "response")))

# Mulher
d1 <- base
d0 <- base
d1$mulher <- 1
d0$mulher <- 0
ame_mulher <- c(coef(reg4)["mulher"],
                mean(predict(probit1, d1, type = "response") - predict(probit1, d0, type = "response")),
                mean(predict(logit1, d1, type = "response") - predict(logit1, d0, type = "response")))

# Reeleição
d1 <- base
d0 <- base
d1$reeleicao <- 1
d0$reeleicao <- 0
ame_reel <- c(coef(reg4)["reeleicao"],
              mean(predict(probit1, d1, type = "response") - predict(probit1, d0, type = "response")),
              mean(predict(logit1, d1, type = "response") - predict(logit1, d0, type = "response")))

ame <- rbind(ame_sup, ame_mulher, ame_reel)
colnames(ame) <- c("MPL", "Probit", "Logit")
rownames(ame) <- c("Superior completo", "Mulher", "Reeleição")
round(100 * ame, 2) # Em pontos percentuais

# Conferindo os partidos com quase nenhum eleito (coeficientes enormes no logit indicam quase-separação)
table(base$partido, base$eleito)


# TABELA COM AS 7 REGRESSÕES

# Lista com os erros-padrão robustos de cada regressão
ep <- list(sqrt(diag(vcovHC(reg1, type = "HC1"))), sqrt(diag(vcovHC(reg2, type = "HC1"))),
           sqrt(diag(vcovHC(reg3, type = "HC1"))), sqrt(diag(V4)), sqrt(diag(vcovHC(reg5, type = "HC1"))),
           sqrt(diag(vcovHC(reg6, type = "HC1"))), sqrt(diag(V7)))

stargazer(reg1, reg2, reg3, reg4, reg5, reg6, reg7, se = ep, type = "text", digits = 3,
          keep = c("^fund$", "^sup_inc$", "^sup_comp$", "^sup_pib$", "^lpib_pc$", "^n_candidatos$", "^idade", "^mulher$",
                   "^preta$", "^parda$", "^outras_cor$", "^reeleicao$", "^lpatrimonio$", "^lgasto$", "^oc_"),
          dep.var.caption = "Variável dependente: eleito (1 = eleito prefeito)",
          dep.var.labels.include = FALSE,
          omit.stat = c("ser", "f", "adj.rsq"),
          add.lines = list(c("Dummies de estado", "Não", rep("Sim", 6)),
                           c("Dummies de partido", "Não", "Não", "Não", rep("Sim", 4))),
          notes = "Erros-padrão robustos (HC1). Na coluna (7), só o superior completo interage com o PIB; seu coeficiente é o efeito com log do PIB = 0 (ver efeitos nos percentis no texto).", notes.append = TRUE, notes.label = "Nota:",
          decimal.mark = ",", digit.separator = ".")
# Conferir a ordem das linhas no resultado antes de colocar covariate.labels em português
# Para o Overleaf: trocar type = "text" por type = "latex" e copiar o resultado


# Figura 5: coeficiente do superior completo nas colunas 1 a 6, com intervalo de confiança de 95%
# A coluna 7 fica de fora: lá o coeficiente de sup_comp sozinho não tem leitura direta (efeito com log do PIB = 0)
coef_sup <- c(coef(reg1)["sup_comp"], coef(reg2)["sup_comp"], coef(reg3)["sup_comp"], coef(reg4)["sup_comp"],
              coef(reg5)["sup_comp"], coef(reg6)["sup_comp"])
ep_sup <- c(ep[[1]]["sup_comp"], ep[[2]]["sup_comp"], ep[[3]]["sup_comp"], ep[[4]]["sup_comp"],
            ep[[5]]["sup_comp"], ep[[6]]["sup_comp"])
plot(1:6, 100 * coef_sup, ylim = c(-4, 8), pch = 19, xaxt = "n", xlab = "", ylab = "Superior completo (p.p.)",
     main = "Coeficiente do superior completo em cada especificação (IC de 95%)")
arrows(1:6, 100 * (coef_sup - 1.96 * ep_sup), 1:6, 100 * (coef_sup + 1.96 * ep_sup),
       angle = 90, code = 3, length = 0.05)
abline(h = 0, lty = 2)
axis(1, at = 1:6, labels = c("(1) Bruta", "(2) UF e disputa", "(3) Demografia", "(4) Principal",
                             "(5) Ocupação", "(6) Gasto"), cex.axis = 0.8)
dev.copy(png, "Figura5_coeficientes.png", width = 1600, height = 1000, res = 200) # Mostra no Plots e salva o que está na tela
dev.off()


# TABELA DA FORMA FUNCIONAL (vai para o apêndice)

stargazer(reg4, probit1, logit1, type = "text", digits = 3,
          se = list(sqrt(diag(V4)), sqrt(diag(vcovHC(probit1, type = "HC1"))), sqrt(diag(vcovHC(logit1, type = "HC1")))),
          column.labels = c("MPL", "Probit", "Logit"), model.names = FALSE,
          omit = c("uf", "partido"),
          dep.var.caption = "Variável dependente: eleito (1 = eleito prefeito)",
          dep.var.labels.include = FALSE,
          omit.stat = c("ser", "f", "adj.rsq", "ll", "aic"),
          add.lines = list(c("Dummies de estado e partido", rep("Sim", 3))),
          notes = "Erros-padrão robustos (HC1). Coeficientes do probit e do logit não estão em escala de probabilidade.",
          notes.append = TRUE, notes.label = "Nota:",
          decimal.mark = ",", digit.separator = ".")


# ROBUSTEZ (sempre olhando o coeficiente do superior completo na especificação principal)

# 1. Superior completo contra todos os outros níveis juntos (uma dummy só)
rob1 <- lm(eleito ~ sup_comp + lpib_pc + n_candidatos + uf + idade + idade2 + mulher + preta + parda + outras_cor
           + reeleicao + lpatrimonio + patr_na + partido, data = base)
coeftest(rob1, vcov. = vcovHC(rob1, type = "HC1"))["sup_comp", ]

# 2. Tirando os municípios com dois candidatos marcados como reeleição
n_reel <- aggregate(reeleicao ~ municipio, data = base, FUN = sum)
mun_2reel <- n_reel$municipio[n_reel$reeleicao == 2]
length(mun_2reel)
rob2 <- lm(as.formula(f4), data = subset(base, !(municipio %in% mun_2reel)))
coeftest(rob2, vcov. = vcovHC(rob2, type = "HC1"))["sup_comp", ]

# 3. Patrimônios acima de R$ 500 milhões tratados como não informados (possíveis erros de digitação)
base_out <- base
fora <- base$patrimonio > 5e8 & !is.na(base$patrimonio)
sum(fora)
base_out$lpatrimonio[fora] <- 0
base_out$patr_na[fora] <- 1
rob3 <- lm(as.formula(f4), data = base_out)
coeftest(rob3, vcov. = vcovHC(rob3, type = "HC1"))["sup_comp", ]

