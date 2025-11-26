"""
ML Classifier Module
Classifies documents into categories using machine learning
"""

import os
import re
import joblib
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline


class DocumentClassifier:
    """Document classifier using ML"""
    
    # Document categories for school records
    CATEGORIES = [
        'Exam Form',
        'Acknowledgement Form',
        'Clearance',
        'Receipt',
        'Grade Sheet',
        'Enrollment Form',
        'ID Application',
        'Certificate Request',
        'Leave Form',
        'Syllabus Review Form',
        'Other'
    ]
    
    def __init__(self):
        """Initialize classifier"""
        self.model_path = os.getenv('MODEL_PATH', 'models/classifier_model.pkl')
        self.confidence_threshold = float(os.getenv('CONFIDENCE_THRESHOLD', 0.7))
        
        # Try to load existing model
        if os.path.exists(self.model_path):
            self.load_model()
        else:
            # Use rule-based classification instead
            print("ℹ Using keyword-based classification (ML model not trained yet)")
            print("  Classification will use document keywords - accuracy may vary")
            self.model = None
    
    def load_model(self):
        """Load pre-trained ML model"""
        try:
            self.model = joblib.load(self.model_path)
            print(f"Model loaded from {self.model_path}")
        except Exception as e:
            print(f"Error loading model: {str(e)}")
            self.model = None
    
    def save_model(self):
        """Save trained model"""
        try:
            os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
            joblib.dump(self.model, self.model_path)
            print(f"Model saved to {self.model_path}")
        except Exception as e:
            print(f"Error saving model: {str(e)}")
    
    def train_model(self, training_data, labels):
        """
        Train the classifier with training data
        
        Args:
            training_data: List of text samples
            labels: List of corresponding category labels
        """
        # Create pipeline with TF-IDF vectorizer and Naive Bayes classifier
        self.model = Pipeline([
            ('tfidf', TfidfVectorizer(max_features=1000, ngram_range=(1, 2))),
            ('classifier', MultinomialNB())
        ])
        
        # Train the model
        self.model.fit(training_data, labels)
        
        # Save the trained model
        self.save_model()
        
        print("Model trained successfully")
    
    def extract_features(self, text):
        """Extract features from text for classification"""
        text_lower = text.lower()
        
        features = {
            # Keyword presence
            'has_exam': any(word in text_lower for word in ['exam', 'examination', 'test', 'quiz']),
            'has_acknowledgement': any(word in text_lower for word in ['acknowledge', 'acknowledgement', 'received']),
            'has_clearance': any(word in text_lower for word in ['clearance', 'cleared', 'no obligations']),
            'has_receipt': any(word in text_lower for word in ['receipt', 'payment', 'amount', 'paid']),
            'has_grade': any(word in text_lower for word in ['grade', 'marks', 'score', 'gpa']),
            'has_enrollment': any(word in text_lower for word in ['enroll', 'enrollment', 'registration']),
            'has_id': any(word in text_lower for word in ['id card', 'identification', 'student id']),
            'has_certificate': any(word in text_lower for word in ['certificate', 'certification', 'certify']),
            'has_leave': any(word in text_lower for word in ['leave', 'absence', 'vacation']),
            # Syllabus review specific
            'has_syllabus_title': 'syllabus review form' in text_lower,
            'has_syllabus_indicators_table': 'indicators' in text_lower and 'remarks' in text_lower and ('yes' in text_lower and 'no' in text_lower),
            'has_syllabus_document_code': 'fm-ustp-acad-12' in text_lower or 'fm ustp acad 12' in text_lower,
            'has_syllabus_title_fuzzy': bool(re.search(r'syllabus\W{0,10}review|review\W{0,10}syllabus', text_lower)),
            'has_ustp_acad_12': bool(re.search(r'\b(?:fm)?\s*-?\s*ustp\s*-?\s*acad\s*-?\s*12\b', text_lower)),
            'has_directions_yes': 'directions' in text_lower and 'yes' in text_lower,
            'has_university_header': 'university of science and technology of southern philippines' in text_lower,
            'has_course_code': 'course code' in text_lower,
            'has_faculty': 'faculty' in text_lower,
            
            # Pattern matching
            'has_amount': bool(re.search(r'\$?\d+\.?\d*', text)),
            'has_date': bool(re.search(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}', text)),
            'has_signature': 'signature' in text_lower or 'signed' in text_lower,
        }
        
        return features
    
    def rule_based_classification(self, text):
        """
        Rule-based classification fallback
        Used when no ML model is available
        """
        features = self.extract_features(text)
        text_lower = text.lower()
        
        # Scoring for each category
        scores = {category: 0 for category in self.CATEGORIES}
        
        # Exam Form
        if features['has_exam']:
            scores['Exam Form'] += 3
        if 'examination' in text_lower and 'form' in text_lower:
            scores['Exam Form'] += 2
        
        # Acknowledgement Form
        if features['has_acknowledgement']:
            scores['Acknowledgement Form'] += 3
        if features['has_signature'] and 'acknowledge' in text_lower:
            scores['Acknowledgement Form'] += 2
        
        # Clearance
        if features['has_clearance']:
            scores['Clearance'] += 4
        if 'cleared' in text_lower or 'no pending' in text_lower:
            scores['Clearance'] += 2
        
        # Receipt
        if features['has_receipt']:
            scores['Receipt'] += 3
        if features['has_amount'] and ('paid' in text_lower or 'payment' in text_lower):
            scores['Receipt'] += 3
        
        # Grade Sheet
        if features['has_grade']:
            scores['Grade Sheet'] += 3
        if 'transcript' in text_lower or 'report card' in text_lower:
            scores['Grade Sheet'] += 2
        
        # Enrollment Form
        if features['has_enrollment']:
            scores['Enrollment Form'] += 3
        if 'enroll' in text_lower and 'subject' in text_lower:
            scores['Enrollment Form'] += 2
        
        # ID Application
        if features['has_id']:
            scores['ID Application'] += 4
        if 'student id' in text_lower or 'id application' in text_lower:
            scores['ID Application'] += 2
        
        # Certificate Request
        if features['has_certificate']:
            scores['Certificate Request'] += 3
        if 'request' in text_lower and 'certificate' in text_lower:
            scores['Certificate Request'] += 2
        
        # Leave Form
        if features['has_leave']:
            scores['Leave Form'] += 3
        if 'leave application' in text_lower or 'absence' in text_lower:
            scores['Leave Form'] += 2

        # Syllabus Review-like forms
        syllabus_signals = 0
        if features.get('has_syllabus_title'):
            syllabus_signals += 4
        if features.get('has_syllabus_title_fuzzy'):
            syllabus_signals += 2
        if features.get('has_syllabus_document_code'):
            syllabus_signals += 3
        if features.get('has_ustp_acad_12'):
            syllabus_signals += 3
        if features.get('has_syllabus_indicators_table'):
            syllabus_signals += 2
        if features.get('has_reviewed_by'):
            syllabus_signals += 1
        if features.get('has_plan_of_action'):
            syllabus_signals += 1
        if features.get('has_directions_yes'):
            syllabus_signals += 1
        if features.get('has_university_header'):
            syllabus_signals += 1
        if features.get('has_course_code'):
            syllabus_signals += 1
        if features.get('has_faculty'):
            syllabus_signals += 1

        if syllabus_signals > 0:
            scores['Syllabus Review Form'] += syllabus_signals
            # Down-weight Grade Sheet for these forms
            if scores['Grade Sheet'] > 0:
                scores['Grade Sheet'] = max(0, scores['Grade Sheet'] - 3)
        
        # Get category with highest score
        max_score = max(scores.values())
        
        if max_score == 0:
            return 'Other', 0.5
        
        document_type = max(scores, key=scores.get)
        confidence = min(max_score / 10.0, 1.0)  # Normalize to 0-1
        
        return document_type, confidence
    
    def classify(self, text):
        """
        Classify document text into a category
        
        Args:
            text: Extracted text from document
            
        Returns:
            dict with document_type, confidence, and keywords
        """
        if not text or len(text.strip()) < 10:
            return {
                'document_type': 'Other',
                'confidence': 0.0,
                'keywords': [],
                'method': 'insufficient_text'
            }
        
        # Use ML model if available
        if self.model is not None:
            try:
                # Predict
                predictions = self.model.predict([text])
                probabilities = self.model.predict_proba([text])
                
                document_type = predictions[0]
                confidence = float(max(probabilities[0]))
                
                # If confidence is too low, fallback to rule-based
                if confidence < self.confidence_threshold:
                    document_type, confidence = self.rule_based_classification(text)
                    method = 'rule_based_fallback'
                else:
                    method = 'ml_model'
                    
            except Exception as e:
                print(f"ML classification error: {str(e)}")
                document_type, confidence = self.rule_based_classification(text)
                method = 'rule_based_error_fallback'
        else:
            # Use rule-based classification
            document_type, confidence = self.rule_based_classification(text)
            method = 'rule_based'
        
        # Extract keywords
        keywords = self.extract_keywords(text)
        
        return {
            'document_type': document_type,
            'confidence': round(confidence, 2),
            'keywords': keywords,
            'method': method
        }
    
    def extract_keywords(self, text, top_n=5):
        """Extract important keywords from text"""
        # Simple keyword extraction
        words = re.findall(r'\b[a-zA-Z]{4,}\b', text.lower())
        
        # Common stop words
        stop_words = {
            'this', 'that', 'with', 'from', 'have', 'been', 'will',
            'would', 'could', 'should', 'about', 'their', 'there'
        }
        
        # Filter and count
        word_freq = {}
        for word in words:
            if word not in stop_words:
                word_freq[word] = word_freq.get(word, 0) + 1
        
        # Get top keywords
        sorted_words = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)
        return [word for word, _ in sorted_words[:top_n]]


if __name__ == "__main__":
    # Test classifier
    classifier = DocumentClassifier()
    
    # Test samples
    test_texts = [
        "This is to acknowledge that I have received the examination form for the final semester exam.",
        "Receipt No: 12345. Amount Paid: $100.00 for tuition fees. Date: 01/15/2025",
        "Clearance Certificate: Student has no pending obligations and is cleared for graduation.",
        "Grade Report for Student ID: 2025-0001. GPA: 3.8. All subjects passed."
    ]
    
    for text in test_texts:
        result = classifier.classify(text)
        print(f"\nText: {text[:50]}...")
        print(f"Classification: {result}")
