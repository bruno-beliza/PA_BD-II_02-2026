-- ============================================================================
-- SCRIPT 02: CARGA DE DADOS (150 Alunos, 12 Turmas, 450+ Matrículas)
-- ============================================================================

-- 1. Campus, Curso e Currículo
INSERT INTO campus (nome) VALUES ('Campus Central'), ('Campus Zona Norte');

INSERT INTO curso (id_campus, nome) VALUES 
(1, 'Ciência da Computação'), 
(1, 'Engenharia de Software');

INSERT INTO curriculo (id_curso, ano_vigencia, ativo) VALUES 
(1, 2023, TRUE), 
(2, 2023, TRUE);

-- 2. Disciplinas em Cadeia (para testar recursão)
INSERT INTO disciplina (codigo, nome, carga_horaria) VALUES
('CC101', 'Introdução à Programação', 60),
('CC102', 'Estruturas de Dados', 60),
('CC103', 'Algoritmos Avançados', 60),
('CC104', 'Banco de Dados I', 60),
('CC105', 'Banco de Dados II', 60),
('MAT101', 'Cálculo I', 90),
('MAT102', 'Cálculo II', 90);

-- Árvore de Pré-requisitos
INSERT INTO pre_requisito (id_disciplina, id_requisito) VALUES
(2, 1), -- ED precisa de IntroProg
(3, 2), -- AlgAvancados precisa de ED
(4, 1), -- BD I precisa de IntroProg
(5, 4), -- BD II precisa de BD I
(7, 6); -- Calc II precisa de Calc I

-- Vincular ao Currículo
INSERT INTO curriculo_disciplina (id_curriculo, id_disciplina, periodo, tipo) VALUES
(1, 1, 1, 'OBRIGATORIA'), (1, 6, 1, 'OBRIGATORIA'),
(1, 2, 2, 'OBRIGATORIA'), (1, 7, 2, 'OBRIGATORIA'), (1, 4, 2, 'OBRIGATORIA'),
(1, 3, 3, 'OBRIGATORIA'), (1, 5, 3, 'OBRIGATORIA');

-- 3. Professores (Incluindo 1 sem turmas para testar LEFT JOIN)
INSERT INTO professor (matricula, nome, email, titulacao) VALUES
('PRF001', 'Alan Turing', 'turing@univ.edu', 'DOUTOR'),
('PRF002', 'Ada Lovelace', 'ada@univ.edu', 'DOUTOR'),
('PRF003', 'Edgar Codd', 'codd@univ.edu', 'MESTRE'),
('PRF004', 'Grace Hopper', 'hopper@univ.edu', 'DOUTOR'),
('PRF005', 'Professor Sem Turma', 'semturma@univ.edu', 'ESPECIALISTA');

-- 4. Períodos Letivos
INSERT INTO periodo_letivo (ano, semestre, data_inicio, data_fim) VALUES
(2024, 1, '2024-02-01', '2024-06-30'),
(2024, 2, '2024-08-01', '2024-12-15'),
(2025, 1, '2025-02-01', '2025-06-30');

-- 5. Turmas (12 turmas criadas)
INSERT INTO turma (id_disciplina, id_periodo_letivo, id_professor, codigo_turma) VALUES
(1, 1, 1, 'T01'), (6, 1, 2, 'T01'), -- 2024.1
(2, 2, 1, 'T01'), (4, 2, 3, 'T01'), (7, 2, 2, 'T01'), -- 2024.2
(3, 3, 4, 'T01'), (5, 3, 3, 'T01'), (1, 3, 1, 'T02'), -- 2025.1
(2, 3, 2, 'T02'), (4, 3, 3, 'T02'), (6, 3, 4, 'T02'), (7, 3, 2, 'T02');

-- 6. Carga de 150 Alunos usando generate_series
INSERT INTO aluno (id_curriculo, matricula, nome, email)
SELECT 
    1,
    '2024' || LPAD(i::text, 5, '0'),
    'Aluno ' || i,
    'aluno' || i || '@discente.univ.edu'
FROM generate_series(1, 150) AS i;

-- 7. Carga de 450+ Matrículas com Notas Variadas
-- 2024.1 (Intro Prog e Calc I)
INSERT INTO matricula (id_aluno, id_turma, nota_final, faltas, situacao)
SELECT id_aluno, 1, ROUND((random() * 4 + 6)::numeric, 2), 2, 'APROVADO' FROM aluno WHERE id_aluno <= 100;

INSERT INTO matricula (id_aluno, id_turma, nota_final, faltas, situacao)
SELECT id_aluno, 2, ROUND((random() * 5 + 5)::numeric, 2), 4, 'APROVADO' FROM aluno WHERE id_aluno <= 100;

-- 2024.2 (Estrutura de Dados e BD I)
INSERT INTO matricula (id_aluno, id_turma, nota_final, faltas, situacao)
SELECT id_aluno, 3, ROUND((random() * 5 + 4)::numeric, 2), 0, 'APROVADO' FROM aluno WHERE id_aluno <= 100;

INSERT INTO matricula (id_aluno, id_turma, nota_final, faltas, situacao)
SELECT id_aluno, 4, ROUND((random() * 6 + 4)::numeric, 2), 1, 'APROVADO' FROM aluno WHERE id_aluno <= 100;

-- 2025.1 (Novos alunos e alunos avançando)
INSERT INTO matricula (id_aluno, id_turma, nota_final, faltas, situacao)
SELECT id_aluno, 8, NULL, 0, 'MATRICULADO' FROM aluno WHERE id_aluno > 100;

INSERT INTO matricula (id_aluno, id_turma, nota_final, faltas, situacao)
SELECT id_aluno, 6, NULL, 0, 'MATRICULADO' FROM aluno WHERE id_aluno <= 50;