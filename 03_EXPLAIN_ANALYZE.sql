-- ============================================================================
-- SCRIPT 03: EVIDÊNCIAS DE EXECUÇÃO (EXPLAIN ANALYZE)
-- Executar preferencialmente no pgAdmin, para visualizar o plano de execução.
-- ============================================================================

ANALYZE;

-- ============================================================================
-- EXPLAIN DAS 10 CONSULTAS OBRIGATÓRIAS
-- ============================================================================

-- CONSULTA 1 (básica): lista os alunos ativos e suas matrículas acadêmicas.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT a.tb_aluno_id, p.tb_pessoa_nome, a.tb_aluno_matricula, a.tb_aluno_data_ingresso
FROM tb_aluno a
JOIN tb_pessoa p ON p.tb_pessoa_id = a.tb_aluno_id
WHERE a.tb_aluno_ativo = TRUE
ORDER BY p.tb_pessoa_nome;

-- CONSULTA 2 (junções): lista as turmas, disciplinas, professores e período letivo.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT t.tb_turma_codigo, d.tb_disciplina_codigo, d.tb_disciplina_nome,
       pp.tb_pessoa_nome AS professor, pl.tb_periodo_letivo_ano, pl.tb_periodo_letivo_semestre,
       t.tb_turma_turno, t.tb_turma_vagas
FROM tb_turma t
JOIN tb_disciplina d ON d.tb_disciplina_id = t.tb_disciplina_id
JOIN tb_professor pr ON pr.tb_professor_id = t.tb_professor_id
JOIN tb_pessoa pp ON pp.tb_pessoa_id = pr.tb_professor_id
JOIN tb_periodo_letivo pl ON pl.tb_periodo_letivo_id = t.tb_periodo_letivo_id
ORDER BY pl.tb_periodo_letivo_ano, pl.tb_periodo_letivo_semestre, d.tb_disciplina_nome;

-- CONSULTA 3 (junção externa + agregação OBRIGATÓRIA): inclui turmas sem matrícula.
-- O LEFT JOIN mantém a turma T037 (2026/2), que ainda não tem matrículas e aparece com 0.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT t.tb_turma_id, t.tb_turma_codigo, d.tb_disciplina_nome,
       COUNT(m.tb_matricula_turma_id) AS total_matriculas,
       t.tb_turma_vagas,
       t.tb_turma_vagas - COUNT(m.tb_matricula_turma_id) AS vagas_restantes
FROM tb_turma t
JOIN tb_disciplina d ON d.tb_disciplina_id = t.tb_disciplina_id
LEFT JOIN tb_matricula_turma m ON m.tb_turma_id = t.tb_turma_id
GROUP BY t.tb_turma_id, t.tb_turma_codigo, d.tb_disciplina_nome, t.tb_turma_vagas
ORDER BY total_matriculas DESC, t.tb_turma_codigo;

-- CONSULTA 4 (agregação com HAVING): rendimento médio por disciplina, somente com 10+ históricos.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT d.tb_disciplina_codigo, d.tb_disciplina_nome,
       COUNT(*) AS total_avaliacoes,
       ROUND(AVG(h.tb_historico_media_final), 2) AS media_turma,
       ROUND(AVG(h.tb_historico_frequencia), 2) AS frequencia_media
FROM tb_historico h
JOIN tb_matricula_turma m ON m.tb_matricula_turma_id = h.tb_matricula_turma_id
JOIN tb_turma t ON t.tb_turma_id = m.tb_turma_id
JOIN tb_disciplina d ON d.tb_disciplina_id = t.tb_disciplina_id
GROUP BY d.tb_disciplina_codigo, d.tb_disciplina_nome
HAVING COUNT(*) >= 10
ORDER BY media_turma DESC;

-- CONSULTA 5 (subconsulta): alunos com média geral acima da média global dos históricos.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT a.tb_aluno_id, p.tb_pessoa_nome,
       ROUND(AVG(h.tb_historico_media_final), 2) AS media_aluno
FROM tb_aluno a
JOIN tb_pessoa p ON p.tb_pessoa_id = a.tb_aluno_id
JOIN tb_aluno_curriculo ac ON ac.tb_aluno_id = a.tb_aluno_id
JOIN tb_matricula_turma m ON m.tb_aluno_curriculo_id = ac.tb_aluno_curriculo_id
JOIN tb_historico h ON h.tb_matricula_turma_id = m.tb_matricula_turma_id
GROUP BY a.tb_aluno_id, p.tb_pessoa_nome
HAVING AVG(h.tb_historico_media_final) > (SELECT AVG(tb_historico_media_final) FROM tb_historico)
ORDER BY media_aluno DESC;

