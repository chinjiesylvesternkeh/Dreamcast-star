"""
Image generation service for the shareable "Dream Card".

Calls a configurable text-to-image provider (defaults to a Stability AI-style
REST endpoint; swap IMAGE_PROVIDER_URL / auth handling for Google Imagen,
DALL-E, etc. without touching callers). Falls back to a placeholder image URL
when no key is configured, so the app remains runnable in dev.
"""
import base64
import logging
import uuid

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from app.config import get_settings

settings = get_settings()
logger = logging.getLogger(__name__)

PLACEHOLDER_IMAGE = "https://placehold.co/768x1024/1a1a2e/eaeaea?text=Dream+Card"


@retry(stop=stop_after_attempt(2), wait=wait_exponential(multiplier=1, min=1, max=6))
def generate_dream_image(prompt_hint: str) -> str:
    """Returns a URL to the generated (or placeholder) image.

    In production, swap the body below for an upload to S3/GCS after
    generation, and return the CDN URL rather than a base64 blob.
    """
    if not settings.IMAGE_PROVIDER_API_KEY:
        logger.warning("IMAGE_PROVIDER_API_KEY not set — using placeholder image")
        return PLACEHOLDER_IMAGE

    style_prompt = (
        f"Dreamlike, surreal, soft cinematic lighting, ethereal atmosphere, "
        f"artistic digital painting depicting: {prompt_hint}"
    )

    try:
        with httpx.Client(timeout=30) as client:
            resp = client.post(
                settings.IMAGE_PROVIDER_URL,
                headers={
                    "Authorization": f"Bearer {settings.IMAGE_PROVIDER_API_KEY}",
                    "Accept": "application/json",
                },
                data={"prompt": style_prompt, "output_format": "png"},
            )
            resp.raise_for_status()
            data = resp.json()
            image_b64 = data.get("image") or data.get("artifacts", [{}])[0].get("base64")
            if not image_b64:
                raise ValueError("No image data in provider response")

            # TODO: upload `base64.b64decode(image_b64)` to your object storage
            # (S3 / GCS bucket) here and return the public/CDN URL instead.
            filename = f"{uuid.uuid4()}.png"
            logger.info("Generated dream image %s (upload-to-storage step is a TODO)", filename)
            return PLACEHOLDER_IMAGE  # replace once storage upload is wired in
    except Exception as exc:  # noqa: BLE001
        logger.error("Image generation failed, falling back to placeholder: %s", exc)
        return PLACEHOLDER_IMAGE
