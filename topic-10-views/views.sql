-- ================================================================
-- SQL VIEWS TEMPLATE (TOPIC 10)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) CREATE VIEW scripts for required view types:
--    - Horizontal view (select specific columns)
--    - Vertical view (filter specific rows)
--    - Mixed view (columns + row filters)
--    - Join-based view (multiple tables)
--    - Subquery-based view
--    - UNION-based view
--    - View based on another view
--    - Updatable view with WITH CHECK OPTION
--
-- 2) Comments before each view explaining:
--    - Purpose of the view
--    - How it supports your project design
--
-- 3) Optional demo SELECT statements to show view output.
--
-- RECOMMENDED ORDER:
-- 1) Simple views (horizontal / vertical / mixed)
-- 2) Join and subquery views
-- 3) UNION and layered views
-- 4) CHECK OPTION view
--
-- IMPORTANT:
-- - Script must execute in PostgreSQL without errors.
-- - Keep naming consistent and readable.
-- - Submit all views in this single SQL file.
-- ================================================================

-- Add your CREATE VIEW statements below this line

-- ================================================================
-- SQL VIEWS FOR CLASS & SCHEDULING MANAGEMENT
-- Author: Oleksandr Chura
-- ================================================================
-- Views built on top of the scheduling subsystem tables:
--   gym.rooms, gym.class_templates, gym.class_recurrence_rules,
--   gym.rule_week_days, gym.rule_month_days, gym.class_schedule
-- ================================================================


-- ================================================================
-- 1. HORIZONTAL VIEW — select specific columns
-- ================================================================
-- Purpose: Provides a simplified catalogue of class templates,
-- exposing only the name and duration. Useful for public-facing
-- timetable displays where internal IDs and capacity details
-- are irrelevant.
-- Relates to: gym.class_templates — strips implementation columns.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_class_catalogue AS
SELECT
    class_name,
    duration_minutes
FROM gym.class_templates;

-- Demo:
-- SELECT * FROM gym.v_class_catalogue;


-- ================================================================
-- 2. VERTICAL VIEW — filter specific rows
-- ================================================================
-- Purpose: Shows only class sessions that have been cancelled.
-- Operations staff use this to audit cancellation rates and
-- identify patterns (e.g. a trainer or room that causes frequent
-- cancellations).
-- Relates to: gym.class_schedule — filters rows by status.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_cancelled_sessions AS
SELECT *
FROM gym.class_schedule
WHERE status = 'cancelled';

-- Demo:
-- SELECT * FROM gym.v_cancelled_sessions;


-- ================================================================
-- 3. MIXED VIEW — column selection + row filtering
-- ================================================================
-- Purpose: Lists upcoming scheduled sessions with only the columns
-- relevant for a member-facing timetable: when and where.
-- Filters out cancelled and completed sessions so members only see
-- sessions they can still book.
-- Relates to: gym.class_schedule — combines column projection with
-- a status + date filter.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_upcoming_sessions AS
SELECT
    class_schedule_id,
    class_id,
    room_id,
    start_datetime,
    end_datetime
FROM gym.class_schedule
WHERE status = 'scheduled'
  AND start_datetime > NOW();

-- Demo:
-- SELECT * FROM gym.v_upcoming_sessions;