-- CONSULTA 6 (CTE recursiva OBRIGATÓRIA): árvore de pré-requisitos de uma disciplina.
-- Altere o valor inicial (6) para explorar a árvore de outra disciplina.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH RECURSIVE arvore_pre_requisitos AS (
  SELECT d.tb_disciplina_id, d.tb_disciplina_nome, 0 AS nivel,
         ARRAY[d.tb_disciplina_id] AS caminho
  FROM tb_disciplina d
  WHERE d.tb_disciplina_id = 6
  UNION ALL
  SELECT req.tb_requisito_id, prereq.tb_disciplina_nome, arv.nivel + 1,
         arv.caminho || req.tb_requisito_id
  FROM arvore_pre_requisitos arv
  
  JOIN tb_disciplina_pre_requisito req
  ON req.tb_disciplina_id = arv.tb_disciplina_id
 AND req.tb_disciplina_pre_requisito_vinculo = 'PRE_REQUISITO'

  
  JOIN tb_disciplina prereq ON prereq.tb_disciplina_id = req.tb_requisito_id
  WHERE NOT req.tb_requisito_id = ANY(arv.caminho)
)
SELECT nivel, tb_disciplina_id, tb_disciplina_nome, caminho
FROM arvore_pre_requisitos
ORDER BY nivel DESC, tb_disciplina_id;

-- CONSULTA 7 (CTE recursiva OBRIGATÓRIA): disciplinas que um aluno já pode cursar.
-- Critério: disciplina do currículo ainda não aprovada pelo aluno e todos os pré-requisitos
-- diretos e transitivos aprovados. Troque o aluno 1 pelo ID desejado.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH RECURSIVE disciplinas_curriculo AS (
  SELECT cd.tb_disciplina_id
  FROM tb_curriculo_disciplina cd
  JOIN tb_aluno_curriculo ac ON ac.tb_curriculo_id = cd.tb_curriculo_id
  WHERE ac.tb_aluno_id = 1 AND ac.tb_aluno_curriculo_ativo = TRUE
), pre_requisitos_transitivos AS (
  SELECT dc.tb_disciplina_id AS disciplina_alvo,
         r.tb_requisito_id AS requisito_id,
         ARRAY[dc.tb_disciplina_id, r.tb_requisito_id] AS caminho
		 
  FROM disciplinas_curriculo dc
JOIN tb_disciplina_pre_requisito r
  ON r.tb_disciplina_id = dc.tb_disciplina_id
 AND r.tb_disciplina_pre_requisito_vinculo = 'PRE_REQUISITO'
  
  UNION ALL
  SELECT prt.disciplina_alvo,
         r.tb_requisito_id,
         prt.caminho || r.tb_requisito_id

		 
  FROM pre_requisitos_transitivos prt
JOIN tb_disciplina_pre_requisito r
  ON r.tb_disciplina_id = prt.requisito_id
 AND r.tb_disciplina_pre_requisito_vinculo = 'PRE_REQUISITO'

  
  WHERE NOT r.tb_requisito_id = ANY(prt.caminho)
), disciplinas_aprovadas AS (
  SELECT DISTINCT t.tb_disciplina_id
  FROM tb_aluno_curriculo ac
  JOIN tb_matricula_turma m ON m.tb_aluno_curriculo_id = ac.tb_aluno_curriculo_id
  JOIN tb_turma t ON t.tb_turma_id = m.tb_turma_id
  JOIN tb_historico h ON h.tb_matricula_turma_id = m.tb_matricula_turma_id
  WHERE ac.tb_aluno_id = 1 AND h.tb_historico_situacao = 'APROVADO'
)
SELECT d.tb_disciplina_id, d.tb_disciplina_codigo, d.tb_disciplina_nome
FROM disciplinas_curriculo dc
JOIN tb_disciplina d ON d.tb_disciplina_id = dc.tb_disciplina_id
WHERE NOT EXISTS (
        SELECT 1 FROM disciplinas_aprovadas da WHERE da.tb_disciplina_id = d.tb_disciplina_id
      )
  AND NOT EXISTS (
        SELECT 1
        FROM pre_requisitos_transitivos prt
        WHERE prt.disciplina_alvo = d.tb_disciplina_id
          AND NOT EXISTS (SELECT 1 FROM disciplinas_aprovadas da WHERE da.tb_disciplina_id = prt.requisito_id)
      )
