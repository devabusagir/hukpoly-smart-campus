CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.user_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT _user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
      AND scope_type = 'institution' AND scope_id IS NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.has_scoped_role(_user_id uuid, _role public.user_role, _scope_type text, _scope_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT _user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
      AND scope_type = _scope_type AND scope_id = _scope_id
  );
$$;
GRANT EXECUTE ON FUNCTION public.has_scoped_role(uuid, public.user_role, text, uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.has_scoped_role(uuid, public.user_role, text, uuid) FROM PUBLIC, anon;

CREATE POLICY "HODs can view students in their own departments" ON public.student_records FOR SELECT TO authenticated USING (
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', (
    SELECT d.id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id
  ))
);
CREATE POLICY "Deans can view students in their own schools" ON public.student_records FOR SELECT TO authenticated USING (
  public.has_scoped_role(auth.uid(), 'dean', 'school', (
    SELECT d.school_id FROM public.programmes p JOIN public.departments d ON d.id = p.department_id WHERE p.id = student_records.programme_id
  ))
);

CREATE POLICY "Deans can view staff in their own schools" ON public.staff_records FOR SELECT TO authenticated USING (
  public.has_scoped_role(auth.uid(), 'dean', 'school', (
    SELECT d.school_id FROM public.departments d WHERE d.id = staff_records.department_id
  ))
);
CREATE POLICY "HODs can view staff in their own departments" ON public.staff_records FOR SELECT TO authenticated USING (
  public.has_scoped_role(auth.uid(), 'head_of_department', 'department', department_id)
);