-- ================================================================
-- 4. JOIN VIEW — multiple tables
-- ================================================================
-- Purpose: Produces a human-readable timetable by joining
-- class_schedule with class_templates (for the class name),
-- rooms (for the room name), and trainers + persons (for the
-- trainer's full name). This is the primary query behind
-- the gym's public schedule display.
-- Relates to: gym.class_schedule, gym.class_templates, gym.rooms,
-- gym.trainers, gym.persons — combines scheduling data with
-- reference data from other subsystems.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_timetable AS
SELECT
    cs.class_schedule_id,
    ct.class_name,
    r.name AS room_name,
    p.first_name || ' ' || p.last_name AS trainer_name,
    cs.start_datetime,
    cs.end_datetime,
    cs.status
FROM gym.class_schedule cs
JOIN gym.class_templates ct ON ct.class_id   = cs.class_id
JOIN gym.rooms r ON r.room_id     = cs.room_id
JOIN gym.trainers t ON t.trainer_id  = cs.trainer_id
JOIN gym.persons p ON p.person_id   = t.person_id;

-- Demo:
-- SELECT * FROM gym.v_timetable
-- WHERE status = 'scheduled'
-- ORDER BY start_datetime;


-- ================================================================
-- 5. SUBQUERY VIEW — uses a subquery
-- ================================================================
-- Purpose: Shows rooms that are not assigned to any
-- scheduled session. Facility managers use this to identify
-- underutilised spaces that could be repurposed or added to the
-- timetable.
-- Relates to: gym.rooms, gym.class_schedule — the subquery checks
-- for the absence of any class_schedule row referencing the room.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_unused_rooms AS
SELECT
    room_id,
    name,
    capacity
FROM gym.rooms
WHERE room_id NOT IN (
    SELECT DISTINCT room_id
    FROM gym.class_schedule
    WHERE status = 'scheduled' AND start_datetime > NOW()
);

-- Demo:
-- SELECT * FROM gym.v_unused_rooms;


-- ================================================================
-- 6. UNION VIEW — combines two result sets
-- ================================================================
-- Purpose: Provides a single list of all scheduled and completed
-- sessions, tagged by their state. The front desk uses this for
-- a unified session log that covers both future bookings and
-- historical records.
-- Relates to: gym.class_schedule — UNION filters on two different
-- status values and labels them for easy distinction.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_session_log AS
SELECT
    class_schedule_id,
    class_id,
    trainer_id,
    room_id,
    start_datetime,
    end_datetime,
    'upcoming' AS session_category
FROM gym.class_schedule
WHERE status = 'scheduled'

UNION ALL

SELECT
    class_schedule_id,
    class_id,
    trainer_id,
    room_id,
    start_datetime,
    end_datetime,
    'past' AS session_category
FROM gym.class_schedule
WHERE status = 'completed';

-- Demo:
-- SELECT * FROM gym.v_session_log ORDER BY start_datetime DESC;


-- ================================================================
-- 7. VIEW ON VIEW — selects from another view
-- ================================================================
-- Purpose: Builds on v_timetable (view #4) to produce a compact
-- summary of upcoming sessions grouped by class name, showing
-- how many sessions are scheduled and when the next one starts.
-- Used on the gym's dashboard for a quick overview.
-- Relates to: gym.v_timetable — aggregates the detailed timetable
-- into a summary without re-joining the base tables.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_class_schedule_summary AS
SELECT
    class_name,
    COUNT(*)                  AS total_sessions,
    MIN(start_datetime)       AS next_session
FROM gym.v_timetable
WHERE status = 'scheduled' AND start_datetime > NOW()
GROUP BY class_name;

-- Demo:
-- SELECT * FROM gym.v_class_schedule_summary
-- ORDER BY next_session;


-- ================================================================
-- 8. UPDATABLE VIEW WITH CHECK OPTION
-- ================================================================
-- Purpose: Exposes only scheduled (not cancelled/completed) class
-- sessions so that staff can update session details (e.g. swap a
-- room or trainer) directly through the view. The CHECK OPTION
-- prevents an UPDATE from changing the status to anything other
-- than 'scheduled', which would move the row outside the view's
-- scope and bypass the intended workflow.
-- Relates to: gym.class_schedule — wraps a single table with a
-- WHERE filter and enforces it on writes.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_scheduled_sessions AS
SELECT
    class_schedule_id,
    rule_id,
    class_id,
    trainer_id,
    room_id,
    start_datetime,
    end_datetime,
    status
FROM gym.class_schedule
WHERE status = 'scheduled'
WITH CHECK OPTION;

-- Demo:
-- The following UPDATE succeeds because the row stays within the view:
-- UPDATE gym.v_scheduled_sessions
-- SET room_id = 2
-- WHERE class_schedule_id = 1;
--
-- The following UPDATE would fail because changing status to 'cancelled'
-- violates the CHECK OPTION (the row would leave the view):
-- UPDATE gym.v_scheduled_sessions
-- SET status = 'cancelled'
-- WHERE class_schedule_id = 1;


-- Task Andre Chernuha
-- =========================================================
-- VIEWS — PERSONAL TRAINING MANAGEMENT
-- RESPONSIBLE ANDREW CHERNUHA
--
-- Covers three tables:
--   gym.personal_training      — one-on-one sessions
--   gym.trainer_work_schedule  — weekly working hours
--   gym.trainer_leaves         — leave requests
-- =========================================================


-- =========================================================
-- 1. HORIZONTAL VIEW
-- Shows only selected columns from personal_training.
-- Hides internal IDs — useful for public-facing reports
-- where session_id is not relevant.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_personal_training_public AS
SELECT
    member_id,
    trainer_id,
    training_date,
    status
FROM gym.personal_training;

-- Sample query
-- SELECT * FROM gym.v_personal_training_public;


-- =========================================================
-- 2. VERTICAL VIEW
-- Shows only scheduled (upcoming) personal training sessions.
-- Filters out completed and cancelled rows.
-- Useful for dashboard widgets showing what's coming up.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_personal_training_upcoming AS
SELECT
    session_id,
    member_id,
    trainer_id,
    training_date,
    status
FROM gym.personal_training
WHERE status = 'scheduled'
  AND training_date >= NOW();

-- Sample query
-- SELECT * FROM gym.v_personal_training_upcoming ORDER BY training_date;


-- =========================================================
-- 3. MIXED VIEW (columns + rows)
-- Shows approved trainer leaves with only the columns
-- relevant for scheduling: trainer, dates, and leave type.
-- Filters out pending and rejected requests.
-- Used by the scheduling layer to detect trainer unavailability.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_approved_leaves AS
SELECT
    trainer_id,
    leave_type,
    start_date,
    end_date
FROM gym.trainer_leaves
WHERE status = 'approved';

-- Sample query
-- SELECT * FROM gym.v_approved_leaves ORDER BY start_date;


-- =========================================================
-- 4. JOIN VIEW
-- Joins personal_training with persons (via members and trainers)
-- to show full names instead of raw IDs.
-- Useful for admin panels and printed schedules.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_personal_training_full AS
SELECT
    pt.session_id,
    pt.training_date,
    pt.status,

    -- Member full name
    mp.first_name || ' ' || mp.last_name AS member_name,

    -- Trainer full name
    tp.first_name || ' ' || tp.last_name AS trainer_name

FROM gym.personal_training pt

JOIN gym.members  m  ON m.member_id   = pt.member_id
JOIN gym.persons  mp ON mp.person_id  = m.person_id

JOIN gym.trainers t  ON t.trainer_id  = pt.trainer_id
JOIN gym.persons  tp ON tp.person_id  = t.person_id;

-- Sample query
-- SELECT * FROM gym.v_personal_training_full ORDER BY training_date;


-- =========================================================
-- 5. JOIN VIEW — trainer schedule with name
-- Joins trainer_work_schedule with trainers and persons
-- to show which days each trainer works, with their full name.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_trainer_schedule_full AS
SELECT
    tws.work_schedule_id,
    p.first_name || ' ' || p.last_name AS trainer_name,
    tws.day_of_week,
    tws.start_time,
    tws.end_time,
    tws.is_active
FROM gym.trainer_work_schedule tws
JOIN gym.trainers t ON t.trainer_id = tws.trainer_id
JOIN gym.persons  p ON p.person_id  = t.person_id;

-- Sample query
-- SELECT * FROM gym.v_trainer_schedule_full WHERE is_active = TRUE ORDER BY trainer_name, day_of_week;


-- =========================================================
-- 6. SUBQUERY VIEW
-- Shows trainers who currently have an approved leave
-- that overlaps with today's date.
-- Uses a subquery to find trainer_ids from trainer_leaves.
-- Useful for real-time availability checks.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_trainers_on_leave_today AS
SELECT
    t.trainer_id,
    p.first_name || ' ' || p.last_name AS trainer_name,
    tl.leave_type,
    tl.start_date,
    tl.end_date
FROM gym.trainers t
JOIN gym.persons p ON p.person_id = t.person_id
WHERE t.trainer_id IN (
    SELECT trainer_id
    FROM gym.trainer_leaves
    WHERE status = 'approved'
      AND start_date <= CURRENT_DATE
      AND (end_date IS NULL OR end_date >= CURRENT_DATE)
);

-- Sample query
-- SELECT * FROM gym.v_trainers_on_leave_today;


-- =========================================================
-- 7. SUBQUERY VIEW
-- Shows trainers who have NO scheduled personal training
-- sessions in the next 7 days — available for new bookings.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_trainers_available_this_week AS
SELECT
    t.trainer_id,
    p.first_name || ' ' || p.last_name AS trainer_name
FROM gym.trainers t
JOIN gym.persons p ON p.person_id = t.person_id
WHERE t.trainer_id NOT IN (
    SELECT DISTINCT trainer_id
    FROM gym.personal_training
    WHERE status = 'scheduled'
      AND training_date BETWEEN NOW() AND NOW() + INTERVAL '7 days'
);

-- Sample query
-- SELECT * FROM gym.v_trainers_available_this_week;


-- =========================================================
-- 8. UNION VIEW
-- Combines active (scheduled) and past (completed) sessions
-- into a single unified session log.
-- Adds a label column to distinguish the two groups.
-- Useful for member history reports.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_personal_training_log AS

    -- Active upcoming sessions
    SELECT
        session_id,
        member_id,
        trainer_id,
        training_date,
        status,
        'upcoming' AS session_group
    FROM gym.personal_training
    WHERE status = 'scheduled'
      AND training_date >= NOW()

UNION ALL

    -- Past completed sessions
    SELECT
        session_id,
        member_id,
        trainer_id,
        training_date,
        status,
        'past' AS session_group
    FROM gym.personal_training
    WHERE status = 'completed';

-- Sample query
-- SELECT * FROM gym.v_personal_training_log ORDER BY training_date DESC;


-- =========================================================
-- 9. VIEW ON TOP OF A VIEW
-- Builds on v_personal_training_full (view #4).
-- Filters to show only upcoming scheduled sessions
-- with full names — ready for a booking confirmation screen.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_upcoming_sessions_named AS
SELECT
    session_id,
    training_date,
    member_name,
    trainer_name,
    status
FROM gym.v_personal_training_full
WHERE status = 'scheduled'
  AND training_date >= NOW()
ORDER BY training_date;

-- Sample query
-- SELECT * FROM gym.v_upcoming_sessions_named;


-- =========================================================
-- 10. CHECK OPTION VIEW
-- Updatable view that only exposes pending leave requests.
-- WITH CHECK OPTION prevents inserting or updating a row
-- into a non-pending status through this view.
-- Ensures that only pending leaves are managed here —
-- approved/rejected leaves must be handled elsewhere.
-- =========================================================
CREATE OR REPLACE VIEW gym.v_pending_leaves AS
SELECT
    leave_id,
    trainer_id,
    leave_type,
    start_date,
    end_date,
    notes
FROM gym.trainer_leaves
WHERE status = 'pending'
WITH CHECK OPTION;

-- Sample query
-- SELECT * FROM gym.v_pending_leaves;

-- Safe UPDATE through the view (status stays pending — allowed):
-- UPDATE gym.v_pending_leaves SET notes = 'Waiting for approval' WHERE leave_id = 1;

-- This INSERT would be BLOCKED by CHECK OPTION (status not pending):
-- INSERT INTO gym.v_pending_leaves (trainer_id, leave_type, start_date, end_date, status)
-- VALUES (1, 'sick', '2024-06-01', '2024-06-05', 'approved');

-- End Andre Chernuhas' task

-- ================================================================
-- TASK: SQL VIEWS FOR Equipment and Goal Tracking
-- Author: Dmytro Tokariev
-- ================================================================
-- Views built on top of the fitness tracking tables:
--   gym.equipment, gym.goals, gym.progress
-- ================================================================


-- ================================================================
-- 1. HORIZONTAL VIEW — select specific columns
-- ================================================================
-- Purpose: Provides a simplified equipment inventory showing only
-- equipment name and current status. Hides maintenance dates and
-- internal IDs. Useful for front-desk staff who just need to know
-- what equipment is available.
-- Relates to: gym.equipment — strips implementation columns.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_equipment_catalogue AS
SELECT
    name,
    status
FROM gym.equipment;

-- Demo:
-- SELECT * FROM gym.v_equipment_catalogue;


-- ================================================================
-- 2. VERTICAL VIEW — filter specific rows
-- ================================================================
-- Purpose: Shows only equipment that is broken or under repair.
-- Maintenance staff use this to see what needs immediate attention
-- without being distracted by available equipment.
-- Relates to: gym.equipment — filters rows by status condition.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_equipment_needing_repair AS
SELECT *
FROM gym.equipment
WHERE status IN ('broken', 'under_repair');

-- Demo:
-- SELECT * FROM gym.v_equipment_needing_repair;


-- ================================================================
-- 3. MIXED VIEW — column selection + row filtering
-- ================================================================
-- Purpose: Lists active (in_progress) goals with only the columns
-- relevant for member progress tracking. Filters out completed and
-- abandoned goals so members see only what they are currently
-- working toward.
-- Relates to: gym.goals — combines column projection with
-- a status filter.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_active_goals AS
SELECT
    goal_id,
    member_id,
    goal_description,
    target_value,
    deadline,
    status,
    created_at
FROM gym.goals
WHERE status = 'in_progress';

-- Demo:
-- SELECT * FROM gym.v_active_goals;


-- ================================================================
-- 4. JOIN VIEW — multiple tables
-- ================================================================
-- Purpose: Produces a complete progress report by joining goals
-- with their progress records. Shows each goal alongside its
-- check-in history. Trainers use this to review member progress
-- during consultations.
-- Relates to: gym.goals, gym.progress — combines goal definitions
-- with actual progress measurements.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_goal_progress_history AS
SELECT
    g.goal_id,
    g.goal_description,
    g.target_value,
    g.status AS goal_status,
    g.deadline,
    p.current_state,
    p.check_date,
    p.notes
FROM gym.goals g
LEFT JOIN gym.progress p ON p.goal_id = g.goal_id
ORDER BY g.goal_id, p.check_date DESC;

-- Demo:
-- SELECT * FROM gym.v_goal_progress_history;


-- ================================================================
-- 5. SUBQUERY VIEW — uses a subquery
-- ================================================================
-- Purpose: Shows goals that have no progress records yet.
-- Trainers use this to identify goals that were set but never
-- tracked — these members might need additional motivation.
-- Relates to: gym.goals, gym.progress — the subquery checks for
-- absence of any progress row referencing the goal.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_untracked_goals AS
SELECT
    goal_id,
    goal_description,
    target_value,
    status,
    created_at
FROM gym.goals
WHERE goal_id NOT IN (
    SELECT DISTINCT goal_id
    FROM gym.progress
);

-- Demo:
-- SELECT * FROM gym.v_untracked_goals;


-- ================================================================
-- 6. UNION VIEW — combines two result sets
-- ================================================================
-- Purpose: Provides a single unified list of all equipment items
-- that need attention (both broken and under repair), tagged by
-- urgency level. Maintenance staff use this as their primary
-- work order list.
-- Relates to: gym.equipment — UNION filters on two status values
-- and labels them for priority.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_maintenance_worklist AS
SELECT
    equipment_id,
    name,
    status,
    last_maintenance,
    'HIGH PRIORITY' AS urgency
FROM gym.equipment
WHERE status = 'broken'

UNION ALL

SELECT
    equipment_id,
    name,
    status,
    last_maintenance,
    'MEDIUM PRIORITY' AS urgency
FROM gym.equipment
WHERE status = 'under_repair';

-- Demo:
-- SELECT * FROM gym.v_maintenance_worklist
-- ORDER BY urgency DESC;


-- ================================================================
-- 7. VIEW ON VIEW — selects from another view
-- ================================================================
-- Purpose: Builds on v_active_goals (view #3) to produce a simple
-- count of how many active goals each member has. Used on the
-- member dashboard for a quick overview.
-- Relates to: gym.v_active_goals — aggregates the active goals
-- view without re-joining the base table.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_member_goal_counts AS
SELECT
    member_id,
    COUNT(*) AS active_goals_count
FROM gym.v_active_goals
GROUP BY member_id;

-- Demo:
-- SELECT * FROM gym.v_member_goal_counts
-- ORDER BY active_goals_count DESC;


-- ================================================================
-- 8. UPDATABLE VIEW WITH CHECK OPTION
-- ================================================================
-- Purpose: Exposes only available equipment so that front-desk
-- staff can update maintenance dates directly through the view.
-- The CHECK OPTION prevents an UPDATE from changing the status
-- to anything other than 'available', which would move the row
-- outside the view's scope.
-- Relates to: gym.equipment — wraps a single table with a
-- WHERE filter and enforces it on writes.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_available_equipment_updatable AS
SELECT
    equipment_id,
    name,
    status,
    last_maintenance
FROM gym.equipment
WHERE status = 'available'
WITH CHECK OPTION;

-- Demo:
-- The following UPDATE succeeds because the row stays within the view:
-- UPDATE gym.v_available_equipment_updatable
-- SET last_maintenance = CURRENT_DATE
-- WHERE name = 'Treadmill X1';
--
-- The following UPDATE would fail because changing status to 'broken'
-- violates the CHECK OPTION (the row would leave the view):
-- UPDATE gym.v_available_equipment_updatable
-- SET status = 'broken'
-- WHERE name = 'Treadmill X1';


-- ================================================================
-- BONUS: Simple member progress summary
-- ================================================================
-- Purpose: Shows each goal with its most recent progress value.
-- This is the primary view for the member progress page.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_latest_progress AS
SELECT DISTINCT ON (g.goal_id)
    g.goal_id,
    g.member_id,
    g.goal_description,
    g.target_value,
    g.status,
    p.current_state AS latest_value,
    p.check_date AS last_checked,
    p.notes
FROM gym.goals g
LEFT JOIN gym.progress p ON p.goal_id = g.goal_id
ORDER BY g.goal_id, p.check_date DESC NULLS LAST;

-- Demo:
-- SELECT * FROM gym.v_latest_progress;


-- ================================================================
-- ALL DEMO QUERIES (commented - uncomment for testing)
-- ================================================================

-- SELECT * FROM gym.v_equipment_catalogue;
-- SELECT * FROM gym.v_equipment_needing_repair;
-- SELECT * FROM gym.v_active_goals;
-- SELECT * FROM gym.v_goal_progress_history LIMIT 20;
-- SELECT * FROM gym.v_untracked_goals;
-- SELECT * FROM gym.v_maintenance_worklist;
-- SELECT * FROM gym.v_member_goal_counts;
-- SELECT * FROM gym.v_available_equipment_updatable;
-- SELECT * FROM gym.v_latest_progress;

-- ================================================================
-- END OF Dmytro VIEWS SCRIPT
-- ================================================================

-- ================================================================
-- SQL VIEWS FOR PERSON AND TRAINER SPECIALIZATIONS
-- Author: Bohdan Bohelskyi
-- ================================================================
-- Views built on top of the identity and trainer qualification tables:
--   gym.persons, gym.trainers, gym.specializations,
--   gym.trainer_specializations
-- ================================================================


-- ================================================================
-- 1. HORIZONTAL VIEW — select specific columns
-- ================================================================
-- Purpose: Provides a safe public person directory with only basic
-- identity fields. It hides contact details and birth dates, which
-- are not needed for most role-selection screens.
-- Relates to: gym.persons — exposes only non-sensitive columns from
-- the base identity table shared by members and trainers.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_person_public_directory AS
SELECT
    person_id,
    first_name,
    last_name
FROM gym.persons;

-- Demo:
-- SELECT * FROM gym.v_person_public_directory;


-- ================================================================
-- 2. VERTICAL VIEW — filter specific rows
-- ================================================================
-- Purpose: Shows trainers hired during the current calendar year.
-- HR staff can use it to review new employees without scanning the
-- full trainers table.
-- Relates to: gym.trainers — filters trainer rows by hire_date.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_trainers_hired_this_year AS
SELECT
    trainer_id,
    person_id,
    hire_date
FROM gym.trainers
WHERE hire_date >= DATE_TRUNC('year', CURRENT_DATE)::date;

-- Demo:
-- SELECT * FROM gym.v_trainers_hired_this_year
-- ORDER BY hire_date DESC;


-- ================================================================
-- 3. MIXED VIEW — column selection + row filtering
-- ================================================================
-- Purpose: Shows only persons who have an email address, exposing
-- only contact-related columns needed by the communication layer.
-- Relates to: gym.persons — combines column projection with a row
-- filter on optional email data.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_email_contact_persons AS
SELECT
    person_id,
    first_name || ' ' || last_name AS full_name,
    email,
    phone
FROM gym.persons
WHERE email IS NOT NULL;

-- Demo:
-- SELECT * FROM gym.v_email_contact_persons;


-- ================================================================
-- 4. JOIN VIEW — multiple tables
-- ================================================================
-- Purpose: Produces readable trainer profiles by joining trainer
-- employment data with the base person identity record.
-- Relates to: gym.trainers and gym.persons — trainers extend persons
-- through a one-to-one relationship, and this view hides that join
-- from application queries.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_trainer_profiles AS
SELECT
    t.trainer_id,
    p.person_id,
    p.first_name,
    p.last_name,
    p.first_name || ' ' || p.last_name AS trainer_name,
    p.email,
    p.phone,
    t.hire_date
FROM gym.trainers AS t
JOIN gym.persons AS p ON p.person_id = t.person_id;

-- Demo:
-- SELECT * FROM gym.v_trainer_profiles
-- ORDER BY trainer_name;


-- ================================================================
-- 5. SUBQUERY VIEW — uses a subquery
-- ================================================================
-- Purpose: Shows trainers who do not have any specialization assigned.
-- Managers can use it as a data-quality checklist before publishing
-- trainer profiles or assigning classes.
-- Relates to: gym.trainers, gym.persons, gym.trainer_specializations —
-- the NOT EXISTS subquery checks the many-to-many junction table.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_trainers_without_specializations AS
SELECT
    t.trainer_id,
    p.person_id,
    p.first_name || ' ' || p.last_name AS trainer_name,
    t.hire_date
FROM gym.trainers AS t
JOIN gym.persons AS p ON p.person_id = t.person_id
WHERE NOT EXISTS (
    SELECT 1
    FROM gym.trainer_specializations AS ts
    WHERE ts.trainer_id = t.trainer_id
);

-- Demo:
-- SELECT * FROM gym.v_trainers_without_specializations;


-- ================================================================
-- 6. UNION VIEW — combines two result sets
-- ================================================================
-- Purpose: Provides a unified person directory grouped by whether
-- a person is registered as a trainer or not. This is useful for
-- admin screens that select people for trainer assignment.
-- Relates to: gym.persons and gym.trainers — shows the role extension
-- built on top of the base person table.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_person_trainer_role_directory AS
SELECT
    p.person_id,
    p.first_name || ' ' || p.last_name AS full_name,
    'trainer' AS role_group
FROM gym.persons AS p
JOIN gym.trainers AS t ON t.person_id = p.person_id

UNION ALL

SELECT
    p.person_id,
    p.first_name || ' ' || p.last_name AS full_name,
    'not_trainer' AS role_group
FROM gym.persons AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM gym.trainers AS t
    WHERE t.person_id = p.person_id
);

-- Demo:
-- SELECT * FROM gym.v_person_trainer_role_directory
-- ORDER BY role_group, full_name;


-- ================================================================
-- 7. DETAILED JOIN VIEW — trainer specialization details
-- ================================================================
-- Purpose: Shows one row per trainer-specialization pair. Trainers
-- without assigned specializations are still included with NULL
-- specialization fields, because of LEFT JOIN.
-- Relates to: gym.trainers, gym.persons, gym.trainer_specializations,
-- gym.specializations — resolves the many-to-many trainer qualification
-- model into a readable report.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_trainer_specialization_details AS
SELECT
    t.trainer_id,
    p.person_id,
    p.first_name || ' ' || p.last_name AS trainer_name,
    t.hire_date,
    s.specialization_id,
    s.specialization_name
FROM gym.trainers AS t
JOIN gym.persons AS p ON p.person_id = t.person_id
LEFT JOIN gym.trainer_specializations AS ts
    ON ts.trainer_id = t.trainer_id
LEFT JOIN gym.specializations AS s
    ON s.specialization_id = ts.specialization_id;

-- Demo:
-- SELECT * FROM gym.v_trainer_specialization_details
-- ORDER BY trainer_name, specialization_name;


-- ================================================================
-- 8. VIEW ON VIEW — selects from another view
-- ================================================================
-- Purpose: Builds on v_trainer_specialization_details to summarize
-- each trainer into one row with the number and list of their
-- specializations.
-- Relates to: gym.v_trainer_specialization_details — reuses the
-- detailed trainer-specialization view instead of repeating joins.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_trainer_specialization_summary AS
SELECT
    trainer_id,
    person_id,
    trainer_name,
    hire_date,
    COUNT(specialization_id) AS specialization_count,
    COALESCE(
        STRING_AGG(specialization_name, ', ' ORDER BY specialization_name)
            FILTER (WHERE specialization_name IS NOT NULL),
        'No specialization assigned'
    ) AS specializations
FROM gym.v_trainer_specialization_details
GROUP BY
    trainer_id,
    person_id,
    trainer_name,
    hire_date;

-- Demo:
-- SELECT * FROM gym.v_trainer_specialization_summary
-- ORDER BY specialization_count DESC, trainer_name;


-- ================================================================
-- 9. UPDATABLE VIEW WITH CHECK OPTION
-- ================================================================
-- Purpose: Exposes specialization rows with non-empty names for safe
-- catalogue maintenance. WITH CHECK OPTION prevents inserting or
-- updating a specialization through this view into an empty name,
-- keeping the specialization catalogue clean.
-- Relates to: gym.specializations — wraps a single table with a
-- validation filter and enforces it on writes.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_valid_specializations_updatable AS
SELECT
    specialization_id,
    specialization_name
FROM gym.specializations
WHERE LENGTH(TRIM(specialization_name)) > 0
WITH CHECK OPTION;

-- Demo:
-- The following UPDATE succeeds because the row stays within the view:
-- UPDATE gym.v_valid_specializations_updatable
-- SET specialization_name = 'Functional Training'
-- WHERE specialization_id = 1;
--
-- The following UPDATE would fail because an empty name violates
-- the CHECK OPTION:
-- UPDATE gym.v_valid_specializations_updatable
-- SET specialization_name = ''
-- WHERE specialization_id = 1;


-- ================================================================
-- ALL DEMO QUERIES FOR BOHDAN'S VIEWS
-- ================================================================
-- SELECT * FROM gym.v_person_public_directory;
-- SELECT * FROM gym.v_trainers_hired_this_year ORDER BY hire_date DESC;
-- SELECT * FROM gym.v_email_contact_persons;
-- SELECT * FROM gym.v_trainer_profiles ORDER BY trainer_name;
-- SELECT * FROM gym.v_trainers_without_specializations;
-- SELECT * FROM gym.v_person_trainer_role_directory ORDER BY role_group, full_name;
-- SELECT * FROM gym.v_trainer_specialization_details ORDER BY trainer_name, specialization_name;
-- SELECT * FROM gym.v_trainer_specialization_summary ORDER BY specialization_count DESC, trainer_name;
-- SELECT * FROM gym.v_valid_specializations_updatable;

-- =========================================================
-- MEMBERSHIP MANAGEMENT VIEWS
-- Responsible: Oleh Svyrydenko
-- =========================================================
-- Covers:
-- - memberships
-- - members
-- - members_memberships
-- - attendance
-- =========================================================


-- =========================================================
-- 1. HORIZONTAL VIEW
-- Purpose:
-- Shows only active membership products.
-- Supports membership sales and pricing operations.
-- =========================================================

CREATE OR REPLACE VIEW gym.active_memberships_view AS
SELECT *
FROM gym.memberships
WHERE valid_to IS NULL;

-- Demo:
-- SELECT * FROM gym.active_memberships_view;


-- =========================================================
-- 2. VERTICAL VIEW
-- Purpose:
-- Exposes only pricing information for memberships.
-- Useful when membership IDs and validity periods are not needed.
-- =========================================================

CREATE OR REPLACE VIEW gym.membership_prices_view AS
SELECT
    type,
    price,
    currency
FROM gym.memberships;

-- Demo:
-- SELECT * FROM gym.membership_prices_view;


-- =========================================================
-- 3. MIXED VIEW
-- Purpose:
-- Shows selected columns for premium memberships only.
-- Combines column selection and row filtering.
-- =========================================================

CREATE OR REPLACE VIEW gym.premium_memberships_view AS
SELECT
    membership_id,
    price,
    currency,
    valid_from
FROM gym.memberships
WHERE type = 'premium';

-- Demo:
-- SELECT * FROM gym.premium_memberships_view;


-- =========================================================
-- 4. JOIN VIEW
-- Purpose:
-- Combines membership enrollment records with membership
-- product information.
-- Useful for reporting and membership administration.
-- =========================================================

CREATE OR REPLACE VIEW gym.member_membership_view AS
SELECT
    mm.member_id,
    m.type AS membership_type,
    m.price,
    mm.discount,
    mm.start_date,
    mm.end_date
FROM gym.members_memberships mm
JOIN gym.memberships m
    ON mm.membership_id = m.membership_id;

-- Demo:
-- SELECT * FROM gym.member_membership_view;


-- =========================================================
-- 5. SUBQUERY VIEW
-- Purpose:
-- Shows the number of attendance records for each member.
-- Demonstrates usage of a subquery inside a view.
-- =========================================================

CREATE OR REPLACE VIEW gym.member_attendance_summary_view AS
SELECT
    mb.member_id,
    (
        SELECT COUNT(*)
        FROM gym.attendance a
        WHERE a.member_id = mb.member_id
    ) AS attendance_count
FROM gym.members mb;

-- Demo:
-- SELECT * FROM gym.member_attendance_summary_view;


-- =========================================================
-- 6. UNION VIEW
-- Purpose:
-- Combines attendance activity and active membership records
-- into a single activity stream.
-- =========================================================

CREATE OR REPLACE VIEW gym.member_activity_view AS

SELECT
    member_id,
    'attendance' AS activity_type,
    status::text AS activity_status
FROM gym.attendance

UNION ALL

SELECT
    p.person_id,
    p.first_name || ' ' || p.last_name AS full_name,
    'not_trainer' AS role_group
FROM gym.persons AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM gym.trainers AS t
    WHERE t.person_id = p.person_id
);

-- Demo:
-- SELECT * FROM gym.v_person_trainer_role_directory
-- ORDER BY role_group, full_name;


-- ================================================================
-- 7. DETAILED JOIN VIEW — trainer specialization details
-- ================================================================
-- Purpose: Shows one row per trainer-specialization pair. Trainers
-- without assigned specializations are still included with NULL
-- specialization fields, because of LEFT JOIN.
-- Relates to: gym.trainers, gym.persons, gym.trainer_specializations,
-- gym.specializations — resolves the many-to-many trainer qualification
-- model into a readable report.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_trainer_specialization_details AS
SELECT
    t.trainer_id,
    p.person_id,
    p.first_name || ' ' || p.last_name AS trainer_name,
    t.hire_date,
    s.specialization_id,
    s.specialization_name
FROM gym.trainers AS t
JOIN gym.persons AS p ON p.person_id = t.person_id
LEFT JOIN gym.trainer_specializations AS ts
    ON ts.trainer_id = t.trainer_id
LEFT JOIN gym.specializations AS s
    ON s.specialization_id = ts.specialization_id;

-- Demo:
-- SELECT * FROM gym.v_trainer_specialization_details
-- ORDER BY trainer_name, specialization_name;


-- ================================================================
-- 8. VIEW ON VIEW — selects from another view
-- ================================================================
-- Purpose: Builds on v_trainer_specialization_details to summarize
-- each trainer into one row with the number and list of their
-- specializations.
-- Relates to: gym.v_trainer_specialization_details — reuses the
-- detailed trainer-specialization view instead of repeating joins.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_trainer_specialization_summary AS
SELECT
    trainer_id,
    person_id,
    trainer_name,
    hire_date,
    COUNT(specialization_id) AS specialization_count,
    COALESCE(
        STRING_AGG(specialization_name, ', ' ORDER BY specialization_name)
            FILTER (WHERE specialization_name IS NOT NULL),
        'No specialization assigned'
    ) AS specializations
FROM gym.v_trainer_specialization_details
GROUP BY
    trainer_id,
    person_id,
    trainer_name,
    hire_date;

-- Demo:
-- SELECT * FROM gym.v_trainer_specialization_summary
-- ORDER BY specialization_count DESC, trainer_name;


-- ================================================================
-- 9. UPDATABLE VIEW WITH CHECK OPTION
-- ================================================================
-- Purpose: Exposes specialization rows with non-empty names for safe
-- catalogue maintenance. WITH CHECK OPTION prevents inserting or
-- updating a specialization through this view into an empty name,
-- keeping the specialization catalogue clean.
-- Relates to: gym.specializations — wraps a single table with a
-- validation filter and enforces it on writes.
-- ================================================================

CREATE OR REPLACE VIEW gym.v_valid_specializations_updatable AS
SELECT
    specialization_id,
    specialization_name
FROM gym.specializations
WHERE LENGTH(TRIM(specialization_name)) > 0
WITH CHECK OPTION;

-- Demo:
-- The following UPDATE succeeds because the row stays within the view:
-- UPDATE gym.v_valid_specializations_updatable
-- SET specialization_name = 'Functional Training'
-- WHERE specialization_id = 1;
--
-- The following UPDATE would fail because an empty name violates
-- the CHECK OPTION:
-- UPDATE gym.v_valid_specializations_updatable
-- SET specialization_name = ''
-- WHERE specialization_id = 1;


-- ================================================================
-- ALL DEMO QUERIES FOR BOHDAN'S VIEWS
-- ================================================================
-- SELECT * FROM gym.v_person_public_directory;
-- SELECT * FROM gym.v_trainers_hired_this_year ORDER BY hire_date DESC;
-- SELECT * FROM gym.v_email_contact_persons;
-- SELECT * FROM gym.v_trainer_profiles ORDER BY trainer_name;
-- SELECT * FROM gym.v_trainers_without_specializations;
-- SELECT * FROM gym.v_person_trainer_role_directory ORDER BY role_group, full_name;
-- SELECT * FROM gym.v_trainer_specialization_details ORDER BY trainer_name, specialization_name;
-- SELECT * FROM gym.v_trainer_specialization_summary ORDER BY specialization_count DESC, trainer_name;
-- SELECT * FROM gym.v_valid_specializations_updatable;
    member_id,
    'membership' AS activity_type,
    'active' AS activity_status
FROM gym.members_memberships
WHERE end_date IS NULL;

-- Demo:
-- SELECT * FROM gym.member_activity_view;


-- =========================================================
-- 7. VIEW BASED ON ANOTHER VIEW
-- Purpose:
-- Uses member_membership_view and shows only members
-- who received a discount.
-- =========================================================

CREATE OR REPLACE VIEW gym.discounted_members_view AS
SELECT *
FROM gym.member_membership_view
WHERE discount > 0;

-- Demo:
-- SELECT * FROM gym.discounted_members_view;


-- =========================================================
-- 8. UPDATABLE VIEW WITH CHECK OPTION
-- Purpose:
-- Allows updates only for active membership products.
-- CHECK OPTION prevents updates that would make a row
-- disappear from the view.
-- =========================================================

CREATE OR REPLACE VIEW gym.current_memberships_view AS
SELECT *
FROM gym.memberships
WHERE valid_to IS NULL
WITH CHECK OPTION;

/* Demo:

SELECT * FROM gym.current_memberships_view;

Allowed:

UPDATE gym.current_memberships_view
SET price = 1300
WHERE membership_id = 3;

Rejected:

UPDATE gym.current_memberships_view
SET valid_to = CURRENT_DATE
WHERE membership_id = 3;

*/

-- =========================================================
-- END OF MEMBERSHIP MANAGEMENT VIEWS
-- =========================================================