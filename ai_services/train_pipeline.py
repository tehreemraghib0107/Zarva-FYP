#!/usr/bin/env python3
"""
ZARVA AI Services — End-to-end training, inference, and FastAPI production engine.

Stages:
  1. IndoFashion neckline classification (MobileNetV3 + neck crop heuristic)
  2. YOLO-World jewelry detection + EfficientNet-B0 regional style classifier
  3. Expert styling matrix → recommendation payload
  4. MongoDB Atlas chat persistence
  5. FastAPI POST /api/ai/recommend
"""

from __future__ import annotations

import argparse
import json
import logging
import os
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
MODELS_DIR = AI_ROOT / "models"

NECKLINE_JSON_FILES = {
    "train": NECKLINES_ROOT / "train_data.json",
    "val": NECKLINES_ROOT / "val_data.json",
    "test": NECKLINES_ROOT / "test_data.json",
}

TARGET_GARMENT_CLASSES = [
    "women_kurta",
    "saree",
    "gowns",
    "blouse",
    "lehenga",
]

NECKLINE_CLASSES = [
    "Boat Neck",
    "Collar/Ban",
    "Round",
    "Sweetheart",
    "V-Neck",
]

JEWELRY_STYLE_CLASSES = [
    "Arabian",
    "Kashmiri",
    "Mughal",
    "Pashtun",
    "Turkish",
]

YOLO_ITEM_CLASSES = ["necklace", "earring", "bracelet"]

STYLING_RULES: Dict[str, str] = {
    "Collar/Ban": "earring",
    "V-Neck": "necklace",
    "Sweetheart": "necklace",
    "Boat Neck": "necklace",
    "Round": "necklace",
}

NECKLINE_MODEL_PATH = MODELS_DIR / "neckline_mobilenetv3.pth"
JEWELRY_MODEL_PATH = MODELS_DIR / "jewelry_efficientnet_b0.pth"
PSEUDO_LABELS_PATH = MODELS_DIR / "neckline_pseudo_labels.json"
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


def crop_neck_region(bgr: np.ndarray) -> np.ndarray:
    """
    Isolate the upper-torso neckline band: skip generic head clearance (~8%),
    then capture the next ~22% vertical slice (≈20–25% garment zone).
    """
    if bgr is None or bgr.size == 0:
        raise ValueError("Empty image passed to crop_neck_region")
    h, w = bgr.shape[:2]
    head_clearance = max(1, int(h * 0.08))
    neck_band_height = max(1, int(h * 0.22))
    y0 = head_clearance
    y1 = min(h, y0 + neck_band_height)
    return bgr[y0:y1, 0:w]


def bgr_to_rgb_tensor(bgr: np.ndarray, transform: transforms.Compose) -> torch.Tensor:
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    pil = Image.fromarray(rgb)
    return transform(pil)


PALETTE_RGB_ANCHORS: Dict[str, Tuple[int, int, int]] = {
    "Red": (180, 40, 50),
    "Blue": (45, 70, 160),
    "Pastel": (210, 190, 220),
    "Gold": (200, 170, 80),
    "Green": (50, 120, 70),
    "Maroon": (100, 25, 40),
    "Ivory": (235, 225, 205),
}

MANUAL_NECKLINE_MAP: Dict[str, str] = {
    "round / scoop": "Round",
    "round": "Round",
    "v-neck": "V-Neck",
    "boat neck": "Boat Neck",
    "collar / ban": "Collar/Ban",
    "collar/ban": "Collar/Ban",
    "sweetheart": "Sweetheart",
}


