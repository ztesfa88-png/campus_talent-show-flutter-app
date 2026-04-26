# 🎤 Campus Talent Show

A cross-platform Flutter application that lets university students discover campus performers, cast votes, submit feedback, and follow live leaderboards — all backed by Supabase.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [User Roles](#user-roles)
- [Screens](#screens)
- [Data Models](#data-models)
- [State Management](#state-management)
- [Routing](#routing)
- [Database & Backend](#database--backend)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Environment Setup](#environment-setup)

---

## Overview

Campus Talent Show is a full-stack Flutter app built for university talent events. Students browse and vote for performers, performers manage their profiles and track their scores, and admins control events, approve performers, and broadcast notifications — all in real time.

---

## Features

### Authentication
- Email + password sign-up and sign-in via Supabase Auth
- Role-based access: `admin`, `performer`, `student`
- Local admin account (no Supabase required for admin login)
- Password reset via email
- Persistent session across app restarts

### Student
- Browse all approved performers with search and talent-type filters
- Select active event from dropdown
- Vote for performers with a score of 1–5
- Submit written feedback with star rating
- Live leaderboard ranked by votes and average score
- Real-time notifications via Supabase Realtime
- Profile view with sign-out

### Performer
- Dashboard with total votes, average score, review count
- Register for upcoming events with performance title and description
- Portfolio management: bio, talent type, experience level, profile photo upload
- View own feedback and vote history
- Live results tab showing current rankings

### Admin
- Analytics dashboard: total users, votes, top performers, votes by category
- Approve or reject performer registrations
- Manage users (view all, filter by role)
- Create, activate, complete, and delete events
- Broadcast notifications to all users or by role
- Full event lifecycle control

### Realtime
- Live vote stream per event via Supabase Postgres Changes
- Live notification delivery to each user
- Event status updates pushed to all clients

### Offline Support
- SQLite cache via `sqflite` for events and performers
- Automatic fallback when network is unavailable
- Cache keyed by event, search term, and talent type

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter (Dart) |
| State Management | Riverpod (`flutter_riverpod`) |
| Navigation | GoRouter |
| Backend | Supabase (PostgreSQL + Auth + Realtime + Storage) |
| Local Cache | SQLite (`sqflite`) |
| Fonts | Inter via `google_fonts` |
| Image Handling | `image_picker` + `cached_network_image` |
| Connectivity | `connectivity_plus` |
| Persistence | `shared_preferences` |

---

## Architecture

The app follows a **feature-first + layered** architecture:

```
lib/
├── main.dart                        # Entry point — Supabase init, ProviderScope, BaseApp
├── core/
│   ├── providers/                   # Riverpod global providers
│   │   ├── auth_provider.dart       # AuthStateNotifier + AuthState
│   │   ├── app_data_provider.dart   # Events, performers, filter state
│   │   └── realtime_provider.dart   # Live vote/notification/event streams
│   ├── routing/
│   │   └── app_router.dart          # GoRouter with role-based redirect
│   ├── theme/
│   │   ├── app_colors.dart          # Design tokens (colors, gradients, shadows)
│   │   └── app_theme.dart           # Material 3 ThemeData
│   └── widgets/
│       └── base_app.dart            # MaterialApp.router root widget
├── data/
│   ├── models/                      # Pure Dart data classes
│   │   ├── user.dart
│   │   ├── performer.dart
│   │   ├── event.dart
│   │   ├── event_registration.dart
│   │   ├── vote.dart
│   │   ├── feedback.dart
│   │   └── notification.dart
│   └── services/                    # Data access layer
│       ├── auth_service.dart        # Supabase Auth + local admin
│       ├── app_data_service.dart    # Votes, feedback, notifications, SQLite cache
│       ├── event_service.dart       # Event CRUD + lifecycle + analytics
│       ├── feedback_service.dart    # Feedback CRUD + statistics
│       ├── hardened_voting_service.dart  # Rate-limited, validated voting
│       ├── image_service.dart       # Photo pick + Supabase Storage upload
│       ├── notification_service.dart     # Notification CRUD + broadcast
│       ├── ranking_service.dart     # Leaderboard computation
│       └── supabase_service.dart    # General Supabase CRUD helpers
└── presentation/
    ├── screens/
    │   ├── auth/
    │   │   ├── splash_screen.dart
    │   │   ├── onboarding_screen.dart
    │   │   ├── login_screen.dart
    │   │   └── register_screen.dart
    │   ├── admin/
    │   │   └── admin_app_shell.dart  # Dashboard, Performers, Users, Events, Admins tabs
    │   ├── performers/
    │   │   └── performer_app_shell.dart  # Dashboard, Alerts, Portfolio, Events, Results tabs
    │   └── student/
    │       └── student_app_shell.dart    # Home, Vote, Leaderboard, Notifications, Profile tabs
    └── widgets/
        ├── app_field.dart           # Shared text form field
        ├── app_background.dart      # Gradient background widget
        └── gradient_scaffold.dart   # Reusable scaffold + card + button widgets
```

---

## User Roles

| Role | Default Route | Capabilities |
|------|--------------|-------------|
| `admin` | `/admin` | Full control — events, performers, users, analytics, notifications |
| `performer` | `/performer` | Profile management, event registration, view own scores and feedback |
| `student` | `/student` | Browse performers, vote, submit feedback, view leaderboard |

Role is stored in the `users` table and resolved at login. GoRouter redirects each role to its own shell automatically.

> **Built-in admin account:** `admin@gmail.com` / `admin123` — authenticated locally, no Supabase call needed.

---

## Screens

### Auth Flow
| Screen | Route | Description |
|--------|-------|-------------|
| Splash | `/splash` | Animated logo, checks onboarding status |
| Onboarding | `/onboarding` | 3-page intro (Discover, Vote, Celebrate) |
| Login | `/login` | Email + password sign-in |
| Register | `/register` | Sign-up with name, email, password, role selection |

### Student Shell (5 tabs)
1. **Home** — performer cards with search, talent filter, event selector
2. **Vote** — cast score (1–5) for a performer in the active event
3. **Leaderboard** — ranked performers by votes and average score
4. **Notifications** — real-time notification feed
5. **Profile** — user info and sign-out

### Performer Shell (5 tabs)
1. **Dashboard** — stats (votes, avg score, reviews), upcoming events
2. **Notifications** — real-time alerts
3. **Portfolio** — profile photo upload, bio, talent type, experience level
4. **Events** — register/unregister for events
5. **Results** — live ranking and feedback received

### Admin Shell (5 tabs)
1. **Dashboard** — analytics, top performers, votes by category
2. **Performers** — approve/reject/delete with search and status filter
3. **Users** — all users with role filter
4. **Events** — create, activate, complete, delete events
5. **Admins** — admin management and broadcast notifications

---

## Data Models

```dart
User          { id, email, name, role, createdAt, updatedAt }
Performer     { id, email, name, role, bio, avatarUrl, talentType,
                experienceLevel, socialLinks, createdAt, updatedAt }
Event         { id, title, description, eventDate, endDate,
                registrationDeadline, votingDeadline, expiresAt,
                location, maxPerformers, votesPerUser, status,
                createdBy, createdAt, updatedAt }
EventRegistration { id, eventId, performerId, performanceTitle,
                    performanceDescription, durationMinutes,
                    status, submissionDate }
Vote          { id, eventId, userId, performerId, score, votedAt }
Feedback      { id, eventId, userId, performerId, rating,
                comment, isPublic, createdAt }
AppNotification { id, userId, title, message, type,
                  isRead, data, createdAt }
```

**Enums:**
- `UserRole`: `admin`, `performer`, `student`
- `TalentType`: `music`, `dance`, `comedy`, `drama`, `magic`, `other`
- `ExperienceLevel`: `beginner`, `intermediate`, `advanced`
- `EventStatus`: `upcoming`, `active`, `completed`, `cancelled`
- `RegistrationStatus`: `pending`, `approved`, `rejected`
- `NotificationType`: `info`, `success`, `warning`, `error`, `event_update`, `vote_reminder`

---

## State Management

Riverpod is used throughout with the following provider types:

```dart
Provider<T>                  // Services (AuthService, AppDataService, etc.)
StateProvider<T>             // Simple mutable state (PerformerFilter)
StateNotifierProvider        // Complex state machine (AuthState)
FutureProvider<T>            // Async data (events list, performers list)
StreamProvider<T>            // Live streams (realtime votes, notifications)
StreamProvider.family<T, A>  // Live stream with parameter (votes by eventId)
```

### Auth State Machine
```
initial (isInitializing: true)
    ↓ _initialize()
authenticated(user) | unauthenticated
    ↓ signIn() / signUp()
loading → authenticated(user) | error(message)
    ↓ signOut()
loading → unauthenticated
```

---

## Routing

GoRouter with a `redirect` callback that enforces role-based access on every navigation:

```
/splash       → SplashScreen
/onboarding   → OnboardingScreen
/login        → LoginScreen
/register     → RegisterScreen
/admin        → AdminAppShell        (role: admin only)
/performer    → PerformerAppShell    (role: performer only)
/student      → StudentAppShell      (role: student only)
```

Unauthenticated users are always redirected to `/login`. Authenticated users on auth routes are redirected to their role's home.

---

## Database & Backend

### Supabase Tables

| Table | Description |
|-------|-------------|
| `users` | All app users with role |
| `performers` | Performer profiles linked to users |
| `events` | Talent show events |
| `event_registrations` | Performer registrations per event |
| `votes` | Student votes with score |
| `feedback` | Written feedback with rating |
| `notifications` | In-app notifications per user |

### Voting Rules
- Score must be 1–5
- One vote per performer per event per user
- 15-second cooldown between votes
- Respects `events.votes_per_user` limit
- Checks `voting_deadline` and `expires_at`
- Enforced client-side and server-side via Supabase RLS + triggers

### Realtime Subscriptions
- `votes` table — new votes for a given event
- `notifications` table — new notifications for the current user
- `events` table — any event change (insert/update/delete)

### Storage
- Bucket: `avatars` — performer profile photos
- Path pattern: `avatars/{userId}.jpg`

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.1`
- Dart SDK `^3.11.1`
- A Supabase project with the schema applied

### 1. Clone the repo
```bash
git clone https://github.com/your-org/campus_talent_show.git
cd campus_talent_show
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure Supabase
Open `lib/main.dart` and replace with your project credentials:
```dart
await Supabase.initialize(
  url: 'https://YOUR_PROJECT_ID.supabase.co',
  anonKey: 'YOUR_ANON_KEY',
);
```

### 4. Apply the database schema
Run the SQL files in your Supabase SQL Editor in this order:
1. `supabase/production_schema_upgrade.sql`
2. `supabase/rls_policies.sql`

### 5. Run the app
```bash
# Web (recommended for development)
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

### 6. Default admin login
```
Email:    admin@gmail.com
Password: admin123
```
This account is authenticated locally — no Supabase row needed.

---

## Project Structure

```
campus_talent_show/
├── lib/                    # All Dart source code
├── supabase/               # SQL schema and RLS policies
├── assets/
│   └── icons/              # App icon
├── android/                # Android platform files
├── ios/                    # iOS platform files
├── web/                    # Web platform files
├── pubspec.yaml            # Dependencies
└── README.md
```

---

## Environment Setup

### Required Supabase Configuration

1. **Disable email confirmation** (for development):
   Supabase Dashboard → Authentication → Providers → Email → toggle off "Confirm email"

2. **Enable Realtime** on tables:
   Supabase Dashboard → Database → Replication → enable `votes`, `notifications`, `events`

3. **Create storage bucket**:
   Supabase Dashboard → Storage → New bucket → name: `avatars` → Public: true

4. **Apply the `handle_new_user` trigger** (if registration fails with DB error):
   ```sql
   CREATE OR REPLACE FUNCTION public.handle_new_user()
   RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public AS $$
   BEGIN
     INSERT INTO public.users(id, email, name, role, created_at, updated_at)
     VALUES (
       NEW.id, NEW.email,
       COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
       COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
       NOW(), NOW()
     )
     ON CONFLICT(id) DO UPDATE SET email = EXCLUDED.email, updated_at = NOW();
     RETURN NEW;
   END;
   $$;

   DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
   CREATE TRIGGER on_auth_user_created
     AFTER INSERT ON auth.users FOR EACH ROW
     EXECUTE FUNCTION public.handle_new_user();
   ```

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^2.6.1 | State management |
| `riverpod` | ^2.6.1 | Core Riverpod |
| `supabase_flutter` | ^2.8.4 | Backend, auth, realtime |
| `go_router` | ^14.8.1 | Declarative navigation |
| `google_fonts` | ^6.2.1 | Inter font |
| `shared_preferences` | ^2.3.5 | Local session persistence |
| `connectivity_plus` | ^6.1.4 | Network status |
| `sqflite` | ^2.4.2 | SQLite offline cache |
| `path_provider` | ^2.1.5 | File system paths |
| `path` | ^1.9.1 | Path utilities |
| `image_picker` | ^1.1.2 | Camera + gallery access |
| `cached_network_image` | ^3.4.1 | Cached image loading |
