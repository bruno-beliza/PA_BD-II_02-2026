# Sistema Acadêmico PostgreSQL - Projeto de Banco de Dados

Este repositório contém o projeto completo do banco de dados relacional para um Sistema Acadêmico Universitário em PostgreSQL, atendendo a todos os requisitos de DDL, restrições de integridade, carga massiva de dados e consultas avançadas.

## Como Subir o Banco do Zero

### Pré-requisitos
- PostgreSQL 14+ instalado (ou contêiner Docker).

### Instalação via PostgreSQL Nativo (psql)

Execute os scripts na sequência numérica indicada:

```bash
# 1 - Executar o script 00_SQL_FULL.sql, o qual contem:

# 1.1 - Criação do Banco de Dados:
psql -U postgres -c "CREATE DATABASE sistema_academico;"

# 2.2 - Executar DDL (Estrutura e Restrições)
Seção SCRIPT 01: DDL E RESTRIÇÕES DE INTEGRIDADE

# 3. Carregar Dados de Teste (generate_series)
Seção SCRIPT 02: CARGA DE DADOS (150 Alunos, 12 Turmas, 450+ Matrículas)

# 4. Executar Consultas Analíticas
Seção SCRIPT 03: CONSULTAS ANALÍTICAS (10 SELECTs)

# 5. Gerar Evidências de EXPLAIN
Seção SCRIPT 04: EVIDÊNCIAS DE EXECUÇÃO (EXPLAIN ANALYZE)

```

### Instalação via Docker Compose (Opcional)

```bash
docker run --name pg-academico -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sistema_academico -p 5432:5432 -d postgres:15

```

## Estrutura e Recursos Implementados
1. DDL Completo (Seção SCRIPT 01): 15 tabelas com Chaves Primárias, Estrangeiras (ON DELETE CASCADE/RESTRICT), CHECK, UNIQUE e Tipos Especiais (TIMERANGE).

2. Carga de Dados (Seção SCRIPT 02): Uso intensivo de generate_series inserindo 150 alunos, 12 turmas e mais de 400 matrículas.

3. Consultas Avançadas (Seção SCRIPT 03):

- Junção Externa (LEFT JOIN) com Agregação (Q3).

- Window Functions: DENSE_RANK(), PERCENT_RANK() (Q5) e LAG() (Q6).

- Consultas Recursivas (WITH RECURSIVE): Árvore de pré-requisitos (Q7) e Aptidão para cursar disciplinas (Q8).

---