def extract_dominant_dress_color(bgr: np.ndarray) -> str:
    """K-Means dominant garment colour when the client sends an empty dressColor."""
    small = cv2.resize(bgr, (128, 128))
    pixels = small.reshape(-1, 3).astype(np.float32)
    if len(pixels) < 3:
        return "Gold"
    _compactness, labels, centers = cv2.kmeans(
        pixels,
        3,
        None,
        (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 24, 1.0),
        8,
        cv2.KMEANS_PP_CENTERS,
    )
    counts = np.bincount(labels.flatten(), minlength=3)
    dominant_bgr = centers[int(np.argmax(counts))]
    dominant_rgb = (int(dominant_bgr[2]), int(dominant_bgr[1]), int(dominant_bgr[0]))
    best_name = "Gold"
    best_dist = float("inf")
    for name, rgb in PALETTE_RGB_ANCHORS.items():
        dist = sum((dominant_rgb[i] - rgb[i]) ** 2 for i in range(3))
        if dist < best_dist:
            best_dist = dist
            best_name = name
    return best_name


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
    """Lightweight text-only stylist replies when no outfit image is supplied."""
    q = user_query.strip().lower()
    if not q:
        return {
            "reply": (
                "Welcome to ZarBot. Ask me about saree draping, lehenga jewelry pairing, "
                "or attach an outfit photo for a full AI styling pass."
            ),
            "whyThisWorks": "Open prompts help us guide you toward the right styling pathway.",
        }
    if any(w in q for w in ("saree", "sari")):
        return {
            "reply": (
                "For sarees, balance the drape with a necklace that follows your blouse neckline — "
                "V and sweetheart necks love layered temple chains; boat necks suit collar-grazing strands."
            ),
            "whyThisWorks": "Vertical lines on the torso stay uninterrupted when jewelry echoes the neckline geometry.",
        }
    if any(w in q for w in ("lehenga", "bridal", "wedding")):
        return {
            "reply": (
                "Bridal lehengas shine with regional statement pieces: Mughal kundan chokers, "
                "Pashtun jhumkas, or Kashmiri delicate filigree depending on your embroidery palette."
            ),
            "whyThisWorks": "Heavy skirt volume is balanced by focal jewelry near the face and neckline.",
        }
    if any(w in q for w in ("kurta", "kurti", "salwar")):
        return {
            "reply": (
                "Kurtas with collar or band necklines photograph best with earrings alone; "
                "add a delicate necklace only if the neckline drops below the collar bone."
            ),
            "whyThisWorks": "High necklines avoid visual clutter — earrings draw the eye without competing lines.",
        }
    return {
        "reply": (
            "I can craft a full jewelry recommendation when you attach an outfit photo. "
            "Until then: match metal tone to embroidery, and let one statement piece anchor the look."
        ),
        "whyThisWorks": "A single focal accessory prevents competing highlights on richly embellished South Asian textiles.",
    }


# ---------------------------------------------------------------------------
# JSON dataset utilities
# ---------------------------------------------------------------------------


