"""Preprocess service (Figure H-1 backend box): Crop, Deskew, Denoise,
Binarize, Resize. Runs before the OCR layer, per the sequence diagram
(Figure H-6: validateAndCrop -> deskew * denoise * binarize * resize(384x384)).
"""

from __future__ import annotations

import cv2
import numpy as np


TARGET_SIZE = (384, 384)  # matches Figure H-6: resize(384 x 384 px)


def crop_answer_box(image: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray:
    """Crop to the answer-box region located by the exam template
    (Figure 3 source: "cropped answer box, 384x384")."""
    x, y, w, h = box
    return image[y : y + h, x : x + w]


def deskew(image: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if image.ndim == 3 else image
    coords = np.column_stack(np.where(gray < 255))
    if coords.size == 0:
        return image
    angle = cv2.minAreaRect(coords)[-1]
    angle = -(90 + angle) if angle < -45 else -angle
    (h, w) = image.shape[:2]
    center = (w // 2, h // 2)
    matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
    return cv2.warpAffine(
        image, matrix, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE
    )


def denoise(image: np.ndarray) -> np.ndarray:
    return cv2.fastNlMeansDenoising(image, h=10) if image.ndim == 2 else cv2.fastNlMeansDenoisingColored(image)


def binarize(image: np.ndarray) -> np.ndarray:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if image.ndim == 3 else image
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return binary


def resize(image: np.ndarray, size: tuple[int, int] = TARGET_SIZE) -> np.ndarray:
    return cv2.resize(image, size, interpolation=cv2.INTER_AREA)


def run_pipeline(image: np.ndarray, crop_box: tuple[int, int, int, int] | None = None) -> np.ndarray:
    """Full preprocessing pipeline in the order specified by Figure H-6:
    crop -> deskew -> denoise -> binarize -> resize."""
    if crop_box is not None:
        image = crop_answer_box(image, crop_box)
    image = deskew(image)
    image = denoise(image)
    image = binarize(image)
    image = resize(image)
    return image
