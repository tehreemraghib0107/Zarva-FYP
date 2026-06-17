import os
import cv2
import numpy as np
import base64

try:
    # pyrefly: ignore [missing-import]
    from rembg import remove
    REMBG_AVAILABLE = True
except ImportError:
    REMBG_AVAILABLE = False

# Clear residual image caching folders on backend startup
try:
    processed_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend", "uploads", "processed"))
    if os.path.exists(processed_dir):
        import shutil
        shutil.rmtree(processed_dir)
        os.makedirs(processed_dir, exist_ok=True)
except Exception as e:
    pass

def trim_transparent_rgba_advanced(rgba: np.ndarray, category: str) -> np.ndarray:
    """
    Crop the RGBA image closely to its non-transparent boundaries.
    For necklaces/chokers, isolates the single largest connected component
    to discard small outlier elements (like matching earrings in margins).
    """
    if len(rgba.shape) < 3 or rgba.shape[2] < 4:
        return rgba
    
    alpha = rgba[:, :, 3]
    cat_lower = category.lower()
    
    if "earring" not in cat_lower:
        # Necklaces / Chokers: Locate the single largest connected component
        contours, _ = cv2.findContours(alpha, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            largest_contour = max(contours, key=cv2.contourArea)
            # Create a clean mask with only the largest component
            clean_alpha = np.zeros_like(alpha)
            cv2.drawContours(clean_alpha, [largest_contour], -1, 255, -1)
            # Apply to alpha channel
            rgba[:, :, 3] = cv2.bitwise_and(alpha, clean_alpha)
            
    # Find the bounding rect of the remaining non-transparent region
    alpha = rgba[:, :, 3]
    coords = cv2.findNonZero(alpha)
    if coords is None:
        return rgba
    x, y, w, h = cv2.boundingRect(coords)
    return rgba[y:y+h, x:x+w]

def bgra_to_data_url(rgba: np.ndarray) -> str:
    """Encode an RGBA/BGRA numpy array into a base64 PNG data URL."""
    ok, buf = cv2.imencode(".png", rgba)
    if not ok:
        raise ValueError("Failed to encode PNG.")
    encoded = base64.b64encode(buf.tobytes()).decode("ascii")
    return f"data:image/png;base64,{encoded}"

def remove_background(img_bgr: np.ndarray) -> np.ndarray:
    """Removes background using rembg (if available) with alpha matting or falls back to GrabCut."""
    if REMBG_AVAILABLE:
        try:
            img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
            # Upgraded matting layer with alpha matting configuration to preserve jewelry edges
            rgba_rgb = remove(
                img_rgb,
                alpha_matting=True,
                alpha_matting_foreground_threshold=240,
                alpha_matting_background_threshold=10,
                alpha_matting_erode_size=10
            )
            return cv2.cvtColor(rgba_rgb, cv2.COLOR_RGBA2BGRA)
        except Exception:
            pass  # Fall through to GrabCut if rembg fails at runtime
            
    # Fallback: Advanced Thresholding / GrabCut background removal
    h, w = img_bgr.shape[:2]
    rgba = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2BGRA)

    mask = np.zeros((h, w), np.uint8)
    bgd_model = np.zeros((1, 65), np.float64)
    fgd_model = np.zeros((1, 65), np.float64)
    margin = max(4, min(h, w) // 16)
    rect = (margin, margin, max(1, w - 2 * margin), max(1, h - 2 * margin))
    try:
        cv2.grabCut(img_bgr, mask, rect, bgd_model, fgd_model, 4, cv2.GC_INIT_WITH_RECT)
        fg_mask = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    except cv2.error:
        fg_mask = np.full((h, w), 255, dtype=np.uint8)

    # Threshold solid white backgrounds (luminance thresholding)
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    _, light_mask = cv2.threshold(gray, 235, 255, cv2.THRESH_BINARY)
    light_mask = cv2.GaussianBlur(light_mask, (5, 5), 0)
    combined = cv2.bitwise_and(fg_mask, cv2.bitwise_not(light_mask))

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    combined = cv2.morphologyEx(combined, cv2.MORPH_CLOSE, kernel, iterations=2)
    combined = cv2.morphologyEx(combined, cv2.MORPH_OPEN, kernel, iterations=1)

    rgba[:, :, 3] = combined
    return rgba

def prepare_ar_asset(image_path: str, category: str) -> dict:
    """
    Process any product image on-the-fly and return isolated transparent assets.
    Implements cache checks to ensure clean asset cache handling.
    """
    try:
        if not os.path.exists(image_path):
            return {"success": False, "error": f"Input image not found: {image_path}"}

        # Determine paths and directories
        dir_name = os.path.dirname(image_path)
        filename = os.path.basename(image_path)
        name_no_ext, _ = os.path.splitext(filename)
        
        # Clean asset cache handling
        cache_dir = os.path.join(dir_name, "processed", name_no_ext)
        cat_lower = category.lower()
        
        if "earring" in cat_lower:
            left_path = os.path.join(cache_dir, "left_earring.png")
            right_path = os.path.join(cache_dir, "right_earring.png")
            
            # Check cache
            if os.path.exists(left_path) and os.path.exists(right_path):
                rgba_bgra = cv2.imread(left_path, cv2.IMREAD_UNCHANGED)
                if rgba_bgra is not None and len(rgba_bgra.shape) == 3 and rgba_bgra.shape[2] == 4:
                    data_url = bgra_to_data_url(rgba_bgra)
                    return {
                        "success": True,
                        "category": "Earrings",
                        "paths": [left_path, right_path],
                        "leftEarringPath": left_path,
                        "rightEarringPath": right_path,
                        "overlayDataUrl": data_url,
                        "leftEarringDataUrl": data_url,
                        "rightEarringDataUrl": data_url,
                        "width": rgba_bgra.shape[1],
                        "height": rgba_bgra.shape[0],
                        "cached": True
                    }

            # Cache miss, process the image
            img = cv2.imread(image_path)
            if img is None:
                return {"success": False, "error": f"Failed to read image: {image_path}"}
                
            h, w = img.shape[:2]
            # Since earring catalog items are uploaded as a side-by-side pair,
            # calculate the horizontal midpoint, slice the image in half to extract exactly one.
            mid_x = w // 2
            one_earring_bgr = img[:, :mid_x]
            
            # Strip background
            rgba_bgra = remove_background(one_earring_bgr)
            rgba_bgra = trim_transparent_rgba_advanced(rgba_bgra, category)
            
            # Ensure cache dir exists
            os.makedirs(cache_dir, exist_ok=True)
            
            # Save duplicated paths
            cv2.imwrite(left_path, rgba_bgra)
            cv2.imwrite(right_path, rgba_bgra)
            
            data_url = bgra_to_data_url(rgba_bgra)
            return {
                "success": True,
                "category": "Earrings",
                "paths": [left_path, right_path],
                "leftEarringPath": left_path,
                "rightEarringPath": right_path,
                "overlayDataUrl": data_url,
                "leftEarringDataUrl": data_url,
                "rightEarringDataUrl": data_url,
                "width": rgba_bgra.shape[1],
                "height": rgba_bgra.shape[0],
                "cached": False
            }
        else:
            # Necklaces / Chokers or default
            necklace_path = os.path.join(cache_dir, "necklace.png")
            
            # Check cache
            if os.path.exists(necklace_path):
                rgba_bgra = cv2.imread(necklace_path, cv2.IMREAD_UNCHANGED)
                if rgba_bgra is not None and len(rgba_bgra.shape) == 3 and rgba_bgra.shape[2] == 4:
                    data_url = bgra_to_data_url(rgba_bgra)
                    return {
                        "success": True,
                        "category": category,
                        "paths": [necklace_path],
                        "necklacePath": necklace_path,
                        "overlayDataUrl": data_url,
                        "width": rgba_bgra.shape[1],
                        "height": rgba_bgra.shape[0],
                        "cached": True
                    }

            # Cache miss, process the image
            img = cv2.imread(image_path)
            if img is None:
                return {"success": False, "error": f"Failed to read image: {image_path}"}
                
            # Strip background
            rgba_bgra = remove_background(img)
            rgba_bgra = trim_transparent_rgba_advanced(rgba_bgra, category)
            
            # Ensure cache dir exists
            os.makedirs(cache_dir, exist_ok=True)
            
            # Save path
            cv2.imwrite(necklace_path, rgba_bgra)
            
            data_url = bgra_to_data_url(rgba_bgra)
            return {
                "success": True,
                "category": category,
                "paths": [necklace_path],
                "necklacePath": necklace_path,
                "overlayDataUrl": data_url,
                "width": rgba_bgra.shape[1],
                "height": rgba_bgra.shape[0],
                "cached": False
            }
    except Exception as e:
        return {"success": False, "error": str(e)}
