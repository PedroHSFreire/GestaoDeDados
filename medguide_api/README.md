# MedGuide API - FastAPI

API convertida para Python/FastAPI. Os endpoints ficam organizados em `app/routers`; autenticação, persistência SQLite e o pipeline de privacidade estão separados em módulos próprios.

## Requisitos

- Python 3.10 a 3.13 para versões anteriores do Presidio; a lista travada desta entrega usa Presidio 2.2.366 e foi instalada e executada também com Python 3.14.7.
- Tesseract OCR 5 com dados de idioma português (`por`) e inglês (`eng`). O [guia de instalação do Tesseract](https://tesseract-ocr.github.io/tessdoc/Installation.html) aponta o projeto de instaladores Windows mantido pela UB Mannheim; baixe o instalador e selecione os dados `por`/`eng`. Se o executável não estiver no `PATH`, configure `TESSERACT_CMD`.
- Modelo de NER português `pt_core_news_sm` para spaCy 3.8.11.

## Instalação no Windows

No PowerShell, dentro desta pasta:

```powershell
py -3.14 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m spacy download pt_core_news_sm
Copy-Item .env.example .env
```

Edite `.env`: gere um segredo aleatório com pelo menos 32 caracteres em `JWT_SECRET`. Não use o valor de exemplo. O arquivo `.env` não deve ser publicado.

O `.env.example` permite as origens locais `http://localhost:5000` e `http://127.0.0.1:5000`, usadas pelo comando de Flutter Web abaixo. Se iniciar o cliente em outra porta, acrescente a origem correspondente a `ALLOWED_ORIGINS`. Em produção, liste somente as origens efetivamente usadas.

Em Linux, instale o Tesseract e os dados de idioma pelo gerenciador da distribuição. Por exemplo, em Debian/Ubuntu:

```bash
sudo apt-get install tesseract-ocr tesseract-ocr-por tesseract-ocr-eng
```

## Executar

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Documentação interativa: `http://127.0.0.1:8000/docs`. A rota `GET /api/health` informa se o binário OCR e o modelo português estão disponíveis. O `database.sqlite3` local é criado na primeira inicialização conforme `DATABASE_PATH`.

## Endpoints principais

| Método | Rota | Acesso |
| --- | --- | --- |
| `POST` | `/api/patients/register`, `/api/doctors/register` | público |
| `POST` | `/api/patients/login`, `/api/doctors/login` | público |
| `GET`, `PATCH` | `/api/patients/me`, `/api/doctors/me` | titular; campos permitidos por perfil |
| `GET` | `/api/doctors/search`, `/api/doctors/specialties` | autenticado |
| `POST` | `/api/appointments` | paciente autenticado |
| `GET` | `/api/appointments/me` | paciente ou profissional autenticado |
| `GET` | `/api/appointments/{id}` | participante da consulta |
| `PATCH` | `/api/appointments/{id}` | titular da consulta; campos limitados por perfil |
| `GET`, `POST` | `/api/medications` | CRUD do próprio paciente |
| `PATCH`, `DELETE` | `/api/medications/{id}` | titular do medicamento |
| `GET` | `/api/medications/prescribed` | paciente; medicamentos prescritos no próprio histórico clínico |
| `GET` | `/api/exams/me` | solicitações do paciente ou profissional titular |
| `POST` | `/api/exams` | profissional com consulta vinculada ao paciente |
| `PATCH` | `/api/exams/{id}` | profissional responsável; paciente pode cancelar enquanto pendente |
| `POST` | `/api/privacy/ingest?document_type=receita` | paciente autenticado e consentimento explícito |
| `GET` | `/api/privacy/documents` | paciente autenticado; somente textos mascarados |

IDs de usuários, consultas, medicamentos, exames e documentos são UUID versão 4 gerados por `uuid4()`. As rotas antigas `/api/pacient/*` e `/api/doctor/*`, além de `/mine` e métodos `PUT` usados anteriormente para atualizações parciais, continuam disponíveis como aliases de compatibilidade; a documentação OpenAPI publica as formas canônicas acima.

Respostas de erro usam `{ "success": false, "error": { "code", "message", "action", "request_id" } }`. A API atribui `X-Request-ID` e registra timestamp, código, rota, método, usuário autenticado quando disponível e contexto seguro. Valores de formulário, texto clínico e conteúdo da requisição não entram nesses logs.

## Pipeline de ingestão

1. O Flutter decodifica e regrava os pixels da imagem, removendo EXIF/GPS. A requisição envia bytes binários em memória, sem nome de arquivo ou formulário multipart.
2. Um middleware limita o corpo da requisição (8 MB padrão) e o mantém em RAM. O backend valida formato e dimensão, redecodifica/regrava a imagem e passa os pixels sem metadados ao Tesseract (`por+eng`).
3. Presidio Analyzer com spaCy português e recognizers adicionais de CPF, CRM, nome contextual, idade, convênio e endereço detecta identificadores. Presidio Anonymizer substitui as entidades detectadas por rótulos como `[CPF]`; regexes brasileiras cobrem identificadores estruturados.
4. O Gatekeeper reanalisa o texto mascarado e calcula um indicador heurístico de risco residual. Baixa confiança de OCR exige revisão; risco acima de `MAX_RESIDUAL_RISK` bloqueia a persistência.
5. A tabela `protected_documents` recebe apenas `masked_text`, o tipo e metadados mínimos do processamento. Imagem original e texto OCR bruto não são escritos no banco nem nos logs. Saídas bloqueadas ou para revisão não são persistidas.

## Limites conhecidos

O escore do Gatekeeper é uma heurística demonstrativa, não uma medida legal ou estatística validada de anonimização. NER e OCR podem omitir identificadores ou mascarar conteúdo clínico; a preservação de medicamentos inclui uma regra contextual que requer avaliação com documentos representativos. A pseudonimização/mascaramento não elimina risco de reidentificação. Use somente material fictício e não empregue esta versão em atendimento ou com documentos reais.

As solicitações de exame guardam tipo, descrição, status, vínculos por ID e data. Só o profissional com consulta vinculada pode criá-las; a listagem não expõe telefone ou e-mail do paciente. O cadastro não solicita CPF. Os horários de medicamentos são registros consultáveis; a API não envia notificações.

## Testes

```powershell
python -m pip install -r requirements-dev.txt
python -m pytest -q
```

Os testes automatizados cobrem a máscara seletiva, a detecção de risco, consentimento, fluxo de aprovação e a garantia de que um resultado bloqueado não seja persistido. O teste de endpoint substitui a chamada do Tesseract por OCR fictício; a execução do OCR real depende de instalar Tesseract com `por`/`eng`.
