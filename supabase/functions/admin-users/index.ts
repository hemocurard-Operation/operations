import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requireText(value: unknown, label: string) {
  const v = String(value ?? "").trim();
  if (!v) throw new Error(`${label} es obligatorio`);
  return v;
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

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: assignments, error: roleErr } = await admin
      .from("user_roles")
      .select("role_id")
      .eq("user_id", callerData.user.id);
    if (roleErr) throw roleErr;
    const roleIds = [...new Set((assignments || []).map((r: any) => r.role_id).filter(Boolean))];
    if (!roleIds.length) return json({ error: "ACCESS_ADMIN requerido" }, 403);

    const { data: adminPerms, error: permErr } = await admin
      .from("role_permissions")
      .select("permission_code")
      .in("role_id", roleIds)
      .eq("permission_code", "ACCESS_ADMIN")
      .limit(1);
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
      return json({ roles: roles || [], branches: branches || [] });
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
        const role = rm.get(ur.role_id) || {};
        const branch = bm.get(ur.branch_id) || {};
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
      return json({ users, roles: roles || [], branches: branches || [] });
    }

    if (action === "invite" || action === "create") {
      const email = requireText(body.email, "Correo").toLowerCase();
      const fullName = requireText(body.full_name, "Nombre");
      const roleId = requireText(body.role_id, "Rol");
      const branchId = requireText(body.branch_id, "Sucursal");

      const [{ data: role, error: roleCheckError }, { data: branch, error: branchCheckError }] = await Promise.all([
        admin.from("roles").select("id").eq("id", roleId).maybeSingle(),
        admin.from("branches").select("id,active").eq("id", branchId).maybeSingle(),
      ]);
      if (roleCheckError) throw roleCheckError;
      if (branchCheckError) throw branchCheckError;
      if (!role) return json({ error: "Rol inválido" }, 400);
      if (!branch?.active) return json({ error: "Sucursal inválida o inactiva" }, 400);

      let created: any;
      if (action === "invite") {
        const { data, error } = await admin.auth.admin.inviteUserByEmail(email, { data: { full_name: fullName } });
        if (error) throw error;
        created = data.user;
      } else {
        const password = requireText(body.password, "Contraseña temporal");
        if (password.length < 8) return json({ error: "La contraseña temporal debe tener al menos 8 caracteres" }, 400);
        const { data, error } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: false,
          user_metadata: { full_name: fullName },
        });
        if (error) throw error;
        created = data.user;
      }
      if (!created?.id) throw new Error("Supabase Auth no devolvió el usuario creado");

      try {
        const { error: profileError } = await admin.from("profiles").upsert({
          id: created.id,
          full_name: fullName,
          branch_id: branchId,
          active: true,
          updated_at: new Date().toISOString(),
        }, { onConflict: "id" });
        if (profileError) throw profileError;
        const { error: userRoleError } = await admin.from("user_roles").insert({ user_id: created.id, role_id: roleId, branch_id: branchId });
        if (userRoleError) throw userRoleError;
      } catch (e) {
        await admin.auth.admin.deleteUser(created.id).catch(() => undefined);
        throw e;
      }

      return json({ ok: true, user: { id: created.id, email, full_name: fullName } }, 201);
    }

    if (action === "add_role") {
      const userId = requireText(body.user_id, "Usuario");
      const roleId = requireText(body.role_id, "Rol");
      const branchId = requireText(body.branch_id, "Sucursal");
      const { error } = await admin.from("user_roles").upsert({ user_id: userId, role_id: roleId, branch_id: branchId });
      if (error) throw error;
      return json({ ok: true });
    }

    return json({ error: "Acción no soportada" }, 400);
  } catch (error) {
    console.error("[ADMIN_USERS]", error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
