/* Interfaz de la app: pista con cronómetros, registro, contabilidad y ajustes. */
(function () {
  'use strict';
  const C = window.Core;
  const S = window.Store;

  const $ = (sel, el = document) => el.querySelector(sel);
  const $$ = (sel, el = document) => Array.from(el.querySelectorAll(sel));
  const esc = (v) =>
    String(v === null || v === undefined ? '' : v).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
  const money = (v) => C.formatMoney(v);
  const today = () => C.dayKey(Date.now());

  let state = S.load();
  const ui = {
    view: 'pista',
    from: today(),
    to: today(),
    regDay: today(),
    silenced: new Set(),
    notified: new Set(),
    lastBeep: 0,
    saveFailed: false,
  };
  const BASE_TITLE = document.title;

  // ---------------------------------------------------------------- utilidades
  function persist() {
    const ok = S.save(state);
    if (!ok && !ui.saveFailed) toast('No se pudo guardar en este navegador. Descarga un respaldo en Ajustes.', 'error');
    ui.saveFailed = !ok;
  }

  function commit() {
    persist();
    render();
  }

  let toastTimer;
  function toast(msg, kind = 'ok') {
    const el = $('#toast');
    el.textContent = msg;
    el.className = `toast show ${kind}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (el.className = 'toast'), 3200);
  }

  function attempt(fn) {
    try {
      fn();
      return true;
    } catch (err) {
      toast(err.message || String(err), 'error');
      return false;
    }
  }

  function findRental(id) {
    return state.rentals.find((r) => r.id === id);
  }

  function activeRentals() {
    return state.rentals.filter((r) => r.status === 'active');
  }

  function download(name, content, type) {
    const blob = new Blob([content], { type });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }

  function methodOptions(selected = 'Efectivo') {
    return C.PAYMENT_METHODS.map((m) => `<option ${m === selected ? 'selected' : ''}>${esc(m)}</option>`).join('');
  }

  function rangeLabel(from, to) {
    const fmt = (d) => {
      const [y, m, dd] = d.split('-').map(Number);
      return new Date(y, m - 1, dd).toLocaleDateString('es-CO', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' });
    };
    return from === to ? fmt(from) : `${fmt(from)} — ${fmt(to)}`;
  }

  function shiftDay(day, delta) {
    const t = C.noonOf(day) + delta * 24 * 60 * 60 * 1000;
    return C.dayKey(t);
  }

  const CAR_SVG = `<svg class="car-icon" viewBox="0 0 64 40" aria-hidden="true"><path d="M6 27 10 17q2-6 9-6h20q6 0 10 5l5 6 4 1q3 1 3 5v3H3v-3q0-1 3-1Z" fill="currentColor"/><path d="M18 15h10v7H14Zm14 0h7q3 0 6 7H32Z" fill="#fff" opacity=".85"/><circle cx="16" cy="32" r="6" fill="#26303b"/><circle cx="48" cy="32" r="6" fill="#26303b"/><circle cx="16" cy="32" r="2.4" fill="#cfd6de"/><circle cx="48" cy="32" r="2.4" fill="#cfd6de"/></svg>`;

  // ---------------------------------------------------------------- sonido y avisos
  let audioCtx = null;
  function unlockAudio() {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!audioCtx && AC) audioCtx = new AC();
    if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
  }

  function beep() {
    if (!audioCtx) return;
    const t0 = audioCtx.currentTime;
    [0, 0.22, 0.44].forEach((d, i) => {
      const o = audioCtx.createOscillator();
      const g = audioCtx.createGain();
      o.type = 'square';
      o.frequency.value = i === 2 ? 1320 : 880;
      g.gain.setValueAtTime(0.0001, t0 + d);
      g.gain.exponentialRampToValueAtTime(0.2, t0 + d + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + d + 0.18);
      o.connect(g).connect(audioCtx.destination);
      o.start(t0 + d);
      o.stop(t0 + d + 0.2);
    });
  }

  function askNotificationPermission() {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission().catch(() => {});
    }
  }

  function notifyExpired(r) {
    if (navigator.vibrate) navigator.vibrate([300, 150, 300]);
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    const title = `⏰ ${r.carName}: se acabó el tiempo`;
    const opts = { body: `${C.kidsLabel(r.kids)}${r.customer ? ' · ' + r.customer : ''}`, tag: r.id, renotify: true, icon: 'icons/icon.svg' };
    try {
      if (navigator.serviceWorker && navigator.serviceWorker.controller) {
        navigator.serviceWorker.ready.then((reg) => reg.showNotification(title, opts)).catch(() => {});
      } else {
        new Notification(title, opts);
      }
    } catch (_) {
      /* algunos navegadores móviles solo permiten notificaciones desde el service worker */
    }
  }

  // Mantener la pantalla encendida mientras haya carros en pista.
  let wakeLock = null;
  let wakeLockPending = false;
  function syncWakeLock(hasActive) {
    if (!('wakeLock' in navigator)) return;
    if (hasActive && !wakeLock && !wakeLockPending && document.visibilityState === 'visible') {
      wakeLockPending = true;
      navigator.wakeLock
        .request('screen')
        .then((lock) => {
          wakeLock = lock;
          lock.addEventListener('release', () => (wakeLock = null));
        })
        .catch(() => {})
        .finally(() => (wakeLockPending = false));
    } else if (!hasActive && wakeLock) {
      wakeLock.release().catch(() => {});
      wakeLock = null;
    }
  }

  // ---------------------------------------------------------------- cronómetro
  function tick() {
    const now = Date.now();
    const clock = new Date(now).toLocaleString('es-CO', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
    $('#clock').textContent = clock.charAt(0).toUpperCase() + clock.slice(1);

    let expiredCount = 0;
    let ring = false;
    const active = activeRentals();
    for (const r of active) {
      const t = C.timeStatus(r, now, state.settings);
      const expired = t.state === 'expired';
      if (expired) {
        expiredCount += 1;
        if (!ui.silenced.has(r.id)) ring = true;
        if (!ui.notified.has(r.id)) {
          ui.notified.add(r.id);
          notifyExpired(r);
        }
      }
      const card = document.querySelector(`[data-rental="${r.id}"]`);
      if (!card) continue;
      card.querySelector('[data-role=time]').textContent = C.formatClock(t.remainingMs);
      card.querySelector('[data-role=label]').textContent = expired ? 'tiempo extra' : 'restante';
      card.querySelector('[data-role=bar]').style.width = `${Math.round(t.progress * 100)}%`;
      card.classList.toggle('warn', t.state === 'warn');
      card.classList.toggle('expired', expired);
      card.classList.toggle('silenced', ui.silenced.has(r.id));
    }
    document.title = expiredCount ? `⏰ (${expiredCount}) ¡Tiempo cumplido! · ${BASE_TITLE}` : BASE_TITLE;
    if (ring && state.settings.sound && now - ui.lastBeep > 6000) {
      ui.lastBeep = now;
      beep();
    }
    syncWakeLock(active.length > 0);
  }

  // ---------------------------------------------------------------- render
  function render() {
    $('#bizName').textContent = state.settings.businessName;
    $$('[data-view]').forEach((b) => {
      if (b.dataset.view === ui.view) b.setAttribute('aria-current', 'page');
      else b.removeAttribute('aria-current');
    });
    const views = { pista: viewPista, registro: viewRegistro, contabilidad: viewContabilidad, ajustes: viewAjustes };
    $('#main').innerHTML = views[ui.view]();
    renderHeaderTotals();
    tick();
  }

  function renderHeaderTotals() {
    const rep = C.report(state, today(), today());
    $('#headerTotals').innerHTML = `<span>Producido hoy</span><strong>${money(rep.produced)}</strong>`;
  }

  function kpi(label, value, kind = '', hint = '') {
    return `<div class="kpi ${kind}"><span class="kpi-label">${label}</span><strong class="kpi-value">${value}</strong>${hint ? `<span class="kpi-hint">${hint}</span>` : ''}</div>`;
  }

  // ----- Pista
  function viewPista() {
    const cars = state.cars.filter((c) => c.active);
    const activeMap = new Map(activeRentals().map((r) => [r.carId, r]));
    const rep = C.report(state, today(), today());
    const strip = `<section class="kpis">
      ${kpi('En pista', activeMap.size)}
      ${kpi('Disponibles', Math.max(0, cars.length - activeMap.size))}
      ${kpi('Viajes hoy', rep.rides, '', C.kidsLabel(rep.kids))}
      ${kpi('Recaudado hoy', money(rep.collected), 'good')}
      ${kpi('Por cobrar hoy', money(rep.pendingFromPeriod), rep.pendingFromPeriod ? 'bad' : '')}
    </section>`;
    if (!cars.length) {
      return `${strip}<section class="panel welcome">
        ${CAR_SVG}
        <h2>Agrega tus carros</h2>
        <p class="sub">Registra cada carro con su nombre (por ejemplo: Rayo McQueen, Ferrari rojo, Jeep rosado) para llevar el tiempo y lo producido por cada uno.</p>
        <button class="btn primary big" data-action="car-new">+ Agregar carro</button>
      </section>`;
    }
    return `${strip}<section class="car-grid">${cars.map((c) => carCard(c, activeMap.get(c.id))).join('')}
      <button class="car-card add-tile" data-action="car-new"><span aria-hidden="true">+</span>Agregar carro</button>
    </section>`;
  }

  function carCard(car, r) {
    const s = state.settings;
    if (!r) {
      return `<article class="car-card free" style="--car:${esc(car.color)}">
        <header>${CAR_SVG}<h3>${esc(car.name)}</h3><span class="badge free">Disponible</span><button class="icon-btn edit" data-action="car-edit" data-id="${car.id}" aria-label="Editar ${esc(car.name)}" title="Cambiar nombre o color">✎</button></header>
        <div class="free-prices">
          <span>1 niño <b>${money(s.prices[1])}</b></span>
          <span>2 niños <b>${money(s.prices[2])}</b></span>
          <small>cada ${s.blockMinutes} min</small>
        </div>
        <button class="btn primary big" data-action="rent" data-car="${car.id}">Alquilar</button>
      </article>`;
    }
    const t = C.rentalTotals(r);
    return `<article class="car-card busy" data-rental="${r.id}" style="--car:${esc(car.color)}">
      <header>${CAR_SVG}<h3>${esc(car.name)}</h3><span class="badge pay-${t.payStatus}">${C.PAY_STATUS_LABELS[t.payStatus]}</span></header>
      <div class="timer"><span data-role="time" class="time">--:--</span><small data-role="label">restante</small></div>
      <div class="bar" aria-hidden="true"><span data-role="bar"></span></div>
      <dl class="meta">
        <div><dt>Niños</dt><dd>${r.kids}</dd></div>
        <div><dt>Inicio</dt><dd>${C.formatTime(r.startAt)}</dd></div>
        <div><dt>Termina</dt><dd>${C.formatTime(C.endAt(r))}</dd></div>
        <div><dt>Total</dt><dd>${money(t.charged)}</dd></div>
      </dl>
      ${r.customer ? `<p class="customer">${esc(r.customer)}</p>` : ''}
      <div class="card-actions">
        <button class="btn danger btn-silence" data-action="silence" data-id="${r.id}">Silenciar alarma</button>
        <button class="btn" data-action="extend" data-id="${r.id}">+${s.blockMinutes} min</button>
        ${t.balance > 0 ? `<button class="btn warn" data-action="charge" data-id="${r.id}">Cobrar ${money(t.balance)}</button>` : ''}
        <button class="btn primary" data-action="finish" data-id="${r.id}">Finalizar</button>
      </div>
    </article>`;
  }

  // ----- Registro
  function rentalRow(r, opts = {}) {
    const t = C.rentalTotals(r);
    const cancelled = r.status === 'cancelled';
    const payBadge = cancelled ? '' : `<span class="badge pay-${t.payStatus}">${C.PAY_STATUS_LABELS[t.payStatus]}</span>`;
    return `<tr class="${cancelled ? 'muted' : ''}">
      ${opts.showDay ? `<td>${r.startAt ? C.dayKey(r.startAt) : ''}</td>` : ''}
      <td>${C.formatTime(r.startAt)}</td>
      <td>${esc(r.carName)}</td>
      <td class="num">${r.kids}</td>
      <td class="num">${r.minutes} min</td>
      <td>${esc(r.customer) || '<span class="muted">—</span>'}</td>
      <td class="num">${cancelled ? '—' : money(t.charged)}</td>
      <td class="num">${cancelled ? '—' : money(t.paid)}</td>
      <td class="num ${t.balance > 0 && !cancelled ? 'bad' : ''}">${cancelled ? '—' : money(Math.max(0, t.balance))}</td>
      <td><span class="status s-${r.status}">${C.STATUS_LABELS[r.status]}</span> ${payBadge}</td>
      <td class="actions">
        ${!cancelled && t.balance > 0 ? `<button class="btn small warn" data-action="charge" data-id="${r.id}">Cobrar</button>` : ''}
        <button class="btn small" data-action="detail" data-id="${r.id}">Ver</button>
      </td>
    </tr>`;
  }

  function rentalTable(list, opts = {}) {
    return `<div class="table-wrap"><table class="table">
      <thead><tr>
        ${opts.showDay ? '<th>Día</th>' : ''}
        <th>Hora</th><th>Carro</th><th class="num">Niños</th><th class="num">Tiempo</th><th>Cliente</th>
        <th class="num">Total</th><th class="num">Pagado</th><th class="num">Saldo</th><th>Estado</th><th></th>
      </tr></thead>
      <tbody>${list.map((r) => rentalRow(r, opts)).join('')}</tbody>
    </table></div>`;
  }

  function viewRegistro() {
    const day = ui.regDay;
    const list = state.rentals.filter((r) => C.dayKey(r.startAt) === day).sort((a, b) => b.startAt - a.startAt);
    const pending = state.rentals
      .filter((r) => r.status !== 'cancelled' && C.rentalTotals(r).balance > 0)
      .sort((a, b) => a.startAt - b.startAt);
    const pendingTotal = C.sum(pending, (r) => C.rentalTotals(r).balance);
    const rep = C.report(state, day, day);
    return `
    <section class="panel">
      <div class="panel-head">
        <h2>Registro de alquileres</h2>
        <div class="toolbar">
          <button class="btn small" data-action="reg-shift" data-delta="-1" aria-label="Día anterior">‹</button>
          <input type="date" value="${day}" data-change="regDay" aria-label="Día">
          <button class="btn small" data-action="reg-shift" data-delta="1" aria-label="Día siguiente">›</button>
          <button class="btn small" data-action="export-rentals">Exportar CSV</button>
        </div>
      </div>
      <p class="sub">${rangeLabel(day, day)} · ${rep.rides} viajes · ${rep.kids} niños · ${rep.minutes} minutos · producido ${money(rep.produced)}</p>
      ${list.length ? rentalTable(list) : '<p class="empty">No hay alquileres registrados este día.</p>'}
    </section>
    <section class="panel">
      <div class="panel-head">
        <h2>Cartera pendiente</h2>
        <strong class="${pendingTotal ? 'bad' : ''}">${money(pendingTotal)}</strong>
      </div>
      <p class="sub">Alquileres que aún no han pagado completo, de cualquier día.</p>
      ${pending.length ? rentalTable(pending, { showDay: true }) : '<p class="empty">Todo está cobrado.</p>'}
    </section>`;
  }

  // ----- Contabilidad
  function simpleTable(head, rows, foot) {
    return `<div class="table-wrap"><table class="table compact">
      <thead><tr>${head.map((h, i) => `<th class="${i ? 'num' : ''}">${h}</th>`).join('')}</tr></thead>
      <tbody>${rows.length ? rows.map((r) => `<tr>${r.map((c, i) => `<td class="${i ? 'num' : ''}">${c}</td>`).join('')}</tr>`).join('') : `<tr><td colspan="${head.length}" class="muted">Sin movimientos</td></tr>`}</tbody>
      ${foot ? `<tfoot><tr>${foot.map((c, i) => `<td class="${i ? 'num' : ''}">${c}</td>`).join('')}</tr></tfoot>` : ''}
    </table></div>`;
  }

  function viewContabilidad() {
    const { from, to } = ui;
    const single = from === to;
    const rep = C.report(state, from, to);
    const entries = C.journal(state, from, to);
    const led = C.ledger(entries);

    const methodRows = Object.entries(rep.byMethod)
      .sort((a, b) => b[1] - a[1])
      .map(([m, v]) => [esc(m), money(v)]);
    const carRows = Object.values(rep.byCar)
      .sort((a, b) => (b.produced || 0) - (a.produced || 0))
      .map((c) => [esc(c.name), c.rides || 0, `${c.minutes || 0} min`, money(c.produced || 0)]);
    const kidsRows = [1, 2].map((k) => [C.kidsLabel(k), rep.byKids[k].rides, money(rep.byKids[k].produced)]);
    const dayRows = Object.entries(rep.byDay)
      .filter(([, d]) => d.produced || d.collected || d.expenses || d.rides)
      .map(([d, v]) => [d, v.rides || 0, money(v.produced || 0), money(v.collected || 0), money(v.expenses || 0), money((v.produced || 0) - (v.expenses || 0))]);

    const expenseLines = Object.entries(rep.expensesByCategory).map(
      ([cat, v]) => `<tr><td>(−) ${esc(C.expenseCategory(cat).name)}</td><td class="num">${money(-v)}</td></tr>`
    );

    const cash = rep.cash;
    const closureHtml = single
      ? `<section class="panel no-break">
        <div class="panel-head"><h2>Cierre de caja (efectivo)</h2>${cash.closedAt ? `<span class="badge pay-pagado">Cerrada ${C.formatTime(cash.closedAt)}</span>` : '<span class="badge pay-pendiente">Abierta</span>'}</div>
        <div class="cash-grid" data-cash>
          <label class="field">Base inicial de caja<input type="text" inputmode="numeric" name="openingCash" value="${cash.opening || ''}" placeholder="0" data-input="cash"></label>
          <div class="cash-line"><span>(+) Efectivo recibido</span><strong>${money(cash.cashIn)}</strong></div>
          <div class="cash-line"><span>(−) Gastos pagados en efectivo</span><strong>${money(-cash.cashOut)}</strong></div>
          <div class="cash-line total"><span>(=) Efectivo que debe haber</span><strong data-role="expected">${money(cash.expected)}</strong></div>
          <label class="field">Efectivo contado<input type="text" inputmode="numeric" name="countedCash" value="${cash.counted === null ? '' : cash.counted}" placeholder="Cuente el dinero" data-input="cash"></label>
          <div class="cash-line total"><span>Diferencia</span><strong data-role="diff">${cash.diff === null ? '—' : diffLabel(cash.diff)}</strong></div>
          <label class="field wide">Observaciones<input type="text" name="notes" value="${esc(cash.notes)}" maxlength="140"></label>
        </div>
        <div class="row-end no-print"><button class="btn primary" data-action="save-closure">Guardar cierre de caja</button></div>
        <p class="sub">Digital (Nequi, Daviplata, transferencias, tarjeta) del día: <strong>${money(rep.digitalCollected)}</strong></p>
      </section>`
      : '';

    return `
    <section class="panel no-print">
      <div class="toolbar wrap">
        <label class="inline">Desde <input type="date" value="${from}" data-change="from"></label>
        <label class="inline">Hasta <input type="date" value="${to}" data-change="to"></label>
        <button class="btn small" data-action="range" data-range="today">Hoy</button>
        <button class="btn small" data-action="range" data-range="yesterday">Ayer</button>
        <button class="btn small" data-action="range" data-range="week">7 días</button>
        <button class="btn small" data-action="range" data-range="month">Este mes</button>
        <span class="spacer"></span>
        <button class="btn small" data-action="add-expense">+ Registrar gasto</button>
        <button class="btn small" data-action="export-journal">Libro diario CSV</button>
        <button class="btn small" data-action="print">Imprimir</button>
      </div>
    </section>

    <h2 class="report-title">Reporte contable · ${esc(state.settings.businessName)}<small>${rangeLabel(from, to)}</small></h2>

    <section class="kpis">
      ${kpi('Producido (ventas)', money(rep.produced), '', `${rep.rides} viajes · ${C.kidsLabel(rep.kids)}`)}
      ${kpi('Recaudado', money(rep.collected), 'good', `Efectivo ${money(rep.cashCollected)} · Digital ${money(rep.digitalCollected)}`)}
      ${kpi('Por cobrar', money(rep.pendingFromPeriod), rep.pendingFromPeriod ? 'bad' : '', `Cartera total ${money(rep.receivablesTotal)}`)}
      ${kpi('Gastos', money(rep.expensesTotal), '', `${rep.expenses.length} registros`)}
      ${kpi('Utilidad neta', money(rep.netIncome), rep.netIncome >= 0 ? 'good' : 'bad', `Flujo de caja ${money(rep.cashFlow)}`)}
    </section>

    <div class="grid-2">
      <section class="panel no-break">
        <h2>Estado de resultados</h2>
        <div class="table-wrap"><table class="table compact">
          <tbody>
            <tr><td>Ingresos por alquiler</td><td class="num">${money(rep.produced)}</td></tr>
            <tr class="muted"><td>&nbsp;&nbsp;Alquileres</td><td class="num">${money(rep.byChargeType.base || 0)}</td></tr>
            <tr class="muted"><td>&nbsp;&nbsp;Tiempo adicional</td><td class="num">${money(rep.byChargeType.extension || 0)}</td></tr>
            <tr class="muted"><td>&nbsp;&nbsp;Tiempo extra cobrado</td><td class="num">${money(rep.byChargeType.overtime || 0)}</td></tr>
            ${expenseLines.join('')}
            ${rep.writeOffs ? `<tr><td>(−) Clientes que no pagaron</td><td class="num">${money(-rep.writeOffs)}</td></tr>` : ''}
            ${rep.cashAdjust ? `<tr><td>(${rep.cashAdjust > 0 ? '+' : '−'}) ${rep.cashAdjust > 0 ? 'Sobrante' : 'Faltante'} de caja</td><td class="num">${money(rep.cashAdjust)}</td></tr>` : ''}
          </tbody>
          <tfoot><tr><td>Utilidad neta</td><td class="num">${money(rep.netIncome)}</td></tr></tfoot>
        </table></div>
        ${rep.collectedFromPrevious ? `<p class="sub">Incluye ${money(rep.collectedFromPrevious)} recaudados de deudas de días anteriores.</p>` : ''}
      </section>
      <section class="panel no-break">
        <h2>Recaudo por medio de pago</h2>
        ${simpleTable(['Medio', 'Valor'], methodRows, ['Total', money(rep.collected)])}
        <h2>Por número de niños</h2>
        ${simpleTable(['Tipo', 'Viajes', 'Producido'], kidsRows)}
      </section>
    </div>

    <section class="panel no-break">
      <h2>Producido por carro</h2>
      ${simpleTable(['Carro', 'Viajes', 'Tiempo', 'Producido'], carRows, ['Total', rep.rides, `${rep.minutes} min`, money(rep.produced)])}
    </section>

    ${!single ? `<section class="panel no-break"><h2>Producido por día</h2>${simpleTable(['Día', 'Viajes', 'Producido', 'Recaudado', 'Gastos', 'Utilidad'], dayRows)}</section>` : ''}

    ${closureHtml}

    <section class="panel">
      <div class="panel-head"><h2>Gastos</h2><button class="btn small no-print" data-action="add-expense">+ Registrar gasto</button></div>
      ${
        rep.expenses.length
          ? `<div class="table-wrap"><table class="table compact">
          <thead><tr><th>Fecha</th><th>Concepto</th><th>Categoría</th><th>Medio</th><th class="num">Valor</th><th class="no-print"></th></tr></thead>
          <tbody>${rep.expenses
            .slice()
            .sort((a, b) => a.at - b.at)
            .map(
              (e) => `<tr><td>${C.dayKey(e.at)} ${C.formatTime(e.at)}</td><td>${esc(e.concept)}</td><td>${esc(C.expenseCategory(e.category).name)}</td><td>${esc(e.method)}</td><td class="num">${money(e.amount)}</td><td class="no-print actions"><button class="btn small danger" data-action="delete-expense" data-id="${e.id}">Eliminar</button></td></tr>`
            )
            .join('')}</tbody>
          <tfoot><tr><td colspan="4">Total gastos</td><td class="num">${money(rep.expensesTotal)}</td><td class="no-print"></td></tr></tfoot>
        </table></div>`
          : '<p class="empty">No hay gastos registrados.</p>'
      }
    </section>

    <section class="panel">
      <div class="panel-head"><h2>Libro diario</h2><span class="sub">${entries.length} asientos · partida doble</span></div>
      ${
        entries.length
          ? `<div class="table-wrap"><table class="table compact journal">
          <thead><tr><th>N°</th><th>Fecha</th><th>Descripción</th><th>Cuenta</th><th class="num">Débito</th><th class="num">Crédito</th></tr></thead>
          ${entries
            .map(
              (e) => `<tbody class="entry">${e.lines
                .map(
                  (l, i) => `<tr>
                  ${i === 0 ? `<td rowspan="${e.lines.length}">${e.number}</td><td rowspan="${e.lines.length}">${e.day} ${C.formatTime(e.at)}<br><small class="muted">${esc(e.ref)}</small></td><td rowspan="${e.lines.length}">${esc(e.description)}</td>` : ''}
                  <td class="${l.credit ? 'indent' : ''}">${esc(l.code)} ${esc(l.name)}</td>
                  <td class="num">${l.debit ? money(l.debit) : ''}</td>
                  <td class="num">${l.credit ? money(l.credit) : ''}</td>
                </tr>`
                )
                .join('')}</tbody>`
            )
            .join('')}
          <tfoot><tr><td colspan="4">Sumas iguales</td><td class="num">${money(led.totalDebit)}</td><td class="num">${money(led.totalCredit)}</td></tr></tfoot>
        </table></div>`
          : '<p class="empty">Sin asientos en este periodo.</p>'
      }
    </section>

    <section class="panel no-break">
      <h2>Balance de comprobación</h2>
      ${simpleTable(
        ['Cuenta', 'Débitos', 'Créditos', 'Saldo'],
        led.accounts.map((a) => [`${esc(a.code)} ${esc(a.name)}`, money(a.debit), money(a.credit), money(a.balance)]),
        ['Totales', money(led.totalDebit), money(led.totalCredit), led.totalDebit === led.totalCredit ? 'Cuadra ✓' : 'No cuadra']
      )}
    </section>`;
  }

  function diffLabel(diff) {
    if (diff === 0) return 'Cuadra ✓';
    return diff > 0 ? `Sobra ${money(diff)}` : `Falta ${money(-diff)}`;
  }

  // ----- Ajustes
  function viewAjustes() {
    const s = state.settings;
    const carRows = state.cars
      .map((c) => {
        const busy = activeRentals().some((r) => r.carId === c.id);
        return `<li class="car-row ${c.active ? '' : 'muted'}">
          <input type="color" value="${esc(c.color)}" data-change="car-color" data-id="${c.id}" aria-label="Color de ${esc(c.name)}">
          <input type="text" value="${esc(c.name)}" maxlength="${C.CAR_NAME_MAX}" data-change="car-name" data-id="${c.id}" aria-label="Nombre del carro">
          ${busy ? '<span class="badge pay-parcial">En pista</span>' : ''}
          ${
            c.active
              ? `<button class="btn small" data-action="car-toggle" data-id="${c.id}" ${busy ? 'disabled' : ''}>Desactivar</button>`
              : `<button class="btn small" data-action="car-toggle" data-id="${c.id}">Activar</button>`
          }
          <button class="btn small danger" data-action="car-delete" data-id="${c.id}" ${busy ? 'disabled' : ''}>Eliminar</button>
        </li>`;
      })
      .join('');

    return `
    <section class="panel">
      <h2>Carros</h2>
      <p class="sub">Escribe el nombre de cada carro. Puedes cambiar el nombre o el color tocándolo.</p>
      <ul class="car-list">${carRows || '<li class="muted">Todavía no hay carros. Agrega el primero abajo.</li>'}</ul>
      <form class="add-car" data-submit="car-add" novalidate>
        <input type="color" name="color" value="${C.nextCarColor(state)}" aria-label="Color del nuevo carro">
        <input type="text" name="name" placeholder="Nombre del carro (ej. Rayo McQueen)" maxlength="${C.CAR_NAME_MAX}" autocomplete="off" required>
        <button type="submit" class="btn primary">Agregar carro</button>
      </form>
    </section>

    <section class="panel">
      <h2>Precios y tiempos</h2>
      <form id="settingsForm" class="settings-grid" onsubmit="return false">
        <label class="field">Nombre del negocio<input name="businessName" value="${esc(s.businessName)}" maxlength="40"></label>
        <label class="field">Precio 1 niño (por bloque)<input name="price1" inputmode="numeric" value="${s.prices[1]}"></label>
        <label class="field">Precio 2 niños (por bloque)<input name="price2" inputmode="numeric" value="${s.prices[2]}"></label>
        <label class="field">Minutos por bloque<input name="blockMinutes" type="number" min="1" value="${s.blockMinutes}"></label>
        <label class="field">Tiempo mínimo (min)<input name="minMinutes" type="number" min="1" value="${s.minMinutes}"></label>
        <label class="field">Opciones de tiempo (min, separadas por coma)<input name="durationOptions" value="${s.durationOptions.join(', ')}"></label>
        <label class="field">Tolerancia antes de cobrar extra (min)<input name="graceMinutes" type="number" min="0" value="${s.graceMinutes}"></label>
        <label class="field">Aviso amarillo (segundos antes)<input name="warnSeconds" type="number" min="0" value="${s.warnSeconds}"></label>
        <label class="check"><input type="checkbox" name="sound" ${s.sound ? 'checked' : ''}> Sonar alarma cuando se acaba el tiempo</label>
      </form>
      <div class="row-end">
        <button class="btn" data-action="test-sound">Probar alarma</button>
        <button class="btn primary" data-action="save-settings">Guardar ajustes</button>
      </div>
    </section>

    <section class="panel">
      <h2>Respaldo de datos</h2>
      <p class="sub">Los datos se guardan en este dispositivo. Descarga un respaldo con frecuencia (por ejemplo, al cerrar cada día).</p>
      <div class="toolbar wrap">
        <button class="btn primary" data-action="backup">Descargar respaldo</button>
        <label class="btn">Restaurar respaldo<input type="file" accept="application/json,.json" data-change="restore" hidden></label>
        <span class="spacer"></span>
        <button class="btn danger" data-action="wipe">Borrar todos los datos</button>
      </div>
    </section>`;
  }

  // ---------------------------------------------------------------- modal
  function openModal({ title, body, actions, onAction, onInput, onClose }) {
    const dlg = $('#modal');
    const form = $('#modalForm');
    if (dlg.open) dlg.close();
    form.innerHTML = `
      <header class="modal-head"><h2 id="modalTitle">${title}</h2><button type="button" class="icon-btn" data-close aria-label="Cerrar">×</button></header>
      <div class="modal-body">${body}</div>
      <footer class="modal-actions">${actions
        .map((a) =>
          a.value === 'cancel'
            ? `<button type="button" class="btn" data-close>${a.label}</button>`
            : `<button type="submit" value="${a.value}" class="btn ${a.kind || ''}">${a.label}</button>`
        )
        .join('')}</footer>`;
    let closedByAction = false;
    const close = () => dlg.open && dlg.close();
    form.onsubmit = (e) => {
      e.preventDefault();
      const value = e.submitter ? e.submitter.value : actions.find((a) => a.value !== 'cancel').value;
      const result = onAction ? onAction(value, form) : true;
      if (result !== false) {
        closedByAction = true;
        close();
      }
    };
    form.oninput = () => onInput && onInput(form);
    form.onchange = () => onInput && onInput(form);
    $$('[data-close]', form).forEach((b) => (b.onclick = close));
    dlg.onclose = () => {
      if (dlg.open) return; // evento atrasado de un modal anterior
      if (!closedByAction && onClose) onClose();
    };
    dlg.showModal();
    if (onInput) onInput(form);
    const first = form.querySelector('.modal-body input:not([type=radio]):not([hidden]), .modal-body select');
    if (first && window.matchMedia('(pointer: fine)').matches) first.focus();
  }

  // ----- Alquilar
  function openRentModal(car) {
    const s = state.settings;
    const opts = s.durationOptions.filter((m) => m >= s.minMinutes && m % s.blockMinutes === 0);
    const body = `
      <fieldset class="seg">
        <legend>¿Cuántos niños se montan?</legend>
        <label><input type="radio" name="kids" value="1" checked><span>1 niño<b>${money(s.prices[1])}</b><small>cada ${s.blockMinutes} min</small></span></label>
        <label><input type="radio" name="kids" value="2"><span>2 niños<b>${money(s.prices[2])}</b><small>cada ${s.blockMinutes} min</small></span></label>
      </fieldset>
      <fieldset class="seg chips">
        <legend>Tiempo</legend>
        ${opts.map((m, i) => `<label><input type="radio" name="minutesOpt" value="${m}" ${i === 0 ? 'checked' : ''}><span>${m} min</span></label>`).join('')}
        <label><input type="radio" name="minutesOpt" value="custom"><span>Otro</span></label>
      </fieldset>
      <label class="field" data-show="custom" hidden>Minutos (mínimo ${s.minMinutes}, de ${s.blockMinutes} en ${s.blockMinutes})
        <input type="number" name="minutesCustom" min="${s.minMinutes}" step="${s.blockMinutes}" value="${s.minMinutes}">
      </label>
      <label class="field">Nombre del niño o acudiente (opcional)<input name="customer" maxlength="60" autocomplete="off"></label>
      <fieldset class="seg">
        <legend>Pago</legend>
        <label><input type="radio" name="pay" value="now" checked><span>Pagó ahora</span></label>
        <label><input type="radio" name="pay" value="later"><span>Paga al final</span></label>
      </fieldset>
      <label class="field" data-show="paynow">Medio de pago<select name="method">${methodOptions()}</select></label>
      <div class="total-box"><span>Total a cobrar</span><strong data-role="total">—</strong><small data-role="detail"></small></div>`;

    const read = (form) => {
      const f = form.elements;
      const opt = form.querySelector('[name=minutesOpt]:checked').value;
      const minutes = opt === 'custom' ? Number(f.minutesCustom.value) : Number(opt);
      return {
        kids: Number(form.querySelector('[name=kids]:checked').value),
        minutes,
        custom: opt === 'custom',
        payNow: form.querySelector('[name=pay]:checked').value === 'now',
        method: f.method.value,
        customer: f.customer.value,
      };
    };

    openModal({
      title: `Alquilar ${esc(car.name)}`,
      body,
      actions: [
        { value: 'cancel', label: 'Cancelar' },
        { value: 'start', label: 'Iniciar tiempo', kind: 'primary' },
      ],
      onInput(form) {
        const v = read(form);
        form.querySelector('[data-show=custom]').hidden = !v.custom;
        form.querySelector('[data-show=paynow]').hidden = !v.payNow;
        let text = '—';
        let detail = '';
        try {
          C.validateMinutes(v.minutes, s);
          text = money(C.priceFor(v.kids, v.minutes, s));
          detail = `${C.kidsLabel(v.kids)} · ${v.minutes} min · ${v.payNow ? 'pagado en ' + v.method : 'pendiente de pago'}`;
        } catch (err) {
          detail = err.message;
        }
        form.querySelector('[data-role=total]').textContent = text;
        form.querySelector('[data-role=detail]').textContent = detail;
      },
      onAction(value, form) {
        const v = read(form);
        unlockAudio();
        askNotificationPermission();
        return attempt(() => {
          if (activeRentals().some((r) => r.carId === car.id)) throw new Error('Este carro ya está en pista');
          const r = C.createRental({ car, settings: s, ...v });
          state.rentals.push(r);
          commit();
          toast(`${car.name} en pista por ${v.minutes} min`);
        });
      },
    });
  }

  // ----- Agregar / editar carro
  function openCarModal(car, { added = [] } = {}) {
    const editing = Boolean(car);
    const color = editing ? car.color : C.nextCarColor(state);
    const palette = C.CAR_COLORS.includes(String(color).toLowerCase()) ? C.CAR_COLORS : [color, ...C.CAR_COLORS];
    const busy = editing && activeRentals().some((r) => r.carId === car.id);
    const body = `
      ${added.length ? `<p class="added">Agregados: <strong>${added.map(esc).join(', ')}</strong></p>` : ''}
      <label class="field">Nombre del carro
        <input name="name" value="${editing ? esc(car.name) : ''}" maxlength="${C.CAR_NAME_MAX}" autocomplete="off" placeholder="Ej. Rayo McQueen, Ferrari rojo, Jeep rosado" required>
      </label>
      <fieldset class="swatches">
        <legend>Color</legend>
        ${palette
          .map((c) => `<label style="--sw:${esc(c)}"><input type="radio" name="color" value="${esc(c)}" ${c.toLowerCase() === String(color).toLowerCase() ? 'checked' : ''}><span aria-label="${esc(c)}"></span></label>`)
          .join('')}
      </fieldset>
      <p class="preview" data-role="preview" style="--car:${esc(color)}">${CAR_SVG}<strong></strong></p>
      ${busy ? '<p class="sub">Este carro está en pista: el nombre nuevo se verá en el alquiler actual.</p>' : ''}`;
    const actions = editing
      ? [
          { value: 'cancel', label: 'Cancelar' },
          { value: 'save', label: 'Guardar', kind: 'primary' },
        ]
      : [
          { value: 'another', label: 'Agregar y seguir con otro' },
          { value: 'cancel', label: added.length ? 'Listo' : 'Cancelar' },
          { value: 'add', label: 'Agregar carro', kind: 'primary' },
        ];
    openModal({
      title: editing ? `Editar ${esc(car.name)}` : 'Agregar carro',
      body,
      actions,
      onInput(form) {
        const pv = form.querySelector('[data-role=preview]');
        const picked = form.querySelector('[name=color]:checked');
        pv.style.setProperty('--car', picked ? picked.value : color);
        pv.querySelector('strong').textContent = form.elements.name.value.trim() || 'Nombre del carro';
      },
      onAction(value, form) {
        const name = form.elements.name.value;
        const picked = form.querySelector('[name=color]:checked');
        const chosen = picked ? picked.value : color;
        if (editing) {
          return attempt(() => {
            const before = car.name;
            C.renameCar(state, car.id, name);
            car.color = chosen;
            commit();
            toast(before === car.name ? 'Carro actualizado' : `"${before}" ahora se llama "${car.name}"`);
          });
        }
        let created;
        const ok = attempt(() => {
          created = C.addCar(state, { name, color: chosen });
          commit();
        });
        if (!ok) {
          form.elements.name.focus();
          return false;
        }
        if (value === 'another') setTimeout(() => openCarModal(null, { added: [...added, created.name] }), 0);
        else toast(`${created.name} agregado`);
        return true;
      },
    });
    // En móvil también enfocar el nombre al agregar, para escribir de una vez.
    if (!editing) $('#modalForm [name=name]').focus();
  }

  // ----- Agregar tiempo
  function openExtendModal(r) {
    const s = state.settings;
    const body = `
      <p>${esc(r.carName)} · ${C.kidsLabel(r.kids)}${r.customer ? ' · ' + esc(r.customer) : ''}</p>
      <fieldset class="seg chips">
        <legend>Tiempo adicional</legend>
        ${[1, 2, 3]
          .map((b, i) => `<label><input type="radio" name="minutes" value="${b * s.blockMinutes}" ${i === 0 ? 'checked' : ''}><span>+${b * s.blockMinutes} min</span></label>`)
          .join('')}
      </fieldset>
      <fieldset class="seg">
        <legend>Pago</legend>
        <label><input type="radio" name="pay" value="now" checked><span>Pagó ahora</span></label>
        <label><input type="radio" name="pay" value="later"><span>Paga al final</span></label>
      </fieldset>
      <label class="field" data-show="paynow">Medio de pago<select name="method">${methodOptions()}</select></label>
      <div class="total-box"><span>Valor adicional</span><strong data-role="total"></strong></div>`;
    const read = (form) => ({
      minutes: Number(form.querySelector('[name=minutes]:checked').value),
      payNow: form.querySelector('[name=pay]:checked').value === 'now',
      method: form.elements.method.value,
    });
    openModal({
      title: 'Agregar tiempo',
      body,
      actions: [
        { value: 'cancel', label: 'Cancelar' },
        { value: 'ok', label: 'Agregar', kind: 'primary' },
      ],
      onInput(form) {
        const v = read(form);
        form.querySelector('[data-show=paynow]').hidden = !v.payNow;
        form.querySelector('[data-role=total]').textContent = money(C.priceFor(r.kids, v.minutes, s));
      },
      onAction(value, form) {
        const v = read(form);
        return attempt(() => {
          C.extendRental(r, { ...v, settings: s, now: Date.now() });
          ui.silenced.delete(r.id);
          ui.notified.delete(r.id);
          commit();
          toast(`+${v.minutes} min para ${r.carName}`);
        });
      },
    });
  }

  // ----- Cobrar
  function openChargeModal(r, { afterFinish = false } = {}) {
    const t = C.rentalTotals(r);
    if (t.balance <= 0) return;
    const body = `
      <p>${esc(r.carName)} · ${C.kidsLabel(r.kids)} · ${r.minutes} min${r.customer ? ' · ' + esc(r.customer) : ''}</p>
      <div class="total-box"><span>Saldo pendiente</span><strong>${money(t.balance)}</strong>${t.paid ? `<small>Ya pagó ${money(t.paid)} de ${money(t.charged)}</small>` : ''}</div>
      <label class="field">Valor recibido<input name="amount" inputmode="numeric" value="${t.balance}" required></label>
      <label class="field">Medio de pago<select name="method">${methodOptions()}</select></label>`;
    openModal({
      title: afterFinish ? 'Falta cobrar este alquiler' : 'Registrar pago',
      body,
      actions: [
        { value: 'cancel', label: afterFinish ? 'Dejar pendiente' : 'Cancelar' },
        { value: 'pay', label: 'Registrar pago', kind: 'primary' },
      ],
      onAction(value, form) {
        const amount = C.parseMoney(form.elements.amount.value);
        return attempt(() => {
          C.addPayment(r, { amount, method: form.elements.method.value, now: Date.now() });
          commit();
          toast(`Pago de ${money(amount)} registrado`);
        });
      },
      onClose() {
        if (afterFinish) toast(`${r.carName}: queda pendiente ${money(C.rentalTotals(r).balance)}`, 'warn');
      },
    });
  }

  // ----- Finalizar
  function finishFlow(r) {
    const s = state.settings;
    const now = Date.now();
    const ot = C.overtimeInfo(r, now, s);
    const t = C.rentalTotals(r);
    const done = (overtimeMinutes) =>
      attempt(() => {
        C.finishRental(r, { now: Date.now(), settings: s, overtimeMinutes });
        ui.silenced.delete(r.id);
        ui.notified.delete(r.id);
        commit();
        if (C.rentalTotals(r).balance > 0) setTimeout(() => openChargeModal(r, { afterFinish: true }), 0);
        else toast(`${r.carName} quedó disponible`);
      });

    if (ot.exceedsGrace) {
      openModal({
        title: `${esc(r.carName)} se pasó del tiempo`,
        body: `<p>Lleva <strong>${ot.overMinutes} min</strong> de tiempo extra (tolerancia ${s.graceMinutes} min).</p>
          <div class="total-box"><span>Cobro sugerido</span><strong>${money(ot.amount)}</strong><small>${ot.blocks} bloque(s) de ${s.blockMinutes} min · ${C.kidsLabel(r.kids)}</small></div>`,
        actions: [
          { value: 'cancel', label: 'Volver' },
          { value: 'nocharge', label: 'Finalizar sin cobrar extra' },
          { value: 'charge', label: `Cobrar ${money(ot.amount)} y finalizar`, kind: 'primary' },
        ],
        onAction(value) {
          return done(value === 'charge' ? ot.overMinutes : 0);
        },
      });
      return;
    }
    const remaining = C.endAt(r) - now;
    openModal({
      title: `Finalizar ${esc(r.carName)}`,
      body: `<p>${remaining > 0 ? `Aún quedan <strong>${C.formatClock(remaining)}</strong> de tiempo.` : 'El tiempo terminó.'}</p>
        <div class="total-box"><span>Total del alquiler</span><strong>${money(t.charged)}</strong><small>${t.balance > 0 ? `Pendiente por cobrar ${money(t.balance)}` : 'Pagado'}</small></div>`,
      actions: [
        { value: 'cancel', label: 'Volver' },
        { value: 'finish', label: 'Finalizar', kind: 'primary' },
      ],
      onAction() {
        return done(0);
      },
    });
  }

  // ----- Detalle
  function openDetailModal(r) {
    const t = C.rentalTotals(r);
    const moves = [
      ...r.charges.map((c) => ({ at: c.at, text: `${C.CHARGE_LABELS[c.type]} · ${c.minutes} min`, amount: c.amount })),
      ...r.payments.map((p) => ({ at: p.at, text: `Pago · ${esc(p.method)}`, amount: -p.amount })),
      ...(r.writeOff ? [{ at: r.writeOff.at, text: `No pagó${r.writeOff.reason ? ' · ' + esc(r.writeOff.reason) : ''}`, amount: -r.writeOff.amount }] : []),
    ].sort((a, b) => a.at - b.at);
    const canWriteOff = r.status === 'finished' && t.balance > 0;
    const actions = [{ value: 'cancel', label: 'Cerrar' }];
    if (r.status !== 'cancelled') actions.push({ value: 'void', label: 'Anular alquiler', kind: 'danger' });
    if (canWriteOff) actions.push({ value: 'writeoff', label: 'Marcar "no pagó"', kind: 'warn' });
    if (r.status !== 'cancelled' && t.balance > 0) actions.push({ value: 'pay', label: 'Cobrar', kind: 'primary' });

    openModal({
      title: `${esc(r.carName)} · ALQ-${C.shortRef(r.id)}`,
      body: `
        <dl class="detail">
          <div><dt>Estado</dt><dd>${C.STATUS_LABELS[r.status]}</dd></div>
          <div><dt>Pago</dt><dd>${r.status === 'cancelled' ? '—' : C.PAY_STATUS_LABELS[t.payStatus]}</dd></div>
          <div><dt>Niños</dt><dd>${r.kids}</dd></div>
          <div><dt>Tiempo</dt><dd>${r.minutes} min</dd></div>
          <div><dt>Inicio</dt><dd>${C.dayKey(r.startAt)} ${C.formatTime(r.startAt)}</dd></div>
          <div><dt>Fin</dt><dd>${r.finishedAt ? C.formatTime(r.finishedAt) : '—'}</dd></div>
          <div><dt>Cliente</dt><dd>${esc(r.customer) || '—'}</dd></div>
          <div><dt>Saldo</dt><dd>${money(Math.max(0, t.balance))}</dd></div>
        </dl>
        <h3>Movimientos</h3>
        <table class="table compact"><tbody>
          ${moves.map((m) => `<tr><td>${C.formatTime(m.at)}</td><td>${m.text}</td><td class="num">${money(m.amount)}</td></tr>`).join('')}
        </tbody></table>
        ${canWriteOff ? '<label class="field">Motivo si no pagó (opcional)<input name="reason" maxlength="80"></label>' : ''}`,
      actions,
      onAction(value, form) {
        if (value === 'pay') {
          setTimeout(() => openChargeModal(r), 0);
          return true;
        }
        if (value === 'writeoff') {
          if (!confirm(`¿Registrar que no pagó ${money(t.balance)}? Se contabiliza como pérdida.`)) return false;
          return attempt(() => {
            C.writeOffRental(r, { now: Date.now(), reason: form.elements.reason ? form.elements.reason.value : '' });
            commit();
            toast('Registrado como no pagado', 'warn');
          });
        }
        if (value === 'void') {
          if (!confirm('¿Anular este alquiler? Dejará de contar en ventas y pagos (úsalo para errores o devoluciones).')) return false;
          return attempt(() => {
            C.cancelRental(r, Date.now());
            commit();
            toast('Alquiler anulado', 'warn');
          });
        }
        return true;
      },
    });
  }

  // ----- Gasto
  function openExpenseModal() {
    const day = ui.from === ui.to ? ui.from : today();
    openModal({
      title: 'Registrar gasto',
      body: `
        <label class="field">Concepto<input name="concept" maxlength="80" required placeholder="Ej. carga de baterías, almuerzo, repuesto"></label>
        <label class="field">Categoría<select name="category">${C.EXPENSE_CATEGORIES.map((c) => `<option value="${c.id}">${esc(c.name)}</option>`).join('')}</select></label>
        <label class="field">Valor<input name="amount" inputmode="numeric" required placeholder="0"></label>
        <label class="field">Pagado con<select name="method">${methodOptions()}</select></label>
        <label class="field">Fecha<input type="date" name="day" value="${day}" max="${today()}"></label>`,
      actions: [
        { value: 'cancel', label: 'Cancelar' },
        { value: 'save', label: 'Guardar gasto', kind: 'primary' },
      ],
      onAction(value, form) {
        const f = form.elements;
        return attempt(() => {
          const e = C.createExpense({
            concept: f.concept.value,
            category: f.category.value,
            amount: C.parseMoney(f.amount.value),
            method: f.method.value,
            day: f.day.value || today(),
            now: Date.now(),
          });
          state.expenses.push(e);
          commit();
          toast(`Gasto de ${money(e.amount)} registrado`);
        });
      },
    });
  }

  // ---------------------------------------------------------------- acciones
  function setRange(kind) {
    const t = today();
    if (kind === 'today') ui.from = ui.to = t;
    else if (kind === 'yesterday') ui.from = ui.to = shiftDay(t, -1);
    else if (kind === 'week') {
      ui.from = shiftDay(t, -6);
      ui.to = t;
    } else if (kind === 'month') {
      ui.from = `${t.slice(0, 8)}01`;
      ui.to = t;
    }
  }

  function readCashForm() {
    const box = $('[data-cash]');
    const opening = C.parseMoney(box.querySelector('[name=openingCash]').value);
    const countedRaw = box.querySelector('[name=countedCash]').value.trim();
    return { opening, counted: countedRaw === '' ? null : C.parseMoney(countedRaw), notes: box.querySelector('[name=notes]').value };
  }

  const actions = {
    go: (d) => {
      ui.view = d.view;
      render();
    },
    rent: (d) => {
      const car = state.cars.find((c) => c.id === d.car);
      if (car) openRentModal(car);
    },
    extend: (d) => {
      const r = findRental(d.id);
      if (r) openExtendModal(r);
    },
    charge: (d) => {
      const r = findRental(d.id);
      if (r) openChargeModal(r);
    },
    finish: (d) => {
      const r = findRental(d.id);
      if (r) finishFlow(r);
    },
    silence: (d) => {
      ui.silenced.add(d.id);
      tick();
    },
    detail: (d) => {
      const r = findRental(d.id);
      if (r) openDetailModal(r);
    },
    'reg-shift': (d) => {
      ui.regDay = shiftDay(ui.regDay, Number(d.delta));
      render();
    },
    'export-rentals': () => {
      download(`alquileres-${ui.regDay}.csv`, C.rentalsCSV(state, ui.regDay, ui.regDay), 'text/csv;charset=utf-8');
    },
    range: (d) => {
      setRange(d.range);
      render();
    },
    'add-expense': () => openExpenseModal(),
    'delete-expense': (d) => {
      const e = state.expenses.find((x) => x.id === d.id);
      if (!e || !confirm(`¿Eliminar el gasto "${e.concept}" por ${money(e.amount)}?`)) return;
      state.expenses = state.expenses.filter((x) => x.id !== d.id);
      commit();
    },
    'export-journal': () => {
      const name = ui.from === ui.to ? ui.from : `${ui.from}_a_${ui.to}`;
      download(`libro-diario-${name}.csv`, C.journalCSV(C.journal(state, ui.from, ui.to)), 'text/csv;charset=utf-8');
    },
    print: () => window.print(),
    'save-closure': () => {
      const v = readCashForm();
      state.closures[ui.from] = {
        openingCash: v.opening,
        countedCash: v.counted,
        notes: v.notes.trim(),
        closedAt: v.counted === null ? null : Date.now(),
      };
      commit();
      toast(v.counted === null ? 'Base de caja guardada' : 'Cierre de caja guardado');
    },
    'car-new': () => openCarModal(null),
    'car-edit': (d) => {
      const car = state.cars.find((c) => c.id === d.id);
      if (car) openCarModal(car);
    },
    'car-toggle': (d) => {
      const car = state.cars.find((c) => c.id === d.id);
      if (!car) return;
      car.active = !car.active;
      commit();
    },
    'car-delete': (d) => {
      const car = state.cars.find((c) => c.id === d.id);
      if (!car) return;
      const used = state.rentals.some((r) => r.carId === car.id);
      if (used) {
        if (!confirm(`${car.name} tiene alquileres registrados. Se desactivará para conservar el historial. ¿Continuar?`)) return;
        car.active = false;
      } else {
        if (!confirm(`¿Eliminar ${car.name}?`)) return;
        state.cars = state.cars.filter((c) => c.id !== car.id);
      }
      commit();
    },
    'save-settings': () => {
      const f = $('#settingsForm').elements;
      attempt(() => {
        const blockMinutes = Number(f.blockMinutes.value);
        const minMinutes = Number(f.minMinutes.value);
        const p1 = C.parseMoney(f.price1.value);
        const p2 = C.parseMoney(f.price2.value);
        if (!(blockMinutes >= 1)) throw new Error('Los minutos por bloque deben ser 1 o más');
        if (!(minMinutes >= blockMinutes) || minMinutes % blockMinutes !== 0) {
          throw new Error('El tiempo mínimo debe ser múltiplo de los minutos por bloque');
        }
        if (!(p1 > 0) || !(p2 > 0)) throw new Error('Los precios deben ser mayores que cero');
        const durationOptions = f.durationOptions.value
          .split(/[,\s]+/)
          .map(Number)
          .filter((m) => m >= minMinutes && m % blockMinutes === 0);
        const uniqueOptions = [...new Set(durationOptions)].sort((a, b) => a - b);
        state.settings = Object.assign({}, state.settings, {
          businessName: f.businessName.value.trim() || 'Carritos Kids',
          prices: { 1: p1, 2: p2 },
          blockMinutes,
          minMinutes,
          durationOptions: uniqueOptions.length ? uniqueOptions : [minMinutes],
          graceMinutes: Math.max(0, Number(f.graceMinutes.value) || 0),
          warnSeconds: Math.max(0, Number(f.warnSeconds.value) || 0),
          sound: f.sound.checked,
        });
        commit();
        toast('Ajustes guardados');
      });
    },
    'test-sound': () => {
      unlockAudio();
      setTimeout(beep, 50);
      if (navigator.vibrate) navigator.vibrate(200);
      askNotificationPermission();
    },
    backup: () => {
      download(`respaldo-carritos-${today()}.json`, S.exportBackup(state), 'application/json');
    },
    wipe: () => {
      if (!confirm('¿Borrar TODOS los datos (alquileres, gastos, cierres y carros)? Esta acción no se puede deshacer.')) return;
      if (prompt('Para confirmar escribe BORRAR') !== 'BORRAR') return;
      state = C.defaultState();
      commit();
      toast('Datos borrados', 'warn');
    },
  };

  const changes = {
    regDay: (el) => {
      if (!el.value) return;
      ui.regDay = el.value;
      render();
    },
    from: (el) => {
      if (!el.value) return;
      ui.from = el.value;
      if (ui.to < ui.from) ui.to = ui.from;
      render();
    },
    to: (el) => {
      if (!el.value) return;
      ui.to = el.value;
      if (ui.from > ui.to) ui.from = ui.to;
      render();
    },
    'car-name': (el) => {
      const car = state.cars.find((c) => c.id === el.dataset.id);
      if (!car) return;
      const before = car.name;
      const ok = attempt(() => C.renameCar(state, car.id, el.value));
      if (!ok) {
        el.value = before;
        return;
      }
      commit();
      if (before !== car.name) toast(`"${before}" ahora se llama "${car.name}"`);
    },
    'car-color': (el) => {
      const car = state.cars.find((c) => c.id === el.dataset.id);
      if (!car) return;
      car.color = el.value;
      commit();
    },
    restore: (el) => {
      const file = el.files && el.files[0];
      if (!file) return;
      file.text().then((text) => {
        attempt(() => {
          const next = S.parseBackup(text);
          if (!confirm(`¿Reemplazar los datos actuales con el respaldo (${next.rentals.length} alquileres)?`)) return;
          state = next;
          commit();
          toast('Respaldo restaurado');
        });
        el.value = '';
      });
    },
  };

  const inputs = {
    cash: () => {
      const v = readCashForm();
      const cs = C.cashSummary(state, ui.from);
      const expected = v.opening + cs.cashIn - cs.cashOut;
      $('[data-role=expected]').textContent = money(expected);
      $('[data-role=diff]').textContent = v.counted === null ? '—' : diffLabel(v.counted - expected);
    },
  };

  // ---------------------------------------------------------------- eventos
  document.addEventListener('click', (e) => {
    const tab = e.target.closest('nav [data-view]');
    if (tab) {
      ui.view = tab.dataset.view;
      render();
      $('#main').focus({ preventScroll: true });
      return;
    }
    const btn = e.target.closest('[data-action]');
    if (btn && actions[btn.dataset.action]) actions[btn.dataset.action](btn.dataset, btn, e);
  });
  document.addEventListener('change', (e) => {
    const el = e.target.closest('[data-change]');
    if (el && changes[el.dataset.change]) changes[el.dataset.change](el);
  });
  document.addEventListener('input', (e) => {
    const el = e.target.closest('[data-input]');
    if (el && inputs[el.dataset.input]) inputs[el.dataset.input](el);
  });
  const submits = {
    'car-add': (form) => {
      const name = form.elements.name;
      const ok = attempt(() => {
        const car = C.addCar(state, { name: name.value, color: form.elements.color.value });
        commit();
        toast(`${car.name} agregado`);
      });
      const input = $('form[data-submit=car-add] [name=name]');
      if (input) input.focus();
      if (!ok) name.focus();
    },
  };
  document.addEventListener('submit', (e) => {
    const form = e.target.closest('form[data-submit]');
    if (!form) return;
    e.preventDefault();
    if (submits[form.dataset.submit]) submits[form.dataset.submit](form);
  });
  document.addEventListener('pointerdown', unlockAudio, { passive: true });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      wakeLock = null;
      tick();
    }
  });
  // Si los datos cambian en otra pestaña, recargar.
  window.addEventListener('storage', (e) => {
    if (e.key === S.KEY) {
      state = S.load();
      if (!$('#modal').open) render();
    }
  });

  // Al cambiar de día, las fechas "hoy" se actualizan solas.
  let lastDay = today();
  setInterval(() => {
    const d = today();
    if (d !== lastDay) {
      if (ui.regDay === lastDay) ui.regDay = d;
      if (ui.from === lastDay && ui.to === lastDay) ui.from = ui.to = d;
      lastDay = d;
      if (!$('#modal').open) render();
    }
    tick();
  }, 1000);

  if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }

  render();
})();
