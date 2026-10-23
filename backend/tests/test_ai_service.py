"""The AI call itself, with the Anthropic client replaced by a fake."""

import json
from types import SimpleNamespace

import anthropic
import httpx
import pytest

from app.config import get_settings
from app.services import ai_service

from tests.test_auth_and_dreams import signup_and_login

READING = {
    "card_headline": "The glass city remembers your name",
    "mood_tags": ["Wonder", " Freedom "],
    "sections": [
        {"heading": "The Vision", "body": "You flew above a city of glass."},
        {"heading": "The Symbols", "body": "Glass is clarity.\n\nFlight is freedom."},
        {"heading": "The Message", "body": "Trust what you see. Blessed be."},
    ],
    "image_prompt": "a glass city at night seen from above",
}


class FakeMessages:
    def __init__(self, response=None, error=None):
        self.response, self.error, self.calls = response, error, []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        return self.response


def _response(stop_reason="end_turn", payload=READING):
    return SimpleNamespace(
        stop_reason=stop_reason,
        stop_details=SimpleNamespace(category="cyber") if stop_reason == "refusal" else None,
        content=[SimpleNamespace(type="thinking"), SimpleNamespace(type="text", text=json.dumps(payload))],
    )


@pytest.fixture
def fake_ai(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "ANTHROPIC_API_KEY", "test-key")
    monkeypatch.setattr(settings, "AI_MODEL_NAME", "claude-opus-5-5")

    def install(**kwargs):
        messages = FakeMessages(**kwargs)
        monkeypatch.setattr(ai_service, "_get_client", lambda: SimpleNamespace(beta=SimpleNamespace(messages=messages)))
        return messages

    return install


def test_request_uses_persona_structure_and_fallbacks(fake_ai):
    messages = fake_ai(response=_response())

    ai_service.interpret_dream("I flew over a glass city", depth="deep", language="fr")

    call = messages.calls[0]
    assert call["model"] == "claude-opus-5-5"
    assert call["output_config"]["format"]["schema"] == ai_service.READING_SCHEMA
    assert call["output_config"]["effort"] == get_settings().AI_EFFORT
    assert call["fallbacks"] == "default" and call["betas"] == ["server-side-fallback-2026-07-01"]
    assert "white witch" in call["system"][0]["text"]
    user_text = call["messages"][0]["content"]
    assert '"Les courants cachés"' in user_text and "French" in user_text
    assert "<dream>\nI flew over a glass city\n</dream>" in user_text


def test_reading_is_returned_as_sections(fake_ai):
    fake_ai(response=_response())

    result = ai_service.interpret_dream("I flew over a glass city")

    assert result.interpretation == (
        "### The Vision\nYou flew above a city of glass.\n\n"
        "### The Symbols\nGlass is clarity.\n\nFlight is freedom.\n\n"
        "### The Message\nTrust what you see. Blessed be."
    )
    assert result.mood_tags == ["wonder", "freedom"]
    assert result.image_prompt == "a glass city at night seen from above"


def test_models_without_fallback_support_skip_the_beta(fake_ai, monkeypatch):
    monkeypatch.setattr(get_settings(), "AI_MODEL_NAME", "claude-sonnet-4-6")
    messages = fake_ai(response=_response())

    ai_service.interpret_dream("A dream")

    assert "fallbacks" not in messages.calls[0] and "betas" not in messages.calls[0]


@pytest.mark.parametrize("stop_reason", ["refusal", "max_tokens"])
def test_unfinished_readings_raise(fake_ai, stop_reason):
    fake_ai(response=_response(stop_reason=stop_reason))
    with pytest.raises(ai_service.ReadingUnavailable):
        ai_service.interpret_dream("A dream")


def test_provider_outage_is_a_friendly_error_and_not_counted(fake_ai, client):
    request = httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    fake_ai(error=anthropic.InternalServerError(
        "overloaded", response=httpx.Response(529, request=request), body=None
    ))
    token = signup_and_login(client)
    headers = {"Authorization": f"Bearer {token}"}

    resp = client.post("/api/v1/dreams", json={"raw_text": "A door in the sea"}, headers=headers)
    assert resp.status_code == 503
    assert resp.json()["detail"].startswith("The Oracle couldn't read this dream")
    # The failed attempt did not use up the free weekly reading.
    assert client.get("/api/v1/dreams", headers=headers).json() == []