ORDER BY d.tb_disciplina_id;

-- CONSULTA 8 (NOT EXISTS): alunos que ainda não foram aprovados em Banco de Dados.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT a.tb_aluno_id, p.tb_pessoa_nome
FROM tb_aluno a
JOIN tb_pessoa p ON p.tb_pessoa_id = a.tb_aluno_id
WHERE NOT EXISTS (
  SELECT 1
  FROM tb_aluno_curriculo ac
  JOIN tb_matricula_turma m ON m.tb_aluno_curriculo_id = ac.tb_aluno_curriculo_id
  JOIN tb_turma t ON t.tb_turma_id = m.tb_turma_id
  JOIN tb_historico h ON h.tb_matricula_turma_id = m.tb_matricula_turma_id
  WHERE ac.tb_aluno_id = a.tb_aluno_id
    AND t.tb_disciplina_id = 5
    AND h.tb_historico_situacao = 'APROVADO'
)
ORDER BY p.tb_pessoa_nome;

-- CONSULTA 9 (funções de janela OBRIGATÓRIAS): ranking e percentil dos alunos por rendimento.
-- RANK posiciona o aluno entre seus pares; PERCENT_RANK retorna posição relativa de 0 a 1.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH rendimento_aluno AS (
  SELECT a.tb_aluno_id, p.tb_pessoa_nome,
         ROUND(AVG(h.tb_historico_media_final), 2) AS media_geral
  FROM tb_aluno a
  JOIN tb_pessoa p ON p.tb_pessoa_id = a.tb_aluno_id
  JOIN tb_aluno_curriculo ac ON ac.tb_aluno_id = a.tb_aluno_id
  JOIN tb_matricula_turma m ON m.tb_aluno_curriculo_id = ac.tb_aluno_curriculo_id
  JOIN tb_historico h ON h.tb_matricula_turma_id = m.tb_matricula_turma_id
  GROUP BY a.tb_aluno_id, p.tb_pessoa_nome
)
SELECT tb_aluno_id, tb_pessoa_nome, media_geral,
       RANK() OVER (ORDER BY media_geral DESC) AS ranking,
       ROUND((PERCENT_RANK() OVER (ORDER BY media_geral DESC))::numeric, 4) AS percentil_relativo
FROM rendimento_aluno
ORDER BY ranking, tb_pessoa_nome;

-- CONSULTA 10 (função de janela OBRIGATÓRIA): LAG para a evolução do rendimento POR SEMESTRE.
-- Primeiro calcula a média de cada aluno em cada semestre cursado; depois o LAG traz a média
-- do semestre imediatamente anterior do mesmo aluno (PARTITION BY aluno, ordem cronológica).
-- A variação positiva indica melhora; a primeira linha de cada aluno não tem semestre anterior.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH media_semestre AS (
  SELECT a.tb_aluno_id, p.tb_pessoa_nome,
         pl.tb_periodo_letivo_ano, pl.tb_periodo_letivo_semestre,
         COUNT(*) AS disciplinas_cursadas,
         ROUND(AVG(h.tb_historico_media_final), 2) AS media_semestre
  FROM tb_aluno a
  JOIN tb_pessoa p ON p.tb_pessoa_id = a.tb_aluno_id
  JOIN tb_aluno_curriculo ac ON ac.tb_aluno_id = a.tb_aluno_id
  JOIN tb_matricula_turma m ON m.tb_aluno_curriculo_id = ac.tb_aluno_curriculo_id
  JOIN tb_turma t ON t.tb_turma_id = m.tb_turma_id
  JOIN tb_periodo_letivo pl ON pl.tb_periodo_letivo_id = t.tb_periodo_letivo_id
  JOIN tb_historico h ON h.tb_matricula_turma_id = m.tb_matricula_turma_id
  GROUP BY a.tb_aluno_id, p.tb_pessoa_nome, pl.tb_periodo_letivo_ano, pl.tb_periodo_letivo_semestre
)
SELECT tb_aluno_id, tb_pessoa_nome, tb_periodo_letivo_ano, tb_periodo_letivo_semestre,
       disciplinas_cursadas, media_semestre,
       LAG(media_semestre) OVER janela_aluno AS media_semestre_anterior,
       ROUND(media_semestre - LAG(media_semestre) OVER janela_aluno, 2) AS variacao_rendimento,
       CASE
         WHEN LAG(media_semestre) OVER janela_aluno IS NULL THEN 'primeiro semestre'
         WHEN media_semestre > LAG(media_semestre) OVER janela_aluno THEN 'melhora'
         WHEN media_semestre < LAG(media_semestre) OVER janela_aluno THEN 'queda'
         ELSE 'estável'
       END AS tendencia
