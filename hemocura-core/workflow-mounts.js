import {lazyMount} from './lazy-mount.js';
const mountTeamDeliveries=lazyMount(()=>import('./team-deliveries.js'),'mountTeamDeliveries');
const mountAreaAgenda=lazyMount(()=>import('./area-agenda.js'),'mountAreaAgenda');
const mountWorkflow=lazyMount(()=>import('./workflow.js'),'mountWorkflow');
const mountCommercial=lazyMount(()=>import('./commercial.js'),'mountCommercial');
const mountHyperbaric=lazyMount(()=>import('./hyperbaric.js'),'mountHyperbaric');
const mountBloodQuality=lazyMount(()=>import('./blood-quality.js'),'mountBloodQuality');
const mountBloodTransfers=lazyMount(()=>import('./blood-transfers.js'),'mountBloodTransfers');
const mountShiftReport=lazyMount(()=>import('./workflow-sales.js'),'mountShiftReport');
const mountSupplyCatalog=lazyMount(()=>import('./supply-catalog.js'),'mountSupplyCatalog');
export const enhanceWorkflowDaily=lazyMount(()=>import('./workflow-daily.js'),'enhanceWorkflowDaily');

export const WORKFLOW_MOUNTS={teamdeliveries:mountTeamDeliveries,extratrips:async root=>(await import('./extra-trips.js')).mountExtraTrips(root),laboratory:async root=>(await import('./laboratory.js')).mountLaboratory(root),sgcimplementation:async root=>(await import('./sgc-project.js')).mountSgcProject(root),areaagenda:mountAreaAgenda,workflow:mountWorkflow,commercial:mountCommercial,hyperbaric:mountHyperbaric,bloodquality:mountBloodQuality,transfers:mountBloodTransfers,shiftreport:mountShiftReport,supplycatalog:mountSupplyCatalog};
