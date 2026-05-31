-- ================================================================
-- SQL DML TEMPLATE (TOPIC 09)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) INSERT scripts for all required tables in your database.
-- 2) At least 10 records per table with meaningful, realistic values.
-- 3) UPDATE / DELETE scripts where they are relevant to business logic.
-- 4) If UPDATE / DELETE are not relevant for a table, add a short note
--    in documentation explaining why.
-- 5) Comments by section so the script is easy to read and run.
--
-- SCRIPT GOALS:
-- - Populate the database with usable test data.
-- - Validate constraints through realistic DML scenarios.
-- - Support the core functionality of your application.
--
-- RECOMMENDED ORDER:
-- 1) Reference data (lookups/dictionaries)
-- 2) Core entities
-- 3) Transactional data
-- 4) Optional UPDATE / DELETE checks
--
-- IMPORTANT:
-- - Use anonymized or privacy-safe sample data where possible.
-- - The script must execute in PostgreSQL.
-- - Submit this as one SQL file.
-- ================================================================

-- Add your DML below this line

-- TEMPORARY DATA FOR FK SATISFACTION
-- =========================================================
-- 1. PREREQUISITE DATA — persons & trainers
-- These tables are owned by another team member (Bohdan Bohelskyi).
-- We insert a minimal set here so that our scheduling tables
-- have valid trainer_id references.
-- =========================================================

INSERT INTO gym.persons (first_name, last_name, email, phone, birth_date) VALUES
    ('Andrii',   'Kovalenko',  'andrii.kovalenko@example.com',  '+380501112233', '1985-03-15'),
    ('Maryna',   'Shevchenko', 'maryna.shevchenko@example.com', '+380672223344', '1990-07-22'),
    ('Dmytro',   'Bondarenko', 'dmytro.bondarenko@example.com', '+380933334455', '1988-11-04'),
    ('Olena',    'Tkachenko',  'olena.tkachenko@example.com',   '+380504445566', '1992-01-30'),
    ('Pavlo',    'Melnyk',     'pavlo.melnyk@example.com',      '+380675556677', '1987-06-18');

INSERT INTO gym.trainers (person_id, hire_date) VALUES
    (1, '2020-01-15'),
    (2, '2019-06-01'),
    (3, '2021-03-10'),
    (4, '2022-08-20'),
    (5, '2023-02-01');


-- personal_training

-- Author - Andrew Chernuha
-- =========================================================
-- SEED DATA — PERSONAL TRAINING, WORK SCHEDULE, LEAVES
-- Generates realistic test data for trainer-related tables.
-- All values reference trainer_id 1–10 and member_id 1–10,
-- which must exist in gym.trainers and gym.members before running.
-- =========================================================

-- ---------------------------------------------------------
-- personal_training
-- 10 sessions, one per day starting from now.
-- member_id cycles 1–10, trainer_id rotates across 1–3
-- to avoid uq_trainer_time unique constraint conflicts.
-- Status is assigned randomly from all three lifecycle values.
-- ---------------------------------------------------------
INSERT INTO gym.personal_training (member_id, trainer_id, training_date, status)
SELECT
    i                                                                         AS member_id,
    i                                                                         AS trainer_id,
    NOW() + (i * INTERVAL '1 day')                                            AS training_date,
    (ARRAY['scheduled','completed','cancelled']::gym.personal_training_status[])[floor(random() * 3 + 1)::int] AS status
FROM generate_series(1, 10) AS i; 

-- Author - Andrew Chernuha
-- ---------------------------------------------------------
-- trainer_work_schedule
-- Generates 5 weekday rows (mon–fri) for each of the 10 trainers.
-- All trainers share the same shift: 09:00–18:00.
-- uq_trainer_day prevents duplicate days per trainer,
-- so this insert is safe to run only once.
-- ---------------------------------------------------------
INSERT INTO gym.trainer_work_schedule (trainer_id, day_of_week, start_time, end_time, is_active)
SELECT
    trainer_id,
    day_of_week,
    '09:00'::TIME,
    '18:00'::TIME,
    TRUE
FROM
    generate_series(1, 10) AS trainer_id,
    UNNEST(ARRAY['mon','tue','wed','thu','fri']::gym.day_of_week[]) AS day_of_week;

