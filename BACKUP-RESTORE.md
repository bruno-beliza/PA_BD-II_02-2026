# Guia de Backup e Restauração - PostgreSQL (Docker)

Este documento estabelece o procedimento padrão para execução de backup e restauração do banco de dados `sistema_academico`, incluindo as configurações globais de segurança (Roles e Permissões). O ambiente presumido opera o PostgreSQL instanciado em um contêiner Docker.

## 📌 Pré-requisitos

* Acesso ao terminal do servidor hospedeiro (host) onde o Docker está em execução.
* Nome ou ID do contêiner do PostgreSQL (referenciado neste guia como `<nome_do_container>`).
* Credenciais de um usuário administrador (ex: `postgres`).

---

## ⚙️ Configuração de Autenticação Automática (`.pgpass`)

Para evitar a exposição de senhas em scripts e permitir a execução automatizada, deve-se configurar o arquivo `.pgpass` na máquina hospedeira.

1. **Criação do arquivo:**
   Criar um arquivo chamado `.pgpass` no diretório home do usuário logado (ex: `~/.pgpass` em sistemas baseados em Unix). O formato interno deve ser:
   ```text
   hostname:porta:banco_de_dados:usuario:senha
   ```
   *Exemplo genérico para liberar acesso a todos os bancos:*
   ```text
   *:5432:*:postgres:senha_super_secreta
   ```

2. **Permissões de segurança (Obrigatório em Linux/Unix):**
   O PostgreSQL exige que o arquivo tenha permissões restritas.
   ```bash
   chmod 0600 ~/.pgpass
   ```

3. **Uso com Docker:**
   Nos comandos subsequentes, o arquivo `.pgpass` do host será mapeado para dentro do contêiner no momento da execução, utilizando a variável de ambiente `PGPASSFILE` e o volume (`-v`).

---

## 📦 Fase 1: Procedimento de Backup (Extração)

O backup deve ser realizado em duas etapas para garantir a persistência das **Roles Globais** (usuários e perfis) independentemente dos dados estruturais do banco.

### 1.1. Exportação das Roles Globais

Os papéis de segurança pertencem ao cluster do banco. Deve-se exportar apenas as roles antes dos dados.

```bash
docker exec -e PGPASSFILE=/tmp/.pgpass -v ~/.pgpass:/tmp/.pgpass:ro <nome_do_container> \
pg_dumpall -U postgres --roles-only > 01_roles_backup.sql
```

### 1.2. Exportação dos Dados e Estrutura

Deve-se utilizar o formato customizado (`-Fc`), que comprime os dados e mitiga riscos de corrupção estrutural.

```bash
docker exec -e PGPASSFILE=/tmp/.pgpass -v ~/.pgpass:/tmp/.pgpass:ro <nome_do_container> \
pg_dump -U postgres -Fc sistema_academico > 02_banco_backup.dump
```

---

## 🛠️ Fase 2: Procedimento de Restauração (Recuperação do Zero)

Em cenários de falha crítica ou migração, os passos abaixo devem ser seguidos rigorosamente na ordem apresentada.

### 2.1. Restauração das Roles Globais

As roles devem ser recriadas antes da importação do banco, evitando falhas em políticas de RLS e concessões de permissões (`GRANTs`).

```bash
cat 01_roles_backup.sql | docker exec -i <nome_do_container> psql -U postgres
```

### 2.2. Criação do Banco de Dados Limpo

Deve-se preparar o cluster instanciando um banco vazio para receber a carga.

```bash
docker exec -i <nome_do_container> psql -U postgres -c "CREATE DATABASE sistema_academico;"
```

### 2.3. Restauração de Estrutura e Dados

Utiliza-se o utilitário `pg_restore` com a flag `-1` (single-transaction). Esta prática garante que, diante de qualquer erro na execução, toda a transação seja revertida (rollback), impedindo que o banco de dados seja restaurado de forma parcial ou corrompida.

```bash
docker exec -i -e PGPASSFILE=/tmp/.pgpass -v ~/.pgpass:/tmp/.pgpass:ro <nome_do_container> \
pg_restore -U postgres -d sistema_academico -1 < 02_banco_backup.dump
```

---

*Nota sobre Automação:* Os comandos descritos na **Fase 1** podem ser consolidados em um script shell (`.sh`) e programados para execução recorrente utilizando utilitários de agendamento, como o `cron` do sistema operacional hospedeiro.