FROM media_semestre
WINDOW janela_aluno AS (
  PARTITION BY tb_aluno_id
  ORDER BY tb_periodo_letivo_ano, tb_periodo_letivo_semestre
)
ORDER BY tb_aluno_id, tb_periodo_letivo_ano, tb_periodo_letivo_semestre;

-- ============================================================================
-- EXPLAIN DAS 3 CONSULTAS DE VALIDAÇÃO DA CARGA
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 'alunos' AS entidade, COUNT(*) AS total FROM tb_aluno
UNION ALL SELECT 'turmas', COUNT(*) FROM tb_turma
UNION ALL SELECT 'matriculas', COUNT(*) FROM tb_matricula_turma
UNION ALL SELECT 'historicos', COUNT(*) FROM tb_historico
UNION ALL SELECT 'turmas sem matricula', COUNT(*)
          FROM tb_turma t WHERE NOT EXISTS (SELECT 1 FROM tb_matricula_turma m WHERE m.tb_turma_id = t.tb_turma_id);

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT COUNT(*) AS matriculas_violando_pre_requisito
FROM tb_matricula_turma m
JOIN tb_aluno_curriculo ac ON ac.tb_aluno_curriculo_id = m.tb_aluno_curriculo_id
JOIN tb_turma t ON t.tb_turma_id = m.tb_turma_id
JOIN tb_periodo_letivo pl ON pl.tb_periodo_letivo_id = t.tb_periodo_letivo_id
JOIN tb_disciplina_pre_requisito r ON r.tb_disciplina_id = t.tb_disciplina_id
WHERE r.tb_disciplina_pre_requisito_vinculo = 'PRE_REQUISITO'
  AND NOT EXISTS (
    SELECT 1
    FROM tb_matricula_turma m2
    JOIN tb_aluno_curriculo ac2 ON ac2.tb_aluno_curriculo_id = m2.tb_aluno_curriculo_id
    JOIN tb_turma t2 ON t2.tb_turma_id = m2.tb_turma_id
    JOIN tb_periodo_letivo pl2 ON pl2.tb_periodo_letivo_id = t2.tb_periodo_letivo_id
    JOIN tb_historico h2 ON h2.tb_matricula_turma_id = m2.tb_matricula_turma_id
    WHERE ac2.tb_aluno_id = ac.tb_aluno_id
      AND t2.tb_disciplina_id = r.tb_requisito_id
      AND h2.tb_historico_situacao = 'APROVADO'
      AND pl2.tb_periodo_letivo_data_fim < pl.tb_periodo_letivo_data_inicio
  );

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT COUNT(DISTINCT ac.tb_aluno_id) AS alunos_com_choque_de_horario
FROM tb_matricula_turma a
JOIN tb_matricula_turma b ON b.tb_aluno_curriculo_id = a.tb_aluno_curriculo_id
                         AND b.tb_matricula_turma_id > a.tb_matricula_turma_id
JOIN tb_aluno_curriculo ac ON ac.tb_aluno_curriculo_id = a.tb_aluno_curriculo_id
JOIN tb_turma ta ON ta.tb_turma_id = a.tb_turma_id
JOIN tb_turma tb ON tb.tb_turma_id = b.tb_turma_id AND tb.tb_periodo_letivo_id = ta.tb_periodo_letivo_id
JOIN tb_turma_horario ha ON ha.tb_turma_id = a.tb_turma_id
JOIN tb_turma_horario hb ON hb.tb_turma_id = b.tb_turma_id
                        AND hb.tb_turma_horario_dia_semana = ha.tb_turma_horario_dia_semana
                        AND ha.tb_turma_horario_inicio < hb.tb_turma_horario_fim
                        AND hb.tb_turma_horario_inicio < ha.tb_turma_horario_fim;