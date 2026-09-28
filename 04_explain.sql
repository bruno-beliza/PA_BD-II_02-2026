-- ============================================================================
-- SCRIPT 04: EVIDÊNCIAS DE EXECUÇÃO (EXPLAIN ANALYZE)
-- ============================================================================

-- 1. Análise da Consulta Q3 (LEFT JOIN com Agregação)
EXPLAIN ANALYZE
SELECT p.nome AS professor, p.titulacao, COUNT(t.id_turma) AS total_turmas_ministradas
FROM professor p
LEFT JOIN turma t ON p.id_professor = t.id_professor
GROUP BY p.id_professor, p.nome, p.titulacao;

-- 2. Análise da Consulta Q5 (Window Functions)
EXPLAIN ANALYZE
SELECT 
    a.id_aluno,
    a.nome,
    ROUND(AVG(m.nota_final), 2) AS coeficiente_rendimento,
    DENSE_RANK() OVER (ORDER BY AVG(m.nota_final) DESC) AS rank_academico
FROM aluno a
JOIN matricula m ON a.id_aluno = m.id_aluno
WHERE m.situacao = 'APROVADO'
GROUP BY a.id_aluno, a.nome;

-- 3. Análise da Consulta Q7 (Recursiva)
EXPLAIN ANALYZE
WITH RECURSIVE arvore_prereq AS (
    SELECT id_disciplina, id_requisito, 1 AS nivel
    FROM pre_requisito WHERE id_disciplina = 3
    UNION ALL
    SELECT pr.id_disciplina, pr.id_requisito, ap.nivel + 1
    FROM pre_requisito pr
    JOIN arvore_prereq ap ON pr.id_disciplina = ap.id_requisito
)
SELECT * FROM arvore_prereq;