"""
English / French support for user-facing API text.

The app sends the user's language in the Accept-Language header; every
message a person might read (errors, plan copy, AI readings) is resolved
from it. Machine-facing messages (webhooks) stay in English.
"""

from typing import Optional

from fastapi import Header

SUPPORTED = ("en", "fr")
DEFAULT = "en"


def language_from_header(value: Optional[str]) -> str:
    """Best supported language from an Accept-Language value, honouring q-weights."""
    if not value:
        return DEFAULT
    candidates = []
    for position, part in enumerate(value.split(",")):
        tag, _, params = part.strip().partition(";")
        quality = 1.0
        if params.strip().startswith("q="):
            try:
                quality = float(params.strip()[2:])
            except ValueError:
                quality = 0.0
        primary = tag.strip().split("-")[0].lower()
        if primary in SUPPORTED and quality > 0:
            candidates.append((-quality, position, primary))
    return min(candidates)[2] if candidates else DEFAULT


def get_language(accept_language: Optional[str] = Header(default=None)) -> str:
    """FastAPI dependency: the request's language code ("en" or "fr")."""
    return language_from_header(accept_language)


MESSAGES: dict[str, dict[str, str]] = {
    "email_registered": {
        "en": "An account with this email already exists.",
        "fr": "Un compte existe déjà avec cette adresse e-mail.",
    },
    "invalid_credentials": {
        "en": "Incorrect email or password.",
        "fr": "Adresse e-mail ou mot de passe incorrect.",
    },
    "session_expired": {
        "en": "Your session has expired. Please log in again.",
        "fr": "Votre session a expiré. Veuillez vous reconnecter.",
    },
    "dream_not_found": {
        "en": "Dream not found.",
        "fr": "Rêve introuvable.",
    },
    "free_limit_reached": {
        "en": "You've used this week's free reading. Choose a plan for daily readings.",
        "fr": "Vous avez utilisé la lecture gratuite de la semaine. Choisissez une offre pour des lectures quotidiennes.",
    },
    "plan_limit_reached": {
        "en": "You've used today's {limit} {plan} readings. Upgrade for more, or come back tomorrow.",
        "fr": "Vous avez utilisé les {limit} lectures {plan} du jour. Passez à une offre supérieure ou revenez demain.",
    },
    "no_subscription": {
        "en": "No subscription record.",
        "fr": "Aucun abonnement trouvé.",
    },
    "unknown_product": {
        "en": "Unknown subscription product.",
        "fr": "Produit d'abonnement inconnu.",
    },
    "token_linked_elsewhere": {
        "en": "This Google Play subscription is linked to another DreamCast account.",
        "fr": "Cet abonnement Google Play est associé à un autre compte DreamCast.",
    },
    "subscription_expired": {
        "en": "This subscription has expired.",
        "fr": "Cet abonnement a expiré.",
    },
    "verification_unavailable": {
        "en": "Purchase verification is temporarily unavailable. Please try again shortly.",
        "fr": "La vérification de l'achat est momentanément indisponible. Veuillez réessayer dans quelques instants.",
    },
    "delete_failed": {
        "en": "Couldn't delete your data right now. Please try again.",
        "fr": "Impossible de supprimer vos données pour le moment. Veuillez réessayer.",
    },
}


def t(key: str, lang: str, **kwargs) -> str:
    """Translated message for `key`, falling back to English."""
    entry = MESSAGES[key]
    text = entry.get(lang) or entry[DEFAULT]
    return text.format(**kwargs) if kwargs else text
