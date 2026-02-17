from langchain.agents import initialize_agent, AgentType  # type: ignore
from langchain.tools import tool  # type: ignore
from llm import llm  # type: ignore
from keras.layers import TFSMLayer

import tensorflow as tf
import pickle
import numpy as np

# Load preprocessing objects
with open("Models/preprocessing_objects.pkl", "rb") as f:
    preprocessing = pickle.load(f)

tokenizer = preprocessing["tokenizer"]
class_encoder = preprocessing["class_encoder"]
subclass_encoder = preprocessing["subclass_encoder"]
max_len = preprocessing.get("max_length", 100)
severity_scaler = preprocessing.get("severity_scaler", None)

# Load trained model

model = tf.saved_model.load("Models/arabic_emergency_marbert_model")
infer = model.signatures["serving_default"]

@tool(description="يصنف نوع الحالة وخطورتها باستخدام النموذج المدرب.")
def classify_emergency(text: str) -> dict:
    try:
        encoding = tokenizer.encode_plus(
            text,
            truncation=True,
            padding='max_length',
            max_length=max_len,
            return_tensors="tf"
        )

        result = infer(
            input_ids=encoding["input_ids"],
            attention_mask=encoding["attention_mask"]
        )

        # التنبؤ الأساسي (النوع)
        class_pred = result["output_1"].numpy()
        class_index = np.argmax(class_pred, axis=1)[0]
        class_label = class_encoder.classes_[class_index]


        # التنبؤ الفرعي (النوع الفرعي)
        subclass_pred = result["output_2"].numpy()
        subclass_index = np.argmax(subclass_pred, axis=1)[0]
        subclass_label = subclass_encoder.classes_[subclass_index]

        # التنبؤ بالخطورة
        severity_pred = result["output_0"].numpy()
        severity_value = severity_pred[0][0]
        severity_label = (
            severity_scaler.inverse_transform([[severity_value]])[0][0]
            if severity_scaler else float(severity_value)
        )

        return class_label
         
        

    except Exception as e:
        print("[❌ Error in model prediction]:", str(e))
        return {"type": "غير معروف", "subtype": "غير معروف", "severity": "غير معروف"}




# Create agent
emergency_type_agent = initialize_agent(
    tools=[classify_emergency],
    llm=llm,
    agent=AgentType.OPENAI_FUNCTIONS,
    verbose=True,
)
