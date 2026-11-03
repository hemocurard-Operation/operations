// Pure helpers for the monthly environmental-control grid: no Supabase calls here,
// so the day-status logic can be reasoned about (and tested) without a database.

export function daysInMonth(year, month) {
  return new Date(year, month, 0).getDate();
}

function inRange(point, value) {
  if (point.min_allowed != null && value < point.min_allowed) return false;
  if (point.max_allowed != null && value > point.max_allowed) return false;
  return true;
}

// Status for one point on one day, from that day's readings (chronological order assumed).
// 'empty' = no readings; 'ok' = every reading in range; 'bad' = ends the day out of range;
// 'partial' = an out-of-range reading exists but a later one that day is back in range.
export function dayStatus(point, dayReadings) {
  if (!dayReadings.length) return 'empty';
  let sawOutOfRange = false;
  let lastInRange = true;
  for (const r of dayReadings) {
    const ok = inRange(point, Number(r.value));
    if (!ok) sawOutOfRange = true;
    lastInRange = ok;
  }
  if (!sawOutOfRange) return 'ok';
  return lastInRange ? 'partial' : 'bad';
}

// Groups a flat readings array by point_id, then by local calendar day (1..daysInMonth).
export function groupReadingsByPointAndDay(readings) {
  const byPoint = new Map();
  for (const r of readings) {
    const day = new Date(r.reading_time).getDate();
    if (!byPoint.has(r.point_id)) byPoint.set(r.point_id, new Map());
    const byDay = byPoint.get(r.point_id);
    if (!byDay.has(day)) byDay.set(day, []);
    byDay.get(day).push(r);
  }
  return byPoint;
}

// Builds { [point.id]: { [day]: status } } for every point x every day of the month.
export function buildMonthMatrix(points, readings, year, month) {
  const total = daysInMonth(year, month);
  const byPoint = groupReadingsByPointAndDay(readings);
  const matrix = {};
  for (const point of points) {
    const byDay = byPoint.get(point.id) || new Map();
    matrix[point.id] = {};
    for (let d = 1; d <= total; d++) {
      matrix[point.id][d] = dayStatus(point, byDay.get(d) || []);
    }
  }
  return matrix;
}

export function monthRangeISO(year, month) {
  const from = new Date(year, month - 1, 1);
  const to = new Date(year, month, 1);
  return { fromISO: from.toISOString(), toISO: to.toISOString() };
}
