import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { Database } from "@/integrations/supabase/types";

type Role = Database["public"]["Enums"]["user_role"];
type Notice = Pick<Database["public"]["Tables"]["announcements"]["Row"], "id" | "title" | "body" | "audience" | "status" | "publisher_name" | "published_at" | "is_demo" | "target_scope_type" | "target_scope_id">;
type CampusTask = Pick<Database["public"]["Tables"]["approval_tasks"]["Row"], "id" | "title" | "description" | "area" | "status" | "priority" | "created_at" | "is_demo">;

const noticeInput = z.object({
  title: z.string().trim().min(4).max(160),
  body: z.string().trim().min(10).max(4000),
  audience: z.enum(["institution", "public", "school", "department", "programme", "students", "staff"]),
  scopeType: z.enum(["school", "department", "programme"]).optional(),
  scopeId: z.string().uuid().optional(),
});

export const getCampusWorkspace = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const { supabase, userId } = context;
    const [profileResult, rolesResult, studentsResult, staffResult, campusesResult, schoolsResult,
      departmentsResult, programmesResult, sessionsResult, noticesResult, tasksResult, requestsResult, auditResult, notificationsResult] = await Promise.all([
      supabase.from("profiles").select("id, display_name, email").eq("id", userId).maybeSingle(),
      supabase.from("user_roles").select("role, scope_type, scope_id").eq("user_id", userId),
      supabase.from("student_records").select("id, student_number, application_number, full_name, programme_id, academic_level, admission_year, status, is_demo, updated_at", { count: "exact" }).order("created_at", { ascending: false }).limit(50),
      supabase.from("staff_records").select("id, employee_number, full_name, title, department_id, employment_status, is_demo", { count: "exact" }).order("created_at", { ascending: false }).limit(50),
      supabase.from("campuses").select("id, name, code, address, is_demo").order("name"),
      supabase.from("schools").select("id, name, code, campus_id, is_demo").order("name"),
      supabase.from("departments").select("id, name, code, school_id, is_demo").order("name"),
      supabase.from("programmes").select("id, name, code, qualification, department_id, is_demo").order("name"),
      supabase.from("academic_sessions").select("id, name, status, starts_on, ends_on, is_demo").order("created_at", { ascending: false }).limit(12),
      supabase.from("announcements").select("id, title, body, audience, status, publisher_name, published_at, is_demo, target_scope_type, target_scope_id").order("created_at", { ascending: false }).limit(30),
      supabase.from("approval_tasks").select("id, title, description, area, status, priority, created_at, is_demo").order("created_at", { ascending: false }).limit(30),
      supabase.from("access_requests").select("id, user_id, requested_role, scope_type, scope_id, justification, status, created_at").order("created_at", { ascending: false }).limit(30),
      supabase.from("audit_logs").select("id, actor_user_id, action, entity_type, entity_id, summary, created_at").order("created_at", { ascending: false }).limit(30),
      supabase.from("notifications").select("id, title, body, category, read_at, created_at").eq("user_id", userId).order("created_at", { ascending: false }).limit(30),
    ]);

    const results = [profileResult, rolesResult, studentsResult, staffResult, campusesResult, schoolsResult,
      departmentsResult, programmesResult, sessionsResult, noticesResult, tasksResult, requestsResult, auditResult, notificationsResult];
    const failed = results.find((result) => result.error);
    if (failed?.error) throw new Error("Campus records are temporarily unavailable. Please try again.");

    return {
      userId,
      profile: profileResult.data,
      roles: (rolesResult.data ?? []) as { role: Role; scope_type: string; scope_id: string | null }[],
      students: studentsResult.data ?? [],
      studentCount: studentsResult.count ?? 0,
      staff: staffResult.data ?? [],
      staffCount: staffResult.count ?? 0,
      campuses: campusesResult.data ?? [],
      schools: schoolsResult.data ?? [],
      departments: departmentsResult.data ?? [],
      programmes: programmesResult.data ?? [],
      sessions: sessionsResult.data ?? [],
      notices: (noticesResult.data ?? []) as Notice[],
      tasks: (tasksResult.data ?? []) as CampusTask[],
      accessRequests: requestsResult.data ?? [],
      auditLogs: auditResult.data ?? [],
      notifications: notificationsResult.data ?? [],
    };
  });

