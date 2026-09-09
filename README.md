# PROVA

Cognitive Error Classification Pipeline — Flutter frontend, Python backend
(preprocessing + TrOCR + BERT + evaluation), Firebase database/auth/storage.

This repo is scaffolded directly from your proposal's architecture
(`docs/architecture/Proposal_Diagrams_Compiled.pdf`, especially Figure H-1
System Architecture and Figure H-5 ERD), so every folder maps to a labeled
box or entity in those diagrams.

```
prova_project/
├── flutter_app/    # Frontend — 4 modules from Figure H-1
├── backend/        # Python — Preprocess / OCR / Classifier / Evaluation
├── firebase/       # Firestore + Storage config, security rules
└── docs/
    ├── prototype/PROVA_Research_Tool.html   # your existing UI mockup, unchanged
    └── architecture/Proposal_Diagrams_Compiled.pdf
```

## Order of operations (do these in order — each step depends on the last)

### 1. Python backend 

```bash
cd backend
source .venv/bin/activate
python -m uvicorn app.main:app --reload --port 8000
```

Confirm it's alive: `curl http://localhost:8000/health` → `{"status":"ok"}`.
Poke around `http://localhost:8000/docs` — you can exercise the whole
pipeline (`/runs`, `/evaluation/{run_id}`) from there before the frontend
exists.

### 2. Flutter frontend

```bash
cd flutter_app
flutter run -d chrome --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

### 4. Reference the existing mockup

`docs/prototype/PROVA_Research_Tool.html` is your dummy-data prototype,
copied in as-is — open it in a browser as your visual reference while
filling in the `TODO`s left in each `*_screen.dart` file.

## How modularity is enforced

- **Frontend**: each of the 4 modules (`operations_monitoring`,
  `annotation_workspace`, `evaluation_records`, `administration`) is a
  self-contained `features/<module>/{data,domain,presentation}` folder.
  None import each other's `presentation/` files. Shared code only in
  `lib/core` and `lib/services`.
- **Backend**: each pipeline stage (`preprocessing`, `ocr`,
  `classification`, `evaluation`) only depends on `app/core`, `app/models`,
  `app/services` — never on each other. `app/api/*.py` is the sole
  composition layer, mirroring the Pipe-and-Filter model in Figure 3.
- **Schema**: `flutter_app/lib/services/firestore_paths.dart` and
  `backend/app/services/firestore_paths.py` are kept in lockstep as the
  single source of truth for collection names, both traceable back to
  Figure H-5.

## What's stubbed vs. what's real

Real and runnable today: Firestore schema + rules, FastAPI routing,
Firebase Auth wiring, Flutter navigation + role gating, the *shape* of the
recognition (Figure 7) and classification (Figure 9) algorithms.

Stubbed with `// TODO` / `# TODO`, because they need your trained model
weights and finalized taxonomy to be real: TrOCR LoRA adapter loading,
BERT fine-tuned checkpoint loading, the bracket-depth/column-alignment step
grouping heuristic, Cohen's Kappa computation, PDF report export, and the
actual retraining job trigger (Figure 11) — that one intentionally hands
off to an external job (Colab/CI), so it's a TODO by design, not an
oversight.

## Next steps once this compiles and runs end-to-end

1. Wire `_ConfigurationTab` and `_RunsTab` in `operations_screen.dart` to
   `BackendApi.startRun()` (file upload → `page_image_paths`).
2. Wire `_AnnotationTab` to pull the next unlabeled item and write an
   `AnnotatorLabelRecord`.
3. Wire `_AdjudicationTab` to query disagreeing `annotator_labels` pairs.
4. Replace the placeholder OCR/BERT checkpoints with your actual trained +
   registered versions once Phase 3 (Model Fine-Tuning) is done.
