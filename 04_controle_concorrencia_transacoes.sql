-- ============================================================================
-- PREPARAÇÃO DO AMBIENTE PARA OS TESTES DE CONCORRÊNCIA
-- Execute este bloco uma única vez antes de iniciar o Teste 1.
-- ============================================================================

-- 1. Sincroniza a sequência de tb_matricula_turma com o maior ID atual (300)
SELECT setval(
    pg_get_serial_sequence('tb_matricula_turma', 'tb_matricula_turma_id'),
    COALESCE((SELECT MAX(tb_matricula_turma_id) FROM tb_matricula_turma), 1)
);

-- 2. Limpa eventuais matrículas na turma 37 e define o limite para 1 única vaga
DELETE FROM tb_matricula_turma WHERE tb_turma_id = 37;
UPDATE tb_turma SET tb_turma_vagas = 1 WHERE tb_turma_id = 37;

-- 3. Verifica o estado inicial pela view oficial do sistema (vagas_disponiveis = 1)
SELECT id_turma, codigo_turma, vagas_totais, matriculas_efetivadas, vagas_disponiveis
FROM vw_vagas
WHERE id_turma = 37;

-- ============================================================================
-- 1. Reprodução da Anomalia de Concorrência (Write Skew)
-- ============================================================================
-- ============================================================================
-- PASSO T1 (Sessão A): Inicia transação no nível padrão e verifica a vaga
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT t.tb_turma_vagas - COUNT(m.tb_matricula_turma_id) AS vagas_disponiveis
FROM tb_turma t
LEFT JOIN tb_matricula_turma m 
  ON m.tb_turma_id = t.tb_turma_id 
 AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
WHERE t.tb_turma_id = 37
GROUP BY t.tb_turma_id, t.tb_turma_vagas;
-- Retorno na Sessão A: vagas_disponiveis = 1 (Aluno 1 pode prosseguir)


-- ============================================================================
-- PASSO T2 (Sessão B): Inicia transação concorrente e verifica a mesma turma
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT t.tb_turma_vagas - COUNT(m.tb_matricula_turma_id) AS vagas_disponiveis
FROM tb_turma t
LEFT JOIN tb_matricula_turma m 
  ON m.tb_turma_id = t.tb_turma_id 
 AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
WHERE t.tb_turma_id = 37
GROUP BY t.tb_turma_id, t.tb_turma_vagas;
-- Retorno na Sessão B: vagas_disponiveis = 1 (Pois a Sessão A ainda não fez COMMIT)


-- ============================================================================
-- PASSO T3 (Sessão A): Efetiva a matrícula do Aluno 1 e confirma
-- ============================================================================
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
) VALUES (1, 37, NOW(), 'MATRICULADA');

COMMIT;
-- Sucesso: Aluno 1 matriculado.


-- ============================================================================
-- PASSO T4 (Sessão B): Efetiva a matrícula do Aluno 2 e confirma
-- ============================================================================
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
) VALUES (2, 37, NOW(), 'MATRICULADA');

COMMIT;
-- Sucesso: Aluno 2 TAMBÉM matriculado, sem nenhum erro ou bloqueio!


-- ============================================================================
-- PASSO T5 (Qualquer Sessão): Evidência da anomalia (Violação da regra de negócio)
-- ============================================================================
SELECT id_turma, codigo_turma, vagas_totais, matriculas_efetivadas, vagas_disponiveis
FROM vw_vagas
WHERE id_turma = 37;
-- Resultado anômalo: vagas_totais = 1 | matriculas_efetivadas = 2 | vagas_disponiveis = -1


--
-- ============================================================================
-- 2. Implementação de Duas Correções Distintas
-- ============================================================================
-- ============================================================================
-- Correção A: Por Bloqueio Explícito (SELECT ... FOR UPDATE)
-- Para impedir leituras concorrentes desatualizadas mantendo o nível 
-- READ COMMITTED, aplica-se um bloqueio pessimista exclusivo de 
-- linha (FOR UPDATE) sobre o registro pai na tabela tb_turma antes de contar 
-- as matrículas.

-- Detalhe Técnico (PostgreSQL): 
-- O PostgreSQL não permite usar FOR UPDATE diretamente na mesma consulta que 
-- possui funções de agregação (COUNT, GROUP BY). Por isso, bloqueamos a linha 
-- em tb_turma (que funciona como um mutex natural para aquela turma específica) 
-- e, em seguida, executamos a inserção condicional.
-- ============================================================================
-- Reset do cenário antes do teste:
DELETE FROM tb_matricula_turma WHERE tb_turma_id = 37;

