CREATE TYPE public.user_role AS ENUM (
  'super_admin',
  'rector',
  'executive_management',
  'registrar',
  'deputy_registrar',
  'bursar',
  'academic_affairs_officer',
  'ict_administrator',
  'dean',
  'head_of_department',
  'lecturer',
  'examination_officer',
  'registry_officer',
  'finance_officer',
  'library_officer',
  'hostel_officer',
  'student_affairs_officer',
  'siwes_coordinator',
  'quality_assurance_officer',
  'student',
  'applicant',
  'alumni'
);

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL DEFAULT 'Campus User',
  email text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own profile" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.user_role NOT NULL,
  scope_type text NOT NULL DEFAULT 'institution',
  scope_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role, scope_type, scope_id)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read their own roles" ON public.user_roles FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.user_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT _user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role
  );
$$;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.user_role) TO authenticated;
REVOKE ALL ON FUNCTION public.has_role(uuid, public.user_role) FROM PUBLIC, anon;

CREATE OR REPLACE FUNCTION public.handle_new_campus_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, email)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''), NULLIF(NEW.raw_user_meta_data ->> 'name', ''), NULLIF(split_part(COALESCE(NEW.email, ''), '@', 1), ''), 'Campus User'),
    COALESCE(NEW.email, '')
  )
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, updated_at = now();

  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'applicant')
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created_campus
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_campus_user();

CREATE TABLE public.campuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  address text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.campuses TO authenticated;
GRANT ALL ON public.campuses TO service_role;
ALTER TABLE public.campuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in users can view campuses" ON public.campuses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Institution administrators can manage campuses" ON public.campuses FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin')) WITH CHECK (public.has_role(auth.uid(), 'super_admin'));

CREATE TABLE public.schools (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campus_id uuid NOT NULL REFERENCES public.campuses(id),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.schools TO authenticated;
GRANT ALL ON public.schools TO service_role;
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in users can view schools" ON public.schools FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized officers can manage schools" ON public.schools FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer')) WITH CHECK (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer'));

CREATE TABLE public.departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id),
  name text NOT NULL,
  code text NOT NULL UNIQUE,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.departments TO authenticated;
GRANT ALL ON public.departments TO service_role;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in users can view departments" ON public.departments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized officers can manage departments" ON public.departments FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean')) WITH CHECK (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean'));

CREATE TABLE public.programmes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid NOT NULL REFERENCES public.departments(id),
  name text NOT NULL,
  qualification text NOT NULL DEFAULT 'To be configured',
  code text NOT NULL UNIQUE,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.programmes TO authenticated;
GRANT ALL ON public.programmes TO service_role;
ALTER TABLE public.programmes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in users can view programmes" ON public.programmes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized officers can manage programmes" ON public.programmes FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department')) WITH CHECK (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department'));

CREATE TABLE public.academic_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'configured' CHECK (status IN ('configured', 'active', 'closed', 'sample')),
  starts_on date,
  ends_on date,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.academic_sessions TO authenticated;
GRANT ALL ON public.academic_sessions TO service_role;
ALTER TABLE public.academic_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in users can view academic sessions" ON public.academic_sessions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authorized officers can manage academic sessions" ON public.academic_sessions FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer')) WITH CHECK (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer'));

CREATE TABLE public.student_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid,
  student_number text UNIQUE,
  application_number text UNIQUE,
  full_name text NOT NULL,
  programme_id uuid REFERENCES public.programmes(id),
  academic_level text,
  admission_year integer,
  status text NOT NULL DEFAULT 'Applicant' CHECK (status IN ('Applicant', 'Admitted', 'Active', 'Suspended', 'Deferred', 'Withdrawn', 'Graduated', 'Archived')),
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_records TO authenticated;
GRANT ALL ON public.student_records TO service_role;
ALTER TABLE public.student_records ENABLE ROW LEVEL SECURITY;
CREATE INDEX student_records_user_id_idx ON public.student_records (auth_user_id);
CREATE INDEX student_records_status_idx ON public.student_records (status);
CREATE POLICY "Students can view their own record" ON public.student_records FOR SELECT TO authenticated USING (auth_user_id = auth.uid());
CREATE POLICY "Authorized academic and registry officers can view student records" ON public.student_records FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'registry_officer') OR public.has_role(auth.uid(), 'quality_assurance_officer')
);
CREATE POLICY "Authorized officers can add student records" ON public.student_records FOR INSERT TO authenticated WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'registry_officer')
);
CREATE POLICY "Authorized officers can update student records" ON public.student_records FOR UPDATE TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'registry_officer')
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'registry_officer')
);