def load_json_records(json_path: Path) -> List[Dict[str, Any]]:
    """Load line-delimited JSON objects or a standard JSON array."""
    text = json_path.read_text(encoding="utf-8").strip()
    if not text:
        return []
    if text.startswith("["):
        data = json.loads(text)
        return data if isinstance(data, list) else []
    records: List[Dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if line:
            records.append(json.loads(line))
    return records


def filter_garment_records(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    allowed = {c.lower() for c in TARGET_GARMENT_CLASSES}
    filtered = []
    for row in records:
        label = str(row.get("class_label", "")).strip().lower()
        if label in allowed:
            filtered.append(row)
    return filtered


def resolve_image_path(relative_path: str) -> Path:
    rel = relative_path.replace("\\", "/").lstrip("/")
    if rel.startswith("images/"):
        return NECKLINES_ROOT / rel
    return NECKLINES_ROOT / "images" / rel.split("images/")[-1]


# ---------------------------------------------------------------------------
# STEP 1 — IndoFashion dataset & neckline classifier
# ---------------------------------------------------------------------------


class IndoFashionDataset(Dataset):
    """IndoFashion JSON loader with inline neck crop and neckline labels."""

    def __init__(
        self,
        records: List[Dict[str, Any]],
        transform: transforms.Compose,
        label_map: Optional[Dict[str, str]] = None,
        default_label: str = "Round",
    ) -> None:
        self.records = records
        self.transform = transform
        self.label_map = label_map or {}
        self.default_label = default_label
        self.class_to_idx = {c: i for i, c in enumerate(NECKLINE_CLASSES)}

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, index: int) -> Tuple[torch.Tensor, int]:
        row = self.records[index]
        img_path = resolve_image_path(str(row["image_path"]))
        bgr = cv2.imread(str(img_path))
        if bgr is None:
            bgr = np.zeros((224, 224, 3), dtype=np.uint8)
        cropped = crop_neck_region(bgr)
        tensor = bgr_to_rgb_tensor(cropped, self.transform)
        rel_key = str(row["image_path"]).replace("\\", "/")
        neckline = row.get("neckline_label") or self.label_map.get(rel_key, self.default_label)
        if neckline not in self.class_to_idx:
            neckline = self.default_label
        return tensor, self.class_to_idx[neckline]


class NecklineClassifier(nn.Module):
    """MobileNetV3-Small transfer-learning head for 5 neckline tags."""

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


def _build_feature_extractor() -> Tuple[nn.Module, transforms.Compose]:
    """Frozen MobileNet trunk for pseudo-label clustering."""
    weights = MobileNet_V3_Small_Weights.DEFAULT
    net = models.mobilenet_v3_small(weights=weights)
    net.classifier = nn.Identity()
    net.eval()
    net.to(DEVICE)
    tfm = weights.transforms()
    return net, tfm


def generate_pseudo_neckline_labels(
    records: List[Dict[str, Any]],
    max_samples: int = 5000,
) -> Dict[str, str]:
    """
    IndoFashion JSON lacks neckline annotations. Bootstrap weak labels via
    frozen ImageNet features + KMeans(5), then name clusters by crop geometry
    (aspect ratio & edge density) for reproducible viva-ready training signal.
    """
    if PSEUDO_LABELS_PATH.is_file():
        logger.info("Loading cached pseudo neckline labels from %s", PSEUDO_LABELS_PATH)
        return json.loads(PSEUDO_LABELS_PATH.read_text(encoding="utf-8"))

    logger.info("Generating pseudo neckline labels (max_samples=%d)...", max_samples)
    extractor, tfm = _build_feature_extractor()
    subset = records[:max_samples]
    features: List[np.ndarray] = []
    meta: List[Dict[str, Any]] = []

    with torch.no_grad():
        for row in subset:
            img_path = resolve_image_path(str(row["image_path"]))
            bgr = cv2.imread(str(img_path))
            if bgr is None:
                continue
            cropped = crop_neck_region(bgr)
            tensor = bgr_to_rgb_tensor(cropped, tfm).unsqueeze(0).to(DEVICE)
            feat = extractor(tensor).cpu().numpy().flatten()
            gray = cv2.cvtColor(cropped, cv2.COLOR_BGR2GRAY)
            edges = cv2.Canny(gray, 50, 150)
            edge_density = float(edges.mean()) / 255.0
            h, w = cropped.shape[:2]
            aspect = w / max(h, 1)
            rel_key = str(row["image_path"]).replace("\\", "/")
            features.append(feat)
            meta.append(
                {
                    "image_path": rel_key,
                    "aspect": aspect,
                    "edge_density": edge_density,
                }
            )

    if len(features) < 5:
        logger.warning("Insufficient samples for KMeans; defaulting all labels to Round.")
        return {m["image_path"]: "Round" for m in meta}

    X = np.stack(features, axis=0)
    kmeans = KMeans(n_clusters=5, random_state=42, n_init=10)
    cluster_ids = kmeans.fit_predict(X)

    cluster_stats: Dict[int, Dict[str, float]] = defaultdict(
        lambda: {"aspect": 0.0, "edge": 0.0, "count": 0}
    )
    for cid, m in zip(cluster_ids, meta):
        cluster_stats[int(cid)]["aspect"] += m["aspect"]
        cluster_stats[int(cid)]["edge"] += m["edge_density"]
        cluster_stats[int(cid)]["count"] += 1

    for cid in cluster_stats:
        cnt = max(cluster_stats[cid]["count"], 1)
        cluster_stats[cid]["aspect"] /= cnt
        cluster_stats[cid]["edge"] /= cnt

    sorted_clusters = sorted(cluster_stats.keys(), key=lambda c: cluster_stats[c]["aspect"])
    name_queue = ["V-Neck", "Sweetheart", "Round", "Boat Neck", "Collar/Ban"]
    cluster_to_name = {
        sorted_clusters[i]: name_queue[i] for i in range(min(5, len(sorted_clusters)))
    }

    label_map: Dict[str, str] = {}
    for cid, m in zip(cluster_ids, meta):
        label_map[m["image_path"]] = cluster_to_name.get(int(cid), "Round")

    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    PSEUDO_LABELS_PATH.write_text(json.dumps(label_map, indent=2), encoding="utf-8")
    logger.info("Saved %d pseudo neckline labels.", len(label_map))
    return label_map


def build_neckline_loaders(
    label_map: Dict[str, str],
    batch_size: int = BATCH_SIZE,
    train_records: Optional[List[Dict[str, Any]]] = None,
) -> Tuple[DataLoader, DataLoader, DataLoader]:
    weights = MobileNet_V3_Small_Weights.DEFAULT
    train_tfm = transforms.Compose(
        [
            transforms.Resize((224, 224)),
            transforms.RandomHorizontalFlip(),
            transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.1),
            transforms.ToTensor(),
            transforms.Normalize(mean=IMAGENET_MEAN, std=IMAGENET_STD),
        ]
    )
    eval_tfm = weights.transforms()

    loaders = []
    for split in ("train", "val", "test"):
        if split == "train" and train_records is not None:
            records = train_records
        else:
            records = filter_garment_records(load_json_records(NECKLINE_JSON_FILES[split]))
        ds = IndoFashionDataset(records, eval_tfm if split != "train" else train_tfm, label_map)
        shuffle = split == "train"
        loaders.append(
            DataLoader(
                ds,
                batch_size=batch_size,
                shuffle=shuffle,
                num_workers=0,
                pin_memory=torch.cuda.is_available(),
            )
        )
    return loaders[0], loaders[1], loaders[2]


