-- ============================================================================
-- CRIAÇÃO DO BANCO DE DADOS
-- ============================================================================

# 1. Criar o Banco de Dados
psql -U postgres -c "CREATE DATABASE sistema_academico;"


-- ============================================================================
-- SCRIPT 01: DDL E RESTRIÇÕES DE INTEGRIDADE
-- ============================================================================

CREATE TABLE IF NOT EXISTS tb_pais (
    id_pais SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL UNIQUE,
    codigo_iso2 CHAR(2) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS tb_estado (
    id_estado SERIAL PRIMARY KEY,
    id_pais INT NOT NULL REFERENCES tb_pais(id_pais) ON DELETE RESTRICT,
    nome VARCHAR(100) NOT NULL,
    uf CHAR(2) NOT NULL,
    CONSTRAINT uk_estado_uf UNIQUE (id_pais, uf)
);

CREATE TABLE IF NOT EXISTS tb_municipio (
    id_municipio SERIAL PRIMARY KEY,
    id_estado INT NOT NULL REFERENCES tb_estado(id_estado) ON DELETE RESTRICT,
    nome VARCHAR(100) NOT NULL,
    codigo_ibge INT UNIQUE
);

CREATE TABLE IF NOT EXISTS tb_campus (
    id_campus SERIAL PRIMARY KEY,
    id_municipio INT NOT NULL REFERENCES tb_municipio(id_municipio) ON DELETE RESTRICT,
    nome VARCHAR(100) NOT NULL,
    endereco VARCHAR(200)
);

-- Tabela Geral de Cursos (Catálogo Geral)
CREATE TABLE IF NOT EXISTS tb_curso (
    id_curso SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    grau VARCHAR(30) NOT NULL CHECK (grau IN ('BACHARELADO', 'LICENCIATURA', 'TECNOLOGO', 'POS_GRADUACAO'))
);

-- Tabela Associativa (Oferta de Cursos por Campus - N:N)
CREATE TABLE IF NOT EXISTS tb_campus_curso (
    id_campus_curso SERIAL PRIMARY KEY,
    id_campus INT NOT NULL REFERENCES tb_campus(id_campus) ON DELETE CASCADE,
    id_curso INT NOT NULL REFERENCES tb_curso(id_curso) ON DELETE RESTRICT,
    turno_predominante VARCHAR(20) CHECK (turno_predominante IN ('MATUTINO', 'VESPERTINO', 'NOTURNO', 'INTEGRAL')),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uk_campus_curso UNIQUE (id_campus, id_curso)
);

-- Currículo vinculado à oferta específica do Campus
CREATE TABLE IF NOT EXISTS tb_curriculo (
    id_curriculo SERIAL PRIMARY KEY,
    id_campus_curso INT NOT NULL REFERENCES tb_campus_curso(id_campus_curso) ON DELETE RESTRICT,
    codigo_matriz VARCHAR(20) NOT NULL,
    ano_vigencia SMALLINT NOT NULL CHECK (ano_vigencia >= 2000),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uk_curriculo_campus_codigo UNIQUE (id_campus_curso, codigo_matriz)
);

CREATE TABLE IF NOT EXISTS tb_disciplina (
    id_disciplina SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nome VARCHAR(120) NOT NULL,
    carga_horaria SMALLINT NOT NULL CHECK (carga_horaria > 0)
);

CREATE TABLE IF NOT EXISTS tb_curriculo_disciplina (
    id_curriculo INT NOT NULL REFERENCES tb_curriculo(id_curriculo) ON DELETE CASCADE,
    id_disciplina INT NOT NULL REFERENCES tb_disciplina(id_disciplina) ON DELETE CASCADE,
    periodo SMALLINT NOT NULL CHECK (periodo > 0),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('OBRIGATORIA', 'ELETIVA', 'OPTATIVA')),
    PRIMARY KEY (id_curriculo, id_disciplina)
);

CREATE TABLE IF NOT EXISTS tb_pre_requisito (
    id_disciplina INT NOT NULL REFERENCES tb_disciplina(id_disciplina) ON DELETE CASCADE,
    id_requisito INT NOT NULL REFERENCES tb_disciplina(id_disciplina) ON DELETE CASCADE,
    vinculo VARCHAR(20) NOT NULL DEFAULT 'OBRIGATORIO' CHECK (vinculo IN ('OBRIGATORIO', 'RECOMENDADO')),
    PRIMARY KEY (id_disciplina, id_requisito),
    CONSTRAINT chk_requisito_diferente CHECK (id_disciplina <> id_requisito)
);

CREATE TABLE IF NOT EXISTS tb_pessoa (
    id_pessoa SERIAL PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    cpf CHAR(11) UNIQUE
);

