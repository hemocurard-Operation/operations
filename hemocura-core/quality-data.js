import { getSupabase } from './supabase.js';

export async function getQualityToday(filters = {}) {
  console.info('[HEMOCURA_QUALITY_KPI] vw_quality_today', filters);

  let q = getSupabase()
    .from('vw_quality_today')
    .select('measurement_date,branch_id,indicator_code,indicator_name,value,status,process_code,process_name')
    .order('measurement_date', { ascending: false })
    .order('process_name', { ascending: true });

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.date) q = q.eq('measurement_date', filters.date);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] quality today', error);
    throw new Error(`Indicadores de calidad: ${error.message}`);
  }
  return data || [];
}

export async function getIncidents(filters = {}) {
  console.info('[HEMOCURA_INCIDENT] incidents', filters);

  let q = getSupabase()
    .from('incidents')
    .select('id,incident_code,incident_date,incident_time,branch_id,classification,process_name,severity,description,patient_or_donor_affected,impact_detail,immediate_action,evidence_url,requires_quality_followup,created_at')
    .order('incident_date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(100);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);
  if (filters.from) q = q.gte('incident_date', filters.from);
  if (filters.to) q = q.lte('incident_date', filters.to);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] incidents', error);
    throw new Error(`Incidencias: ${error.message}`);
  }
  return data || [];
}

export async function createIncident(payload) {
  console.info('[HEMOCURA_INCIDENT] create');
  const { data, error } = await getSupabase()
    .from('incidents')
    .insert({
      incident_code: payload.incidentCode,
      incident_date: payload.incidentDate,
      incident_time: payload.incidentTime || null,
      branch_id: payload.branchId || null,
      classification: payload.classification || null,
      process_name: payload.processName || null,
      severity: Number(payload.severity || 1),
      description: payload.description,
      patient_or_donor_affected: !!payload.patientOrDonorAffected,
      impact_detail: payload.impactDetail || null,
      immediate_action: payload.immediateAction || null,
      evidence_url: payload.evidenceUrl || null,
      requires_quality_followup: !!payload.requiresQualityFollowup
    })
    .select()
    .single();

  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] create incident', error);
    throw new Error(`Crear incidencia: ${error.message}`);
  }
  return data;
}

export async function getNonconformities(filters = {}) {
  console.info('[HEMOCURA_NC] nonconformities');

  let q = getSupabase()
    .from('nonconformities')
    .select('id,code,incident_id,branch_id,process_id,detected_at,description,root_cause,status,owner_user_id,due_date,created_at')
    .order('detected_at', { ascending: false })
    .limit(100);

  if (filters.branchId) q = q.eq('branch_id', filters.branchId);

  const { data, error } = await q;
  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] nonconformities', error);
    throw new Error(`No conformidades: ${error.message}`);
  }
  return data || [];
}

export async function getCapa() {
  console.info('[HEMOCURA_CAPA] capa');

  const { data, error } = await getSupabase()
    .from('capa')
    .select('id,code,nonconformity_id,problem,root_cause,action_plan,owner_user_id,due_date,status,effectiveness_status,effectiveness_notes,closed_at,created_at')
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] capa', error);
    throw new Error(`CAPA: ${error.message}`);
  }
  return data || [];
}

export async function getOpenQualityAlerts() {
  const { data, error } = await getSupabase()
    .from('vw_open_management_alerts')
    .select('id,alert_date,branch_id,branch,category,severity,title,description,status,due_at')
    .order('alert_date', { ascending: false })
    .limit(50);

  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] alerts', error);
    throw new Error(`Alertas: ${error.message}`);
  }
  return data || [];
}

export async function createNonconformity(payload) {
  console.info('[HEMOCURA_NC] create');

  const { data, error } = await getSupabase()
    .from('nonconformities')
    .insert({
      code: payload.code,
      incident_id: payload.incidentId || null,
      branch_id: payload.branchId || null,
      process_id: payload.processId || null,
      description: payload.description,
      root_cause: payload.rootCause || null,
      status: payload.status || 'ABIERTA',
      due_date: payload.dueDate || null
    })
    .select()
    .single();

  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] create NC', error);
    throw new Error(`Crear no conformidad: ${error.message}`);
  }
  return data;
}

export async function createCapa(payload) {
  console.info('[HEMOCURA_CAPA] create');

  const { data, error } = await getSupabase()
    .from('capa')
    .insert({
      code: payload.code,
      nonconformity_id: payload.nonconformityId || null,
      problem: payload.problem,
      root_cause: payload.rootCause || null,
      action_plan: payload.actionPlan,
      due_date: payload.dueDate || null,
      status: payload.status || 'ABIERTA',
      effectiveness_status: 'PENDIENTE'
    })
    .select()
    .single();

  if (error) {
    console.error('[HEMOCURA_QUALITY_ERROR] create CAPA', error);
    throw new Error(`Crear CAPA: ${error.message}`);
  }
  return data;
}

export async function loadQualityWorkspace(filters = {}) {
  const results = await Promise.allSettled([
    getQualityToday(filters),
    getIncidents(filters),
    getNonconformities(filters),
    getCapa(),
    getOpenQualityAlerts()
  ]);

  const values = results.map(r => r.status === 'fulfilled' ? r.value : []);
  const errors = results
    .filter(r => r.status === 'rejected')
    .map(r => r.reason?.message || 'Error');

  return {
    measurements: values[0],
    incidents: values[1],
    nonconformities: values[2],
    capa: values[3],
    alerts: values[4],
    errors
  };
}
