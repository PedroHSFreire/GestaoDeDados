# MedGuide — conversão alinhada aos blocos de Gestão de Dados

## Escopo e critério

Os PDFs descrevem uma proposta acadêmica: aplicativo Flutter/MVVM, API Python/FastAPI e proteção de documentos de saúde por remoção de metadados, OCR, detecção de identificadores, mascaramento seletivo e uma etapa de validação de risco antes de persistir o resultado. Essa orientação foi tratada como requisito da conversão. Os PDFs não são evidência de que esses recursos já estivessem nos repositórios originais.

Os repositórios recebidos eram um front-end Next.js/React/TypeScript (`medguide_front`) e um back-end Node.js/Express/TypeScript (`Medguide`). A conversão foi criada como projetos novos e executáveis: `medguide_flutter` e `medguide_api`. As cópias de referência do código original continuam no diretório de trabalho deste atendimento; a pasta solicitada contém os projetos convertidos.

## Arquitetura convertida

### Flutter (`medguide_flutter`)

- `lib/models/`: modelos de usuário, consulta, medicamentos e solicitação de exames.
- `lib/services/`: comunicação HTTP, autenticação, consultas, medicamentos, exames e ingestão.
- `lib/viewmodels/`: estado e regras de apresentação (MVVM com Provider).
- `lib/views/`: login/cadastro, painel, consultas, medicamentos, exames, perfil e documentos.
- Dio para API, `flutter_secure_storage` para token, `image_picker` para imagem e `image` para decodificar/regravar pixels sem EXIF/GPS.
- Cadastro não pede CPF. Pacientes buscam profissionais, agendam/cancelam consultas, gerenciam medicamentos, consultam/cancelam exames e processam documentos com consentimento.
- Profissionais filtram consultas, confirmam/recusam/concluem, registram prontuário e solicitam exames vinculados a consultas.
- Perfis de paciente e profissional podem ser atualizados pela API; há FAQ acessível antes e depois da autenticação.
- Horários de medicamentos são persistidos; o protótipo não envia notificações push.

### Python/FastAPI (`medguide_api`)

- `app/routers/`: autenticação/perfis, consultas, medicamentos, exames e ingestão/documentos protegidos.
- `app/privacy/pipeline.py`: limpeza de imagem, Tesseract OCR, Presidio Analyzer/Anonymizer, recognizers e regras brasileiras, avaliação heurística de risco residual.
- `app/security.py`, `app/database.py`, `app/schemas.py`: JWT e perfis, persistência SQLite e validação.
- `app/middleware.py`: limite de corpo da requisição; a imagem é processada em memória.
- `tests/`: testes automatizados dos caminhos de mascaramento, consentimento, aprovação e bloqueio.

## Fluxo de proteção

1. O paciente seleciona imagem e concede consentimento explícito.
2. O Flutter regrava os pixels, removendo metadados EXIF/GPS, e envia bytes sem nome de arquivo.
3. A API aceita JPEG/PNG/WEBP, limita o corpo (8 MB por padrão), redecodifica/regrava a imagem e extrai texto com Tesseract (`por+eng`).
4. Presidio/spaCy português e recognizers/regexes detectam identificadores; Presidio Anonymizer substitui os identificadores por rótulos como `[NOME]` e `[CPF]`.
5. O Gatekeeper heurístico examina risco residual: baixa confiança de OCR encaminha para revisão; risco acima do limite bloqueia. Apenas o texto mascarado aprovado é persistido.

O caminho requer instalar Tesseract 5 com dados `por` e `eng`; `pt_core_news_sm` também precisa estar instalado. O computador usado para esta conversão não tinha o executável Tesseract, portanto OCR de imagem real não foi executado. O endpoint consulta essa dependência e responde indisponível até a instalação. Os testes do fluxo de endpoint usam OCR fictício controlado, sem alegar que houve OCR real.

Além do pipeline, os principais fluxos do cliente agora usam endpoints persistentes: CRUD de medicamentos por titular, edição de perfil, estados de consulta e prontuário, solicitação/status de exames. A antiga aba de exames lia `localStorage`, mas não possuía fluxo funcional para criar solicitações; agora o profissional solicita a partir de uma consulta existente. Os antigos botões de suporte/chat e recuperação/troca de senha não tinham implementação funcional completa e não são anunciados como ações ativas. O cronograma de medicamentos é salvo e exibido, sem notificações do sistema.

## Como executar

Consulte instruções completas em `medguide_api/README.md` e `medguide_flutter/README.md`.

Resumo no Windows:

1. Instale Python, Flutter/Dart e Tesseract OCR com idiomas português e inglês.
2. Na pasta `medguide_api`, crie/ative `.venv`, instale `requirements.txt`, instale `pt_core_news_sm`, copie `.env.example` para `.env` e gere `JWT_SECRET` próprio com pelo menos 32 caracteres.
3. Inicie `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`.
4. Na pasta `medguide_flutter`, execute `flutter pub get` e `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`. Para Firefox use `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:8000` e abra o endereço impresso. Android Emulator deve usar `http://10.0.2.2:8000`.
5. A documentação interativa da API estará em `http://127.0.0.1:8000/docs`.

## Evidências verificadas nesta conversão

- Na versão inicial, antes da expansão de paridade: API `python -m pytest -q` — 5 passaram; Flutter `flutter test` — 1 passou. Esses testes não cobrem os novos fluxos de perfil, medicamento e exames e não foram repetidos nesta expansão.
- Após a expansão: Flutter `flutter analyze` — **sem problemas**; `flutter build web --release --no-wasm-dry-run` — **compilação web concluída**; `python -m compileall -q app` — sintaxe Python compilada.
- Máscara de texto sintético executada com o modelo Presidio/spaCy instalado:

```text
ENTRADA FICTÍCIA: Paciente: Ana Exemplo, CPF: 000.000.000-00. CRM 123456. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
TEXTO MASCARADO: [NOME], CPF: [CPF]. [CRM]. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
CATEGORIAS: CPF, CRM, NOME
RISCO RESIDUAL (heurístico): 0.0; sem achados
```

O exemplo é texto sintético e prova a regra de mascaramento de texto, não uma leitura de receita por OCR. Os testes anteriores cobrem consentimento, aprovação e bloqueio apenas para o pipeline de documentos; não há captura de OCR real.

## Limitações e discurso correto para apresentação

- É correto dizer que a versão convertida tem cliente Flutter e API Python/FastAPI e que o front comunica com rotas da API configuráveis por `API_BASE_URL`. É um protótipo acadêmico; ainda requer configurar o ambiente e instalar Tesseract para executar OCR real.
- O escore de risco é uma heurística demonstrativa, não uma métrica legal/estatística validada. NER/OCR podem errar; a preservação de nomes de medicamentos usa regra contextual e precisa de avaliação com material representativo.
- Mascaramento/pseudonimização não garante anonimização nem conformidade LGPD. Não usar documentos reais ou em atendimento.
- Nenhuma imagem original nem OCR bruto é persistido; documentos aceitos guardam apenas o texto mascarado. Saídas de bloqueio/revisão não são armazenadas.
- A conversão não importou as contas/banco Node/SQLite. Migrações aditivas preservam contas já criadas no SQLite Python e adicionam os campos/tabelas novos.
- Recuperação/troca de senha e botões externos de suporte eram incompletos ou sem implementação funcional na versão recebida. Não foram convertidos como fluxos ativos.
