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

-- =========================================================
-- PERSON AND TRAINER MANAGEMENT
-- Responsible: Bohdan Bohelskyi
-- =========================================================
-- This section inserts base identity records, trainers,
-- trainer specialization catalogue data, and trainer-to-specialization
-- assignments.
--
-- These records are also used as FK prerequisites by other modules:
-- class scheduling, membership management, and personal training.
--
-- Execution order follows FK dependencies:
--   persons
--   trainers
--   specializations
--   trainer_specializations
-- =========================================================

-- =========================================================
-- PERSONS
-- Base identity records shared by trainers and members.
-- The first 10 persons are used as trainers.
-- The remaining persons are available for other modules, such as members.
-- =========================================================

INSERT INTO gym.persons (first_name, last_name, email, phone, birth_date) VALUES
    ('Andrii',   'Kovalenko',  'andrii.kovalenko@example.com',  '+380501112233', '1985-03-15'),
    ('Maryna',   'Shevchenko', 'maryna.shevchenko@example.com', '+380672223344', '1990-07-22'),
    ('Dmytro',   'Bondarenko', 'dmytro.bondarenko@example.com', '+380933334455', '1988-11-04'),
    ('Olena',    'Tkachenko',  'olena.tkachenko@example.com',   '+380504445566', '1992-01-30'),
    ('Pavlo',    'Melnyk',     'pavlo.melnyk@example.com',      '+380675556677', '1987-06-18'),
    ('Ihor',     'Petrenko',   'ihor.petrenko@example.com',     '+380501234561', '1991-05-12'),
    ('Kateryna', 'Ivanenko',   'kateryna.ivanenko@example.com', '+380501234562', '1993-07-18'),
    ('Roman',    'Kravchenko', 'roman.kravchenko@example.com',  '+380501234563', '1989-09-21'),
    ('Svitlana', 'Bondar',     'svitlana.bondar@example.com',   '+380501234564', '1994-02-11'),
    ('Oleksii',  'Marchenko',  'oleksii.marchenko@example.com', '+380501234565', '1990-11-03'),
    ('Taras',    'Hrytsenko',  'taras.hrytsenko@example.com',   '+380501234566', '1985-01-10'),
    ('Natalia',  'Koval',      'natalia.koval@example.com',     '+380501234567', '1986-03-22'),
    ('Yurii',    'Savchenko',  'yurii.savchenko@example.com',   '+380501234568', '1982-08-15'),
    ('Oksana',   'Lysenko',    'oksana.lysenko@example.com',    '+380501234569', '1988-06-09'),
    ('Viktor',   'Tkachenko',  'viktor.tkachenko@example.com',  '+380501234570', '1984-04-27'),
    ('Anna',     'Moroz',      'anna.moroz@example.com',        '+380501234571', '1990-10-05'),
    ('Serhii',   'Polishchuk', 'serhii.polishchuk@example.com', '+380501234572', '1983-12-14'),
    ('Iryna',    'Melnyk',     'iryna.melnyk@example.com',      '+380501234573', '1987-05-30'),
    ('Denys',    'Shevchuk',   'denys.shevchuk@example.com',    '+380501234574', '1981-09-17'),
    ('Alina',    'Dovzhenko',  'alina.dovzhenko@example.com',   '+380501234575', '1992-07-25');

-- =========================================================
-- TRAINERS
-- Each trainer references one existing person.
-- person_id values 1–10 refer to the first 10 records inserted above.
-- =========================================================

INSERT INTO gym.trainers (person_id, hire_date) VALUES
   (1, '2020-01-15'),
   (2, '2019-06-01'),
   (3, '2021-03-10'),
   (4, '2022-08-20'),
   (5, '2023-02-01'),
   (6, '2020-04-11'),
   (7, '2021-07-01'),
   (8, '2018-11-20'),
   (9, '2022-03-15'),
   (10, '2019-09-01');

-- =========================================================
-- SPECIALIZATIONS
-- Catalogue of trainer qualification types.
-- 10 distinct specialization names.
-- =========================================================

INSERT INTO gym.specializations (specialization_name) VALUES
    ('Yoga'),
    ('HIIT'),
    ('Strength Training'),
    ('Pilates'),
    ('Spinning'),
    ('Boxing'),
    ('CrossFit'),
    ('Stretching'),
    ('Functional Training'),
    ('Rehabilitation Training');

-- =========================================================
-- TRAINER SPECIALIZATIONS
-- Many-to-many relationship between trainers and specializations.
-- Composite primary key prevents duplicate trainer-specialization pairs.
-- =========================================================

