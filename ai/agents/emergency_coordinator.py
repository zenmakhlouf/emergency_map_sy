# coordinator_graph.py
from langgraph.graph import StateGraph, END # type: ignore
from agents.emergency_type_agent import emergency_type_agent
from agents.get_missing_info_agent import get_missing_info_agent
from agents.get_safety_tips_agent import get_safety_tips_agent
from agents.get_response_unit_agent import get_response_unit
from typing_extensions import TypedDict


class EmergencyState(TypedDict):
    user_input: str
    location: str | None
    emergency_type: str | None
    missing_info: dict | None
    safety_tips: list | None
    response_unit: dict | str | None
    report: str 

# 1. Define your node functions
def detect_emergency_type(state):
    emergency_type = emergency_type_agent.run(state["user_input"])
    state["emergency_type"] = emergency_type
    print("\n[🔍 التصنيف]:", emergency_type)
    state["report"] += f"\n🧠 التصنيف: {emergency_type}"
    return state

def detect_missing_info(state):
    prompt_text = f"نوع الطارئ: {state['emergency_type']}\nالبلاغ: {state['user_input']}"
    missing_info = get_missing_info_agent.run({"input": prompt_text})
    state["missing_info"] = missing_info
    print("\n[🔍 المعلومات الناقصة]:", missing_info)
    state["report"] += f"\n📋 معلومات ناقصة مقترحة: {missing_info}"
    return state

def ask_for_missing_info_text(state):
    print("\n📝 الرجاء تزويدنا بمعلومات إضافية حول البلاغ (أي نص):")
    user_text = input(">>> ")
    state["missing_info_text"] = user_text
    state["report"] += f"\n📝 معلومات أضافها المستخدم: {user_text}"
    return state

def get_safety_tips(state):
    prompt_text = f"نوع الطارئ: {state['emergency_type']}\nالبلاغ: {state['user_input']}"
    safety_tips = get_safety_tips_agent.run({"input": prompt_text})
    state["safety_tips"] = safety_tips
    print("\n[🔍 ارشادات السلامة]:", safety_tips)
    return state

def get_response_unit_node(state):
    location = state.get("location")
    if location:
        response_unit = get_response_unit.run({
            "emergency_type": state["emergency_type"],
            "location": location,
        })
        state["response_unit"] = response_unit
        print("\n[🔍 الوحدة المناسبة]:", response_unit)
    else:
        state["response_unit"] = "❌ الموقع غير متوفر"
    state["report"] += f"\n🚒 الوحدة المناسبة: {state['response_unit']}"


    return state

def build_emergency_coordinator_graph():
 
    builder = StateGraph(EmergencyState)

    # إضافة العقد والاتصالات كما في السابق
    builder.add_node("detect_emergency_type", detect_emergency_type)
    builder.add_node("detect_missing_info", detect_missing_info)
    builder.add_node("ask_for_missing_info_text", ask_for_missing_info_text)
    builder.add_node("get_safety_tips", get_safety_tips)
    builder.add_node("get_response_unit", get_response_unit_node)

    builder.set_entry_point("detect_emergency_type")

    builder.add_edge("detect_emergency_type", "detect_missing_info")
    builder.add_edge("detect_missing_info", "ask_for_missing_info_text")
    builder.add_edge("ask_for_missing_info_text", "get_safety_tips")
    builder.add_edge("get_safety_tips", "get_response_unit")
    builder.add_edge("get_response_unit", END)


    graph = builder.compile()
    return graph