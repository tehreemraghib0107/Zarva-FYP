#!/usr/bin/env python3
"""
ZARVA AI Services — End-to-end training, inference, and FastAPI production engine.

Stages:
  1. Custom 9-class South Asian neckline classification (YOLO-World crop + MobileNetV3)
  2. YOLO-World jewelry detection + EfficientNet-B0 regional style classifier
  3. Skin tone + expert styling matrix → recommendation payload
  4. MongoDB Atlas chat persistence
  5. FastAPI POST /api/ai/recommend
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import random
import sys
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from PIL import Image
from pymongo import MongoClient
from pymongo.collection import Collection
from sklearn.cluster import KMeans
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms
from torchvision.models import (
    EfficientNet_B0_Weights,
    MobileNet_V3_Small_Weights,
)
from ultralytics import YOLO

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None  # type: ignore

try:
    from fastapi import FastAPI, File, Form, UploadFile
    from fastapi.middleware.cors import CORSMiddleware
    import uvicorn
except ImportError:
    FastAPI = None  # type: ignore

# ---------------------------------------------------------------------------
# Paths & constants
# ---------------------------------------------------------------------------

AI_ROOT = Path(__file__).resolve().parent
NECKLINES_ROOT = AI_ROOT / "Images" / "Necklines"
JEWELRY_STYLE_ROOT = AI_ROOT / "Images" / "Jewelry" / "Style"
SKIN_TONE_ROOT = AI_ROOT / "Images" / "skin tone classification data"
MODELS_DIR = AI_ROOT / "models"

NECKLINE_CLASSES = [
    "Angrakha Neck",
    "Boat Neck",
    "Collar Ban",
    "Key-Hole Neck",
    "Round and Scoop Neck",
    "Simple Collar",
    "Square Neck",
    "Sweetheart Neck",
    "V-Neck",
]

JEWELRY_STYLE_CLASSES = [
    "Arabian",
    "Kashmiri",
    "Mughal",
    "Pashtun",
    "Turkish",
]

SKIN_TONE_CLASSES = [
    "dark brown",
    "Olive",
    "White",
]

# Maps trained folder labels → Flutter chatbot filter labels
SKIN_TONE_DISPLAY_MAP: Dict[str, str] = {
    "dark brown": "Deep",
    "Olive": "Olive",
    "White": "Neutral",
}

YOLO_ITEM_CLASSES = ["necklace", "earring", "bracelet"]

YOLO_NECKLINE_VOCAB = ["neckline", "collarbone region"]

CHOKER_NECKLINES = frozenset({"Square Neck", "Round and Scoop Neck", "Boat Neck"})
PENDANT_NECKLINES = frozenset({"V-Neck", "Sweetheart Neck", "Key-Hole Neck"})
EARRINGS_ONLY_NECKLINES = frozenset({"Collar Ban", "Simple Collar", "Angrakha Neck"})

WARM_DRESS_COLORS = frozenset({"Gold", "Maroon", "Red", "Ivory"})
COOL_DRESS_COLORS = frozenset({"Blue", "Teal", "Green", "Pastel"})
WARM_SKIN_TONES = frozenset({"Olive", "Warm", "Deep"})

DEFAULT_NECKLINE_CLASS = "Round and Scoop Neck"
DEFAULT_NECKLINE_INDEX = NECKLINE_CLASSES.index(DEFAULT_NECKLINE_CLASS)

NECKLINE_MODEL_PATH = MODELS_DIR / "neckline_9class_model.pth"
JEWELRY_MODEL_PATH = MODELS_DIR / "jewelry_efficientnet_b0.pth"
SKIN_TONE_MODEL_PATH = MODELS_DIR / "skin_tone_mobilenetv3.pth"
JEWELRY_CACHE_PATH = MODELS_DIR / "jewelry_yolo_crops.json"
TRAINING_CONFIG_PATH = MODELS_DIR / "training_config.json"

BATCH_SIZE = 32
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("zarva.ai")


def _load_env() -> None:
    """Load MONGO_URI from ai_services/.env or backend/.env if present."""
    if load_dotenv is None:
        return
    for candidate in (AI_ROOT / ".env", AI_ROOT.parent / "backend" / ".env"):
        if candidate.is_file():
            load_dotenv(candidate)
            logger.info("Loaded environment from %s", candidate)
            break


# ---------------------------------------------------------------------------
# OpenCV neck-region crop heuristic
# ---------------------------------------------------------------------------


# crop_neck_region function removed to prioritize dynamic YOLO-World bounding-box strategy.


def bgr_to_rgb_tensor(bgr: np.ndarray, transform: transforms.Compose) -> torch.Tensor:
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    pil = Image.fromarray(rgb)
    return transform(pil)


PALETTE_RGB_ANCHORS: Dict[str, Tuple[int, int, int]] = {
    "Red": (180, 40, 50),
    "Blue": (45, 70, 160),
    "Teal": (35, 130, 125),
    "Pastel": (210, 190, 220),
    "Gold": (200, 170, 80),
    "Green": (50, 120, 70),
    "Maroon": (100, 25, 40),
    "Ivory": (235, 225, 205),
}

MANUAL_NECKLINE_MAP: Dict[str, str] = {
    "round / scoop": "Round and Scoop Neck",
    "round": "Round and Scoop Neck",
    "scoop": "Round and Scoop Neck",
    "boat neck": "Boat Neck",
    "v-neck": "V-Neck",
    "v neck": "V-Neck",
    "key-hole": "Key-Hole Neck",
    "key hole": "Key-Hole Neck",
    "sweetheart": "Sweetheart Neck",
    "collar ban": "Collar Ban",
    "collar / ban": "Collar Ban",
    "collar/ban": "Collar Ban",
    "simple collar": "Simple Collar",
    "square neck": "Square Neck",
    "angrakha": "Angrakha Neck",
}


def _rgb_to_palette_name(rgb: Tuple[int, int, int]) -> str:
    best_name = "Gold"
    best_dist = float("inf")
    for name, anchor in PALETTE_RGB_ANCHORS.items():
        dist = sum((rgb[i] - anchor[i]) ** 2 for i in range(3))
        if dist < best_dist:
            best_dist = dist
            best_name = name
    return best_name


def _is_gold_accent_rgb(rgb: Tuple[int, int, int]) -> bool:
    """Detect mustard/gold embroidery pixels in multi-tone South Asian prints."""
    r, g, b = rgb
    return r > 150 and g > 110 and b < 120 and (r - b) > 40


def _is_skin_tone_bgr(bgr: Tuple[int, int, int]) -> bool:
    """
    Return True when a BGR pixel falls inside human skin / lip colour ranges
    in both HSV and YCrCb colour spaces.  Used to strip flesh-tone clusters
    (body, neck, face edges) from the K-Means garment-colour pool.
    """
    b, g, r = bgr
    # --- HSV gate (OpenCV uses H∈[0,179], S,V∈[0,255]) ---
    hsv = cv2.cvtColor(np.uint8([[[b, g, r]]]), cv2.COLOR_BGR2HSV)[0, 0]
    h, s, v = int(hsv[0]), int(hsv[1]), int(hsv[2])
    hsv_skin = (0 <= h <= 25) and (s >= 30) and (v >= 60)

    # --- YCrCb gate ---
    ycrcb = cv2.cvtColor(np.uint8([[[b, g, r]]]), cv2.COLOR_BGR2YCrCb)[0, 0]
    cr, cb = int(ycrcb[1]), int(ycrcb[2])
    ycrcb_skin = (133 <= cr <= 173) and (77 <= cb <= 127)

    return hsv_skin and ycrcb_skin


def extract_dress_color_profile(bgr: np.ndarray) -> Tuple[str, bool, str]:
    """
    K-Means on YOLO neck crop — returns (palette_name, has_warm_accents, display_label).

    Optimised for heavily embroidered South Asian bridal garments:
      • 5 clusters isolate metallic / embroidery sparkle into their own centroids.
      • Skin-tone clusters (body, neck, face edges) are dropped before selection.
      • The background fabric is chosen by lowest spatial variance (most spatially
        continuous cluster), not by raw pixel count, so dense surface embroidery
        cannot hijack the dominant-colour result.
    """
    if bgr is None or bgr.size == 0:
        return "Gold", True, "Gold"
    small = cv2.resize(bgr, (128, 128))
    pixels = small.reshape(-1, 3).astype(np.float32)
    if len(pixels) < 4:
        return "Gold", True, "Gold"

    # ── 1. INCREASE CLUSTER RESOLUTION: 5 clusters ────────────────────────
    k = 5
    _compactness, labels, centers = cv2.kmeans(
        pixels,
        k,
        None,
        (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 24, 1.0),
        8,
        cv2.KMEANS_PP_CENTERS,
    )
    labels_flat = labels.flatten()

    # ── 2. ANTI-SKIN MASK: drop any centroid that matches skin / lip tones ─
    valid_indices: List[int] = []
    valid_rgbs: List[Tuple[int, int, int]] = []
    for i in range(k):
        bgr_c = centers[i]
        rgb = (int(bgr_c[2]), int(bgr_c[1]), int(bgr_c[0]))
        if not _is_skin_tone_bgr((int(bgr_c[0]), int(bgr_c[1]), int(bgr_c[2]))):
            valid_indices.append(i)
            valid_rgbs.append(rgb)

    # Fallback: if every cluster was flagged as skin (rare edge-case), accept all
    if not valid_indices:
        valid_indices = list(range(k))
        valid_rgbs = [
            (int(centers[i][2]), int(centers[i][1]), int(centers[i][0]))
            for i in range(k)
        ]

    # ── 3. DOMINANT BACKGROUND FABRIC via spatial variance ─────────────────
    # Build a 2-D coordinate grid matching the 128×128 resized image.
    h, w = small.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]                       # shape (h, w)
    pixel_coords = np.stack([xx.ravel(), yy.ravel()], axis=1)  # (N, 2)

    # For each surviving cluster compute the sum of x- and y-variance.
    # Low variance  → pixels form a compact, spatially continuous region
    #                 (i.e. the uninterrupted background fabric matrix).
    # High variance → pixels are scattered across the image (dense
    #                 embroidery sparkles, metallic reflections, etc.).
    spatial_variances: List[float] = []
    for idx in valid_indices:
        mask = labels_flat == idx
        if mask.sum() < 2:
            spatial_variances.append(float("inf"))
        else:
            coords = pixel_coords[mask]
            spatial_variances.append(float(np.var(coords, axis=0).sum()))

    # Pick the valid cluster with the *lowest* spatial variance
    best_valid_pos = int(np.argmin(spatial_variances))
    best_idx = valid_indices[best_valid_pos]
    dominant_rgb = valid_rgbs[best_valid_pos]
    dominant = _rgb_to_palette_name(dominant_rgb)

    # ── 4. HSV BOUNDARY GATES: override Euclidean anchor matching ───────────
    # Convert the dominant background cluster centroid to HSV to apply
    # saturation/value-based classification rules that prevent embroidery
    # threads and lighting artifacts from hijacking the base textile color.
    hsv = cv2.cvtColor(np.uint8([[[dominant_rgb[2], dominant_rgb[1], dominant_rgb[0]]]]), cv2.COLOR_BGR2HSV)[0, 0]
    h_val, s_val, v_val = int(hsv[0]), int(hsv[1]), int(hsv[2])

    # Gate A: High saturation (S > 110) with blue-green hue profile
    # Prevents golden/bronze embroidery threads from being classified as warm neutrals.
    # OpenCV H range: Green ≈ 60-90, Teal ≈ 85-100, Blue-green overlap ≈ 80-110.
    if s_val > 110 and 60 <= h_val <= 110:
        # Distinguish Teal (higher hue, bluer) from Green (lower hue, yellower green)
        dominant = "Teal" if h_val >= 85 else "Green"

    # Gate B: Low saturation (S < 45) with intermediate-to-high value (V > 95)
    # Prevents amber shadows or dim indoor lighting from misclassifying neutral
    # beige/tan outfits as 'Maroon'. Route directly to Ivory (warm neutral light).
    elif s_val < 45 and v_val > 95:
        dominant = "Ivory"

    # Accent detection: check every *other* valid cluster for warm / gold tones
    accent_rgbs = [rgb for j, rgb in enumerate(valid_rgbs) if valid_indices[j] != best_idx]
    has_gold_accent = any(_is_gold_accent_rgb(rgb) for rgb in accent_rgbs)
    accent_names = [_rgb_to_palette_name(rgb) for rgb in accent_rgbs]
    has_warm_accent = has_gold_accent or any(n in WARM_DRESS_COLORS for n in accent_names)

    if dominant in ("Teal", "Blue", "Green") and has_gold_accent:
        display = f"{dominant} with Gold"
        has_warm_accent = True
    elif dominant in WARM_DRESS_COLORS:
        display = dominant
        has_warm_accent = True
    else:
        display = dominant

    return dominant, has_warm_accent, display


def extract_dominant_dress_color(bgr: np.ndarray) -> str:
    """Backward-compatible wrapper — returns human-readable dress colour label."""
    _dominant, _warm, display = extract_dress_color_profile(bgr)
    return display


def normalize_neckline_label(neckline: str) -> str:
    """Map any prediction/manual string to one of the 9 canonical folder class names."""
    cleaned = neckline.strip()
    if not cleaned:
        return DEFAULT_NECKLINE_CLASS
    resolved = resolve_manual_neckline(cleaned)
    if resolved is not None:
        return resolved
    for label in NECKLINE_CLASSES:
        if label.lower() == cleaned.lower():
            return label
    return DEFAULT_NECKLINE_CLASS


def is_warm_metal_palette(skin_tone: str, dress_color: str, dress_has_warm_accents: bool = False) -> bool:
    tone = skin_tone.strip()
    color_lower = dress_color.lower()
    if tone in WARM_SKIN_TONES:
        return True
    if dress_has_warm_accents:
        return True
    if any(w in color_lower for w in ("gold", "maroon", "mustard", "warm")):
        return True
    for warm in WARM_DRESS_COLORS:
        if warm.lower() in color_lower:
            return True
    return False


def build_tri_factor_recommendation(
    neckline: str,
    dress_color: str,
    skin_tone: str,
    user_query: str = "",
    dress_has_warm_accents: bool = False,
    color_auto_detected: bool = False,
    skin_tone_auto_detected: bool = False,
) -> Dict[str, str]:
    """
    Tri-Factor Fusion Matrix: neckline geometry × dress colour × skin tone → jewelry advice.
    """
    neckline_tag = normalize_neckline_label(neckline)
    skin_tone = skin_tone.strip() or "Neutral"
    dress_color = dress_color.strip() or "Gold"

    if is_warm_metal_palette(skin_tone, dress_color, dress_has_warm_accents):
        metal_type = "Antique Gold"
        heritage_style = (
            "Mughal Heritage Style Jewelry (combining classic subcontinental bridal geometry "
            "and traditional Kundan elements)"
        )
    else:
        metal_type = "Silver / White Gold / Diamond"
        heritage_style = "Contemporary Classic Heritage"

    if neckline_tag in CHOKER_NECKLINES:
        jewelry_type = f"a stunning {metal_type} Choker Necklace"
        jewelry_tag = f"{metal_type} Choker Necklace"
        why_this_works = (
            f"These wide open horizontal silhouettes leave a gorgeous negative space across the collarbones. "
            f"A high-sitting choker in {metal_type} perfectly frames your bare skin without dipping awkwardly below the fabric line."
        )
    elif neckline_tag in PENDANT_NECKLINES:
        jewelry_type = f"a refined {metal_type} Locket / Pendant Necklace"
        jewelry_tag = f"{metal_type} Locket / Pendant Necklace"
        why_this_works = (
            "These necklines plunge downward vertically, creating an elongated triangular chest space. "
            "A dangling pendant mimics this linear symmetry perfectly, creating a highly balanced, elongated profile."
        )
    else:
        jewelry_type = f"bold {metal_type} Statement Earrings Only (Omit the necklace)"
        jewelry_tag = f"{metal_type} Statement Earrings Only"
        why_this_works = (
            "High collars, band overlaps, and heavy embroidery structures crowd the upper throat. "
            "Adding a necklace introduces unnecessary visual friction. Omitting it completely and scaling up "
            "your face-framing earrings creates an elegant, intentional look."
        )

    if color_auto_detected:
        color_phrase = f"detected {dress_color} garment tones from the neckline crop"
    else:
        color_phrase = f"{dress_color} outfit"
    if skin_tone_auto_detected:
        tone_phrase = f"auto-detected {skin_tone} skin tone"
    else:
        tone_phrase = f"{skin_tone} skin tone"

    styling_insight = (
        f"For your {color_phrase} on {tone_phrase} with a {neckline_tag} neckline, "
        f"we recommend {jewelry_type} in our {heritage_style}."
    )
    if user_query.strip():
        styling_insight += f" You asked: \"{user_query.strip()}\" — this pairing respects that brief."

    if neckline_tag in CHOKER_NECKLINES:
        why_this_works = (
            "This pairing establishes geometric equilibrium — horizontal necklines present an open area "
            "that a close-fitting choker fills beautifully, drawing focus upward toward the face."
        )
    elif neckline_tag in PENDANT_NECKLINES:
        why_this_works = (
            "This pairing establishes linear harmony — plunging vertical silhouettes are complemented perfectly "
            "by the dangling weight of a pendant, elongating the upper frame elegantly."
        )
    else:
        why_this_works = (
            "This pairing prevents visual overcrowding — structured collars and busy asymmetric layers look most elegant "
            "when neck chains are completely omitted in favor of dominant, face-framing earrings."
        )

    return {
        "neckline_tag": neckline_tag,
        "jewelry_tag": jewelry_tag,
        "metal_type": metal_type,
        "heritage_style": heritage_style,
        "styling_insight": styling_insight,
        "reply": styling_insight,
        "recommendation": styling_insight,
        "text": styling_insight,
        "whyThisWorks": why_this_works,
        "why_this_works": why_this_works,
    }


def resolve_manual_neckline(manual: str) -> Optional[str]:
    key = manual.strip().lower()
    if not key:
        return None
    if key in MANUAL_NECKLINE_MAP:
        return MANUAL_NECKLINE_MAP[key]
    for label in NECKLINE_CLASSES:
        if label.lower() == key:
            return label
    return None


def fashion_text_reply(user_query: str) -> Dict[str, str]:
    """
    Hardcoded Absolute Context Routing Engine for ZARVA Chatbot.
    Uses substring evaluation gates to completely prevent text matching failures.
    """
    # Clean up input string fully against trailing layout spaces or punctuation
    q = user_query.strip().lower().replace("?", "").replace(".", "").replace("!", "")
    
    # ── 1. GLOBAL GREETING GATE ─────────────────────────────────────────────
    greeting_keywords = ["hi", "hello", "hey", "salam", "aoa", "assalam", "hi zarbot", "hello zarva"]
    if any(g == q or q.startswith(g) for g in greeting_keywords) or q in ["hi", "hello", "hey"]:
        msg = "Hi! Welcome to ZarBot. How can I help you today?"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": msg,
            "whyThisWorks": "",
            "why_this_works": "",
            "neckline_tag": "",
            "jewelry_tag": ""
        }

    # ── 2. EXPLICIT VISION FUNNEL GATES (Forces image upload for Pakistani events) ──
    vision_keywords = [
        "want jewelry suggestion", "suggest jewelry", "wedding", "eid",
        "pakistani wedding", "party", "function", "mehndi", "baraat", "walima",
        "shadi", "festive", "occasion", "event", "ceremony", "dholki", "mayoun",
        "nikah", "engagement", "aqeeqah", "milad", "dinner", "reception",
        "heavy look", "bridals", "cousin shadi", "brother shadi", "sister shadi",
        "what should i wear"
    ]
    if any(w in q for w in vision_keywords):
        msg = "Okay! I will gladly suggest the perfect jewelry for your festive event. Please upload a clear image of your dress or outfit so I can mathematically analyze its neckline geometry, color space profiles, and skin tone variations to give you a highly customized, heavy jewelry recommendation from our collection!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "Vision funnel activated — awaiting outfit image for full tri-factor fusion analysis.",
            "whyThisWorks": "",
            "why_this_works": "",
            "neckline_tag": "",
            "jewelry_tag": "",
        }

    # ── 3. NATIVE PAKISTANI CUSTOMER SHOPPING QUERIES ───────────────────────
    if any(w in q for w in ["casual lawn", "simple suite", "cotton kurti", "eid lawn", "printed suite"]):
        msg = "For printed South Asian lawn suits or light Eid cotton kurtis, adding a heavy bridal choker creates a severe clash in fabric weight. We highly recommend matching these casual silhouettes with bold statement earrings alone to frame the face beautifully while keeping the neckline completely clean. Upload your suit photo to check its color profile!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "Light casual fabrics demand earring-only focus to preserve visual balance.",
            "whyThisWorks": "This pairing prevents visual overcrowding — structured collars and busy asymmetric layers look most elegant when neck chains are completely omitted in favor of dominant, face-framing earrings.",
            "why_this_works": "This pairing prevents visual overcrowding — structured collars and busy asymmetric layers look most elegant when neck chains are completely omitted in favor of dominant, face-framing earrings.",
            "neckline_tag": "",
            "jewelry_tag": "Statement Earrings Only",
        }

    if any(w in q for w in ["kaam hua wa hai", "heavy embroidery", "zardozi", "tilla work", "dabka", "gotta kinari"]):
        msg = "Rich subcontinental tilla, dabka, and zardozi mirror embroidery heavily crowds the throat region. Adding a dense necklace introduces unnecessary visual clutter. We recommend dropping the necklace entirely and scaling up your face-framing earrings into bold Mughal or Pashtun traditional statements. Upload a photo of the chest embroidery so our K-Means matrix can find the base fabric tone!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "Dense mirror-work embroidery mandates earring-only styling to avoid visual friction.",
            "whyThisWorks": "This pairing prevents visual overcrowding — structured collars and busy asymmetric layers look most elegant when neck chains are completely omitted in favor of dominant, face-framing earrings.",
            "why_this_works": "This pairing prevents visual overcrowding — structured collars and busy asymmetric layers look most elegant when neck chains are completely omitted in favor of dominant, face-framing earrings.",
            "neckline_tag": "",
            "jewelry_tag": "Statement Earrings Only",
        }

    if any(w in q for w in ["dupatta setting", "heavy dupatta", "dupatta on head", "bridal drape"]):
        msg = "When setting a heavy embroidered dupatta over your head or draped across one shoulder, your upper chest layout changes visually. A high-sitting Mughal Antique Gold Choker balances the scale of a heavy bridal drape perfectly without getting caught in the fabric folds. To ensure your neckline width supports a choker framework, please upload your draped outfit photo!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "Heavy draped dupattas require a high-sitting choker to maintain proportional balance.",
            "whyThisWorks": "This pairing establishes geometric equilibrium — horizontal necklines present an open area that a close-fitting choker fills beautifully, drawing focus upward toward the face.",
            "why_this_works": "This pairing establishes geometric equilibrium — horizontal necklines present an open area that a close-fitting choker fills beautifully, drawing focus upward toward the face.",
            "neckline_tag": "Round and Scoop Neck",
            "jewelry_tag": "Antique Gold Choker Necklace",
        }

    # ── 4. INTERNATIONAL & REGIONAL CULTURE GATES ───────────────────────────
    if any(w in q for w in ["western", "gown", "maxi", "cocktail dress", "gala", "prom", "skirt", "frock"]):
        msg = "For Western evening gowns and open-neck gala maxis, a sleek, structured choker layout acts as a stunning fusion centerpiece. Since our collection features rich, high-density traditional craftsmanship, pairing it with an open-shoulder Western cut creates a striking modern-ethnic look. Upload your dress photo to lock down the layout!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "Fusion Western silhouettes pair best with structured chokers for contrast.",
            "whyThisWorks": "This pairing establishes geometric equilibrium — horizontal necklines present an open area that a close-fitting choker fills beautifully, drawing focus upward toward the face.",
            "why_this_works": "This pairing establishes geometric equilibrium — horizontal necklines present an open area that a close-fitting choker fills beautifully, drawing focus upward toward the face.",
            "neckline_tag": "Square Neck",
            "jewelry_tag": "Mughal Antique Gold Choker",
        }

    if any(w in q for w in ["abaya", "kaftan", "caftan", "dubai style", "middle eastern", "hijab"]):
        if any(kw in q for kw in ["abaya and hijab", "only my hands are visible", "hijab and abaya", "hands visible", "suggest a bracelet"]):
            msg = "When wearing a traditional full-coverage Hijab and Abaya where only your hands are visible, necklaces and earrings are naturally occluded by the fabric drape. Therefore, the wrist becomes the singular, high-impact focal point for jewelry styling. We highly recommend pairing your outfit with a structured, high-density Arabian Metallic Statement Bracelet or stacked cuffs from our collection to elegantly frame the hand. Please upload a photo of your Abaya sleeve area so we can analyze the base fabric color!"
            return {
                "reply": msg,
                "recommendation": msg,
                "text": msg,
                "styling_insight": "For full-coverage modest silhouettes, focus all styling scale on heavy wrist bracelets and stacked cuffs to maximize visibility.",
                "whyThisWorks": "Wrist frames remain uninterrupted when high textile drapes occlude upper facial parameters.",
                "why_this_works": "Wrist frames remain uninterrupted when high textile drapes occlude upper facial parameters.",
                "neckline_tag": "Collar Ban",
                "jewelry_tag": "Arabian Metallic Statement Bracelet / Cuff",
            }
        msg = "Middle Eastern flowing kaftans and formal high-neck abayas look spectacular when balanced with prominent face-framing earrings or structural wrist-wear like metallic statement cuffs instead of throat chains. Let our vision engine compute the fabric matrix—upload your portrait now!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "High-coverage Middle Eastern silhouettes redirect focal weight to earrings and wrist cuffs.",
            "whyThisWorks": "This pairing prevents visual overcrowding — structured collars look most elegant when neck chains are completely omitted in favor of dominant wrist layouts.",
            "why_this_works": "This pairing prevents visual overcrowding — structured collars look most elegant when neck chains are completely omitted in favor of dominant wrist layouts.",
            "neckline_tag": "Collar Ban",
            "jewelry_tag": "Statement Earrings Only",
        }

    if any(w in q for w in ["kashmiri", "pashmina", "phiran", "velvet kurti", "filigree"]):
        msg = "Traditional high-neck Kashmiri phirans and rich winter velvet kurtis carry beautiful neckline embroidery layouts. Adding a necklace disrupts this craftsmanship. We recommend focusing purely on delicate Kashmiri filigree jhumkas to balance the silhouette. Upload your image to begin!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "Kashmiri neckline embroidery demands earring-only focus to preserve artisanal integrity.",
            "whyThisWorks": "This pairing prevents visual overcrowding — structured collars look most elegant when neck chains are completely omitted in favor of dominant, face-framing earrings.",
            "why_this_works": "This pairing prevents visual overcrowding — structured collars look most elegant when neck chains are completely omitted in favor of dominant, face-framing earrings.",
            "neckline_tag": "Simple Collar",
            "jewelry_tag": "Kashmiri Delicate Silver Filigree Jhumkas",
        }

    if any(w in q for w in ["pashtun", "afghan", "frock suit", "tribal", "kuchi"]):
        msg = "Vibrant Pashtun tribal frocks and mirror-work borders pair naturally with oxidized antique metals or gemstone settings. Please upload your dress image so our background K-Means analyzer can cleanly separate your continuous fabric color blocks from your intricate multi-tone tribal thread borders!"
        return {
            "reply": msg,
            "recommendation": msg,
            "text": msg,
            "styling_insight": "Pashtun tribal textiles require K-Means color de-noising before choker vs. earring routing.",
            "whyThisWorks": "This pairing establishes geometric equilibrium — open layouts present an area that a tribal choker fills beautifully, drawing focus upward toward the face.",
            "why_this_works": "This pairing establishes geometric equilibrium — open layouts present an area that a tribal choker fills beautifully, drawing focus upward toward the face.",
            "neckline_tag": "Round and Scoop Neck",
            "jewelry_tag": "Pashtun Oxidized Tribal Gemstone Choker",
        }

    # ── 5. PRESERVE EXISTING NECKLINE-CLASS KEYWORD FALLBACK ─────────────────
    for label in NECKLINE_CLASSES:
        if label.lower() in q:
            fused = build_tri_factor_recommendation(neckline=label, dress_color="Gold", skin_tone="Neutral")
            return {
                "reply": fused["reply"],
                "recommendation": fused["recommendation"],
                "text": fused["text"],
                "styling_insight": fused["styling_insight"],
                "whyThisWorks": "Dynamic geometric baseline matrix applied.",
                "why_this_works": "Dynamic geometric baseline matrix applied.",
                "neckline_tag": fused["neckline_tag"],
                "jewelry_tag": fused["jewelry_tag"],
            }

    # ── 6. GLOBAL FALLBACK GATE ──────────────────────────────────────────────
    msg = "I can craft a highly precise, multi-factor jewelry recommendation for you. Please attach an outfit photo, or specify your style parameters (e.g., Western gown, Pakistani wedding, Abaya drape, Kashmiri Phiran) so I can guide your styling profile!"
    return {
        "reply": msg,
        "recommendation": msg,
        "text": msg,
        "styling_insight": "Until an outfit image is supplied, choose one strong piece and avoid competing accents.",
        "whyThisWorks": "This pairing follows ZARVA styling parameters — input custom text identifiers or supply an image canvas above.",
        "why_this_works": "This pairing follows ZARVA styling parameters — input custom text identifiers or supply an image canvas above.",
        "neckline_tag": "",
        "jewelry_tag": ""
    }


# ---------------------------------------------------------------------------
# JSON dataset utilities
# ---------------------------------------------------------------------------


# JSON dataset utilities removed to prioritize direct Custom South Asian dataset folder training.


def neckline_class_to_idx() -> Dict[str, int]:
    """Canonical index map — folder order must match NECKLINE_CLASSES exactly."""
    return {name: idx for idx, name in enumerate(NECKLINE_CLASSES)}


def validate_neckline_classes(classes: List[str]) -> None:
    if classes != NECKLINE_CLASSES:
        raise ValueError(
            f"Neckline class order mismatch.\n"
            f"  Expected: {NECKLINE_CLASSES}\n"
            f"  Got:      {classes}"
        )


def save_neckline_checkpoint(model: nn.Module, path: Path = NECKLINE_MODEL_PATH) -> None:
    """Persist 9-class MobileNetV3 weights; overwrites any previous checkpoint."""
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    if path.is_file():
        logger.info("Overwriting previous neckline checkpoint at %s", path)
    torch.save(
        {
            "model_state": model.state_dict(),
            "classes": NECKLINE_CLASSES,
            "class_to_idx": neckline_class_to_idx(),
            "arch": "mobilenet_v3_small",
            "num_classes": len(NECKLINE_CLASSES),
        },
        path,
    )
    logger.info("Saved neckline checkpoint → %s (%d classes)", path, len(NECKLINE_CLASSES))


def load_neckline_folder_samples(
    root: Path,
    allowed_labels: Optional[List[str]] = None,
) -> List[Dict[str, str]]:
    allowed_labels = allowed_labels or NECKLINE_CLASSES
    class_to_idx = neckline_class_to_idx()
    image_exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".jfif"}
    samples: List[Dict[str, str]] = []
    for label in allowed_labels:
        if label not in class_to_idx:
            logger.warning("Skipping unknown neckline label: %s", label)
            continue
        folder = root / label
        if not folder.is_dir():
            logger.warning("Missing neckline folder: %s", folder)
            continue
        for image_path in sorted(folder.iterdir()):
            if image_path.suffix.lower() not in image_exts:
                continue
            samples.append(
                {
                    "image_path": str(image_path),
                    "neckline_label": label,
                    "class_index": class_to_idx[label],
                }
            )
    return samples


def split_dataset_samples(
    samples: List[Dict[str, str]],
    train_ratio: float = 0.8,
    val_ratio: float = 0.1,
    seed: int = 42,
) -> Tuple[List[Dict[str, str]], List[Dict[str, str]], List[Dict[str, str]]]:
    shuffled = list(samples)
    random.Random(seed).shuffle(shuffled)
    total = len(shuffled)
    train_end = int(total * train_ratio)
    val_end = train_end + int(total * val_ratio)
    return shuffled[:train_end], shuffled[train_end:val_end], shuffled[val_end:]


def central_square_anchor_crop(bgr: np.ndarray) -> np.ndarray:
    h, w = bgr.shape[:2]
    side = min(h, w)
    if side <= 0:
        return bgr
    x0 = max(0, (w - side) // 2)
    y0 = max(0, (h - side) // 2)
    return bgr[y0 : y0 + side, x0 : x0 + side]


def extract_skin_tone_crop(bgr: np.ndarray) -> np.ndarray:
    """Upper-centre face/chest band for skin-tone classification on full-length portraits."""
    if bgr is None or bgr.size == 0:
        raise ValueError("Empty image passed to extract_skin_tone_crop")
    h, w = bgr.shape[:2]
    y1, y2 = 0, max(1, int(h * 0.38))
    x1 = max(0, int(w * 0.22))
    x2 = min(w, int(w * 0.78))
    crop = bgr[y1:y2, x1:x2]
    if crop.size == 0:
        return central_square_anchor_crop(bgr)
    return crop


def crop_neckline_bbox(bgr: np.ndarray, yolo_model: YOLO) -> np.ndarray:
    if bgr is None or bgr.size == 0:
        raise ValueError("Empty image passed to crop_neckline_bbox")
    # Target neckline and collarbone region explicitly
    yolo_model.set_classes(YOLO_NECKLINE_VOCAB)
    results = yolo_model.predict(source=bgr, verbose=False, conf=0.15)
    if results:
        result = results[0]
        if getattr(result, "boxes", None) is not None and len(result.boxes) > 0:
            best_conf = -1.0
            best_box = None
            for box in result.boxes:
                conf = float(box.conf[0].cpu().numpy())
                if conf > best_conf:
                    best_conf = conf
                    best_box = box
            if best_box is not None:
                xyxy = best_box.xyxy[0].cpu().numpy().astype(int)
                x1, y1, x2, y2 = xyxy
                h, w = bgr.shape[:2]
                x1 = max(0, x1)
                y1 = max(0, y1)
                x2 = min(w, x2)
                y2 = min(h, y2)
                pad_x = int((x2 - x1) * 0.1)
                pad_y = int((y2 - y1) * 0.1)
                x1 = max(0, x1 - pad_x)
                y1 = max(0, y1 - pad_y)
                x2 = min(w, x2 + pad_x)
                y2 = min(h, y2 + pad_y)
                crop = bgr[y1:y2, x1:x2]
                if crop.size > 0:
                    return crop
    return central_square_anchor_crop(bgr)


# ---------------------------------------------------------------------------
# STEP 1 — Custom 9-class South Asian neckline classifier
# ---------------------------------------------------------------------------


def build_neck_crop_train_transforms() -> transforms.Compose:
    """Augmentations applied strictly on YOLO-isolated neck crops during training."""
    return transforms.Compose(
        [
            transforms.RandomHorizontalFlip(p=0.5),
            transforms.RandomRotation(degrees=15),
            transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
            transforms.RandomResizedCrop(size=224, scale=(0.8, 1.0)),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )


def build_neck_crop_eval_transforms() -> transforms.Compose:
    """Deterministic resize for validation/test/inference neck crops."""
    return transforms.Compose(
        [
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )


class NecklineFolderDataset(Dataset):
    """
    South Asian neckline loader.

    Live preprocessing per sample:
      1. Load raw image from folder path
      2. YOLO-World neck/collarbone bounding box (+10% pad, central-square fallback)
      3. Apply split-specific transforms on the isolated crop only
    """

    def __init__(
        self,
        samples: List[Dict[str, str]],
        transform: transforms.Compose,
        yolo_model: YOLO,
    ) -> None:
        self.samples = samples
        self.transform = transform
        self.yolo_model = yolo_model
        self.class_to_idx = neckline_class_to_idx()

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, index: int) -> Tuple[torch.Tensor, int]:
        row = self.samples[index]
        img_path = Path(row["image_path"])
        bgr = cv2.imread(str(img_path))
        if bgr is None or bgr.size == 0:
            bgr = np.zeros((224, 224, 3), dtype=np.uint8)
        neck_crop = crop_neckline_bbox(bgr, self.yolo_model)
        tensor = bgr_to_rgb_tensor(neck_crop, self.transform)
        label = row.get("neckline_label", DEFAULT_NECKLINE_CLASS)
        if label not in self.class_to_idx:
            label = DEFAULT_NECKLINE_CLASS
        return tensor, self.class_to_idx[label]


class NecklineClassifier(nn.Module):
    """MobileNetV3-Small transfer-learning head for 9 neckline tags."""

    def __init__(self, num_classes: int = len(NECKLINE_CLASSES)) -> None:
        super().__init__()
        weights = MobileNet_V3_Small_Weights.DEFAULT
        self.backbone = models.mobilenet_v3_small(weights=weights)
        in_features = self.backbone.classifier[0].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Linear(in_features, 256),
            nn.Hardswish(inplace=True),
            nn.Dropout(p=0.25),
            nn.Linear(256, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.backbone(x)


def build_neckline_loaders(
    yolo_model: YOLO,
    samples: Optional[List[Dict[str, str]]] = None,
    batch_size: int = BATCH_SIZE,
) -> Tuple[DataLoader, DataLoader, DataLoader]:
    train_tfm = build_neck_crop_train_transforms()
    eval_tfm = build_neck_crop_eval_transforms()

    if samples is None:
        samples = load_neckline_folder_samples(NECKLINES_ROOT)
    if not samples:
        raise RuntimeError(f"No neckline samples found in {NECKLINES_ROOT}")

    train_samples, val_samples, test_samples = split_dataset_samples(samples)

    loaders = []
    for split, split_samples in zip(("train", "val", "test"), (train_samples, val_samples, test_samples)):
        transform = train_tfm if split == "train" else eval_tfm
        ds = NecklineFolderDataset(split_samples, transform, yolo_model)
        loaders.append(
            DataLoader(
                ds,
                batch_size=batch_size,
                shuffle=split == "train",
                num_workers=0,
                pin_memory=torch.cuda.is_available(),
            )
        )
    return loaders[0], loaders[1], loaders[2]


def train_neckline_model(
    epochs: int = 8,
    lr: float = 1e-3,
    train_limit: Optional[int] = None,
) -> Dict[str, float]:
    samples = load_neckline_folder_samples(NECKLINES_ROOT)
    if train_limit is not None and train_limit > 0:
        samples = samples[:train_limit]
        logger.info("Neckline training capped to %d samples.", len(samples))
    if not samples:
        raise RuntimeError(f"No neckline samples found in {NECKLINES_ROOT}")

    yolo_model = _init_yolo_world(YOLO_NECKLINE_VOCAB)
    train_loader, val_loader, test_loader = build_neckline_loaders(
        yolo_model=yolo_model,
        samples=samples,
    )

    model = NecklineClassifier().to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=max(epochs, 1))

    best_val_acc = 0.0
    history: Dict[str, float] = {}

    for epoch in range(1, epochs + 1):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        for images, labels in train_loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * images.size(0)
            preds = outputs.argmax(dim=1)
            correct += (preds == labels).sum().item()
            total += labels.size(0)

        train_acc = correct / max(total, 1)
        val_loss, val_acc = _evaluate_classifier(model, val_loader, criterion)
        scheduler.step()
        logger.info(
            "Neckline Epoch %d/%d — train_loss=%.4f train_acc=%.3f val_loss=%.4f val_acc=%.3f",
            epoch,
            epochs,
            running_loss / max(total, 1),
            train_acc,
            val_loss,
            val_acc,
        )
        if val_acc >= best_val_acc:
            best_val_acc = val_acc
            save_neckline_checkpoint(model)

    save_neckline_checkpoint(model)
    test_loss, test_acc = _evaluate_classifier(model, test_loader, criterion)
    history = {
        "best_val_acc": best_val_acc,
        "test_acc": test_acc,
        "test_loss": test_loss,
        "classes": NECKLINE_CLASSES,
        "weights_path": str(NECKLINE_MODEL_PATH),
        "sample_count": len(samples),
    }
    logger.info(
        "Neckline training complete — test_acc=%.3f, weights=%s",
        test_acc,
        NECKLINE_MODEL_PATH,
    )
    return history


def _evaluate_classifier(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
) -> Tuple[float, float]:
    model.eval()
    loss_sum = 0.0
    correct = 0
    total = 0
    with torch.no_grad():
        for images, labels in loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss_sum += loss.item() * images.size(0)
            correct += (outputs.argmax(dim=1) == labels).sum().item()
            total += labels.size(0)
    return loss_sum / max(total, 1), correct / max(total, 1)


# ---------------------------------------------------------------------------
# STEP 2 — YOLO-World + EfficientNet-B0 jewelry style pipeline
# ---------------------------------------------------------------------------


class JewelryStyleClassifier(nn.Module):
    """
    EfficientNet-B0 with a replaced classifier head for 5 regional styles.

  Transfer learning rationale (viva defense):
  ImageNet-pretrained convolutional filters already encode edges, textures,
  and color distributions. With only ~700 jewelry images, training from scratch
  would overfit immediately; fine-tuning the last blocks plus aggressive
  in-memory augmentation (rotation, jitter, flip) synthetically multiplies
  diversity without splitting folders below viable sample counts.
    """

    def __init__(self, num_classes: int = len(JEWELRY_STYLE_CLASSES)) -> None:
        super().__init__()
        weights = EfficientNet_B0_Weights.DEFAULT
        self.backbone = models.efficientnet_b0(weights=weights)
        in_features = self.backbone.classifier[-1].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Dropout(p=0.3),
            nn.Linear(in_features, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.backbone(x)


def _init_yolo_world(vocabulary: Optional[List[str]] = None) -> YOLO:
    weights = AI_ROOT / "yolov8s-world.pt"
    if not weights.is_file():
        weights = AI_ROOT.parent / "yolov8s-world.pt"
    model = YOLO(str(weights))
    if vocabulary:
        model.set_classes(vocabulary)
    return model


def _yolo_best_crop(bgr: np.ndarray, yolo_model: YOLO) -> Tuple[Optional[np.ndarray], str]:
    """Run open-vocabulary detection; return highest-confidence item crop."""
    results = yolo_model.predict(source=bgr, verbose=False, conf=0.15)
    if not results:
        return None, "necklace"
    result = results[0]
    if result.boxes is None or len(result.boxes) == 0:
        h, w = bgr.shape[:2]
        return bgr, "necklace"

    best_conf = -1.0
    best_box = None
    best_cls_name = "necklace"
    names = result.names

    for box in result.boxes:
        conf = float(box.conf[0].cpu().numpy())
        if conf > best_conf:
            best_conf = conf
            xyxy = box.xyxy[0].cpu().numpy().astype(int)
            cls_id = int(box.cls[0].cpu().numpy())
            best_box = xyxy
            best_cls_name = names.get(cls_id, YOLO_ITEM_CLASSES[cls_id % len(YOLO_ITEM_CLASSES)])

    if best_box is None:
        return bgr, "necklace"

    x1, y1, x2, y2 = best_box
    h, w = bgr.shape[:2]
    x1, y1 = max(0, x1), max(0, y1)
    x2, y2 = min(w, x2), min(h, y2)
    crop = bgr[y1:y2, x1:x2]
    if crop.size == 0:
        return bgr, best_cls_name
    item_type = best_cls_name.lower()
    if item_type not in YOLO_ITEM_CLASSES:
        item_type = "necklace"
    return crop, item_type


def preprocess_jewelry_dataset(yolo_model: YOLO, force_refresh: bool = False) -> List[Dict[str, str]]:
    """
    Two-stage jewelry pipeline:
      1) YOLO-World localizes necklace / earring / bracelet in mixed folders.
      2) Crops are tagged with regional style from parent directory name.
    """
    if JEWELRY_CACHE_PATH.is_file() and not force_refresh:
        logger.info("Loading cached YOLO jewelry crops from %s", JEWELRY_CACHE_PATH)
        return json.loads(JEWELRY_CACHE_PATH.read_text(encoding="utf-8"))

    logger.info("Running YOLO-World preprocessing across regional jewelry folders...")
    samples: List[Dict[str, str]] = []
    image_exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".jfif"}

    for style_name in JEWELRY_STYLE_CLASSES:
        style_dir = JEWELRY_STYLE_ROOT / style_name
        if not style_dir.is_dir():
            logger.warning("Missing jewelry style directory: %s", style_dir)
            continue
        for img_file in style_dir.iterdir():
            if img_file.suffix.lower() not in image_exts:
                continue
            bgr = cv2.imread(str(img_file))
            if bgr is None:
                continue
            crop, item_type = _yolo_best_crop(bgr, yolo_model)
            crop_name = f"{style_name}_{img_file.stem}_crop.jpg"
            crop_path = MODELS_DIR / "jewelry_crops" / crop_name
            crop_path.parent.mkdir(parents=True, exist_ok=True)
            cv2.imwrite(str(crop_path), crop)
            samples.append(
                {
                    "crop_path": str(crop_path.relative_to(AI_ROOT)),
                    "style_label": style_name,
                    "item_type": item_type,
                    "source_image": str(img_file.relative_to(AI_ROOT)),
                }
            )

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    JEWELRY_CACHE_PATH.write_text(json.dumps(samples, indent=2), encoding="utf-8")
    logger.info("YOLO preprocessing complete — %d crops indexed.", len(samples))
    return samples


class JewelryStyleDataset(Dataset):
    def __init__(
        self,
        samples: List[Dict[str, str]],
        transform: transforms.Compose,
    ) -> None:
        self.samples = samples
        self.transform = transform
        self.class_to_idx = {c: i for i, c in enumerate(JEWELRY_STYLE_CLASSES)}

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, index: int) -> Tuple[torch.Tensor, int]:
        row = self.samples[index]
        path = AI_ROOT / row["crop_path"]
        bgr = cv2.imread(str(path))
        if bgr is None:
            bgr = np.zeros((224, 224, 3), dtype=np.uint8)
        tensor = bgr_to_rgb_tensor(bgr, self.transform)
        label = self.class_to_idx[row["style_label"]]
        return tensor, label


def build_jewelry_loaders(
    samples: List[Dict[str, str]],
    batch_size: int = BATCH_SIZE,
) -> DataLoader:
    """
    Aggressive augmentation defends the small (~700 image) jewelry corpus:
    rotations and color jitter simulate lighting & pose variance at train time.
    """
    weights = EfficientNet_B0_Weights.DEFAULT
    train_tfm = transforms.Compose(
        [
            transforms.Resize((256, 256)),
            transforms.RandomRotation(15),
            transforms.RandomHorizontalFlip(),
            transforms.ColorJitter(brightness=0.3, contrast=0.3, saturation=0.25, hue=0.05),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )
    ds = JewelryStyleDataset(samples, train_tfm)
    return DataLoader(
        ds,
        batch_size=min(batch_size, max(1, len(ds))),
        shuffle=True,
        num_workers=0,
        pin_memory=torch.cuda.is_available(),
    )


def train_jewelry_model(
    yolo_model: YOLO,
    epochs: int = 25,
    lr: float = 5e-4,
    force_yolo_refresh: bool = False,
) -> Dict[str, float]:
    samples = preprocess_jewelry_dataset(yolo_model, force_refresh=force_yolo_refresh)
    if not samples:
        raise RuntimeError("No jewelry samples found after YOLO preprocessing.")

    loader = build_jewelry_loaders(samples)
    model = JewelryStyleClassifier().to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.StepLR(optimizer, step_size=8, gamma=0.5)

    for epoch in range(1, epochs + 1):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        for images, labels in loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * images.size(0)
            correct += (outputs.argmax(dim=1) == labels).sum().item()
            total += labels.size(0)
        scheduler.step()
        acc = correct / max(total, 1)
        logger.info(
            "Jewelry Epoch %d/%d — loss=%.4f acc=%.3f (augmented in-memory batches)",
            epoch,
            epochs,
            running_loss / max(total, 1),
            acc,
        )

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    torch.save(
        {
            "model_state": model.state_dict(),
            "classes": JEWELRY_STYLE_CLASSES,
            "arch": "efficientnet_b0",
        },
        JEWELRY_MODEL_PATH,
    )
    logger.info("Jewelry model saved to %s", JEWELRY_MODEL_PATH)
    return {"final_train_acc": correct / max(total, 1)}


# ---------------------------------------------------------------------------
# STEP 2b — Skin tone classifier (folder dataset, no YOLO)
# ---------------------------------------------------------------------------


def skin_tone_class_to_idx() -> Dict[str, int]:
    return {name: idx for idx, name in enumerate(SKIN_TONE_CLASSES)}


def load_skin_tone_folder_samples(
    root: Path,
    allowed_labels: Optional[List[str]] = None,
) -> List[Dict[str, str]]:
    allowed_labels = allowed_labels or SKIN_TONE_CLASSES
    class_to_idx = skin_tone_class_to_idx()
    image_exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".jfif"}
    samples: List[Dict[str, str]] = []
    for label in allowed_labels:
        if label not in class_to_idx:
            logger.warning("Skipping unknown skin tone label: %s", label)
            continue
        folder = root / label
        if not folder.is_dir():
            logger.warning("Missing skin tone folder: %s", folder)
            continue
        for image_path in sorted(folder.iterdir()):
            if image_path.suffix.lower() not in image_exts:
                continue
            samples.append(
                {
                    "image_path": str(image_path),
                    "skin_tone_label": label,
                    "class_index": class_to_idx[label],
                }
            )
    return samples


class SkinToneFolderDataset(Dataset):
    def __init__(
        self,
        samples: List[Dict[str, str]],
        transform: transforms.Compose,
    ) -> None:
        self.samples = samples
        self.transform = transform
        self.class_to_idx = skin_tone_class_to_idx()

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, index: int) -> Tuple[torch.Tensor, int]:
        row = self.samples[index]
        bgr = cv2.imread(str(row["image_path"]))
        if bgr is None or bgr.size == 0:
            bgr = np.zeros((224, 224, 3), dtype=np.uint8)
        cropped = extract_skin_tone_crop(bgr)
        tensor = bgr_to_rgb_tensor(cropped, self.transform)
        label = row.get("skin_tone_label", SKIN_TONE_CLASSES[0])
        if label not in self.class_to_idx:
            label = SKIN_TONE_CLASSES[0]
        return tensor, self.class_to_idx[label]


class SkinToneClassifier(nn.Module):
    """MobileNetV3-Small head for 3 skin-tone folders."""

    def __init__(self, num_classes: int = len(SKIN_TONE_CLASSES)) -> None:
        super().__init__()
        weights = MobileNet_V3_Small_Weights.DEFAULT
        self.backbone = models.mobilenet_v3_small(weights=weights)
        in_features = self.backbone.classifier[0].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Linear(in_features, 128),
            nn.Hardswish(inplace=True),
            nn.Dropout(p=0.2),
            nn.Linear(128, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.backbone(x)


def build_skin_tone_loaders(
    samples: Optional[List[Dict[str, str]]] = None,
    batch_size: int = BATCH_SIZE,
) -> Tuple[DataLoader, DataLoader, DataLoader]:
    weights = MobileNet_V3_Small_Weights.DEFAULT
    train_tfm = transforms.Compose(
        [
            transforms.Resize((224, 224)),
            transforms.RandomHorizontalFlip(),
            transforms.ColorJitter(brightness=0.2, contrast=0.15, saturation=0.1),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )
    eval_tfm = weights.transforms()

    if samples is None:
        samples = load_skin_tone_folder_samples(SKIN_TONE_ROOT)
    if not samples:
        raise RuntimeError(f"No skin tone samples found in {SKIN_TONE_ROOT}")

    train_samples, val_samples, test_samples = split_dataset_samples(samples)
    loaders = []
    for split, split_samples in zip(("train", "val", "test"), (train_samples, val_samples, test_samples)):
        transform = train_tfm if split == "train" else eval_tfm
        ds = SkinToneFolderDataset(split_samples, transform)
        loaders.append(
            DataLoader(
                ds,
                batch_size=batch_size,
                shuffle=split == "train",
                num_workers=0,
                pin_memory=torch.cuda.is_available(),
            )
        )
    return loaders[0], loaders[1], loaders[2]


def save_skin_tone_checkpoint(model: nn.Module, path: Path = SKIN_TONE_MODEL_PATH) -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    torch.save(
        {
            "model_state": model.state_dict(),
            "classes": SKIN_TONE_CLASSES,
            "class_to_idx": skin_tone_class_to_idx(),
            "display_map": SKIN_TONE_DISPLAY_MAP,
            "arch": "mobilenet_v3_small",
            "num_classes": len(SKIN_TONE_CLASSES),
        },
        path,
    )
    logger.info("Saved skin tone checkpoint → %s", path)


def train_skin_tone_model(epochs: int = 10, lr: float = 1e-3) -> Dict[str, float]:
    samples = load_skin_tone_folder_samples(SKIN_TONE_ROOT)
    if not samples:
        raise RuntimeError(f"No skin tone samples found in {SKIN_TONE_ROOT}")
    logger.info("Skin tone dataset: %d samples across %d classes", len(samples), len(SKIN_TONE_CLASSES))

    train_loader, val_loader, test_loader = build_skin_tone_loaders(samples=samples)
    model = SkinToneClassifier().to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=max(epochs, 1))

    best_val_acc = 0.0
    for epoch in range(1, epochs + 1):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        for images, labels in train_loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * images.size(0)
            correct += (outputs.argmax(dim=1) == labels).sum().item()
            total += labels.size(0)

        train_acc = correct / max(total, 1)
        val_loss, val_acc = _evaluate_classifier(model, val_loader, criterion)
        scheduler.step()
        logger.info(
            "Skin Tone Epoch %d/%d — train_loss=%.4f train_acc=%.3f val_loss=%.4f val_acc=%.3f",
            epoch,
            epochs,
            running_loss / max(total, 1),
            train_acc,
            val_loss,
            val_acc,
        )
        if val_acc >= best_val_acc:
            best_val_acc = val_acc
            save_skin_tone_checkpoint(model)

    save_skin_tone_checkpoint(model)
    test_loss, test_acc = _evaluate_classifier(model, test_loader, criterion)
    logger.info("Skin tone training complete — test_acc=%.3f", test_acc)
    return {
        "best_val_acc": best_val_acc,
        "test_acc": test_acc,
        "test_loss": test_loss,
        "sample_count": len(samples),
        "weights_path": str(SKIN_TONE_MODEL_PATH),
    }


def format_skin_tone_label(raw_label: str) -> str:
    return SKIN_TONE_DISPLAY_MAP.get(raw_label, raw_label.title())


# ---------------------------------------------------------------------------
# STEP 3 — Expert recommendation engine
# ---------------------------------------------------------------------------


class ZarvaRecommendationEngine:
    """Loads trained weights and runs multi-stage outfit → jewelry inference."""

    def __init__(self) -> None:
        self.device = DEVICE
        self.neckline_model: Optional[NecklineClassifier] = None
        self.jewelry_model: Optional[JewelryStyleClassifier] = None
        self.skin_tone_model: Optional[SkinToneClassifier] = None
        self.neckline_yolo: Optional[YOLO] = None
        self.jewelry_yolo: Optional[YOLO] = None
        self._neckline_classes: List[str] = list(NECKLINE_CLASSES)
        self._skin_tone_classes: List[str] = list(SKIN_TONE_CLASSES)
        self._neckline_tfm = build_neck_crop_eval_transforms()
        self._jewelry_tfm = EfficientNet_B0_Weights.DEFAULT.transforms()
        self._skin_tone_tfm = MobileNet_V3_Small_Weights.DEFAULT.transforms()
        self._load_models()

    def _load_models(self) -> None:
        if NECKLINE_MODEL_PATH.is_file():
            ckpt = torch.load(NECKLINE_MODEL_PATH, map_location=self.device, weights_only=False)
            ckpt_classes = ckpt.get("classes", NECKLINE_CLASSES)
            try:
                validate_neckline_classes(ckpt_classes)
            except ValueError as exc:
                logger.error(
                    "Checkpoint at %s has incompatible class labels — %s. "
                    "Run: python train_pipeline.py --mode train-neckline",
                    NECKLINE_MODEL_PATH,
                    exc,
                )
                return
            self._neckline_classes = ckpt_classes
            self.neckline_model = NecklineClassifier(num_classes=len(self._neckline_classes)).to(self.device)
            self.neckline_model.load_state_dict(ckpt["model_state"])
            self.neckline_model.eval()
            self._neckline_tfm = build_neck_crop_eval_transforms()
            logger.info(
                "Loaded 9-class neckline classifier from %s — classes: %s",
                NECKLINE_MODEL_PATH,
                self._neckline_classes,
            )
        else:
            logger.warning(
                "Neckline weights missing at %s — train with: python train_pipeline.py --mode train-neckline",
                NECKLINE_MODEL_PATH,
            )

        if JEWELRY_MODEL_PATH.is_file():
            self.jewelry_model = JewelryStyleClassifier().to(self.device)
            ckpt = torch.load(JEWELRY_MODEL_PATH, map_location=self.device, weights_only=False)
            self.jewelry_model.load_state_dict(ckpt["model_state"])
            self.jewelry_model.eval()
            logger.info("Loaded jewelry style classifier from %s", JEWELRY_MODEL_PATH)
        else:
            logger.warning("Jewelry weights missing — train with --mode train first.")

        if SKIN_TONE_MODEL_PATH.is_file():
            ckpt = torch.load(SKIN_TONE_MODEL_PATH, map_location=self.device, weights_only=False)
            self._skin_tone_classes = ckpt.get("classes", SKIN_TONE_CLASSES)
            self.skin_tone_model = SkinToneClassifier(num_classes=len(self._skin_tone_classes)).to(self.device)
            self.skin_tone_model.load_state_dict(ckpt["model_state"])
            self.skin_tone_model.eval()
            logger.info("Loaded skin tone classifier from %s — classes: %s", SKIN_TONE_MODEL_PATH, self._skin_tone_classes)
        else:
            logger.warning("Skin tone weights missing at %s — train with --mode train-skin-tone", SKIN_TONE_MODEL_PATH)

        self.neckline_yolo = _init_yolo_world(YOLO_NECKLINE_VOCAB)
        self.jewelry_yolo = _init_yolo_world(YOLO_ITEM_CLASSES)

    def isolate_neck_region(self, bgr: np.ndarray) -> np.ndarray:
        """Priority YOLO crop — neckline/collarbone box before any downstream step."""
        if self.neckline_yolo is None:
            self.neckline_yolo = _init_yolo_world(YOLO_NECKLINE_VOCAB)
        return crop_neckline_bbox(bgr, self.neckline_yolo)

    def predict_neckline_from_crop(self, neck_crop: np.ndarray) -> str:
        """Classify neckline from an already YOLO-localized neck crop."""
        if self.neckline_model is None:
            return DEFAULT_NECKLINE_CLASS
        tensor = bgr_to_rgb_tensor(neck_crop, self._neckline_tfm).unsqueeze(0).to(self.device)
        with torch.no_grad():
            logits = self.neckline_model(tensor)
            idx = int(logits.argmax(dim=1).item())
        if idx < 0 or idx >= len(self._neckline_classes):
            logger.warning(
                "Neckline index %d out of range — defaulting to %s",
                idx,
                DEFAULT_NECKLINE_CLASS,
            )
            idx = DEFAULT_NECKLINE_INDEX
        return self._neckline_classes[idx]

    def predict_neckline(self, bgr: np.ndarray, neck_crop: Optional[np.ndarray] = None) -> str:
        crop = neck_crop if neck_crop is not None else self.isolate_neck_region(bgr)
        return self.predict_neckline_from_crop(crop)

    def predict_jewelry_style(self, bgr: np.ndarray) -> Tuple[str, str]:
        """Returns (regional_style, detected_item_type)."""
        if self.jewelry_yolo is None:
            self.jewelry_yolo = _init_yolo_world(YOLO_ITEM_CLASSES)
        crop, item_type = _yolo_best_crop(bgr, self.jewelry_yolo)
        if self.jewelry_model is None:
            return "Mughal", item_type
        tensor = bgr_to_rgb_tensor(crop, self._jewelry_tfm).unsqueeze(0).to(self.device)
        with torch.no_grad():
            logits = self.jewelry_model(tensor)
            idx = int(logits.argmax(dim=1).item())
        return JEWELRY_STYLE_CLASSES[idx], item_type

    def predict_skin_tone(self, bgr: np.ndarray) -> str:
        """Predict skin tone from upper-centre crop; returns Flutter-friendly label."""
        if self.skin_tone_model is None:
            return "Neutral"
        skin_crop = extract_skin_tone_crop(bgr)
        tensor = bgr_to_rgb_tensor(skin_crop, self._skin_tone_tfm).unsqueeze(0).to(self.device)
        with torch.no_grad():
            logits = self.skin_tone_model(tensor)
            idx = int(logits.argmax(dim=1).item())
        if idx < 0 or idx >= len(self._skin_tone_classes):
            idx = 0
        raw_label = self._skin_tone_classes[idx]
        display = format_skin_tone_label(raw_label)
        logger.info("Skin tone prediction: %s → %s", raw_label, display)
        return display

    def build_recommendation_payload(
        self,
        neckline: str,
        jewelry_style: str,
        detected_item: str,
        dress_color: str,
        skin_tone: str,
        user_query: str = "",
        color_auto_detected: bool = False,
        skin_tone_auto_detected: bool = False,
        dress_has_warm_accents: bool = False,
    ) -> Dict[str, Any]:
        neckline_tag = normalize_neckline_label(neckline)
        fused = build_tri_factor_recommendation(
            neckline=neckline_tag,
            dress_color=dress_color,
            skin_tone=skin_tone,
            user_query=user_query,
            dress_has_warm_accents=dress_has_warm_accents,
            color_auto_detected=color_auto_detected,
            skin_tone_auto_detected=skin_tone_auto_detected,
        )
        recommended_piece = fused["jewelry_tag"]
        styling_insight = fused["styling_insight"]
        accent_label = (
            "Earrings" if "Earrings Only" in recommended_piece else "Necklace"
        )

        return {
            "neckline": neckline_tag,
            "neckline_tag": neckline_tag,
            "jewelryStyle": fused["heritage_style"],
            "jewelry_tag": recommended_piece,
            "metalType": fused["metal_type"],
            "heritageStyle": fused["heritage_style"],
            "recommendedJewelryType": recommended_piece,
            "recommendedAccentLabel": accent_label,
            "culturalTheme": fused["heritage_style"],
            "detectedItemType": detected_item,
            "detectedRegionalStyle": jewelry_style,
            "dressColor": dress_color,
            "skinTone": skin_tone,
            "stylingInsight": styling_insight,
            "styling_insight": styling_insight,
            "whyThisWorks": fused["whyThisWorks"],
            "why_this_works": fused["why_this_works"],
            "recommendation": styling_insight,
            "text": styling_insight,
            "reply": styling_insight,
            "colorAutoDetected": color_auto_detected,
            "skinToneAutoDetected": skin_tone_auto_detected,
        }

    def run_pipeline(
        self,
        outfit_bgr: np.ndarray,
        jewelry_bgr: Optional[np.ndarray],
        dress_color: str,
        skin_tone: str,
        manual_neckline: str = "",
        user_query: str = "",
    ) -> Dict[str, Any]:
        neck_crop = self.isolate_neck_region(outfit_bgr)
        logger.info(
            "YOLO neck crop ready — original=%dx%d, crop=%dx%d",
            outfit_bgr.shape[1],
            outfit_bgr.shape[0],
            neck_crop.shape[1],
            neck_crop.shape[0],
        )

        color_auto = False
        skin_auto = False
        dress_warm_accents = False
        if not dress_color.strip():
            _dominant, dress_warm_accents, dress_color = extract_dress_color_profile(neck_crop)
            color_auto = True
            logger.info(
                "K-Means dress colour from neck crop: %s (warm_accents=%s)",
                dress_color,
                dress_warm_accents,
            )
        if not skin_tone.strip():
            skin_tone = self.predict_skin_tone(outfit_bgr)
            skin_auto = True

        override = resolve_manual_neckline(manual_neckline)
        raw_neckline = override if override else self.predict_neckline_from_crop(neck_crop)
        neckline = normalize_neckline_label(raw_neckline)
        if neckline != raw_neckline:
            logger.info("Neckline normalized: %s → %s", raw_neckline, neckline)

        reference = jewelry_bgr if jewelry_bgr is not None else outfit_bgr
        jewelry_style, detected_item = self.predict_jewelry_style(reference)
        return self.build_recommendation_payload(
            neckline,
            jewelry_style,
            detected_item,
            dress_color,
            skin_tone,
            user_query=user_query,
            color_auto_detected=color_auto,
            skin_tone_auto_detected=skin_auto,
            dress_has_warm_accents=dress_warm_accents,
        )


# ---------------------------------------------------------------------------
# STEP 4 — MongoDB Atlas persistence
# ---------------------------------------------------------------------------


def get_mongo_collection() -> Optional[Collection]:
    uri = os.environ.get("MONGO_URI", "").strip()
    if not uri:
        logger.warning("MONGO_URI not set — database writes disabled.")
        return None
    client = MongoClient(uri, serverSelectionTimeoutMS=15000)
    db = client["zarva_db"]
    return db["chats"]


def save_chat_to_db(
    user_id: str,
    user_message: str,
    bot_response: str,
    metadata: Optional[Dict[str, Any]] = None,
) -> Optional[str]:
    """
    Upsert user chat history in zarva_db.chats.
    Returns inserted document id string on success.
    """
    try:
        collection = get_mongo_collection()
        if collection is None:
            return None

        now = datetime.now(timezone.utc)
        entry = {
            "role": "user",
            "content": user_message,
            "timestamp": now,
        }
        assistant_entry = {
            "role": "assistant",
            "content": bot_response,
            "metadata": metadata or {},
            "timestamp": now,
        }

        result = collection.update_one(
            {"user_id": user_id},
            {
                "$push": {"messages": {"$each": [entry, assistant_entry]}},
                "$set": {"updated_at": now},
                "$setOnInsert": {"created_at": now},
            },
            upsert=True,
        )
        doc_id = str(result.upserted_id) if result.upserted_id else user_id
        logger.info("Chat history saved for user_id=%s", user_id)
        return doc_id
    except Exception as e:
        logger.error("Failed to save chat to database: %s", e)
        return None


# ---------------------------------------------------------------------------
# STEP 5 — FastAPI production wrapper
# ---------------------------------------------------------------------------

_engine: Optional[ZarvaRecommendationEngine] = None


def get_engine() -> ZarvaRecommendationEngine:
    global _engine
    if _engine is None:
        _engine = ZarvaRecommendationEngine()
    return _engine


def create_app() -> "FastAPI":
    if FastAPI is None:
        raise ImportError("FastAPI is not installed. pip install fastapi uvicorn")

    app = FastAPI(
        title="ZARVA AI Recommendation Service",
        description="South Asian fashion & jewelry SAAS inference API",
        version="1.0.0",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/health")
    async def health() -> Dict[str, str]:
        return {"status": "ok", "service": "zarva-ai"}

    @app.post("/api/ai/recommend")
    async def recommend(
        userId: str = Form(default="guest"),
        dressColor: str = Form(default=""),
        skinTone: str = Form(default=""),
        manualNeckline: str = Form(default=""),
        userQuery: str = Form(default=""),
        image: UploadFile = File(...),
    ) -> Dict[str, Any]:
        raw = await image.read()
        arr = np.frombuffer(raw, dtype=np.uint8)
        outfit_bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if outfit_bgr is None:
            return {"success": False, "error": "Invalid image upload."}

        engine = get_engine()
        payload = engine.run_pipeline(
            outfit_bgr,
            None,
            dressColor,
            skinTone,
            manual_neckline=manualNeckline,
            user_query=userQuery,
        )
        user_message = userQuery.strip() or (
            f"Outfit styling — dressColor={dressColor or 'auto'}, "
            f"skinTone={skinTone or 'auto'}, manualNeckline={manualNeckline or 'auto'}"
        )
        save_chat_to_db(
            user_id=userId,
            user_message=user_message,
            bot_response=payload["recommendation"],
            metadata=payload,
        )
        return {
            "success": True,
            "userId": userId,
            "sessionId": str(uuid.uuid4()),
            **payload,
        }

    @app.post("/api/chat/text")
    async def chat_text(
        userId: str = Form(default="guest"),
        userQuery: str = Form(default=""),
    ) -> Dict[str, Any]:
        text_payload = fashion_text_reply(userQuery)
        save_chat_to_db(
            user_id=userId,
            user_message=userQuery,
            bot_response=text_payload["reply"],
            metadata=text_payload,
        )
        return {
            "success": True,
            "userId": userId,
            "sessionId": str(uuid.uuid4()),
            "type": "text",
            "reply": text_payload["reply"],
            "recommendation": text_payload["recommendation"],
            "text": text_payload["text"],
            "stylingInsight": text_payload["styling_insight"],
            "styling_insight": text_payload["styling_insight"],
            "whyThisWorks": text_payload["whyThisWorks"],
            "why_this_works": text_payload["why_this_works"],
            "neckline_tag": text_payload["neckline_tag"],
            "jewelry_tag": text_payload["jewelry_tag"],
        }

    return app


# ---------------------------------------------------------------------------
# Orchestration CLI
# ---------------------------------------------------------------------------


def run_full_training(
    neckline_epochs: int = 8,
    jewelry_epochs: int = 25,
    neckline_train_limit: Optional[int] = None,
    force_yolo_refresh: bool = False,
) -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    logger.info("ZARVA training on device: %s", DEVICE)

    logger.info("=== STAGE 1: Custom South Asian neckline transfer learning ===")
    neckline_metrics = train_neckline_model(
        epochs=neckline_epochs,
        train_limit=neckline_train_limit,
    )

    logger.info("=== STAGE 2: YOLO-World + EfficientNet-B0 jewelry styles ===")
    yolo = _init_yolo_world()
    jewelry_metrics = train_jewelry_model(
        yolo_model=yolo,
        epochs=jewelry_epochs,
        force_yolo_refresh=force_yolo_refresh,
    )

    logger.info("=== STAGE 3: Skin tone MobileNetV3 transfer learning ===")
    skin_tone_metrics = train_skin_tone_model()

    config = {
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "device": str(DEVICE),
        "neckline_metrics": neckline_metrics,
        "jewelry_metrics": jewelry_metrics,
        "skin_tone_metrics": skin_tone_metrics,
        "neckline_weights": str(NECKLINE_MODEL_PATH),
        "jewelry_weights": str(JEWELRY_MODEL_PATH),
        "skin_tone_weights": str(SKIN_TONE_MODEL_PATH),
        "recommendation_engine": "tri_factor_fusion_matrix",
        "neckline_classes": NECKLINE_CLASSES,
    }
    TRAINING_CONFIG_PATH.write_text(json.dumps(config, indent=2), encoding="utf-8")
    logger.info("Training config written to %s", TRAINING_CONFIG_PATH)
    logger.info("=== All training stages complete ===")


def serve_api(host: str = "0.0.0.0", port: int = 8000) -> None:
    _load_env()
    app = create_app()
    uvicorn.run(app, host=host, port=port, log_level="info")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="ZARVA AI train & serve pipeline")
    parser.add_argument(
        "--mode",
        choices=["train", "train-neckline", "train-skin-tone", "serve", "all"],
        default="all",
        help="train all models, neckline only, skin tone only, serve API, or train+serve",
    )
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--neckline-epochs", type=int, default=8)
    parser.add_argument("--jewelry-epochs", type=int, default=25)
    parser.add_argument("--skin-tone-epochs", type=int, default=10)
    parser.add_argument(
        "--neckline-train-limit",
        type=int,
        default=None,
        help="Optional cap on Custom South Asian train rows (default: full filtered set)",
    )
    parser.add_argument("--force-yolo-refresh", action="store_true")
    return parser.parse_args()


def main() -> None:
    _load_env()
    args = parse_args()

    if args.mode == "train-neckline":
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        logger.info("=== Neckline-only training (9-class custom dataset) ===")
        train_neckline_model(
            epochs=args.neckline_epochs,
            train_limit=args.neckline_train_limit,
        )
    elif args.mode == "train-skin-tone":
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        logger.info("=== Skin tone-only training (3-class custom dataset) ===")
        train_skin_tone_model(epochs=args.skin_tone_epochs)
    elif args.mode in ("train", "all"):
        run_full_training(
            neckline_epochs=args.neckline_epochs,
            jewelry_epochs=args.jewelry_epochs,
            neckline_train_limit=args.neckline_train_limit,
            force_yolo_refresh=args.force_yolo_refresh,
        )

    if args.mode in ("serve", "all"):
        serve_api(host=args.host, port=args.port)


if __name__ == "__main__":
    main()
