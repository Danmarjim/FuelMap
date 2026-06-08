/* ============================================================
   FuelMap doc engine
   - Reads REAL token values from tokens.css via theme probes,
     so swatches & contrast ratios always match implementation.
   - Builds iPhone chrome so device markup stays content-only.
   ============================================================ */
(function () {
  "use strict";

  /* ---------- color math ---------- */
  function hexToRgb(hex) {
    hex = hex.trim();
    if (hex.startsWith("rgb")) {
      const m = hex.match(/[\d.]+/g).map(Number);
      return { r: m[0], g: m[1], b: m[2] };
    }
    hex = hex.replace("#", "");
    if (hex.length === 3) hex = hex.split("").map(c => c + c).join("");
    return { r: parseInt(hex.slice(0, 2), 16), g: parseInt(hex.slice(2, 4), 16), b: parseInt(hex.slice(4, 6), 16) };
  }
  function lin(c) { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
  function lum({ r, g, b }) { return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b); }
  function contrast(a, b) {
    const L1 = lum(hexToRgb(a)), L2 = lum(hexToRgb(b));
    const hi = Math.max(L1, L2), lo = Math.min(L1, L2);
    return (hi + 0.05) / (lo + 0.05);
  }
  function grade(ratio, large) {
    const aa = large ? 3 : 4.5, aaa = large ? 4.5 : 7;
    if (ratio >= aaa) return "AAA";
    if (ratio >= aa) return "AA";
    if (ratio >= 3) return "AA·lg";
    return "fail";
  }
  window.FMContrast = contrast;

  /* ---------- read real token values ---------- */
  const probes = {};
  function makeProbe(theme) {
    const p = document.createElement("div");
    p.setAttribute("data-theme", theme);
    p.style.cssText = "position:absolute;width:0;height:0;overflow:hidden;opacity:0;pointer-events:none;";
    document.body.appendChild(p);
    return p;
  }
  function getVar(name, theme) {
    const p = probes[theme] || (probes[theme] = makeProbe(theme));
    let v = getComputedStyle(p).getPropertyValue(name).trim();
    // resolve one level of var() alias if needed
    if (v.startsWith("var(")) {
      const inner = v.slice(4, -1).split(",")[0].trim();
      v = getVar(inner, theme);
    }
    return v;
  }
  window.FMToken = getVar;

  /* ---------- swatch rendering ---------- */
  function lightText(bgHex) { return contrast(bgHex, "#FFFFFF") >= contrast(bgHex, "#000000"); }

  function swatchDual(token) {
    const L = getVar(token.var, "light"), D = getVar(token.var, "dark");
    const el = document.createElement("div");
    el.className = "swatch dual";
    let chips = `<div class="chip">`;
    [["light", L], ["dark", D]].forEach(([t, hex]) => {
      const onDark = lightText(hex);
      let badge = "";
      if (token.on) {
        const onHex = getVar(token.on, t);
        const r = contrast(hex, onHex);
        badge = `<span class="ratio ${onDark ? "on-dark" : ""}">${r.toFixed(1)} ${grade(r, token.large)}</span>`;
      }
      chips += `<div style="background:${hex}">${badge}</div>`;
    });
    chips += `</div>`;
    el.innerHTML = chips +
      `<div class="meta"><div class="name">${token.name}</div>
       <div class="hex">${L} · ${D}</div></div>`;
    return el;
  }

  function swatchSingle(token) {
    const hex = getVar(token.var, token.theme || "light");
    const onDark = lightText(hex);
    let badge = "";
    if (token.on) {
      const onHex = token.onHex || getVar(token.on, token.theme || "light");
      const r = contrast(hex, onHex);
      badge = `<span class="ratio ${onDark ? "on-dark" : ""}">${r.toFixed(1)} ${grade(r, token.large)}</span>`;
    }
    const el = document.createElement("div");
    el.className = "swatch";
    el.innerHTML =
      `<div class="chip" style="background:${hex}">${badge}</div>
       <div class="meta"><div class="name">${token.name}</div><div class="hex">${hex}</div></div>`;
    return el;
  }

  function fill(id, tokens, mode) {
    const host = document.getElementById(id);
    if (!host) return;
    tokens.forEach(t => host.appendChild(mode === "single" ? swatchSingle(t) : swatchDual(t)));
  }

  /* ---------- token groups ---------- */
  const RAMP = ["--brand-50","--brand-100","--brand-200","--brand-300","--brand-400","--brand-500","--brand-600","--brand-700"]
    .map(v => ({ name: v.replace("--brand-", "brand "), var: v, theme: "light" }));

  const BRAND = [
    { name: "brandPrimary", var: "--brandPrimary" },
    { name: "brandPrimaryFill", var: "--brandPrimaryFill", on: "--onBrand" },
    { name: "brandTint", var: "--brandTint" },
    { name: "brandSurface", var: "--brandSurface" },
  ];
  const SURFACES = [
    { name: "surface", var: "--surface", on: "--textPrimary" },
    { name: "surfaceElevated", var: "--surfaceElevated" },
    { name: "surfaceSecondary", var: "--surfaceSecondary" },
    { name: "surfaceTertiary", var: "--surfaceTertiary" },
    { name: "separator", var: "--separator" },
  ];
  const TEXT = [
    { name: "textPrimary", var: "--textPrimary", on: "--surface" },
    { name: "textSecondary", var: "--textSecondary", on: "--surface" },
    { name: "textTertiary", var: "--textTertiary", on: "--surface", large: true },
    { name: "onBrand", var: "--onBrand", on: "--brandPrimaryFill" },
  ];
  const TIERS = [
    { name: "priceCheap", var: "--priceCheap", on: "--textOnTier", large: true },
    { name: "priceMid", var: "--priceMid", on: "--textOnTier", large: true },
    { name: "priceHigh", var: "--priceHigh", on: "--textOnTier", large: true },
  ];
  const FUNC = [
    { name: "success", var: "--success", on: "--textOnTier", large: true },
    { name: "warning", var: "--warning", on: "--textOnTier", large: true },
    { name: "error", var: "--error", on: "--textOnTier", large: true },
  ];

  /* ---------- JSON appendix ---------- */
  function buildAppendix() {
    const groups = {
      brand: BRAND, surfaces: SURFACES, text: TEXT,
      price: TIERS, functional: FUNC,
    };
    const out = { light: {}, dark: {} };
    Object.values(groups).flat().forEach(t => {
      out.light[t.name] = getVar(t.var, "light");
      out.dark[t.name] = getVar(t.var, "dark");
    });
    const host = document.getElementById("json-appendix");
    if (host) host.textContent = JSON.stringify(out, null, 2);
  }

  /* ---------- iPhone chrome ---------- */
  function buildChrome() {
    document.querySelectorAll(".device .screen").forEach(scr => {
      if (scr.dataset.chromed) return;
      scr.dataset.chromed = "1";
      const dev = scr.closest(".device");
      if (dev.hasAttribute("data-map")) {
        const m = document.createElement("div");
        m.className = "map";
        m.innerHTML = '<svg class="mapsvg" viewBox="0 0 390 844" preserveAspectRatio="xMidYMid slice"><use href="#citymap"/></svg>';
        scr.insertBefore(m, scr.firstChild);
      }
      scr.insertAdjacentHTML("beforeend",
        '<div class="island"></div>' +
        '<div class="statusbar on-map"><span class="time">9:41</span>' +
        '<span class="sysicons">' +
        '<svg viewBox="0 0 20 14"><use href="#ic-cellular"/></svg>' +
        '<svg viewBox="0 0 18 14"><use href="#ic-wifi"/></svg>' +
        '<svg viewBox="0 0 28 14"><use href="#ic-battery"/></svg>' +
        '</span></div>' +
        '<div class="home-ind"></div>');
    });
  }

  /* ---------- init ---------- */
  function init() {
    buildChrome();
    fill("ramp", RAMP, "single");
    fill("sw-brand", BRAND, "dual");
    fill("sw-surface", SURFACES, "dual");
    fill("sw-text", TEXT, "dual");
    fill("sw-tier", TIERS, "dual");
    fill("sw-func", FUNC, "dual");
    buildAppendix();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
