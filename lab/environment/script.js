/* ════════════════════════════════════════
   script.js — Server Test Page
   ════════════════════════════════════════ */

const loc = window.location;

// ── Info cards ──
document.getElementById('protocol').textContent = loc.protocol.replace(':', '').toUpperCase();
document.getElementById('hostname').textContent = loc.hostname || 'localhost';
document.getElementById('port').textContent     = loc.port || (loc.protocol === 'https:' ? '443' : '80');
document.getElementById('viewport').textContent = `${window.innerWidth} × ${window.innerHeight} px`;

// Page load time (available after the load event)
window.addEventListener('load', () => {
  const t = performance.getEntriesByType('navigation')[0];
  if (t) {
    const ms = Math.round(t.loadEventEnd - t.startTime);
    const el = document.getElementById('load-time');
    el.textContent = ms + ' ms';
    if (ms > 1000) el.classList.replace('ok', 'warn');
  }
});

// ── Request details table ──
const rows = [
  ['Full URL',         loc.href],
  ['Path',            loc.pathname || '/'],
  ['User-Agent',      navigator.userAgent],
  ['Language',        navigator.language],
  ['Cookies enabled', navigator.cookieEnabled ? 'Yes' : 'No'],
  ['Online',          navigator.onLine ? 'Yes' : 'No'],
  ['Referrer',        document.referrer || '(none)'],
  ['Connection',      navigator.connection?.effectiveType?.toUpperCase() || 'Unknown'],
];

const tbody = document.getElementById('request-table');
rows.forEach(([k, v]) => {
  const tr = document.createElement('tr');
  tr.innerHTML = `<td>${k}</td><td>${v}</td>`;
  tbody.appendChild(tr);
});

// ── Live UTC clock ──
const clock = document.getElementById('clock');
const tick = () => { clock.textContent = new Date().toUTCString(); };
tick();
setInterval(tick, 1000);

// ── Viewport size on resize ──
window.addEventListener('resize', () => {
  document.getElementById('viewport').textContent = `${window.innerWidth} × ${window.innerHeight} px`;
});
