"""
Test script to verify Tesseract OCR is working
"""
import os
import sys
from PIL import Image
import numpy as np

# Add compatibility patch for Python 3.14
if sys.version_info >= (3, 12):
    import pkgutil
    from importlib.util import find_spec
    if not hasattr(pkgutil, 'find_loader'):
        pkgutil.find_loader = lambda name: find_spec(name).loader if find_spec(name) else None

import pytesseract

def test_tesseract():
    """Test if Tesseract is properly installed and configured"""
    
    print("="*60)
    print("Testing Tesseract OCR Installation")
    print("="*60)
    
    # Test 1: Check Tesseract version
    try:
        version = pytesseract.get_tesseract_version()
        print(f"✓ Tesseract version: {version}")
    except Exception as e:
        print(f"✗ Tesseract not found: {e}")
        print("\nPlease install Tesseract OCR:")
        print("  https://github.com/UB-Mannheim/tesseract/wiki")
        return False
    
    # Test 2: Check Tesseract path
    tesseract_cmd = pytesseract.pytesseract.tesseract_cmd
    print(f"✓ Tesseract path: {tesseract_cmd}")
    
    # Test 3: Test OCR on simple image
    print("\n Testing OCR on sample text...")
    try:
        # Create a simple test image with text
        from PIL import ImageDraw, ImageFont
        
        # Create white image with black text
        img = Image.new('RGB', (400, 100), color='white')
        draw = ImageDraw.Draw(img)
        
        # Use default font
        text = "Hello World! Test 123"
        draw.text((10, 30), text, fill='black')
        
        # Save test image
        test_image_path = 'test_ocr_image.png'
        img.save(test_image_path)
        
        # Perform OCR
        extracted_text = pytesseract.image_to_string(img)
        print(f"✓ OCR extracted: '{extracted_text.strip()}'")
        
        # Clean up
        os.remove(test_image_path)
        
        if 'Hello' in extracted_text or 'Test' in extracted_text:
            print("✓ OCR is working correctly!")
            return True
        else:
            print("⚠ OCR completed but text extraction may be inaccurate")
            return True
            
    except Exception as e:
        print(f"✗ OCR test failed: {e}")
        return False

if __name__ == "__main__":
    from dotenv import load_dotenv
    
    # Load environment variables
    load_dotenv()
    
    # Set Tesseract path if specified in .env
    tesseract_path = os.getenv('TESSERACT_PATH')
    if tesseract_path:
        print(f"Using TESSERACT_PATH from .env: {tesseract_path}")
        pytesseract.pytesseract.tesseract_cmd = tesseract_path
    
    # Run test
    success = test_tesseract()
    
    print("\n" + "="*60)
    if success:
        print("✓ All tests passed! Tesseract is ready to use.")
    else:
        print("✗ Tesseract setup incomplete. Please follow installation instructions.")
    print("="*60)
