# MedGuide — entrega Flutter + Python

- `medguide_flutter/`: app Flutter/MVVM com cadastro, sessão, busca/agendamento, prontuário, medicamentos, exames, perfil, FAQ e documentos protegidos.
- `medguide_api/`: API Python/FastAPI com SQLite, JWT, perfil e agenda, CRUD de medicamentos, solicitações de exames e pipeline de mascaramento.
- `ENTREGA_GESTAO_DE_DADOS.md`: escopo, arquitetura, instalação, evidências e limitações.
- `EVIDENCIAS_TESTES.md`: logs da versão inicial e checagens de compilação da expansão funcional.

Os projetos Next/Express originais continuam disponíveis nos repositórios informados: [front-end](https://github.com/PedroHSFreire/medguide_front) e [back-end](https://github.com/PedroHSFreire/Medguide). O código entregue aqui é a conversão, em pastas separadas.

Comece pelos READMEs dentro de cada projeto. No Firefox, inicie o Flutter com `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:8000` e abra o endereço impresso. OCR real requer Tesseract com idiomas `por` e `eng`.

Os horários de medicamentos são armazenados, mas não geram notificações do sistema. Não use documentos reais: OCR, mascaramento e Gatekeeper ainda são demonstrativos.
