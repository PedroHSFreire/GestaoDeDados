# MedGuide — GestãoDeDados_Info

**Guia de execução, arquitetura, mascaramento e evidências**
Data de revisão: 17/11/2026

Este guia consolida os requisitos de dependências e instalação, os trechos centrais do pipeline de privacidade, os logs de testes disponíveis e o estado real da integração. Ele foi conferido com os arquivos do projeto.

### Leitura rápida

O MedGuide tem um aplicativo Flutter e uma API FastAPI. O aplicativo envia operações à API por HTTP, e a API salva os dados em SQLite. Nesta documentação, “comprovado” significa que existe um teste executado e registrado; “implementado” significa que há código para a função, mas isso não garante que todos os cenários tenham sido testados. Os testes de consultas, prontuários e exames foram executados contra a API HTTP usando dados fictícios. O processamento de uma imagem real não foi comprovado neste ambiente porque o OCR e/ou o modelo de reconhecimento de português não estavam disponíveis.

### Termos usados

- **API:** serviço que recebe pedidos do aplicativo e devolve respostas.
- **OCR:** leitura automática do texto que aparece em uma imagem.
- **NER:** reconhecimento automático de entidades, como nomes e organizações, em um texto.
- **Presidio:** biblioteca que ajuda a localizar e ocultar dados identificáveis.
- **Gatekeeper:** etapa do sistema que decide se o texto mascarado pode ser aprovado, precisa de revisão ou deve ser bloqueado. A decisão atual usa regras e um indicador heurístico.
- **Smoke test (teste de fluxo básico):** verificação rápida de vários endpoints funcionando em sequência.
- **Fixture/mock:** resposta de teste que substitui uma dependência externa. Nos testes de ingestão, o OCR é substituído; portanto, esses testes não leem uma imagem de verdade.

| Requisito solicitado | Seção deste guia |
|---|---|
| `requirements.txt`, `pubspec.yaml`, `.env.example`, instalação e execução do zero | 2 e 3 |
| Limpeza de metadados, OCR, Presidio/NER, validação e Gatekeeper | 4 |
| Logs de mascaramento, bloqueio e testes | 5 |
| Integração real, simulações e limitações | 1 e 7 |

## 1. Visão geral e status atual

O projeto tem dois componentes:

- `medguide_flutter/`: aplicativo Flutter com telas de autenticação, consultas, prontuário, medicamentos, exames, documentos e perfil. Usa MVVM, Provider, Dio e armazenamento seguro do token.
- `medguide_api/`: API FastAPI em Python, autenticação JWT e persistência SQLite. Contém as rotas e o pipeline de privacidade.

O cliente tem `API_BASE_URL` configurável e os serviços Flutter chamam endpoints HTTP da API local. O servidor atualmente configurado para desenvolvimento responde em `http://127.0.0.1:8000`; a interface web pode ser iniciada em `http://127.0.0.1:5000`. A API e a interface têm integração por HTTP implementada. Os testes desta documentação não constituem uma validação completa de todos os fluxos ponta a ponta.

| Parte | Estado verificado | Limite atual |
|---|---|---|
| Autenticação, consultas, perfil, medicamentos e exames | Rotas da API e chamadas do aplicativo implementadas; dados persistidos em SQLite. O smoke test verificou cadastro/login, prontuário, prescrição e exame pela API HTTP. | O smoke test não percorreu todas as telas do Flutter. Notificações de medicamentos não são enviadas. |
| Prescrição clínica | Gravada na consulta e consultável no histórico e na seção de prescrições em Medicamentos. | A lista é informativa; não cria automaticamente horários da rotina pessoal. |
| Tratamento documental | Consentimento, limpeza de metadados, rota OCR, mascaramento Presidio/NER e decisão do Gatekeeper implementados. | OCR real por imagem não foi comprovado nesta execução. |
| Testes de ingestão | Testes verificam consentimento, aprovação, bloqueio e persistência usando respostas de OCR controladas. | Eles não exercitam o Tesseract nem demonstram leitura de imagem. |
| Gatekeeper | Reanálise do texto mascarado e regras heurísticas de risco residual. | Não é uma métrica jurídica, estatística ou garantia de anonimização. |

O Tesseract não estava instalado no ambiente da execução documentada. O pipeline retorna indisponibilidade se o executável ou o modelo spaCy português estiver ausente. Mascaramento reduz exposição, mas não garante anonimização nem conformidade automática. Use apenas documentos fictícios ou autorizados.