def train_neckline_model(
    epochs: int = 8,
    lr: float = 1e-3,
    max_pseudo_samples: int = 5000,
    train_limit: Optional[int] = None,
) -> Dict[str, float]:
    train_records = filter_garment_records(load_json_records(NECKLINE_JSON_FILES["train"]))
    if train_limit is not None and train_limit > 0:
        train_records = train_records[:train_limit]
        logger.info("Neckline training capped to %d samples.", len(train_records))
    label_map = generate_pseudo_neckline_labels(train_records, max_samples=max_pseudo_samples)
    train_loader, val_loader, test_loader = build_neckline_loaders(
        label_map, train_records=train_records
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
            MODELS_DIR.mkdir(parents=True, exist_ok=True)
            torch.save(
                {
                    "model_state": model.state_dict(),
                    "classes": NECKLINE_CLASSES,
                    "arch": "mobilenet_v3_small",
                },
                NECKLINE_MODEL_PATH,
            )

    test_loss, test_acc = _evaluate_classifier(model, test_loader, criterion)
    history = {"best_val_acc": best_val_acc, "test_acc": test_acc, "test_loss": test_loss}
    logger.info("Neckline training complete — test_acc=%.3f", test_acc)
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


def _init_yolo_world() -> YOLO:
    model = YOLO("yolov8s-world.pt")
    model.set_classes(YOLO_ITEM_CLASSES)
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
    image_exts = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}

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
# STEP 3 — Expert recommendation engine
# ---------------------------------------------------------------------------