CREATE TABLE public.staff_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid,
  employee_number text UNIQUE,
  full_name text NOT NULL,
  title text,
  department_id uuid REFERENCES public.departments(id),
  employment_status text NOT NULL DEFAULT 'Active' CHECK (employment_status IN ('Active', 'On leave', 'Retired', 'Separated')),
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.staff_records TO authenticated;
GRANT ALL ON public.staff_records TO service_role;
ALTER TABLE public.staff_records ENABLE ROW LEVEL SECURITY;
CREATE INDEX staff_records_user_id_idx ON public.staff_records (auth_user_id);
CREATE INDEX staff_records_department_id_idx ON public.staff_records (department_id);
CREATE POLICY "Staff can view their own record" ON public.staff_records FOR SELECT TO authenticated USING (auth_user_id = auth.uid());
CREATE POLICY "Authorized HR and executive officers can view staff records" ON public.staff_records FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'ict_administrator')
);
CREATE POLICY "Authorized HR officers can manage staff records" ON public.staff_records FOR ALL TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'ict_administrator')
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'ict_administrator')
);

CREATE TABLE public.announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  audience text NOT NULL DEFAULT 'institution' CHECK (audience IN ('institution', 'public', 'school', 'department', 'programme', 'students', 'staff')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'published', 'archived')),
  published_at timestamptz,
  expires_at timestamptz,
  publisher_name text NOT NULL DEFAULT 'HUKPOLY',
  created_by uuid,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.announcements TO authenticated;
GRANT SELECT ON public.announcements TO anon;
GRANT ALL ON public.announcements TO service_role;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
CREATE INDEX announcements_status_published_idx ON public.announcements (status, published_at DESC);
CREATE POLICY "Public can read published public notices" ON public.announcements FOR SELECT TO anon USING (
  audience IN ('institution', 'public') AND status = 'published' AND published_at IS NOT NULL AND published_at <= now() AND (expires_at IS NULL OR expires_at > now())
);
CREATE POLICY "Signed-in users can read published notices" ON public.announcements FOR SELECT TO authenticated USING (
  status = 'published' AND published_at IS NOT NULL AND published_at <= now() AND (expires_at IS NULL OR expires_at > now())
  OR created_by = auth.uid()
  OR public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'student_affairs_officer')
);
CREATE POLICY "Authorized officers can publish notices" ON public.announcements FOR INSERT TO authenticated WITH CHECK (
  created_by = auth.uid() AND (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'student_affairs_officer'))
);
CREATE POLICY "Authorized officers can update notices" ON public.announcements FOR UPDATE TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR (created_by = auth.uid() AND (public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'student_affairs_officer')))
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR (created_by = auth.uid() AND (public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'student_affairs_officer')))
);
CREATE POLICY "Super administrators can delete notices" ON public.announcements FOR DELETE TO authenticated USING (public.has_role(auth.uid(), 'super_admin'));

CREATE TABLE public.approval_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  area text NOT NULL DEFAULT 'institutional',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_review', 'approved', 'rejected', 'completed')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  assigned_to uuid,
  created_by uuid,
  due_at timestamptz,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.approval_tasks TO authenticated;
GRANT ALL ON public.approval_tasks TO service_role;
ALTER TABLE public.approval_tasks ENABLE ROW LEVEL SECURITY;
CREATE INDEX approval_tasks_assignee_status_idx ON public.approval_tasks (assigned_to, status);
CREATE POLICY "Users can view assigned approval tasks" ON public.approval_tasks FOR SELECT TO authenticated USING (assigned_to = auth.uid() OR created_by = auth.uid());
CREATE POLICY "Authorized managers can view all approval tasks" ON public.approval_tasks FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'finance_officer') OR public.has_role(auth.uid(), 'quality_assurance_officer')
);
CREATE POLICY "Authorized managers can create approval tasks" ON public.approval_tasks FOR INSERT TO authenticated WITH CHECK (
  created_by = auth.uid() AND (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'finance_officer'))
);
CREATE POLICY "Assignees and authorized managers can update approval tasks" ON public.approval_tasks FOR UPDATE TO authenticated USING (
  assigned_to = auth.uid() OR public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'finance_officer')
) WITH CHECK (
  assigned_to = auth.uid() OR public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'finance_officer')
);

CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  summary text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
CREATE INDEX audit_logs_created_at_idx ON public.audit_logs (created_at DESC);
CREATE POLICY "Authorized officers can review audit logs" ON public.audit_logs FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'ict_administrator') OR public.has_role(auth.uid(), 'quality_assurance_officer')
);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE INDEX notifications_user_created_idx ON public.notifications (user_id, created_at DESC);
CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Users can mark their own notifications read" ON public.notifications FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

