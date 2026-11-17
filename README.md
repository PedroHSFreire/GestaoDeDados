# MedGuide

Aplicação de acompanhamento de saúde com cliente Flutter e API Python/FastAPI.

## Componentes

- `medguide_flutter/` — interface Flutter organizada em MVVM, com cadastro, consultas, medicamentos, exames, perfil e área de documentos.
- `medguide_api/` — API FastAPI com autenticação JWT, persistência SQLite e pipeline de proteção documental.
- [`GestãoDeDados_Info.md`](GestãoDeDados_Info.md) — guia completo de instalação, dependências, configuração, pipeline de mascaramento, testes e limitações reais.
- `EVIDENCIAS_TESTES.md` — execuções verificadas, alcance e limitações dos testes.
- `PITCH_ROTEIRO.md` — roteiro de 7 minutos alinhado ao estado funcional registrado.

## Início rápido

1. Siga [medguide_api/README.md](medguide_api/README.md) para instalar Python, dependências, Tesseract com idiomas `por`/`eng`, modelo spaCy, configurar `.env` e iniciar a API.
2. Siga [medguide_flutter/README.md](medguide_flutter/README.md) para instalar dependências Flutter e iniciar o cliente apontando `API_BASE_URL` para a API.
3. Consulte `http://127.0.0.1:8000/api/health` para verificar disponibilidade do backend e dependências de OCR/NER.

O app e as rotas de API comunicam-se por HTTP. OCR real depende da instalação do Tesseract; a evidência de máscara disponível é texto sintético e os testes de ingestão substituem OCR por resposta controlada. O Gatekeeper é heurístico. Use documentos fictícios ou autorizados e não interprete a máscara como garantia de anonimização ou conformidade legal.

Os horários de medicamentos ficam salvos para consulta, sem notificações de sistema nesta versão. Consulte `PITCH_ROTEIRO.md` para apresentar essas fronteiras com clareza.
