# Odd or Even - Deployment & Operations Guide

## 1. Prerequisites
- Flutter SDK 3.47+ & Dart SDK 3.13+
- Android Studio / Android SDK (Platform 34 / Build-Tools 34.0.0+)
- OpenJDK 17 or 21+
- Supabase Project (PostgreSQL 15+, Auth, Realtime enabled)

## 2. Environment Variables & App Configuration
Store configuration in compile-time environment variables (`--dart-define`):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```
Never commit service-role keys or production passwords into Git.

## 3. Database Migrations
Apply migrations in numerical order to the Supabase database using the Supabase CLI or PostgreSQL connection:
```bash
supabase db push
# Or manual execution in order:
# 1. supabase/migrations/00001_initial_schema.sql
# 2. supabase/migrations/00002_rls_security.sql
# 3. supabase/migrations/00003_rpc_functions.sql
```

## 4. Mobile Releases
### Android
```bash
flutter build apk --release
# Or App Bundle for Google Play:
flutter build appbundle --release
```

### iOS
```bash
flutter build ipa --release
```