## 2. Dependências e arquivos de configuração

### 2.1 API Python

O arquivo fonte de dependências é [`medguide_api/requirements.txt`](medguide_api/requirements.txt):

```text
fastapi==0.121.3
uvicorn[standard]==0.38.0
pydantic-settings==2.11.0
email-validator==2.3.0
PyJWT==2.10.1
pwdlib[argon2]==0.2.1
pillow==12.0.0
pytesseract==0.3.13
presidio-analyzer==2.2.366
presidio-anonymizer==2.2.366
spacy==3.8.11
```

`requirements-dev.txt` acrescenta as ferramentas de teste. O NER português é instalado como pacote de modelo separado: `pt_core_news_sm`. O arquivo [`medguide_api/requirements-dev.txt`](medguide_api/requirements-dev.txt) inclui `pytest==9.0.2` e `httpx==0.28.1`, além de importar `requirements.txt`.

### 2.2 Cliente Flutter

O arquivo fonte é [`medguide_flutter/pubspec.yaml`](medguide_flutter/pubspec.yaml). O SDK declarado é `^3.13.5`. Dependências diretas:

```yaml
cupertino_icons: ^1.0.8
dio: ^5.11.1
provider: ^6.1.5+1
flutter_secure_storage: ^11.2.0
image_picker: ^1.2.4
image: ^4.13.1
```

Dependências de desenvolvimento: `flutter_test` e `flutter_lints: ^6.0.0`.

### 2.3 Variáveis de ambiente

O modelo de configuração fica em [`medguide_api/.env.example`](medguide_api/.env.example):

```dotenv
APP_ENV=development
JWT_SECRET=replace-with-a-random-secret-at-least-32-characters
DATABASE_PATH=./data/medguide.sqlite3
ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
TESSERACT_CMD=
TESSERACT_LANGUAGES=por+eng
MAX_UPLOAD_BYTES=8388608
MIN_OCR_CONFIDENCE=0.55
MAX_RESIDUAL_RISK=0.2
```

Copie o exemplo para `.env` e troque o placeholder do segredo por um valor aleatório exclusivo. Não publique `.env`. Se o executável não estiver no `PATH`, `TESSERACT_CMD` recebe o caminho completo do Tesseract.

### 2.4 Tesseract OCR

