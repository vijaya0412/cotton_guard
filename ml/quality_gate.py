"""Image Quality and Cotton Leaf Validation Gate for Cotton Guard."""

import math
from typing import Dict, Any, Tuple
from PIL import Image
import numpy as np

class ImageQualityGate:
    """Evaluates image suitability: resolution, blur, exposure, and leaf/foliage presence."""

    MIN_WIDTH = 150
    MIN_HEIGHT = 150
    MIN_BLUR_SCORE = 15.0  # Variance of Laplacian approximation / high frequencies
    MIN_BRIGHTNESS = 30.0  # 0-255 scale
    MAX_BRIGHTNESS = 245.0 # 0-255 scale
    MIN_FOLIAGE_FRACTION = 0.12 # Minimum percentage of leaf/chlorophyll/foliage pigmentation

    @classmethod
    def evaluate_image(cls, image: Image.Image) -> Dict[str, Any]:
        """
        Runs comprehensive image quality and cotton leaf botanical validation.
        Returns:
            {
                "quality_passed": bool,
                "is_cotton_leaf": bool,
                "status": "VALID" | "POOR_QUALITY" | "NON_COTTON",
                "message": str,
                "metrics": {
                    "width": int,
                    "height": int,
                    "brightness": float,
                    "blur_score": float,
                    "foliage_ratio": float
                }
            }
        """
        rgb_image = image.convert("RGB")
        w, h = rgb_image.size

        # 1. Dimension Check
        if w < cls.MIN_WIDTH or h < cls.MIN_HEIGHT:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": f"Image resolution ({w}x{h}) is too low. Please provide an image with at least {cls.MIN_WIDTH}x{cls.MIN_HEIGHT} pixels.",
                "metrics": {"width": w, "height": h, "brightness": 0.0, "blur_score": 0.0, "foliage_ratio": 0.0}
            }

        # Convert to numpy array
        np_img = np.array(rgb_image, dtype=np.float32)
        r, g, b = np_img[:, :, 0], np_img[:, :, 1], np_img[:, :, 2]

        # 2. Brightness / Exposure Check (Perceived Luminance)
        luminance = 0.299 * r + 0.587 * g + 0.114 * b
        mean_brightness = float(np.mean(luminance))

        if mean_brightness < cls.MIN_BRIGHTNESS:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": "Image is too dark or underexposed. Please capture the cotton leaf under adequate ambient light.",
                "metrics": {"width": w, "height": h, "brightness": round(mean_brightness, 2), "blur_score": 0.0, "foliage_ratio": 0.0}
            }

        if mean_brightness > cls.MAX_BRIGHTNESS:
            return {
                "quality_passed": False,
                "is_cotton_leaf": False,
                "status": "POOR_QUALITY",
                "message": "Image is heavily overexposed or washed out. Please avoid direct harsh glare when capturing the leaf.",
                "metrics": {"width": w, "height": h, "brightness": round(mean_brightness, 2), "blur_score": 0.0, "foliage_ratio": 0.0}
            }

        # 3. Blur / Sharpness Check using Discrete Laplacian Approximation
        # Downsample for consistent scale if huge
        if max(w, h) > 600:
            scale = 600.0 / max(w, h)
            scaled_w, scaled_h = max(1, int(w * scale)), max(1, int(h * scale))
            small_lum = np.array(Image.fromarray(luminance.astype(np.uint8)).resize((scaled_w, scaled_h), Image.Resampling.BILINEAR), dtype=np.float32)
        else:
            small_lum = luminance

        # Approximate 2D Laplacian operator [ [0, 1, 0], [1, -4, 1], [0, 1, 0] ]
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
                "message": "Image is too blurry or out of focus. Hold the camera steady and focus clearly on the leaf surface.",
                "metrics": {
                    "width": w,
                    "height": h,
                    "brightness": round(mean_brightness, 2),
                    "blur_score": round(blur_score, 2),
                    "foliage_ratio": 0.0
                }
            }

        # 4. Cotton Foliage / Botanical Gate
        # Cotton leaves naturally display plant chlorophyll tones, yellowing/chlorosis, reddish anthocyanin, or necrotic brown leaf tissue.
        # Synthetic non-cotton objects (monochrome grey metal, text on white paper, solid blue screens, skin tones without plant structure) fail this gate.
        hsv_image = rgb_image.convert("HSV")
        np_hsv = np.array(hsv_image, dtype=np.float32)
        h_chan, s_chan, v_chan = np_hsv[:, :, 0], np_hsv[:, :, 1], np_hsv[:, :, 2]

        # Normalized Hue: 0-255 in PIL HSV
        # Green plant range: 35 to 110 (Hue ~50° to 155°)
        # Yellow/disease range: 15 to 45 (Hue ~21° to 63°)
        # Reddening range: 0 to 18 and 235 to 255 with saturation > 40
        # Brown necrotic spots: Hue 10 to 35 with moderate saturation
        plant_mask = (
            # Green foliage
            ((h_chan >= 30) & (h_chan <= 115) & (s_chan > 35) & (v_chan > 25)) |
            # Yellow / chlorotic / jassid edge damage
            ((h_chan >= 15) & (h_chan < 30) & (s_chan > 40) & (v_chan > 30)) |
            # Leaf reddening / anthocyanin
            (((h_chan < 15) | (h_chan > 230)) & (s_chan > 45) & (v_chan > 25))
        )
        foliage_pixels = np.sum(plant_mask)
        total_pixels = w * h
        foliage_ratio = float(foliage_pixels / total_pixels)

        # Non-cotton rejection check
        if foliage_ratio < cls.MIN_FOLIAGE_FRACTION:
            return {
                "quality_passed": True,
                "is_cotton_leaf": False,
                "status": "NON_COTTON",
                "message": "This image does not appear to contain a cotton leaf. Please frame a clear cotton leaf within the viewfinder.",
                "metrics": {
                    "width": w,
                    "height": h,
                    "brightness": round(mean_brightness, 2),
                    "blur_score": round(blur_score, 2),
                    "foliage_ratio": round(foliage_ratio, 4)
                }
            }

        # Passed all gates
        return {
            "quality_passed": True,
            "is_cotton_leaf": True,
            "status": "VALID",
            "message": "Image quality and cotton leaf botanical verification passed.",
            "metrics": {
                "width": w,
                "height": h,
                "brightness": round(mean_brightness, 2),
                "blur_score": round(blur_score, 2),
                "foliage_ratio": round(foliage_ratio, 4)
            }
        }
