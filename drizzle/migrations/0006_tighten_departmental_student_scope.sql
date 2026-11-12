DROP POLICY "Authorized academic and registry officers can view student records" ON public.student_records;
CREATE POLICY "Institution officers can view student records" ON public.student_records FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'registry_officer') OR public.has_role(auth.uid(), 'quality_assurance_officer')
);
CREATE POLICY "Deans can view student records in their own schools" ON public.student_records FOR SELECT TO authenticated USING (
  public.has_scoped_role(auth.uid(), 'dean', 'school', (
    SELECT d.school_id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id
  ))
);
CREATE POLICY "HODs can view student records in their own departments" ON public.student_records FOR SELECT TO authenticated USING (
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', (
    SELECT d.id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id
  ))
);

DROP POLICY "Authorized managers can view all approval tasks" ON public.approval_tasks;
CREATE POLICY "Authorized managers can view all approval tasks" ON public.approval_tasks FOR SELECT TO authenticated USING (
  public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'finance_officer') OR public.has_role(auth.uid(), 'quality_assurance_officer')
);
DROP POLICY "Assignees and authorized managers can update approval tasks" ON public.approval_tasks;
CREATE POLICY "Assignees and authorized managers can update approval tasks" ON public.approval_tasks FOR UPDATE TO authenticated USING (
  assigned_to = auth.uid() OR public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'finance_officer')
) WITH CHECK (
  assigned_to = auth.uid() OR public.has_role(auth.uid(), 'super_admin') OR public.has_role(auth.uid(), 'rector') OR public.has_role(auth.uid(), 'executive_management') OR public.has_role(auth.uid(), 'registrar') OR public.has_role(auth.uid(), 'deputy_registrar') OR public.has_role(auth.uid(), 'bursar') OR public.has_role(auth.uid(), 'academic_affairs_officer') OR public.has_role(auth.uid(), 'examination_officer') OR public.has_role(auth.uid(), 'finance_officer')
);
REVOKE UPDATE ON public.approval_tasks FROM authenticated;
GRANT UPDATE (status, updated_at, description) ON public.approval_tasks TO authenticated;