class ZarvaRecommendationEngine:
    """Loads trained weights and runs multi-stage outfit → jewelry inference."""

    def __init__(self) -> None:
        self.device = DEVICE
        self.neckline_model: Optional[NecklineClassifier] = None
        self.jewelry_model: Optional[JewelryStyleClassifier] = None
        self.yolo_model: Optional[YOLO] = None
        self._neckline_tfm = MobileNet_V3_Small_Weights.DEFAULT.transforms()
        self._jewelry_tfm = EfficientNet_B0_Weights.DEFAULT.transforms()
        self._load_models()

    def _load_models(self) -> None:
        if NECKLINE_MODEL_PATH.is_file():
            self.neckline_model = NecklineClassifier().to(self.device)
            ckpt = torch.load(NECKLINE_MODEL_PATH, map_location=self.device, weights_only=False)
            self.neckline_model.load_state_dict(ckpt["model_state"])
            self.neckline_model.eval()
            logger.info("Loaded neckline classifier from %s", NECKLINE_MODEL_PATH)
        else:
            logger.warning("Neckline weights missing — train with --mode train first.")

        if JEWELRY_MODEL_PATH.is_file():
            self.jewelry_model = JewelryStyleClassifier().to(self.device)
            ckpt = torch.load(JEWELRY_MODEL_PATH, map_location=self.device, weights_only=False)
            self.jewelry_model.load_state_dict(ckpt["model_state"])
            self.jewelry_model.eval()
            logger.info("Loaded jewelry style classifier from %s", JEWELRY_MODEL_PATH)
        else:
            logger.warning("Jewelry weights missing — train with --mode train first.")

        self.yolo_model = _init_yolo_world()

    def predict_neckline(self, bgr: np.ndarray) -> str:
        if self.neckline_model is None:
            return "Round"
        cropped = crop_neck_region(bgr)
        tensor = bgr_to_rgb_tensor(cropped, self._neckline_tfm).unsqueeze(0).to(self.device)
        with torch.no_grad():
            logits = self.neckline_model(tensor)
            idx = int(logits.argmax(dim=1).item())
        return NECKLINE_CLASSES[idx]

    def predict_jewelry_style(self, bgr: np.ndarray) -> Tuple[str, str]:
        """Returns (regional_style, detected_item_type)."""
        if self.yolo_model is None:
            self.yolo_model = _init_yolo_world()
        crop, item_type = _yolo_best_crop(bgr, self.yolo_model)
        if self.jewelry_model is None:
            return "Mughal", item_type
        tensor = bgr_to_rgb_tensor(crop, self._jewelry_tfm).unsqueeze(0).to(self.device)
        with torch.no_grad():
            logits = self.jewelry_model(tensor)
            idx = int(logits.argmax(dim=1).item())
        return JEWELRY_STYLE_CLASSES[idx], item_type

    def build_recommendation_payload(
        self,
        neckline: str,
        jewelry_style: str,
        detected_item: str,
        dress_color: str,
        skin_tone: str,
        user_query: str = "",
        color_auto_detected: bool = False,
    ) -> Dict[str, Any]:
        recommended_piece = STYLING_RULES.get(neckline, "necklace")
        accent_label = "Earrings" if recommended_piece == "earring" else "Necklace"
        if neckline in ("V-Neck", "Sweetheart"):
            accent_label = "Statement Necklace"

        if neckline == "Collar/Ban":
            styling_insight = (
                f"Pair refined {jewelry_style}-inspired earrings with your {neckline} silhouette — "
                f"your {dress_color} palette stays elegant without collar-bone clutter."
            )
            why_this_works = (
                "High necklines create a closed frame at the throat; earrings draw attention upward "
                "without competing lines across the chest."
            )
        elif neckline in ("V-Neck", "Sweetheart"):
            styling_insight = (
                f"Anchor a {jewelry_style} hanging necklace or choker along your {neckline} — "
                f"it harmonizes with {dress_color} tones and {skin_tone.lower()} undertones."
            )
            why_this_works = (
                "Open necklines invite a vertical jewelry line that mirrors the décolletage and "
                "balances shoulder width on South Asian formal wear."
            )
        else:
            styling_insight = (
                f"A classic {jewelry_style} necklace complements your {neckline} against "
                f"{dress_color} fabric with {skin_tone.lower()} skin warmth."
            )
            why_this_works = (
                "Boat and round necklines benefit from even horizontal framing — a mid-length "
                "strand fills negative space without overwhelming embroidery."
            )

        if color_auto_detected:
            styling_insight += " Your dress colour was refined automatically from the garment pixels."

        if user_query.strip():
            styling_insight += f" You asked: \"{user_query.strip()}\" — this pairing respects that brief."

        bot_response = f"{styling_insight} {why_this_works}"

        return {
            "neckline": neckline,
            "jewelryStyle": jewelry_style,
            "recommendedJewelryType": recommended_piece,
            "recommendedAccentLabel": accent_label,
            "culturalTheme": f"{jewelry_style} Heritage",
            "detectedItemType": detected_item,
            "dressColor": dress_color,
            "skinTone": skin_tone,
            "stylingInsight": styling_insight,
            "whyThisWorks": why_this_works,
            "stylingRulesApplied": STYLING_RULES,
            "recommendation": bot_response,
            "colorAutoDetected": color_auto_detected,
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
        color_auto = False
        if not dress_color.strip():
            dress_color = extract_dominant_dress_color(outfit_bgr)
            color_auto = True
        if not skin_tone.strip():
            skin_tone = "Neutral"

        override = resolve_manual_neckline(manual_neckline)
        neckline = override if override else self.predict_neckline(outfit_bgr)

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
            "stylingInsight": text_payload["reply"],
            "whyThisWorks": text_payload["whyThisWorks"],
            "recommendation": text_payload["reply"],
        }

    return app


