# MedGuide | Roteiro de apresentação e demonstração

**Duração sugerida: 7 minutos.** Ajuste a fala ao tempo definido pela banca. Demonstre apenas com contas e documentos fictícios.

## Roteiro falado (o que dizer)

### 0:00–1:00 | A necessidade

“Informações de saúde são dados pessoais sensíveis. Uma receita compartilhada sem controle pode expor identidade, tratamento e vínculo com um serviço. O desafio prático é organizar o acesso e reduzir identificadores antes de guardar ou compartilhar o conteúdo.”

### 1:00–2:00 | A solução

“O MedGuide reúne operações de acompanhamento de saúde e uma etapa de proteção documental. O aplicativo Flutter conversa com uma API FastAPI. No fluxo documental, a imagem é regravada sem os metadados de origem, o Tesseract extrai texto, Presidio com spaCy e regras estruturadas buscam identificadores e o Gatekeeper decide entre aprovação, revisão e bloqueio. A proposta é reduzir exposição e tornar a decisão visível.”

### 2:00–5:30 | Demonstração

“Vou entrar com uma conta de paciente de demonstração, abrir Documentos e selecionar uma imagem fictícia. Antes do envio, o app solicita consentimento. A API processa o conteúdo e retorna o estado e as categorias encontradas. Se aprovado, a lista mostra somente o texto mascarado. Se a confiança estiver baixa, solicita revisão; se o risco residual superar o limite configurado, bloqueia a persistência.”

Fale com precisão: testes de API comprovam a decisão com OCR substituído por retorno de teste. O exemplo de máscara registrado é texto sintético. O OCR real só pode ser demonstrado depois de instalar Tesseract e validar `GET /api/health` com ambas as dependências disponíveis.

### 5:30–6:30 | Prontidão e limites

“A base funcional inclui autenticação, consultas, medicamentos, exames e a rota de documentos, com persistência SQLite e cliente Flutter integrado por HTTP. Para uso operacional ainda faltam validação com imagens representativas, revisão dos falsos positivos e negativos, hardening de implantação, monitoramento e avaliação de privacidade. O Gatekeeper é heurístico: o indicador não é certificação legal nem garantia de anonimização. Este ambiente serve para demonstração controlada e usa dados fictícios.”

### 6:30–7:00 | Fechamento

“O valor do MedGuide está em combinar um fluxo de saúde utilizável com controles explícitos de consentimento, mascaramento e decisão. O próximo passo é validar o desempenho e os controles em ambiente autorizado, com critérios mensuráveis e supervisão humana.”

## Ações na tela (o que mostrar)

1. **Antes da apresentação:** inicie API e Flutter; confira `/api/health`; deixe uma conta fictícia pronta. Se Tesseract/NER não estiverem disponíveis, não prometa processamento de imagem ao vivo; apresente o teste automatizado e o log de máscara de texto, nomeando claramente o que cada um comprova.
2. **Slide 1 — necessidade:** mostre três tipos de informação exposta em um documento (identificação, contato, contexto clínico), usando conteúdo inventado. Evite estatísticas sem fonte.
3. **Slide 2 — arquitetura:** desenhe Flutter → API FastAPI → limpeza/OCR/Presidio/Gatekeeper → SQLite somente com texto mascarado aprovado. Marque OCR como dependente do Tesseract local.
4. **Demo — documentos:** entre na conta paciente, abra Documentos, mostre o consentimento, selecione arquivo fictício e apresente decisão/categorias/texto mascarado. Mostre bloqueio/revisão apenas por meio de cenário de teste se não houver uma imagem de demonstração validada.
5. **Slide final — estado atual:** “Cliente e API conectados por HTTP; OCR de imagem depende da instalação e não foi comprovado nesta execução; Gatekeeper heurístico; testes de API cobrem fluxo com OCR substituído.”

## Preparação e contingência

- Confirme API, Flutter, modelo `pt_core_news_sm`, Tesseract e idiomas `por`/`eng` antes da banca.
- Use uma imagem sintética de boa legibilidade e remova qualquer dado real do dispositivo.
- Se a API não estiver saudável, não improvise a alegação de OCR: apresente `EVIDENCIAS_TESTES.md` e explique a diferença entre teste da regra e leitura real da imagem.
- Não chame o indicador de risco de “percentual de anonimização” e não alegue conformidade LGPD automática.
