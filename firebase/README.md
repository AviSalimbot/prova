# PROVA — Firebase Setup

Covers the "Firebase" box in Figure H-1 (Firestore + Storage, Admin auth).

## 1. Create the project

```bash
npm install -g firebase-tools
firebase login
firebase projects:create prova-<yoursuffix>
```

## 2. Enable services (Firebase Console)

- **Authentication** → Sign-in method → enable Email/Password
  (Researcher/Operator, Annotator, Adjudicator all sign in this way per
  Figure H-2's User Roles panel).
- **Firestore Database** → create in Native mode, pick your region.
- **Storage** → enable, same region as Firestore.

## 3. Link this folder to the project

```bash
cd firebase
firebase use --add     # select prova-<yoursuffix>, alias it "default"
```

## 4. Deploy rules + indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## 5. Seed the `users` collection with roles

Rules key off `users/{uid}.role` being one of `operator` | `annotator` |
`adjudicator`. After each person creates an account via
Firebase Auth (or you create them in the console), add a matching doc:

```bash
# Example using the Firebase CLI's Firestore shell, or do this from the
# Administration > Admin tab once the app is running.
firebase firestore:set users/<uid> '{"email":"you@school.edu","role":"operator","status":"active"}'
```

## 6. Connect Flutter

From `flutter_app/`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=prova-<yoursuffix>
```

This writes real values into `flutter_app/lib/firebase_options.dart`.

## 7. Connect the Python backend

The backend uses the **Admin SDK**, which bypasses `firestore.rules`
entirely (that's expected — it's the trusted preprocessing/OCR/classifier
service). Generate a service account key:

Console → Project Settings → Service Accounts → Generate new private key,
save as `backend/serviceAccountKey.json` (already gitignored — never commit
it).

## Collections (must match `flutter_app/lib/services/firestore_paths.dart`
and `backend/app/models/schemas.py` exactly)

| Collection             | Mirrors ERD entity     |
|-------------------------|-------------------------|
| `users`                 | User                    |
| `exams`                 | Exam                    |
| `pages`                 | Page                    |
| `items`                 | Item                    |
| `runs`                  | Run                     |
| `results`               | Result                  |
| `annotator_labels`      | AnnotatorLabel          |
| `gold_standard_labels`  | GoldStandardLabel       |
| `reports`               | Report                  |
| `model_versions`        | Model Version           |
| `retraining_cycles`     | Retraining Cycle        |
| `logs`                  | Log                     |
| `participants`          | Participant             |