INSERT INTO gym.trainer_specializations (trainer_id, specialization_id) VALUES
    (1, 1),   -- Andrii Kovalenko: Yoga
    (1, 8),   -- Andrii Kovalenko: Stretching
    (2, 2),   -- Maryna Shevchenko: HIIT
    (2, 7),   -- Maryna Shevchenko: CrossFit
    (3, 5),   -- Dmytro Bondarenko: Spinning
    (3, 6),   -- Dmytro Bondarenko: Boxing
    (4, 4),   -- Olena Tkachenko: Pilates
    (5, 3),   -- Pavlo Melnyk: Strength Training
    (6, 9),   -- Ihor Petrenko: Functional Training
    (7, 10),  -- Kateryna Ivanenko: Rehabilitation Training
    (8, 1),   -- Roman Kravchenko: Yoga
    (9, 8),   -- Svitlana Bondar: Stretching
    (10, 3);  -- Oleksii Marchenko: Strength Training

-- =========================================================
-- CONSTRAINT VALIDATION FOR PERSON AND TRAINER MANAGEMENT
-- The statements below are intentionally commented out.
-- They can be uncommented one at a time to verify constraints.
-- =========================================================

-- persons.phone must contain only digits with optional leading +
-- Expected: CHECK constraint violation (ck_person_phone_format)
-- INSERT INTO gym.persons (first_name, last_name, email, phone, birth_date)
-- VALUES ('Invalid', 'Phone', 'invalid.phone@example.com', '+380ABC123', '1990-01-01');

-- persons.email must match the required email format
-- Expected: CHECK constraint violation (ck_person_email_format)
-- INSERT INTO gym.persons (first_name, last_name, email, phone, birth_date)
-- VALUES ('Invalid', 'Email', 'wrong-email-format', '+380509999999', '1990-01-01');

-- persons.phone must be unique
-- Expected: UNIQUE constraint violation on phone
-- INSERT INTO gym.persons (first_name, last_name, email, phone, birth_date)
-- VALUES ('Duplicate', 'Phone', 'duplicate.phone@example.com', '+380501112233', '1990-01-01');

-- persons.email must be unique
-- Expected: UNIQUE constraint violation on email
-- INSERT INTO gym.persons (first_name, last_name, email, phone, birth_date)
-- VALUES ('Duplicate', 'Email', 'andrii.kovalenko@example.com', '+380509999997', '1990-01-01');

-- persons.birth_date cannot be in the future
-- Expected: CHECK constraint violation (ck_person_birth_date)
-- INSERT INTO gym.persons (first_name, last_name, email, phone, birth_date)
-- VALUES ('Future', 'Birthdate', 'future.birthdate@example.com', '+380509999998', '2999-01-01');

-- trainers.person_id must reference an existing person
-- Expected: FOREIGN KEY violation (fk_trainer_person)
-- INSERT INTO gym.trainers (person_id, hire_date)
-- VALUES (999, '2024-01-01');

-- trainers.person_id must be unique
-- Expected: UNIQUE constraint violation on person_id
-- INSERT INTO gym.trainers (person_id, hire_date)
-- VALUES (1, '2024-01-01');

-- trainers.hire_date cannot be in the future
-- Expected: CHECK constraint violation (ck_trainer_hire_date)
-- INSERT INTO gym.trainers (person_id, hire_date)
-- VALUES (20, '2999-01-01');

-- specializations.specialization_name must be unique
-- Expected: UNIQUE constraint violation on specialization_name
-- INSERT INTO gym.specializations (specialization_name)
-- VALUES ('Yoga');

-- trainer_specializations composite primary key prevents duplicate pairs
-- Expected: PRIMARY KEY violation (trainer_id, specialization_id)
-- INSERT INTO gym.trainer_specializations (trainer_id, specialization_id)
-- VALUES (1, 1);

-- trainer_specializations.trainer_id must reference an existing trainer
-- Expected: FOREIGN KEY violation
-- INSERT INTO gym.trainer_specializations (trainer_id, specialization_id)
-- VALUES (999, 1);

-- trainer_specializations.specialization_id must reference an existing specialization
-- Expected: FOREIGN KEY violation
-- INSERT INTO gym.trainer_specializations (trainer_id, specialization_id)
-- VALUES (1, 999);

-- =========================================================
-- WHY UPDATE / DELETE SCRIPTS ARE NOT INCLUDED
-- =========================================================
-- persons and trainers are core identity records. In a real gym system,
-- these records should usually be preserved for history, reporting,
-- attendance, scheduling, and audit consistency.
--
-- specializations are catalogue records. If a specialization becomes obsolete,
-- it should normally be hidden or deactivated at the application level instead
-- of being deleted from the database.
--
-- trainer_specializations may be changed when a trainer gains or loses
-- a qualification. However, direct UPDATE or DELETE statements are not included
-- in this seed script because the inserted data is used as stable test data
-- by other modules.
--
-- Example of a possible qualification removal, commented out to preserve seed data:
-- DELETE FROM gym.trainer_specializations
-- WHERE trainer_id = 10 AND specialization_id = 3;


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
    (3, 3, 4, 'weekly',  '07:00', '2025-09-01', '2026-06-30'),  -- Spinning, Mon/Wed/Fri
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