Instale o Tesseract 5 e os dados de idioma português (`por`) e inglês (`eng`). O [guia de instalação do Tesseract](https://tesseract-ocr.github.io/tessdoc/Installation.html) documenta os pacotes por sistema e aponta instaladores Windows de terceiros mantidos pela UB Mannheim. No Windows, inclua `por` e `eng` durante a instalação e adicione o diretório do executável ao `PATH`. Verifique:

```powershell
tesseract --version
tesseract --list-langs
```

No resultado de `--list-langs`, confirme `por` e `eng`. No Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install tesseract-ocr tesseract-ocr-por tesseract-ocr-eng
```

O pipeline usa também o pacote spaCy `pt_core_news_sm`, instalado pelo comando `python -m spacy download pt_core_news_sm`, conforme a [documentação de modelos do spaCy](https://spacy.io/usage/models).

## 3. Instalação e execução do zero

Os passos abaixo usam PowerShell no Windows. Para Flutter, instale o SDK e a plataforma-alvo seguindo a [documentação oficial de instalação](https://docs.flutter.dev/install).

### 3.1 Preparar a API

Abra um PowerShell na pasta do projeto e execute:

```powershell
Set-Location .\medguide_api
py -3.14 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m spacy download pt_core_news_sm
Copy-Item .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Copie o segredo gerado para `JWT_SECRET` no `.env`. Configure `TESSERACT_CMD` apenas se `tesseract` não for encontrado pelo `PATH`. Inicie:

```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Verifique `http://127.0.0.1:8000/api/health`. Para o fluxo de documentos, os campos `ocr_binary_available` e `portuguese_ner_model_available` devem ser `true`. A documentação da API fica em `http://127.0.0.1:8000/docs`.

### 3.2 Preparar o Flutter

Em outro PowerShell:

```powershell
Set-Location .\medguide_flutter
flutter doctor
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Para web:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Abra o endereço mostrado pelo comando. No emulador Android, use `--dart-define=API_BASE_URL=http://10.0.2.2:8000`. Em dispositivo físico, aponte para o endereço acessível do computador que executa a API e ajuste `ALLOWED_ORIGINS` para a origem usada.

### 3.3 Fluxo para reproduzir o mascaramento

1. Registre e autentique uma conta de paciente.
2. Confirme que o health check informa as dependências de OCR/NER disponíveis.
3. Abra **Documentos**, selecione receita, exame ou laudo, leia e aceite o consentimento.
4. Envie uma imagem fictícia JPEG, PNG ou WEBP, com até 8 MB após o pré-processamento.
5. Confira a decisão `approved`, `review` ou `blocked`, as categorias detectadas e o texto retornado.

Somente o texto mascarado aprovado é persistido. Ausência de Tesseract ou do modelo NER resulta em HTTP 503; isso é indisponibilidade, não um teste de OCR.

## 4. Mascaramento, OCR, validação e Gatekeeper

Os trechos abaixo correspondem a `medguide_api/app/privacy/pipeline.py` e `medguide_api/app/routers/privacy.py`.

### 4.1 Limpeza de metadados

```python
def sanitize_image_bytes(raw: bytes) -> bytes:
    with Image.open(io.BytesIO(raw)) as source:
        source.verify()
    with Image.open(io.BytesIO(raw)) as source:
        clean = ImageOps.exif_transpose(source).convert("RGB")
        buffer = io.BytesIO()
        clean.save(buffer, format="PNG", optimize=True)
        return buffer.getvalue()
```

A imagem é decodificada, orientada e regravada em PNG a partir dos pixels. O Flutter também regrava a imagem antes de enviar bytes à API.

### 4.2 OCR e confiança

`extract_text(clean_image)` configura o executável via `TESSERACT_CMD`, chama `pytesseract.image_to_data` com idiomas `por+eng` e `--psm 6`, concatena as palavras e calcula confiança média normalizada. Imagem e texto bruto ficam em memória durante a requisição.

### 4.3 Presidio/NER e regexes

`get_analyzer()` configura `AnalyzerEngine` com spaCy em português (`pt_core_news_sm`) e recognizers contextuais para CPF, CRM, nome, idade, convênio e endereço. `mask_text(text)` analisa entidades, usa `AnonymizerEngine` para substituí-las por rótulos (`[NOME]`, `[CPF]`, entre outros) e aplica uma segunda passagem de regexes para CPF, CRM, e-mail, telefone, CEP, datas e outros padrões estruturados.

### 4.4 Gatekeeper e persistência

`assess_residual_risk(masked_text)` procura identificadores ainda presentes e combinações de quase-identificadores. O escore é uma heurística configurável, não uma probabilidade calibrada.

Em `medguide_api/app/routers/privacy.py`, a rota `POST /api/privacy/ingest` valida autenticação, consentimento, tipo e MIME; exige Tesseract e modelo NER; e decide:

- OCR vazio: bloqueia sem persistir.
- Confiança menor que `MIN_OCR_CONFIDENCE`: retorna `review` sem persistir.
- Risco maior que `MAX_RESIDUAL_RISK`: retorna `blocked` sem persistir.
- Resultado aprovado: grava apenas texto mascarado e metadados mínimos em `protected_documents`; não grava imagem nem OCR bruto.

Arquivos principais: [`pipeline.py`](medguide_api/app/privacy/pipeline.py), [`privacy.py`](medguide_api/app/routers/privacy.py), [`config.py`](medguide_api/app/config.py), [`document_ingestion_view_model.dart`](medguide_flutter/lib/viewmodels/document_ingestion_view_model.dart) e [`privacy_service.dart`](medguide_flutter/lib/services/privacy_service.dart).

## 5. Logs e resultados de testes

### 5.1 Exemplo de texto fictício mascarado

Este exemplo de mascaramento foi executado com texto sintético e Presidio/spaCy. Ele não é leitura de imagem:

```text
ENTRADA FICTÍCIA: Paciente: Ana Exemplo, CPF: 000.000.000-00. CRM 123456. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
TEXTO MASCARADO: [NOME], CPF: [CPF]. [CRM]. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
CATEGORIAS: CPF, CRM, NOME
RISCO RESIDUAL (heurístico): 0.0; sem achados
```

### 5.2 Resultado de bloqueio coberto por teste

O teste `test_gatekeeper_blocks_and_does_not_persist_residual_risk` substitui o OCR por uma fixture e força risco residual `0.7`. A resposta exercitada pela asserção é `decision: blocked`; a rota inclui `risk_score: 0.7` e `findings: ["CPF"]`. A consulta posterior a `/api/privacy/documents` confirma lista vazia. A entrada de imagem do teste é `b"fake image"`; portanto, o caso valida a decisão e a não persistência, não OCR real.

### 5.3 Saídas de verificação registradas

Suíte da API:

```text
python -m pip install -r requirements-dev.txt
python -m pytest -q
13 passed, 1 warning
```

O aviso conhecido é de depreciação do alias `anyio.abc.BlockingPortal` na integração Starlette/TestClient. Os testes incluem mascaramento, detecção de risco, consentimento, persistência aprovada, bloqueio sem persistência, validação de erros, IDs UUIDv4, prescrição no histórico, visibilidade em Medicamentos e solicitações de exames.

Flutter:

```text
dart analyze
Analyzing medguide_flutter...
No issues found!

flutter test
00:00 +0: ApiClient.messageFor traduz erros de validação sem mostrar os valores enviados
00:00 +1: ApiClient.messageFor orienta quando o serviço está temporariamente indisponível
00:00 +2: exibe login e alterna para cadastro sem coletar CPF
00:00 +3: All tests passed!
```

Não há captura de tela de OCR real nos registros disponíveis. Para demonstrar OCR de imagem, instale Tesseract e os idiomas, confirme `/api/health` e execute o fluxo com imagem fictícia legível.

### 5.4 Teste de fluxo básico da API (HTTP)

Em 17/11/2026 foi executado um teste de fluxo básico com um servidor local da API iniciado pelo próprio script, chamadas HTTP e um banco SQLite temporário. Foram usados usuários e dados clínicos fictícios; o banco normal do projeto não foi tocado. O teste verificou cadastro e login de paciente e profissional, criação e confirmação de consulta, gravação e leitura do prontuário e da prescrição, gravação de prontuário sem prescrição, rejeição de detalhes de medicamento sem nome (HTTP 422) e solicitação de exame visível na lista do paciente. A API também devolveu HTTP 503 padronizado na tentativa de ingestão porque OCR/NER não estavam disponíveis. Esse último resultado confirma a resposta de indisponibilidade; não confirma leitura de imagem.

Reprodução no PowerShell, a partir de `medguide_api`:

```powershell
.\.venv\Scripts\python.exe tests\smoke_http_workflow.py
```

O script está em [`smoke_http_workflow.py`](medguide_api/tests/smoke_http_workflow.py); a saída completa está em [`EVIDENCIAS_TESTES.md`](EVIDENCIAS_TESTES.md). Esse teste chama a API diretamente; não é uma gravação da tela nem uma validação completa do fluxo visual no Flutter. Não foram fornecidas capturas reais do app nesta etapa; quando recebidas, podem ser anexadas como evidência separada, sem criar imagens simuladas.

Detalhes adicionais: [`EVIDENCIAS_TESTES.md`](EVIDENCIAS_TESTES.md).

## 6. Referências

- Brasil. **Lei nº 13.709/2018 — Lei Geral de Proteção de Dados Pessoais**. [Planalto](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm).
- Microsoft. **Presidio — Data Protection and De-identification SDK**. [Documentação](https://microsoft.github.io/presidio/).
- spaCy. **Models & Languages**. [Documentação](https://spacy.io/usage/models).
- Tesseract OCR. **Installation**. [Documentação](https://tesseract-ocr.github.io/tessdoc/Installation.html).
- Flutter. **Install Flutter**. [Documentação](https://docs.flutter.dev/install).
- Python Software Foundation. **Python 3 documentation**. [Documentação](https://docs.python.org/3/).
- FastAPI. **Tutorial — User Guide**. [Documentação](https://fastapi.tiangolo.com/tutorial/).

## 7. Limites a declarar

O app tem rotas HTTP e serviços Flutter ligados à API FastAPI, com persistência SQLite. A validação local comprova testes automatizados da API e do cliente, mas não comprova OCR real: os testes de ingestão fazem mock da etapa OCR e o executável Tesseract não estava instalado no ambiente usado para estes registros. O Gatekeeper usa regras heurísticas; OCR/NER podem falhar. Mascaramento não elimina risco de reidentificação nem substitui revisão humana, controles de segurança, validação com documentos representativos ou avaliação jurídica.
