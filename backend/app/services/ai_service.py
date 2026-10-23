"""
AI interpretation service.

Turns raw dream text into a reading delivered in the voice of the DreamCast
Oracle — a wise, gentle white witch and dream seer:
  - a titled reading in sections ("### Heading" + body), whose length and
    depth follow the user's plan (standard / deep / oracle — see app/plans.py)
  - 3-5 short mood/theme tags
  - a shareable one-line "card headline" for the Dream Card
  - an English scene description for the Dream Card image

The reading is returned in the user's language (English or French). Output
is constrained with structured outputs, so it always parses.

Kept provider-agnostic at the call boundary (`interpret_dream`) so you can
swap in a different LLM provider later without touching callers.
"""

import json
import logging
from dataclasses import dataclass
from typing import Optional, Sequence

import anthropic
from anthropic import Anthropic

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

_client: Anthropic | None = None


def _get_client() -> Anthropic:
    global _client
    if _client is None:
        # The SDK retries rate limits, overloads and connection errors itself.
        _client = Anthropic(api_key=settings.ANTHROPIC_API_KEY, max_retries=2)
    return _client


class ReadingUnavailable(Exception):
    """The model declined or could not complete a reading for this dream."""


# Stable across requests (and cacheable): persona, craft and safety rules.
# Per-request specifics — depth, language, recent dreams — go in the user turn.
SYSTEM_PROMPT = """You are the Oracle of DreamCast: a wise, gentle white witch and dream seer who has listened to dreams for a lifetime. You read dreams the way a trusted elder reads the sky: with warmth, quiet authority and wonder.

VOICE
- Speak directly to the dreamer as "you", like a seer sitting across a candlelit table: lyrical but clear, never vague, never theatrical.
- Draw on the great traditions of dream-lore: Jungian archetypes and the shadow, world folklore and myth, elemental symbolism (water, fire, earth, air), the phases of the moon, thresholds and journeys, and archetypal imagery akin to the tarot. Name a tradition when it deepens the meaning.
- Every reading must be about THIS dream. Echo the dreamer's own images, colours, places and feelings, and explain what each one may be telling them now. Never pad with generic statements, and never retell the whole dream back.
- Offer layered meanings ("on one level… and deeper still…") rather than one flat answer.
- Close with warmth: a blessing, an encouragement or a gentle charge to carry into the day.

TRUTH AND CARE (these rules override everything else)
- A reading is for reflection and entertainment. Speak of possibilities ("may", "often", "invites you to"), never certainties. Never predict the future as fact, and never foretell death, illness, accidents, disaster, curses or misfortune.
- Never diagnose or give medical, psychological, legal or financial advice. Do not claim to be human or to hold real supernatural power; the Oracle is a storytelling voice.
- If the dream touches on trauma, violence, abuse, self-harm, grief or deep fear, or the dreamer seems distressed, be especially gentle, do not dramatise, and in the guidance encourage them to lean on people they trust or a qualified professional — and to contact local emergency services if they ever feel unsafe.
- Any ritual you suggest must be simple, safe, free and optional: journaling, a glass of water by the bed, a few slow breaths, a walk in daylight, opening a window to the morning, an attended candle. Never suggest ingesting anything, fasting, risky fire, harming any being, or any working aimed at another person.

FORMAT
- Section bodies are plain prose: no markdown, bullet points, numbered lists or emoji. A body may contain several paragraphs separated by a blank line.
- Write the section headings exactly as given in the request, in the dreamer's language."""

