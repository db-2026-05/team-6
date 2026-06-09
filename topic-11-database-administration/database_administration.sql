-- ================================================================
-- DATABASE ADMINISTRATION TEMPLATE (TOPIC 11)
-- ================================================================
-- WHAT SHOULD BE ADDED HERE:
-- 1) CREATE ROLE statements for at least 2 distinct roles.
--    Example roles: read-only analyst, read-write editor.
--
-- 2) GRANT statements assigning appropriate permissions to each role:
--    - Read-only role: GRANT SELECT ON ALL TABLES IN SCHEMA ...
--    - Read-write role: GRANT SELECT, INSERT, UPDATE, DELETE ...
--
-- 3) CREATE USER statements for at least 2 users.
--    Each user must be assigned to one of the defined roles.
--
-- 4) Comments before each section explaining the rationale:
--    - Why this role exists
--    - What access it should and should not have
--
-- RECOMMENDED ORDER:
-- 1) Roles + their GRANTs
-- 2) Users + GRANT ROLE TO USER
-- 3) Optional: REVOKE statements for fine-grained restrictions
-- 4) Optional cleanup block (commented out by default):
--    -- DROP USER ...; DROP ROLE ...;
--
-- IMPORTANT:
-- - Use explicit GRANT / REVOKE statements — do not rely on defaults.
-- - Roles must have meaningfully different permission levels.
-- - Script must execute in PostgreSQL without errors.
-- ================================================================

-- Add your script below this line


-- This script follows the principle of least privilege: every role
-- receives only the permissions it needs to fulfil its purpose —
-- nothing more.
--
--   gym_admin      – admin role (full control)
--   gym_app        – backend application runtime (DML only)
--   gym_developer  – developer manual access (DML, no DDL)
--   gym_migration  – schema migration runner (DML + DDL)
--   gym_tester     – QA read-only verification (SELECT only)
--
-- Separation of concerns:
--   • The application never alters the schema — migrations do.
--   • Developers can query and modify data but cannot drop tables.
--   • Testers can verify data without risk of accidental mutation.
--   • Only the admin role can create or manage other roles.
--
-- All permissions are granted explicitly; default PUBLIC privileges
-- on the gym schema are revoked so that unlisted roles have zero
-- access.
-- ================================================================


-- ================================================================
-- 1. REVOKE DEFAULT PUBLIC PRIVILEGES
-- ================================================================

REVOKE ALL ON SCHEMA gym FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA gym FROM PUBLIC;
-- Clearing PUBLIC privileges: add for SEQUENCES and TYPES
REVOKE ALL ON ALL SEQUENCES IN SCHEMA gym FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA gym FROM PUBLIC;

-- ================================================================
-- 2. CREATE ROLES
-- ================================================================
-- Roles are permission templates (NOLOGIN).
-- ================================================================

-- gym_tester: read-only access for QA engineers.
-- Rationale: testers must be able to verify data integrity after
-- test runs without any risk of accidentally modifying records.
CREATE ROLE gym_tester NOLOGIN;

-- gym_app: runtime application service account.
-- Rationale: the backend API performs CRUD operations on behalf of
-- end users.  It must never alter the schema — that responsibility
-- belongs exclusively to the migration role.
CREATE ROLE gym_app NOLOGIN;

-- gym_developer: manual developer access during development.
-- Rationale: developers need the same DML capabilities as the
-- application to debug and develop features, but must not execute
-- DDL (CREATE / ALTER / DROP) in shared environments to avoid
-- uncoordinated schema changes.
CREATE ROLE gym_developer NOLOGIN;

-- gym_migration: automated schema migration runner.
-- Rationale: migration tools (Flyway, Liquibase, custom scripts)
-- require DDL permissions to evolve the schema.  Keeping this as a
-- separate role ensures that only the CI/CD pipeline can alter
-- tables, preventing ad-hoc schema changes by developers or the
-- application.
CREATE ROLE gym_migration NOLOGIN;

