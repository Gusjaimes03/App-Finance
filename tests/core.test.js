const test = require('node:test');
const assert = require('node:assert/strict');
const C = require('../js/core.js');

const MIN = 60 * 1000;
const T0 = new Date(2026, 9, 31, 10, 0, 0).getTime(); // 31 oct 2026, 10:00 hora local
const TODAY = C.dayKey(T0);

function fresh() {
  const s = C.defaultState();
  return s;
}

test('precios: 10 mil por 1 niño y 15 mil por 2 niños cada 10 minutos', () => {
  const s = C.DEFAULT_SETTINGS;
  assert.equal(C.priceFor(1, 10, s), 10000);
  assert.equal(C.priceFor(2, 10, s), 15000);
  assert.equal(C.priceFor(1, 30, s), 30000);
  assert.equal(C.priceFor(2, 20, s), 30000);
});

test('tiempo mínimo de 10 minutos y en múltiplos de 10', () => {
  const st = fresh();
  const car = st.cars[0];
  assert.throws(() => C.createRental({ car, kids: 1, minutes: 5, settings: st.settings }), /mínimo/);
  assert.throws(() => C.createRental({ car, kids: 1, minutes: 15, settings: st.settings }), /múltiplo/);
  assert.throws(() => C.createRental({ car, kids: 3, minutes: 10, settings: st.settings }), /1 o 2/);
});

test('crear alquiler pagado y pendiente', () => {
  const st = fresh();
  const paid = C.createRental({ car: st.cars[0], kids: 2, minutes: 10, payNow: true, method: 'Nequi', now: T0, settings: st.settings });
  assert.deepEqual(
    { ...C.rentalTotals(paid) },
    { charged: 15000, paid: 15000, writtenOff: 0, balance: 0, payStatus: 'pagado' }
  );
  const pending = C.createRental({ car: st.cars[1], kids: 1, minutes: 20, now: T0, settings: st.settings });
  assert.equal(C.rentalTotals(pending).balance, 20000);
  assert.equal(C.rentalTotals(pending).payStatus, 'pendiente');
  C.addPayment(pending, { amount: 5000, method: 'Efectivo', now: T0 });
  assert.equal(C.rentalTotals(pending).payStatus, 'parcial');
  assert.throws(() => C.addPayment(pending, { amount: 50000, now: T0 }), /supera/);
});

test('cronómetro: aviso, vencido y tiempo extra', () => {
  const st = fresh();
  const r = C.createRental({ car: st.cars[0], kids: 1, minutes: 10, now: T0, settings: st.settings });
  assert.equal(C.timeStatus(r, T0 + 5 * MIN, st.settings).state, 'ok');
  assert.equal(C.timeStatus(r, T0 + 9.5 * MIN, st.settings).state, 'warn');
  const exp = C.timeStatus(r, T0 + 12 * MIN, st.settings);
  assert.equal(exp.state, 'expired');
  assert.equal(C.formatClock(exp.remainingMs), '+02:00');
  assert.equal(C.formatClock(10 * MIN), '10:00');

  const within = C.overtimeInfo(r, T0 + 11 * MIN, st.settings);
  assert.equal(within.exceedsGrace, false);
  const over = C.overtimeInfo(r, T0 + 13 * MIN + 1000, st.settings);
  assert.equal(over.exceedsGrace, true);
  assert.equal(over.overMinutes, 4);
  assert.equal(over.blocks, 1);
  assert.equal(over.amount, 10000);
});

test('extender y finalizar con cobro de tiempo extra', () => {
  const st = fresh();
  const r = C.createRental({ car: st.cars[0], kids: 2, minutes: 10, payNow: true, now: T0, settings: st.settings });
  C.extendRental(r, { minutes: 10, now: T0 + 9 * MIN, settings: st.settings });
  assert.equal(r.minutes, 20);
  assert.equal(C.endAt(r), T0 + 20 * MIN);
  assert.equal(C.rentalTotals(r).balance, 15000);
  C.finishRental(r, { now: T0 + 25 * MIN, settings: st.settings, overtimeMinutes: 5 });
  assert.equal(r.status, 'finished');
  assert.equal(C.rentalTotals(r).charged, 45000);
  assert.throws(() => C.extendRental(r, { minutes: 10, settings: st.settings }), /pista/);
});

test('reporte diario: producido, recaudado, por cobrar, gastos y caja', () => {
  const st = fresh();
  const [a, b, c] = st.cars;
  const r1 = C.createRental({ car: a, kids: 1, minutes: 10, payNow: true, method: 'Efectivo', now: T0, settings: st.settings });
  const r2 = C.createRental({ car: b, kids: 2, minutes: 20, payNow: true, method: 'Nequi', now: T0 + MIN, settings: st.settings });
  const r3 = C.createRental({ car: c, kids: 1, minutes: 10, now: T0 + 2 * MIN, settings: st.settings });
  const r4 = C.createRental({ car: c, kids: 2, minutes: 10, payNow: true, now: T0 + 30 * MIN, settings: st.settings });
  C.cancelRental(r4, T0 + 31 * MIN);
  st.rentals.push(r1, r2, r3, r4);
  st.expenses.push(C.createExpense({ concept: 'Carga baterías', category: 'energia', amount: 8000, method: 'Efectivo', now: T0 + 60 * MIN }));
  st.closures[TODAY] = { openingCash: 50000, countedCash: 51000 };

  const rep = C.report(st, TODAY, TODAY);
  assert.equal(rep.rides, 3); // el cancelado no cuenta
  assert.equal(rep.kids, 4);
  assert.equal(rep.produced, 10000 + 30000 + 10000);
  assert.equal(rep.collected, 40000);
  assert.equal(rep.cashCollected, 10000);
  assert.equal(rep.digitalCollected, 30000);
  assert.equal(rep.pendingFromPeriod, 10000);
  assert.equal(rep.expensesTotal, 8000);
  assert.equal(rep.byKids[1].rides, 2);
  assert.equal(rep.byKids[2].produced, 30000);
  assert.equal(rep.byCar[b.id].produced, 30000);
  // Caja: 50.000 base + 10.000 efectivo - 8.000 gasto = 52.000 esperado; contado 51.000
  assert.equal(rep.cash.expected, 52000);
  assert.equal(rep.cash.diff, -1000);
  assert.equal(rep.netIncome, 50000 - 8000 - 1000);
});

