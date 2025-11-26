# ML Model Training Guide

## Overview

The ARC system uses machine learning to classify documents. This guide explains how to train and improve the classification model.

---

## Current Approach

### Rule-Based Classification (Default)

By default, the system uses a rule-based classifier that:
- Searches for keywords specific to each document type
- Calculates scores based on keyword presence
- Uses pattern matching (dates, amounts, signatures)
- Returns the document type with the highest score

**Advantages:**
- No training data required
- Immediate deployment
- Interpretable results

**Limitations:**
- May miss nuanced patterns
- Requires manual rule updates
- Lower accuracy for edge cases

---

## Machine Learning Approach

### Training Data Requirements

To train an ML model, you need:

1. **Minimum 50-100 samples per document category**
2. **Labeled data** with:
   - Document text (from OCR)
   - Correct document type label

### Data Collection

```python
# Example training data structure
training_data = [
    ("This is to acknowledge receipt of examination form...", "Exam Form"),
    ("Receipt No: 12345 Amount: $100...", "Receipt"),
    ("Clearance Certificate: No pending obligations...", "Clearance"),
    # ... more samples
]
```

---

## Training the Model

### Step 1: Prepare Training Data

Create a CSV file with your labeled data:

```csv
text,label
"Examination Form for Final Semester...","Exam Form"
"Receipt No: 001 Amount Paid $50","Receipt"
"Clearance: Student has cleared all...","Clearance"
```

### Step 2: Run Training Script

```python
from ml_classifier import DocumentClassifier
import pandas as pd

# Load your training data
df = pd.read_csv('training_data.csv')
texts = df['text'].tolist()
labels = df['label'].tolist()

# Initialize and train classifier
classifier = DocumentClassifier()
classifier.train_model(texts, labels)

print("Model trained and saved successfully!")
```

### Step 3: Test the Model

```python
# Test with sample text
test_text = "This is an examination application form for the final exam."
result = classifier.classify(test_text)

print(f"Type: {result['document_type']}")
print(f"Confidence: {result['confidence']}")
```

---

## Model Architecture

The default ML model uses:

1. **TF-IDF Vectorizer**
   - Converts text to numerical features
   - Uses 1-2 word n-grams
   - Max 1000 features

2. **Naive Bayes Classifier**
   - Fast training and prediction
   - Works well with text data
   - Provides probability scores

### Model Pipeline

```
Input Text → TF-IDF Vectorization → Naive Bayes → Document Type + Confidence
```

---

## Improving Model Accuracy

### 1. Increase Training Data

- Collect more labeled examples
- Ensure balanced representation of all document types
- Include edge cases and variations

### 2. Feature Engineering

Add custom features:

```python
def extract_features(text):
    features = {
        'has_amount': bool(re.search(r'\$\d+', text)),
        'has_date': bool(re.search(r'\d{1,2}/\d{1,2}/\d{4}', text)),
        'word_count': len(text.split()),
        'has_signature': 'signature' in text.lower(),
    }
    return features
```

### 3. Try Different Algorithms

Replace Naive Bayes with:

```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.neural_network import MLPClassifier

# Random Forest
classifier = RandomForestClassifier(n_estimators=100)

# Support Vector Machine
classifier = SVC(kernel='rbf', probability=True)

# Neural Network
classifier = MLPClassifier(hidden_layer_sizes=(100, 50))
```

### 4. Hyperparameter Tuning

```python
from sklearn.model_selection import GridSearchCV

params = {
    'tfidf__max_features': [500, 1000, 2000],
    'tfidf__ngram_range': [(1, 1), (1, 2), (1, 3)],
    'classifier__alpha': [0.1, 0.5, 1.0],
}

grid_search = GridSearchCV(pipeline, params, cv=5)
grid_search.fit(X_train, y_train)
```

---

## Model Evaluation

### Metrics to Track

1. **Accuracy**: Overall correct predictions
2. **Precision**: Correct positive predictions per class
3. **Recall**: Coverage of actual positives per class
4. **F1-Score**: Balance of precision and recall

### Evaluation Script

```python
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix

# Split data
X_train, X_test, y_train, y_test = train_test_split(
    texts, labels, test_size=0.2, random_state=42
)

# Train
classifier.train_model(X_train, y_train)

# Predict
predictions = [classifier.classify(text)['document_type'] for text in X_test]

# Evaluate
print(classification_report(y_test, predictions))
print(confusion_matrix(y_test, predictions))
```

---

## Deployment

### Save Trained Model

```python
import joblib

# Model is auto-saved during training to:
# backend/models/classifier_model.pkl

# Or manually save:
joblib.dump(classifier.model, 'models/classifier_model.pkl')
```

### Load Model in Production

```python
# Model is automatically loaded in ml_classifier.py
# when initialized:

classifier = DocumentClassifier()
# Will load from MODEL_PATH environment variable
```

---

## Active Learning

Improve model over time:

1. **Collect misclassified documents**
2. **Manually label them correctly**
3. **Add to training set**
4. **Retrain model periodically**

### Confidence-Based Review

```python
# Flag low-confidence predictions for human review
if result['confidence'] < 0.7:
    # Send for manual verification
    flag_for_review(document)
```

---

## Advanced Techniques

### 1. Deep Learning with BERT

```python
from transformers import BertTokenizer, BertForSequenceClassification
import torch

tokenizer = BertTokenizer.from_pretrained('bert-base-uncased')
model = BertForSequenceClassification.from_pretrained(
    'bert-base-uncased',
    num_labels=len(CATEGORIES)
)

# Fine-tune on your data
# ... training code
```

### 2. Multi-Modal Classification

Combine text features with:
- Document layout analysis
- Image features
- Structural patterns

### 3. Semi-Supervised Learning

Use unlabeled data:
```python
from sklearn.semi_supervised import LabelSpreading

# Use both labeled and unlabeled data
semi_model = LabelSpreading()
```

---

## Monitoring and Maintenance

### Track Model Performance

```sql
-- Query classification accuracy over time
SELECT 
    DATE(created_at) as date,
    AVG(confidence) as avg_confidence,
    COUNT(*) as total
FROM documents
GROUP BY DATE(created_at)
ORDER BY date DESC;
```

### Retraining Schedule

- **Weekly**: If high volume (>100 documents/day)
- **Monthly**: For moderate volume
- **Quarterly**: For low volume

### Model Versioning

```
models/
├── classifier_model_v1.0.pkl
├── classifier_model_v1.1.pkl
└── classifier_model_v2.0.pkl (current)
```

---

## Troubleshooting

### Low Accuracy

- Check training data quality and balance
- Increase training data size
- Try different algorithms
- Improve feature engineering

### Slow Predictions

- Reduce max_features in TF-IDF
- Use simpler model (e.g., Naive Bayes)
- Optimize preprocessing

### High Confidence on Wrong Predictions

- Model might be overfitting
- Need more diverse training examples
- Consider ensemble methods

---

## Resources

- [Scikit-learn Documentation](https://scikit-learn.org/)
- [Text Classification Tutorial](https://scikit-learn.org/stable/tutorial/text_analytics/working_with_text_data.html)
- [NLP Best Practices](https://github.com/microsoft/nlp-recipes)
