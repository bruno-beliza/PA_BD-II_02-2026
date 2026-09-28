1. Responsável pela Modelagem Física e Desempenho: Samuel Rodrigues da Rocha Lima
- Implementação do DDL completo: tabelas, tipos, domínios, chaves e todas as restrições de integridade;
- Criação dos índices, incluindo ao menos um índice parcial;
- Evidências de EXPLAIN (ANALYZE, BUFFERS) antes e depois de cada índice, com o ganho medido.

2. Responsável por Transações e Concorrência: Murilo Monteiro de Jesus
- Reprodução da anomalia de concorrência na disputa pela última vaga de uma turma;
- Implementação de duas correções distintas — uma por bloqueio explícito, outra por nível de isolamento;
- Comparação fundamentada entre as duas abordagens (custo, contenção, necessidade de retentativa).

3. Responsável por Administração e Operação: Bruno Washignton Gomes Belizário
- Views (oferta, vagas, histórico) e uma materialized view de indicadores com política de atualização justificada;
- Papéis de acesso (aluno, secretaria, coordenacao) com GRANT/REVOKE e row-level security;
- Procedimento de backup e restauração, documentado e reproduzível do zero.