-- ============================================================================
-- PASSO T1 (Sessão A): Inicia transação e adquire o lock exclusivo na turma 37
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT tb_turma_id, tb_turma_vagas 
FROM tb_turma 
WHERE tb_turma_id = 37 
FOR UPDATE;
-- Retorno imediato: Sessão A detém o lock de linha (Row-Level Lock) da turma 37.


-- ============================================================================
-- PASSO T2 (Sessão B): Tenta adquirir o lock na mesma turma 37
-- ============================================================================
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT tb_turma_id, tb_turma_vagas 
FROM tb_turma 
WHERE tb_turma_id = 37 
FOR UPDATE;
-- ESTADO: A Sessão B fica BLOQUEADA (aguardando na fila de lock) até a Sessão A finalizar.


-- ============================================================================
-- PASSO T3 (Sessão A): Insere validando o limite de vagas e faz COMMIT
-- ============================================================================
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
)
SELECT 1, 37, NOW(), 'MATRICULADA'
FROM tb_turma t
WHERE t.tb_turma_id = 37
  AND (
    SELECT COUNT(*) 
    FROM tb_matricula_turma m 
    WHERE m.tb_turma_id = t.tb_turma_id 
      AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
  ) < t.tb_turma_vagas;
-- Retorno: INSERT 0 1 (1 linha inserida)

COMMIT;
-- No instante deste COMMIT, a Sessão B é desbloqueada automaticamente!


-- ============================================================================
-- PASSO T4 (Sessão B): Já desbloqueada, executa a inserção condicional
-- ============================================================================
-- Como estamos em READ COMMITTED, o comando abaixo enxerga o COMMIT da Sessão A:
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
)
SELECT 2, 37, NOW(), 'MATRICULADA'
FROM tb_turma t
WHERE t.tb_turma_id = 37
  AND (
    SELECT COUNT(*) 
    FROM tb_matricula_turma m 
    WHERE m.tb_turma_id = t.tb_turma_id 
      AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
  ) < t.tb_turma_vagas;
-- Retorno: INSERT 0 0 (0 linhas inseridas — a condição < tb_turma_vagas retornou falso!)

COMMIT;


-- ============================================================================
-- PASSO T5 (Qualquer Sessão): Verificação de integridade
-- ============================================================================
SELECT id_turma, codigo_turma, vagas_totais, matriculas_efetivadas, vagas_disponiveis
FROM vw_vagas
WHERE id_turma = 37;
-- Resultado íntegro: vagas_totais = 1 | matriculas_efetivadas = 1 | vagas_disponiveis = 0

-- Correção B: Por Nível de Isolamento (SERIALIZABLE)
-- NoPostgreSQL, o nível REPEATABLE READ implementa Snapshot Isolation (SI), que previne
-- leituras não repetíveis, mas não previne Write Skew (pois não detecta conflitos de 
-- leitura contra escrita em linhas novas). Para corrigir a anomalia via nível de isolamento
-- sem bloqueios explícitos, é obrigatório utilizar SERIALIZABLE, que utiliza o 
-- protocolo SSI (Serializable Snapshot Isolation) por meio de bloqueios de predicado (SIRead locks).
-- Reset do cenário antes do teste:

DELETE FROM tb_matricula_turma WHERE tb_turma_id = 37;

-- ============================================================================
-- PASSO T1 (Sessão A): Inicia em SERIALIZABLE e lê o predicado de matrículas
-- ============================================================================
BEGIN ISOLATION LEVEL SERIALIZABLE;

SELECT t.tb_turma_vagas - COUNT(m.tb_matricula_turma_id) AS vagas_disponiveis
FROM tb_turma t
LEFT JOIN tb_matricula_turma m 
  ON m.tb_turma_id = t.tb_turma_id 
 AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
WHERE t.tb_turma_id = 37
GROUP BY t.tb_turma_id, t.tb_turma_vagas;
-- Retorno: vagas_disponiveis = 1 (PostgreSQL registra um SIRead predicate lock para a Sessão A)


-- ============================================================================
-- PASSO T2 (Sessão B): Inicia em SERIALIZABLE e lê o mesmo predicado
-- ============================================================================
BEGIN ISOLATION LEVEL SERIALIZABLE;

SELECT t.tb_turma_vagas - COUNT(m.tb_matricula_turma_id) AS vagas_disponiveis
FROM tb_turma t
LEFT JOIN tb_matricula_turma m 
  ON m.tb_turma_id = t.tb_turma_id 
 AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
WHERE t.tb_turma_id = 37
GROUP BY t.tb_turma_id, t.tb_turma_vagas;
-- Retorno: vagas_disponiveis = 1 (Nenhum bloqueio de espera ocorre; ambas avançam!)


