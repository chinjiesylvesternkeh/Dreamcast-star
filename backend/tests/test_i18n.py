import pytest

from app.i18n import MESSAGES, language_from_header
from app.plans import PLANS
from app.services.ai_service import DEPTHS, SYSTEM_PROMPT

from tests.test_auth_and_dreams import signup_and_login

FR = {"Accept-Language": "fr-CM,fr;q=0.9,en;q=0.8"}


@pytest.mark.parametrize(
    "header, expected",
    [
        (None, "en"),
        ("", "en"),
        ("fr", "fr"),
        ("fr-FR", "fr"),
        ("en-US,en;q=0.9", "en"),
        ("de-DE,fr;q=0.7,en;q=0.5", "fr"),
        ("en;q=0.4,fr;q=0.8", "fr"),
        ("es, it", "en"),
        ("fr;q=0", "en"),
    ],
)
def test_language_negotiation(header, expected):
    assert language_from_header(header) == expected


def test_every_message_and_plan_has_french():
    for key, entry in MESSAGES.items():
        assert entry.get("fr"), key
    for plan in PLANS.values():
        assert plan.copy["fr"].features and len(plan.copy["fr"].features) == len(plan.copy["en"].features)


def test_reading_sections_exist_in_every_language():
    for spec in DEPTHS.values():
        for language in ("en", "fr"):
            assert len(spec["headings"][language]) == len(spec["guide"])
    assert "white witch" in SYSTEM_PROMPT


def test_plans_are_served_in_french(client):
    plans = client.get("/api/v1/subscriptions/plans", headers=FR).json()
    mystic = next(p for p in plans if p["id"] == "mystic")
    assert mystic["name"] == "Mystic"  # brand names are not translated
    assert mystic["highlight"] == "Le plus populaire"
    assert mystic["recommended"] is True
    assert mystic["features"][0].startswith("Jusqu'à 5 lectures")


def test_reading_follows_request_language(client):
    token = signup_and_login(client)
    resp = client.post(
        "/api/v1/dreams",
        json={"raw_text": "Je volais au-dessus d'une ville de verre"},
        headers={"Authorization": f"Bearer {token}", **FR},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["card_headline"].startswith("La nuit vous a ouvert une porte")
    assert body["interpretation"].startswith("### La vision\nVous avez écrit : « Je volais")


def test_errors_are_translated(client):
    token = signup_and_login(client)
    headers = {"Authorization": f"Bearer {token}", **FR}
    client.post("/api/v1/dreams", json={"raw_text": "Premier rêve"}, headers=headers)

    limited = client.post("/api/v1/dreams", json={"raw_text": "Deuxième rêve"}, headers=headers)
    assert limited.status_code == 429
    assert limited.json()["detail"].startswith("Vous avez utilisé la lecture gratuite")

    login = client.post(
        "/api/v1/auth/login", json={"email": "dreamer@example.com", "password": "wrongpass"}, headers=FR
    )
    assert login.json()["detail"] == "Adresse e-mail ou mot de passe incorrect."
