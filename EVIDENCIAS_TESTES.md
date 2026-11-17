# Evidências de verificação — MedGuide

Atualizado em 17/11/2026. Use somente dados fictícios nas demonstrações.

## Tratamento de erros

A API padroniza erros de validação com nomes de campos em português e não ecoa os valores enviados. Falhas inesperadas retornam mensagem genérica ao cliente; o log registra apenas o tipo da exceção, sem corpo da requisição ou texto sensível. O Flutter traduz erros HTTP e de conexão em mensagens acionáveis e mostra falhas ocorridas em formulários e diálogos sem fechar o formulário.

## Suíte atual da API

Comando executado em `medguide_api`:

```text
python -m pytest -q
.......                                                                  [100%]
13 passed, 1 warning in 4.23s
```

O aviso é uma depreciação do alias `anyio.abc.BlockingPortal` na integração TestClient/Starlette. Os testes cobrem máscara de identificadores e preservação de conteúdo clínico sintético, detecção de risco residual, aprovação e persistência somente de texto mascarado, falta de consentimento, bloqueio sem persistência, atualização de consulta sem medicação, exigência do nome quando há detalhes de prescrição, retorno de validação legível sem ecoar dados, criação de exame pelo médico com leitura posterior na lista do paciente, atualização do registro clínico com os campos de medicação, UUIDv4, alias legado de rota e envelope padronizado para 404. Nas rotas de documentos, a chamada de OCR é substituída por fixture (mock), logo os testes não exercitam o Tesseract.

O cenário de exame confirma a consulta, registra um hemograma com autenticação do médico e valida que `/api/exams/me` do paciente devolve o exame e o nome do profissional.

O registro clínico envia os campos de medicação para `PATCH /api/appointments/{id}`. A rota agora permite esses campos; o teste confirma a gravação no histórico e a leitura na rota paciente `GET /api/medications/prescribed`. IDs de recursos são UUIDv4; as rotas antigas de autenticação e os métodos PUT permanecem como aliases para compatibilidade, enquanto o app usa os caminhos plurais e PATCH.

## Smoke test HTTP com banco descartável

Em 17/11/2026 executei um segundo cenário em processo Uvicorn real, usando chamadas HTTP locais, contas fictícias geradas a cada execução e banco SQLite temporário. O script inicia e encerra seu próprio servidor e remove o banco temporário ao finalizar; não altera `database.sqlite3` da aplicação. Reproduza em `medguide_api` com o ambiente virtual ativado:

```powershell
.\.venv\Scripts\python.exe tests\smoke_http_workflow.py
```

Saída observada:

```text
PASS health endpoint HTTP
PASS cadastro e autenticacao HTTP para paciente e profissional
PASS consulta, gravacao do prontuario e leitura da prescricao pelo paciente
PASS prontuario sem prescricao; detalhes sem nome retornam validacao 422 padronizada
PASS solicitacao de exame visivel na area do paciente
LIMIT OCR real nao executado: dependencia Tesseract/NER indisponivel; API respondeu 503 padronizado
```

Isso comprova os endpoints e a persistência no banco temporário para o fluxo clínico descrito. Também comprova que a indisponibilidade de OCR/NER resulta em resposta de serviço indisponível padronizada. Não comprova leitura de imagem, entrega visual do Flutter, nem aptidão para uso clínico ou produção.

## Análise do Flutter

`dart analyze` (executado após as mudanças):

```text
dart analyze
Analyzing medguide_flutter...
No issues found!
```

Teste de widget Flutter:

```text
flutter test
00:00 +0: ApiClient.messageFor traduz erros de validação sem mostrar os valores enviados
00:00 +1: ApiClient.messageFor orienta quando o serviço está temporariamente indisponível
00:00 +2: exibe login e alterna para cadastro sem coletar CPF
00:00 +3: All tests passed!
```

Os testes incluem mensagens para validação e indisponibilidade temporária, além do widget de entrada/cadastro. Não cobrem todos os estados da interface.

## Demonstração de máscara de texto

Entrada totalmente fictícia e saída registrada na execução anterior com Presidio/spaCy:

```text
ENTRADA: Paciente: Ana Exemplo, CPF: 000.000.000-00. CRM 123456. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
SAÍDA:   [NOME], CPF: [CPF]. [CRM]. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
CATEGORIAS: CPF, CRM, NOME
RISCO RESIDUAL (heurístico): 0.0; sem achados
```

Esse é um exemplo de processamento de texto sintético, não uma receita fotografada nem resultado de OCR.

## OCR e captura da aplicação

O smoke test HTTP desta rodada confirmou a comunicação direta dos endpoints com a API e registrou que a ingestão retorna 503 quando as dependências OCR/NER estão indisponíveis. Não há evidência de OCR real por imagem nem captura de tela do fluxo concluído. Instale Tesseract 5 e os idiomas `por`/`eng`, configure o modelo spaCy e consulte `GET /api/health`; ambos devem ser informados como disponíveis antes de demonstrar ingestão. A API e o cliente têm serviços HTTP integrados, porém esta rodada não comprova o fluxo visual Flutter → OCR → Gatekeeper com uma imagem real.

## Registro de verificações anteriores

Na versão anterior à expansão das funcionalidades, o registro local indicava `5 passed` para a API e um teste Flutter aprovado. Após a expansão, foi registrada compilação Flutter web e análise sem problemas e compilação sintática Python. Esses resultados históricos não substituem a execução acima nem atestam integração dos fluxos novos. O teste de tela não foi reexecutado nesta rodada.
