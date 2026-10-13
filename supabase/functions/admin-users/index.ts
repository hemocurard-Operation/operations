import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

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
  const v = typeof value === "string" ? value.trim() : "";
  if (!v) throw new HttpError(`${label} es obligatorio`, 400);
  return v;
}

function requestedBranchIds(body: any) {
  if (body.branch_ids !== undefined && !Array.isArray(body.branch_ids)) throw new HttpError("Sucursales debe ser una lista", 400);
  const values = [...(body.branch_ids || [])];
  if (body.branch_id !== undefined) values.push(body.branch_id);
  if (values.some((v: unknown) => typeof v !== "string" || !v.trim())) throw new HttpError("Cada sucursal debe ser un identificador válido", 400);
  return [...new Set(values.map((v: string) => v.trim()))];
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

    const callerClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: callerData, error: callerError } = await callerClient.auth.getUser(token);
    if (callerError || !callerData.user) return json({ error: "Sesión inválida" }, 401);

    const { data: callerProfile, error: callerProfileError } = await callerClient.from("profiles").select("id,active").eq("id", callerData.user.id).maybeSingle();
    if (callerProfileError || !callerProfile || callerProfile.active !== true) return json({ error: "Perfil activo requerido" }, 403);

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

    const { data: assignments, error: roleErr } = await admin.from("user_roles").select("role_id").eq("user_id", callerData.user.id);
    if (roleErr) throw roleErr;
    const roleIds = [...new Set((assignments || []).map((r: any) => r.role_id).filter(Boolean))];
    if (!roleIds.length) return json({ error: "ACCESS_ADMIN requerido" }, 403);

    // Permission flags alone must never grant authority to manage identities.
    const { data: superRole, error: superRoleError } = await admin.from("roles").select("id,code").eq("code", SUPER_ROLE).maybeSingle();
    if (superRoleError) throw superRoleError;
    if (!superRole || !roleIds.includes(superRole.id)) return json({ error: "Solo el Super Usuario puede administrar cuentas, claves y roles" }, 403);

    const { data: adminPerms, error: permErr } = await admin.from("role_permissions").select("permission_code").in("role_id", roleIds).eq("permission_code", "ACCESS_ADMIN").limit(1);
    if (permErr) throw permErr;
    if (!adminPerms?.length) return json({ error: "ACCESS_ADMIN requerido" }, 403);

    const { data: permission, error: permissionError } = await admin.from("app_permissions").select("permission_code,active").eq("permission_code", "ACCESS_ADMIN").eq("active", true).maybeSingle();
    if (permissionError) throw permissionError;
    if (!permission) return json({ error: "ACCESS_ADMIN activo requerido" }, 403);

    let body: any;
    try { body = await req.json(); } catch { throw new HttpError("JSON inválido", 400); }
    if (!body || typeof body !== "object" || Array.isArray(body)) throw new HttpError("El cuerpo debe ser un objeto JSON", 400);
    if (body.action !== undefined && (typeof body.action !== "string" || !body.action.trim())) throw new HttpError("Acción inválida", 400);
    const action = body.action === undefined ? "list" : body.action.trim();

    if (action === "change_password") {
      const userId = requireText(body.user_id, "Usuario");
      // Keep the exact secret, including intentional spaces; never put it in logs/audit.
      const password = typeof body.password === "string" ? body.password : "";
      if (password.length < 12 || password.length > 128 || !password.trim()) throw new HttpError("La clave debe tener entre 12 y 128 caracteres", 400);
      const { data: target, error: targetError } = await admin.from("profiles").select("id,active").eq("id", userId).maybeSingle();
      if (targetError) throw targetError;
      if (!target) throw new HttpError("Usuario no encontrado", 404);
      if (target.active !== true) throw new HttpError("El usuario debe estar activo", 409);
      // Record intent first: if audit is unavailable, do not change credentials.
      const audit = { user_id: callerData.user.id, branch_id: null, module: "USERS_ADMIN", entity_table: "profiles", entity_id: userId, entity_reference: userId, metadata: { source: "admin-users-edge", credential_values_logged: false } };
      const { error: auditError } = await admin.from("audit_events").insert({ ...audit, action: "PASSWORD_CHANGE_REQUESTED" });
      if (auditError) throw auditError;
      const { error: passwordError } = await admin.auth.admin.updateUserById(userId, { password });
      if (passwordError) {
        await admin.from("audit_events").insert({ ...audit, action: "PASSWORD_CHANGE_FAILED" });
        throw new HttpError("No se pudo cambiar la clave. Verifique los requisitos de seguridad de la cuenta.", 400);
      }
      const { error: completedError } = await admin.from("audit_events").insert({ ...audit, action: "PASSWORD_CHANGED" });
      return json({ ok: true, audit_complete: !completedError, message: completedError ? "Clave cambiada; el registro de finalización de auditoría requiere revisión." : "Clave cambiada correctamente." });
    }

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
          active: p.active === true,
          roles: rolesByUser.get(u.id) || [],
          created_at: u.created_at,
          last_sign_in_at: u.last_sign_in_at || null,
          email_confirmed_at: u.email_confirmed_at || null,
        };
      });
      return json({ caller_user_id: callerData.user.id, users, roles: roles || [], branches: branches || [], rules: { super_role: SUPER_ROLE, branch_scoped_roles: [...BRANCH_SCOPED_ROLES] } });
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
        if (password.length < 12 || password.length > 128) return json({ error: "La contraseña temporal debe tener entre 12 y 128 caracteres" }, 400);
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

    if (action === "remove_role") {
      const userId = requireText(body.user_id, "Usuario");
      const roleId = requireText(body.role_id, "Rol");
      if (userId === callerData.user.id) return json({ error: "No puede retirar sus propios roles" }, 409);
      const branches = requestedBranchIds(body);
      if (!branches.length) return json({ error: "Seleccione asignaciones por sucursal" }, 400);
      const { data, error } = await callerClient.rpc("remove_user_role", {
        p_user_id: userId, p_role_id: roleId, p_branch_ids: branches,
      });
      if (error) {
        const status = error.code === "42501" ? 403 : error.code === "23514" ? 409 : error.code === "P0002" ? 404 : error.code === "22023" || error.code === "22P02" ? 400 : 500;
        throw new HttpError(error.message, status);
      }
      return json({ ok: true, removed_assignments: data });
    }

    if (action === "add_role") {
      const userId = requireText(body.user_id, "Usuario");
      const roleId = requireText(body.role_id, "Rol");
      const { data: profile, error: profileError } = await admin.from("profiles").select("id,active").eq("id", userId).maybeSingle();
      if (profileError) throw profileError;
      if (!profile) throw new HttpError("Usuario inválido", 404);
      if (profile.active !== true) throw new HttpError("Se requiere un perfil explícitamente activo para agregar roles", 409);

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
