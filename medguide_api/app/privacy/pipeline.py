import io
import re
import shutil
from dataclasses import dataclass
from functools import lru_cache

import pytesseract
from PIL import Image, ImageOps
from presidio_analyzer import AnalyzerEngine, Pattern, PatternRecognizer
from presidio_analyzer.nlp_engine import NlpEngineProvider
from presidio_anonymizer import AnonymizerEngine
from presidio_anonymizer.entities import OperatorConfig

from app.config import get_settings

Image.MAX_IMAGE_PIXELS = 24_000_000

DIRECT_PATTERNS: dict[str, re.Pattern[str]] = {
    "CPF": re.compile(r"(?<!\d)\d{3}\.?\d{3}\.?\d{3}-?\d{2}(?!\d)"),
    "CRM": re.compile(r"(?i)\bCRM\s*[-:]?\s*[A-Z]{0,2}\s*\d{4,8}\b"),
    "EMAIL": re.compile(r"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"),
    "TELEFONE": re.compile(r"(?<!\d)(?:\+?55\s*)?(?:\(?\d{2}\)?\s*)?9?\d{4}[-. ]?\d{4}(?!\d)"),
    "CEP": re.compile(r"(?<!\d)\d{5}-?\d{3}(?!\d)"),
    "DATA": re.compile(r"(?<!\d)(?:\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2})(?!\d)"),
    "CONVENIO": re.compile(r"(?i)\b(?:conv[eê]nio|carteirinha|matr[ií]cula)\s*[:\-]?\s*[A-Z0-9.-]{6,20}\b"),
    "ENDERECO": re.compile(r"(?i)\b(?:rua|avenida|av\.|alameda|travessa|estrada)\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ][\wÁÉÍÓÚÂÊÔÃÕÇáéíóúâêôãõç]+(?:\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ][\wÁÉÍÓÚÂÊÔÃÕÇáéíóúâêôãõç]+){0,4},?\s*(?:n[º°o]?\.?\s*)?\d{1,5}\b"),
}

ENTITY_LABELS = {
    "PERSON": "NOME",
    "BR_PERSON": "NOME",
    "BR_CPF": "CPF",
    "BR_CRM": "CRM",
    "EMAIL_ADDRESS": "EMAIL",
    "PHONE_NUMBER": "TELEFONE",
    "LOCATION": "LOCAL",
    "DATE_TIME": "DATA",
    "BR_AGE": "FAIXA_ETARIA",
    "BR_INSURANCE_ID": "CONVENIO",
    "BR_ADDRESS": "ENDERECO",
    "US_DRIVER_LICENSE": "IDENTIFICADOR",
    "IBAN_CODE": "IDENTIFICADOR",
    "IP_ADDRESS": "IDENTIFICADOR",
}


@dataclass(frozen=True)
class OCRResult:
    text: str
    confidence: float


@dataclass(frozen=True)
class MaskResult:
    text: str
    categories: tuple[str, ...]


@dataclass(frozen=True)
class RiskResult:
    score: float
    findings: tuple[str, ...]


def configure_tesseract() -> None:
    settings = get_settings()
    if settings.tesseract_cmd:
        pytesseract.pytesseract.tesseract_cmd = settings.tesseract_cmd
    if not shutil.which(pytesseract.pytesseract.tesseract_cmd):
        raise RuntimeError("Tesseract OCR não encontrado no PATH")


def sanitize_image_bytes(raw: bytes) -> bytes:
    """Decode pixels, apply orientation and re-encode without source metadata."""
    with Image.open(io.BytesIO(raw)) as source:
        source.verify()
    with Image.open(io.BytesIO(raw)) as source:
        clean = ImageOps.exif_transpose(source).convert("RGB")
        buffer = io.BytesIO()
        clean.save(buffer, format="PNG", optimize=True)
        return buffer.getvalue()


def extract_text(clean_image: bytes) -> OCRResult:
    configure_tesseract()
    settings = get_settings()
    with Image.open(io.BytesIO(clean_image)) as image:
        data = pytesseract.image_to_data(
            image,
            lang=settings.tesseract_languages,
            config="--psm 6",
            output_type=pytesseract.Output.DICT,
        )
        words = [word.strip() for word in data["text"] if word and word.strip()]
        confidence_values = [
            float(value) / 100
            for value, word in zip(data["conf"], data["text"])
            if word and word.strip() and str(value).strip() not in {"-1", ""}
        ]
        text = " ".join(words).strip()
        confidence = sum(confidence_values) / len(confidence_values) if confidence_values else 0.0
    return OCRResult(text=text, confidence=confidence)