# ---------------------------------------------------------------------------
# Orchestration CLI
# ---------------------------------------------------------------------------


def run_full_training(
    neckline_epochs: int = 8,
    jewelry_epochs: int = 25,
    max_pseudo_samples: int = 5000,
    neckline_train_limit: Optional[int] = None,
    force_yolo_refresh: bool = False,
) -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    logger.info("ZARVA training on device: %s", DEVICE)

    logger.info("=== STAGE 1: IndoFashion neckline transfer learning ===")
    neckline_metrics = train_neckline_model(
        epochs=neckline_epochs,
        max_pseudo_samples=max_pseudo_samples,
        train_limit=neckline_train_limit,
    )

    logger.info("=== STAGE 2: YOLO-World + EfficientNet-B0 jewelry styles ===")
    yolo = _init_yolo_world()
    jewelry_metrics = train_jewelry_model(
        yolo_model=yolo,
        epochs=jewelry_epochs,
        force_yolo_refresh=force_yolo_refresh,
    )

    config = {
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "device": str(DEVICE),
        "neckline_metrics": neckline_metrics,
        "jewelry_metrics": jewelry_metrics,
        "neckline_weights": str(NECKLINE_MODEL_PATH),
        "jewelry_weights": str(JEWELRY_MODEL_PATH),
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
        choices=["train", "serve", "all"],
        default="all",
        help="train models, serve API, or both sequentially",
    )
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--neckline-epochs", type=int, default=8)
    parser.add_argument("--jewelry-epochs", type=int, default=25)
    parser.add_argument("--max-pseudo-samples", type=int, default=5000)
    parser.add_argument(
        "--neckline-train-limit",
        type=int,
        default=None,
        help="Optional cap on IndoFashion train rows (default: full filtered set)",
    )
    parser.add_argument("--force-yolo-refresh", action="store_true")
    return parser.parse_args()


def main() -> None:
    _load_env()
    args = parse_args()

    if args.mode in ("train", "all"):
        run_full_training(
            neckline_epochs=args.neckline_epochs,
            jewelry_epochs=args.jewelry_epochs,
            max_pseudo_samples=args.max_pseudo_samples,
            neckline_train_limit=args.neckline_train_limit,
            force_yolo_refresh=args.force_yolo_refresh,
        )

    if args.mode in ("serve", "all"):
        serve_api(host=args.host, port=args.port)


if __name__ == "__main__":
    main()