-- =========================================================
-- MEMBERSHIP MANAGEMENT
-- Responsible: Oleh Svyrydenko
--
-- Covers:
-- - membership products
-- - member registration
-- - membership enrollment history
-- - class attendance tracking
-- =========================================================

-- =========================================================
-- MEMBERSHIPS
-- Versioned membership products.
-- 10 rows to satisfy assignment requirements.
-- =========================================================

INSERT INTO gym.memberships
(type, price, currency, valid_from, valid_to)
VALUES
('monthly', 800.00, 'UAH', '2023-01-01', '2023-12-31'),
('monthly', 1000.00, 'UAH', '2024-01-01', '2024-12-31'),
('monthly', 1200.00, 'UAH', '2025-01-01', NULL),

('yearly', 8000.00, 'UAH', '2023-01-01', '2023-12-31'),
('yearly', 9500.00, 'UAH', '2024-01-01', '2024-12-31'),
('yearly', 12000.00, 'UAH', '2025-01-01', NULL),

('premium', 15000.00, 'UAH', '2023-01-01', '2023-12-31'),
('premium', 18000.00, 'UAH', '2024-01-01', '2024-12-31'),
('premium', 22000.00, 'UAH', '2025-01-01', NULL),
('premium', 25000.00, 'UAH', '2026-01-01', NULL);

-- =========================================================
-- MEMBERS
-- Assumes person_id 1-10 are gym members.
-- =========================================================

INSERT INTO gym.members (person_id)
VALUES
(11),
(12),
(13),
(14),
(15),
(16),
(17),
(18),
(19),
(20);

-- =========================================================
-- MEMBERS_MEMBERSHIPS
-- Membership enrollment history.
-- =========================================================

INSERT INTO gym.members_memberships
(membership_id, member_id, start_date, end_date, discount)
VALUES
(3, 1, '2025-01-01', NULL, 0),
(6, 2, '2025-01-01', NULL, 5),
(9, 3, '2025-01-01', NULL, 10),
(3, 4, '2025-02-01', NULL, 0),
(6, 5, '2025-02-01', NULL, 15),
(9, 6, '2025-03-01', NULL, 0),
(3, 7, '2025-03-01', NULL, 20),
(6, 8, '2025-04-01', NULL, 0),
(9, 9, '2025-04-01', NULL, 5),
(3,10, '2025-05-01', NULL, 0);

-- =========================================================
-- ATTENDANCE
-- Uses class_schedule_id 1-12 created by Oleksandr.
-- =========================================================

INSERT INTO gym.attendance
(member_id, class_schedule_id, check_in_time, status)
VALUES
(1, 1, '2026-03-02 08:02:00+00', 'attended'),
(2, 1, '2026-03-02 08:05:00+00', 'attended'),
(3, 2, NULL, 'no_show'),
(4, 2, NULL, 'cancelled'),
(5, 3, '2026-04-08 10:01:00+00', 'attended'),
(6, 3, '2026-04-08 10:04:00+00', 'attended'),
(7, 4, NULL, 'cancelled'),
(8, 5, '2026-05-05 07:00:30+00', 'attended'),
(9, 6, NULL, 'booked'),
(10, 7, '2026-05-01 17:03:00+00', 'attended'),
(1, 8, NULL, 'booked'),
(2, 9, NULL, 'cancelled');

-- UPDATE and DELETE statements are provided as examples only.
-- They are commented out to preserve seed data consistency.

-- =========================================================
-- UPDATE EXAMPLES
-- =========================================================

-- UPDATE gym.members_memberships
--SET discount = 10
--WHERE member_id = 1;

--UPDATE gym.attendance
-- SET status = 'attended',
-- check_in_time = '2026-05-07 07:01:00+00'
-- WHERE attendance_id = 9;

-- =========================================================
-- DELETE EXAMPLE
-- =========================================================

-- DELETE FROM gym.attendance
-- WHERE attendance_id = 10;


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

-- Trainer leave records with valid date ranges.

INSERT INTO gym.trainer_leaves
(trainer_id, leave_type, start_date, end_date, status, notes)
VALUES
(1,  'vacation', '2024-01-15', '2024-01-22', 'approved', 'Winter vacation'),
(2,  'sick',     '2024-02-10', '2024-02-15', 'approved', 'Flu recovery'),
(3,  'personal', '2024-03-05', '2024-03-12', 'pending',  'Family matters'),
(4,  'vacation', '2024-04-10', '2024-04-17', 'approved', 'Spring break'),
(5,  'sick',     '2024-05-01', '2024-05-05', 'approved', 'Medical leave'),
(6,  'vacation', '2024-06-15', '2024-06-22', 'pending',  'Summer vacation'),
(7,  'personal', '2024-07-03', '2024-07-10', 'approved', 'Personal reasons'),
(8,  'vacation', '2024-08-01', '2024-08-08', 'approved', 'Annual holiday'),
(9,  'sick',     '2024-09-12', '2024-09-16', 'approved', 'Recovery period'),
(10, 'vacation', '2024-10-05', '2024-10-12', 'pending',  'Family trip');
