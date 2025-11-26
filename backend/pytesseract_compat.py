"""
Compatibility wrapper for pytesseract with Python 3.14
"""
import sys
from importlib.util import find_spec

# Patch pkgutil for Python 3.14 compatibility
if sys.version_info >= (3, 12):
    import pkgutil
    if not hasattr(pkgutil, 'find_loader'):
        def find_loader(name):
            """Compatibility function for Python 3.14+"""
            spec = find_spec(name)
            return spec.loader if spec else None
        pkgutil.find_loader = find_loader

# Now import pytesseract
import pytesseract

# Export everything from pytesseract
__all__ = dir(pytesseract)
