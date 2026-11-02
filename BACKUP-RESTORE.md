# Guia de Backup e Restauração - PostgreSQL (Terminal do Contêiner)

Este documento estabelece o procedimento padrão para execução de backup e restauração do banco de dados `sistema_academico`, incluindo as configurações globais de segurança (Roles e Permissões).

## 📌 Pré-requisitos

* Acesso ao terminal interativo do contêiner (ex: via aba *Terminal* do Docker Desktop, Portainer, ou usando `docker exec -it <BD2_Postgres> /bin/bash`).
* Credenciais de um usuário administrador (ex: `admin` ou `postgres`).

---

## ⚙️ Configuração de Autenticação Automática (`.pgpass`)

Para evitar a digitação manual de senhas e permitir a execução fluida, deve-se configurar o arquivo `.pgpass` dentro do próprio contêiner.

1. **Criação do arquivo:**
   Gere o arquivo oculto com as credenciais executando o comando abaixo:
   ```bash
   echo '*:5432:*:admin:@DM!N' > ~/.pgpass
   ```

2. **Permissões de segurança (Obrigatório):**
   O PostgreSQL exige que o arquivo tenha permissões estritas de leitura apenas para o dono.
   ```bash
   chmod 0600 ~/.pgpass
   ```

---

## 📦 Fase 1: Procedimento de Backup (Extração)

O backup deve ser realizado em duas etapas para garantir a persistência das **Roles Globais** (usuários e perfis) independentemente dos dados estruturais do banco.

### 1.1. Exportação das Roles Globais

Os papéis de segurança pertencem ao cluster do banco. Deve-se exportar apenas as roles antes dos dados.

```bash
pg_dumpall -U admin --roles-only > 01_roles_backup.sql
```

### 1.2. Exportação dos Dados e Estrutura

Deve-se utilizar o formato customizado (`-Fc`), que comprime os dados e mitiga riscos de corrupção estrutural.

```bash
pg_dump -U admin -Fc sistema_academico > 02_banco_backup.dump
```

---

## 🛠️ Fase 2: Procedimento de Restauração (Recuperação do Zero)

Em cenários de falha crítica, testes ou migração, os passos abaixo devem ser seguidos rigorosamente na ordem apresentada.

### 2.1. Restauração das Roles Globais

As roles devem ser recriadas antes da importação do banco, evitando falhas em políticas de RLS e concessões de permissões (`GRANTs`).

```bash
psql -U admin -d postgres -f 01_roles_backup.sql
```
*(Nota: a restauração de roles globais geralmente exige o superusuário `postgres`)*

### 2.2. Criação do Banco de Dados Limpo

Deve-se preparar o cluster instanciando um banco vazio para receber a carga.

```bash
psql -U admin -d postgres -c "CREATE DATABASE sistema_academico;"
```

### 2.3. Restauração de Estrutura e Dados

Utiliza-se o utilitário `pg_restore` com a flag `-1` (single-transaction). Esta prática garante que, diante de qualquer erro na execução, toda a transação seja revertida (rollback), impedindo que o banco de dados seja restaurado de forma parcial ou corrompida.

```bash
pg_restore -U admin -d sistema_academico -1 02_banco_backup.dump
```

---

## 📤 Fase 3: Exportação dos Backups para a Máquina Host (Retenção Segura)

Como os backups foram gerados na Fase 1 dentro do sistema de arquivos do contêiner, eles serão perdidos se o contêiner for destruído. É fundamental copiá-los para a sua máquina física (host). 

Abra um terminal **na sua máquina local** (fora do contêiner) e execute:

```bash
# Copiar o backup das roles
docker cp BD2_Postgres:/01_roles_backup.sql ./01_roles_backup.sql

# Copiar o backup do banco de dados
docker cp BD2_Postgres:/02_banco_backup.dump ./02_banco_backup.dump
```
*(Nota: O caminho de origem `/` assume que os comandos de backup foram rodados na raiz do contêiner. Ajuste o caminho se tiver navegado para outra pasta antes do backup).*