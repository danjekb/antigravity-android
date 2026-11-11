/* Antigravity Security Shield (Toolbar Policy Manager).
 * Reads and writes the live settings store (window.__agySettings),
 * persists selections to localStorage and mirrors them to config.json.
 * Provides instant 1-click toggling of sandbox, policies, and terminal execution.
 */
(function () {
  "use strict";
  if (window.__agyShield) return;
  window.__agyShield = true;

  var BOX = "[data-testid='agent-input-box']";
  var SVG = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3l7 3v5c0 4.6-3 8.4-7 10-4-1.6-7-5.4-7-10V6l7-3z"/><path d="M9 12l2 2 4-4"/></svg>';

  function getLang() {
    try {
      var l = (navigator.language || "en").toLowerCase();
      if (l.startsWith("pl")) return "pl";
      if (l.startsWith("ru")) return "ru";
      return "en";
    } catch (_) { return "en"; }
  }

  function tr(en, pl, ru) {
    var l = getLang();
    if (l === "pl") return pl || en;
    if (l === "ru") return ru || en;
    return en;
  }

  function injectStyles() {
    if (document.getElementById("agy-shield-style")) return;
    var st = document.createElement("style");
    st.id = "agy-shield-style";
    st.textContent = [
      ".agy-shield-btn { all: unset; box-sizing: border-box; display: inline-flex; align-items: center; justify-content: center; width: 28px; height: 28px; border-radius: 6px; cursor: pointer; color: var(--muted-foreground, #888); transition: background .15s, color .15s; margin-right: 4px; }",
      ".agy-shield-btn:hover, .agy-shield-btn[aria-expanded='true'] { background: rgba(127,127,127,.18); color: var(--foreground, #fff); }",
      "#agy-shield { position: fixed; z-index: 9999; background: var(--background, #18181b); color: var(--foreground, #fafafa); border: 1px solid var(--border, rgba(127,127,127,.25)); border-radius: 12px; box-shadow: 0 10px 25px -5px rgba(0,0,0,.4), 0 8px 10px -6px rgba(0,0,0,.4); padding: 6px; font-size: 13px; overflow-y: auto; backdrop-filter: blur(8px); }",
      "#agy-shield button { all: unset; box-sizing: border-box; cursor: pointer; display: flex; align-items: center; width: 100%; gap: 8px; border-radius: 8px; }",
      "#agy-shield .agy-sh-head { padding: 8px 10px; }",
      "#agy-shield .agy-sh-head:hover { background: rgba(127,127,127,.12); }",
      "#agy-shield .agy-sh-title { flex: 1 1 auto; min-width: 0; font-weight: 500; }",
      "#agy-shield .agy-sh-cur { color: var(--muted-foreground, #888); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 45%; }",
      "#agy-shield .agy-sh-chev { flex-shrink: 0; opacity: .6; transition: transform .15s; }",
      "#agy-shield .agy-sh-sec.open .agy-sh-chev { transform: rotate(180deg); }",
      "#agy-shield .agy-sh-sec + .agy-sh-sec { border-top: 1px solid var(--border, rgba(127,127,127,.15)); }",
      "#agy-shield .agy-sh-opts { padding: 0 0 4px 8px; }",
      "#agy-shield .agy-sh-opt { padding: 6px 10px; justify-content: space-between; }",
      "#agy-shield .agy-sh-opt:hover { background: rgba(127,127,127,.12); }",
      "#agy-shield .agy-sh-opt.sel { background: rgba(127,127,127,.22); font-weight: 500; }",
      "#agy-shield .agy-sh-opt.passive:not(.sel) { opacity: .6; cursor: default; }",
      "#agy-shield .agy-sh-ol { display: flex; flex-direction: column; gap: 2px; min-width: 0; }",
      "#agy-shield .agy-sh-od { color: var(--muted-foreground, #888); font-size: 11.5px; white-space: normal; }",
      "#agy-shield .agy-sh-empty { padding: 10px; color: var(--muted-foreground, #888); text-align: center; }"
    ].join("\n");
    document.head.appendChild(st);
  }

  function api() {
    var x = window.__agySettings;
    if (!x || !x.store || !x.store.getState) return null;
    var st = x.store.getState();
    if (!st || typeof st.getPrefValue !== "function" || typeof st.setPrefValue !== "function") return null;
    return x;
  }

  function get(key) {
    var x = api();
    return x ? x.store.getState().getPrefValue(x.Ui[key]) : undefined;
  }

  function set(key, v) {
    var x = api();
    if (x) x.store.getState().setPrefValue(x.Ui[key], v);
  }

  function osGroup(x) {
    var os = x.qq();
    return os === "macos" || os === "linux" ? "macos_linux" : "windows";
  }

  function normEnum(v, E) {
    if (typeof v !== "string") return v;
    var u = v.toUpperCase(), best, bl = -1;
    for (var k in E) {
      if (typeof E[k] !== "number") continue;
      if (u.length >= k.length && u.lastIndexOf(k) === u.length - k.length && k.length > bl) {
        best = E[k];
        bl = k.length;
      }
    }
    return best !== undefined ? best : E.UNSPECIFIED;
  }

  var OVK = "agyShieldOv";
  function ovAll() { try { return JSON.parse(window.localStorage.getItem(OVK) || "{}"); } catch (e) { return {}; } }
  function ovGet(id) { var o = ovAll(); return o[id]; }
  function ovSet(id, v) { try { var o = ovAll(); o[id] = v; window.localStorage.setItem(OVK, JSON.stringify(o)); } catch (e) {} }

  var pickAt = {};
  var SECTIONS_CFG = {
    file: { field: "nonWorkspaceFileAccessPolicy", prefix: "AGENT_SETTING_POLICY" },
    net:  { field: "internetAccessPolicy", prefix: "AGENT_SETTING_POLICY" },
    term: { field: "autoExecutionPolicy", prefix: "CASCADE_COMMANDS_AUTO_EXECUTION" },
    sbx:  { field: "enableTerminalSandbox", bool: true },
    js:   { field: "browserJsExecutionPolicy", prefix: "BROWSER_JS_EXECUTION_POLICY" }
  };

  function cfgStr(cfg, v) {
    if (cfg.bool) return v ? "true" : "false";
    return cfg.prefix + "_" + cfg.E[v];
  }

  function bridgePolicy(arg, done) {
    var b = window.AgyTools;
    if (!b || typeof b.start !== "function") {
      if (done) done(null);
      return;
    }
    var id;
    try { id = b.start("policy", arg); } catch (e) { if (done) done(null); return; }
    if (!id || /^ERR/.test(String(id))) { if (done) done(null); return; }
    var t0 = Date.now();
    (function poll() {
      var r = null;
      try { r = JSON.parse(b.read(id) || "{}"); } catch (e) {}
      if (r && r.rc !== undefined && r.rc !== "") { if (done) done(r); return; }
      if (Date.now() - t0 > 15000) { if (done) done(null); return; }
      setTimeout(poll, 300);
    })();
  }

  function syncFromBridge() {
    var x = api();
    if (!x) return;
    var defaults = {
      file: "NON_WORKSPACE_FILE_ACCESS_POLICY",
      net: "INTERNET_ACCESS_POLICY",
      term: "CASCADE_AUTO_EXECUTION_POLICY",
      js: "BROWSER_JS_EXECUTION_POLICY",
      sbx: "ENABLE_TERMINAL_SANDBOX"
    };
    var fields = [];
    for (var id in defaults) {
      var cfg = SECTIONS_CFG[id], value = get(defaults[id]);
      if (cfg.bool) value = value === true;
      else {
        value = normEnum(value, cfg.E);
        if (value === undefined || value === cfg.E.UNSPECIFIED || cfg.E[value] === undefined) {
          value = id === "term" ? cfg.E.OFF : id === "js" ? cfg.E.ALWAYS_ASK : cfg.E.ASK;
        }
      }
      fields.push(cfg.field + "=" + cfgStr(cfg, value));
    }
    bridgePolicy("init," + fields.join(","), function (r) {
      if (!r || !r.log || String(r.rc) !== "0") { if (pop) render(); return; }
      var changed = false;
      (String(r.log).match(/@@kv \S+ \S*/g) || []).forEach(function (line) {
        var m = /^@@kv (\S+) (\S*)$/.exec(line);
        if (!m) return;
        for (var sid in SECTIONS_CFG) {
          var sc = SECTIONS_CFG[sid];
          if (sc.field !== m[1]) continue;
          if (pickAt[sid] && Date.now() - pickAt[sid] < 3000) continue;
          ovSet(sid, sc.bool ? (m[2].toLowerCase() === "true") : normEnum(m[2], sc.E));
          changed = true;
        }
      });
      if (changed && pop) render();
    });
  }

  function mirrorPick(id, v) {
    var cfg = SECTIONS_CFG[id];
    if (!cfg) return;
    pickAt[id] = Date.now();
    ovSet(id, v);
    bridgePolicy(cfg.field + "=" + cfgStr(cfg, v));
  }

  function sections() {
    var x = api();
    if (!x) return null;
    var I = x.I, CAE = I.CascadeCommandsAutoExecution, ASP = I.AgentSettingPolicy, JS = I.BrowserJsExecutionPolicy;
    SECTIONS_CFG.file.E = ASP;
    SECTIONS_CFG.net.E = ASP;
    SECTIONS_CFG.term.E = CAE;
    SECTIONS_CFG.js.E = JS;

    var sandbox = get("ENABLE_TERMINAL_SANDBOX");
    var term = normEnum(get("CASCADE_AUTO_EXECUTION_POLICY"), CAE);
    var file = normEnum(get("NON_WORKSPACE_FILE_ACCESS_POLICY"), ASP);
    if (file === undefined || file === ASP.UNSPECIFIED) file = ASP.ASK;
    var js = normEnum(get("BROWSER_JS_EXECUTION_POLICY"), JS);
    var net = normEnum(get("INTERNET_ACCESS_POLICY"), ASP);
    if (net === undefined || net === ASP.UNSPECIFIED) net = ASP.ASK;
    if (js === undefined || js === JS.UNSPECIFIED) js = JS.ALWAYS_ASK;

    if (ovGet("sbx") !== undefined) sandbox = ovGet("sbx");
    if (ovGet("term") !== undefined) term = ovGet("term");
    if (ovGet("file") !== undefined) file = ovGet("file");
    if (ovGet("net") !== undefined) net = ovGet("net");
    if (ovGet("js") !== undefined) js = ovGet("js");

    if (file === undefined || file === ASP.UNSPECIFIED || ASP[file] === undefined) file = ASP.ASK;
    if (net === undefined || net === ASP.UNSPECIFIED || ASP[net] === undefined) net = ASP.ASK;
    if (term === undefined || term === CAE.UNSPECIFIED || CAE[term] === undefined) term = CAE.OFF;
    if (js === undefined || js === JS.UNSPECIFIED || JS[js] === undefined) js = JS.ALWAYS_ASK;

    var presets = x.hEa[x.qq()].presets;
    var cur = x.iEa(sandbox === undefined ? false : sandbox, term, file, presets);
    var labels = x.Mt[osGroup(x)];
    var presetOpts = presets.map(function (p) {
      return { v: p, label: labels[p].displayName, desc: labels[p].shortDescription };
    });
    presetOpts.push({
      v: "custom",
      label: tr("Custom", "Własny", "Пользовательский"),
      desc: tr("Manually customize individual settings.", "Ręcznie dostosuj poszczególne parametry.", "Настройте отдельные параметры вручную."),
      passive: true
    });

    return [
      {
        id: "preset",
        title: tr("Security Preset", "Profil bezpieczeństwa", "Профиль безопасности"),
        value: cur,
        opts: presetOpts,
        pick: function (v) {
          var p = x.gEa[v];
          if (!p) return;
          set("ENABLE_TERMINAL_SANDBOX", p.sandboxMode);
          set("CASCADE_AUTO_EXECUTION_POLICY", p.terminal);
          set("NON_WORKSPACE_FILE_ACCESS_POLICY", p.fileAccess);
        }
      },
      {
        id: "file",
        title: tr("Non-workspace File Access", "Dostęp do plików poza projektem", "Доступ к файлам вне папок"),
        value: file,
        opts: [
          { v: ASP.ASK, label: tr("Always ask", "Zawsze pytaj", "Всегда спрашивать") },
          { v: ASP.ALLOW, label: tr("Allow", "Zezwalaj", "Разрешить") },
          { v: ASP.DENY, label: tr("Deny", "Blokuj", "Запретить") }
        ],
        pick: function (v) { set("NON_WORKSPACE_FILE_ACCESS_POLICY", v); }
      },
      {
        id: "net",
        title: tr("Internet Access", "Dostęp do internetu", "Доступ в интернет"),
        value: net,
        opts: [
          { v: ASP.ASK, label: tr("Always ask", "Zawsze pytaj", "Всегда спрашивать") },
          { v: ASP.ALLOW, label: tr("Allow", "Zezwalaj", "Разрешить") },
          { v: ASP.DENY, label: tr("Deny", "Blokuj", "Запретить") }
        ],
        pick: function (v) { set("INTERNET_ACCESS_POLICY", v); }
      },
      {
        id: "term",
        title: tr("Terminal Auto-execution", "Wykonywanie komend terminala", "Автовыполнение команд терминала"),
        value: term,
        opts: [
          { v: CAE.OFF, label: tr("Request review", "Wymagaj potwierdzenia", "Требовать подтверждение") },
          { v: CAE.PROCEED_IN_SANDBOX, label: tr("Proceed in sandbox", "W piaskownicy", "Выполнять в песочнице") },
          { v: CAE.EAGER, label: tr("Always proceed (autonomous)", "Zawsze wykonuj (autonomicznie)", "Не спрашивать") }
        ],
        pick: function (v) {
          set("CASCADE_AUTO_EXECUTION_POLICY", v);
          if (v === CAE.EAGER) {
            set("ENABLE_TERMINAL_SANDBOX", false);
            mirrorPick("sbx", false);
          }
          if (v === CAE.PROCEED_IN_SANDBOX) {
            set("ENABLE_TERMINAL_SANDBOX", true);
            mirrorPick("sbx", true);
          }
        }
      },
      {
        id: "sbx",
        title: tr("Linux Sandbox", "Piaskownica (Sandbox)", "Песочница"),
        value: sandbox === true,
        opts: [
          {
            v: false,
            label: tr("Off (Direct execution)", "Wyłączona (bezpośrednio)", "Выключена"),
            desc: tr("Commands execute directly in AGY sandbox. Required for Android.", "Komendy wykonują się bezpośrednio. Wymagane dla Androida.", "Команды выполняются напрямую. Нужно для работы без подтверждений на Android.")
          },
          {
            v: true,
            label: tr("On (bwrap)", "Włączona (bwrap)", "Включена"),
            desc: tr("Requires desktop Linux bwrap; on Android triggers fallback prompts.", "Wymaga linuksowego bwrap; na Androidzie wywołuje monity.", "На Android не работает (нет bwrap).")
          }
        ],
        pick: function (v) { set("ENABLE_TERMINAL_SANDBOX", v); }
      },
      {
        id: "js",
        title: tr("Browser JavaScript", "JavaScript w przeglądarce", "JavaScript в браузере"),
        value: js,
        opts: [
          { v: JS.DISABLED, label: tr("Disabled", "Wyłączony", "Отключено") },
          { v: JS.ALWAYS_ASK, label: tr("Ask first", "Pytaj przed uruchomieniem", "Запрашивать подтверждение") },
          { v: JS.TURBO, label: tr("Always run", "Zawsze uruchamiaj", "Не спрашивать") }
        ],
        pick: function (v) { set("BROWSER_JS_EXECUTION_POLICY", v); }
      }
    ];
  }

  var pop = null, openId = null, unsub = null;

  function esc(s) {
    return String(s || "").replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  function render() {
    if (!pop) return;
    var secs = sections();
    if (!secs) {
      pop.innerHTML = '<div class="agy-sh-empty">' + esc(tr("Settings are still loading…", "Ładowanie ustawień…", "Настройки ещё загружаются…")) + "</div>";
      return;
    }
    var h = "";
    secs.forEach(function (s) {
      var cur = s.opts.filter(function (o) { return o.v === s.value; })[0];
      var open = openId === s.id;
      h += '<div class="agy-sh-sec' + (open ? " open" : "") + '">' +
        '<button type="button" class="agy-sh-head" data-sec="' + s.id + '"><span class="agy-sh-title">' + esc(s.title) + '</span>' +
        '<span class="agy-sh-cur">' + esc(cur ? cur.label : "—") + '</span>' +
        '<svg class="agy-sh-chev" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg></button>';
      if (open) {
        h += '<div class="agy-sh-opts" role="listbox">';
        s.opts.forEach(function (o, i) {
          var sel = o.v === s.value;
          h += '<button type="button" role="option" aria-selected="' + sel + '" class="agy-sh-opt' + (sel ? " sel" : "") + (o.passive ? " passive" : "") +
            '" data-sec="' + s.id + '" data-i="' + i + '"><span class="agy-sh-ol"><span>' + esc(o.label) + "</span>" +
            (o.desc ? '<span class="agy-sh-od">' + esc(o.desc) + "</span>" : "") + "</span>" +
            (sel ? '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M5 12l5 5 9-10"/></svg>' : "") + "</button>";
        });
        h += "</div>";
      }
      h += "</div>";
    });
    pop.innerHTML = h;
    place();
  }

  function place() {
    if (!pop) return;
    var box = document.querySelector(BOX);
    if (!box) { close(); return; }
    var r = box.getBoundingClientRect();
    var vw = window.innerWidth || document.documentElement.clientWidth;
    var w = Math.min(r.width, vw - 8);
    var left = Math.max(4, Math.min(r.left, vw - w - 4));
    pop.style.width = Math.round(w) + "px";
    pop.style.left = Math.round(left) + "px";
    pop.style.bottom = Math.round(window.innerHeight - r.top + 6) + "px";
    pop.style.maxHeight = Math.max(160, Math.round(r.top - 64)) + "px";
  }

  function open(btn) {
    if (pop) { close(); return; }
    injectStyles();
    pop = document.createElement("div");
    pop.id = "agy-shield";
    pop.setAttribute("data-agy-no-translate", "");
    pop.addEventListener("pointerdown", function (e) { e.preventDefault(); });
    pop.addEventListener("click", function (e) {
      var b = e.target.closest("button");
      if (!b) return;
      var id = b.getAttribute("data-sec");
      if (b.classList.contains("agy-sh-head")) {
        openId = openId === id ? null : id;
        render();
        return;
      }
      var secs = sections();
      if (!secs) return;
      var s = secs.filter(function (q) { return q.id === id; })[0];
      var o = s && s.opts[+b.getAttribute("data-i")];
      if (!o || o.passive) return;
      openId = null;
      try { s.pick(o.v); } catch (err) {}
      if (s.id === "preset") {
        var xx = api(), pp = xx && xx.gEa && xx.gEa[o.v];
        if (pp) {
          mirrorPick("sbx", pp.sandboxMode === true);
          mirrorPick("term", pp.terminal);
          mirrorPick("file", pp.fileAccess);
          if (pp.internetAccess !== undefined) mirrorPick("net", pp.internetAccess);
          if (pp.browserJs !== undefined) mirrorPick("js", pp.browserJs);
        }
      } else {
        mirrorPick(s.id, o.v);
      }
      setTimeout(render, 30);
    });
    document.body.appendChild(pop);
    btn.setAttribute("aria-expanded", "true");
    var x = api();
    if (x && x.store && x.store.onDidChange) {
      var d = x.store.onDidChange(function () { render(); });
      unsub = function () { try { d.dispose(); } catch (e) {} };
    }
    render();
    syncFromBridge();
  }

  function close() {
    if (unsub) { unsub(); unsub = null; }
    if (pop) { pop.remove(); pop = null; }
    openId = null;
    var b = document.querySelector(".agy-shield-btn");
    if (b) b.setAttribute("aria-expanded", "false");
  }

  document.addEventListener("pointerdown", function (e) {
    if (!pop) return;
    if (e.target.closest && (e.target.closest("#agy-shield") || e.target.closest(".agy-shield-btn"))) return;
    close();
  }, true);

  window.addEventListener("resize", function () { place(); });

  function ensureButton() {
    var plus = document.querySelector(BOX + " button[aria-label='Add context']");
    var footer = plus && plus.closest("[class*='input-footer']");
    if (!footer) {
      if (pop && !document.querySelector(BOX)) close();
      return;
    }
    var group = footer.lastElementChild;
    if (!group || group.contains(plus)) return;
    if (group.querySelector(".agy-shield-btn")) return;

    var b = document.createElement("button");
    b.type = "button";
    b.className = "agy-shield-btn";
    b.setAttribute("aria-label", tr("Security Shield", "Tarcza bezpieczeństwa", "Безопасность"));
    b.setAttribute("aria-expanded", "false");
    b.innerHTML = SVG;
    b.addEventListener("pointerdown", function (e) { e.preventDefault(); });
    b.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      open(b);
    });
    group.insertBefore(b, group.firstChild);
  }

  var raf = 0;
  function schedule() {
    if (!raf) raf = requestAnimationFrame(function () {
      raf = 0;
      ensureButton();
      if (pop) place();
    });
  }

  function start() {
    injectStyles();
    new MutationObserver(schedule).observe(document.body, { childList: true, subtree: true });
    schedule();
  }

  if (document.body) start();
  else document.addEventListener("DOMContentLoaded", start, { once: true });
})();

