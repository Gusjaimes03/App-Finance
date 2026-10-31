/* Persistencia local (localStorage) y respaldo en archivo JSON. */
(function (root) {
  'use strict';
  const C = root.Core;
  const KEY = 'carritos-kids.v1';

  function load() {
    try {
      const raw = root.localStorage.getItem(KEY);
      if (!raw) return C.defaultState();
      return C.normalizeState(JSON.parse(raw));
    } catch (err) {
      console.error('No se pudieron leer los datos guardados', err);
      return C.defaultState();
    }
  }

  function save(state) {
    try {
      root.localStorage.setItem(KEY, JSON.stringify(state));
      return true;
    } catch (err) {
      console.error('No se pudieron guardar los datos', err);
      return false;
    }
  }

  function exportBackup(state) {
    return JSON.stringify({ app: 'carritos-kids', exportedAt: new Date().toISOString(), state }, null, 2);
  }

  function parseBackup(text) {
    const data = JSON.parse(text);
    const state = data && data.state ? data.state : data;
    if (!state || !Array.isArray(state.rentals) || !Array.isArray(state.cars)) {
      throw new Error('El archivo no es un respaldo válido de Carritos Kids');
    }
    return C.normalizeState(state);
  }

  root.Store = { KEY, load, save, exportBackup, parseBackup };
})(self);