@lru_cache(maxsize=1)
def get_analyzer() -> AnalyzerEngine:
    configuration = {
        "nlp_engine_name": "spacy",
        "models": [{"lang_code": "pt", "model_name": "pt_core_news_sm"}],
    }
    nlp_engine = NlpEngineProvider(nlp_configuration=configuration).create_engine()
    analyzer = AnalyzerEngine(nlp_engine=nlp_engine, supported_languages=["pt"])
    recognizers = [
        PatternRecognizer(
            supported_entity="BR_CPF",
            patterns=[Pattern("cpf_br", r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b", 0.8)],
            context=["cpf", "documento", "titular"],
            supported_language="pt",
        ),
        PatternRecognizer(
            supported_entity="BR_CRM",
            patterns=[Pattern("crm_br", r"\bCRM\s*[-:]?\s*[A-Z]{0,2}\s*\d{4,8}\b", 0.85)],
            context=["médico", "medica", "crm", "prescritor"],
            supported_language="pt",
        ),
        PatternRecognizer(
            supported_entity="BR_PERSON",
            patterns=[Pattern("patient_label", r"(?i)(?:paciente|titular|nome)\s*[:\-]\s*[A-ZÁÉÍÓÚÂÊÔÃÕÇ][a-záéíóúâêôãõç]+(?:\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ][a-záéíóúâêôãõç]+){1,3}", 0.65)],
            context=["paciente", "titular", "nome"],
            supported_language="pt",
        ),
        PatternRecognizer(
            supported_entity="BR_AGE",
            patterns=[Pattern("age_years", r"\b\d{1,3}\s+anos?\b", 0.55)],
            context=["idade", "anos"],
            supported_language="pt",
        ),
        PatternRecognizer(
            supported_entity="BR_INSURANCE_ID",
            patterns=[Pattern("insurance_member_id", r"(?i)\b(?:conv[eê]nio|carteirinha|matr[ií]cula)\s*[:\-]?\s*[A-Z0-9.-]{6,20}\b", 0.7)],
            context=["convênio", "carteirinha", "matrícula", "operadora"],
            supported_language="pt",
        ),
        PatternRecognizer(
            supported_entity="BR_ADDRESS",
            patterns=[Pattern("brazil_address", DIRECT_PATTERNS["ENDERECO"].pattern, 0.65)],
            context=["endereço", "rua", "avenida", "residente"],
            supported_language="pt",
        ),
    ]
    for recognizer in recognizers:
        analyzer.registry.add_recognizer(recognizer)
    return analyzer


def _exclude_medication_ner_false_positives(text: str, results: list) -> list:
    filtered = []
    for result in results:
        trailing = text[result.end : result.end + 32]
        dosage_follows = bool(
            result.entity_type == "PERSON"
            and re.match(r"\s+\d+(?:[,.]\d+)?\s*(?:mg|mcg|µg|g|ml|mL|UI|%)\b", trailing, re.IGNORECASE)
        )
        if not dosage_follows:
            filtered.append(result)
    return filtered


def mask_text(text: str) -> MaskResult:
    analyzer = get_analyzer()
    results = _exclude_medication_ner_false_positives(text, analyzer.analyze(text=text, language="pt"))
    operators = {
        entity: OperatorConfig("replace", {"new_value": f"[{label}]"})
        for entity, label in ENTITY_LABELS.items()
    }
    anonymized = AnonymizerEngine().anonymize(text=text, analyzer_results=results, operators=operators)
    categories = tuple(sorted({ENTITY_LABELS.get(result.entity_type, "IDENTIFICADOR") for result in results}))
    # Regex backstops catch Brazilian identifiers if OCR context/NER misses them.
    safe_text = anonymized.text
    for category, expression in DIRECT_PATTERNS.items():
        label = "DATA" if category == "DATA" else category
        safe_text = expression.sub(f"[{label}]", safe_text)
        if expression.search(text):
            categories = tuple(sorted(set(categories) | {label}))
    return MaskResult(text=safe_text, categories=categories)


def assess_residual_risk(masked_text: str) -> RiskResult:
    findings: set[str] = set()
    for category, expression in DIRECT_PATTERNS.items():
        if expression.search(masked_text):
            findings.add(category)
    try:
        residual_entities = _exclude_medication_ner_false_positives(
            masked_text, get_analyzer().analyze(text=masked_text, language="pt")
        )
        for entity in residual_entities:
            label = ENTITY_LABELS.get(entity.entity_type, "IDENTIFICADOR")
            if f"[{label}]" not in masked_text[entity.start : entity.end + 16]:
                findings.add(label)
    except Exception as exc:
        raise RuntimeError("Não foi possível avaliar os identificadores residuais") from exc

    age_found = bool(re.search(r"\b\d{1,3}\s+anos?\b", masked_text, re.IGNORECASE))
    exact_date = bool(re.search(r"\b(?:\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2})\b", masked_text))
    location_found = bool(re.search(r"\b(?:em|de|no|na)\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ][a-záéíóúâêôãõç]{3,}(?:\s+[A-ZÁÉÍÓÚÂÊÔÃÕÇ][a-záéíóúâêôãõç]+)?\b", masked_text))
    quasi_identifiers = sum((age_found, exact_date, location_found))
    if quasi_identifiers >= 2:
        findings.add("COMBINACAO_DE_ATRIBUTOS")
    direct_count = sum(1 for item in findings if item in DIRECT_PATTERNS or item in {"NOME", "LOCAL", "IDENTIFICADOR"})
    if direct_count:
        score = min(1.0, 0.7 + 0.1 * (direct_count - 1))
    else:
        score = min(1.0, quasi_identifiers * 0.15)
    return RiskResult(score=round(score, 2), findings=tuple(sorted(findings)))
