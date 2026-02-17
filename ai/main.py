from agents.emergency_coordinator import EmergencyState, build_emergency_coordinator_graph

graph = build_emergency_coordinator_graph()

# user_input = "في مشاجرة ب مشروع ياسين عند دار الراحة للمسنين سكاكين وخلافو"
# location = "بناية 12، شارع التحرير"  

user_input = input("🚨 الرجاء كتابة بلاغك: ")

initial_state: EmergencyState = {
        "user_input": user_input,
        "location": None,
        "emergency_type": None,
        "missing_info": None,
        "safety_tips": None,
        "response_unit": None,
        "report": "",
    }


final_state = graph.invoke(initial_state)

print("\n📦 [النتيجة النهائية]:")
for key, value in final_state.items():
    print(f"{key}: {value}")


print("\n📦 [التقرير النهائي]:")
print(final_state["report"])