-- gym_admin: database administrator with full control.
-- Rationale: break-glass role for the DBA or lead engineer.
-- Includes CREATEROLE so the admin can provision new users/roles.
-- Should be used sparingly and audited.
CREATE ROLE gym_admin NOLOGIN CREATEROLE;


-- ================================================================
-- 3. GRANT PERMISSIONS TO ROLES
-- ================================================================

-- ----------------------------------------------------------------
-- 3a. gym_tester — SELECT only
-- ----------------------------------------------------------------
-- Testers can read every table to validate query results and data
-- correctness.  No write access of any kind is granted.
-- ----------------------------------------------------------------
GRANT USAGE ON SCHEMA gym TO gym_tester;
GRANT SELECT ON ALL TABLES IN SCHEMA gym TO gym_tester;

-- ----------------------------------------------------------------
-- 3b. gym_app — full DML (SELECT, INSERT, UPDATE, DELETE)
-- ----------------------------------------------------------------
-- The application handles all CRUD operations for the fitness
-- center: member registration, attendance tracking, class booking,
-- equipment updates, etc.  Sequence UPDATE is required so the app
-- can use NEXTVAL() for serial/identity columns when inserting.
-- ----------------------------------------------------------------
GRANT USAGE ON SCHEMA gym TO gym_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA gym TO gym_app;
-- Adding SEQUENCES for gym_app
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gym TO gym_app;
-- Adding custom ENUM types for gym_app
GRANT USAGE ON TYPE gym.recurrence_frequency TO gym_app;
GRANT USAGE ON TYPE gym.day_of_week TO gym_app;

-- ----------------------------------------------------------------
-- 3c. gym_developer — full DML (same as app, granted independently)
-- ----------------------------------------------------------------
-- Developers receive the same data-level access as the application
-- so they can reproduce and debug issues.  Permissions are granted
-- directly (not inherited from gym_app) to keep the two roles
-- independent — revoking something from the app does not
-- accidentally affect developers, and vice versa.
-- ----------------------------------------------------------------
GRANT USAGE ON SCHEMA gym TO gym_developer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA gym TO gym_developer;
--  Adding SEQUENCES for gym_developer
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gym TO gym_developer;
-- Adding custom ENUM types for gym_developer
GRANT USAGE ON TYPE gym.recurrence_frequency TO gym_developer;
GRANT USAGE ON TYPE gym.day_of_week TO gym_developer;

-- ----------------------------------------------------------------
-- 3d. gym_migration — DML + DDL (schema evolution)
-- ----------------------------------------------------------------
-- The migration role can create, alter, and drop tables,
-- and types within the gym schema.  This is necessary to run
-- migration scripts that evolve the database structure over time.
-- CREATE on the schema allows new objects; ownership of created
-- objects lets the role ALTER and DROP them.
-- ----------------------------------------------------------------
GRANT USAGE, CREATE ON SCHEMA gym TO gym_migration;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA gym TO gym_migration;
-- Allow the migration role to ALTER and DROP existing tables
-- that it does not own.  In practice the migration user will own
-- objects it creates; for pre-existing objects the database owner
-- may need to transfer ownership or grant these explicitly.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA gym TO gym_migration;
-- Add SEQUENCES for gym_migration
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gym TO gym_migration;

-- ----------------------------------------------------------------
-- 3e. gym_admin — unrestricted access
-- ----------------------------------------------------------------
-- Full control over the gym schema and all objects within it.
-- Combined with CREATEROLE (set at role creation), the admin can
-- also provision new users and roles.
-- ----------------------------------------------------------------
GRANT ALL PRIVILEGES ON SCHEMA gym TO gym_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA gym TO gym_admin;
-- Additional best practices for sequence admins
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA gym TO gym_admin;


-- ================================================================
-- 4. REVOKE STATEMENTS — fine-grained restrictions
-- ================================================================
-- Even though gym_developer has full DML, we add a
-- restriction by revoking DELETE on the memberships
-- table.  Membership pricing records are versioned (soft-closed
-- with valid_to) and should never be physically deleted — not
-- even during development.  This protects pricing audit history.
-- ================================================================