CREATE TABLE IF NOT EXISTS tb_aluno (
    id_aluno SERIAL PRIMARY KEY,
    id_pessoa INT NOT NULL UNIQUE REFERENCES tb_pessoa(id_pessoa) ON DELETE RESTRICT,
    id_curriculo INT NOT NULL REFERENCES tb_curriculo(id_curriculo) ON DELETE RESTRICT,
    matricula VARCHAR(12) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS tb_professor (
    id_professor SERIAL PRIMARY KEY,
    id_pessoa INT NOT NULL UNIQUE REFERENCES tb_pessoa(id_pessoa) ON DELETE RESTRICT,
    matricula VARCHAR(12) UNIQUE NOT NULL,
    titulacao VARCHAR(20) NOT NULL CHECK (titulacao IN ('ESPECIALISTA', 'MESTRE', 'DOUTOR'))
);

CREATE TABLE IF NOT EXISTS tb_sala (
    id_sala SERIAL PRIMARY KEY,
    id_campus INT NOT NULL REFERENCES tb_campus(id_campus) ON DELETE CASCADE,
    bloco VARCHAR(10) NOT NULL,
    numero VARCHAR(10) NOT NULL,
    capacidade SMALLINT NOT NULL CHECK (capacidade > 0),
    CONSTRAINT uk_sala_campus_bloco_num UNIQUE (id_campus, bloco, numero)
);

CREATE TABLE IF NOT EXISTS tb_feriado (
    id_feriado SERIAL PRIMARY KEY,
    id_estado INT REFERENCES tb_estado(id_estado) ON DELETE CASCADE,
    id_municipio INT REFERENCES tb_municipio(id_municipio) ON DELETE CASCADE,
    data DATE NOT NULL,
    descricao VARCHAR(120) NOT NULL,
    abrangencia VARCHAR(20) NOT NULL CHECK (abrangencia IN ('NACIONAL', 'ESTADUAL', 'MUNICIPAL')),
    CONSTRAINT chk_feriado_abrangencia CHECK (
        (abrangencia = 'NACIONAL'  AND id_estado IS NULL AND id_municipio IS NULL) OR
        (abrangencia = 'ESTADUAL'  AND id_estado IS NOT NULL AND id_municipio IS NULL) OR
        (abrangencia = 'MUNICIPAL' AND id_municipio IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS tb_periodo_letivo (
    id_periodo_letivo SERIAL PRIMARY KEY,
    ano SMALLINT NOT NULL CHECK (ano >= 2000),
    semestre SMALLINT NOT NULL CHECK (semestre IN (1, 2)),
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    CONSTRAINT chk_datas_periodo CHECK (data_fim > data_inicio),
    CONSTRAINT uk_ano_semestre UNIQUE (ano, semestre)
);

CREATE TABLE IF NOT EXISTS tb_turma (
    id_turma SERIAL PRIMARY KEY,
    id_disciplina INT NOT NULL REFERENCES tb_disciplina(id_disciplina) ON DELETE RESTRICT,
    id_periodo_letivo INT NOT NULL REFERENCES tb_periodo_letivo(id_periodo_letivo) ON DELETE RESTRICT,
    id_professor INT NOT NULL REFERENCES tb_professor(id_professor) ON DELETE RESTRICT,
    codigo_turma VARCHAR(10) NOT NULL,
    CONSTRAINT uk_disciplina_periodo_turma UNIQUE (id_disciplina, id_periodo_letivo, codigo_turma)
);

-- Ajuste de tipo no Horário (Substituição do TSRANGE incoerente por TIME)
CREATE TABLE IF NOT EXISTS tb_turma_horario (
    id_turma_horario SERIAL PRIMARY KEY,
    id_turma INT NOT NULL REFERENCES tb_turma(id_turma) ON DELETE CASCADE,
    id_sala INT NOT NULL REFERENCES tb_sala(id_sala) ON DELETE RESTRICT,
    dia_semana SMALLINT NOT NULL CHECK (dia_semana BETWEEN 1 AND 7), -- 1=Domingo, 7=Sábado
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    CONSTRAINT chk_horario_valido CHECK (hora_fim > hora_inicio)
);

CREATE TABLE IF NOT EXISTS tb_matricula (
    id_matricula SERIAL PRIMARY KEY,
    id_aluno INT NOT NULL REFERENCES tb_aluno(id_aluno) ON DELETE CASCADE,
    id_turma INT NOT NULL REFERENCES tb_turma(id_turma) ON DELETE CASCADE,
    nota_final NUMERIC(4,2) CHECK (nota_final BETWEEN 0.00 AND 10.00),
    faltas INT NOT NULL DEFAULT 0 CHECK (faltas >= 0),
    situacao VARCHAR(20) NOT NULL DEFAULT 'MATRICULADO' CHECK (situacao IN ('APROVADO', 'REPROVADO', 'MATRICULADO', 'TRANCADO')),
    CONSTRAINT uk_aluno_turma UNIQUE (id_aluno, id_turma)
);

-- Log mantido mesmo se a matrícula for removida
CREATE TABLE IF NOT EXISTS tb_log_matricula (
    id_log_matricula SERIAL PRIMARY KEY,
    id_matricula INT, -- Sem NOT NULL rígido para preservar histórico caso a matrícula seja excluída
    id_aluno INT NOT NULL,
    id_turma INT NOT NULL,
    acao VARCHAR(20) NOT NULL,
    detalhes TEXT,
    ocorrido_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

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