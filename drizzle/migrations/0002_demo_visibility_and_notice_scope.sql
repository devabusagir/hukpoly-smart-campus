REVOKE UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE (display_name) ON public.profiles TO authenticated;

CREATE POLICY "Users can read explicitly labelled sample student records" ON public.student_records FOR SELECT TO authenticated USING (is_demo = true);
CREATE POLICY "Users can read explicitly labelled sample staff records" ON public.staff_records FOR SELECT TO authenticated USING (is_demo = true);
CREATE POLICY "Users can read explicitly labelled sample approval tasks" ON public.approval_tasks FOR SELECT TO authenticated USING (is_demo = true);

DROP POLICY "Signed-in users can read published notices" ON public.announcements;
CREATE POLICY "Signed-in users can read notices for their audience" ON public.announcements FOR SELECT TO authenticated USING (
  (status = 'published' AND published_at IS NOT NULL AND published_at <= now() AND (expires_at IS NULL OR expires_at > now()) AND (
    audience IN ('institution', 'public') OR
    (audience = 'students' AND (public.has_role(auth.uid(), 'student') OR public.has_role(auth.uid(), 'alumni'))) OR
    (audience = 'staff' AND (
      public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'ict_administrator') OR public.has_role(auth.uid(), 'dean') OR public.has_role(auth.uid(), 'head_of_department') OR public.has_role(auth.uid(), 'lecturer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'registry_officer') OR public.has_role(auth.uid(), 'finance_officer') OR public.has_role(auth.uid(), 'library_officer') OR public.has_role(auth.uid(), 'hostel_officer') OR public.has_role(auth.uid(), 'student_affairs_officer') OR public.has_role(auth.uid(), 'siwes_coordinator') OR public.has_role(auth.uid(), 'quality_assurance_officer')
    ))
  )) OR created_by = auth.uid()
  OR public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer')
);