-- Author - Andrew Chernuha
-- ---------------------------------------------------------
-- trainer_leaves
-- 2 leave requests per trainer = 20 rows total.
-- start_date is random within 2024.
-- end_date is always start_date + 7 days.
-- Note: random() is evaluated per row, so start_date and end_date
-- are independent — chk_leaves_date_range guarantees end >= start.
-- leave_type and status are assigned randomly.
-- ---------------------------------------------------------
INSERT INTO gym.trainer_leaves (trainer_id, leave_type, start_date, end_date, status, notes)
SELECT
    trainer_id,
    (ARRAY['sick','vacation','personal']::gym.leave_type[])[floor(random() * 3 + 1)::int],
    (DATE '2024-01-01' + (random() * 300)::int * INTERVAL '1 day')::date,
    (DATE '2024-01-01' + (random() * 300)::int * INTERVAL '1 day' + INTERVAL '7 days')::date,
    (ARRAY['pending','approved','rejected']::gym.leave_status[])[floor(random() * 3 + 1)::int],
    'Auto-generated leave'
FROM generate_series(1, 10) AS trainer_id,
     generate_series(1, 2);


-- =========================================================
-- CLASS AND SCHEDULING MANAGEMENT
-- Responsible: Oleksandr Chura
-- =========================================================
-- This script inserts data into the Class and Scheduling
-- Management tables and their FK prerequisites. It also includes
-- statements that demonstrate constraint enforcement.
--
-- Execution order follows FK dependencies:
--   rooms
--   class_templates
--   class_recurrence_rules
--   rule_week_days & rule_month_days
--   class_schedule
--   Constraint validation for CLASS AND SCHEDULING MANAGEMENT tables
-- =========================================================

-- =========================================================
-- ROOMS
-- Physical spaces where classes take place.
-- 10 rooms with varied capacities; one room has NULL capacity
-- (open-air area with no fixed limit).
-- =========================================================

INSERT INTO gym.rooms (name, capacity) VALUES
    ('Main Hall',           40),
    ('Studio A',            20),
    ('Studio B',            15),
    ('Cycling Room',        25),
    ('Yoga Studio',         18),
    ('Boxing Ring',         12),
    ('Pool Area',           30),
    ('Outdoor Terrace',     NULL),  -- no fixed capacity limit
    ('Small Group Room',     8),
    ('Functional Zone',     22);

-- =========================================================
-- CLASS TEMPLATES
-- Catalogue of class types offered by the gym.
-- 10 distinct class types.
-- =========================================================

INSERT INTO gym.class_templates (class_name, description, duration_minutes, capacity) VALUES
    ('Yoga',            'Hatha yoga for all levels',                         60,  NULL),
    ('HIIT',            'High-intensity interval training',                  45,  20),
    ('Spinning',        'Indoor cycling cardio workout',                     50,  25),
    ('Pilates',         'Core-strengthening mat Pilates',                    55,  15),
    ('Zumba',           'Dance fitness set to Latin music',                  60,  30),
    ('CrossFit',        'Functional movements at high intensity',            60,  16),
    ('Boxing Basics',   'Beginner-friendly boxing techniques and drills',    60,  12),
    ('Stretching',      'Full-body flexibility and recovery session',        30,  NULL),
    ('Aqua Aerobics',   'Low-impact water-based exercises',                 45,  28),
    ('TRX Suspension',  'Bodyweight exercises using suspension trainers',    45,  10);

-- =========================================================
-- CLASS RECURRENCE RULES
-- 10 rules that define repeating class assignments.
-- Covers all three frequency types: daily, weekly, monthly.
-- =========================================================

