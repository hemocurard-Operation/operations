import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPER_ROLE = "SUPER_USUARIO";
const BRANCH_SCOPED_ROLES = new Set(["LABORATORIO", "CONSULTA", "ENCARGADA_LABORATORIO"]);

class HttpError extends Error {
  status: number;
  constructor(message: string, status = 400) {
    super(message);
    this.status = status;
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requireText(value: unknown, label: string) {
  const v = String(value ?? "").trim();
  if (!v) throw new HttpError(`${label} es obligatorio`, 400);
  return v;
}

function requestedBranchIds(body: any) {
  const values = Array.isArray(body.branch_ids) ? body.branch_ids : [];
  if (body.branch_id) values.push(body.branch_id);
  return [...new Set(values.map((v: unknown) => String(v ?? "").trim()).filter(Boolean))];
}

async function resolveRoleScope(admin: any, roleId: string, body: any, targetUserId?: string) {
  const [{ data: role, error: roleError }, { data: branches, error: branchError }] = await Promise.all([
    admin.from("roles").select("id,code,name").eq("id", roleId).maybeSingle(),
    admin.from("branches").select("id,code,name,active").eq("active", true).order("name"),
  ]);
  if (roleError) throw roleError;
  if (branchError) throw branchError;
  if (!role) throw new HttpError("Rol inválido", 400);

  const activeBranches = branches || [];
  if (!activeBranches.length) throw new HttpError("No existen sucursales activas", 409);

  if (role.code === SUPER_ROLE) {
    const { data: existing, error } = await admin
      .from("user_roles")
      .select("user_id")
      .eq("role_id", role.id);
    if (error) throw error;
    const holders = [...new Set((existing || []).map((x: any) => x.user_id).filter(Boolean))];
    const otherHolder = holders.find((id: string) => !targetUserId || id !== targetUserId);
    if (otherHolder) throw new HttpError("HemoCura permite un solo Superusuario global", 409);
    return { role, branches: activeBranches, scope: "GLOBAL" };
  }

  const ids = requestedBranchIds(body);
  if (BRANCH_SCOPED_ROLES.has(role.code) && ids.length !== 1) {
    throw new HttpError(`${role.name} debe asignarse a una sola sucursal por asignación`, 400);
  }
  if (!BRANCH_SCOPED_ROLES.has(role.code) && ids.length < 1) {
    throw new HttpError("Seleccione al menos una sucursal", 400);
  }

  const branchMap = new Map(activeBranches.map((b: any) => [b.id, b]));
  const invalid = ids.filter((id: string) => !branchMap.has(id));
  if (invalid.length) throw new HttpError("Una o más sucursales son inválidas o están inactivas", 400);
  return { role, branches: ids.map((id: string) => branchMap.get(id)), scope: BRANCH_SCOPED_ROLES.has(role.code) ? "BRANCH" : "MULTI_BRANCH" };
}

async function writeAudit(admin: any, callerId: string, action: string, targetUserId: string, role: any, branches: any[], scope: string) {
  const { error } = await admin.from("audit_events").insert({
    user_id: callerId,
    branch_id: null,
    module: "USERS_ADMIN",
    action,
    entity_table: "user_roles",
    entity_id: targetUserId,
    entity_reference: `${targetUserId}:${role.code}`,
    after_data: { role_id: role.id, role_code: role.code, branch_ids: branches.map((b: any) => b.id), scope },
    metadata: { source: "admin-users-edge", branch_codes: branches.map((b: any) => b.code) },
  });
  if (error) throw error;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) return json({ error: "Sesión requerida" }, 401);

    const callerClient = createClient(url, anonKey, { auth: { persistSession: false } });
    const { data: callerData, error: callerError } = await callerClient.auth.getUser(token);
    if (callerError || !callerData.user) return json({ error: "Sesión inválida" }, 401);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

    const { data: assignments, error: roleErr } = await admin.from("user_roles").select("role_id").eq("user_id", callerData.user.id);
    if (roleErr) throw roleErr;
    const roleIds = [...new Set((assignments || []).map((r: any) => r.role_id).filter(Boolean))];
    if (!roleIds.length) return json({ error: "ACCESS_ADMIN requerido" }, 403);

    const { data: adminPerms, error: permErr } = await admin.from("role_permissions").select("permission_code").in("role_id", roleIds).eq("permission_code", "ACCESS_ADMIN").limit(1);
    if (permErr) throw permErr;
    if (!adminPerms?.length) return json({ error: "ACCESS_ADMIN requerido" }, 403);

    const body = await req.json().catch(() => ({}));
    const action = String(body.action || "list");

    if (action === "catalogs") {
      const [{ data: roles, error: rolesError }, { data: branches, error: branchesError }] = await Promise.all([
        admin.from("roles").select("id,code,name").order("name"),
        admin.from("branches").select("id,code,name,active").eq("active", true).order("name"),
      ]);
      if (rolesError) throw rolesError;
      if (branchesError) throw branchesError;
      return json({ roles: roles || [], branches: branches || [], rules: { super_role: SUPER_ROLE, branch_scoped_roles: [...BRANCH_SCOPED_ROLES] } });
    }

    if (action === "list") {
      const [{ data: authData, error: authError }, { data: profiles, error: profilesError }, { data: userRoles, error: userRolesError }, { data: roles, error: rolesError }, { data: branches, error: branchesError }] = await Promise.all([
        admin.auth.admin.listUsers({ page: 1, perPage: 1000 }),
        admin.from("profiles").select("id,full_name,branch_id,active,created_at,updated_at"),
        admin.from("user_roles").select("user_id,role_id,branch_id"),
        admin.from("roles").select("id,code,name"),
        admin.from("branches").select("id,code,name,active"),
      ]);
      if (authError) throw authError;
      if (profilesError) throw profilesError;
      if (userRolesError) throw userRolesError;
      if (rolesError) throw rolesError;
      if (branchesError) throw branchesError;
      const pm = new Map((profiles || []).map((p: any) => [p.id, p]));
      const rm = new Map((roles || []).map((r: any) => [r.id, r]));
      const bm = new Map((branches || []).map((b: any) => [b.id, b]));
      const rolesByUser = new Map<string, any[]>();
      for (const ur of userRoles || []) {
        const arr = rolesByUser.get(ur.user_id) || [];
        const role: any = rm.get(ur.role_id) || {};
        const branch: any = bm.get(ur.branch_id) || {};
        arr.push({ role_id: ur.role_id, role_code: role.code || "", role_name: role.name || "", branch_id: ur.branch_id, branch_name: branch.name || "" });
        rolesByUser.set(ur.user_id, arr);
      }
      const users = (authData.users || []).map((u: any) => {
        const p: any = pm.get(u.id) || {};
        return {
          id: u.id,
          email: u.email || "",
          full_name: p.full_name || u.user_metadata?.full_name || "",
          branch_id: p.branch_id || null,
          branch_name: (bm.get(p.branch_id) as any)?.name || "",
          active: p.active !== false,
          roles: rolesByUser.get(u.id) || [],
          created_at: u.created_at,
          last_sign_in_at: u.last_sign_in_at || null,
          email_confirmed_at: u.email_confirmed_at || null,
        };
      });
      return json({ users, roles: roles || [], branches: branches || [], rules: { super_role: SUPER_ROLE, branch_scoped_roles: [...BRANCH_SCOPED_ROLES] } });
    }

    if (action === "invite" || action === "create") {
      const email = requireText(body.email, "Correo").toLowerCase();
      const fullName = requireText(body.full_name, "Nombre");
      const roleId = requireText(body.role_id, "Rol");
      const resolved = await resolveRoleScope(admin, roleId, body);

      let created: any;
      if (action === "invite") {
        const { data, error } = await admin.auth.admin.inviteUserByEmail(email, { data: { full_name: fullName } });
        if (error) throw error;
        created = data.user;
      } else {
        const password = requireText(body.password, "Contraseña temporal");
        if (password.length < 8) return json({ error: "La contraseña temporal debe tener al menos 8 caracteres" }, 400);
        const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: false, user_metadata: { full_name: fullName } });
        if (error) throw error;
        created = data.user;
      }
      if (!created?.id) throw new Error("Supabase Auth no devolvió el usuario creado");

