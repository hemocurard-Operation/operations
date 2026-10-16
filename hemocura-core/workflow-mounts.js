import {mountAreaAgenda} from './area-agenda.js';
import { mountWorkflow } from './workflow.js';
import { mountCommercial } from './commercial.js';
import { mountHyperbaric } from './hyperbaric.js';
import { mountBloodQuality } from './blood-quality.js';
import { mountBloodTransfers } from './blood-transfers.js';
import { mountShiftReport } from './workflow-sales.js';
import { mountSupplyCatalog } from './supply-catalog.js';
export { enhanceWorkflowDaily } from './workflow-daily.js';

export const WORKFLOW_MOUNTS={areaagenda:mountAreaAgenda,workflow:mountWorkflow,commercial:mountCommercial,hyperbaric:mountHyperbaric,bloodquality:mountBloodQuality,transfers:mountBloodTransfers,shiftreport:mountShiftReport,supplycatalog:mountSupplyCatalog};