INSERT INTO gym.class_recurrence_rules (class_id, trainer_id, room_id, frequency, start_time, start_date, end_date) VALUES
    -- Weekly rules (rule_id 1–5)
    (1, 1, 5, 'weekly',  '08:00', '2025-09-01', '2026-06-30'),  -- Yoga, Mon/Wed/Fri
    (2, 2, 1, 'weekly',  '10:00', '2025-09-01', '2026-06-30'),  -- HIIT, Tue/Thu
    (3, 3, 4, 'weekly',  ('07:00', '2025-09-01', '2026-06-30'),  -- Spinning, Mon/Wed/Fri
    (4, 4, 2, 'weekly',  '18:00', '2025-09-01', '2026-06-30'),  -- Pilates, Tue/Thu/Sat
    (5, 5, 1, 'weekly',  '19:00', '2025-09-01', '2026-06-30'),  -- Zumba, Wed/Fri

    -- Daily rules (rule_id 6–7)
    (8, 1, 2, 'daily',   '06:30', '2025-10-01', '2025-12-31'),  -- Stretching, every day
    (6, 2, 10, 'daily',  '12:00', '2025-10-01', '2025-12-31'),  -- CrossFit, every day

    -- Monthly rules (rule_id 8–10)
    (7, 3, 6, 'monthly', '17:00', '2025-09-01', '2026-06-30'),  -- Boxing Basics, 1st & 15th
    (9, 4, 7, 'monthly', '09:00', '2025-09-01', '2026-06-30'),  -- Aqua Aerobics, 5th & 20th
    (10, 5, 9, 'monthly', '16:00', '2025-09-01', '2026-06-30'); -- TRX, 10th & 25th

-- =========================================================
-- RULE WEEK DAYS
-- Day-of-week assignments for the 5 weekly recurrence rules.
-- =========================================================

INSERT INTO gym.rule_week_days (rule_id, day_of_week) VALUES
    -- Rule 1: Yoga on Mon/Wed/Fri
    (1, 'mon'), (1, 'wed'), (1, 'fri'),
    -- Rule 2: HIIT on Tue/Thu
    (2, 'tue'), (2, 'thu'),
    -- Rule 3: Spinning on Mon/Wed/Fri
    (3, 'mon'), (3, 'wed'), (3, 'fri'),
    -- Rule 4: Pilates on Tue/Thu/Sat
    (4, 'tue'), (4, 'thu'), (4, 'sat'),
    -- Rule 5: Zumba on Wed/Fri
    (5, 'wed'), (5, 'fri');

-- =========================================================
-- RULE MONTH DAYS
-- Day-of-month assignments for the 3 monthly recurrence rules.
-- =========================================================

INSERT INTO gym.rule_month_days (rule_id, day_of_month) VALUES
    -- Rule 8: Boxing Basics on 1st and 15th
    (8, 1),  (8, 15),
    -- Rule 9: Aqua Aerobics on 5th and 20th
    (9, 5),  (9, 20),
    -- Rule 10: TRX on 10th and 25th
    (10, 10), (10, 25);

-- =========================================================
-- CLASS SCHEDULE
-- Materialized individual sessions generated from recurrence rules.
-- 12 sessions across different rules, statuses, and dates.
-- All timestamps in UTC. Current date assumed: 2026-06-01.
-- Past sessions use completed/cancelled, future ones use scheduled.
-- =========================================================

INSERT INTO gym.class_schedule (rule_id, class_id, trainer_id, room_id, start_datetime, end_datetime, status) VALUES
    -- Past sessions (completed / cancelled)
    -- From rule 1: Yoga (60 min) in Yoga Studio
    (1, 1, 1, 5, '2026-03-02 08:00:00+00', '2026-03-02 09:00:00+00', 'completed'),
    (1, 1, 1, 5, '2026-03-04 08:00:00+00', '2026-03-04 09:00:00+00', 'completed'),
    -- From rule 2: HIIT (45 min) in Main Hall
    (2, 2, 2, 1, '2026-04-08 10:00:00+00', '2026-04-08 10:45:00+00', 'completed'),
    (2, 2, 2, 1, '2026-04-10 10:00:00+00', '2026-04-10 10:45:00+00', 'cancelled'),
    -- From rule 3: Spinning (50 min) in Cycling Room
    (3, 3, 3, 4, '2026-05-05 07:00:00+00', '2026-05-05 07:50:00+00', 'completed'),
    (3, 3, 3, 4, '2026-05-07 07:00:00+00', '2026-05-07 07:50:00+00', 'completed'),
    -- From rule 8: Boxing Basics (60 min) on the 1st — monthly
    (8, 7, 3, 6, '2026-05-01 17:00:00+00', '2026-05-01 18:00:00+00', 'completed'),

    -- Future sessions (scheduled)
    -- From rule 4: Pilates (55 min) in Studio A
    (4, 4, 4, 2, '2026-06-02 18:00:00+00', '2026-06-02 18:55:00+00', 'scheduled'),
    -- From rule 5: Zumba (60 min) in Main Hall
    (5, 5, 5, 1, '2026-06-04 19:00:00+00', '2026-06-04 20:00:00+00', 'scheduled'),
    -- From rule 6: Stretching (30 min) in Studio A — daily
    (6, 8, 1, 2, '2026-06-02 06:30:00+00', '2026-06-02 07:00:00+00', 'scheduled'),
    -- From rule 9: Aqua Aerobics (45 min) on the 5th — monthly
    (9, 9, 4, 7, '2026-06-05 09:00:00+00', '2026-06-05 09:45:00+00', 'scheduled'),
    -- From rule 10: TRX (45 min) on the 10th — monthly
    (10, 10, 5, 9, '2026-06-10 16:00:00+00', '2026-06-10 16:45:00+00', 'scheduled');

-- =========================================================
-- CONSTRAINT VALIDATION (uncommented to test constraints)
-- The statements below are intentionally invalid and should be (commented out)
-- run one at a time to verify that each constraint
-- correctly rejects bad data. Expected errors are noted.
-- =========================================================

-- rooms.capacity must be > 1
-- Expected: CHECK constraint violation (capacity > 1)
-- INSERT INTO gym.rooms (name, capacity) VALUES ('Closet', 1);

-- rooms.capacity = 0 is also invalid
-- Expected: CHECK constraint violation (capacity > 1)
-- INSERT INTO gym.rooms (name, capacity) VALUES ('Phone Booth', 0);

-- class_templates.duration_minutes must be > 0
-- Expected: CHECK constraint violation (duration_minutes > 0)
-- INSERT INTO gym.class_templates (class_name, duration_minutes) VALUES ('Invalid Class', 0);

-- class_templates.class_name must be unique
-- Expected: UNIQUE constraint violation on class_name
-- INSERT INTO gym.class_templates (class_name, duration_minutes) VALUES ('Yoga', 60);

-- class_templates.capacity must be > 1 when provided
-- Expected: CHECK constraint violation (capacity > 1)
-- INSERT INTO gym.class_templates (class_name, duration_minutes, capacity) VALUES ('Private Session', 30, 1);

-- class_recurrence_rules.end_date must be >= start_date
-- Expected: CHECK constraint violation (chk_recurrence_rules_date_range)
-- INSERT INTO gym.class_recurrence_rules (class_id, trainer_id, room_id, frequency, start_time, start_date, end_date)
--     VALUES (1, 1, 1, 'weekly', '10:00', '2026-06-01', '2026-01-01');

-- rule_month_days.day_of_month must be between 1 and 31
-- Expected: CHECK constraint violation (chk_rule_month_days_range)
-- INSERT INTO gym.rule_month_days (rule_id, day_of_month) VALUES (8, 32);

-- rule_month_days.day_of_month = 0 is invalid
-- Expected: CHECK constraint violation (chk_rule_month_days_range)
-- INSERT INTO gym.rule_month_days (rule_id, day_of_month) VALUES (8, 0);

-- class_schedule.end_datetime must be > start_datetime
-- Expected: CHECK constraint violation (chk_class_schedule_datetime_range)
-- INSERT INTO gym.class_schedule (rule_id, class_id, trainer_id, room_id, start_datetime, end_datetime, status)
--     VALUES (1, 1, 1, 5, '2025-09-10 08:00:00+00', '2025-09-10 08:00:00+00', 'scheduled');

-- Foreign key violation — nonexistent trainer_id
-- Expected: FK violation (fk_recurrence_rules_trainer)
-- INSERT INTO gym.class_recurrence_rules (class_id, trainer_id, room_id, frequency, start_time, start_date, end_date)
--     VALUES (1, 999, 1, 'weekly', '10:00', '2025-09-01', '2026-06-30');

-- Foreign key violation — nonexistent room_id
-- Expected: FK violation (fk_class_schedule_room)
-- INSERT INTO gym.class_schedule (rule_id, class_id, trainer_id, room_id, start_datetime, end_datetime, status)
--     VALUES (1, 1, 1, 999, '2025-09-10 08:00:00+00', '2025-09-10 09:00:00+00', 'scheduled');

-- Duplicate composite PK in rule_week_days
-- Expected: PRIMARY KEY violation (rule_id, day_of_week)
-- INSERT INTO gym.rule_week_days (rule_id, day_of_week) VALUES (1, 'mon');

-- =========================================================
-- WHY UPDATE / DELETE SCRIPTS ARE NOT INCLUDED
-- =========================================================
-- The tables above are catalogue and scheduling data:
--
-- rooms, class_templates:
--   These are reference/catalogue tables. In normal operation their
--   rows are created once and rarely modified. Deletions are handled
--   at the application level (soft-delete or deactivation), not via
--   raw SQL. Updates (e.g. renaming a room) are trivial single-column
--   changes that do not exercise any meaningful constraint logic.
--
-- class_recurrence_rules, rule_week_days, rule_month_days:
--   Recurrence rules are defined once and generate sessions via a
--   background job. Modifying a rule mid-cycle would require
--   regenerating future sessions — an application-level operation,
--   not a raw DML concern.
--
-- class_schedule:
--   Status transitions (scheduled → completed, scheduled → cancelled)
--   are operational actions driven by the application. The constraint
--   checks that matter (datetime range, FK integrity) are fully
--   tested by the insertion and constraint-validation sections above.

-- ================================================================
-- Tables: equipment, goals, progress
-- Author:   Dmytro Tokariev
-- ================================================================
-- Description:
--   This script populates the database with realistic test data.
--   Each table has at least 10 records.
--   Includes INSERT and UPDATE operations.
-- ================================================================

-- ================================================================
-- SECTION 1: EQUIPMENT TABLE
-- Stores fitness center equipment inventory
-- Records added: 11
-- Fields: name, status, last_maintenance
-- ================================================================

INSERT INTO gym.equipment (name, status, last_maintenance) VALUES
    ('Treadmill X1', 'available', '2025-04-15'),
    ('Treadmill X2', 'available', '2025-04-15'),
    ('Elliptical E5', 'under_repair', '2025-03-01'),
    ('Elliptical E6', 'available', '2025-05-10'),
    ('Stationary Bike B7', 'available', '2025-04-20'),
    ('Stationary Bike B8', 'broken', '2025-02-15'),
    ('Rowing Machine R3', 'available', '2025-05-01'),
    ('Rowing Machine R4', 'under_repair', '2025-04-01'),
    ('Dumbbell Set 20kg', 'available', '2025-05-12'),
    ('Dumbbell Set 30kg', 'available', '2025-05-12'),
    ('Toorx Station CSX70', 'available', '2025-04-15');

-- ================================================================
-- SECTION 2: GOALS TABLE
-- Stores fitness goals set by members
-- Dependencies: member_id references gym.members
-- Records added: 10
-- Fields: member_id, goal_description, target_value, deadline, status, created_at
-- ================================================================

INSERT INTO gym.goals (member_id, goal_description, target_value, deadline, status, created_at) VALUES
    (1, 'Lose weight before summer', '75 kg', '2025-07-01', 'in_progress', '2025-01-10'),
    (1, 'Increase pull-ups', '10 reps', '2025-08-15', 'in_progress', '2025-02-01'),
    (1, 'Improve running endurance', '5 km in 25 min', '2025-09-30', 'in_progress', '2025-02-15'),
    (2, 'Build muscle mass', '85 kg body weight', '2025-12-31', 'in_progress', '2025-01-20'),
    (2, 'Master handstand', '30 seconds', '2025-10-01', 'in_progress', '2025-03-01'),
    (3, 'Recover from injury', 'Pain-free running', '2025-06-15', 'completed', '2024-12-01'),
    (3, 'Strengthen core', '100 sit-ups in one set', '2025-08-01', 'in_progress', '2025-01-05'),
    (4, 'Prepare for marathon', '42 km in 4 hours', '2025-11-15', 'in_progress', '2025-01-10'),
    (4, 'Improve flexibility', 'Full split', '2025-12-01', 'abandoned', '2025-01-15'),
    (5, 'Reduce stress', 'Meditate daily 15 min', '2025-06-01', 'completed', '2025-01-01');

-- ================================================================
-- SECTION 3: PROGRESS TABLE
-- Tracks progress check-ins against goals
-- Dependencies: goal_id references gym.goals
-- Records added: 17
-- Fields: goal_id, current_state, notes, check_date
-- ================================================================

INSERT INTO gym.progress (goal_id, current_state, notes, check_date) VALUES
    -- Progress for goal_id = 1 (Lose weight)
    (1, '78 kg', 'First measurement', '2025-02-01'),
    (1, '76.5 kg', 'Steady progress', '2025-03-01'),
    (1, '75.5 kg', 'Almost there', '2025-04-01'),
    
    -- Progress for goal_id = 2 (Pull-ups)
    (2, '5 reps', 'Starting point', '2025-02-10'),
    (2, '7 reps', 'Improving', '2025-03-15'),
    (2, '8 reps', 'Need more training', '2025-04-10'),
    
    -- Progress for goal_id = 3 (Running endurance)
    (3, '5 km in 32 min', 'Baseline', '2025-03-01'),
    (3, '5 km in 29 min', 'Good progress', '2025-04-01'),
    
    -- Progress for goal_id = 4 (Muscle mass)
    (4, '78 kg', 'Starting weight', '2025-02-01'),
    (4, '80 kg', '+2 kg muscle', '2025-03-01'),
    (4, '82 kg', 'Good bulk', '2025-04-01'),
    
    -- Progress for goal_id = 5 (Handstand)
    (5, '5 seconds', 'Learning to balance', '2025-03-15'),
    (5, '15 seconds', 'Getting better', '2025-04-15'),
    
    -- Progress for goal_id = 6 (Injury recovery - completed goal)
    (6, 'Pain-free walking', 'Recovery milestone', '2025-02-01'),
    (6, 'Pain-free running', 'Goal achieved', '2025-05-01');

-- ================================================================
-- SECTION 4: EQUIPMENT TABLE - UPDATES
-- Table: gym.equipment
-- Operation: UPDATE status after maintenance/repair is completed
-- Scenario: Equipment that was broken/under_repair is now available
-- ================================================================

-- 4.1 Update: Stationary Bike B8 was broken, now repaired and available
UPDATE gym.equipment
SET status = 'available', 
    last_maintenance = '2026-04-20'
WHERE name = 'Stationary Bike B8' AND status = 'broken';

-- 4.2 Update: Rowing Machine R4 was under repair, now available
UPDATE gym.equipment 
SET status = 'available', 
    last_maintenance = '2026-05-25'
WHERE name = 'Rowing Machine R4' AND status = 'under_repair';

-- 4.3 Update: Elliptical E5 was under repair, now available
UPDATE gym.equipment
SET status = 'available', 
    last_maintenance = '2026-04-20'
WHERE name = 'Elliptical E5' AND status = 'under_repair';

-- ================================================================
-- SECTION 5: CONSTRAINT TESTS (commented)
-- These demonstrate that all constraints work as expected
-- ================================================================

-- 5.1 ENUM constraint on equipment.status
-- This would fail: status 'new' is not in ENUM {'available','under_repair','broken'}
-- INSERT INTO gym.equipment (name, status) VALUES ('Test Machine', 'new');
-- Expected error: value for enum "equipment_status" is not in enum

-- 5.2 CHECK constraint on equipment.last_maintenance
-- This would fail: future date (2027) not allowed
-- INSERT INTO gym.equipment (name, status, last_maintenance) 
-- VALUES ('Test Machine', 'available', '2027-01-01');
-- Expected error: violates check constraint "chk_equipment_maintenance_not_future"

-- 5.3 CHECK constraint on goals.deadline
-- This would fail: year 1999 is before 2000
-- INSERT INTO gym.goals (member_id, goal_description, deadline) 
-- VALUES (1, 'Old goal', '1999-12-31');
-- Expected error: violates check constraint "chk_goals_deadline"

-- 5.4 UNIQUE constraint on progress (goal_id, check_date)
-- This would fail: duplicate check_date for same goal (goal_id=1, date=2025-04-01)
-- INSERT INTO gym.progress (goal_id, current_state, check_date) 
-- VALUES (1, '75 kg', '2025-04-01');
-- Expected error: duplicate key violates unique constraint "uq_progress_goal_date"

-- 5.5 FOREIGN KEY constraint on progress.goal_id
-- This would fail: goal_id 999 does not exist in goals table
-- INSERT INTO gym.progress (goal_id, current_state, check_date) 
-- VALUES (999, 'Test', '2026-01-01');
-- Expected error: violates foreign key constraint "fk_progress_goal"

-- 5.6 FOREIGN KEY with CASCADE DELETE (demonstration)
-- This shows that ON DELETE CASCADE works (goal deletion removes progress)
-- Uncomment to test:
-- DELETE FROM gym.goals WHERE goal_id = 6;
-- SELECT * FROM gym.progress WHERE goal_id = 6; -- Would return 0 rows

-- ================================================================
-- WHY DELETE IS NOT INCLUDED
-- ================================================================
-- DELETE operations are omitted for the following reasons:
-- 1. Business context: Fitness centers PRESERVE historical data
--    - Deleted goals would break progress history charts
--    - Equipment maintenance logs must be kept for audits
--    - Member progress data is valuable for analytics
-- 2. CASCADE DELETE is already tested in SECTION 5 (constraints)
--    The foreign key ON DELETE CASCADE is demonstrated there
-- 3. Our application uses SOFT DELETE pattern
--    Status fields like 'abandoned', 'broken' indicate deletion
--    Actual DELETE from database is rarely used
