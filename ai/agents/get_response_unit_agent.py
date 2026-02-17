from langchain.agents import initialize_agent, AgentType # type: ignore
from langchain.tools import tool # type: ignore
from llm import llm # type: ignore

@tool
def get_response_unit(emergency_type: str, location: str) -> dict:
    """
    يحدد الفريق الأنسب (شرطة، إسعاف، إطفاء...) بناءً على نوع الطارئ والموقع.
    يعيد أيضًا وقت الوصول التقديري ومعرف الفريق.
    """

    response_map = {
        "حوادث المرور": {"unit": "الإسعاف والشرطة", "eta": "5 دقائق", "team_id": 101},
        "الحرائق": {"unit": "الدفاع المدني", "eta": "7 دقائق", "team_id": 102},
        "السرقة": {"unit": "الشرطة", "eta": "4 دقائق", "team_id": 103},
        "الجرائم والحوادث الأمنية": {"unit": "الشرطة", "eta": "3 دقائق", "team_id": 104},
        "الانفجارات والتسريبات": {"unit": "الدفاع المدني", "eta": "6 دقائق", "team_id": 105},
        "الحالات الطبية الطارئة": {"unit": "الإسعاف", "eta": "4 دقائق", "team_id": 106},
        "الكوارث الطبيعية": {"unit": "الدفاع المدني", "eta": "10 دقائق", "team_id": 107},
        "طوارئ بنية تحتية": {"unit": "الجهات الخدمية والدفاع المدني", "eta": "8 دقائق", "team_id": 108},
        "طوارئ إنسانية أو اجتماعية": {"unit": "الشرطة أو الهلال الأحمر", "eta": "5 دقائق", "team_id": 109},
    }

    result = response_map.get(emergency_type, {
        "unit": "جهة غير معروفة",
        "eta": "غير متوفّر",
        "team_id": 0
    })

    result["location"] = location
    return result


# إنشاء العميل
get_response_unit_agent = initialize_agent(
    tools=[get_response_unit],
    llm=llm,
    agent=AgentType.OPENAI_FUNCTIONS,
    verbose=True,
)
