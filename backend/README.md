# PROVA — Python Backend

FastAPI service implementing the Preprocess / OCR (TrOCR) / Classifier
(BERT) / Evaluation boxes from Figure H-1, wired to Firestore via the Admin
SDK.

## Module -> Figure map

| Module                                   | Figure(s)                          |
|-------------------------------------------|--------------------------------------|
| `app/preprocessing/pipeline.py`            | Figure H-1 (Crop/Deskew/Denoise/Binarize/Resize), Figure H-6 |
| `app/ocr/recognition_algorithm.py`         | Figure 7 (Recognition algorithm)     |
| `app/ocr/trocr_service.py`                 | Figure 1, Figure 6                    |
| `app/classification/classification_algorithm.py` | Figure 9 (Classification algorithm) |
| `app/classification/bert_service.py`       | Figure 2, Figure 8                    |
| `app/evaluation/evaluator.py`              | Figure 4, Figure 10                   |
| `app/api/runs.py`                          | Figure 3 (Pipe-and-Filter), Figure H-6 |
| `app/api/evaluation.py`                    | Figure 4 / 10                         |
| `app/api/retraining.py`, `model_versions.py` | Figure 11 (Retraining & promotion)  |

## Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate        
pip install -r requirements.txt

cp .env.example .env
# edit .env with your real Firebase project values

# Download your service account key (see /firebase/README.md step 7) and
# save it as backend/serviceAccountKey.json
```

## Run locally

```bash
uvicorn app.main:app --reload --port 8000
```

Visit `http://localhost:8000/docs` for the interactive OpenAPI UI — this
is the fastest way to test `/runs`, `/evaluation/{run_id}`,
`/model-versions/{id}/promote`, `/retraining-cycles` without the Flutter
app running yet.

## Notes on the placeholder ML code

- `ocr/trocr_service.py` and `classification/bert_service.py` load a base
  Hugging Face checkpoint and try to layer a LoRA/fine-tuned adapter from
  `MODEL_CACHE_DIR/<version_id>` on top. Until you've actually trained and
  registered a version there, they silently fall back to the un-adapted
  base checkpoint — fine for wiring up the rest of the system end-to-end,
  not fine for real transcription/classification accuracy.
- `ocr/recognition_algorithm.py`'s `step_grouping` bracket-depth heuristic
  is a stub. Real bracket-depth + column-alignment detection is Phase 3
  (Model Fine-Tuning) work per your V-Model (Figure 12).
- `evaluation/evaluator.py`'s Cohen's Kappa in `api/evaluation.py` is
  hardcoded to `0.0` — that metric needs the two annotators' raw
  (pre-adjudication) labels, not gold-vs-predicted, so it belongs in the
  Annotation Workspace's "Compute Inter-Rater Reliability (Kappa)" use case
  (Figure H-2), not here.

## Modularity notes

- Each layer (`preprocessing`, `ocr`, `classification`, `evaluation`) only
  imports from `app/core`, `app/models`, `app/services` — never from each
  other directly. `app/api/*.py` is the only place that composes them.
- Firestore collection names live in `app/services/firestore_paths.py`,
  kept in lockstep with `flutter_app/lib/services/firestore_paths.dart`.
