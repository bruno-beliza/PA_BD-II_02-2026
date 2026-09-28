-- ============================================================================
-- SCRIPT 03: CONSULTAS ANALÍTICAS (10 SELECTs)
-- ============================================================================

-- Q1: Listagem simples de alunos matriculados ativos
SELECT matricula, nome, email 
FROM aluno 
ORDER BY nome LIMIT 10;

-- Q2: Junção interna simples com filtro de agregação (HAVING)
SELECT d.nome AS disciplina, COUNT(m.id_matricula) AS total_matriculas
FROM turma t
JOIN disciplina d ON t.id_disciplina = d.id_disciplina
JOIN matricula m ON t.id_turma = m.id_turma
GROUP BY d.nome
HAVING COUNT(m.id_matricula) > 5;

-- Q3: [REQUISITO] Junção Externa (LEFT JOIN) com Agregação
-- Exibe TODOS os professores e a quantidade de turmas ministradas (inclusive 0)
SELECT p.nome AS professor, p.titulacao, COUNT(t.id_turma) AS total_turmas_ministradas
FROM professor p
LEFT JOIN turma t ON p.id_professor = t.id_professor
GROUP BY p.id_professor, p.nome, p.titulacao
ORDER BY total_turmas_ministradas DESC;

-- Q4: Subconsulta com EXISTS (Alunos aprovados em Banco de Dados I)
SELECT a.matricula, a.nome 
FROM aluno a
WHERE EXISTS (
    SELECT 1 FROM matricula m
    JOIN turma t ON m.id_turma = t.id_turma
    JOIN disciplina d ON t.id_disciplina = d.id_disciplina
    WHERE m.id_aluno = a.id_aluno 
      AND d.codigo = 'CC104' 
      AND m.situacao = 'APROVADO'
);

-- Q5: [REQUISITO] Window Function: Ranking e Percentil de Alunos por CR
SELECT 
    a.id_aluno,
    a.nome,
    ROUND(AVG(m.nota_final), 2) AS coeficiente_rendimento,
    DENSE_RANK() OVER (ORDER BY AVG(m.nota_final) DESC) AS rank_academico,
    ROUND(PERCENT_RANK() OVER (ORDER BY AVG(m.nota_final))::numeric, 2) AS percentil
FROM aluno a
JOIN matricula m ON a.id_aluno = m.id_aluno
WHERE m.situacao = 'APROVADO'
GROUP BY a.id_aluno, a.nome
ORDER BY rank_academico LIMIT 15;

-- Q6: [REQUISITO] Window Function: Evolution de Rendimento com LAG
SELECT 
    m.id_aluno,
    pl.ano || '.' || pl.semestre AS periodo,
    d.nome AS disciplina,
    m.nota_final AS nota_atual,
    LAG(m.nota_final) OVER (PARTITION BY m.id_aluno ORDER BY pl.ano, pl.semestre) AS nota_anterior,
    ROUND((m.nota_final - LAG(m.nota_final) OVER (PARTITION BY m.id_aluno ORDER BY pl.ano, pl.semestre)), 2) AS evolucao
FROM matricula m
JOIN turma t ON m.id_turma = t.id_turma
JOIN periodo_letivo pl ON t.id_periodo_letivo = pl.id_periodo_letivo
JOIN disciplina d ON t.id_disciplina = d.id_disciplina
WHERE m.id_aluno = 1 AND m.nota_final IS NOT NULL
ORDER BY pl.ano, pl.semestre;

-- Q7: [REQUISITO] Consulta Recursiva 1: Árvore de Pré-requisitos
WITH RECURSIVE arvore_prereq AS (
    -- Caso Base: Pré-requisitos diretos da disciplina 'CC103' (Algoritmos Avançados)
    SELECT id_disciplina, id_requisito, 1 AS nivel
    FROM pre_requisito
    WHERE id_disciplina = 3
    
    UNION ALL
    
    -- Passo Recursivo: Pré-requisitos dos pré-requisitos
    SELECT pr.id_disciplina, pr.id_requisito, ap.nivel + 1
    FROM pre_requisito pr
    JOIN arvore_prereq ap ON pr.id_disciplina = ap.id_requisito
)
SELECT 
    d_alvo.nome AS disciplina_alvo,
    d_req.nome AS pre_requisito_necessario,
    ap.nivel
FROM arvore_prereq ap
JOIN disciplina d_alvo ON ap.id_disciplina = d_alvo.id_disciplina
JOIN disciplina d_req ON ap.id_requisito = d_req.id_disciplina;

-- Q8: [REQUISITO] Consulta Recursiva 2: Disciplinas aptas para cursar
-- Avalia se o aluno (id_aluno = 1) concluiu todos os pré-requisitos necessários
WITH disciplinas_concluidas AS (
    SELECT DISTINCT t.id_disciplina
    FROM matricula m
    JOIN turma t ON m.id_turma = t.id_turma
    WHERE m.id_aluno = 1 AND m.situacao = 'APROVADO'
),
disciplinas_faltantes AS (
    SELECT cd.id_disciplina
    FROM curriculo_disciplina cd
    JOIN aluno a ON a.id_curriculo = cd.id_curriculo
    WHERE a.id_aluno = 1 AND cd.id_disciplina NOT IN (SELECT id_disciplina FROM disciplinas_concluidas)
)
SELECT d.codigo, d.nome AS disciplina_pronta_para_cursar
FROM disciplinas_faltantes df
JOIN disciplina d ON df.id_disciplina = d.id_disciplina
WHERE NOT EXISTS (
    SELECT 1 FROM pre_requisito pr
    WHERE pr.id_disciplina = df.id_disciplina
      AND pr.id_requisito NOT IN (SELECT id_disciplina FROM disciplinas_concluidas)
);

-- Q9: Taxa de Aprovação Média por Professor
SELECT 
    p.nome AS professor,
    COUNT(m.id_matricula) AS total_avaliados,
    ROUND(COUNT(CASE WHEN m.situacao = 'APROVADO' THEN 1 END) * 100.0 / COUNT(m.id_matricula), 2) AS taxa_aprovacao_pct
FROM professor p
JOIN turma t ON p.id_professor = t.id_professor
JOIN matricula m ON t.id_turma = m.id_turma
WHERE m.situacao IN ('APROVADO', 'REPROVADO')
GROUP BY p.id_professor, p.nome;

-- Q10: Relatório Consolidado de Desempenho por Período Letivo
SELECT 
    pl.ano,
    pl.semestre,
    COUNT(DISTINCT m.id_aluno) AS total_alunos_ativos,
    ROUND(AVG(m.nota_final), 2) AS media_geral_periodo
FROM periodo_letivo pl
JOIN turma t ON pl.id_periodo_letivo = t.id_periodo_letivo
JOIN matricula m ON t.id_turma = m.id_turma
GROUP BY pl.id_periodo_letivo, pl.ano, pl.semestre
ORDER BY pl.ano, pl.semestre;