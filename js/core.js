/*
 * Lógica de negocio del sistema de alquiler de carros para niños.
 * Sin dependencias del navegador: se usa en la app (window.Core) y en las
 * pruebas de Node (require).
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.Core = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const MINUTE = 60 * 1000;

  const DEFAULT_SETTINGS = {
    businessName: 'Carritos Kids',
    blockMinutes: 10, // cada bloque de tiempo que se cobra
    minMinutes: 10, // tiempo mínimo de alquiler
    prices: { 1: 10000, 2: 15000 }, // precio por bloque según número de niños
    durationOptions: [10, 20, 30, 60],
    graceMinutes: 2, // minutos de tolerancia antes de cobrar tiempo extra
    warnSeconds: 60, // aviso amarillo cuando falta este tiempo
    sound: true,
  };

  const PAYMENT_METHODS = ['Efectivo', 'Nequi', 'Daviplata', 'Transferencia', 'Tarjeta'];

  // Cuentas de referencia (PUC colombiano, nivel cuenta).
  const ACCOUNTS = {
    CAJA: { code: '1105', name: 'Caja' },
    BANCOS: { code: '1110', name: 'Bancos y billeteras digitales' },
    CLIENTES: { code: '1305', name: 'Clientes (cuentas por cobrar)' },
    INGRESOS: { code: '4155', name: 'Ingresos por alquiler de carros' },
    SOBRANTES: { code: '4295', name: 'Sobrantes de caja' },
    INCOBRABLES: { code: '5199', name: 'Cartera no cobrada (castigo)' },
    FALTANTES: { code: '5395', name: 'Faltantes de caja' },
  };

  const EXPENSE_CATEGORIES = [
    { id: 'energia', name: 'Carga de baterías / energía', code: '5135', account: 'Servicios' },
    { id: 'mantenimiento', name: 'Mantenimiento y repuestos', code: '5145', account: 'Mantenimiento y reparaciones' },
    { id: 'personal', name: 'Pago a trabajadores', code: '5105', account: 'Gastos de personal' },
    { id: 'arriendo', name: 'Arriendo / permiso del espacio', code: '5120', account: 'Arrendamientos' },
    { id: 'transporte', name: 'Transporte', code: '5155', account: 'Gastos de viaje y transporte' },
    { id: 'otros', name: 'Otros gastos', code: '5195', account: 'Diversos' },
  ];

  const CHARGE_LABELS = { base: 'Alquiler', extension: 'Tiempo adicional', overtime: 'Tiempo extra' };
  const PAY_STATUS_LABELS = { pagado: 'Pagado', parcial: 'Abono', pendiente: 'Pendiente', castigado: 'No pagó' };
  const STATUS_LABELS = { active: 'En pista', finished: 'Finalizado', cancelled: 'Cancelado' };

  // ---------- utilidades ----------
  let counter = 0;
  function uid() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
    counter += 1;
    return `${Date.now().toString(36)}-${counter.toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
  }

  function clone(v) {
    return JSON.parse(JSON.stringify(v));
  }

  function sum(arr, f) {
    return arr.reduce((acc, x) => acc + (Number(f ? f(x) : x) || 0), 0);
  }

  function pad(n) {
    return String(n).padStart(2, '0');
  }

  /** Fecha local YYYY-MM-DD de un timestamp. */
  function dayKey(ts) {
    const d = new Date(ts);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  }

  function inRange(ts, from, to) {
    const k = dayKey(ts);
    return k >= from && k <= to;
  }

  /** Lista de días entre from y to (inclusive). */
  function daysBetween(from, to) {
    const out = [];
    const [y, m, d] = from.split('-').map(Number);
    const cur = new Date(y, m - 1, d, 12);
    for (let i = 0; i < 400; i++) {
      const k = dayKey(cur.getTime());
      if (k > to) break;
      out.push(k);
      cur.setDate(cur.getDate() + 1);
    }
    return out;
  }

  /** Timestamp del mediodía de un día (para registrar movimientos de días pasados). */
  function noonOf(day) {
    const [y, m, d] = day.split('-').map(Number);
    return new Date(y, m - 1, d, 12).getTime();
  }

  function endOfDay(day) {
    const [y, m, d] = day.split('-').map(Number);
    return new Date(y, m - 1, d, 23, 59, 59).getTime();
  }

  const moneyFmt =
    typeof Intl !== 'undefined'
      ? new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 })
      : null;

  function formatMoney(v) {
    const n = Math.round(Number(v) || 0);
    if (moneyFmt) return moneyFmt.format(n).replace(/ /g, ' ');
    return '$ ' + String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  }

  /** Convierte "15.000", "$15,000" o 15000 en número entero. */
  function parseMoney(v) {
    if (typeof v === 'number') return Math.round(v);
    const digits = String(v || '').replace(/[^\d-]/g, '');
    const n = parseInt(digits, 10);
    return Number.isFinite(n) ? n : 0;
  }

  /** mm:ss (o h:mm:ss). Negativo = tiempo extra, se muestra con "+". */
  function formatClock(ms) {
    const over = ms < 0;
    let s = Math.abs(over ? Math.floor(ms / 1000) : Math.ceil(ms / 1000));
    const h = Math.floor(s / 3600);
    s -= h * 3600;
    const m = Math.floor(s / 60);
    s -= m * 60;
    const body = h ? `${h}:${pad(m)}:${pad(s)}` : `${pad(m)}:${pad(s)}`;
    return over ? `+${body}` : body;
  }

  function formatTime(ts) {
    const d = new Date(ts);
    return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function isCash(method) {
    return String(method || '').trim().toLowerCase() === 'efectivo';
  }

  function kidsLabel(n) {
    return n === 1 ? '1 niño' : `${n} niños`;
  }

  // ---------- estado ----------
  const CAR_COLORS = ['#e63946', '#1d7bd8', '#f4a300', '#2a9d8f', '#8e44ad', '#ff6fa8', '#2b2d42', '#43aa8b', '#f3722c', '#577590'];

  function defaultState() {
    return {
      version: 1,
      settings: clone(DEFAULT_SETTINGS),
      cars: [], // el dueño agrega sus carros con el nombre de cada uno
      rentals: [],
      expenses: [],
      closures: {},
    };
  }

  /** Completa un estado cargado con los valores por defecto que falten. */
  function normalizeState(raw) {
    const base = defaultState();
    if (!raw || typeof raw !== 'object') return base;
    const settings = Object.assign({}, base.settings, raw.settings || {});
    settings.prices = Object.assign({}, base.settings.prices, (raw.settings && raw.settings.prices) || {});
    if (!Array.isArray(settings.durationOptions) || !settings.durationOptions.length) {
      settings.durationOptions = base.settings.durationOptions.slice();
    }
    return {
      version: 1,
      settings,
      cars: Array.isArray(raw.cars) ? raw.cars.map((c) => Object.assign({ active: true }, c)) : [],
      rentals: Array.isArray(raw.rentals)
        ? raw.rentals.map((r) => Object.assign({ charges: [], payments: [], writeOff: null }, r))
        : [],
      expenses: Array.isArray(raw.expenses) ? raw.expenses : [],
      closures: raw.closures && typeof raw.closures === 'object' ? raw.closures : {},
    };
  }

  // ---------- carros ----------
  const CAR_NAME_MAX = 30;

  function cleanCarName(name) {
    return String(name || '').replace(/\s+/g, ' ').trim();
  }

  function validateCarName(state, name, exceptId) {
    const n = cleanCarName(name);
    if (!n) throw new Error('Escribe el nombre del carro');
    if (n.length > CAR_NAME_MAX) throw new Error(`El nombre puede tener máximo ${CAR_NAME_MAX} letras`);
    const key = n.toLocaleLowerCase('es');
    const dup = state.cars.find((c) => c.id !== exceptId && c.name.toLocaleLowerCase('es') === key);
    if (dup) throw new Error(`Ya existe un carro llamado "${dup.name}"`);
    return n;
  }

  /** Color sugerido para el siguiente carro (el primero de la paleta que no esté en uso). */
  function nextCarColor(state) {
    const used = new Set(state.cars.map((c) => String(c.color).toLowerCase()));
    return CAR_COLORS.find((c) => !used.has(c)) || CAR_COLORS[state.cars.length % CAR_COLORS.length];
  }

  function addCar(state, { name, color } = {}) {
    const car = { id: uid(), name: validateCarName(state, name), color: color || nextCarColor(state), active: true };
    state.cars.push(car);
    return car;
  }

  /** Cambia el nombre de un carro. Los alquileres en pista toman el nombre nuevo; el historial conserva el anterior. */
  function renameCar(state, carId, name) {
    const car = state.cars.find((c) => c.id === carId);
    if (!car) throw new Error('Carro no encontrado');
    car.name = validateCarName(state, name, carId);
    for (const r of state.rentals) if (r.carId === carId && r.status === 'active') r.carName = car.name;
    return car;
  }

  // ---------- precios y tiempos ----------
  function blocksFor(minutes, settings) {
    const block = Number(settings.blockMinutes) || 10;
    return Math.max(1, Math.ceil(Number(minutes) / block));
  }

  function rateFor(kids, settings) {
    const rate = Number(settings.prices[kids]);
    if (!Number.isFinite(rate) || rate < 0) throw new Error(`No hay precio configurado para ${kidsLabel(kids)}`);
    return rate;
  }

  function priceFor(kids, minutes, settings) {
    return blocksFor(minutes, settings) * rateFor(kids, settings);
  }

  function validateMinutes(minutes, settings) {
    const m = Number(minutes);
    if (!Number.isFinite(m) || m < settings.minMinutes) {
      throw new Error(`El tiempo mínimo de alquiler es ${settings.minMinutes} minutos`);
    }
    if (m % settings.blockMinutes !== 0) {
      throw new Error(`El tiempo debe ser múltiplo de ${settings.blockMinutes} minutos`);
    }
    return m;
  }

  function validateKids(kids) {
    const k = Number(kids);
    if (k !== 1 && k !== 2) throw new Error('Cada carro admite 1 o 2 niños');
    return k;
  }

  function endAt(rental) {
    return rental.startAt + rental.minutes * MINUTE;
  }

  /** Estado del cronómetro de un alquiler activo. */
  function timeStatus(rental, now, settings) {
    const total = rental.minutes * MINUTE;
    const remainingMs = endAt(rental) - now;
    const warnMs = ((settings && settings.warnSeconds) || 60) * 1000;
    let state = 'ok';
    if (remainingMs <= 0) state = 'expired';
    else if (remainingMs <= warnMs) state = 'warn';
    const progress = Math.min(1, Math.max(0, (now - rental.startAt) / total));
    return { remainingMs, state, progress, endAt: endAt(rental) };
  }

  /** Cuánto tiempo extra lleva y cuánto costaría cobrarlo. */
  function overtimeInfo(rental, now, settings) {
    const overMs = now - endAt(rental);
    const overMinutes = overMs > 0 ? Math.ceil(overMs / MINUTE) : 0;
    const exceedsGrace = overMs > (Number(settings.graceMinutes) || 0) * MINUTE;
    const blocks = overMinutes > 0 ? Math.ceil(overMinutes / settings.blockMinutes) : 0;
    return {
      overMinutes,
      exceedsGrace,
      blocks,
      minutes: blocks * settings.blockMinutes,
      amount: blocks * rateFor(rental.kids, settings),
    };
  }

  // ---------- operaciones sobre alquileres ----------
  function rentalTotals(rental) {
    const charged = sum(rental.charges, (c) => c.amount);
    const paid = sum(rental.payments, (p) => p.amount);
    const writtenOff = rental.writeOff ? Number(rental.writeOff.amount) || 0 : 0;
    const balance = charged - paid - writtenOff;
    let payStatus;
    if (balance <= 0) payStatus = writtenOff > 0 ? 'castigado' : 'pagado';
    else payStatus = paid > 0 ? 'parcial' : 'pendiente';
    return { charged, paid, writtenOff, balance, payStatus };
  }

  function createRental(opts) {
    const { car, kids, minutes, customer = '', payNow = false, method = 'Efectivo', now = Date.now(), settings } = opts;
    if (!car) throw new Error('Selecciona un carro');
    const k = validateKids(kids);
    const m = validateMinutes(minutes, settings);
    const amount = priceFor(k, m, settings);
    const rental = {
      id: uid(),
      carId: car.id,
      carName: car.name,
      kids: k,
      minutes: m,
      customer: String(customer || '').trim(),
      startAt: now,
      finishedAt: null,
      cancelledAt: null,
      status: 'active',
      charges: [{ id: uid(), type: 'base', minutes: m, amount, at: now }],
      payments: [],
      writeOff: null,
    };
    if (payNow) addPayment(rental, { amount, method, now });
    return rental;
  }

  function extendRental(rental, opts) {
    const { minutes, now = Date.now(), settings, payNow = false, method = 'Efectivo' } = opts;
    if (rental.status !== 'active') throw new Error('Solo se puede agregar tiempo a un carro en pista');
    const m = Number(minutes);
    if (!Number.isFinite(m) || m <= 0 || m % settings.blockMinutes !== 0) {
      throw new Error(`El tiempo adicional debe ser múltiplo de ${settings.blockMinutes} minutos`);
    }
    // La extensión se suma al final original: si ya iba en tiempo extra, ese tiempo
    // queda dentro del bloque que se está cobrando (no se regala).
    const amount = priceFor(rental.kids, m, settings);
    rental.minutes += m;
    rental.charges.push({ id: uid(), type: 'extension', minutes: m, amount, at: now });
    if (payNow) addPayment(rental, { amount, method, now });
    return rental;
  }

  function addPayment(rental, opts) {
    const { amount, method = 'Efectivo', now = Date.now() } = opts;
    if (rental.status === 'cancelled') throw new Error('El alquiler está cancelado');
    const a = Math.round(Number(amount));
    if (!Number.isFinite(a) || a <= 0) throw new Error('El valor del pago debe ser mayor que cero');
    const { balance } = rentalTotals(rental);
    if (a > balance) throw new Error(`El pago supera el saldo pendiente (${formatMoney(balance)})`);
    rental.payments.push({ id: uid(), amount: a, method, at: now });
    return rental;
  }

  function finishRental(rental, opts) {
    const { now = Date.now(), settings, overtimeMinutes = 0 } = opts;
    if (rental.status !== 'active') throw new Error('Este alquiler ya no está en pista');
    if (overtimeMinutes > 0) {
      const blocks = Math.ceil(overtimeMinutes / settings.blockMinutes);
      const minutes = blocks * settings.blockMinutes;
      rental.charges.push({
        id: uid(),
        type: 'overtime',
        minutes,
        amount: blocks * rateFor(rental.kids, settings),
        at: now,
      });
    }
    rental.status = 'finished';
    rental.finishedAt = now;
    return rental;
  }

  function cancelRental(rental, now = Date.now()) {
    if (rental.status === 'cancelled') return rental;
    rental.status = 'cancelled';
    rental.cancelledAt = now;
    if (!rental.finishedAt) rental.finishedAt = now;
    return rental;
  }

  /** Registra que el cliente no pagó: el saldo pasa a pérdida. */
  function writeOffRental(rental, opts = {}) {
    const { now = Date.now(), reason = '' } = opts;
    if (rental.status === 'cancelled') throw new Error('El alquiler está cancelado');
    if (rental.status === 'active') throw new Error('Primero finaliza el alquiler');
    const { balance } = rentalTotals(rental);
    if (balance <= 0) throw new Error('Este alquiler no tiene saldo pendiente');
    rental.writeOff = { amount: balance, at: now, reason: String(reason || '').trim() };
    return rental;
  }

  function createExpense(opts) {
    const { concept, category = 'otros', amount, method = 'Efectivo', day, now = Date.now() } = opts;
    const a = Math.round(Number(amount));
    if (!String(concept || '').trim()) throw new Error('Escribe el concepto del gasto');
    if (!Number.isFinite(a) || a <= 0) throw new Error('El valor del gasto debe ser mayor que cero');
    const at = !day || day === dayKey(now) ? now : noonOf(day);
    return { id: uid(), concept: String(concept).trim(), category, amount: a, method, at };
  }

  function expenseCategory(id) {
    return EXPENSE_CATEGORIES.find((c) => c.id === id) || EXPENSE_CATEGORIES[EXPENSE_CATEGORIES.length - 1];
  }

  // ---------- reportes ----------
  function liveRentals(state) {
    return state.rentals.filter((r) => r.status !== 'cancelled');
  }

  /** Cuadre de caja (efectivo) de un día. */
  function cashSummary(state, day) {
    const closure = state.closures[day] || {};
    const opening = Number(closure.openingCash) || 0;
    let cashIn = 0;
    for (const r of liveRentals(state)) {
      for (const p of r.payments) if (isCash(p.method) && dayKey(p.at) === day) cashIn += p.amount;
    }
    const cashOut = sum(
      state.expenses.filter((e) => isCash(e.method) && dayKey(e.at) === day),
      (e) => e.amount
    );
    const expected = opening + cashIn - cashOut;
    const hasCount = closure.countedCash !== undefined && closure.countedCash !== null && closure.countedCash !== '';
    const counted = hasCount ? Number(closure.countedCash) : null;
    return {
      opening,
      cashIn,
      cashOut,
      expected,
      counted,
      diff: counted === null ? null : counted - expected,
      closedAt: closure.closedAt || null,
      notes: closure.notes || '',
    };
  }

  function bump(map, key, field, value) {
    if (!map[key]) map[key] = {};
    map[key][field] = (map[key][field] || 0) + value;
    return map[key];
  }

  /** Resumen contable de un rango de días (inclusive). */
  function report(state, from, to) {
    const rentals = liveRentals(state);
    const started = rentals.filter((r) => inRange(r.startAt, from, to));

    let produced = 0;
    let collected = 0;
    let collectedFromPrevious = 0;
    let writeOffs = 0;
    const byMethod = {};
    const byCar = {};
    const byKids = { 1: { rides: 0, produced: 0 }, 2: { rides: 0, produced: 0 } };
    const byDay = {};
    const byChargeType = { base: 0, extension: 0, overtime: 0 };

    for (const d of daysBetween(from, to)) byDay[d] = { produced: 0, collected: 0, expenses: 0, rides: 0 };

    for (const r of rentals) {
      const carKey = r.carId;
      for (const c of r.charges) {
        if (!inRange(c.at, from, to)) continue;
        produced += c.amount;
        byChargeType[c.type] = (byChargeType[c.type] || 0) + c.amount;
        const car = bump(byCar, carKey, 'produced', c.amount);
        car.name = r.carName;
        byKids[r.kids].produced += c.amount;
        bump(byDay, dayKey(c.at), 'produced', c.amount);
      }
      for (const p of r.payments) {
        if (!inRange(p.at, from, to)) continue;
        collected += p.amount;
        byMethod[p.method] = (byMethod[p.method] || 0) + p.amount;
        if (dayKey(r.startAt) < from) collectedFromPrevious += p.amount;
        bump(byDay, dayKey(p.at), 'collected', p.amount);
      }
      if (r.writeOff && inRange(r.writeOff.at, from, to)) writeOffs += r.writeOff.amount;
    }

    for (const r of started) {
      const car = bump(byCar, r.carId, 'rides', 1);
      bump(byCar, r.carId, 'minutes', r.minutes);
      car.name = r.carName;
      byKids[r.kids].rides += 1;
      bump(byDay, dayKey(r.startAt), 'rides', 1);
    }

    const expenses = state.expenses.filter((e) => inRange(e.at, from, to));
    const expensesTotal = sum(expenses, (e) => e.amount);
    const expensesByCategory = {};
    for (const e of expenses) {
      expensesByCategory[e.category] = (expensesByCategory[e.category] || 0) + e.amount;
      bump(byDay, dayKey(e.at), 'expenses', e.amount);
    }

    let cashAdjust = 0;
    for (const d of daysBetween(from, to)) {
      const cs = cashSummary(state, d);
      if (cs.diff) cashAdjust += cs.diff;
    }

    const pendingFromPeriod = sum(started, (r) => Math.max(0, rentalTotals(r).balance));
    const receivablesTotal = sum(rentals, (r) => Math.max(0, rentalTotals(r).balance));
    const cashCollected = sum(Object.keys(byMethod).filter(isCash), (m) => byMethod[m]);

    return {
      from,
      to,
      rides: started.length,
      kids: sum(started, (r) => r.kids),
      minutes: sum(started, (r) => r.minutes),
      produced,
      collected,
      cashCollected,
      digitalCollected: collected - cashCollected,
      collectedFromPrevious,
      pendingFromPeriod,
      receivablesTotal,
      writeOffs,
      expensesTotal,
      expensesByCategory,
      expenses,
      cashAdjust,
      netIncome: produced - expensesTotal - writeOffs + cashAdjust,
      cashFlow: collected - expensesTotal,
      byMethod,
      byCar,
      byKids,
      byDay,
      byChargeType,
      cash: from === to ? cashSummary(state, from) : null,
    };
  }

  // ---------- libro diario (partida doble) ----------
  function line(account, debit, credit) {
    return { code: account.code, name: account.name, debit: debit || 0, credit: credit || 0 };
  }

  function shortRef(id) {
    return String(id).replace(/-/g, '').slice(0, 6).toUpperCase();
  }

  function journal(state, from, to) {
    const entries = [];
    for (const r of liveRentals(state)) {
      const ref = `ALQ-${shortRef(r.id)}`;
      const who = r.customer ? ` · ${r.customer}` : '';
      for (const c of r.charges) {
        if (!inRange(c.at, from, to)) continue;
        entries.push({
          at: c.at,
          ref,
          description: `${CHARGE_LABELS[c.type] || 'Alquiler'} ${r.carName} · ${kidsLabel(r.kids)} · ${c.minutes} min${who}`,
          lines: [line(ACCOUNTS.CLIENTES, c.amount, 0), line(ACCOUNTS.INGRESOS, 0, c.amount)],
        });
      }
      for (const p of r.payments) {
        if (!inRange(p.at, from, to)) continue;
        const acc = isCash(p.method) ? ACCOUNTS.CAJA : ACCOUNTS.BANCOS;
        entries.push({
          at: p.at,
          ref,
          description: `Pago ${p.method} ${r.carName}${who}`,
          lines: [line(acc, p.amount, 0), line(ACCOUNTS.CLIENTES, 0, p.amount)],
        });
      }
      if (r.writeOff && inRange(r.writeOff.at, from, to)) {
        entries.push({
          at: r.writeOff.at,
          ref,
          description: `No pagó: ${r.carName}${who}${r.writeOff.reason ? ' · ' + r.writeOff.reason : ''}`,
          lines: [line(ACCOUNTS.INCOBRABLES, r.writeOff.amount, 0), line(ACCOUNTS.CLIENTES, 0, r.writeOff.amount)],
        });
      }
    }
    for (const e of state.expenses) {
      if (!inRange(e.at, from, to)) continue;
      const cat = expenseCategory(e.category);
      const acc = isCash(e.method) ? ACCOUNTS.CAJA : ACCOUNTS.BANCOS;
      entries.push({
        at: e.at,
        ref: `GTO-${shortRef(e.id)}`,
        description: `Gasto: ${e.concept} (${e.method})`,
        lines: [line({ code: cat.code, name: cat.account }, e.amount, 0), line(acc, 0, e.amount)],
      });
    }
    for (const d of daysBetween(from, to)) {
      const cs = cashSummary(state, d);
      if (!cs.diff) continue;
      const at = cs.closedAt || endOfDay(d);
      const amount = Math.abs(cs.diff);
      entries.push({
        at,
        ref: `CAJ-${d.replace(/-/g, '')}`,
        description: cs.diff < 0 ? `Faltante en cierre de caja ${d}` : `Sobrante en cierre de caja ${d}`,
        lines:
          cs.diff < 0
            ? [line(ACCOUNTS.FALTANTES, amount, 0), line(ACCOUNTS.CAJA, 0, amount)]
            : [line(ACCOUNTS.CAJA, amount, 0), line(ACCOUNTS.SOBRANTES, 0, amount)],
      });
    }
    entries.sort((a, b) => a.at - b.at);
    entries.forEach((e, i) => {
      e.number = i + 1;
      e.day = dayKey(e.at);
    });
    return entries;
  }

  /** Sumas y saldos por cuenta (balance de comprobación). */
  function ledger(entries) {
    const map = {};
    for (const e of entries) {
      for (const l of e.lines) {
        if (!map[l.code]) map[l.code] = { code: l.code, name: l.name, debit: 0, credit: 0 };
        map[l.code].debit += l.debit;
        map[l.code].credit += l.credit;
      }
    }
    const accounts = Object.values(map)
      .map((a) => Object.assign(a, { balance: a.debit - a.credit }))
      .sort((a, b) => a.code.localeCompare(b.code));
    return {
      accounts,
      totalDebit: sum(accounts, (a) => a.debit),
      totalCredit: sum(accounts, (a) => a.credit),
    };
  }

  // ---------- exportación ----------
  function toCSV(rows) {
    const cell = (v) => {
      const s = v === null || v === undefined ? '' : String(v);
      return /[";\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
    };
    // BOM + punto y coma para que Excel en español lo abra bien.
    return '﻿' + rows.map((r) => r.map(cell).join(';')).join('\r\n');
  }

  function rentalsCSV(state, from, to) {
    const rows = [
      ['Fecha', 'Hora inicio', 'Hora fin', 'Ref', 'Carro', 'Niños', 'Minutos', 'Cliente', 'Estado', 'Total', 'Pagado', 'Saldo', 'Estado de pago', 'Medios de pago'],
    ];
    const list = state.rentals.filter((r) => inRange(r.startAt, from, to)).sort((a, b) => a.startAt - b.startAt);
    for (const r of list) {
      const t = rentalTotals(r);
      rows.push([
        dayKey(r.startAt),
        formatTime(r.startAt),
        r.finishedAt ? formatTime(r.finishedAt) : '',
        `ALQ-${shortRef(r.id)}`,
        r.carName,
        r.kids,
        r.minutes,
        r.customer,
        STATUS_LABELS[r.status],
        r.status === 'cancelled' ? 0 : t.charged,
        r.status === 'cancelled' ? 0 : t.paid,
        r.status === 'cancelled' ? 0 : Math.max(0, t.balance),
        r.status === 'cancelled' ? '' : PAY_STATUS_LABELS[t.payStatus],
        [...new Set(r.payments.map((p) => p.method))].join(', '),
      ]);
    }
    return toCSV(rows);
  }

  function journalCSV(entries) {
    const rows = [['N°', 'Fecha', 'Hora', 'Ref', 'Descripción', 'Código', 'Cuenta', 'Débito', 'Crédito']];
    for (const e of entries) {
      for (const l of e.lines) {
        rows.push([e.number, e.day, formatTime(e.at), e.ref, e.description, l.code, l.name, l.debit || '', l.credit || '']);
      }
    }
    return toCSV(rows);
  }

  return {
    MINUTE,
    DEFAULT_SETTINGS,
    PAYMENT_METHODS,
    ACCOUNTS,
    EXPENSE_CATEGORIES,
    CHARGE_LABELS,
    PAY_STATUS_LABELS,
    STATUS_LABELS,
    uid,
    clone,
    sum,
    dayKey,
    inRange,
    daysBetween,
    noonOf,
    formatMoney,
    parseMoney,
    formatClock,
    formatTime,
    isCash,
    kidsLabel,
    shortRef,
    CAR_COLORS,
    CAR_NAME_MAX,
    defaultState,
    validateCarName,
    nextCarColor,
    addCar,
    renameCar,
    normalizeState,
    blocksFor,
    rateFor,
    priceFor,
    validateMinutes,
    endAt,
    timeStatus,
    overtimeInfo,
    rentalTotals,
    createRental,
    extendRental,
    addPayment,
    finishRental,
    cancelRental,
    writeOffRental,
    createExpense,
    expenseCategory,
    cashSummary,
    report,
    journal,
    ledger,
    toCSV,
    rentalsCSV,
    journalCSV,
  };
});