export const createStudentRecord = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => z.object({ fullName: z.string().trim().min(2).max(160), studentNumber: z.string().trim().max(40).optional(), applicationNumber: z.string().trim().max(40).optional(), programmeId: z.string().uuid().optional(), academicLevel: z.string().trim().max(40).optional() }).parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.from("student_records").insert({
      full_name: data.fullName,
      student_number: data.studentNumber || null,
      application_number: data.applicationNumber || null,
      programme_id: data.programmeId || null,
      academic_level: data.academicLevel || null,
      status: "Applicant",
      is_demo: false,
    });
    if (error) throw new Error("The student record could not be saved. Check your access and required details.");
    return { success: true };
  });

export const submitNotice = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => noticeInput.parse(input))
  .handler(async ({ data, context }) => {
    if ((data.scopeType && !data.scopeId) || (!data.scopeType && data.scopeId)) throw new Error("Choose a matching organization scope.");
    const { data: profile } = await context.supabase.from("profiles").select("display_name").eq("id", context.userId).maybeSingle();
    const { error } = await context.supabase.from("announcements").insert({
      title: data.title,
      body: data.body,
      audience: data.audience,
      target_scope_type: data.scopeType ?? null,
      target_scope_id: data.scopeId ?? null,
      created_by: context.userId,
      publisher_name: profile?.display_name || "Campus officer",
      status: "pending",
      published_at: null,
      is_demo: false,
    });
    if (error) throw new Error("The notice could not be submitted. Check your access and selected audience.");
    return { success: true };
  });

export const updateApprovalTask = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => z.object({ id: z.string().uuid(), status: z.enum(["pending", "in_review", "approved", "rejected", "completed"]) }).parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.from("approval_tasks").update({ status: data.status, updated_at: new Date().toISOString() }).eq("id", data.id);
    if (error) throw new Error("This task could not be updated with your current access.");
    return { success: true };
  });

export const requestCampusAccess = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => z.object({ role: z.custom<Role>((value) => typeof value === "string"), scopeType: z.enum(["institution", "school", "department"]), scopeId: z.string().uuid().optional(), justification: z.string().trim().min(12).max(1200) }).parse(input))
  .handler(async ({ data, context }) => {
    if ((data.scopeType === "institution" && data.scopeId) || (data.scopeType !== "institution" && !data.scopeId)) throw new Error("Choose the matching access scope.");
    const { error } = await context.supabase.from("access_requests").insert({ user_id: context.userId, requested_role: data.role, scope_type: data.scopeType, scope_id: data.scopeId ?? null, justification: data.justification, status: "pending" });
    if (error) throw new Error("Your access request could not be submitted.");
    return { success: true };
  });

export const reviewCampusAccess = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => z.object({ requestId: z.string().uuid(), status: z.enum(["approved", "rejected"]) }).parse(input))
  .handler(async ({ data, context }) => {
    const { data: isAdmin, error: roleError } = await context.supabase.rpc("has_role", { _user_id: context.userId, _role: "super_admin" });
    if (roleError || !isAdmin) throw new Error("Only a super administrator can review access requests.");
    const { data: accessRequest, error: requestError } = await context.supabase.from("access_requests").select("id, user_id, requested_role, scope_type, scope_id, status").eq("id", data.requestId).eq("status", "pending").maybeSingle();
    if (requestError || !accessRequest) throw new Error("This access request is no longer pending.");
    if (data.status === "approved") {
      const { error: grantError } = await context.supabase.from("user_roles").insert({ user_id: accessRequest.user_id, role: accessRequest.requested_role, scope_type: accessRequest.scope_type, scope_id: accessRequest.scope_id });
      if (grantError && grantError.code !== "23505") throw new Error("Access could not be granted. The request remains pending.");
    }
    const { error } = await context.supabase.from("access_requests").update({ status: data.status, reviewed_by: context.userId, reviewed_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq("id", accessRequest.id).eq("status", "pending");
    if (error) throw new Error("The access request could not be updated.");
    return { success: true };
  });

export const updateMyProfile = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => z.object({ displayName: z.string().trim().min(2).max(120) }).parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.from("profiles").update({ display_name: data.displayName, updated_at: new Date().toISOString() }).eq("id", context.userId);
    if (error) throw new Error("Your profile could not be updated.");
    return { success: true };
  });

export const markCampusNotificationRead = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((input: unknown) => z.object({ id: z.string().uuid() }).parse(input))
  .handler(async ({ data, context }) => {
    const { error } = await context.supabase.from("notifications").update({ read_at: new Date().toISOString() }).eq("id", data.id).eq("user_id", context.userId);
    if (error) throw new Error("This notification could not be marked as read.");
    return { success: true };
  });