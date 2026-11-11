CREATE OR REPLACE FUNCTION public.record_campus_audit_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  record_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    record_id := OLD.id;
  ELSE
    record_id := NEW.id;
  END IF;

  INSERT INTO public.audit_logs (actor_user_id, action, entity_type, entity_id, summary)
  VALUES (
    auth.uid(),
    lower(TG_OP),
    TG_TABLE_NAME,
    record_id,
    CASE WHEN TG_OP = 'DELETE' THEN 'Institutional record removed.' ELSE 'Institutional record changed.' END
  );
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE TRIGGER campus_audit_students AFTER INSERT OR UPDATE OR DELETE ON public.student_records FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_staff AFTER INSERT OR UPDATE OR DELETE ON public.staff_records FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_announcements AFTER INSERT OR UPDATE OR DELETE ON public.announcements FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_approvals AFTER INSERT OR UPDATE OR DELETE ON public.approval_tasks FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_campuses AFTER INSERT OR UPDATE OR DELETE ON public.campuses FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_schools AFTER INSERT OR UPDATE OR DELETE ON public.schools FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_departments AFTER INSERT OR UPDATE OR DELETE ON public.departments FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_programmes AFTER INSERT OR UPDATE OR DELETE ON public.programmes FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_sessions AFTER INSERT OR UPDATE OR DELETE ON public.academic_sessions FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();
CREATE TRIGGER campus_audit_user_roles AFTER INSERT OR UPDATE OR DELETE ON public.user_roles FOR EACH ROW EXECUTE FUNCTION public.record_campus_audit_event();