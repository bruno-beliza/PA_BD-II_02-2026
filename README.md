# Sistema Acadêmico PostgreSQL - Projeto de Banco de Dados II

Este repositório contém o projeto completo de um banco de dados relacional para um Sistema Acadêmico Universitário em PostgreSQL. O projeto atende a todos os requisitos de modelagem (DDL), restrições de integridade, carga de dados (DML), automação via Triggers, segurança com RLS, consultas avançadas e análise de performance.

## 📁 Estrutura de Arquivos

A arquitetura do projeto foi consolidada nos seguintes arquivos principais:

*   `docker-compose.yaml`: Orquestração da infraestrutura (PostgreSQL 18 + pgAdmin 4).
*   `01_CRIACAO_CARGA.sql`: Script unificado contendo DDL completo (tabelas, enums, views, materialized views), automação (Triggers), DML (carga de 100 alunos e centenas de matrículas via `generate_series`) e Segurança (Roles, GRANTs e Row-Level Security).
*   `02_CONSULTAS.sql`: Script contendo as 10 consultas obrigatórias de complexidade crescente (Junções, CTEs Recursivas, Funções de Janela) e validações de integridade.
*   **`03_EXPLAIN_ANALYZE.sql`**: **Arquivo próprio e isolado** contendo as evidências de plano de execução e custo (`EXPLAIN ANALYZE VERBOSE`) para todas as consultas do projeto.
*   `BACKUP-RESTORE.md`: Manual oficializado com procedimentos de extração e recuperação de dados via CLI do Docker.

---

## 🚀 Como Subir o Banco do Zero

O ambiente é 100% dockerizado. Para iniciar do zero, siga o passo a passo abaixo:

### Passo 1: Subir a Infraestrutura
No terminal, navegue até a pasta onde está o arquivo `docker-compose.yaml` e execute:
```bash
docker-compose up -d
```
*O Docker baixará as imagens e criará os contêineres `BD2_Postgres` e `BD2_pgAdmin`. O banco de dados `sistema_academico` será criado automaticamente pelas variáveis de ambiente.*

### Passo 2: Executar a Criação e Carga de Dados (Script 01)
Aguarde alguns segundos para o banco iniciar completamente. Em seguida, injete o script principal diretamente no contêiner:
```bash
docker exec -i BD2_Postgres psql -U admin -d sistema_academico < 01_CRIACAO_CARGA.sql
```
*Este comando criará toda a estrutura, as regras automáticas (Triggers), as políticas de segurança e populará o banco com os dados de teste.*

### Passo 3: Executar Consultas e Evidências de Performance (Scripts 02 e 03)
Com o banco populado, você pode rodar os relatórios e as validações de performance:
```bash
# Executar as consultas acadêmicas
docker exec -i BD2_Postgres psql -U admin -d sistema_academico < 02_CONSULTAS.sql

# Gerar as evidências de performance (EXPLAIN ANALYZE)
docker exec -i BD2_Postgres psql -U admin -d sistema_academico < 03_EXPLAIN_ANALYZE.sql
```

---

## 🔑 Acesso Gráfico e Credenciais

Caso prefira inspecionar o banco e rodar os scripts visualmente, o **pgAdmin 4** já está configurado.

**Acesso ao pgAdmin (Navegador):**
*   **URL:** `http://localhost:5050`
*   **Login:** `admin@iesb.edu.br`
*   **Senha:** `@DM!N`

**Conexão do Servidor no pgAdmin:**
*   **Host/Endereço:** `postgres` *(nome do serviço no docker-compose)*
*   **Porta:** `5432`
*   **Database:** `sistema_academico`
*   **Username:** `admin`
*   **Password:** `@DM!N`

*(Nota: Para conexões externas via DBeaver, DataGrip ou VSCode, utilize `localhost` e a porta mapeada `5433`)*