ALTER TABLE public.announcements ADD COLUMN target_scope_type text CHECK (target_scope_type IS NULL OR target_scope_type IN ('school', 'department', 'programme'));
ALTER TABLE public.announcements ADD COLUMN target_scope_id uuid;
ALTER TABLE public.announcements ADD CONSTRAINT announcements_target_scope_pair_check CHECK ((target_scope_type IS NULL) = (target_scope_id IS NULL));
CREATE INDEX announcements_target_scope_idx ON public.announcements (target_scope_type, target_scope_id, status, published_at DESC);

DROP POLICY "Authorized officers can manage departments" ON public.departments;
CREATE POLICY "Authorized officers can manage departments within scope" ON public.departments FOR ALL TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', school_id) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', id)
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', school_id) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', id)
);

DROP POLICY "Authorized officers can manage schools" ON public.schools;
CREATE POLICY "Authorized officers can manage schools within scope" ON public.schools FOR ALL TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', id)
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', id)
);

DROP POLICY "Authorized officers can manage programmes" ON public.programmes;
CREATE POLICY "Authorized officers can manage programmes within scope" ON public.programmes FOR ALL TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.departments d WHERE d.id = programmes.department_id)) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', programmes.department_id)
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.departments d WHERE d.id = programmes.department_id)) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', programmes.department_id)
);

DROP POLICY "Authorized officers can add student records" ON public.student_records;
CREATE POLICY "Authorized officers can add student records within scope" ON public.student_records FOR INSERT TO authenticated WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'registry_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id)) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', (SELECT d.id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id))
);
DROP POLICY "Authorized officers can update student records" ON public.student_records;
CREATE POLICY "Authorized officers can update student records within scope" ON public.student_records FOR UPDATE TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'registry_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id)) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', (SELECT d.id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id))
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'registry_officer') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id)) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', (SELECT d.id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id))
);

DROP POLICY "Authorized HR officers can manage staff records" ON public.staff_records;
CREATE POLICY "Authorized HR officers can manage staff records within scope" ON public.staff_records FOR ALL TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.departments d WHERE d.id = staff_records.department_id)) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', staff_records.department_id)
) WITH CHECK (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR
  public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.departments d WHERE d.id = staff_records.department_id)) OR
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', staff_records.department_id)
);

REVOKE UPDATE ON public.approval_tasks FROM authenticated;
GRANT UPDATE (status, updated_at, description) ON public.approval_tasks TO authenticated;

DROP POLICY "Authorized officers can publish notices" ON public.announcements;
CREATE POLICY "Authorized officers can submit scoped notices for approval" ON public.announcements FOR INSERT TO authenticated WITH CHECK (
  created_by = auth.uid() AND status IN ('draft', 'pending') AND published_at IS NULL AND (
    public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'student_affairs_officer') OR
    (audience = 'school' AND target_scope_type = 'school' AND public.has_scoped_role(auth.uid(), 'dean', 'school', target_scope_id)) OR
    (audience = 'department' AND target_scope_type = 'department' AND (public.has_scoped_role(auth.uid(), 'dean', 'school', (SELECT d.school_id FROM public.departments d WHERE d.id = target_scope_id)) OR public.has_scoped_role(auth.uid(), 'head_of_department', 'department', target_scope_id)))
  )
);
DROP POLICY "Authorized officers can update notices" ON public.announcements;
CREATE POLICY "Authorized officers can review and publish notices" ON public.announcements FOR UPDATE TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR (created_by = auth.uid() AND (public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'student_affairs_officer')))
) WITH CHECK (
  (status IN ('draft', 'pending') AND created_by = auth.uid()) OR
  (status IN ('draft', 'pending', 'published', 'archived') AND (public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer')))
);

DROP POLICY "Signed-in users can read notices for their audience" ON public.announcements;
CREATE POLICY "Signed-in users can read published notices for their audience" ON public.announcements FOR SELECT TO authenticated USING (
  (status = 'published' AND published_at IS NOT NULL AND published_at <= now() AND (expires_at IS NULL OR expires_at > now()) AND (
    audience IN ('institution', 'public') OR
    (audience = 'students' AND (public.has_role(auth.uid(), 'student') OR public.has_role(auth.uid(), 'alumni'))) OR
    (audience = 'staff' AND (
      public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'lecturer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'registry_officer') OR public.has_role(auth.uid(), 'finance_officer') OR public.has_role(auth.uid(), 'library_officer') OR public.has_role(auth.uid(), 'hostel_officer') OR public.has_role(auth.uid(), 'student_affairs_officer') OR public.has_role(auth.uid(), 'siwes_coordinator') OR public.has_role(auth.uid(), 'quality_assurance_officer')
    )) OR
    (audience = 'school' AND target_scope_type = 'school' AND (
      public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_scoped_role(auth.uid(), 'dean', 'school', target_scope_id) OR
      EXISTS (SELECT 1 FROM public.student_records s JOIN public.programmes p ON p.id = s.programme_id JOIN public.departments d ON d.id = p.department_id WHERE s.auth_user_id = auth.uid() AND d.school_id = target_scope_id) OR
      EXISTS (SELECT 1 FROM public.staff_records sr JOIN public.departments d ON d.id = sr.department_id WHERE sr.auth_user_id = auth.uid() AND d.school_id = target_scope_id)
    )) OR
    (audience = 'department' AND target_scope_type = 'department' AND (
      public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_scoped_role(auth.uid(), 'head_of_department', 'department', target_scope_id) OR
      EXISTS (SELECT 1 FROM public.student_records s JOIN public.programmes p ON p.id = s.programme_id WHERE s.auth_user_id = auth.uid() AND p.department_id = target_scope_id) OR
      EXISTS (SELECT 1 FROM public.staff_records sr WHERE sr.auth_user_id = auth.uid() AND sr.department_id = target_scope_id)
    )) OR
    (audience = 'programme' AND target_scope_type = 'programme' AND EXISTS (SELECT 1 FROM public.student_records s WHERE s.auth_user_id = auth.uid() AND s.programme_id = target_scope_id))
  )) OR created_by = auth.uid() OR public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer')
);

DROP POLICY "Public can read published public notices" ON public.announcements;
CREATE POLICY "Public can read published institution and public notices" ON public.announcements FOR SELECT TO anon USING (
  audience IN ('institution', 'public') AND status = 'published' AND published_at IS NOT NULL AND published_at <= now() AND (expires_at IS NULL OR expires_at > now())
);