test('pago recibido al día siguiente cuenta como recaudo de cartera', () => {
  const st = fresh();
  const r = C.createRental({ car: st.cars[0], kids: 1, minutes: 10, now: T0, settings: st.settings });
  C.finishRental(r, { now: T0 + 10 * MIN, settings: st.settings });
  st.rentals.push(r);
  const tomorrow = T0 + 24 * 60 * MIN;
  C.addPayment(r, { amount: 10000, method: 'Efectivo', now: tomorrow });
  const day2 = C.dayKey(tomorrow);
  const rep2 = C.report(st, day2, day2);
  assert.equal(rep2.produced, 0);
  assert.equal(rep2.collected, 10000);
  assert.equal(rep2.collectedFromPrevious, 10000);
  const rep1 = C.report(st, TODAY, TODAY);
  assert.equal(rep1.produced, 10000);
  assert.equal(rep1.collected, 0);
});

test('libro diario siempre cuadra (débitos = créditos)', () => {
  const st = fresh();
  const r1 = C.createRental({ car: st.cars[0], kids: 1, minutes: 10, payNow: true, now: T0, settings: st.settings });
  const r2 = C.createRental({ car: st.cars[1], kids: 2, minutes: 10, now: T0, settings: st.settings });
  C.extendRental(r1, { minutes: 10, now: T0 + 5 * MIN, settings: st.settings, payNow: true, method: 'Daviplata' });
  C.finishRental(r2, { now: T0 + 20 * MIN, settings: st.settings, overtimeMinutes: 10 });
  C.writeOffRental(r2, { now: T0 + 21 * MIN, reason: 'Se fue sin pagar' });
  st.rentals.push(r1, r2);
  st.expenses.push(C.createExpense({ concept: 'Almuerzo trabajador', category: 'personal', amount: 12000, now: T0 }));
  st.closures[TODAY] = { openingCash: 0, countedCash: 0, closedAt: T0 + 8 * 60 * MIN };

  const entries = C.journal(st, TODAY, TODAY);
  for (const e of entries) {
    assert.equal(C.sum(e.lines, (l) => l.debit), C.sum(e.lines, (l) => l.credit), e.description);
  }
  const led = C.ledger(entries);
  assert.equal(led.totalDebit, led.totalCredit);
  const clientes = led.accounts.find((a) => a.code === '1305');
  assert.equal(clientes.balance, 0); // todo cobrado o castigado
  const ingresos = led.accounts.find((a) => a.code === '4155');
  assert.equal(ingresos.credit, 10000 + 10000 + 15000 + 15000);
  const caja = led.accounts.find((a) => a.code === '1105');
  // 10.000 cobrados en efectivo - 12.000 gasto + 2.000 de sobrante (contado 0 vs esperado -2.000) = 0
  assert.equal(caja.balance, 0);
});

test('castigo de cartera solo para alquileres finalizados con saldo', () => {
  const st = fresh();
  const r = C.createRental({ car: st.cars[0], kids: 1, minutes: 10, now: T0, settings: st.settings });
  assert.throws(() => C.writeOffRental(r), /finaliza/);
  C.finishRental(r, { now: T0 + 10 * MIN, settings: st.settings });
  C.writeOffRental(r, { now: T0 + 11 * MIN });
  assert.equal(C.rentalTotals(r).payStatus, 'castigado');
  assert.throws(() => C.writeOffRental(r), /saldo/);
});

test('utilidades de formato y CSV', () => {
  assert.equal(C.parseMoney('$ 15.000'), 15000);
  assert.equal(C.parseMoney(''), 0);
  assert.match(C.formatMoney(15000), /15\.000/);
  assert.deepEqual(C.daysBetween('2026-10-30', '2026-11-02'), ['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02']);
  const csv = C.toCSV([['a;b', 'c"d'], [1, 2]]);
  assert.equal(csv, '﻿"a;b";"c""d"\r\n1;2');
});

test('normalizeState completa datos faltantes', () => {
  const s = C.normalizeState({ settings: { prices: { 1: 12000 } }, rentals: [{ id: 'x' }] });
  assert.equal(s.settings.prices[1], 12000);
  assert.equal(s.settings.prices[2], 15000);
  assert.deepEqual(s.rentals[0].charges, []);
  assert.equal(s.cars.length, 4);
});
