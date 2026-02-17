import os
from dotenv import load_dotenv
from langchain.chat_models import ChatOpenAI  # type: ignore

load_dotenv()

llm = ChatOpenAI(
    model_name="gpt-4o-mini",
    temperature=0,
    openai_api_key=os.getenv("OPENAI_API_KEY"),
)