INSERT INTO public.campuses (id, name, code, address, is_demo) VALUES
('10000000-0000-4000-8000-000000000001', 'HUKPOLY Main Campus (Sample)', 'DEMO-MAIN', 'Katsina State, Nigeria — demonstration record', true);

INSERT INTO public.schools (id, campus_id, name, code, is_demo) VALUES
('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'School of Engineering (Sample)', 'DEMO-ENG', true),
('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'School of Applied Sciences (Sample)', 'DEMO-SAS', true),
('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', 'School of Business Studies (Sample)', 'DEMO-SBS', true);

INSERT INTO public.departments (id, school_id, name, code, is_demo) VALUES
('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Computer Engineering (Sample)', 'DEMO-CPE', true),
('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'Computing (Sample)', 'DEMO-COMP', true),
('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000003', 'Accountancy (Sample)', 'DEMO-ACC', true);

INSERT INTO public.programmes (id, department_id, name, qualification, code, is_demo) VALUES
('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'Computer Science (Sample)', 'HND — sample programme', 'DEMO-HND-CS', true),
('40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001', 'Computer Engineering (Sample)', 'ND — sample programme', 'DEMO-ND-CE', true),
('40000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000003', 'Accountancy (Sample)', 'ND — sample programme', 'DEMO-ND-ACC', true);

INSERT INTO public.academic_sessions (id, name, status, is_demo) VALUES
('50000000-0000-4000-8000-000000000001', '2026/2027 (Sample — not official)', 'sample', true);

INSERT INTO public.student_records (id, student_number, application_number, full_name, programme_id, academic_level, admission_year, status, is_demo) VALUES
('60000000-0000-4000-8000-000000000001', 'DEMO/26/001', 'SAMPLE-APP-001', 'Amina Demo Student', '40000000-0000-4000-8000-000000000001', 'ND I (sample)', 2026, 'Active', true),
('60000000-0000-4000-8000-000000000002', 'DEMO/26/002', 'SAMPLE-APP-002', 'Usman Sample Student', '40000000-0000-4000-8000-000000000002', 'ND I (sample)', 2026, 'Admitted', true),
('60000000-0000-4000-8000-000000000003', 'DEMO/26/003', 'SAMPLE-APP-003', 'Hauwa Example Applicant', '40000000-0000-4000-8000-000000000003', NULL, 2026, 'Applicant', true);

INSERT INTO public.staff_records (id, employee_number, full_name, title, department_id, employment_status, is_demo) VALUES
('70000000-0000-4000-8000-000000000001', 'DEMO-EMP-001', 'Demo Academic Officer', 'Academic Officer (sample)', '30000000-0000-4000-8000-000000000002', 'Active', true),
('70000000-0000-4000-8000-000000000002', 'DEMO-EMP-002', 'Sample Registry Officer', 'Registry Officer (sample)', '30000000-0000-4000-8000-000000000003', 'Active', true);

INSERT INTO public.announcements (id, title, body, audience, status, published_at, publisher_name, is_demo) VALUES
('80000000-0000-4000-8000-000000000001', 'SAMPLE NOTICE — Academic calendar preview', 'This fictional notice is for demonstration only. The institution must configure and approve official dates before publishing.', 'public', 'published', now(), 'HUKPOLY Smart Campus — Demo', true),
('80000000-0000-4000-8000-000000000002', 'SAMPLE NOTICE — Student services preview', 'This sample notice demonstrates the campus noticeboard. It does not announce an official HUKPOLY policy or deadline.', 'public', 'published', now(), 'HUKPOLY Smart Campus — Demo', true),
('80000000-0000-4000-8000-000000000003', 'SAMPLE NOTICE — Admissions information preview', 'Admissions requirements and dates are not configured. Please consult official HUKPOLY channels for current information.', 'public', 'published', now(), 'HUKPOLY Smart Campus — Demo', true);

INSERT INTO public.approval_tasks (id, title, description, area, status, priority, is_demo) VALUES
('90000000-0000-4000-8000-000000000001', 'Review sample student record', 'Fictional demonstration task — no institutional action is required.', 'Registry', 'pending', 'normal', true),
('90000000-0000-4000-8000-000000000002', 'Review sample programme profile', 'Fictional demonstration task — policies must be configured by authorized officers.', 'Academic affairs', 'in_review', 'normal', true),
('90000000-0000-4000-8000-000000000003', 'Approve sample campus notice', 'Fictional demonstration task — demonstration data only.', 'Communications', 'pending', 'low', true);