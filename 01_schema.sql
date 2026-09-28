-- ============================================================================
-- SCRIPT 01: DDL E RESTRIÇÕES DE INTEGRIDADE
-- ============================================================================

CREATE TABLE IF NOT EXISTS campus (
    id_campus SERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS curso (
    id_curso SERIAL PRIMARY KEY,
    id_campus INT NOT NULL REFERENCES campus(id_campus) ON DELETE RESTRICT,
    nome VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS curriculo (
    id_curriculo SERIAL PRIMARY KEY,
    id_curso INT NOT NULL REFERENCES curso(id_curso) ON DELETE CASCADE,
    ano_vigencia SMALLINT NOT NULL CHECK (ano_vigencia >= 2000),
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS disciplina (
    id_disciplina SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nome VARCHAR(120) NOT NULL,
    carga_horaria SMALLINT NOT NULL CHECK (carga_horaria > 0)
);

CREATE TABLE IF NOT EXISTS curriculo_disciplina (
    id_curriculo INT NOT NULL REFERENCES curriculo(id_curriculo) ON DELETE CASCADE,
    id_disciplina INT NOT NULL REFERENCES disciplina(id_disciplina) ON DELETE CASCADE,
    periodo SMALLINT NOT NULL CHECK (periodo > 0),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('OBRIGATORIA', 'ELETIVA', 'OPTATIVA')),
    PRIMARY KEY (id_curriculo, id_disciplina)
);

CREATE TABLE IF NOT EXISTS pre_requisito (
    id_disciplina INT NOT NULL REFERENCES disciplina(id_disciplina) ON DELETE CASCADE,
    id_requisito INT NOT NULL REFERENCES disciplina(id_disciplina) ON DELETE CASCADE,
    vinculo VARCHAR(20) DEFAULT 'OBRIGATORIO',
    PRIMARY KEY (id_disciplina, id_requisito),
    CONSTRAINT chk_requisito_diferente CHECK (id_disciplina <> id_requisito)
);

CREATE TABLE IF NOT EXISTS aluno (
    id_aluno SERIAL PRIMARY KEY,
    id_curriculo INT NOT NULL REFERENCES curriculo(id_curriculo) ON DELETE RESTRICT,
    matricula VARCHAR(12) UNIQUE NOT NULL,
    nome VARCHAR(120) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS professor (
    id_professor SERIAL PRIMARY KEY,
    matricula VARCHAR(12) UNIQUE NOT NULL,
    nome VARCHAR(120) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    titulacao VARCHAR(20) NOT NULL CHECK (titulacao IN ('ESPECIALISTA', 'MESTRE', 'DOUTOR'))
);

CREATE TABLE IF NOT EXISTS sala (
    id_sala SERIAL PRIMARY KEY,
    id_campus INT NOT NULL REFERENCES campus(id_campus) ON DELETE CASCADE,
    bloco VARCHAR(10) NOT NULL,
    numero VARCHAR(10) NOT NULL,
    capacidade SMALLINT NOT NULL CHECK (capacidade > 0)
);

CREATE TABLE IF NOT EXISTS feriado (
    id_feriado SERIAL PRIMARY KEY,
    id_campus INT REFERENCES campus(id_campus) ON DELETE CASCADE,
    data DATE NOT NULL,
    descricao VARCHAR(120) NOT NULL
);

CREATE TABLE IF NOT EXISTS periodo_letivo (
    id_periodo_letivo SERIAL PRIMARY KEY,
    ano SMALLINT NOT NULL CHECK (ano >= 2000),
    semestre SMALLINT NOT NULL CHECK (semestre IN (1, 2)),
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    CONSTRAINT chk_datas_periodo CHECK (data_fim > data_inicio),
    CONSTRAINT uk_ano_semestre UNIQUE (ano, semestre)
);

CREATE TABLE IF NOT EXISTS turma (
    id_turma SERIAL PRIMARY KEY,
    id_disciplina INT NOT NULL REFERENCES disciplina(id_disciplina) ON DELETE RESTRICT,
    id_periodo_letivo INT NOT NULL REFERENCES periodo_letivo(id_periodo_letivo) ON DELETE RESTRICT,
    id_professor INT NOT NULL REFERENCES professor(id_professor) ON DELETE RESTRICT,
    codigo_turma VARCHAR(10) NOT NULL,
    CONSTRAINT uk_disciplina_periodo_turma UNIQUE (id_disciplina, id_periodo_letivo, codigo_turma)
);

CREATE TABLE IF NOT EXISTS turma_horario (
    id_turma_horario SERIAL PRIMARY KEY,
    id_turma INT NOT NULL REFERENCES turma(id_turma) ON DELETE CASCADE,
    id_sala INT NOT NULL REFERENCES sala(id_sala) ON DELETE RESTRICT,
    dia_semana SMALLINT NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    faixa TSRANGE NOT NULL
);

CREATE TABLE IF NOT EXISTS matricula (
    id_matricula SERIAL PRIMARY KEY,
    id_aluno INT NOT NULL REFERENCES aluno(id_aluno) ON DELETE CASCADE,
    id_turma INT NOT NULL REFERENCES turma(id_turma) ON DELETE CASCADE,
    nota_final NUMERIC(4,2) CHECK (nota_final BETWEEN 0.00 AND 10.00),
    faltas INT NOT NULL DEFAULT 0 CHECK (faltas >= 0),
    situacao VARCHAR(20) NOT NULL DEFAULT 'MATRICULADO' CHECK (situacao IN ('APROVADO', 'REPROVADO', 'MATRICULADO', 'TRANCADO')),
    CONSTRAINT uk_aluno_turma UNIQUE (id_aluno, id_turma)
);

CREATE TABLE IF NOT EXISTS log_matricula (
    id_log_matricula SERIAL PRIMARY KEY,
    id_matricula INT NOT NULL REFERENCES matricula(id_matricula) ON DELETE CASCADE,
    acao VARCHAR(20) NOT NULL,
    ocorrido_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);