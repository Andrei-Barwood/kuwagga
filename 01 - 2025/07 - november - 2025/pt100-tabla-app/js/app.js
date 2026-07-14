/**
 * Tabla PT100 / PT1000 — IEC 60751
 * Author: Kirtan Teg Singh (ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ)
 * Lógica portada desde 04_tabla_pt100.py
 * Funciona offline (PWA + service worker)
 */

(function () {
  "use strict";

  // Constantes IEC 60751 para RTD platinum
  const A = 3.9083e-3;
  const B = -5.775e-7;
  const C = -4.183e-12; // Solo para T < 0 °C

  /**
   * Calcula la resistencia de un sensor PT100 o PT1000 a una temperatura.
   * @param {number} temp Temperatura en °C
   * @param {"PT100"|"PT1000"} tipo
   * @returns {number} Resistencia en ohmios
   */
  function calcularResistenciaPt(temp, tipo) {
    const R0 = tipo === "PT100" ? 100 : 1000;
    const t = temp;
    if (t >= 0) {
      return R0 * (1 + A * t + B * t * t);
    }
    return R0 * (1 + A * t + B * t * t + C * (t - 100) * t * t * t);
  }

  /**
   * Genera filas de la tabla entre ti y tf con el paso indicado.
   * @param {number} ti
   * @param {number} tf
   * @param {number} step
   * @param {"PT100"|"PT1000"} tipo
   * @returns {{ t: number, R: number }[]}
   */
  function generarFilas(ti, tf, step, tipo) {
    const rows = [];
    // Usar contador entero para evitar errores de punto flotante
    const n = Math.floor((tf - ti) / step + 1e-9);
    for (let i = 0; i <= n; i++) {
      const t = ti + i * step;
      if (t > tf + 1e-9) break;
      rows.push({ t, R: calcularResistenciaPt(t, tipo) });
    }
    // Incluir tf si el paso no cae exactamente en el final
    if (rows.length === 0 || Math.abs(rows[rows.length - 1].t - tf) > 1e-6) {
      if (tf >= ti) {
        rows.push({ t: tf, R: calcularResistenciaPt(tf, tipo) });
      }
    }
    return rows;
  }

  // DOM
  const form = document.getElementById("tabla-form");
  const tiInput = document.getElementById("ti");
  const tfInput = document.getElementById("tf");
  const stepSelect = document.getElementById("step");
  const tipoSelect = document.getElementById("tipo");
  const formError = document.getElementById("form-error");
  const resultSection = document.getElementById("result-section");
  const resultTitle = document.getElementById("result-title");
  const resultMeta = document.getElementById("result-meta");
  const resultBody = document.getElementById("result-body");
  const btnExport = document.getElementById("btn-export");
  const btnPrint = document.getElementById("btn-print");
  const offlineBadge = document.getElementById("offline-badge");
  const swStatus = document.getElementById("sw-status");

  /** @type {{ ti: number, tf: number, step: number, tipo: string, rows: {t:number,R:number}[] } | null} */
  let lastResult = null;

  function showError(msg) {
    formError.textContent = msg;
    formError.hidden = !msg;
  }

  function fmt(n, decimals) {
    return n.toFixed(decimals);
  }

  function renderTable(ti, tf, step, tipo, rows) {
    resultTitle.textContent = `Tabla estándar ${tipo} — IEC 60751`;
    resultMeta.innerHTML =
      `<b>Temperatura</b> de ${fmt(ti, 2)} °C a ${fmt(tf, 2)} °C` +
      `&nbsp;|&nbsp; <b>Paso:</b> ${fmt(step, 2)} °C` +
      `&nbsp;|&nbsp; <b>${rows.length}</b> puntos`;

    const frag = document.createDocumentFragment();
    for (const { t, R } of rows) {
      const tr = document.createElement("tr");
      const tdT = document.createElement("td");
      const tdR = document.createElement("td");
      tdT.textContent = fmt(t, 2);
      tdR.textContent = `${fmt(R, 2)} Ω`;
      tr.appendChild(tdT);
      tr.appendChild(tdR);
      frag.appendChild(tr);
    }
    resultBody.replaceChildren(frag);
    resultSection.hidden = false;
    btnExport.disabled = false;
    btnPrint.disabled = false;
    lastResult = { ti, tf, step, tipo, rows };
  }

  function validate(ti, tf, step, tipo) {
    if (Number.isNaN(ti) || Number.isNaN(tf) || Number.isNaN(step)) {
      return "Error: Entrada inválida. Usa valores numéricos.";
    }
    if (tf <= ti) {
      return "Error: La temperatura final debe ser mayor que la inicial.";
    }
    if (step <= 0) {
      return "Error: El paso debe ser mayor que cero.";
    }
    if (tipo !== "PT100" && tipo !== "PT1000") {
      return "Error: Tipo de sensor debe ser PT100 o PT1000.";
    }
    const count = Math.floor((tf - ti) / step) + 2;
    if (count > 50000) {
      return "Error: Demasiados puntos. Amplía el paso o reduce el rango.";
    }
    return null;
  }

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    showError("");

    const ti = parseFloat(tiInput.value);
    const tf = parseFloat(tfInput.value);
    const step = parseFloat(stepSelect.value);
    const tipo = tipoSelect.value.trim().toUpperCase();

    const err = validate(ti, tf, step, tipo);
    if (err) {
      showError(err);
      resultSection.hidden = true;
      btnExport.disabled = true;
      btnPrint.disabled = true;
      lastResult = null;
      return;
    }

    const rows = generarFilas(ti, tf, step, tipo);
    renderTable(ti, tf, step, tipo, rows);
    resultSection.scrollIntoView({ behavior: "smooth", block: "start" });
  });

  btnPrint.addEventListener("click", function () {
    if (!lastResult) return;
    window.print();
  });

  btnExport.addEventListener("click", function () {
    if (!lastResult) return;
    const { ti, tf, step, tipo, rows } = lastResult;
    const rowsHtml = rows
      .map(
        ({ t, R }) =>
          `<tr><td>${fmt(t, 2)}</td><td>${fmt(R, 2)} Ω</td></tr>`
      )
      .join("\n    ");

    const html = `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="author" content="Kirtan Teg Singh (ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ)">
<title>Tabla estándar ${tipo}</title>
<style>
  body { background: #EAEEF4; font-family: Arial, sans-serif; }
  h2 { color: #485199; }
  table { border-collapse: collapse; width: 60%; margin:auto; box-shadow: 0 2px 8px #63627C44; }
  th { background: #485199; color: #FFFFB8; border: 2px solid #63627C; padding: 10px; }
  td { background: #A6A4D7; border: 1px solid #A7B7CF; text-align:center; padding: 6px; color: #63627C; }
  tr:nth-child(even) td { background: #EAEEF4; color: #63627C; }
  tr:hover td { background: #A7B7CF; color: #485199; }
  p { text-align:center; color: #63627C; }
  .author { font-size: 0.95rem; margin-top: 1.25rem; }
</style>
</head>
<body>
  <h2>Tabla estándar ${tipo} &mdash; IEC 60751</h2>
  <p>
    <b>Temperatura</b> de ${fmt(ti, 2)} °C a ${fmt(tf, 2)} °C &nbsp;|&nbsp; <b>Paso:</b> ${fmt(step, 2)} °C
  </p>
  <table>
    <tr>
      <th>Temperatura (°C)</th>
      <th>Resistencia (Ω)</th>
    </tr>
    ${rowsHtml}
  </table>
  <p class="author">
    <b>Autor / Author:</b> Kirtan Teg Singh · <span lang="pa">ਕੀਰਤਨ ਤੇਗ ਸਿੰਘ</span>
  </p>
</body>
</html>
`;

    const blob = new Blob([html], { type: "text/html;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `tabla_${tipo.toLowerCase()}_${fmt(ti, 0)}_${fmt(tf, 0)}.html`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  });

  // Estado online / offline
  function updateOnlineStatus() {
    const offline = !navigator.onLine;
    offlineBadge.hidden = !offline;
  }
  window.addEventListener("online", updateOnlineStatus);
  window.addEventListener("offline", updateOnlineStatus);
  updateOnlineStatus();

  // Service Worker para uso offline
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", function () {
      navigator.serviceWorker
        .register("./sw.js")
        .then(function (reg) {
          swStatus.textContent = "Listo para uso offline";
          console.info("[SW] Registrado:", reg.scope);
        })
        .catch(function (err) {
          swStatus.textContent = "Sin caché offline (abre vía http/https)";
          console.warn("[SW] No registrado:", err);
        });
    });
  } else {
    swStatus.textContent = "Navegador sin soporte de Service Worker";
  }

  // Exponer cálculo para pruebas en consola
  window.calcularResistenciaPt = calcularResistenciaPt;
})();
