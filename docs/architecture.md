# Architecture Deep Dive

## Overview

The Smart Emergency Platform is a two-layer system: an **AI Engine** (Python) that processes and classifies Arabic emergency text, and a **Mobile App** (Flutter) that provides real-time coordination.

---

## AI Layer: Transformer + Multi-Agent Pipeline

### Transformer Classifier

**Model:** Fine-tuned `UBC-NLP/MARBERTv2` with custom multi-head architecture.

```
Input (Arabic Text) → MARBERTv2 Encoder → Shared Embedding
                                              │
                      ┌───────────────────────┼───────────────────────┐
                      ▼                       ▼                       ▼
              Main Class Head         Subclass Expert Heads     Severity Expert Heads
              (Softmax)               (1 per main class)        (1 per context group)
                      │                       │                       │
                      ▼                       ▼                       ▼
              "FIRE"                  "structure_fire"            severity: 8.5
```

**Training Innovation — Gradient Masking:**

- Standard multi-task models update ALL heads on every sample, causing interference
- Our approach masks gradients so each expert head ONLY trains on its relevant samples
- Result: each expert becomes a true domain specialist

### LangGraph StateGraph

The coordinator graph processes reports through 5 sequential nodes:

```
detect_emergency_type → detect_missing_info → ask_for_missing_info_text → get_safety_tips → get_response_unit → END
```

Each node mutates a shared `EmergencyState` TypedDict, building up a complete structured report progressively.

The `emergency_type_agent` is unique because it wraps the trained TensorFlow model as a LangChain `@tool`, letting the LLM agent decide when and how to invoke the classifier.

---

## Mobile Layer: Flutter Feature Architecture

### Feature Modules

| Module           | Cubit                | Key Screens                                                      |
| ---------------- | -------------------- | ---------------------------------------------------------------- |
| `reports`        | `ReportsCubit`       | `map_screen.dart`                                                |
| `assignments`    | `AssignmentsCubit`   | `focus_mode_screen.dart`                                         |
| `chat`           | `ChatCubit`          | `chat_conversation_screen.dart`, `ai_emergency_chat_screen.dart` |
| `users_location` | `UsersLocationCubit` | _(Background service)_                                           |
| `dashboard`      | —                    | `unified_dashboard.dart`                                         |

### Data Flow

```
Backend API → Dio Client → Repository Service → Cubit (State Machine) → BlocBuilder → UI Widget
                                                     ↑
                                              Timer.periodic (5s polling)
```

### Resilience Patterns

1. **Optimistic UI**: Report status changes update the UI immediately, then sync
2. **Fallback Location**: 4-tier fallback (raw coords → location object → geocoding → Damascus center)
3. **Defensive Parsing**: `fromJson` blocks handle type mismatches (`String` vs `num`), null fields, and malformed dates
4. **Route Degradation**: If routing API fails → retry with backoff → straight-line distance fallback

### Services Layer

| Service                       | Purpose                                             |
| ----------------------------- | --------------------------------------------------- |
| `routing_service.dart`        | OSRM-based route calculation with polyline decoding |
| `geocoding_service.dart`      | Address ↔ Coordinate resolution                     |
| `map_navigation_service.dart` | External map app launchers                          |
| `report_details_service.dart` | Report metadata enrichment                          |