# Sections per plan depth: (headings by language, what each section covers, target length, effort).
DEPTHS = {
    "standard": {
        "headings": {
            "en": ["The Vision", "The Symbols", "The Message"],
            "fr": ["La vision", "Les symboles", "Le message"],
        },
        "guide": [
            "what this dream as a whole is revealing about the dreamer's inner life right now",
            "the two most important images in the dream, each with its traditional meaning and its meaning for the dreamer",
            "the guidance the dream offers, ending with a short blessing",
        ],
        "words": "about 300 words in total",
    },
    "deep": {
        "headings": {
            "en": ["The Vision", "The Symbols", "The Hidden Currents", "The Guidance", "A Small Ritual"],
            "fr": ["La vision", "Les symboles", "Les courants cachés", "La guidance", "Un petit rituel"],
        },
        "guide": [
            "what this dream as a whole is revealing about the dreamer's inner life right now",
            "the three or four key images, each explained through the traditions it belongs to and what it may mean for the dreamer",
            "the feelings and unspoken questions the dream is working through beneath its imagery",
            "a practical reflection for the dreamer's waking life over the coming days",
            "one simple, safe ritual to honour the dream, ending with a short blessing",
        ],
        "words": "about 600 words in total",
    },
    "oracle": {
        "headings": {
            "en": [
                "The Vision", "The Symbols", "Threads Across Your Nights",
                "The Hidden Currents", "The Guidance", "The Question to Carry",
            ],
            "fr": [
                "La vision", "Les symboles", "Les fils de vos nuits",
                "Les courants cachés", "La guidance", "La question à porter",
            ],
        },
        "guide": [
            "what this dream as a whole is revealing about the dreamer's inner life right now",
            "every significant image, each explained through the traditions it belongs to and what it may mean for the dreamer",
            "how this dream connects to the dreamer's recent dreams listed below — recurring symbols, emotions or a story unfolding night after night; if there is no clear link, say so plainly and briefly",
            "the feelings and unspoken questions the dream is working through beneath its imagery",
            "practical guidance for waking life and one simple, safe ritual",
            "one guiding question for the dreamer to carry through the day, followed by a closing blessing",
        ],
        "words": "about 900 words in total",
    },
}

LANGUAGE_NAMES = {
    "en": "English",
    "fr": (
        "French (natural and warm, addressing the dreamer as « vous », and in gender-neutral wording "
        "since the dreamer's gender is unknown)"
    ),
}

READING_SCHEMA = {
    "type": "object",
    "properties": {
        "card_headline": {
            "type": "string",
            "description": "A luminous, shareable one-line takeaway for the Dream Card, at most 12 words.",
        },
        "mood_tags": {
            "type": "array",
            "items": {"type": "string"},
            "description": "3 to 5 one- or two-word moods or themes, lowercase.",
        },
        "sections": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"heading": {"type": "string"}, "body": {"type": "string"}},
                "required": ["heading", "body"],
                "additionalProperties": False,
            },
        },
        "image_prompt": {
            "type": "string",
            "description": "In English: a short visual scene for an illustration of the dream, at most 25 words.",
        },
    },
    "required": ["card_headline", "mood_tags", "sections", "image_prompt"],
    "additionalProperties": False,
}

# Models that accept server-side refusal fallbacks in "default" mode.
_FALLBACK_MODELS = {"claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"}
_FALLBACK_BETA = "server-side-fallback-2026-07-01"


@dataclass
class DreamInterpretation:
    interpretation: str
    mood_tags: list[str]
    card_headline: str
    image_prompt: str = ""


def format_sections(sections: Sequence[tuple[str, str]]) -> str:
    """Serialises a reading as '### Heading\\nBody' blocks the app renders as sections."""
    return "\n\n".join(f"### {heading.strip()}\n{body.strip()}" for heading, body in sections)


def _recent_dreams_context(recent_dreams: Sequence) -> str:
    lines = []
    for dream in recent_dreams:
        date = dream.created_at.strftime("%Y-%m-%d") if dream.created_at else "earlier"
        summary = dream.card_headline or (dream.raw_text or "")[:160]
        tags = f" (themes: {dream.mood_tags})" if dream.mood_tags else ""
        lines.append(f"- {date}: {summary}{tags}")
    return "\n".join(lines) if lines else "- none yet"


