# Sistema Acadêmico PostgreSQL - Projeto de Banco de Dados

Este repositório contém o projeto completo do banco de dados relacional para um Sistema Acadêmico Universitário em PostgreSQL, atendendo a todos os requisitos de DDL, restrições de integridade, carga massiva de dados e consultas avançadas.

## Como Subir o Banco do Zero

### Pré-requisitos
- PostgreSQL 14+ instalado (ou contêiner Docker).

### Instalação via PostgreSQL Nativo (psql)

Execute os scripts na sequência numérica indicada:

```bash
# 1. Criar o Banco de Dados
psql -U postgres -c "CREATE DATABASE sistema_academico;"

# 2. Executar DDL (Estrutura e Restrições)
psql -U postgres -d sistema_academico -f 01_schema.sql

# 3. Carregar Dados de Teste (generate_series)
psql -U postgres -d sistema_academico -f 02_seeds.sql

# 4. Executar Consultas Analíticas
psql -U postgres -d sistema_academico -f 03_queries.sql

# 5. Gerar Evidências de EXPLAIN
psql -U postgres -d sistema_academico -f 04_explain.sql

```

### Instalação via Docker Compose (Opcional)

```bash
docker run --name pg-academico -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=sistema_academico -p 5432:5432 -d postgres:15

```

## Estrutura e Recursos Implementados
1. DDL Completo (01_schema.sql): 15 tabelas com Chaves Primárias, Estrangeiras (ON DELETE CASCADE/RESTRICT), CHECK, UNIQUE e Tipos Especiais (TIMERANGE).

2. Carga de Dados (02_seeds.sql): Uso intensivo de generate_series inserindo 150 alunos, 12 turmas e mais de 400 matrículas.

3. Consultas Avançadas (03_queries.sql):

- Junção Externa (LEFT JOIN) com Agregação (Q3).

- Window Functions: DENSE_RANK(), PERCENT_RANK() (Q5) e LAG() (Q6).

- Consultas Recursivas (WITH RECURSIVE): Árvore de pré-requisitos (Q7) e Aptidão para cursar disciplinas (Q8).

---