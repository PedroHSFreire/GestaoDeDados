# MedGuide Flutter

Aplicativo móvel desenvolvido em Flutter e organizado em MVVM. Esta pasta substitui o cliente Next.js para a versão convertida. Os fluxos de entrada incluem cadastro e login de pacientes/profissionais, consultas e ingestão de imagens para processamento de privacidade.

## Arquitetura

```text
lib/
  models/        modelos de usuário, consulta, medicamento e solicitação de exame
  services/      cliente HTTP, autenticação, consultas, medicamentos, exames e ingestão
  viewmodels/    estado e lógica MVVM
  views/         telas de login, consultas, perfil, medicamentos, exames e documentos
  main.dart      tema, restauração de sessão e composição da aplicação
```

O token de sessão é guardado com `flutter_secure_storage`. O aplicativo usa `image_picker` para obter a imagem e reprocessa os pixels com o pacote `image`, removendo EXIF/GPS antes da requisição. O arquivo original não é enviado pelo cliente.

## Requisitos

- Flutter 3.47 ou superior e Dart 3.13.5 ou superior.
- Uma API FastAPI iniciada conforme `../medguide_api/README.md`.
- Dispositivo Android/iOS, navegador ou desktop. A captura pela câmera está disponível em Android/iOS; outros destinos usam seleção de arquivo.

## Executar

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

No emulador Android, use o endereço de host do emulador:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Em dispositivo físico, configure `API_BASE_URL` com o endereço acessível da máquina servidora. Para navegador, `http://localhost` funciona quando front e API estão na mesma máquina e a origem está permitida pelo CORS de desenvolvimento.

No Firefox, inicie o servidor web do Flutter e abra o endereço impresso no terminal:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

O `pubspec.yaml` registra as dependências do cliente, inclusive `image_picker`, `image`, `provider`, `dio` e `flutter_secure_storage`.

## Funcionalidades convertidas

- Cadastro e login por perfil, restauração da sessão, edição de perfil e encerramento de sessão.
- Busca de profissionais por nome/especialidade e agendamento pelo paciente com tipo, data, horário, motivo e observações.
- Filtro de consultas por situação; paciente pode cancelar e profissional pode confirmar, recusar, concluir e salvar diagnóstico, prescrição e observações do prontuário.
- CRUD de medicamentos por paciente: dose, vários horários, pausa/reativação e remoção. A aba também mostra, separadamente, as prescrições registradas pelo profissional nas consultas. Os horários ficam salvos para consulta; notificações do sistema não são simuladas.
- Solicitações de exames persistidas: o profissional cria a partir de uma consulta vinculada, acompanha e conclui/cancela; o paciente consulta e pode cancelar enquanto pendente.
- Dúvidas frequentes acessíveis antes e depois do login.
- Seleção/captura de receitas, exames ou laudos; consentimento explícito; pré-processamento sem metadados; resultado mascarado/bloqueado e lista de textos protegidos.

O CPF não é solicitado nem armazenado na versão convertida, alinhado à minimização de dados dos PDFs. Os antigos botões sem implementação funcional completa (suporte/chat e recuperação/troca de senha) não são apresentados como ações funcionais.

## Verificação

```bash
flutter analyze
flutter test
```