      try {
        const primaryBranch = resolved.branches[0]?.id || null;
        const { error: profileError } = await admin.from("profiles").upsert({ id: created.id, full_name: fullName, branch_id: primaryBranch, active: true, updated_at: new Date().toISOString() }, { onConflict: "id" });
        if (profileError) throw profileError;
        const rows = resolved.branches.map((b: any) => ({ user_id: created.id, role_id: resolved.role.id, branch_id: b.id }));
        const { error: userRoleError } = await admin.from("user_roles").upsert(rows, { onConflict: "user_id,role_id,branch_id", ignoreDuplicates: true });
        if (userRoleError) throw userRoleError;
        await writeAudit(admin, callerData.user.id, action === "invite" ? "USER_INVITED" : "USER_CREATED", created.id, resolved.role, resolved.branches, resolved.scope);
      } catch (e) {
        await admin.auth.admin.deleteUser(created.id).catch(() => undefined);
        throw e;
      }

      return json({ ok: true, user: { id: created.id, email, full_name: fullName }, role: resolved.role.code, branches: resolved.branches.map((b: any) => b.code) }, 201);
    }

    if (action === "add_role") {
      const userId = requireText(body.user_id, "Usuario");
      const roleId = requireText(body.role_id, "Rol");
      const { data: profile, error: profileError } = await admin.from("profiles").select("id,active").eq("id", userId).maybeSingle();
      if (profileError) throw profileError;
      if (!profile) throw new HttpError("Usuario inválido", 404);
      if (profile.active === false) throw new HttpError("No se pueden agregar roles a un usuario inactivo", 409);

      const resolved = await resolveRoleScope(admin, roleId, body, userId);
      const rows = resolved.branches.map((b: any) => ({ user_id: userId, role_id: resolved.role.id, branch_id: b.id }));
      const { error } = await admin.from("user_roles").upsert(rows, { onConflict: "user_id,role_id,branch_id", ignoreDuplicates: true });
      if (error) throw error;
      await writeAudit(admin, callerData.user.id, "ROLE_ASSIGNED", userId, resolved.role, resolved.branches, resolved.scope);
      return json({ ok: true, role: resolved.role.code, branches: resolved.branches.map((b: any) => b.code) });
    }

    return json({ error: "Acción no soportada" }, 400);
  } catch (error) {
    console.error("[ADMIN_USERS]", error);
    const status = error instanceof HttpError ? error.status : 500;
    return json({ error: error instanceof Error ? error.message : String(error) }, status);
  }
});