-- ============================================================================
-- PASSO T3 (Sessão A): Insere o Aluno 1 e confirma a transação
-- ============================================================================
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
) VALUES (1, 37, NOW(), 'MATRICULADA');

COMMIT;
-- Retorno: COMMIT realizado com sucesso.


-- ============================================================================
-- PASSO T4 (Sessão B): Tenta inserir o Aluno 2 (ou confirmar a transação)
-- ============================================================================
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
) VALUES (2, 37, NOW(), 'MATRICULADA');

COMMIT;
-- ERRO IMEDIATO DO SGBD (SQLSTATE 40001):
-- ERROR: could not serialize access due to read/write dependencies among transactions
-- DETAIL: Reason code: Canceled on identification as a pivot, during write.
-- HINT: The transaction might succeed if retried.

-- Na Sessão B, limpa-se o estado da transação abortada:
ROLLBACK;


-- ============================================================================
-- PASSO T5 (Qualquer Sessão): Verificação de integridade
-- ============================================================================
SELECT id_turma, codigo_turma, vagas_totais, matriculas_efetivadas, vagas_disponiveis
FROM vw_vagas
WHERE id_turma = 37;
-- Resultado íntegro: vagas_totais = 1 | matriculas_efetivadas = 1 | vagas_disponiveis = 0

--
-- Nota: Caso queira restaurar a base para o estado exato de fábrica após o término das 
-- demonstrações, basta executar
DELETE FROM tb_matricula_turma WHERE tb_turma_id = 37;

UPDATE tb_turma SET tb_turma_vagas = 60 WHERE tb_turma_id = 37;


-- 
-- ============================================================================
-- TESTE QUANTITATIVO 1: CUSTO DE LEITURA, BUFFERS SUJOS (DIRTIED) E GERAÇÃO DE WAL

-- Medição de Custo de Plano, Buffers e WAL (EXPLAIN ANALYZE)
-- No PostgreSQL, o SELECT ... FOR UPDATE precisa gravar o XID (ID da transação) 
-- no campo xmax do cabeçalho da tupla em tb_turma e setar os infomask bits, 
-- o que suja a página no buffer (dirtied) e gera registros de WAL, mesmo sem alterar
-- nenhuma coluna da tabela. Já a leitura em SERIALIZABLE apenas registra um SIReadLock
-- em memória RAM volátil, sem tocar no disco/WAL.
-- ============================================================================

-- 1A. Custo da Abordagem 1 (Bloqueio Explícito em READ COMMITTED)
BEGIN ISOLATION LEVEL READ COMMITTED;

EXPLAIN (ANALYZE, BUFFERS, WAL, TIMING, COSTS)
SELECT tb_turma_id, tb_turma_vagas 
FROM tb_turma 
WHERE tb_turma_id = 37 
FOR UPDATE;

EXPLAIN (ANALYZE, BUFFERS, WAL, TIMING, COSTS)
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
)
SELECT 1, 37, NOW(), 'MATRICULADA'
FROM tb_turma t
WHERE t.tb_turma_id = 37
  AND (
    SELECT COUNT(*) 
    FROM tb_matricula_turma m 
    WHERE m.tb_turma_id = t.tb_turma_id 
      AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
  ) < t.tb_turma_vagas;

ROLLBACK;

-- 1B. Custo da Abordagem 2 (Leitura de Predicado + Inserção em SERIALIZABLE)
BEGIN ISOLATION LEVEL SERIALIZABLE;

EXPLAIN (ANALYZE, BUFFERS, WAL, TIMING, COSTS)
SELECT t.tb_turma_vagas - COUNT(m.tb_matricula_turma_id) AS vagas_disponiveis
FROM tb_turma t
LEFT JOIN tb_matricula_turma m 
  ON m.tb_turma_id = t.tb_turma_id 
 AND m.tb_matricula_turma_status IN ('MATRICULADA', 'CONCLUIDA')
WHERE t.tb_turma_id = 37
GROUP BY t.tb_turma_id, t.tb_turma_vagas;

EXPLAIN (ANALYZE, BUFFERS, WAL, TIMING, COSTS)
INSERT INTO tb_matricula_turma (
    tb_aluno_curriculo_id, tb_turma_id, tb_matricula_turma_data_matricula, tb_matricula_turma_status
) VALUES (1, 37, NOW(), 'MATRICULADA');

ROLLBACK;

-- ============================================================================
-- TESTE QUANTITATIVO 2: INSPEÇÃO DE BLOQUEIOS E FILA DE ESPERA (pg_locks)

-- Medição de Contenção e Pegada de Memória na pg_locks
-- Esta consulta quantifica a quantidade de objetos de bloqueio alocados 
-- na memória compartilhada do SGBD e evidencia se há sessões retidas em 
-- espera (granted = false) ou se há alocação de bloqueios de predicado (SIReadLock).

