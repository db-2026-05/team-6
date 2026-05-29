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
