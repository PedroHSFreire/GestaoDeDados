# Evidências de verificação — MedGuide convertido

Execução local em 16/11/2026. Os logs de testes abaixo são da versão inicial, antes da expansão de paridade de perfil/medicamentos/exames; a suíte não foi repetida após a expansão. O OCR do Tesseract não foi executado porque o binário não está instalado neste computador.

## API — `python -m pytest -q`

```text
.....                                                                    [100%]
5 passed, 1 warning in 2.84s
```

O aviso é uma depreciação interna do Starlette/AnyIO; os cinco testes passaram.

## Flutter — `flutter test`

```text
00:00 +0: exibe login e alterna para cadastro sem coletar CPF
00:00 +1: All tests passed!
```

## Flutter — `flutter analyze`

```text
Analyzing medguide_flutter...
No issues found!
```

## Flutter — `flutter build web --release`

```text
Compiling lib\main.dart for the Web... 67,8s
√ Built build\web
```

## Demonstração sintética de mascaramento

```text
ENTRADA FICTÍCIA: Paciente: Ana Exemplo, CPF: 000.000.000-00. CRM 123456. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
TEXTO MASCARADO: [NOME], CPF: [CPF]. [CRM]. Usar Dipirona 500 mg, 1 comprimido a cada 8 horas.
CATEGORIAS: CPF, CRM, NOME
RISCO RESIDUAL (heurístico): 0.0; sem achados
```

Esse exemplo roda o mascaramento de texto com Presidio/spaCy usando uma entrada inteiramente fictícia. Não é uma foto nem comprovação de OCR real. Os testes automatizados substituem a extração OCR nos testes da rota e verificam aprovação, consentimento e bloqueio antes de persistir.

## Dependência ausente para OCR real

O executável Tesseract não foi encontrado no host. O endpoint `/api/health` sinaliza `ocr_binary_available: false`, e `/api/privacy/ingest` retorna indisponibilidade até a instalação. Instale Tesseract 5 com pacotes de idioma `por` e `eng` conforme o README da API.

## Verificações após a expansão de funcionalidades

```text
Flutter: flutter analyze
No issues found!

Flutter: flutter build web --release --no-wasm-dry-run
√ Built build\web

Python: python -m compileall -q app
Python syntax compilation completed.
```

Essas verificações confirmam análise estática e compilação; não substituem testes de integração dos novos fluxos de perfil, medicamento e exames.
