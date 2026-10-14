"""Multi-Stage Input Validation, Image Quality, and Cotton-Leaf Domain Gate.
Implements:
  Stage 1: Input & Byte Validation (size, dimension, corruption)
  Stage 2: Photometric Quality (exposure, blur/sharpness)
  Stage 3: Botanical Foliage & Cotton-Domain Screening (color distribution, leaf texture, non-plant rejection)
  Stage 4: Prediction Uncertainty Evaluation (confidence calibration & margin thresholds)
"""

import io
from typing import Dict, Any, Tuple, Optional
from PIL import Image
import numpy as np
import cv2
from ml.cotton_domain_classifier import classify_cotton

class CottonDomainGate:
    """Multi-stage validation and domain gating engine for Cotton Guard."""

    # Stage 1 Limits
    MIN_FILE_SIZE_BYTES = 200          # Min 200 bytes
    MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024  # Max 15 MB
    MIN_DIMENSION = 150
    MAX_DIMENSION = 8192

    # Stage 2 Quality Thresholds
    MIN_BRIGHTNESS = 30.0   # 0-255 scale
    MAX_BRIGHTNESS = 245.0  # 0-255 scale
    MIN_BLUR_SCORE = 15.0   # Laplacian variance

    # Stage 3 Domain Thresholds
    MIN_FOLIAGE_RATIO = 0.15  # Minimum 15% leaf/foliage pixels in field frame
    MIN_TEXTURE_ENERGY = 10.0 # Rejects flat artificial uniform color surfaces

    # Stage 4 Uncertainty Thresholds
    LOW_CONFIDENCE_THRESHOLD = 0.70  # Below this, flag as low confidence
    UNCERTAINTY_MARGIN = 0.12        # Top-1 vs Top-2 probability margin

    @classmethod
    def validate_file_payload(cls, file_bytes: bytes, filename: str = "") -> Tuple[bool, Optional[str], Optional[Image.Image]]:
        """
        Stage 1: Verifies byte size, header, and decodes the image safely.
        Returns: (success, error_message, pil_image)
        """
        byte_len = len(file_bytes)
        if byte_len < cls.MIN_FILE_SIZE_BYTES:
            return False, f"Uploaded file is empty or too small ({byte_len} bytes). Please provide a valid leaf image.", None

        if byte_len > cls.MAX_FILE_SIZE_BYTES:
            return False, f"Uploaded image exceeds maximum allowable limit of 15 MB ({byte_len / (1024*1024):.1f} MB).", None

        # Verify extension if filename provided
        if filename:
            ext = filename.lower().split(".")[-1]
            if ext not in ["jpg", "jpeg", "png", "webp"]:
                return False, f"Unsupported image extension '.{ext}'. Supported formats: JPEG, PNG, WEBP.", None

        # Safe decode
        try:
            image = Image.open(io.BytesIO(file_bytes))
            image.load() # Verify decompression without truncated data errors
        except Exception as e:
            return False, f"Malformed or corrupted image file: {str(e)}", None

        # Verify format
        fmt = (image.format or "").upper()
        if fmt not in ["JPEG", "PNG", "WEBP", "MPO"]:
            return False, f"Unsupported decoded format: '{fmt}'. Please upload JPEG, PNG, or WEBP.", None

        return True, None, image

    @classmethod
    def evaluate_quality_and_domain(cls, image: Image.Image) -> Dict[str, Any]:
        """
        Stages 2 & 3: Evaluates resolution, exposure, blur, and botanical leaf domain characteristics.
        """
        rgb_image = image.convert("RGB")
        w, h = rgb_image.size

        # 1. Dimension Check
        if w < cls.MIN_DIMENSION or h < cls.MIN_DIMENSION:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": f"Image resolution ({w}x{h}) is too low. Required minimum is {cls.MIN_DIMENSION}x{cls.MIN_DIMENSION} pixels.",
                "metrics": {"width": w, "height": h, "brightness": 0.0, "blur_score": 0.0, "foliage_ratio": 0.0}
            }

        if w > cls.MAX_DIMENSION or h > cls.MAX_DIMENSION:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": f"Image dimension ({w}x{h}) exceeds system limit of {cls.MAX_DIMENSION}x{cls.MAX_DIMENSION}.",
                "metrics": {"width": w, "height": h, "brightness": 0.0, "blur_score": 0.0, "foliage_ratio": 0.0}
            }

        np_img = np.array(rgb_image, dtype=np.float32)
        r, g, b = np_img[:, :, 0], np_img[:, :, 1], np_img[:, :, 2]

        # 2. Brightness Check
        luminance = 0.299 * r + 0.587 * g + 0.114 * b
        mean_brightness = float(np.mean(luminance))

        if mean_brightness < cls.MIN_BRIGHTNESS:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": f"Image is too dark or underexposed (brightness: {mean_brightness:.1f}/255). Please capture under adequate ambient daylight.",
                "metrics": {"width": w, "height": h, "brightness": round(mean_brightness, 2), "blur_score": 0.0, "foliage_ratio": 0.0}
            }

        if mean_brightness > cls.MAX_BRIGHTNESS:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": f"Image is washed out or overexposed (brightness: {mean_brightness:.1f}/255). Avoid direct camera flash glare on the leaf.",
                "metrics": {"width": w, "height": h, "brightness": round(mean_brightness, 2), "blur_score": 0.0, "foliage_ratio": 0.0}
            }

        # 3. Blur / Sharpness Check
        if max(w, h) > 600:
            scale = 600.0 / max(w, h)
            scaled_w, scaled_h = max(1, int(w * scale)), max(1, int(h * scale))
            small_lum = np.array(Image.fromarray(luminance.astype(np.uint8)).resize((scaled_w, scaled_h), Image.Resampling.BILINEAR), dtype=np.float32)
        else:
            small_lum = luminance

        padded = np.pad(small_lum, 1, mode='reflect')
        laplacian = (
            padded[0:-2, 1:-1] +
            padded[2:, 1:-1] +
            padded[1:-1, 0:-2] +
            padded[1:-1, 2:] -
            4.0 * small_lum
        )
        blur_score = float(np.var(laplacian))

        if blur_score < cls.MIN_BLUR_SCORE:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": f"Image is out of focus or blurry (sharpness score: {blur_score:.1f}). Hold camera steady and tap to focus on the leaf.",
                "metrics": {
                    "width": w,
                    "height": h,
                    "brightness": round(mean_brightness, 2),
                    "blur_score": round(blur_score, 2),
                    "foliage_ratio": 0.0
                }
            }

        # 4. Botanical Foliage & Cotton-Domain Check
        hsv_image = rgb_image.convert("HSV")
        np_hsv = np.array(hsv_image, dtype=np.float32)
        h_chan, s_chan, v_chan = np_hsv[:, :, 0], np_hsv[:, :, 1], np_hsv[:, :, 2]

        # Multi-chromatic cotton foliage mask:
        # Green chlorophyll: Hue 30-115, Sat > 35, Val > 25
        # Yellow chlorosis / jassid margin burn: Hue 15-30, Sat > 35, Val > 30
        # Reddening / anthocyanosis: Hue < 15 or > 230, Sat > 40, Val > 25
        # Necrotic brown lesions: Hue 10-25, Sat 25-180, Val 20-150
        plant_foliage_mask = (
            ((h_chan >= 30) & (h_chan <= 115) & (s_chan > 35) & (v_chan > 25)) |
            ((h_chan >= 15) & (h_chan < 30) & (s_chan > 35) & (v_chan > 30)) |
            (((h_chan < 15) | (h_chan > 230)) & (s_chan > 40) & (v_chan > 25)) |
            ((h_chan >= 10) & (h_chan <= 25) & (s_chan >= 25) & (s_chan <= 180) & (v_chan >= 20) & (v_chan <= 150))
        )

        foliage_pixels = np.sum(plant_foliage_mask)
        total_pixels = w * h
        foliage_ratio = float(foliage_pixels / total_pixels)

        # Texture energy on leaf foliage area
        texture_energy = float(np.std(luminance[plant_foliage_mask])) if foliage_pixels > 100 else 0.0

        if foliage_ratio < cls.MIN_FOLIAGE_RATIO:
            return {
                "quality_passed": True,
                "is_cotton_leaf": False,
                "status": "NON_COTTON",
                "message": f"Non-plant or unsupported input detected (foliage coverage {foliage_ratio*100:.1f}% < {cls.MIN_FOLIAGE_RATIO*100:.0f}%). Please center a cotton leaf within the frame.",
                "metrics": {
                    "width": w,
                    "height": h,
                    "brightness": round(mean_brightness, 2),
                    "blur_score": round(blur_score, 2),
                    "foliage_ratio": round(foliage_ratio, 4)
                }
            }

        if texture_energy < cls.MIN_TEXTURE_ENERGY:
            return {
                "quality_passed": True,
                "is_cotton_leaf": False,
                "status": "NON_COTTON",
                "message": "Uniform synthetic or non-biological texture detected. Please provide an authentic leaf photograph.",
                "metrics": {
                    "width": w,
                    "height": h,
                    "brightness": round(mean_brightness, 2),
                    "blur_score": round(blur_score, 2),
                    "foliage_ratio": round(foliage_ratio, 4)
                }
            }

        # A dedicated binary classifier is the only stage intended to distinguish
        # cotton from other real plant species. The seven-class disease model stays
        # unchanged. Until its artifact is trained/installed, retain legacy behavior.
        is_cotton, domain_message = classify_cotton(rgb_image)
        if not is_cotton:
            return {
                "quality_passed": True,
                "is_cotton_leaf": False,
                "status": "NON_COTTON",
                "message": domain_message,
                "metrics": {
                    "width": w,
                    "height": h,
                    "brightness": round(mean_brightness, 2),
                    "blur_score": round(blur_score, 2),
                    "foliage_ratio": round(foliage_ratio, 4)
                }
            }

        return {
            "quality_passed": True,
            "is_cotton_leaf": True,
            "status": "VALID",
            "message": domain_message if "classifier passed" in domain_message else "Image quality and cotton leaf botanical checks passed.",
            "metrics": {
                "width": w,
                "height": h,
                "brightness": round(mean_brightness, 2),
                "blur_score": round(blur_score, 2),
                "foliage_ratio": round(foliage_ratio, 4)
            }
        }

    @classmethod
    def evaluate_prediction_uncertainty(
        cls,
        probabilities: np.ndarray
    ) -> Tuple[bool, str]:
        """
        Stage 4: Evaluates prediction confidence and margin between top classes.
        Returns: (is_uncertain, reason_message)
        """
        sorted_probs = np.sort(probabilities)[::-1]
        top1 = float(sorted_probs[0])
        top2 = float(sorted_probs[1]) if len(sorted_probs) > 1 else 0.0
        margin = top1 - top2

        if top1 < cls.LOW_CONFIDENCE_THRESHOLD:
            return True, f"Prediction confidence ({top1*100:.1f}%) is below reliable certainty threshold ({cls.LOW_CONFIDENCE_THRESHOLD*100:.0f}%)."

        if margin < cls.UNCERTAINTY_MARGIN:
            return True, f"Ambiguous symptoms: Top diagnosis ({top1*100:.1f}%) and second candidate ({top2*100:.1f}%) are too close (margin: {margin*100:.1f}%)."

        return False, "Prediction is confident and well-separated."
