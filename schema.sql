-- ============================================================
-- Workspace Management System — Supabase Schema
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'employee');
CREATE TYPE group_type AS ENUM ('managers', 'coordinators', 'junior_a', 'junior_b');
CREATE TYPE room_type AS ENUM ('private', 'shared');
CREATE TYPE assignment_type AS ENUM ('permanent', 'oneoff', 'temporary');
CREATE TYPE work_location AS ENUM ('office', 'home', 'leave');
CREATE TYPE leave_type AS ENUM ('annual', 'sick', 'special');
CREATE TYPE leave_status AS ENUM ('pending_manager', 'pending_admin', 'approved', 'rejected');

-- ============================================================
-- TABLES
-- ============================================================

-- Groups (קבוצות)
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_he TEXT NOT NULL,
  type group_type NOT NULL,
  wfh_max_percent INTEGER DEFAULT 20,
  wfh_flex_percent INTEGER DEFAULT 20,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rooms (חדרים)
CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  name_he TEXT NOT NULL,
  capacity INTEGER NOT NULL,
  type room_type NOT NULL DEFAULT 'shared',
  group_id UUID REFERENCES groups(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Employees (עובדים)
CREATE TABLE employees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role user_role NOT NULL DEFAULT 'employee',
  group_id UUID REFERENCES groups(id),
  primary_room_id UUID REFERENCES rooms(id),
  work_days_per_week INTEGER DEFAULT 5,
  home_days_per_week INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Assignments — שיבוצים יומיים לחדרים
CREATE TABLE assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  type assignment_type NOT NULL DEFAULT 'oneoff',
  temp_end_date DATE,
  note TEXT,
  created_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, date)
);

-- Work Days — מצב יומי לכל עובד
CREATE TABLE work_days (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  location work_location NOT NULL DEFAULT 'office',
  room_id UUID REFERENCES rooms(id),
  note TEXT,
  set_by UUID REFERENCES employees(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, date)
);

-- Leave Requests — בקשות חופשה
CREATE TABLE leave_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  type leave_type NOT NULL DEFAULT 'annual',
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status leave_status NOT NULL DEFAULT 'pending_manager',
  manager_id UUID REFERENCES employees(id),
  manager_approved_at TIMESTAMPTZ,
  admin_id UUID REFERENCES employees(id),
  admin_approved_at TIMESTAMPTZ,
  rejection_reason TEXT,
  employee_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- WFH Policy overrides per employee
CREATE TABLE wfh_overrides (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  max_home_days_per_week INTEGER,
  note TEXT,
  valid_from DATE,
  valid_to DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit log
CREATE TABLE audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id UUID REFERENCES employees(id),
  action TEXT NOT NULL,
  table_name TEXT,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_work_days_date ON work_days(date);
CREATE INDEX idx_work_days_employee ON work_days(employee_id);
CREATE INDEX idx_assignments_date ON assignments(date);
CREATE INDEX idx_leave_requests_employee ON leave_requests(employee_id);
CREATE INDEX idx_leave_requests_status ON leave_requests(status);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE wfh_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Helper function: get current employee record
CREATE OR REPLACE FUNCTION current_employee_id()
RETURNS UUID AS $$
  SELECT id FROM employees WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_employee_role()
RETURNS user_role AS $$
  SELECT role FROM employees WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Groups — all authenticated users can read
CREATE POLICY "groups_read" ON groups FOR SELECT TO authenticated USING (true);
CREATE POLICY "groups_write" ON groups FOR ALL TO authenticated USING (current_employee_role() = 'admin');

-- Rooms — all can read, only admin writes
CREATE POLICY "rooms_read" ON rooms FOR SELECT TO authenticated USING (true);
CREATE POLICY "rooms_write" ON rooms FOR ALL TO authenticated USING (current_employee_role() = 'admin');

-- Employees — all can read active employees; only admin writes
CREATE POLICY "employees_read" ON employees FOR SELECT TO authenticated USING (is_active = true);
CREATE POLICY "employees_write" ON employees FOR ALL TO authenticated USING (current_employee_role() = 'admin');

-- Assignments — all read; admin+manager write
CREATE POLICY "assignments_read" ON assignments FOR SELECT TO authenticated USING (true);
CREATE POLICY "assignments_write" ON assignments FOR ALL TO authenticated
  USING (current_employee_role() IN ('admin', 'manager'));

-- Work Days — all read; admin+manager write
CREATE POLICY "workdays_read" ON work_days FOR SELECT TO authenticated USING (true);
CREATE POLICY "workdays_write" ON work_days FOR ALL TO authenticated
  USING (current_employee_role() IN ('admin', 'manager'));

-- Leave Requests — employees see own; managers see group; admin sees all
CREATE POLICY "leave_read_own" ON leave_requests FOR SELECT TO authenticated
  USING (employee_id = current_employee_id() OR current_employee_role() IN ('admin', 'manager'));
CREATE POLICY "leave_insert_own" ON leave_requests FOR INSERT TO authenticated
  WITH CHECK (employee_id = current_employee_id() OR current_employee_role() IN ('admin', 'manager'));
CREATE POLICY "leave_update_manager" ON leave_requests FOR UPDATE TO authenticated
  USING (current_employee_role() IN ('admin', 'manager'));

-- Audit log — admin only
CREATE POLICY "audit_admin" ON audit_log FOR SELECT TO authenticated
  USING (current_employee_role() = 'admin');

-- ============================================================
-- SEED DATA — Groups
-- ============================================================
INSERT INTO groups (id, name, name_he, type, wfh_max_percent, wfh_flex_percent) VALUES
  ('11111111-0000-0000-0000-000000000001', 'Managers', 'מנהלים', 'managers', 0, 0),
  ('11111111-0000-0000-0000-000000000002', 'Coordinators', 'רכזות', 'coordinators', 20, 20),
  ('11111111-0000-0000-0000-000000000003', 'Junior Managers A', 'מנהלות זוטרות א', 'junior_a', 20, 20),
  ('11111111-0000-0000-0000-000000000004', 'Junior Managers B', 'מנהלות זוטרות ב', 'junior_b', 20, 20);

-- ============================================================
-- SEED DATA — Rooms
-- ============================================================
INSERT INTO rooms (id, name, name_he, capacity, type, group_id) VALUES
  ('22222222-0000-0000-0000-000000000001', 'Manager 1 Office', 'חדר מנהל 1', 1, 'private', '11111111-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000002', 'Manager 2 Office', 'חדר מנהל 2', 1, 'private', '11111111-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000003', 'Manager 3 Office', 'חדר מנהל 3', 1, 'private', '11111111-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000004', 'Manager 4 Office', 'חדר מנהל 4', 1, 'private', '11111111-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000005', 'Manager 5 Office', 'חדר מנהל 5', 1, 'private', '11111111-0000-0000-0000-000000000001'),
  ('22222222-0000-0000-0000-000000000006', 'Coordinators Room', 'חדר רכזות', 3, 'shared', '11111111-0000-0000-0000-000000000002'),
  ('22222222-0000-0000-0000-000000000007', 'Junior A Room', 'חדר זוטרות א', 2, 'shared', '11111111-0000-0000-0000-000000000003'),
  ('22222222-0000-0000-0000-000000000008', 'Junior B Room', 'חדר זוטרות ב', 4, 'shared', '11111111-0000-0000-0000-000000000004');
