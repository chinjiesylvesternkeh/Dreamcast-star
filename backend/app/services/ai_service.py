"""
AI interpretation service.

Wraps the Anthropic API to turn raw dream text into:
  - a warm, non-clinical interpretation whose depth follows the user's plan
    (standard / deep / oracle — see app/plans.py)
  - 3-5 short mood/theme tags
  - a punchy one-line "card headline" for the shareable Dream Card

Kept provider-agnostic at the call boundary (`interpret_dream`) so you can
swap in a different LLM provider later without touching callers.
"""
import json
import logging
from dataclasses import dataclass
from typing import Optional, Sequence

from anthropic import Anthropic
from tenacity import retry, stop_after_attempt, wait_exponential

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

_client: Anthropic | None = None


def _get_client() -> Anthropic:
    global _client
    if _client is None:
        _client = Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client


SYSTEM_PROMPT = """You are DreamCast's dream interpreter. You write warm, insightful,
non-clinical dream interpretations grounded in common dream-symbolism traditions
(Jungian archetypes, everyday psychology) while being clear you are not offering
medical or psychological diagnosis. Keep interpretations emotionally resonant and
never alarming. Respond ONLY with valid JSON matching this schema:
{{
  "interpretation": "{interpretation_spec}",
  "mood_tags": ["tag1", "tag2", "tag3"],
  "card_headline": "a punchy, shareable one-line takeaway, max 12 words",
  "image_prompt": "a short visual scene description in English for an illustration of the dream, max 25 words"
}}
{language_instruction}
Separate paragraphs inside "interpretation" with a blank line (\\n\\n).
No markdown, no extra commentary, JSON only."""

# Reading depth per plan: (what to ask for, token budget).
DEPTHS = {
    "standard": ("a concise 2-4 sentence interpretation", 400),
    "deep": (
        "an in-depth interpretation in 3 short paragraphs: the dream's overall "
        "meaning; the 2-3 most important symbols and what each suggests; and one "
        "practical reflection for the dreamer's waking life",
        900,
    ),
    "oracle": (
        "an oracle-depth interpretation in 4 short paragraphs: the dream's overall "
        "meaning; its key symbols; how it connects to the dreamer's recent dreams "
        "(recurring symbols, emotions or progressions — say plainly if there is no "
        "clear link); and close with one guiding question for the dreamer to "
        "carry through the day",
        1200,
    ),
}


# The reading follows the user's app language; image prompts stay in English
# because image models follow English best.
LANGUAGE_INSTRUCTIONS = {
    "en": "Write the interpretation, mood tags and card headline in English.",
    "fr": (
        "Write the interpretation, mood tags and card headline in natural, warm French, "
        "addressing the dreamer as « vous ». Keep image_prompt in English."
    ),
}


@dataclass
class DreamInterpretation:
    interpretation: str
    mood_tags: list[str]
    card_headline: str
    image_prompt: str = ""


# Local/dev stand-in so the app runs without a live key: (paragraphs, tags, headline).
_STUB = {
    "en": (
        [
            "This dream reflects a mind processing change and searching for steadiness. "
            "The imagery suggests curiosity mixed with a little uncertainty about what comes next.",
            "The setting stands for your inner landscape right now, and movement through it "
            "hints that you are ready to explore it rather than avoid it.",
            "What would change if you trusted the direction you are already moving in?",
        ],
        ["change", "curiosity", "uncertainty"],
        "Your subconscious is preparing you for something new.",
    ),
    "fr": (
        [
            "Ce rêve reflète un esprit qui traverse un changement et cherche un point d'équilibre. "
            "Ses images mêlent la curiosité à une légère incertitude quant à la suite.",
            "Le décor représente votre paysage intérieur du moment, et le fait de le parcourir "
            "montre que vous êtes prêt à l'explorer plutôt qu'à l'éviter.",
            "Que changerait-il si vous faisiez confiance à la direction que vous prenez déjà ?",
        ],
        ["changement", "curiosité", "incertitude"],
        "Votre inconscient vous prépare à quelque chose de nouveau.",
    ),
}


def _recent_dreams_context(recent_dreams: Sequence) -> str:
    lines = []
    for dream in recent_dreams:
        date = dream.created_at.strftime("%Y-%m-%d") if dream.created_at else "earlier"
        summary = dream.card_headline or (dream.raw_text or "")[:160]
        tags = f" (themes: {dream.mood_tags})" if dream.mood_tags else ""
        lines.append(f"- {date}: {summary}{tags}")
    return "\n".join(lines) if lines else "- none yet"


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=8))
def interpret_dream(
    raw_text: str,
    depth: str = "standard",
    recent_dreams: Optional[Sequence] = None,
    language: str = "en",
) -> DreamInterpretation:
    interpretation_spec, max_tokens = DEPTHS.get(depth, DEPTHS["standard"])
    language_instruction = LANGUAGE_INSTRUCTIONS.get(language, LANGUAGE_INSTRUCTIONS["en"])

    if not settings.ANTHROPIC_API_KEY:
        logger.warning("ANTHROPIC_API_KEY not set — returning stub interpretation")
        paragraphs, tags, headline = _STUB.get(language, _STUB["en"])
        count = {"standard": 1, "deep": 2, "oracle": 3}.get(depth, 1)
        return DreamInterpretation(
            interpretation="\n\n".join(paragraphs[:count]),
            mood_tags=list(tags),
            card_headline=headline,
            image_prompt="a dreamer drifting through a softly glowing night landscape",
        )

    content = f"Dream: {raw_text}"
    if recent_dreams is not None:
        content += (
            "\n\nThe dreamer's recent dreams, newest first:\n"
            + _recent_dreams_context(recent_dreams)
        )

    client = _get_client()
    response = client.messages.create(
        model=settings.AI_MODEL_NAME,
        max_tokens=max_tokens,
        system=SYSTEM_PROMPT.format(
            interpretation_spec=interpretation_spec, language_instruction=language_instruction
        ),
        messages=[{"role": "user", "content": content}],
    )
    text_block = next((b.text for b in response.content if b.type == "text"), "{}")

    try:
        data = json.loads(text_block)
        return DreamInterpretation(
            interpretation=data["interpretation"],
            mood_tags=data.get("mood_tags", []),
            card_headline=data.get("card_headline", ""),
            image_prompt=data.get("image_prompt", ""),
        )
    except (json.JSONDecodeError, KeyError) as exc:
        logger.error("Failed to parse AI response: %s | raw=%s", exc, text_block)
        raise
