# PROVA — Docs

## `prototype/PROVA_Research_Tool.html`

Your existing React-based mockup, copied in unchanged. It's a **standalone
bundled HTML export** (self-extracting — the `<script>` at the top of the
file unpacks embedded assets on load), not a Flutter or backend artifact.
Open it directly in a browser to reference the intended UI/UX and dummy
data model while building out the real screens in `flutter_app/`.

It is **not wired to Firebase or the Python backend** — treat it as a
design reference, not a component to import into the Flutter app. The
`flutter_app/lib/features/*/presentation/*_screen.dart` files are where
you'll rebuild each of its views (Dashboard, Exams, Configuration, Runs,
Annotation, My Labels, Adjudication, Evaluation, Item Detail, Models,
Admin) against live Firestore data.

## `architecture/Proposal_Diagrams_Compiled.pdf`

Your compiled Figures 1–13 and H-1–H-6 from the proposal. Kept here as the
single source of truth every module in this repo cites back to (see the
docstrings/comments throughout `backend/app/` and `flutter_app/lib/`).
