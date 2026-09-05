"""
AI interpretation service.

Wraps the Anthropic API to turn raw dream text into:
  - a warm, non-clinical interpretation (2-4 sentences)
  - 3-5 short mood/theme tags
  - a punchy one-line "card headline" for the shareable Dream Card

Kept provider-agnostic at the call boundary (`interpret_dream`) so you can
swap in a different LLM provider later without touching callers.
"""
import json
import logging
from dataclasses import dataclass

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
medical or psychological diagnosis. Keep interpretations concise, emotionally
resonant, and never alarming. Respond ONLY with valid JSON matching this schema:
{
  "interpretation": "2-4 sentence interpretation",
  "mood_tags": ["tag1", "tag2", "tag3"],
  "card_headline": "a punchy, shareable one-line takeaway, max 12 words"
}
No markdown, no extra commentary, JSON only."""


@dataclass
class DreamInterpretation:
    interpretation: str
    mood_tags: list[str]
    card_headline: str


@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=1, max=8))
def interpret_dream(raw_text: str) -> DreamInterpretation:
    if not settings.ANTHROPIC_API_KEY:
        # Safe local/dev fallback so the app is runnable without a live key.
        logger.warning("ANTHROPIC_API_KEY not set — returning stub interpretation")
        return DreamInterpretation(
            interpretation=(
                "This dream reflects a mind processing change and searching for "
                "steadiness. The imagery suggests curiosity mixed with a little "
                "uncertainty about what comes next."
            ),
            mood_tags=["change", "curiosity", "uncertainty"],
            card_headline="Your subconscious is preparing you for something new.",
        )

    client = _get_client()
    response = client.messages.create(
        model=settings.AI_MODEL_NAME,
        max_tokens=400,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": f"Dream: {raw_text}"}],
    )
    text_block = next((b.text for b in response.content if b.type == "text"), "{}")

    try:
        data = json.loads(text_block)
        return DreamInterpretation(
            interpretation=data["interpretation"],
            mood_tags=data.get("mood_tags", []),
            card_headline=data.get("card_headline", ""),
        )
    except (json.JSONDecodeError, KeyError) as exc:
        logger.error("Failed to parse AI response: %s | raw=%s", exc, text_block)
        raise