def _request_text(raw_text: str, depth: str, language: str, recent_dreams: Optional[Sequence]) -> str:
    spec = DEPTHS[depth]
    headings = spec["headings"].get(language, spec["headings"]["en"])
    outline = "\n".join(
        f'{i}. "{heading}" — {guide}' for i, (heading, guide) in enumerate(zip(headings, spec["guide"]), 1)
    )
    parts = [
        f"Write the reading in {LANGUAGE_NAMES.get(language, 'English')}: the headline, tags and "
        "every section. Keep image_prompt in English.",
        f"Give the reading exactly these sections, in this order, {spec['words']}:\n{outline}",
    ]
    if recent_dreams is not None:
        parts.append("The dreamer's recent dreams, newest first:\n" + _recent_dreams_context(recent_dreams))
    parts.append(f"The dream:\n<dream>\n{raw_text}\n</dream>")
    return "\n\n".join(parts)


def interpret_dream(
    raw_text: str,
    depth: str = "standard",
    recent_dreams: Optional[Sequence] = None,
    language: str = "en",
    model: Optional[str] = None,
) -> DreamInterpretation:
    depth = depth if depth in DEPTHS else "standard"
    model = model or settings.AI_MODEL_PAID

    if not settings.ANTHROPIC_API_KEY:
        if settings.APP_ENV == "production":
            # Real visitors must never receive the canned sample as their reading.
            logger.error("ANTHROPIC_API_KEY is not configured in production")
            raise ReadingUnavailable("not_configured")
        logger.warning("ANTHROPIC_API_KEY not set — returning sample reading")
        return _sample_reading(raw_text, depth, language)

    request = {
        "model": model,
        "max_tokens": 16000,
        "system": [{"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": _request_text(raw_text, depth, language, recent_dreams)}],
        "output_config": {
            "effort": settings.AI_EFFORT,
            "format": {"type": "json_schema", "schema": READING_SCHEMA},
        },
    }
    if model in _FALLBACK_MODELS:
        # If a safety classifier declines, the API retries on a fallback model.
        request.update(betas=[_FALLBACK_BETA], fallbacks="default")

    try:
        response = _get_client().beta.messages.create(**request)
    except anthropic.APIConnectionError as exc:
        logger.error("Could not reach the AI provider: %s", exc)
        raise ReadingUnavailable("unreachable") from exc
    except anthropic.RateLimitError as exc:
        logger.error("AI provider rate limit (request %s)", exc.request_id)
        raise ReadingUnavailable("rate_limited") from exc
    except anthropic.APIStatusError as exc:
        # 4xx here is a bug in our request; 5xx an outage. Either way, log it and fail softly.
        logger.error("AI provider error %s (request %s): %s", exc.status_code, exc.request_id, exc.message)
        raise ReadingUnavailable("api_error") from exc

    usage = response.usage
    # One line per reading: the raw numbers behind the plan margins.
    logger.info(
        "reading model=%s depth=%s lang=%s input_tokens=%s output_tokens=%s cache_read=%s",
        getattr(response, "model", model), depth, language, usage.input_tokens, usage.output_tokens,
        getattr(usage, "cache_read_input_tokens", 0),
    )

    if response.stop_reason == "refusal":
        category = getattr(response.stop_details, "category", None) if response.stop_details else None
        logger.warning("Reading declined (category=%s)", category)
        raise ReadingUnavailable("declined")
    if response.stop_reason == "max_tokens":
        logger.error("Reading hit max_tokens before finishing")
        raise ReadingUnavailable("truncated")

    text = next((block.text for block in response.content if block.type == "text"), "")
    data = json.loads(text)  # guaranteed valid by output_config.format
    return DreamInterpretation(
        interpretation=format_sections([(s["heading"], s["body"]) for s in data["sections"]]),
        mood_tags=[tag.strip().lower() for tag in data["mood_tags"] if tag.strip()][:5],
        card_headline=data["card_headline"].strip(),
        image_prompt=data["image_prompt"].strip(),
    )


