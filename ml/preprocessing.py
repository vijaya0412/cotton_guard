"""Authoritative Preprocessing Pipeline for Cotton Guard.
Shared consistently between training, ONNX export, and production inference.
Applies CIELAB conversion, CLAHE on L-channel, and standard ImageNet normalization.
"""

from typing import Union, Tuple
from PIL import Image
import numpy as np
import cv2

# Canonical constants
DEFAULT_IMAGE_SIZE = (224, 224)
IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)
CLAHE_CLIP_LIMIT = 2.0
CLAHE_TILE_GRID_SIZE = (8, 8)


def apply_cielab_clahe(
    rgb_image: np.ndarray,
    clip_limit: float = CLAHE_CLIP_LIMIT,
    tile_grid_size: Tuple[int, int] = CLAHE_TILE_GRID_SIZE
) -> np.ndarray:
    """
    Converts RGB uint8 image to CIELAB, applies CLAHE to the Luminance (L) channel,
    and converts back to RGB uint8.
    """
    if rgb_image.dtype != np.uint8:
        rgb_image = np.clip(rgb_image, 0, 255).astype(np.uint8)

    lab = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=clip_limit, tileGridSize=tile_grid_size)
    cl = clahe.apply(l)
    enhanced_lab = cv2.merge((cl, a, b))
    enhanced_rgb = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2RGB)
    return enhanced_rgb


def preprocess_image(
    image: Union[Image.Image, np.ndarray],
    target_size: Tuple[int, int] = DEFAULT_IMAGE_SIZE,
    enable_clahe: bool = True,
    layout: str = "NCHW",
    clip_limit: float = CLAHE_CLIP_LIMIT,
    tile_grid_size: Tuple[int, int] = CLAHE_TILE_GRID_SIZE
) -> np.ndarray:
    """
    Authoritative preprocessing pipeline:
    1. Ensures RGB format.
    2. Resizes to target_size (224, 224) via bilinear interpolation.
    3. (Optional) Applies CIELAB + CLAHE on L-channel.
    4. Scales pixels to [0.0, 1.0].
    5. Normalizes by ImageNet mean and std.
    6. Formats to specified layout ('NCHW' or 'NHWC') with batch dimension.

    Returns float32 ndarray with shape:
      - (1, 3, H, W) if layout == 'NCHW'
      - (1, H, W, 3) if layout == 'NHWC'
    """
    # 1. Convert to RGB PIL Image if needed
    if isinstance(image, np.ndarray):
        if image.ndim == 2:
            image = cv2.cvtColor(image, cv2.COLOR_GRAY2RGB)
        elif image.ndim == 3 and image.shape[2] == 4:
            image = cv2.cvtColor(image, cv2.COLOR_RGBA2RGB)
        pil_img = Image.fromarray(image.astype(np.uint8))
    else:
        pil_img = image.convert("RGB")

    # 2. Resize
    resized = pil_img.resize(target_size, Image.Resampling.BILINEAR)
    np_img = np.array(resized, dtype=np.uint8)

    # 3. Hybrid CIELAB + CLAHE
    if enable_clahe:
        enhanced = apply_cielab_clahe(np_img, clip_limit=clip_limit, tile_grid_size=tile_grid_size)
    else:
        enhanced = np_img

    # 4 & 5. Normalization [0, 1] -> (x - mean) / std
    arr = enhanced.astype(np.float32) / 255.0
    normalized = (arr - IMAGENET_MEAN) / IMAGENET_STD

    # 6. Tensor Layout Formatting
    if layout.upper() == "NCHW":
        transposed = np.transpose(normalized, (2, 0, 1))
        batched = np.expand_dims(transposed, axis=0)
    elif layout.upper() == "NHWC":
        batched = np.expand_dims(normalized, axis=0)
    else:
        raise ValueError(f"Unsupported layout: {layout}. Expected 'NCHW' or 'NHWC'.")

    return batched.astype(np.float32)