-- Execute enquanto as Sessões A e B estiverem abertas (antes do COMMIT da Sessão A)
-- ============================================================================
SELECT 
    l.locktype AS tipo_alvo,
    c.relname AS relacao_ou_indice,
    l.mode AS modo_bloqueio,
    l.granted AS concedido,
    l.pid AS pid_sessao,
    a.state AS estado_sessao,
    a.wait_event_type AS tipo_espera,
    a.wait_event AS evento_espera,
    ROUND(EXTRACT(EPOCH FROM (NOW() - a.state_change))::numeric, 3) AS tempo_no_estado_seg
FROM pg_locks l
JOIN pg_stat_activity a ON a.pid = l.pid
LEFT JOIN pg_class c ON c.oid = l.relation
WHERE c.relname IN (
        'tb_turma', 'tb_turma_pkey', 
        'tb_matricula_turma', 'ix_matricula_turma_turma', 'uk_matricula_curriculo_turma'
      )
   OR l.mode = 'SIReadLock'
ORDER BY l.pid, l.locktype;

-- ============================================================================
-- TESTE QUANTITATIVO 3: CONTABILIZAÇÃO DE COMMITS VS. ABORTOS E MODELO DE PICO

-- Medição da Taxa de Abortos, Trabalho Desperdiçado e Retentativas
-- Para quantificar matematicamente a necessidade de retentativas em um cenário de 
-- pico (ex.: N alunos disputando simultaneamente uma turma com V vagas), 
-- podemos extrair a variação de xact_commit e xact_rollback em pg_stat_database e 
-- calcular o volume de transações desperdiçadas em função da concorrência
-- ============================================================================

-- 3A. Consulta para medir commits vs. rollbacks reais antes e depois da bateria de testes:
SELECT 
    datname AS banco,
    xact_commit AS total_commits,
    xact_rollback AS total_rollbacks_e_abortos,
    ROUND((xact_rollback::numeric / NULLIF(xact_commit + xact_rollback, 0)) * 100, 2) AS taxa_aborto_perc,
    tup_fetched AS tuplas_lidas,
    tup_inserted AS tuplas_inseridas
FROM pg_stat_database
WHERE datname = current_database();

-- 3B. Simulação Analítica: N = 20 alunos concorrentes disputando simultaneamente V = 10 vagas
-- Compara o número exato de transações executadas, abortos (40001) e retentativas necessárias
-- quando ondas simultâneas chegam ao banco de dados:
WITH RECURSIVE ondas_serializable AS (
    -- Onda 1: 20 alunos leem vagas_disponiveis = 10 ao mesmo tempo.
    -- 1 faz COMMIT com sucesso; 19 sofrem aborto (SQLSTATE 40001) e precisam de retry.
    SELECT 
        1 AS onda,
        20 AS concorrentes_na_onda,
        10 AS vagas_restantes_inicio,
        1 AS commits_sucesso,
        19 AS abortos_40001_retry,
        0 AS rejeicoes_limpas_sem_vaga
    UNION ALL
    SELECT 
        onda + 1,
        abortos_40001_retry AS concorrentes_na_onda,
        vagas_restantes_inicio - 1 AS vagas_restantes_inicio,
        CASE WHEN vagas_restantes_inicio - 1 > 0 THEN 1 ELSE 0 END AS commits_sucesso,
        CASE WHEN vagas_restantes_inicio - 1 > 0 THEN abortos_40001_retry - 1 ELSE 0 END AS abortos_40001_retry,
        CASE WHEN vagas_restantes_inicio - 1 = 0 THEN abortos_40001_retry ELSE 0 END AS rejeicoes_limpas_sem_vaga
    FROM ondas_serializable
    WHERE vagas_restantes_inicio > 0
)
SELECT 
    '1. Bloqueio Explícito (FOR UPDATE)' AS abordagem,
    1 AS ondas_necessarias,
    20 AS total_transacoes_executadas,
    10 AS matriculas_efetivadas,
    10 AS recusas_limpas_0_linhas,
    0 AS erros_40001_abortados,
    '0.00%' AS overhead_transacional
UNION ALL
SELECT 
    '2. Isolamento (SERIALIZABLE - Pior Caso Simultâneo)',
    MAX(onda),
    SUM(concorrentes_na_onda)::int,
    SUM(commits_sucesso)::int,
    SUM(rejeicoes_limpas_sem_vaga)::int,
    SUM(abortos_40001_retry)::int,
    ROUND(((SUM(concorrentes_na_onda) - 20)::numeric / 20) * 100, 2) || '%'
FROM ondas_serializable;