# ---------------------------------------------------------------------------
# Sample reading — used only when no API key is configured (local development),
# so the app shows a realistic reading of the right shape and length.
# ---------------------------------------------------------------------------

_SAMPLE = {
    "en": {
        "headline": "The night has opened a door, and you are ready to step through.",
        "tags": ["transformation", "intuition", "courage", "renewal"],
        "sections": {
            "vision": (
                "You wrote: “{excerpt}”. Dreams like this arrive when the soul is turning a page. The scene you "
                "walked through is not random; it is a mirror held up to the season of your life, showing a part of "
                "you that is already changing before your waking mind has caught up.\n\nOn its surface the dream "
                "speaks of movement and discovery. Deeper still, it speaks of permission: permission to leave behind "
                "a shape you have outgrown, and to trust the person you are becoming."
            ),
            "symbols": (
                "The setting is your inner landscape. In the old dream-lore, the places we wander at night are "
                "rooms of the self, and their light tells us how we feel within them. Where the scene was open and "
                "bright, your spirit feels free; where it narrowed or darkened, something is asking to be looked at "
                "kindly rather than avoided.\n\nThe journey itself is one of the oldest symbols we carry. Jung saw it "
                "as the path of individuation, the long walk toward wholeness. That you kept moving, rather than "
                "freezing, suggests a quiet courage in you that is stronger than you give it credit for."
            ),
            "currents": (
                "Beneath the imagery runs a current of longing mixed with a little uncertainty. Part of you wants "
                "something new; another part is still holding the hand of what is familiar. Both are welcome. The "
                "dream does not ask you to choose in a hurry. It asks you to notice which of the two feels more "
                "alive when you imagine the year ahead."
            ),
            "threads": (
                "Looking across your recent nights, a thread of change keeps returning: doors, roads and open skies "
                "appear again and again. Your dreams are telling one story in several chapters, and this chapter is "
                "the moment the traveller realises the road has been leading somewhere all along."
            ),
            "guidance": (
                "In the days ahead, give yourself one small act of trust. Say yes to an invitation you would usually "
                "decline, or begin the thing you have been circling. Notice how your body feels when you choose "
                "from curiosity instead of fear, and let that feeling guide the next step."
            ),
            "ritual": (
                "Tonight, before sleep, place a glass of water by your bed and write one sentence about what you "
                "are ready to release. In the morning, drink the water slowly and read the sentence aloud. Let it be "
                "a simple promise to yourself, nothing more and nothing less.\n\nMay your nights be gentle and your "
                "mornings clear."
            ),
            "question": (
                "Carry this question with you today: what would you begin if you trusted that you were already "
                "ready?\n\nMay the moon keep watch over your path, and may you meet each threshold with an open heart."
            ),
            "message": (
                "This dream is a gentle nudge toward trust. Notice where you hold back out of habit rather than "
                "need, and offer yourself one small, brave step this week. Change is already moving in you; it only "
                "asks that you walk with it.\n\nMay your nights be gentle and your mornings clear."
            ),
        },
    },
    "fr": {
        "headline": "La nuit vous a ouvert une porte : il ne reste qu'à la franchir.",
        "tags": ["transformation", "intuition", "courage", "renouveau"],
        "sections": {
            "vision": (
                "Vous avez écrit : « {excerpt} ». Ce type de rêve survient quand l'âme tourne une page. Le décor "
                "que vous avez traversé n'a rien d'un hasard : c'est un miroir tendu vers cette saison de votre vie, "
                "qui montre une part de vous déjà en mouvement, avant même que votre esprit éveillé ne la "
                "rattrape.\n\nEn surface, le rêve parle de mouvement et de découverte. Plus profondément, il parle de "
                "permission : celle de quitter une forme devenue trop étroite, et de faire confiance à la personne "
                "que vous devenez."
            ),
            "symbols": (
                "Le décor est votre paysage intérieur. Dans la tradition des rêves, les lieux que nous parcourons la "
                "nuit sont des pièces de notre être, et leur lumière dit ce que nous y ressentons. Là où la scène "
                "était ouverte et claire, votre esprit se sent libre ; là où elle se resserrait ou s'assombrissait, "
                "quelque chose demande à être regardé avec douceur plutôt qu'évité.\n\nLe voyage lui-même est l'un "
                "des plus anciens symboles. Jung y voyait le chemin de l'individuation, la longue marche vers "
                "l'unité intérieure. Le fait que vous ayez continué d'avancer révèle un courage tranquille, plus "
                "fort que vous ne le pensez."
            ),
            "currents": (
                "Sous les images coule un courant de désir mêlé d'une légère incertitude. Une part de vous aspire à "
                "la nouveauté ; une autre tient encore la main de ce qui est familier. Les deux ont leur place. Le "
                "rêve ne vous demande pas de choisir dans l'urgence, mais de remarquer laquelle des deux vous semble "
                "la plus vivante lorsque vous imaginez l'année à venir."
            ),
            "threads": (
                "En regardant vos nuits récentes, un fil de changement revient sans cesse : portes, routes et ciels "
                "ouverts se répondent. Vos rêves racontent une même histoire en plusieurs chapitres, et celui-ci est "
                "le moment où le voyageur comprend que la route menait quelque part depuis le début."
            ),
            "guidance": (
                "Dans les jours qui viennent, offrez-vous un petit acte de confiance. Acceptez une invitation que "
                "vous auriez déclinée, ou commencez ce que vous repoussez depuis longtemps. Observez ce que ressent "
                "votre corps quand vous choisissez par curiosité plutôt que par peur, et laissez cette sensation "
                "guider le pas suivant."
            ),
            "ritual": (
                "Ce soir, avant de dormir, posez un verre d'eau près de votre lit et écrivez une phrase sur ce que "
                "vous souhaitez laisser partir. Au matin, buvez l'eau lentement et lisez la phrase à voix haute. "
                "Qu'elle soit une simple promesse envers vous-même.\n\nQue vos nuits soient douces et vos matins "
                "limpides."
            ),
            "question": (
                "Gardez cette question avec vous aujourd'hui : que commenceriez-vous si vous saviez que le "
                "moment est déjà venu ?\n\nQue la lune veille sur votre chemin, et puissiez-vous franchir chaque seuil le cœur "
                "ouvert."
            ),
            "message": (
                "Ce rêve est une douce invitation à la confiance. Remarquez où vous vous retenez par habitude plutôt "
                "que par nécessité, et offrez-vous cette semaine un petit pas courageux. Le changement est déjà en "
                "marche en vous ; il vous demande seulement de l'accompagner.\n\nQue vos nuits soient douces et vos "
                "matins limpides."
            ),
        },
    },
}

_SAMPLE_ORDER = {
    "standard": ["vision", "symbols", "message"],
    "deep": ["vision", "symbols", "currents", "guidance", "ritual"],
    "oracle": ["vision", "symbols", "threads", "currents", "guidance", "question"],
}


def _sample_reading(raw_text: str, depth: str, language: str) -> DreamInterpretation:
    sample = _SAMPLE.get(language, _SAMPLE["en"])
    headings = DEPTHS[depth]["headings"].get(language, DEPTHS[depth]["headings"]["en"])
    excerpt = raw_text.strip().replace("\n", " ")
    excerpt = excerpt if len(excerpt) <= 90 else excerpt[:87].rstrip() + "…"
    bodies = [sample["sections"][key].format(excerpt=excerpt) for key in _SAMPLE_ORDER[depth]]
    return DreamInterpretation(
        interpretation=format_sections(list(zip(headings, bodies))),
        mood_tags=list(sample["tags"]),
        card_headline=sample["headline"],
        image_prompt="a dreamer standing at a glowing doorway under a crescent moon, soft mist, starlit sky",
    )