REVOKE DELETE ON gym.memberships FROM gym_developer;

-- Similarly, the application should never delete membership
-- pricing records; business logic relies on versioning.
REVOKE DELETE ON gym.memberships FROM gym_app;

-- Revoke TRUNCATE from all non-admin roles as an extra safeguard.
-- TRUNCATE bypasses row-level triggers and can cause irreversible
-- data loss.  Only the admin should ever truncate tables.
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA gym FROM gym_tester;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA gym FROM gym_app;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA gym FROM gym_developer;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA gym FROM gym_migration;


-- ================================================================
-- 5. CREATE USERS (login-capable roles)
-- ================================================================
-- Each user is a LOGIN role with a password.  In production these
-- passwords would be managed by a secrets manager, not hardcoded.
-- ================================================================

CREATE USER admin_user     WITH LOGIN PASSWORD 'admin_secure_pass_2025';
CREATE USER app_user       WITH LOGIN PASSWORD 'app_secure_pass_2025';
CREATE USER developer_user WITH LOGIN PASSWORD 'dev_secure_pass_2025';
CREATE USER migration_user WITH LOGIN PASSWORD 'migration_secure_pass_2025';
CREATE USER tester_user    WITH LOGIN PASSWORD 'tester_secure_pass_2025';


-- ================================================================
-- 6. ASSIGN ROLES TO USERS
-- ================================================================
-- Each user inherits all privileges of its assigned role.
-- A user can be reassigned or granted multiple roles if needs
-- change, without modifying the role definitions themselves.
-- ================================================================

GRANT gym_admin     TO admin_user;
GRANT gym_app       TO app_user;
GRANT gym_developer TO developer_user;
GRANT gym_migration TO migration_user;
GRANT gym_tester    TO tester_user;


-- ================================================================
-- 7. ALTER DEFAULT PRIVILEGES
-- ================================================================
-- When the migration_user creates new tables in the
-- gym schema (during migrations), the other roles should
-- automatically receive appropriate access without manual grants.
-- ================================================================

-- Technical fix for Supabase cloud to allow modifying default privileges for this role
GRANT migration_user TO postgres;

-- Future tables created by migration_user: grant SELECT to testers
ALTER DEFAULT PRIVILEGES FOR ROLE migration_user IN SCHEMA gym
    GRANT SELECT ON TABLES TO gym_tester;

-- Future tables created by migration_user: grant full DML to app
ALTER DEFAULT PRIVILEGES FOR ROLE migration_user IN SCHEMA gym
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO gym_app;

-- Future tables created by migration_user: grant full DML to developers
ALTER DEFAULT PRIVILEGES FOR ROLE migration_user IN SCHEMA gym
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO gym_developer;

-- Additional fix for future SEQUENCES so that automation doesn't break during migrations
ALTER DEFAULT PRIVILEGES FOR ROLE migration_user IN SCHEMA gym
    GRANT USAGE, SELECT ON SEQUENCES TO gym_app;

ALTER DEFAULT PRIVILEGES FOR ROLE migration_user IN SCHEMA gym
    GRANT USAGE, SELECT ON SEQUENCES TO gym_developer;

-- Cleaning up the temporary role assignment for Supabase session security
REVOKE migration_user FROM postgres;
    

-- ================================================================
-- 9. CLEANUP
-- ================================================================
-- Uncomment the following statements to remove all users and roles
-- created by this script.  Execute in this order to avoid
-- dependency errors (users first, then roles).
-- ================================================================

-- DROP USER IF EXISTS tester_user;
-- DROP USER IF EXISTS migration_user;
-- DROP USER IF EXISTS developer_user;
-- DROP USER IF EXISTS app_user;
-- DROP USER IF EXISTS admin_user;

-- DROP ROLE IF EXISTS gym_admin;
-- DROP ROLE IF EXISTS gym_migration;
-- DROP ROLE IF EXISTS gym_developer;
-- DROP ROLE IF EXISTS gym_app;
-- DROP ROLE IF EXISTS gym_tester;
