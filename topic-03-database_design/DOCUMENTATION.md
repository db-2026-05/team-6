# Fitness Center Database

A relational database for managing a fitness center — memberships, classes, trainers, attendance, personal training, equipment, and member progress tracking.

---

## Table of Contents

- [Overview](#overview)
- [ER Diagram](#er-diagram)
- [Key Design Decisions](#key-design-decisions)
- [Known Constraints & Limitations](#known-constraints--limitations)

---
## ER Diagram
### [dbdiagram](https://dbdiagram.io/d/Fitness-Center-69fdce9f54a51d93d3cef0a1)


---
## Overview

### MVP Tables
| Table | Purpose |
|---|---|
| `persons` | Shared identity record for members and trainers |
| `members` | Members of the fitness center |
| `trainers` | Employed trainers |
| `memberships` | Versioned membership products (monthly, yearly, premium) |
| `members_memberships` | Records which membership a member signed up for |
| `class_templates` | Catalogue of class types (yoga, spinning, strength) |
| `class_recurrence_rules` | Repeating schedule rules per class/trainer/room |
| `rule_week_days` | Days of week for weekly recurrence rules |
| `rule_month_days` | Days of month for monthly recurrence rules |
| `class_schedule` | Materialized calendar instances generated from rules |
| `attendance` | Member presence at a specific session |
| `rooms` | Physical spaces in the center |

### Final Version Tables
| Table | Purpose |
|---|---|
| `equipment` | Equipment inventory |
| `specializations` | Catalogue of trainer specialization types |
| `trainer_specializations` | Many-to-many: which specializations a trainer holds |
| `trainer_work_schedule` | Regular weekly working hours per trainer |
| `trainer_leaves` | Leave requests (vacation, sick, personal) |
| `personal_training` | One-on-one sessions booked outside group schedule |
| `goals` | Fitness goals set by members |
| `progress` | Progress check-ins logged against a goal |

---

## 1. Core — Personal Data & Roles

### `persons`
The base identity table for every human in the system. No business logic lives here — only contact and identity data.

| Column | Type | Notes |
|---|---|---|
| `person_id` | integer | Primary key |
| `first_name` | varchar | Required |
| `last_name` | varchar | Required |
| `email` | varchar | Unique, required |
| `phone` | varchar | Optional |
| `birth_date` | date | Optional |

### `members`
Extends `persons` for people who hold or have held a gym membership. The separation from `persons` allows a person to be both a member and a trainer simultaneously, and provides a clean anchor for member-specific data.

| Column | Type | Notes |
|---|---|---|
| `member_id` | integer | Primary key |
| `person_id` | integer | FK → `persons`, unique (1-to-1) |

### `trainers`
Extends `persons` for employed trainers.

| Column | Type | Notes |
|---|---|---|
| `trainer_id` | integer | Primary key |
| `person_id` | integer | FK → `persons`, unique (1-to-1) |
| `hire_date` | date | Optional |

**Design note:** `persons` is never used directly as a foreign key target by business tables — only `members` and `trainers` are referenced. This enforces role clarity: a booking always involves a *member*, not just any person.

---

## 2. Memberships

### `memberships`
Defines available membership products. **Prices are versioned by inserting new rows** — existing rows are never edited. This preserves a full price history and ensures historical `members_memberships` records always reflect the price that was active at signup.

| Column | Type | Notes |
|---|---|---|
| `membership_id` | integer | Primary key |
| `type` | varchar | e.g. `'monthly'`, `'yearly'`, `'premium'` |
| `price` | decimal | Required |
| `currency` | varchar | Required — e.g. `'PLN'`, `'EUR'`, `'USD'` |
| `valid_from` | date | Required — when this price version became active |
| `valid_to` | date | `NULL` means currently active |

### `members_memberships`
Tracks which membership product a member is enrolled in, and when. Supports full membership history per member — a member can have multiple rows over time (renewals, upgrades, lapses).

| Column | Type | Notes |
|---|---|---|
| `members_membership_id` | integer | Surrogate primary key |
| `membership_id` | integer | FK → `memberships` — points to the exact versioned product |
| `member_id` | integer | FK → `members` |
| `start_date` | date | When this enrollment began |
| `end_date` | date | `NULL` for open-ended memberships |
| `discount` | integer | Percentage discount applied at signup, e.g. `10` = 10% off |

> **Design note:** Because `membership_id` points to a specific versioned product row (which never changes), the price a member paid is implicitly snapshotted.

---

## 3. Scheduling & Attendance

The scheduling system uses a **three-layer model** that separates *what a class is*, *when it repeats*, and *which specific instances exist on the calendar*.

```
class_templates               — What is this class?
       ↓
class_recurrence_rules        — Who runs it, when, how often?
+ rule_week_days              — On which days of the week? (weekly rules)
+ rule_month_days             — On which days of the month? (monthly rules)
       ↓
class_schedule                — Materialized individual sessions
       ↓
attendance                    — Who showed up?
```

### `class_templates`
The catalogue of class types. One row per class type — no scheduling data lives here.

| Column | Type | Notes |
|---|---|---|
| `class_id` | integer | Primary key |
| `class_name` | varchar | Required |
| `description` | text | Optional |
| `duration_minutes` | integer | Default session length |
| `capacity` | integer | Max members per session |

### `class_recurrence_rules`
Defines a repeating assignment: a specific trainer runs a specific class in a specific room on a recurring pattern. Multiple rules can exist for the same template (e.g. Anna teaches Yoga on mornings, Tomek on evenings).

| Column | Type | Notes |
|---|---|---|
| `rule_id` | integer | Primary key |
| `class_id` | integer | FK → `class_templates` |
| `trainer_id` | integer | FK → `trainers` |
| `room_id` | integer | FK → `rooms` |
| `frequency` | varchar | `'daily'`, `'weekly'`, or `'monthly'` |
| `start_time` | time | Time of day the class starts |
| `start_date` | date | First date the rule is active |
| `end_date` | date | Last date the rule is active |

### `rule_week_days`
Stores the days of the week for weekly recurrence rules. One row per day per rule. Only populated when `frequency = 'weekly'`.

| Column | Type | Notes |
|---|---|---|
| `rule_id` | integer | FK → `class_recurrence_rules` (cascade delete) |
| `day_of_week` | varchar | `'MON'`, `'TUE'`, `'WED'`, `'THU'`, `'FRI'`, `'SAT'`, `'SUN'` |
| *(composite PK)* | | `(rule_id, day_of_week)` |

A class running on Monday and Wednesday has two rows pointing to the same `rule_id` — one for `MON`, one for `WED`. This makes day-based queries clean and indexed, and naturally supports any number of days per rule.

### `rule_month_days`
Stores the days of the month for monthly recurrence rules. One row per day per rule. Only populated when `frequency = 'monthly'`.

| Column | Type | Notes |
|---|---|---|
| `rule_id` | integer | FK → `class_recurrence_rules` (cascade delete) |
| `day_of_month` | varchar | Day number, e.g. `'1'`, `'15'`, `'28'` |
| *(composite PK)* | | `(rule_id, day_of_month)` |

Using a separate table (rather than a single integer on the rule) means a monthly class can run on multiple days per month — e.g. the 1st and the 15th — with no schema change.

### `class_schedule`
Materialized individual calendar sessions generated from recurrence rules by a background job. Once generated, each session can be modified independently without touching the master rule — this is where cancellations and substitutions are recorded.

| Column              | Type      | Notes                                                                |
| ------------------- | --------- | -------------------------------------------------------------------- |
| `class_schedule_id` | integer   | Primary key                                                          |
| `rule_id`           | integer   | FK → `class_recurrence_rules` — the rule that generated this session |
| `class_id`          | integer   | FK → `class_templates` — may differ from rule if overridden          |
| `trainer_id`        | integer   | FK → `trainers` — may differ from rule if substitute                 |
| `room_id`           | integer   | FK → `rooms` — may differ from rule if room changed                  |
| `start_datetime`    | timestamp |                                                                      |
| `end_datetime`      | timestamp |                                                                      |
| `status`            | varchar   | `'Scheduled'`, `'Cancelled'`, `'Completed'`                          |
| `is_override`       | boolean   | `true` when this session intentionally differs from its rule         |
| `override_reason`   | varchar   | Human-readable explanation of the override                           |

**Design note:** `class_id`, `trainer_id`, and `room_id` are duplicated from the rule intentionally. When `is_override = false` they should match the rule exactly. When `is_override = true` they represent the actual values for that session (e.g. substitute trainer).

### `attendance`
Records each member's booking or presence at a specific session.

| Column              | Type      | Notes                                                |
| ------------------- | --------- | ---------------------------------------------------- |
| `attendance_id`     | integer   | Primary key                                          |
| `member_id`         | integer   | FK → `members`                                       |
| `class_schedule_id` | integer   | FK → `class_schedule`                                |
| `check_in_time`     | timestamp | `NULL` until the member physically checks in         |
| `status`            | varchar   | `'Booked'`, `'Attended'`, `'No-show'`, `'Cancelled'` |

---

## 4. Rooms & Equipment

### `rooms`
Physical spaces where classes and personal training take place. Referenced by scheduling tables to track where sessions occur.

| Column | Type | Notes |
|---|---|---|
| `room_id` | integer | Primary key |
| `name` | varchar | Required |
| `capacity` | integer | Max occupancy — useful for booking limit checks |

### `equipment`
Fitness equipment in the gym. Not directly tied to scheduling — used for maintenance tracking.

| Column             | Type    | Notes                                       |
| ------------------ | ------- | ------------------------------------------- |
| `equipment_id`     | integer | Primary key                                 |
| `name`             | varchar | Required                                    |
| `status`           | varchar | `'Available'`, `'Under Repair'`, `'Broken'` |
| `last_maintenance` | date    | Date of last service                        |

---

## 5. Trainer Management

### `specializations`
A catalogue of trainer qualification types (e.g. Yoga, HIIT, Spinning).

| Column                | Type    | Notes       |
| --------------------- | ------- | ----------- |
| `specialization_id`   | integer | Primary key |
| `specialization_name` | varchar | Required    |

### `trainer_specializations`
Many-to-many junction between trainers and specializations.

| Column              | Type    | Notes                             |
| ------------------- | ------- | --------------------------------- |
| `trainer_id`        | integer | FK → `trainers`                   |
| `specialization_id` | integer | FK → `specializations`            |
| *(composite PK)*    |         | `(trainer_id, specialization_id)` |

### `trainer_work_schedule`
Defines the regular weekly working hours for a trainer. Used by the application to validate that scheduled classes fall within a trainer's working hours.

| Column             | Type    | Notes                                           |
| ------------------ | ------- | ----------------------------------------------- |
| `work_schedule_id` | integer | Primary key                                     |
| `trainer_id`       | integer | FK → `trainers`                                 |
| `day_of_week`      | varchar | e.g. `'Monday'`                                 |
| `start_time`       | time    |                                                 |
| `end_time`         | time    |                                                 |
| `is_active`        | boolean | Allows disabling a day without deleting the row |

### `trainer_leaves`
Leave requests for trainers. The application should cross-reference this table when scheduling classes to flag conflicts.

| Column | Type | Notes |
|---|---|---|
| `leave_id` | integer | Primary key |
| `trainer_id` | integer | FK → `trainers` |
| `leave_type` | varchar | `'Sick'`, `'Vacation'`, `'Personal'` |
| `start_date` | date | |
| `end_date` | date | |
| `status` | varchar | `'Pending'`, `'Approved'`, `'Rejected'` |
| `notes` | text | Optional |

---

## 6. Goals & Progress

### `goals`
A fitness goal set by a member. Goals are deliberately flexible — `target_value` and `status` are free-form to accommodate any goal type (weight, distance, reps, habits).

| Column | Type | Notes |
|---|---|---|
| `goal_id` | integer | Primary key |
| `member_id` | integer | FK → `members` |
| `goal_description` | varchar | Human-readable description |
| `target_value` | varchar | The target to reach |
| `deadline` | date | Optional target date |
| `status` | varchar | e.g. `'In Progress'`, `'Completed'`, `'Abandoned'` |
| `created_at` | date | Defaults to `now()` |

### `progress`
A timestamped check-in entry against a goal. Multiple entries per goal build a progress timeline.

| Column | Type | Notes |
|---|---|---|
| `progress_id` | integer | Primary key |
| `goal_id` | integer | FK → `goals` |
| `current_state` | varchar | Current value or qualitative state |
| `notes` | text | Optional context |
| `check_date` | date | Defaults to `now()` |

---

## 7. Personal Training

### `personal_training`
One-on-one sessions between a member and a trainer, booked outside the group class system.

| Column | Type | Notes |
|---|---|---|
| `session_id` | integer | Primary key |
| `member_id` | integer | FK → `members` |
| `trainer_id` | integer | FK → `trainers` |
| `training_date` | timestamp | |
| `status` | varchar | e.g. `'Scheduled'`, `'Completed'`, `'Cancelled'` |

---

## Key Design Decisions

### Table inheritance for people
`persons` holds shared identity data. `members` and `trainers` extend it via a 1-to-1 FK. This means a person can hold both roles simultaneously, and role-specific data never pollutes the base table. All business tables reference `member_id` or `trainer_id`, never `person_id` directly.

### Versioned membership products
Rather than editing a `memberships` row when a price changes, a new row is inserted with a new `valid_from` date and the old row gets a `valid_to` date. `members_memberships` points to the exact product version a member enrolled with, so historical pricing is preserved without a `price_at_snapshot` column.

### Three-layer scheduling model
| Layer | Table | Purpose |
|---|---|---|
| 1 | `class_templates` | What the class is |
| 2 | `class_recurrence_rules` + `rule_week_days` / `rule_month_days` | When and how it repeats |
| 3 | `class_schedule` | Individual materialized sessions |

This separation means a single class type can have multiple recurring assignments (different trainers, rooms, times), and individual sessions can be modified (cancelled, substituted) without affecting the master rule.

### Recurrence days — two dedicated tables
Weekly and monthly day details live in separate tables rather than on the rule itself. `rule_week_days` holds day-of-week values (`'MON'`, `'WED'`) for weekly rules; `rule_month_days` holds day-of-month values (`'1'`, `'15'`) for monthly rules. Daily rules need neither. Keeping them separate prevents invalid combinations, makes each table self-documenting, and allows multiple days per rule in both cases without any schema change.

### Override tracking on sessions
When a `class_schedule` session deviates from its rule (substitute trainer, room change), `is_override = true` and `override_reason` is populated. The denormalized `trainer_id` and `room_id` columns on `class_schedule` then represent the *actual* values for that session, making reporting accurate without requiring rule joins.

---

## Known Constraints & Limitations

**Double-booking not enforced at DB level**
`personal_training` has no unique constraint preventing a trainer or member from being booked twice at the same time. This must be enforced at the application layer.

**`progress` requires a goal**
A progress check-in cannot exist without a parent `goals` row. Goalless measurements are not supported.

**`equipment` is not room-assigned**

**Leave approval has no approver**
`trainer_leaves` tracks a `status` but not who approved it.
