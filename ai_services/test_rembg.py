import cv2
import numpy as np
import os
import sys

try:
    from rembg import remove
    print("Successfully imported rembg.remove!")
except Exception as e:
    print(f"Error importing rembg: {e}")
    sys.exit(1)

# Find a test image
upload_dir = r"e:\Zarva FYP\backend\uploads"
images = [f for f in os.listdir(upload_dir) if f.endswith(('.png', '.jpg', '.jpeg'))]

if not images:
    print("No test images found in backend/uploads.")
    sys.exit(0)

input_path = os.path.join(upload_dir, images[0])
print(f"Using test image: {input_path}")

try:
    bgr = cv2.imread(input_path)
    if bgr is None:
        print("Failed to read image.")
        sys.exit(1)

    print("Running background removal...")
    # Convert BGR to RGBA for rembg
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    output_rgb = remove(rgb)
    
    # Convert back to BGRA to save
    output_bgra = cv2.cvtColor(output_rgb, cv2.COLOR_RGBA2BGRA)
    
    out_path = os.path.join(upload_dir, "test_rembg_output.png")
    cv2.imwrite(out_path, output_bgra)
    print(f"Success! Output saved to: {out_path}")
except Exception as e:
    print(f"Execution failed: {e}")
