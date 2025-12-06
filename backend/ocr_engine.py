"""
OCR Engine Module
Handles text extraction from images and PDF documents using Tesseract OCR
"""

import os
import sys
from PIL import Image
from pdf2image import convert_from_path
import cv2
import numpy as np

# Python 3.14 compatibility patch for pytesseract
if sys.version_info >= (3, 12):
    import pkgutil
    from importlib.util import find_spec
    if not hasattr(pkgutil, 'find_loader'):
        pkgutil.find_loader = lambda name: find_spec(name).loader if find_spec(name) else None

import pytesseract


class OCREngine:
    """OCR Engine for extracting text from documents"""
    
    def __init__(self):
        """Initialize OCR engine with configuration"""
        # Set Tesseract path if specified in environment
        tesseract_path = os.getenv('TESSERACT_PATH')
        if tesseract_path:
            pytesseract.pytesseract.tesseract_cmd = tesseract_path
        
        self.ocr_language = os.getenv('OCR_LANGUAGE', 'eng')
        
    def preprocess_image(self, image_path):
        """
        Preprocess image for better OCR results
        - Convert to grayscale
        - Apply thresholding
        - Denoise
        """
        try:
            # Read image
            img = cv2.imread(image_path)
            if img is None:
                raise ValueError(f"Could not read image at path: {image_path}")

            # Convert to grayscale
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            # Optional histogram equalization to improve contrast
            try:
                gray = cv2.equalizeHist(gray)
            except Exception as eq_error:
                print(f"Histogram equalization failed, continuing without it: {eq_error}")

            # Global Otsu thresholding (more conservative than aggressive adaptive schemes)
            _, thresh = cv2.threshold(
                gray,
                0,
                255,
                cv2.THRESH_BINARY + cv2.THRESH_OTSU,
            )

            # Denoise while preserving thin lines and text strokes
            denoised = cv2.fastNlMeansDenoising(thresh, None, 10, 7, 21)

            return denoised
            
        except Exception as e:
            print(f"Error preprocessing image: {str(e)}")
            # Return original image if preprocessing fails
            return cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    
    def _ocr_text_and_conf(self, img_np, config):
        try:
            pil = Image.fromarray(img_np)
            data = pytesseract.image_to_data(
                pil,
                lang=self.ocr_language,
                config=config,
                output_type=pytesseract.Output.DICT,
            )
            words = [w for w in data.get('text', []) if isinstance(w, str) and w.strip()]
            confs_raw = data.get('conf', [])
            confs = []
            for c in confs_raw:
                try:
                    ci = int(c)
                    if ci >= 0:
                        confs.append(ci)
                except Exception:
                    pass
            median_conf = float(np.median(confs)) if confs else 0.0
            text = " ".join(words).strip()
            if not text:
                text = pytesseract.image_to_string(pil, lang=self.ocr_language, config=config).strip()
            return text, median_conf
        except Exception:
            try:
                pil = Image.fromarray(img_np)
                text = pytesseract.image_to_string(pil, lang=self.ocr_language, config=config).strip()
                return text, 0.0
            except Exception:
                return "", 0.0
    
    def _crop_to_content(self, gray_img):
        try:
            _, th = cv2.threshold(gray_img, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            inv = cv2.bitwise_not(th)
            coords = cv2.findNonZero(inv)
            if coords is None:
                return gray_img
            x, y, w, h = cv2.boundingRect(coords)
            pad_w = max(4, int(0.02 * gray_img.shape[1]))
            pad_h = max(4, int(0.02 * gray_img.shape[0]))
            x = max(0, x - pad_w)
            y = max(0, y - pad_h)
            w = min(gray_img.shape[1] - x, w + 2 * pad_w)
            h = min(gray_img.shape[0] - y, h + 2 * pad_h)
            return gray_img[y:y + h, x:x + w]
        except Exception:
            return gray_img

    def _remove_lines(self, bin_img):
        try:
            inv = cv2.bitwise_not(bin_img)
            h, w = bin_img.shape[:2]
            h_ker = max(10, w // 40)
            v_ker = max(10, h // 40)
            horiz_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (h_ker, 1))
            vert_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, v_ker))
            h_lines = cv2.morphologyEx(inv, cv2.MORPH_OPEN, horiz_kernel, iterations=1)
            v_lines = cv2.morphologyEx(inv, cv2.MORPH_OPEN, vert_kernel, iterations=1)
            lines = cv2.bitwise_or(h_lines, v_lines)
            cleaned_inv = cv2.subtract(inv, lines)
            cleaned = cv2.bitwise_not(cleaned_inv)
            return cleaned
        except Exception:
            return bin_img

    def extract_text_from_image(self, image_path):
        """Extract text from image file"""
        try:
            base = cv2.imread(image_path)
            if base is None:
                return ""
            gray = cv2.cvtColor(base, cv2.COLOR_BGR2GRAY)
            try:
                osd = pytesseract.image_to_osd(Image.fromarray(gray))
                rot = 0
                for line in osd.splitlines():
                    if line.lower().startswith('rotate:'):
                        try:
                            rot = int(line.split(':')[1].strip())
                        except Exception:
                            rot = 0
                        break
                if rot in (90, 180, 270):
                    if rot == 90:
                        gray = cv2.rotate(gray, cv2.ROTATE_90_CLOCKWISE)
                    elif rot == 180:
                        gray = cv2.rotate(gray, cv2.ROTATE_180)
                    elif rot == 270:
                        gray = cv2.rotate(gray, cv2.ROTATE_90_COUNTERCLOCKWISE)
            except Exception:
                pass

            try:
                gray_eq = cv2.equalizeHist(gray)
            except Exception:
                gray_eq = gray

            h0, w0 = gray_eq.shape[:2]
            scale = 1.0
            if min(h0, w0) < 1200:
                scale = 1200.0 / float(min(h0, w0))
                gray_eq = cv2.resize(gray_eq, (int(w0 * scale), int(h0 * scale)), interpolation=cv2.INTER_CUBIC)

            gray_eq = self._crop_to_content(gray_eq)

            _, otsu = cv2.threshold(gray_eq, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            den = cv2.fastNlMeansDenoising(otsu, None, 10, 7, 21)
            kernel = np.ones((2, 2), np.uint8)
            dil = cv2.dilate(den, kernel, 1)
            try:
                adaptive = cv2.adaptiveThreshold(gray_eq, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 41, 10)
            except Exception:
                adaptive = den
            opened = cv2.morphologyEx(den, cv2.MORPH_OPEN, kernel, iterations=1)
            closed = cv2.morphologyEx(den, cv2.MORPH_CLOSE, kernel, iterations=1)
            inv_den = cv2.bitwise_not(den)
            inv_adaptive = cv2.bitwise_not(adaptive)
            no_lines_den = self._remove_lines(den)
            no_lines_ad = self._remove_lines(adaptive)
            try:
                clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
                gray_clahe = clahe.apply(gray)
            except Exception:
                gray_clahe = gray
            bil = cv2.bilateralFilter(gray_eq, 5, 50, 50)
            blur = cv2.GaussianBlur(gray_eq, (0, 0), 1.0)
            sharp = cv2.addWeighted(gray_eq, 1.5, blur, -0.5, 0)
            blackhat = cv2.morphologyEx(gray_eq, cv2.MORPH_BLACKHAT, kernel, iterations=1)

            candidates = [gray, gray_eq, gray_clahe, bil, sharp, den, no_lines_den, dil, adaptive, no_lines_ad, opened, closed, blackhat, inv_den, inv_adaptive]
            configs = [
                '--oem 3 --psm 6 -c user_defined_dpi=300',
                '--oem 1 --psm 6 -c user_defined_dpi=300',
                '--oem 3 --psm 4 -c user_defined_dpi=300',
                '--oem 3 --psm 11 -c user_defined_dpi=300',
                '--oem 3 --psm 12 -c user_defined_dpi=300',
                '--oem 3 --psm 3 -c user_defined_dpi=300',
            ]
            best_text = ""
            best_conf = -1.0
            for cand in candidates:
                for cfg in configs:
                    text, conf = self._ocr_text_and_conf(cand, cfg)
                    if conf > best_conf or (conf == best_conf and len(text) > len(best_text)):
                        best_text = text
                        best_conf = conf

            header_text = ""
            try:
                h, w = gray_eq.shape[:2]
                hh = max(int(h * 0.25), 1)
                header_region = gray_eq[0:hh, 0:w]
                ht, hc = self._ocr_text_and_conf(header_region, '--oem 3 --psm 7 -c user_defined_dpi=300 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-:/()&.,')
                header_text = ht.strip()
            except Exception:
                header_text = ""

            body_text = ""
            try:
                h2_start = hh
                h2_end = max(int(h * 0.90), hh + 1)
                body_region = gray_eq[h2_start:h2_end, 0:w]
                bt, bc = self._ocr_text_and_conf(body_region, '--oem 3 --psm 6')
                body_text = bt.strip()
            except Exception:
                body_text = ""

            pieces = [p for p in [header_text, best_text, body_text] if p]
            text = ("\n\n".join(pieces)).strip()
            # Limit how much text we keep to the most relevant portion for classification
            try:
                max_chars_env = os.getenv('OCR_MAX_CHARS')
                max_chars = int(max_chars_env) if max_chars_env else 1500
            except Exception:
                max_chars = 1500
            if len(text) > max_chars:
                text = text[:max_chars]
            return text
            
        except Exception as e:
            print(f"Error extracting text from image: {str(e)}")
            return ""
    
    def extract_text_from_pdf(self, pdf_path):
        """Extract text from PDF file"""
        try:
            # Convert PDF pages to images
            pages = convert_from_path(pdf_path, dpi=300)
            
            extracted_text = []
            
            # Only process the first N pages (header pages usually contain all signals we need)
            try:
                max_pages_env = os.getenv('OCR_MAX_PAGES')
                max_pages = int(max_pages_env) if max_pages_env else 1
            except Exception:
                max_pages = 1

            pages_to_process = pages[: max(1, max_pages)]

            # Process each selected page
            for i, page in enumerate(pages_to_process):
                print(f"Processing page {i+1}/{len(pages_to_process)}")
                
                # Convert PIL Image to numpy array for preprocessing
                img_array = np.array(page)
                
                # Convert RGB to BGR for OpenCV
                img_bgr = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)
                
                # Save temporarily for processing
                temp_path = f"temp_page_{i}.png"
                cv2.imwrite(temp_path, img_bgr)
                
                # Extract text from page
                page_text = self.extract_text_from_image(temp_path)
                extracted_text.append(page_text)
                
                # Clean up temp file
                os.remove(temp_path)
            
            # Combine text from all pages
            full_text = "\n\n".join(extracted_text).strip()

            # Apply the same length cap used for single images
            try:
                max_chars_env = os.getenv('OCR_MAX_CHARS')
                max_chars = int(max_chars_env) if max_chars_env else 1500
            except Exception:
                max_chars = 1500
            if len(full_text) > max_chars:
                full_text = full_text[:max_chars]

            return full_text
            
        except Exception as e:
            print(f"Error extracting text from PDF: {str(e)}")
            return ""
    
    def extract_text(self, file_path):
        """
        Main method to extract text from any supported document type
        Automatically detects file type and uses appropriate extraction method
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
        
        # Get file extension
        _, ext = os.path.splitext(file_path)
        ext = ext.lower()
        
        print(f"Extracting text from {ext} file: {file_path}")
        
        # Route to appropriate extraction method
        if ext == '.pdf':
            return self.extract_text_from_pdf(file_path)
        elif ext in ['.png', '.jpg', '.jpeg', '.tiff', '.bmp']:
            return self.extract_text_from_image(file_path)
        else:
            raise ValueError(f"Unsupported file type: {ext}")
    
    def extract_keywords(self, text, top_n=10):
        """
        Extract important keywords from text
        Simple implementation - can be enhanced with NLP libraries
        """
        # Remove common words (stop words)
        stop_words = {
            'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
            'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'been', 'be',
            'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it'
        }
        
        # Split into words and filter
        words = text.lower().split()
        keywords = [w for w in words if len(w) > 3 and w not in stop_words]
        
        # Count frequency
        word_freq = {}
        for word in keywords:
            word_freq[word] = word_freq.get(word, 0) + 1
        
        # Get top N keywords
        sorted_keywords = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)
        return [word for word, _ in sorted_keywords[:top_n]]


if __name__ == "__main__":
    # Test OCR engine
    ocr = OCREngine()
    
    test_file = "test_document.pdf"
    if os.path.exists(test_file):
        text = ocr.extract_text(test_file)
        print("Extracted Text:")
        print(text)
        print("\nKeywords:")
        print(ocr.extract_keywords(text))
    else:
        print(f"Test file {test_file} not found")
