/* Antigravity RU — Settings › Tools (ТЗ 9.3, B-22).
 * Rendered into the "Tools" settings screen (main.js calls
 * window.__agyToolsMount(el)). Every action goes through the native
 * window.AgyTools bridge, which runs the bundled agy-tools.sh with a
 * validated operation; the page only polls the job log. */
(function () {
  "use strict";
  if (window.__agyToolsReady) return;
  window.__agyToolsReady = true;

  function ru() {
    try {
      var l = (navigator.language || "").toLowerCase();
      return l.startsWith("ru");
    } catch (e) { return false; }
  }
  function T(r, e) { return ru() ? r : e; }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function store(k, v) { try { if (v === undefined) return localStorage.getItem(k); if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch (e) {} return null; }

  /* ------------------------------------------------------------ catalog */
  // kind: pkg (Termux package via pkg), npm (global npm), sdk (sdkmanager id), ndk (full NDK)
  var GROUPS = [
    { id: "node", ru: "Node.js — плагины и расширения", en: "Node.js — plugins and extensions", items: [
      { id: "nodejs-lts", kind: "pkg", ru: "Node.js LTS + npm", en: "Node.js LTS + npm", dru: "Рекомендуется. Нужен для плагинов, MCP-серверов и расширений.", den: "Recommended. Required by plugins, MCP servers and extensions.", verify: "node-lts,npm" },
      { id: "nodejs", kind: "pkg", ru: "Node.js (текущая версия)", en: "Node.js (current)", dru: "Вместо LTS, если нужна самая новая версия. Не ставить вместе с LTS.", den: "Instead of LTS when the newest version is needed. Do not install together with LTS.", verify: "node-current,npm" },
      { id: "yarn", kind: "pkg", ru: "Yarn", en: "Yarn", dru: "Менеджер пакетов JavaScript.", den: "JavaScript package manager." },
      { id: "pnpm", kind: "npm", ru: "pnpm", en: "pnpm", dru: "Устанавливается через npm -g.", den: "Installed with npm -g.", verify: "pnpm" },
      { id: "typescript", kind: "npm", ru: "TypeScript (tsc)", en: "TypeScript (tsc)", dru: "Компилятор TypeScript через npm -g.", den: "TypeScript compiler via npm -g.", verify: "tsc" }
    ] },
    { id: "build", ru: "Сборка нативного кода", en: "Native build tools", items: [
      { id: "clang", kind: "pkg", ru: "Clang / LLVM", en: "Clang / LLVM", dru: "C/C++ компилятор; нужен node-gyp и NDK-сборкам.", den: "C/C++ compiler; needed by node-gyp and NDK builds.", verify: "clang" },
      { id: "lld", kind: "pkg", ru: "LLD", en: "LLD", dru: "Линкер LLVM.", den: "LLVM linker." },
      { id: "make", kind: "pkg", ru: "Make", en: "Make", dru: "Классическая система сборки по Makefile.", den: "Classic Makefile-based build system." },
      { id: "cmake", kind: "pkg", ru: "CMake", en: "CMake", dru: "Кроссплатформенная система сборки для C/C++.", den: "Cross-platform build system generator for C/C++.", verify: "cmake" },
      { id: "ninja", kind: "pkg", ru: "Ninja", en: "Ninja", dru: "Быстрая система сборки, используется CMake и NDK.", den: "Fast build system used by CMake and NDK." },
      { id: "pkg-config", kind: "pkg", ru: "pkg-config", en: "pkg-config", dru: "Получение флагов компилятора для системных библиотек.", den: "Retrieves compiler flags for installed system libraries." },
      { id: "binutils", kind: "pkg", ru: "Binutils", en: "Binutils", dru: "objdump, readelf, strip…", den: "objdump, readelf, strip…" },
      { id: "python", kind: "pkg", ru: "Python 3", en: "Python 3", dru: "Нужен node-gyp и многим скриптам.", den: "Needed by node-gyp and many scripts.", verify: "python" },
      { id: "python-pip", kind: "pkg", ru: "pip", en: "pip", dru: "Менеджер пакетов Python.", den: "Python package manager." }
    ] },
    { id: "java", ru: "Java и Kotlin", en: "Java and Kotlin", items: [
      { id: "openjdk-17", kind: "pkg", ru: "OpenJDK 17", en: "OpenJDK 17", dru: "Для Gradle и Android Gradle Plugin 8.x.", den: "For Gradle and Android Gradle Plugin 8.x.", verify: "java17,javac17" },
      { id: "openjdk-21", kind: "pkg", ru: "OpenJDK 21", en: "OpenJDK 21", dru: "Новее; AGP 8.x работает и с 17.", den: "Newer; AGP 8.x works with 17 as well.", verify: "java21,javac21" },
      { id: "kotlin", kind: "pkg", ru: "Kotlin (kotlinc)", en: "Kotlin (kotlinc)", dru: "Компилятор языка Kotlin.", den: "Kotlin language compiler.", verify: "kotlin" },
      { id: "gradle", kind: "pkg", ru: "Gradle", en: "Gradle", dru: "Сборка Android-проектов.", den: "Builds Android projects.", verify: "gradle" },
      { id: "maven", kind: "pkg", ru: "Maven", en: "Maven", dru: "Система сборки и управления зависимостями для Java.", den: "Build and dependency management system for Java." }
    ] },
    { id: "android", ru: "Android: сборка APK", en: "Android: APK build", items: [
      { id: "aapt", kind: "pkg", ru: "aapt + zipalign", en: "aapt + zipalign", dru: "Упаковка ресурсов и выравнивание APK.", den: "Resource packaging and APK alignment; zipalign is included in aapt.", verify: "aapt,zipalign" },
      { id: "aapt2", kind: "pkg", ru: "aapt2", en: "aapt2", dru: "Обработка ресурсов Android.", den: "Native aapt2 — Gradle uses it instead of the x86 build.", verify: "aapt2" },
      { id: "aidl", kind: "pkg", ru: "aidl", en: "aidl", dru: "Нативный компилятор интерфейсов AIDL.", den: "Native AIDL interface compiler.", verify: "aidl" },
      { id: "d8", kind: "pkg", ru: "d8", en: "d8", dru: "Компиляция в DEX.", den: "DEX compiler.", verify: "d8" },
      { id: "apksigner", kind: "pkg", ru: "apksigner", en: "apksigner", dru: "Подпись APK v1–v4.", den: "APK signing v1–v4.", verify: "apksigner" },
      { id: "android-tools", kind: "pkg", ru: "adb / fastboot", en: "adb / fastboot", dru: "Отладка по Wi-Fi и через Shizuku.", den: "Debugging over Wi-Fi and via Shizuku.", verify: "adb" },
      { id: "apktool", kind: "pkg", ru: "apktool", en: "apktool", dru: "Разбор и сборка APK.", den: "Decode and rebuild APKs.", verify: "apktool" },
      { id: "jadx", kind: "pkg", ru: "jadx", en: "jadx", dru: "Декомпилятор DEX → Java.", den: "DEX → Java decompiler.", verify: "jadx" }
    ] },
    { id: "sdk", ru: "Android SDK", en: "Android SDK", note: { ru: "Загружается с dl.google.com через sdkmanager. Нужен OpenJDK — поставится сам. x86-бинарники build-tools заменяются нативными aapt/aapt2/zipalign.", en: "Downloaded from dl.google.com with sdkmanager. Needs OpenJDK (installed automatically). x86 build-tools binaries are replaced with native aapt/aapt2/zipalign." }, items: [
      { id: "platforms;android-37.1", kind: "sdk", ru: "Платформа Android 17 preview (API 37.1)", en: "Android 17 preview platform (API 37.1)", dru: "Canary-версия Android 17. Требуется --channel=3 в sdkmanager.", den: "Android 17 canary preview. Requires --channel=3 in sdkmanager." },
      { id: "platforms;android-37.0", kind: "sdk", ru: "Платформа Android 17 preview (API 37.0)", en: "Android 17 preview platform (API 37.0)", dru: "Ранний preview Android 17. Требуется --channel=3 в sdkmanager.", den: "Early Android 17 preview. Requires --channel=3 in sdkmanager." },
      { id: "platforms;android-36", kind: "sdk", ru: "Платформа Android 16 (API 36)", en: "Android 16 platform (API 36)", dru: "android.jar для компиляции под Android 16.", den: "android.jar for compiling against Android 16." },
      { id: "platforms;android-35", kind: "sdk", ru: "Платформа Android 15 (API 35)", en: "Android 15 platform (API 35)", dru: "android.jar для компиляции. Рекомендуется.", den: "android.jar for compilation. Recommended." },
      { id: "platforms;android-34", kind: "sdk", ru: "Платформа Android 14 (API 34)", en: "Android 14 platform (API 34)", dru: "android.jar для компиляции под Android 14.", den: "android.jar for compiling against Android 14." },
      { id: "build-tools;37.0.0", kind: "sdk", ru: "Build-tools 37.0.0", en: "Build-tools 37.0.0", dru: "Инструменты сборки для Android 17 preview (canary).", den: "Build tools for Android 17 preview (canary channel)." },
      { id: "build-tools;36.0.0", kind: "sdk", ru: "Build-tools 36.0.0", en: "Build-tools 36.0.0", dru: "Инструменты сборки для Android 16.", den: "Build tools for Android 16." },
      { id: "build-tools;35.0.0", kind: "sdk", ru: "Build-tools 35.0.0", en: "Build-tools 35.0.0", dru: "Нужны Gradle (d8, lib). Рекомендуется.", den: "Required by Gradle (d8, lib). Recommended." },
      { id: "build-tools;34.0.0", kind: "sdk", ru: "Build-tools 34.0.0", en: "Build-tools 34.0.0", dru: "Инструменты сборки для Android 14.", den: "Build tools for Android 14." }
    ] },
    { id: "ndk", ru: "Android NDK", en: "Android NDK", items: [
      { id: "ndk-sysroot", kind: "pkg", ru: "NDK sysroot", en: "NDK sysroot", dru: "Заголовки и библиотеки Android для clang.", den: "Android headers and libraries for clang." },
      { id: "ndk-multilib", kind: "pkg", ru: "NDK multilib", en: "NDK multilib", dru: "Библиотеки для arm, x86, x86_64.", den: "Libraries for arm, x86, x86_64." },
      { id: "ndk-full", kind: "ndk", ru: "Полный NDK (сборка Termux)", en: "Full NDK (Termux build)", dru: "Инструменты для нативных Android-сборок.", den: "ndk-build and CMake toolchain for Gradle. ~1 GB, from github.com/lzhiyong/termux-ndk.", verify: "ndk" }
    ] },
    { id: "flutter", ru: "Flutter & Dart", en: "Flutter & Dart", note: { ru: "Кроссплатформенный SDK для создания Android/Web-приложений. Автоматически настраивается для Android bionic через agy-fix-flutter.", en: "Cross-platform SDK for Android/Web apps. Automatically patched for Android bionic userspace via agy-fix-flutter." }, items: [
      { id: "flutter-sdk", kind: "flutter", ru: "Flutter SDK (stable)", en: "Flutter SDK (stable)", dru: "SDK для Flutter-приложений.", den: "Flutter SDK + Dart + bionic libc autopatch.", verify: "flutter,dart" }
    ] },
    { id: "lang", ru: "Другие языки", en: "Other languages", items: [
      { id: "rust", kind: "pkg", ru: "Rust (cargo)", en: "Rust (cargo)", dru: "Компилятор Rust и менеджер пакетов cargo.", den: "Rust compiler and cargo package manager.", verify: "rust" },
      { id: "golang", kind: "pkg", ru: "Go", en: "Go", dru: "Компилятор языка Go.", den: "Go language compiler.", verify: "go" }
    ] },
    { id: "util", ru: "Git и утилиты", en: "Git and utilities", items: [
      { id: "git", kind: "pkg", ru: "Git", en: "Git", dru: "Система контроля версий.", den: "Version control system.", verify: "git" },
      { id: "gh", kind: "pkg", ru: "GitHub CLI", en: "GitHub CLI", dru: "Управление репозиториями и релизами GitHub из терминала.", den: "Manage GitHub repositories and releases from the terminal." },
      { id: "openssh", kind: "pkg", ru: "OpenSSH", en: "OpenSSH", dru: "SSH-клиент и агент ключей для git и удалённых серверов.", den: "SSH client and key agent for git and remote servers." },
      { id: "openssl-tool", kind: "pkg", ru: "OpenSSL (openssl)", en: "OpenSSL (openssl)", dru: "Сертификаты, ключи подписи PKCS#12/PEM и криптография.", den: "Certificates, PKCS#12/PEM signing keys and cryptography.", verify: "openssl" },
      { id: "curl", kind: "pkg", ru: "curl", en: "curl", dru: "Загрузка файлов и HTTP-запросы из терминала.", den: "File downloads and HTTP requests from the terminal." },
      { id: "wget", kind: "pkg", ru: "wget", en: "wget", dru: "Рекурсивная загрузка файлов по HTTP/FTP.", den: "Recursive file downloads over HTTP/FTP." },
      { id: "jq", kind: "pkg", ru: "jq", en: "jq", dru: "Обработка и фильтрация JSON в терминале.", den: "JSON processing and filtering in the terminal." },
      { id: "ripgrep", kind: "pkg", ru: "ripgrep (rg)", en: "ripgrep (rg)", dru: "Быстрый рекурсивный поиск текста в файлах.", den: "Fast recursive text search across files." },
      { id: "fd", kind: "pkg", ru: "fd", en: "fd", dru: "Быстрый поиск файлов, замена find.", den: "Fast file search, modern replacement for find." },
      { id: "tree", kind: "pkg", ru: "tree", en: "tree", dru: "Отображение дерева файловой системы.", den: "Display directory tree in the terminal." }
    ] },
    { id: "archives", ru: "Архивы", en: "Archives", items: [
      { id: "zip", kind: "pkg", ru: "zip", en: "zip", dru: "Создание ZIP-архивов.", den: "Create ZIP archives." },
      { id: "unzip", kind: "pkg", ru: "unzip", en: "unzip", dru: "Распаковка ZIP-архивов.", den: "Extract ZIP archives." },
      { id: "7zip", kind: "pkg", ru: "7zip (7z, tar, gz, bz2, xz, iso)", en: "7zip (7z, tar, gz, bz2, xz, iso)", dru: "Основной пакет для открытия остальных форматов архивов.", den: "Main package for opening the remaining archive formats.", verify: "7z" },
      { id: "unrar", kind: "pkg", ru: "unrar (RAR)", en: "unrar (RAR)", dru: "Распаковка архивов RAR.", den: "Extracts RAR archives.", verify: "unrar" },
      { id: "zstd", kind: "pkg", ru: "zstd (.zst)", en: "zstd (.zst)", dru: "Сжатие и распаковка .zst.", den: "Compresses and extracts .zst.", verify: "zstd" },
      { id: "lz4", kind: "pkg", ru: "lz4", en: "lz4", dru: "Сжатие .lz4.", den: "Compresses .lz4.", verify: "lz4" },
      { id: "lhasa", kind: "pkg", ru: "lhasa (.lzh)", en: "lhasa (.lzh)", dru: "Архивы LHA/LZH.", den: "LHA/LZH archives.", verify: "lha" },
      { id: "lrzip", kind: "pkg", ru: "lrzip (.lrz)", en: "lrzip (.lrz)", dru: "Долгое сжатие .lrz.", den: "Long-range .lrz compression.", verify: "lrzip" }
    ] }
  ];
  var PRESETS = [
    { id: "plugins", ru: "Плагины приложения", en: "App plugins", dru: "Node.js LTS, Python, clang, make, openssl", den: "Node.js LTS, Python, clang, make, openssl",
      items: ["nodejs-lts", "python", "clang", "make", "pkg-config", "openssl-tool"] },
    { id: "apk", ru: "Android-приложение (Gradle)", en: "Android app (Gradle)", dru: "OpenJDK 17, Gradle, Kotlin, aapt2, d8, apksigner, apktool, jadx, openssl, SDK 35", den: "OpenJDK 17, Gradle, Kotlin, aapt2, d8, apksigner, apktool, jadx, openssl, SDK 35",
      items: ["openjdk-17", "gradle", "kotlin", "aapt", "aapt2", "d8", "apksigner", "apktool", "jadx", "openssl-tool", "zip", "unzip", "android-tools", "platforms;android-35", "build-tools;35.0.0"] },
    { id: "native", ru: "Нативный код (NDK)", en: "Native code (NDK)", dru: "clang, CMake, Ninja, NDK sysroot/multilib", den: "clang, CMake, Ninja, NDK sysroot/multilib",
      items: ["clang", "lld", "cmake", "ninja", "make", "ndk-sysroot", "ndk-multilib"] }
  ];
  var ITEMS = {};
  GROUPS.forEach(function (g) { g.items.forEach(function (it) { it.group = g.id; ITEMS[it.id] = it; }); });

  /* ------------------------------------------------------------ state */
  var host = null, root = null;
  var status = {};          // id -> {avail, inst}
  var special = { cmdline: false, platforms: {}, buildtools: {}, ndk: [], flutter: false };
  var checks = {};          // verify name -> {ok, text}
  var selected = {};
  var versionOpen = {};
  var batchLog = "";
  var job = null;           // {id, op, label, log, rc}
  var queue = [];
  var logOpen = false;
  var loaded = false;

  function bridge() { return window.AgyTools && typeof window.AgyTools.start === "function" ? window.AgyTools : null; }

  function installed(it) {
    if (it.kind === "pkg") { var s = status[it.id]; return !!(s && s.inst && s.inst !== "-"); }
    if (it.kind === "sdk") { var p = it.id.split(";"); return (p[0] === "platforms" ? special.platforms[p[1]] : special.buildtools[p[1]]) === true; }
    if (it.kind === "ndk") return special.ndk.length > 0;
    if (it.kind === "flutter") return !!special.flutter;
    if (it.kind === "npm") { var n = status["npm:" + it.id]; return !!(n && n.inst); }
    return false;
  }
  function availability(it) {
    if (it.kind !== "pkg") return true;
    var s = status[it.id];
    return !hasIndex || !s || s.avail !== "-";
  }

  /* ------------------------------------------------------------ jobs */
  function run(op, arg, label, after, continueOnFailure) {
    queue.push({ op: op, arg: arg || "", label: label, after: after, continueOnFailure: !!continueOnFailure });
    if (!job) next();
    render();
  }
  function next() {
    var q = queue.shift();
    if (!q) { job = null; render(); return; }
    var b = bridge();
    if (!b) { job = { op: q.op, label: q.label, log: T("Нативный мост AgyTools недоступен.", "Native AgyTools bridge is not available."), rc: "1", after: q.after, continueOnFailure: q.continueOnFailure }; finish(); return; }
    var id = b.start(q.op, q.arg);
    if (!id || /^ERR/.test(id)) {
      job = { op: q.op, label: q.label, log: T("Не удалось запустить: ", "Could not start: ") + String(id), rc: "1", after: q.after, continueOnFailure: q.continueOnFailure };
      finish();
      return;
    }
    job = { id: id, op: q.op, arg: q.arg, label: q.label, log: "", rc: "", after: q.after, continueOnFailure: q.continueOnFailure, t0: Date.now() };
    lastLogChange = Date.now();
    store("agyToolsJob", JSON.stringify({ id: id, op: q.op, arg: q.arg, label: q.label, t0: job.t0 }));

    poll();
  }
  var pollTimer = 0;
  var lastLogChange = 0;
  function poll() {
    clearTimeout(pollTimer);
    if (!job || !job.id) return;
    var b = bridge(); if (!b) return;
    var r = {};
    try { r = JSON.parse(b.read(job.id) || "{}"); } catch (e) {}
    var prevLen = (job.log || "").length;
    job.log = r.log || job.log || "";
    if (job.log.length !== prevLen) lastLogChange = Date.now();
    if (r.rc !== undefined && r.rc !== "") { job.rc = r.rc; finish(); return; }
    var now = Date.now();
    var jobAge = job.t0 ? (now - job.t0) : 0;
    var stallTime = lastLogChange ? (now - lastLogChange) : jobAge;
    // Silent package and SDK operations may take minutes. A UI-only timeout
    // cannot stop the native process and must not start the next queued job.
    renderLog();
    pollTimer = setTimeout(poll, job.op === "status" ? 400 : 700);
  }
  function finish() {
    var j = job;
    store("agyToolsJob", null);
    parse(j);
    if (j.rc !== "0" && !QUIET[j.op] && !j.continueOnFailure) {
      // Stop subsequent changes; still refresh the actual installed state.
      queue = queue.filter(function (q) { return q.op === "status"; });
    }
    if ((j.op !== "status" && j.op !== "verify") || j.rc !== "0") {
      j.done = true;
      if (hiddenJob !== j || j.rc !== "0") lastDone = j;
      if (j.rc !== "0") logOpen = true;
    }
    if (hiddenJob === j) hiddenJob = null;
    if (typeof j.after === "function") { try { j.after(j); } catch (e) {} }
    job = null;
    next();
    render();
  }
  var lastDone = null, hiddenJob = null;

  function parse(j) {
    if (j.op === "status") special = { cmdline: false, platforms: {}, buildtools: {}, ndk: [], flutter: false };
    (j.log || "").split("\n").forEach(function (line) {
      var m;
      if ((m = /^@@pkg (\S+) (\S+) (\S+)/.exec(line))) status[m[1]] = { avail: m[2], inst: m[3] };
      else if ((m = /^@@special cmdline-tools (\S+)/.exec(line))) special.cmdline = m[1] === "ok";
      else if ((m = /^@@special platform (\S+)(?: (\S+))?/.exec(line))) special.platforms[m[1]] = m[2] === "incomplete" ? "incomplete" : true;
      else if ((m = /^@@special build-tools (\S+)(?: (\S+))?/.exec(line))) special.buildtools[m[1]] = m[2] === "incomplete" ? "incomplete" : true;
      else if ((m = /^@@special ndk (\S+)/.exec(line))) { if (special.ndk.indexOf(m[1]) < 0) special.ndk.push(m[1]); }
      else if ((m = /^@@special flutter (\S+)/.exec(line))) special.flutter = m[1] === "ok";
      else if ((m = /^@@(ok|fail) (\S+) ?(.*)$/.exec(line))) checks[m[2]] = { ok: m[1] === "ok", text: m[3] };
      else if ((m = /^@@npm (\S+) (\S+)/.exec(line))) status["npm:" + m[1]] = { inst: m[2] !== "-" };
      else if ((m = /^@@index (\S+)/.exec(line))) hasIndex = m[1] === "ok";
    });
    saveCache();
  }
  var hasIndex = true;
  function saveCache() {
    store("agyToolsCache", JSON.stringify({ t: Date.now(), status: status, special: special, checks: checks, hasIndex: hasIndex }));
  }
  function loadCache() {
    var c = null;
    try { c = JSON.parse(store("agyToolsCache") || "null"); } catch (e) {}
    if (!c) return false;
    status = c.status || {}; special = c.special || special; checks = c.checks || {};
    hasIndex = c.hasIndex !== false || Object.keys(status).length > 0;
    loaded = true;
    return true;
  }

  function refresh(withVerify, afterStatus) {
    var names = [];
    GROUPS.forEach(function (g) { g.items.forEach(function (it) { if (it.kind === "pkg") names.push(it.id); }); });
    run("status", names.join(","), T("Обновление состояния", "Refreshing status"), function () {
      loaded = true;
      if (afterStatus) afterStatus();
      if (!withVerify) return;
      var v = [];
      GROUPS.forEach(function (g) { g.items.forEach(function (it) { if (it.verify && installed(it)) v = v.concat(it.verify.split(",")); }); });
      v = v.filter(function (x, i) { return v.indexOf(x) === i; });
      if (v.length) run("verify", v.join(","), T("Самопроверка", "Self-test"));
    });
  }

  function nodeConflict(ids) {
    var wantLts = ids.indexOf("nodejs-lts") >= 0, wantCurrent = ids.indexOf("nodejs") >= 0;
    if (wantLts && (wantCurrent || installed(ITEMS.nodejs))) return T("Чтобы установить Node.js LTS, сначала удалите другую версию Node.js и снимите её выбор. Версии используют общие файлы npm.", "To install Node.js LTS, remove the other Node.js version and deselect it first. Both versions share npm files.");
    if (wantCurrent && installed(ITEMS["nodejs-lts"])) return T("Чтобы установить другую версию Node.js, сначала удалите Node.js LTS. Версии используют общие файлы npm.", "To install the other Node.js version, remove Node.js LTS first. Both versions share npm files.");
    return "";
  }
  function installIds(ids) {
    var conflict = nodeConflict(ids); if (conflict) { alert(conflict); return; }
    batchLog = ""; logOpen = true;
    var pk = [], sdk = [], npm = [], ndk = false, flutter = false;
    var failures = [];
    function recordFailure(j) {
      if (!j) return;
      batchLog += "\n== " + (j.label || j.op) + "\n" + (j.log || "") + "\n";
      if (String(j.rc) === "0") return;
      failures.push((j.label || j.op) + "\n" + (j.log || T("Ошибка запуска", "Failed to start")));
    }
    ids.forEach(function (id) {
      var it = ITEMS[id]; if (!it) return;
      if (it.kind === "pkg") { if (availability(it)) pk.push(id); }
      else if (it.kind === "sdk") sdk.push(id);
      else if (it.kind === "npm") npm.push(id);
      else if (it.kind === "ndk") ndk = true;
      else if (it.kind === "flutter") flutter = true;
    });
    if (pk.length) run("install", pk.join(" "), T("Установка: ", "Install: ") + pk.join(", "), recordFailure, true);
    if (npm.length) run("npm", npm.join(" "), "npm -g " + npm.join(" "), recordFailure, true);
    if (sdk.length) run("sdk", sdk.join(" "), "sdkmanager " + sdk.join(" "), recordFailure, true);
    if (ndk) run("ndk", "", T("Полный NDK", "Full NDK"), recordFailure, true);
    if (flutter) run("flutter", "", T("Flutter SDK", "Flutter SDK"), recordFailure, true);
    refresh(true, function () {
      if (batchLog) {
        lastDone = {op: "install", label: failures.length ? T("Ошибки установки", "Installation errors") : T("Установка завершена", "Installation complete"), rc: failures.length ? "1" : "0", log: batchLog};
        logOpen = true;
      }
    });
  }
  function removeId(id) {
    var it = ITEMS[id]; if (!it) return;
    if (it.kind === "pkg") run("remove", id, T("Удаление: ", "Remove: ") + id);
    else if (it.kind === "sdk") run("sdkremove", id, T("Удаление: ", "Remove: ") + id);
    else if (it.kind === "ndk") run("ndkremove", "", T("Удаление NDK", "Remove NDK"));
    else if (it.kind === "flutter") run("flutterremove", "", T("Удаление Flutter SDK", "Remove Flutter SDK"));
    else return;
    refresh(true);
  }

  /* ------------------------------------------------------------ render */
  function verified(it) {
    if (!installed(it)) return false;
    if (!it.verify) return true;
    return it.verify.split(",").every(function (v) { return checks[v] && checks[v].ok; });
  }
  function needsPresetInstall(it) {
    if (!installed(it)) return true;
    return !!(it.verify && it.verify.split(",").some(function (v) { return checks[v] && !checks[v].ok; }));
  }
  function badge(it) {
    if (job && job.arg && (" " + job.arg.replace(/,/g, " ") + " ").indexOf(" " + it.id + " ") >= 0 && /install|sdk|npm/.test(job.op))
      return '<span class="agy-t-badge run">' + esc(T("Устанавливается…", "Installing…")) + "</span>";
    if (it.kind === "pkg") {
      var s = status[it.id];
      if (!loaded || !s) return '<span class="agy-t-badge">…</span>';
      if (s.inst !== "-" && it.verify && it.verify.split(",").some(function (v) { return checks[v] && !checks[v].ok; })) return '<span class="agy-t-badge off">' + esc(T("Ошибка проверки", "Check failed")) + "</span>";
      if (s.inst !== "-") return '<span class="agy-t-badge ok">' + esc(T("Установлено ", "Installed ") + s.inst) + "</span>";
      if (s.avail === "-") return '<span class="agy-t-badge off">' + esc(T("Нет в репозитории", "Not in repository")) + "</span>";
      return '<span class="agy-t-badge">' + esc(T("Доступно ", "Available ") + s.avail) + "</span>";
    }
    if (!loaded) return '<span class="agy-t-badge">…</span>';
    if (it.kind === "sdk") { var p = it.id.split(";"); if ((p[0] === "platforms" ? special.platforms[p[1]] : special.buildtools[p[1]]) === "incomplete") return '<span class="agy-t-badge off">' + esc(T("Не хватает файлов", "Missing files")) + '</span>'; }
    return installed(it) ? '<span class="agy-t-badge ok">' + esc(T("Установлено", "Installed")) + "</span>"
                         : '<span class="agy-t-badge">' + esc(T("Не установлено", "Not installed")) + "</span>";
  }
  function checkLine(it) {
    if (!it.verify || !installed(it)) return "";
    var failed = it.verify.split(",").some(function(v) { return checks[v] && !checks[v].ok; });
    return failed ? '<div class="agy-t-check bad">' + esc(T("Ошибка проверки — откройте журнал", "Check failed — open the log")) + '</div>' : "";
  }
  var VERSION_GROUPS = {
    node: [{title: ["Node.js", "Node.js"], ids: ["nodejs-lts", "nodejs"]}],
    java: [{title: ["OpenJDK", "OpenJDK"], ids: ["openjdk-17", "openjdk-21"]}],
    sdk: [{title: ["Платформа Android", "Android platform"], ids: ["platforms;android-37.1", "platforms;android-37.0", "platforms;android-36", "platforms;android-35", "platforms;android-34"]},
          {title: ["Android Build-tools", "Android Build-tools"], ids: ["build-tools;37.0.0", "build-tools;36.0.0", "build-tools;35.0.0", "build-tools;34.0.0"]}]
  };

  function render() {
    if (!root || !root.isConnected) return;
    var busy = !!job || queue.length > 0;
    var nsel = Object.keys(selected).filter(function (k) { return selected[k]; }).length;
    var h = '<div class="agy-t-head"><div style="display:flex;align-items:center;justify-content:space-between;gap:12px"><div class="agy-t-title">' + esc(T("Инструменты", "Tools")) + '</div><button type="button" class="agy-t-btn sec" data-act="tools-menu" aria-label="' + esc(T("Меню инструментов", "Tools menu")) + '">☰</button></div>' +
      '<div class="agy-t-sub">' + esc(T("Компоненты для разработки прямо в приложении: Node.js для плагинов, Java, Android SDK/NDK, компиляторы. Устанавливаются в окружение агента и сразу доступны ему.", "Development components inside the app: Node.js for plugins, Java, Android SDK/NDK, compilers. Installed into the agent environment and available to it right away.")) + "</div>" +
      '<div class="agy-t-actions"><button type="button" data-act="refresh"' + (busy ? " disabled" : "") + ">" + esc(T("Проверить", "Check")) + "</button>" +
      '<button type="button" data-act="upgrade"' + (busy ? " disabled" : "") + ">" + esc(T("Обновить всё", "Upgrade all")) + "</button>" +
      '<button type="button" data-act="selftest-save"' + (busy ? " disabled" : "") + ">" + esc(T("Тест сохранения", "Save test")) + "</button></div></div>"; /* AGY-P1-5-SELFTEST */

    h += '<div class="agy-t-job" hidden>' +
      '<div class="agy-t-jtop"><span class="agy-t-jicon"></span><span class="agy-t-jlabel"></span><span class="agy-t-jpct"></span><button type="button" class="agy-t-jcancel" data-act="cancel-job" title="' + esc(T("Закрыть окно", "Close panel")) + '">✕</button></div>' +
      '<div class="agy-t-pbar"><div class="agy-t-pfill"></div></div>' +
      '<div class="agy-t-jrow"><span class="agy-t-jphase"></span><span class="agy-t-jtime"></span></div>' +
      '<div class="agy-t-jfacts"></div>' +
      '<div class="agy-t-jrow"><span class="agy-t-jtail"></span><button type="button" class="agy-t-jlog" data-act="log"></button><button type="button" data-act="copy-log">' + esc(T("Копировать", "Copy")) + '</button></div>' +
      '<pre class="agy-t-log" hidden></pre></div>';
    if (loaded && !hasIndex && Object.keys(status).length === 0) h += '<div class="agy-t-warn">' + esc(T("Список пакетов ещё не загружен — состояние неполное.", "Package list is not downloaded yet — status is incomplete.")) +
      ' <button type="button" class="agy-t-btn" data-act="index"' + (busy ? " disabled" : "") + ">" + esc(T("Загрузить", "Download")) + "</button></div>";
    if (!bridge()) h += '<div class="agy-t-warn">' + esc(T("Нативный мост недоступен в этой сборке.", "Native bridge is not available in this build.")) + "</div>";

    h += '<div class="agy-t-sec">' + esc(T("Готовые наборы", "Presets")) + "</div>";
    PRESETS.forEach(function (p) {
      var all = p.items.every(function (id) { var it = ITEMS[id]; return it && !needsPresetInstall(it); });
      var pending = p.items.filter(function (id) { var it = ITEMS[id]; return it && availability(it) && needsPresetInstall(it); }).length;
      h += '<div class="agy-t-card"><div class="agy-t-main"><div class="agy-t-name">' + esc(T(p.ru, p.en)) + '</div><div class="agy-t-desc">' + esc(T(p.dru, p.den)) + ' · ' + esc(T("В наборе: ", "In preset: ") + p.items.length) + (loaded && !busy && pending ? ' · ' + esc(T("К установке: ", "To install: ") + pending) : '') + "</div></div>" +
        (all ? '<span class="agy-t-badge ok">' + esc(T("Готово", "Ready")) + "</span>"
             : '<button type="button" class="agy-t-btn" data-preset="' + p.id + '"' + (busy ? " disabled" : "") + ">" + esc(T("Установить", "Install")) + "</button>") + "</div>";
    });

    GROUPS.forEach(function (g) {
      h += '<div class="agy-t-sec">' + esc(T(g.ru, g.en)) + "</div>";
      if (g.id === "sdk") h += '<div class="agy-t-note">' + esc(T("Платформы и инструменты сборки Android.", "Android platforms and build tools.")) + "</div>";
      if (g.id === "flutter") h += '<div class="agy-t-note">' + esc(T("SDK для разработки Flutter-приложений.", "SDK for Flutter development.")) + "</div>";
      h += '<div class="agy-t-group">';
      function renderItem(it) {
        var inst = installed(it), av = availability(it);
        h += '<div class="agy-t-row">' +
          '<label class="agy-t-chk"><input type="checkbox" data-sel="' + esc(it.id) + '"' + (selected[it.id] ? " checked" : "") + (inst || !av || busy ? " disabled" : "") + "></label>" +
          '<div class="agy-t-main"><div class="agy-t-name">' + esc(T(it.ru, it.en)) + " " + badge(it) + "</div>" +
          (T(it.dru, it.den) ? '<div class="agy-t-desc">' + esc(T(it.dru, it.den)) + "</div>" : "") + checkLine(it) + "</div>" +
          (inst
            ? ((it.verify && it.verify.split(",").some(function(v) { return checks[v] && !checks[v].ok; })) ? '<button type="button" class="agy-t-btn" data-in="' + esc(it.id) + '"' + (busy ? " disabled" : "") + ">" + esc(T("Починить", "Repair")) + "</button>" : (it.kind !== "npm" ? '<button type="button" class="agy-t-btn sec" data-rm="' + esc(it.id) + '"' + (busy ? " disabled" : "") + ">" + esc(T("Удалить", "Remove")) + "</button>" : ""))
            : (!inst && av ? '<button type="button" class="agy-t-btn" data-in="' + esc(it.id) + '"' + (busy ? " disabled" : "") + ">" + esc(T("Установить", "Install")) + "</button>" : "")) +
          "</div>";
      }
      var rendered = {};
      g.items.forEach(function(it) {
        var groups = VERSION_GROUPS[g.id] || [];
        var vg = groups.filter(function(x) { return x.ids.indexOf(it.id) >= 0; })[0];
        if (!vg) { renderItem(it); return; }
        var key = g.id + ":" + vg.title[1];
        if (rendered[key]) return;
        rendered[key] = true;
        h += '<div class="agy-t-versions"><div class="agy-t-row"><div class="agy-t-main"><div class="agy-t-name">' + esc(T(vg.title[0], vg.title[1])) + '</div><div class="agy-t-desc">' + esc(T("Выбор версии", "Choose version")) + '</div></div>' +
          '<button type="button" class="agy-t-btn sec" data-version-toggle="' + esc(key) + '" aria-expanded="' + (versionOpen[key] ? 'true' : 'false') + '">' + esc(versionOpen[key] ? T("Скрыть ▲", "Hide ▲") : T("Версии ▼", "Versions ▼")) + '</button></div>';
        if (versionOpen[key]) vg.ids.forEach(function(id) { if (ITEMS[id]) renderItem(ITEMS[id]); });
        h += '</div>';
      });
      h += "</div>";
    });

    h += '<div class="agy-t-bar">' +
      '<button type="button" class="agy-t-btn" data-act="install-sel"' + (!nsel || busy ? " disabled" : "") + ">" + esc(T("Установить выбранные", "Install selected") + (nsel ? " (" + nsel + ")" : "")) + "</button>" +
      "</div>";
    root.innerHTML = h;
    renderLog();
  }
  var QUIET = { status: 1, verify: 1 };
  // Log text: drop machine lines and curl "####" bars; keep the last state of \r-lines.
  function cleanLog(raw) {
    return (raw || "").split("\n").map(function (l) { var p = l.split("\r"); while (p.length && !p[p.length - 1].trim()) p.pop(); return p.pop() || ""; })
      .map(function (l) { return l.replace(/^@@fail\s+/, "Ошибка: ").replace(/^@@error\s+/, "Ошибка: "); })
      .filter(function (l) { return !/^@@/.test(l) && !/^[#\s]*(\d{1,3}(?:[.,]\d+)?%?)?\s*$/.test(l) && !/^#{3,}/.test(l); }).join("\n");
  }
  // Progress model from pkg / curl / sdkmanager output.
  function progress(j) {
    var raw = j.log || "", r = { pct: -1, phase: "", facts: [] };
    // Each pkg invocation reports its own package list and counters. In
    // particular npm is installed in a second invocation after Node.js.
    // Never combine the first list with Setting up lines from later runs.
    var pkgStage = "";
    if (/install|upgrade/.test(j.op)) {
      var stages = Array.from(raw.matchAll(/^== pkg (?:install|upgrade)\b[^\r\n]*/gm));
      if (stages.length) {
        var latestStage = stages[stages.length - 1];
        pkgStage = latestStage[0].slice(3);
        raw = raw.slice(latestStage.index);
      }
      var lists = Array.from(raw.matchAll(/^The following NEW packages will be installed:\s*$/gm));
      if (lists.length) raw = raw.slice(lists[lists.length - 1].index);
    }
    var mNew = /The following NEW packages will be installed:\n([\s\S]*?)\n(?:Need to get|\S)/.exec(raw);
    var names = mNew ? mNew[1].trim().split(/\s+/) : [];
    var total = names.length;
    var size = (/Need to get ([^\n]+?) of archives/.exec(raw) || [])[1];
    var gets = (raw.match(/^Get:\d+ /gm) || []).length;
    var sets = raw.match(/^Setting up (\S+)/gm) || [];
    var pcts = raw.match(/\d{1,3}(?:[.,]\d+)?%/g) || [];
    var cur = pcts.length ? parseFloat(pcts[pcts.length - 1].replace(",", ".")) : 0;
    if (/install|upgrade/.test(j.op) && total) {
      var dl = Math.max(0, gets - 1) + (gets ? Math.min(1, cur / 100) : 0);
      r.pct = Math.min(99, Math.round((dl / total) * 50 + (sets.length / total) * 50));
      var lastName = sets.length ? sets[sets.length - 1].replace(/^Setting up /, "") : "";
      r.phase = sets.length >= gets && gets
        ? T("Установлено ", "Installed ") + Math.min(sets.length, total) + T(" из ", " of ") + total + (lastName ? " · " + lastName : "")
        : T("Загрузка ", "Downloading ") + Math.min(Math.max(gets, 1), total) + T(" из ", " of ") + total + (cur ? " · " + Math.round(cur) + "%" : "");
      if (pkgStage === "pkg install npm") r.phase = "npm · " + r.phase;
      r.facts.push(T("Пакетов: ", "Packages: ") + total + (size ? T(" · объём ", " · size ") + size : ""));
    } else if (/sdk|ndk|npm|flutter/.test(j.op) && pcts.length) {
      r.pct = Math.min(99, Math.round(cur));
      r.phase = T("Загрузка · ", "Downloading · ") + Math.round(cur) + "%";
    } else if (/^== pkg update/m.test(raw) && !/Reading package lists/.test(raw)) {
      r.phase = T("Загрузка списка пакетов…", "Downloading package list…");
    } else if (/Reading package lists/.test(raw) && !total && j.op === "install") {
      r.phase = T("Подготовка…", "Preparing…");
    }
    var steps = raw.match(/^== .+$/gm);
    if (!r.phase && steps) r.phase = steps[steps.length - 1].slice(3);
    if (/^(sdk|npm)$/.test(j.op) && j.arg) {
      var requested = j.arg.trim().split(/\s+/).filter(Boolean).length;
      if (requested) r.facts.push(T("Компонентов на этом этапе: ", "Components in this stage: ") + requested);
    } else if (/^(ndk|flutter)$/.test(j.op)) {
      r.facts.push(T("Компонентов на этом этапе: 1", "Components in this stage: 1"));
    }
    return r;
  }
  function elapsed(j) {
    if (!j.t0) return "";
    var s = Math.round((Date.now() - j.t0) / 1000);
    return (s >= 60 ? Math.floor(s / 60) + T(" мин ", " min ") : "") + (s % 60) + T(" с", " s");
  }
  var tick = 0;
  function renderLog() {
    if (!root || !root.isConnected) return;
    var panel = root.querySelector(".agy-t-job");
    if (!panel) return;
    var j = job && !QUIET[job.op] ? (hiddenJob === job ? null : job) : lastDone;
    if (!j) { panel.hidden = true; return; }
    panel.hidden = false;
    var checking = !!(job && job.op === "verify" && j === lastDone && j.rc === "0");
    var running = j === job || checking;
    var ok = !running && j.rc === "0";
    panel.className = "agy-t-job" + (running ? " run" : ok ? " ok" : " bad");
    var pr = running ? progress(j) : { pct: ok ? 100 : -1, phase: "", facts: [] };
    tick = (tick + 1) % 4;
    panel.querySelector(".agy-t-jicon").textContent = running ? ["◐", "◓", "◑", "◒"][tick] : ok ? "✓" : "✗";
    panel.querySelector(".agy-t-jlabel").textContent = j.label;
    panel.querySelector(".agy-t-jpct").textContent = running && pr.pct >= 0 ? pr.pct + "%" : "";
    panel.querySelector(".agy-t-jphase").textContent = checking ? T("Проверка компонентов…", "Checking components…") : running ? (pr.phase || T("Выполняется…", "Running…"))
      : ok ? T("Готово", "Done") : T("Ошибка — откройте журнал", "Failed — open the log");
    panel.querySelector(".agy-t-jtime").textContent = running ? elapsed(j) + (queue.filter(function (q) { return !QUIET[q.op]; }).length ? T(" · этапов в очереди: ", " · stages queued: ") + queue.filter(function (q) { return !QUIET[q.op]; }).length : "") : "";
    panel.querySelector(".agy-t-jfacts").textContent = pr.facts.join("  ");
    var bar = panel.querySelector(".agy-t-pbar"), fill = panel.querySelector(".agy-t-pfill");
    bar.hidden = !running && !ok;
    fill.style.width = (pr.pct >= 0 ? Math.max(3, pr.pct) : 3) + "%";
    var text = cleanLog((j === job && batchLog ? batchLog + "\n== " + j.label + "\n" : "") + j.log);
    var lines = text.split("\n").filter(function (l) { return l.trim(); });
    panel.querySelector(".agy-t-jtail").textContent = logOpen ? "" : (lines[lines.length - 1] || "");
    panel.querySelector(".agy-t-jlog").textContent = logOpen ? T("Скрыть журнал", "Hide log") : T("Журнал", "Log");
    var pre = panel.querySelector(".agy-t-log");
    pre.hidden = !logOpen;
    if (logOpen) {
      var stick = pre.scrollTop + pre.clientHeight >= pre.scrollHeight - 20;
      pre.textContent = text.slice(-20000) || T("(пока пусто)", "(empty so far)");
      if (stick) pre.scrollTop = pre.scrollHeight;
    }
  }

  /* AGY-P2-11: локальное уведомление (глобального toast нет в этом бандле) */
  function agyToast11(msg){ try { var d=document.createElement("div"); d.textContent=msg; d.style.cssText="position:fixed;left:12px;right:12px;bottom:24px;z-index:999999;background:#222;color:#fff;padding:12px 14px;border-radius:10px;font-size:14px;line-height:1.4;"; document.body.appendChild(d); setTimeout(function(){ try{d.remove();}catch(e){} },6000); } catch(e){ try{alert(msg);}catch(e2){} } }
  /* AGY-P1-5-SELFTEST: диагностика нативного сохранения файлов */
  function selftestSave15() {
    var txt = "AGY selftest " + new Date().toISOString() + "\nЕсли вы видите этот файл в Загрузках — нативный экспорт работает.\n";
    var blob = new Blob([txt], { type: "text/plain" });
    var fr = new FileReader();
    fr.onload = function () {
      var s = String(fr.result || ""); var i = s.indexOf(",");
      var b64 = i >= 0 ? s.slice(i + 1) : s;
      var a = (window.AndroidBridge && window.AndroidBridge.saveBlob) ? window.AndroidBridge : (window.Android && window.Android.saveBlob ? window.Android : null);
      var tok = window.__AG_NATIVE_BRIDGE_TOKEN__ || (function () { try { return localStorage.getItem("agy_bridge_token") || null; } catch (e) { return null; } })();
      if (!a || !tok) { alert("Мост недоступен: saveBlob=" + (!!a) + ", токен=" + (!!tok)); return; }
      try {
        a.saveBlob(tok, b64, "agy-selftest.txt", "text/plain");
        alert("saveBlob вызван. Файл agy-selftest.txt должен появиться в Загрузках.");
      } catch (e) { alert("Ошибка saveBlob: " + e); }
    };
    fr.onerror = function () { alert("FileReader failed"); };
    fr.readAsDataURL(blob);
  }
  function onClick(e) {
    var b = e.target.closest("button,input"); if (!b || b.disabled) return;
    var toggle = b.getAttribute("data-version-toggle");
    if (toggle) { versionOpen[toggle] = !versionOpen[toggle]; render(); return; }
    if (b.matches("input[data-sel]")) {
      var selectedId = b.getAttribute("data-sel");
      var proposed = Object.keys(selected).filter(function(k) { return selected[k] && k !== selectedId; });
      if (b.checked) proposed.push(selectedId);
      var conflict = nodeConflict(proposed);
      if (conflict) { b.checked = false; alert(conflict); return; }
      selected[selectedId] = b.checked; render(); return;
    }
    var act = b.getAttribute("data-act");
    if (act === "tools-menu") openToolsMenu();
    else if (act === "selftest-save") { try { selftestSave15(); } catch (e15) { alert("selftest error: " + e15); } } /* AGY-P1-5-SELFTEST */
    else if (act === "refresh") refresh(true);
    /* AGY-P2-11: предпоказ объёма и подтверждение перед pkg upgrade */
    else if (act === "upgrade") {
      var b11 = bridge();
      var doUpgrade = function () { run("upgrade", "", T("Обновление пакетов", "Upgrading packages")); refresh(true); };
      if (!b11 || !b11.start) { doUpgrade(); return; }
      var statsId = b11.start("pkgstats", "");
      if (!statsId || /^ERR/.test(statsId)) { doUpgrade(); return; }
      var poll11 = function (tries) {
        var raw = "";
        try { raw = b11.read(statsId) || ""; } catch (_) {}
        var res = {};
        try { res = JSON.parse(raw) || {}; } catch (_) {}
        if (res.rc === undefined || res.rc === "") {
          if (tries > 600) { doUpgrade(); return; }
          setTimeout(function () { poll11(tries + 1); }, 150);
          return;
        }
        var n = parseInt(res.count, 10);
        var mb = Math.round((parseInt(res.bytes, 10) || 0) / 1048576);
        var msg;
        if (res.error || isNaN(n)) {
          msg = T("Обновление пакетов может занять 10+ минут и десятки МБ. Продолжить?", "Upgrading packages may take 10+ minutes and tens of MB. Continue?");
        } else if (n === 0) {
          agyToast11(T("Обновления не требуются: все пакеты актуальны.", "Nothing to upgrade: all packages are up to date."));
          return;
        } else {
          msg = T("Будет обновлено пакетов: ", "Packages to upgrade: ") + n + (mb > 0 ? ("\n" + T("Объём загрузки: ~", "Download size: ~") + mb + " МиБ") : "") + "\n\n" + T("Это может занять 10+ минут. Продолжить?", "This may take 10+ minutes. Continue?");
        }
        if (confirm(msg)) doUpgrade();
      };
      poll11(0);
    }
    else if (act === "install-sel") { var ids = Object.keys(selected).filter(function (k) { return selected[k]; }); selected = {}; installIds(ids); }
    else if (act === "index") { run("index", "", T("Загрузка списка пакетов", "Downloading package list")); refresh(false); }
    else if (act === "log") { logOpen = !logOpen; renderLog(); }
    else if (act === "copy-log") {
      var shown = job && !QUIET[job.op] ? job : lastDone;
      var txt = shown ? cleanLog(shown.log || "") : "";
      if (!txt) return;
      /* AGY-P2-11: clipboard API first, execCommand fallback */
      var ok11 = function () { b.textContent = T("Скопировано", "Copied"); };
      var fail11 = function () { logOpen = true; renderLog(); alert(T("Не удалось скопировать. Выделите текст журнала вручную.", "Copy failed. Select the log text manually.")); };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(txt).then(ok11, function () {
          var area = document.createElement("textarea"); area.value = txt;
          area.setAttribute("readonly", ""); area.style.position = "fixed"; area.style.left = "-9999px";
          document.body.appendChild(area); area.select();
          var copied = false; try { copied = document.execCommand("copy"); } catch (_) {}
          area.remove();
          if (copied) ok11(); else fail11();
        });
      } else { fail11(); }
    }
    else if (act === "cancel-job") {
      // Closing the panel must not cancel a running operation or its follow-up checks.
      if (job && !QUIET[job.op]) hiddenJob = job;
      else lastDone = null;
      logOpen = false;
      render();
    }
    else if (b.getAttribute("data-preset")) {
      var p = PRESETS.filter(function (x) { return x.id === b.getAttribute("data-preset"); })[0];
      if (p) installIds(p.items.filter(function (id) { return ITEMS[id] && needsPresetInstall(ITEMS[id]); }));
    }
    else if (b.getAttribute("data-in")) installIds([b.getAttribute("data-in")]);
    else if (b.getAttribute("data-rm")) removeId(b.getAttribute("data-rm"));
  }

  var termJobId = null, termTimer = null, modal = null, historyText = "";
  var scroll21List = [];
  function closeToolsModal() {
    if (modal && modal.__agyUnlockScroll) { try { modal.__agyUnlockScroll(); } catch (_) {} }
    if (modal) modal.remove(); modal = null;
    if (termTimer) clearTimeout(termTimer); termTimer = null;
    scroll21List.forEach(function (fn) { try { if (fn && fn.__off) fn.__off(); } catch (_) {} });
    scroll21List.length = 0;
  }
  function modalBox(title, body) {
    closeToolsModal();
    modal = document.createElement("div");
    modal.style.cssText = "position:fixed;inset:0;z-index:2147483000;background:rgba(0,0,0,.72);display:flex;align-items:center;justify-content:center;padding:16px";
    modal.innerHTML = '<div data-card style="box-sizing:border-box;background:#1c1c1e;color:#eee;border:1px solid #555;border-radius:16px;padding:16px;width:min(100%,680px);max-height:88vh;overflow:hidden;display:flex;flex-direction:column"><div style="display:flex;justify-content:space-between;align-items:center;gap:10px"><strong>' + esc(title) + '</strong><button type="button" data-modal="close">✕</button></div>' + body + '</div>';
    document.body.appendChild(modal);
    modal.addEventListener("click", function(e) { if (e.target===modal || e.target.getAttribute("data-modal")==="close") closeToolsModal(); });
    /* AGY-P2-22: пока окно открыто, чат позади не листается вообще */
    var scroller = document.scrollingElement || document.documentElement;
    var lockedTop = scroller.scrollTop;
    var lock = function () { if (scroller.scrollTop !== lockedTop) scroller.scrollTop = lockedTop; };
    scroller.addEventListener("scroll", lock, { passive: true });
    modal.__agyUnlockScroll = function () { try { scroller.removeEventListener("scroll", lock); } catch (_) {} };
    modal.addEventListener("touchmove", function (e) {
      var pane = e.target.closest && e.target.closest("[data-history],[data-terminal]");
      if (!pane) e.preventDefault();
    }, { passive: false });
    return modal;
  }
  function openToolsMenu() {
    var m=modalBox(T("Инструменты", "Tools"), '<div style="display:grid;gap:10px;margin-top:16px"><button type="button" data-modal="history">' + esc(T("История ошибок", "Error history")) + '</button><button type="button" data-modal="terminal">' + esc(T("Консоль приложения", "App console")) + '</button></div>');
    m.querySelector('[data-modal="history"]').onclick=openErrorHistory;
    m.querySelector('[data-modal="terminal"]').onclick=openToolsTerminal;
  }
  function pollAux(id, done, tries) {
    if (!modal) return;
    var b=bridge(), r={};
    try { r=JSON.parse(b.read(id)||"{}"); } catch (_) {}
    if (r.rc!==undefined && r.rc!=="") { done(r); return; }
    if (tries>600) { done({rc:"1",log:"Timeout"}); return; }
    setTimeout(function(){pollAux(id,done,tries+1);},150);
  }
  /* AGY-BACKUP: poll without modal dependency, no artificial timeout */
  function pollStandalone(id, done, tries) {
    var b = bridge();
    if (!b) { done({rc:"1",log:"Bridge unavailable"}); return; }
    var r = {};
    try { r = JSON.parse(b.read(id) || "{}"); } catch (_) {}
    if (r.rc !== undefined && r.rc !== "") { done(r); return; }
    if (tries > 20000) { done({rc:"1",log:"Timeout after 50 min"}); return; }
    setTimeout(function () { pollStandalone(id, done, tries + 1); }, 250);
  }
  /* AGY-P2-18: clipboard API first (execCommand мёртв в Android WebView) */
  function copyText(txt) {
    var fail=function(){ alert(T("Не удалось скопировать; выделите текст вручную.", "Copy failed; select the text manually.")); };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(txt).catch(function(){
        var a=document.createElement("textarea"); a.value=txt; a.style.cssText="position:fixed;left:-9999px"; document.body.appendChild(a); a.select();
        var ok=false; try { ok=document.execCommand("copy"); } catch (_) {} a.remove();
        if (!ok) fail();
      });
      return;
    }
    fail();
  }

  /* AGY-P2-21: видимый ползунок внутри окна (Android WebView не рисует ::-webkit-scrollbar) */
  function attachScroll21(wrap, pane) {
    if (!wrap || !pane) return function(){};
    var sb = document.createElement("div");
    sb.setAttribute("data-sb", "");
    sb.style.cssText = "position:absolute;top:6px;right:2px;bottom:6px;width:18px;border-radius:10px;"
      + "background:rgba(255,255,255,.06);opacity:0;transition:opacity .15s;touch-action:none;user-select:none;z-index:3";
    var thumb = document.createElement("div");
    thumb.style.cssText = "position:absolute;left:4px;width:10px;border-radius:6px;background:#9a9aa0;"
      + "min-height:28px;opacity:.92;touch-action:none;user-select:none";
    sb.appendChild(thumb);
    wrap.appendChild(sb);
    function sync() {
      var ch = pane.clientHeight, sh = pane.scrollHeight;
      if (sh <= ch + 6) { sb.style.opacity = "0"; sb.style.pointerEvents = "none"; return; }
      sb.style.opacity = "1"; sb.style.pointerEvents = "auto";
      var th = Math.max(28, Math.round((ch / sh) * sb.clientHeight));
      thumb.style.height = th + "px";
      var track = sb.clientHeight - th;
      var max = sh - ch;
      thumb.style.top = (max > 0 ? Math.round((pane.scrollTop / max) * track) : 0) + "px";
    }
    pane.addEventListener("scroll", sync, { passive: true });
    window.addEventListener("resize", sync);
    var dragging = false, startY = 0, startTop = 0;
    thumb.addEventListener("pointerdown", function (e) {
      dragging = true; startY = e.clientY; startTop = parseFloat(thumb.style.top) || 0;
      e.preventDefault(); e.stopPropagation();
      try { thumb.setPointerCapture(e.pointerId); } catch (_) {}
    });
    thumb.addEventListener("pointermove", function (e) {
      if (!dragging) return;
      var th = thumb.offsetHeight;
      var track = sb.clientHeight - th;
      if (track <= 0) return;
      var top = Math.min(track, Math.max(0, startTop + (e.clientY - startY)));
      pane.scrollTop = (top / track) * (pane.scrollHeight - pane.clientHeight);
    });
    thumb.addEventListener("pointerup", function () { dragging = false; });
    thumb.addEventListener("pointercancel", function () { dragging = false; });
    sb.addEventListener("click", function (e) {
      if (e.target !== sb) return;
      var r = sb.getBoundingClientRect();
      var y = e.clientY - r.top;
      pane.scrollTop = (y / sb.clientHeight) * (pane.scrollHeight - pane.clientHeight) - pane.clientHeight / 2;
      sync();
    });
    sync.__off = function () {
      try { window.removeEventListener("resize", sync); } catch (_) {}
    };
    scroll21List.push(sync);
    requestAnimationFrame(sync);
    setTimeout(sync, 80);
    setTimeout(sync, 400);
    return sync;
  }

  function openErrorHistory() {
    /* AGY-P2-20: тулбар истории ошибок + своя прокрутка, не терминал проекта */
    var m=modalBox(T("История ошибок", "Error history"),
      '<div data-toolbar style="display:flex;gap:8px;align-items:center;margin:12px 0 8px"></div>' +
      '<div data-pane style="position:relative;flex:1 1 auto;min-height:200px">' +
      '<pre data-history style="position:absolute;inset:0;white-space:pre-wrap;overflow-wrap:anywhere;overflow-y:scroll;overflow-x:hidden;-webkit-overflow-scrolling:touch;overscroll-behavior:contain;touch-action:pan-y;background:#101012;padding:10px 18px 10px 10px;margin:0;border-radius:10px"></pre></div>');
    var bar=m.querySelector('[data-toolbar]');
    function toolBtn(label, title) {
      var b=document.createElement("button");
      b.type="button"; b.textContent=label; b.title=title;
      b.style.cssText="background:#2a2a2e;color:#eee;border:1px solid #555;border-radius:8px;padding:6px 10px;font-size:13px";
      bar.appendChild(b); return b;
    }
    var btnCopy=toolBtn("⧉  " + T("Копировать всё", "Copy all"), T("Копировать всё", "Copy all"));
    var btnClear=toolBtn("⌫  " + T("Очистить", "Clear"), T("Очистить журнал ошибок", "Clear error log"));
    var output=m.querySelector('[data-history]'), decoder=new TextDecoder(), bytes=[]; historyText="";
    var syncH=attachScroll21(m.querySelector('[data-pane]'), output);
    output.textContent=T("Загрузка истории…", "Loading history…");
    btnCopy.onclick=function(){ copyText(historyText); btnCopy.textContent="✓  " + T("Скопировано", "Copied"); setTimeout(function(){ btnCopy.textContent="⧉  " + T("Копировать всё", "Copy all"); }, 1200); };
    btnClear.onclick=function(){
      if (!confirm(T("Очистить журнал ошибок?", "Clear the error log?"))) return;
      var id=bridge().start("histclear","");
      if (!id || /^ERR/.test(id)) { alert(String(id)); return; }
      pollAux(id, function(){ historyText=""; output.textContent=T("Ошибок пока нет.","No errors yet."); }, 0);
    };
    var userMoved=false, ignoreScroll=0;
    output.addEventListener("scroll", function(){ if (!ignoreScroll) userMoved=true; }, {passive:true});
    function placeScroll(top) {
      ignoreScroll++;
      output.scrollTop=top;
      setTimeout(function(){ ignoreScroll=Math.max(0, ignoreScroll-1); }, 60);
    }
    function load(offset) {
      if (modal!==m) return;
      var id=bridge().start("histread",String(offset));
      if (!id || /^ERR/.test(id)) { output.textContent=T("Не удалось открыть историю: ","Cannot open history: ")+id; return; }
      pollAux(id,function(r){
        if (modal!==m) return;
        var match=/@@HISTORY (\d+) (\d+) ?([A-Za-z0-9+/=]*)/.exec(r.log||"");
        if (String(r.rc)!=="0" || !match) {output.textContent=T("Ошибка чтения: ","Read error: ")+(r.log||"");return;}
        var raw=atob(match[3]||""), part=new Uint8Array(raw.length); for(var i=0;i<raw.length;i++)part[i]=raw.charCodeAt(i);
        var keep=output.scrollTop, atBottom=keep+output.clientHeight>=output.scrollHeight-24;
        historyText+=decoder.decode(part,{stream:Number(match[1])<Number(match[2])});
        output.textContent=historyText || T("Ошибок пока нет.","No errors yet.");
        if (!userMoved) placeScroll(0);
        else if (atBottom) placeScroll(output.scrollHeight);
        else placeScroll(keep);
        if (typeof syncH === "function") syncH();
        if (Number(match[1])<Number(match[2]) && Number(match[1])>offset) setTimeout(function(){load(Number(match[1]));},80);
      },0);
    }
    if (!bridge()) {output.textContent=T("Мост недоступен.","Bridge unavailable.");return;} load(0);
  }
  function openToolsTerminal() {
    /* AGY-P2-20: консоль снятия логов приложения. Каждая команда — отдельный запуск,
       не PTY открытой сессии/проекта (тот FIFO умирал и ввод падал с ENXIO). */
    var m=modalBox(T("Консоль приложения", "App console"),
      '<div data-toolbar style="display:flex;gap:8px;align-items:center;margin:10px 0 8px"></div>' +
      '<div data-pane style="position:relative;flex:1 1 auto;min-height:200px">' +
      '<pre data-terminal style="position:absolute;inset:0;white-space:pre-wrap;overflow-wrap:anywhere;overflow-y:scroll;overflow-x:hidden;-webkit-overflow-scrolling:touch;overscroll-behavior:contain;touch-action:pan-y;background:#101012;padding:10px 18px 10px 10px;margin:0;border-radius:10px"></pre></div>' +
      '<div style="display:flex;gap:8px;margin-top:8px"><input data-command style="flex:1;min-width:0;background:#101012;color:#eee;border:1px solid #555;border-radius:8px;padding:8px" placeholder="' + esc(T("Команда для логов приложения", "Command for app logs")) + '">' +
      '<button type="button" data-send style="background:#0b84ff;color:#fff;border:0;border-radius:8px;padding:8px 14px">▶</button></div>' +
      '<div style="margin-top:6px;color:#888;font-size:12px">' + esc(T("Это не терминал открытого проекта: команда выполняется в окружении приложения и сразу завершается.", "This is not the open project terminal: the command runs in the app environment and then exits.")) + '</div>');
    var bar=m.querySelector('[data-toolbar]');
    function toolBtn(label, title) {
      var b=document.createElement("button");
      b.type="button"; b.textContent=label; b.title=title;
      b.style.cssText="background:#2a2a2e;color:#eee;border:1px solid #555;border-radius:8px;padding:6px 10px;font-size:13px";
      bar.appendChild(b); return b;
    }
    var out=m.querySelector('[data-terminal]'), input=m.querySelector('[data-command]');
    var syncT=attachScroll21(m.querySelector('[data-pane]'), out);
    var transcript="";
    function paint(extra) {
      if (extra) transcript += extra;
      if (transcript.length > 80000) transcript = transcript.slice(-80000);
      out.textContent = transcript || T("Готово. Введите команду, например: logcat -d -t 80", "Ready. Try: logcat -d -t 80");
      out.scrollTop = out.scrollHeight;
      if (typeof syncT === "function") syncT();
    }
    paint("");
    toolBtn("⧉  " + T("Копировать", "Copy"), T("Копировать вывод", "Copy output")).onclick=function(){ copyText(transcript); };
    toolBtn("⌫  " + T("Очистить", "Clear"), T("Очистить экран", "Clear screen")).onclick=function(){ transcript=""; paint(""); };
    toolBtn("logcat", "logcat -d -t 80").onclick=function(){ input.value="logcat -d -t 80 *:W"; send(); };
    if (!bridge()) { out.textContent=T("Мост недоступен.","Bridge unavailable."); return; }
    function send(){
      var v=(input.value||"").replace(/\r/g,"");
      if (!v.trim()) return;
      input.value="";
      var encoded=new TextEncoder().encode(v);
      if (encoded.length>3500){ alert(T("Команда слишком длинная.","Command is too long.")); return; }
      var raw=""; encoded.forEach(function(x){ raw+=String.fromCharCode(x); });
      transcript += "\n$ " + v + "\n";
      paint("");
      var id=bridge().start("termrun", btoa(raw));
      if (!id || /^ERR/.test(id)) { paint(String(id||"ERR")+"\n"); return; }
      pollAux(id, function(r){
        var log=String(r.log||"");
        paint(log.replace(/@@[A-Z0-9_]+[^\n]*\n?/g,"") + (log && !/\n$/.test(log) ? "\n" : ""));
      }, 0);
    }
    m.querySelector('[data-send]').onclick=send;
    input.onkeydown=function(e){ if(e.key==="Enter"){ e.preventDefault(); send(); } };
    input.focus();
  }

  /* AGY-BACKUP: экспорт/импорт всех данных (провайдеры, MCP, настройки, чаты) */
  function openBackupSection(hostEl) {
    if (!hostEl) return;
    if (hostEl.querySelector("[data-backup-section]") && hostEl.children.length === 1) return;
    hostEl.innerHTML = "";
    var wrap = document.createElement("div");
    wrap.className = "agy-tools";
    wrap.setAttribute("data-backup-section", "");
    wrap.setAttribute("data-agy-no-translate", "");

    var sec = document.createElement("div");
    sec.className = "agy-t-sec";
    sec.textContent = T("Резервное копирование", "Backup && Restore");
    wrap.appendChild(sec);

    var note = document.createElement("div");
    note.className = "agy-t-note";
    note.textContent = T(
      "Отметьте, что сохранить, и укажите путь. По умолчанию — папка «Leostryx Backup» на телефоне. Включает провайдеры, ключи MCP, настройки и историю чатов с фото.",
      "Check what to save and set the path. Default folder: Leostryx Backup on the phone. Includes providers, MCP keys, settings and chat history with photos."
    );
    wrap.appendChild(note);

    /* AGY-BACKUP: поле выбора пути сохранения */
    var pathRow = document.createElement("div");
    pathRow.style.cssText = "display:flex;gap:8px;align-items:center;margin-bottom:10px";
    var pathLabel = document.createElement("span");
    pathLabel.style.cssText = "font-size:12px;color:#888;white-space:nowrap";
    pathLabel.textContent = T("Путь:", "Path:");
    pathRow.appendChild(pathLabel);
    var pathInput = document.createElement("input");
    pathInput.type = "text";
    pathInput.value = "/storage/emulated/0/Leostryx Backup";
    pathInput.style.cssText = "flex:1;min-width:0;background:#101012;color:#eee;border:1px solid #555;border-radius:8px;padding:8px;font-size:12px";
    pathInput.setAttribute("data-backup-path", "");
    pathRow.appendChild(pathInput);
    wrap.appendChild(pathRow);

    /* AGY-BACKUP: галочки выбора данных */
    var checkData = [
      { id: "providers", label: T("Провайдеры и API-ключи", "Providers & API keys"), checked: true },
      { id: "mcp", label: T("Ключи MCP-серверов", "MCP server keys"), checked: true },
      { id: "settings", label: T("Настройки приложения", "App settings"), checked: true },
      { id: "chats", label: T("История чатов", "Chat history"), checked: true },
      { id: "attachments", label: T("Фото и вложения", "Photos & attachments"), checked: true },
    ];
    var checkWrap = document.createElement("div");
    checkWrap.style.cssText = "display:flex;flex-direction:column;gap:6px;margin-bottom:12px";
    var checkLabel = document.createElement("div");
    checkLabel.style.cssText = "font-size:12px;color:#888;margin-bottom:2px";
    checkLabel.textContent = T("Что резервировать:", "What to back up:");
    checkWrap.appendChild(checkLabel);
    checkData.forEach(function (item) {
      var row = document.createElement("label");
      row.style.cssText = "display:flex;align-items:center;gap:8px;cursor:pointer;font-size:13px";
      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.checked = item.checked;
      cb.setAttribute("data-bk-item", item.id);
      cb.style.cssText = "width:18px;height:18px;accent-color:#0b84ff";
      row.appendChild(cb);
      var span = document.createElement("span");
      span.textContent = item.label;
      row.appendChild(span);
      checkWrap.appendChild(row);
    });
    wrap.appendChild(checkWrap);

    var card = document.createElement("div");
    card.className = "agy-t-card";

    var main = document.createElement("div");
    main.className = "agy-t-main";
    var name = document.createElement("div");
    name.className = "agy-t-name";
    name.textContent = T("Экспорт / Импорт данных", "Export / Import data");
    main.appendChild(name);

    var desc = document.createElement("div");
    desc.className = "agy-t-desc";
    desc.setAttribute("data-desc", "");
    desc.textContent = T("Архив сохраняется в папку «Leostryx Backup» на телефоне.", "Archive is saved to the Leostryx Backup folder on the phone.");
    main.appendChild(desc);

    card.appendChild(main);

    var actions = document.createElement("div");
    actions.style.cssText = "display:flex;gap:8px;flex-shrink:0";

    var btnExport = document.createElement("button");
    btnExport.className = "agy-t-btn";
    btnExport.textContent = T("Экспорт", "Export");
    var progressBar = document.createElement("div");
    progressBar.style.cssText = "display:none;align-items:center;gap:8px;margin-top:8px";
    var pbarOuter = document.createElement("div");
    pbarOuter.style.cssText = "flex:1;height:6px;border-radius:6px;background:rgba(255,255,255,.1);overflow:hidden";
    var pbarFill = document.createElement("div");
    pbarFill.style.cssText = "height:100%;width:0%;border-radius:6px;background:#0b84ff;transition:width .3s";
    pbarOuter.appendChild(pbarFill);
    var pbarTime = document.createElement("span");
    pbarTime.style.cssText = "font-size:11px;color:#888;white-space:nowrap;font-variant-numeric:tabular-nums";
    progressBar.appendChild(pbarOuter);
    progressBar.appendChild(pbarTime);
    card.appendChild(progressBar);
    btnExport.onclick = function () {
      var items = [];
      wrap.querySelectorAll("[data-bk-item]").forEach(function (cb) {
        if (cb.checked) items.push(cb.getAttribute("data-bk-item"));
      });
      if (!items.length) { alert(T("Отметьте хотя бы один пункт.", "Check at least one item.")); return; }
      var path = (pathInput.value || "").trim();
      var arg = path + "@" + items.join(",");
      btnExport.disabled = true;
      btnExport.textContent = T("Сохранение…", "Saving…");
      progressBar.style.display = "flex";
      pbarFill.style.width = "5%";
      var t0 = Date.now();
      var timer = setInterval(function () {
        var s = Math.round((Date.now() - t0) / 1000);
        var min = Math.floor(s / 60), sec = s % 60;
        pbarTime.textContent = (min > 0 ? min + T(" мин ", " min ") : "") + sec + T(" с", " s");
        /* indeterminate: oscillate between 5% and 90% */
        var pct = 5 + (Math.sin(Date.now() / 600) + 1) * 42.5;
        pbarFill.style.width = pct.toFixed(0) + "%";
      }, 400);
      var b = bridge();
      if (!b) { clearInterval(timer); progressBar.style.display = "none"; alert(T("Мост недоступен.", "Bridge unavailable.")); btnExport.disabled = false; return; }
      var id = b.start("backup", arg);
      if (!id || /^ERR/.test(id)) { clearInterval(timer); progressBar.style.display = "none"; alert(String(id)); btnExport.disabled = false; return; }
      pollStandalone(id, function (r) {
        clearInterval(timer);
        pbarFill.style.width = "100%";
        setTimeout(function () { progressBar.style.display = "none"; pbarFill.style.width = "0%"; }, 800);
        btnExport.disabled = false;
        btnExport.textContent = T("Экспорт", "Export");
        var elapsed = Math.round((Date.now() - t0) / 1000);
        var emin = Math.floor(elapsed / 60), esec = elapsed % 60;
        var timeStr = (emin > 0 ? emin + T(" мин ", " min ") : "") + esec + T(" с", " s");
        var m = /@@BACKUP (\S+) (\d+) (\d+)/.exec(r.log || "");
        if (String(r.rc) === "0" && m) {
          var mb = Math.round(parseInt(m[2], 10) / 1048576);
          desc.textContent = T(
            "Готово за " + timeStr + ": " + mb + " МБ, " + m[3] + " файлов → " + m[1],
            "Done in " + timeStr + ": " + mb + " MB, " + m[3] + " files → " + m[1]
          );
          agyToast11(T("Бэкап за ", "Backup done in ") + timeStr);
          refreshBkList();
        } else {
          desc.textContent = T("Ошибка экспорта: ", "Export error: ") + (r.log || "");
        }
      }, 0);
    };
    actions.appendChild(btnExport);

    var btnImport = document.createElement("button");
    btnImport.className = "agy-t-btn sec";
    btnImport.textContent = T("Импорт", "Import");
    btnImport.onclick = function () {
      var b = bridge();
      if (!b) { alert(T("Мост недоступен.", "Bridge unavailable.")); return; }
      var lsId = b.start("termrun", btoa("ls -1t \"/storage/emulated/0/Leostryx Backup\"/agy-backup-*.zip \"/storage/emulated/0/Antigravity Backup\"/agy-backup-*.zip 2>/dev/null | head -15"));
      if (!lsId || /^ERR/.test(lsId)) { alert(String(lsId)); return; }
      pollStandalone(lsId, function (r) {
        var lines = (r.log || "").split("\n").filter(function (l) { return l.trim() && l.indexOf(".zip") >= 0; });
        if (!lines.length) { alert(T("Нет файлов бэкапа в папке Leostryx Backup.", "No backup files found.")); return; }
        var overlay = document.createElement("div");
        overlay.style.cssText = "position:fixed;inset:0;z-index:2147483000;background:rgba(0,0,0,.72);display:flex;align-items:center;justify-content:center;padding:16px";
        var box = document.createElement("div");
        box.style.cssText = "background:#1c1c1e;border:1px solid #555;border-radius:16px;padding:16px;width:min(100%,500px);max-height:80vh;overflow-y:auto";
        var title = document.createElement("div");
        title.style.cssText = "margin-bottom:10px;font-weight:600";
        title.textContent = T("Выберите бэкап:", "Choose backup:");
        box.appendChild(title);
        lines.forEach(function (line) {
          var name = line.trim().split("/").pop();
          var btn = document.createElement("button");
          btn.textContent = name;
          btn.style.cssText = "display:block;width:100%;text-align:left;padding:10px 12px;margin:4px 0;border:1px solid #444;border-radius:8px;background:#222;color:#eee;cursor:pointer;font-size:12px";
          btn.onclick = function () {
            overlay.remove();
            btnImport.disabled = true;
            btnImport.textContent = T("Восстановление…", "Restoring…");
            var id = b.start("restore", line.trim());
            if (!id || /^ERR/.test(id)) { alert(String(id)); btnImport.disabled = false; btnImport.textContent = T("Импорт", "Import"); return; }
            pollStandalone(id, function (r2) {
              btnImport.disabled = false;
              btnImport.textContent = T("Импорт", "Import");
              var ok = /@@RESTORE OK (\d+)/.exec(r2.log || "");
              if (String(r2.rc) === "0" && ok) {
                desc.textContent = T("Восстановлено файлов: " + ok[1] + ". Перезапустите приложение.", "Restored: " + ok[1] + " files. Restart the app.");
                agyToast11(T("Данные восстановлены. Перезапустите приложение.", "Data restored. Restart the app."));
              } else {
                desc.textContent = T("Ошибка импорта: ", "Import error: ") + (r2.log || "");
              }
            }, 0);
          };
          box.appendChild(btn);
        });
        var cancel = document.createElement("button");
        cancel.textContent = T("Отмена", "Cancel");
        cancel.style.cssText = "display:block;width:100%;padding:10px;margin:10px 0 0;border:1px solid #555;border-radius:8px;background:transparent;color:#aaa;cursor:pointer";
        cancel.onclick = function () { overlay.remove(); };
        box.appendChild(cancel);
        overlay.appendChild(box);
        document.body.appendChild(overlay);
      }, 0);
    };
    actions.appendChild(btnImport);

    card.appendChild(actions);
    wrap.appendChild(card);

    /* AGY-BACKUP: список существующих бэкапов */
    var listSec = document.createElement("div");
    listSec.className = "agy-t-sec";
    listSec.textContent = T("Сохранённые бэкапы", "Saved backups");
    wrap.appendChild(listSec);

    var listWrap = document.createElement("div");
    listWrap.setAttribute("data-bk-list", "");
    listWrap.style.cssText = "display:flex;flex-direction:column;gap:6px;margin-bottom:16px";
    wrap.appendChild(listWrap);

    function refreshBkList() {
      listWrap.innerHTML = "";
      var b = bridge();
      if (!b) return;
      var id = b.start("bklist", "");
      if (!id || /^ERR/.test(id)) return;
      pollStandalone(id, function (r) {
        var lines = (r.log || "").split("\n").filter(function (l) { return l.indexOf("@@BKFILE") === 0; });
        if (!lines.length) {
          var empty = document.createElement("div");
          empty.style.cssText = "display:flex;flex-direction:column;align-items:center;gap:6px;padding:20px 12px;border:1px dashed rgba(127,127,127,.25);border-radius:12px;color:#888;font-size:12px;text-align:center";
          empty.innerHTML = '<svg width="24" height="24" fill="none" stroke="#888" stroke-width="1.5" viewBox="0 0 24 24"><path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>' +
            '<div>' + T("Пока нет сохранённых бэкапов.", "No saved backups yet.") + '</div>';
          listWrap.appendChild(empty);
          return;
        }
        lines.forEach(function (line, idx) {
          var parts = line.split(" ");
          if (parts.length < 4) return;
          var fname = parts[1], sz = parseInt(parts[2], 10), ts = parts.slice(3).join(" ");
          var mb = (sz / 1048576).toFixed(1);
          var row = document.createElement("div");
          row.style.cssText = "display:flex;align-items:center;gap:12px;padding:12px 14px;border:1px solid rgba(127,127,127,.15);border-radius:12px;background:rgba(255,255,255,.02);transition:background .15s,border-color .15s";
          row.onmouseenter = function() { row.style.borderColor = "rgba(127,127,127,.35)"; row.style.background = "rgba(255,255,255,.05)"; };
          row.onmouseleave = function() { row.style.borderColor = "rgba(127,127,127,.15)"; row.style.background = "rgba(255,255,255,.02)"; };

          /* icon */
          var icon = document.createElement("div");
          icon.style.cssText = "width:36px;height:36px;border-radius:10px;background:rgba(11,132,255,.12);display:flex;align-items:center;justify-content:center;flex-shrink:0";
          icon.innerHTML = '<svg width="18" height="18" fill="none" stroke="#0b84ff" stroke-width="1.5" viewBox="0 0 24 24"><path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>';
          row.appendChild(icon);

          /* info */
          var info = document.createElement("div");
          info.style.cssText = "flex:1;min-width:0";
          var nameEl = document.createElement("div");
          nameEl.style.cssText = "font-size:13px;font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#eee";
          nameEl.textContent = fname.replace("agy-backup-", "").replace(".zip", "");
          var meta = document.createElement("div");
          meta.style.cssText = "font-size:11px;color:#888;margin-top:2px;display:flex;gap:8px;align-items:center";
          var dateIcon = '<svg width="12" height="12" fill="none" stroke="#888" stroke-width="1.5" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>';
          var sizeIcon = '<svg width="12" height="12" fill="none" stroke="#888" stroke-width="1.5" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>';
          meta.innerHTML = dateIcon + ' ' + ts + ' <span style="opacity:.5">·</span> ' + sizeIcon + ' ' + mb + ' МБ';
          info.appendChild(nameEl);
          info.appendChild(meta);
          row.appendChild(info);

          /* delete button */
          var btnDel = document.createElement("button");
          btnDel.title = T("Удалить", "Delete");
          btnDel.style.cssText = "width:32px;height:32px;border-radius:8px;background:transparent;border:1px solid rgba(214,69,69,.2);color:#d64545;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:background .15s;flex-shrink:0";
          btnDel.innerHTML = '<svg width="14" height="14" fill="none" stroke="#d64545" stroke-width="1.5" viewBox="0 0 24 24"><path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2m3 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6h14M10 11v6M14 11v6"/></svg>';
          btnDel.onmouseenter = function() { btnDel.style.background = "rgba(214,69,69,.15)"; };
          btnDel.onmouseleave = function() { btnDel.style.background = "transparent"; };
          btnDel.onclick = function () {
            if (!confirm(T("Удалить бэкап от ", "Delete backup from ") + ts + "?")) return;
            row.style.opacity = "0.4";
            var did = b.start("bkdelete", fname);
            if (!did || /^ERR/.test(did)) { row.style.opacity = "1"; alert(String(did)); return; }
            pollStandalone(did, function () { refreshBkList(); }, 0);
          };
          row.appendChild(btnDel);
          listWrap.appendChild(row);
        });
      }, 0);
    }
    refreshBkList();

    hostEl.appendChild(wrap);
  }
  window.__agyBackupMount = openBackupSection;

  /* AGY-ABOUT: О приложении — три карточки: приложение, разработчик, обновления */
  function openAboutSection(hostEl) {
    if (!hostEl) return;
    if (hostEl.querySelector("[data-about-section]") && hostEl.children.length === 1) return;
    hostEl.innerHTML = "";

    var ACCENT = "#0b84ff";
    var BORDER = "rgba(127,127,127,.18)";
    var BG = "rgba(255,255,255,.025)";

    var wrap = document.createElement("div");
    wrap.setAttribute("data-about-section", "");
    wrap.style.cssText = "padding:20px;max-width:560px;overflow-y:auto;height:100%;box-sizing:border-box";

    /* ── fixed header ── */
    var header = document.createElement("div");
    header.style.cssText = "position:sticky;top:0;z-index:2;background:var(--background,#111);display:flex;align-items:center;padding:0 0 14px 0;margin-bottom:12px";
    var hTitle = document.createElement("div");
    hTitle.style.cssText = "font-size:18px;font-weight:600;color:var(--foreground,#eee)";
    hTitle.textContent = T("О приложении", "About");
    header.appendChild(hTitle);
    wrap.appendChild(header);

    function makeCard() {
      var c = document.createElement("div");
      c.style.cssText = "background:" + BG + ";border:1px solid " + BORDER + ";border-radius:16px;padding:16px;margin-bottom:12px";
      return c;
    }

    /* ── Card 1: Приложение ── */
    var c1 = makeCard();
    var appRow = document.createElement("div");
    appRow.style.cssText = "display:flex;align-items:center;gap:12px;margin-bottom:12px";
    var appIcon = document.createElement("div");
    appIcon.style.cssText = "width:40px;height:40px;border-radius:12px;background:rgba(11,132,255,.12);display:flex;align-items:center;justify-content:center;flex-shrink:0";
    appIcon.innerHTML = '<svg width="22" height="22" fill="none" stroke="' + ACCENT + '" stroke-width="1.5" viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>';
    appRow.appendChild(appIcon);
    var appInfo = document.createElement("div");
    var appName = document.createElement("div");
    appName.style.cssText = "font-size:17px;font-weight:600;color:var(--foreground,#eee)";
    appName.textContent = "Leostryx";
    var appVer = document.createElement("div");
    appVer.style.cssText = "font-size:12px;color:#888;margin-top:2px";
    appVer.textContent = "3.0.9";
    appInfo.appendChild(appName);
    appInfo.appendChild(appVer);
    appRow.appendChild(appInfo);
    c1.appendChild(appRow);

    var appDesc = document.createElement("div");
    appDesc.style.cssText = "font-size:14px;line-height:1.55;color:var(--foreground,#ddd);margin-bottom:6px";
    appDesc.textContent = T(
      "Среда разработки с ИИ-агентом для Android. Позволяет работать с кодом, редактировать файлы и запускать инструменты прямо на устройстве.",
      "AI agent development environment for Android. Work with code, edit files and run tools right on your device."
    );
    c1.appendChild(appDesc);

    var appDesc2 = document.createElement("div");
    appDesc2.style.cssText = "font-size:13px;line-height:1.5;color:#999;margin-bottom:14px";
    appDesc2.textContent = T(
      "Сборка Leostrange: русский интерфейс, пользовательские ИИ-провайдеры, настройки безопасности, MCP и инструменты разработки.",
      "Leostrange build: Russian UI, custom AI providers, security settings, MCP and developer tools."
    );
    c1.appendChild(appDesc2);

    var linksRow = document.createElement("div");
    linksRow.style.cssText = "display:flex;gap:16px;flex-wrap:wrap";
    function makeLink(text, url) {
      var a = document.createElement("a");
      a.textContent = text;
      a.href = url;
      a.target = "_blank";
      a.style.cssText = "font-size:13px;color:" + ACCENT + ";text-decoration:none;cursor:pointer;border-bottom:1px solid rgba(11,132,255,.3);padding-bottom:1px";
      return a;
    }
    linksRow.appendChild(makeLink(T("Исходный код", "Source code"), "https://github.com/Leostrange/Leostryx"));
    linksRow.appendChild(makeLink(T("История изменений", "Changelog"), "https://github.com/Leostrange/Leostryx/blob/main/CHANGELOG.md"));
    c1.appendChild(linksRow);

    var credit = document.createElement("div");
    credit.style.cssText = "margin-top:12px;font-size:11px;color:#666;line-height:1.4";
    credit.innerHTML = T("На основе проекта ", "Based on ") + '<a href="https://github.com/werdio325-png/antigravity-android" target="_blank" style="color:#888;text-decoration:underline">werdio325-png/antigravity-android</a>';
    c1.appendChild(credit);
    wrap.appendChild(c1);

    /* ── Card 2: Разработчик ── */
    var c2 = makeCard();
    var devTitle = document.createElement("div");
    devTitle.style.cssText = "font-size:16px;font-weight:600;color:var(--foreground,#eee);margin-bottom:10px";
    devTitle.textContent = T("О разработчике", "About the developer");
    c2.appendChild(devTitle);

    var devName = document.createElement("div");
    devName.style.cssText = "font-size:15px;font-weight:500;color:var(--foreground,#eee);margin-bottom:6px";
    devName.textContent = "Leostrange";
    c2.appendChild(devName);

    var devDesc = document.createElement("div");
    devDesc.style.cssText = "font-size:14px;line-height:1.55;color:var(--foreground,#ddd);margin-bottom:14px";
    devDesc.textContent = T(
      "Создаю приложения для Android и компьютеров, инструменты с ИИ и русификации программ. Развиваю открытые проекты, стараясь делать технологии удобнее и доступнее. Пишу книгу, увлекаюсь музыкой и фотографией.",
      "Creating apps for Android and desktop, AI tools and software localization. Building open-source projects to make technology more accessible. Writing a book, passionate about music and photography."
    );
    c2.appendChild(devDesc);

    var contacts = [
      { icon: '<svg width="15" height="15" fill="#888" viewBox="0 0 24 24"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/></svg>',
        text: "GitHub · Leostrange", url: "https://github.com/Leostrange" },
      { icon: '<svg width="15" height="15" fill="none" stroke="#888" stroke-width="1.5" viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M22 4l-10 8L2 4"/></svg>',
        text: "xmetalcore@outlook.com", url: "mailto:xmetalcore@outlook.com" },
      { icon: '<svg width="15" height="15" fill="none" stroke="#888" stroke-width="1.5" viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M22 4l-10 8L2 4"/></svg>',
        text: "chester.god.alive@gmail.com", url: "mailto:chester.god.alive@gmail.com" }
    ];
    contacts.forEach(function (ct) {
      var row = document.createElement("div");
      row.style.cssText = "display:flex;align-items:center;gap:10px;padding:10px 0;border-top:1px solid " + BORDER + ";cursor:pointer;transition:opacity .15s";
      row.onmouseenter = function() { row.style.opacity = "0.7"; };
      row.onmouseleave = function() { row.style.opacity = "1"; };
      row.onclick = function() { window.open(ct.url, "_blank"); };
      /* long-press to copy */
      var lpTimer = null;
      row.onmousedown = function() { lpTimer = setTimeout(function() { copyText(ct.text); }, 600); };
      row.onmouseup = function() { clearTimeout(lpTimer); };
      row.onmouseleave = function() { clearTimeout(lpTimer); row.style.opacity = "1"; };
      var ic = document.createElement("div");
      ic.style.cssText = "width:28px;height:28px;border-radius:8px;background:rgba(127,127,127,.08);display:flex;align-items:center;justify-content:center;flex-shrink:0";
      ic.innerHTML = ct.icon;
      row.appendChild(ic);
      var tx = document.createElement("div");
      tx.style.cssText = "font-size:13px;color:var(--foreground,#ddd);word-break:break-all;flex:1;min-width:0";
      tx.textContent = ct.text;
      row.appendChild(tx);
      c2.appendChild(row);
    });
    wrap.appendChild(c2);

    /* ── Card 3: Обновления ── */
    var c3 = makeCard();
    var updTitle = document.createElement("div");
    updTitle.style.cssText = "font-size:16px;font-weight:600;color:var(--foreground,#eee);margin-bottom:6px";
    updTitle.textContent = T("Обновления", "Updates");
    c3.appendChild(updTitle);

    var updStatus = document.createElement("div");
    updStatus.style.cssText = "font-size:13px;color:#888;margin-bottom:12px;min-height:20px";
    updStatus.textContent = T("Нажмите для проверки наличия обновлений.", "Tap to check for updates.");
    c3.appendChild(updStatus);

    var btnUpd = document.createElement("button");
    btnUpd.style.cssText = "width:100%;padding:12px;border:0;border-radius:12px;background:" + ACCENT + ";color:#fff;font-size:14px;font-weight:500;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;transition:opacity .15s, background .15s";
    btnUpd.onmouseenter = function() { btnUpd.style.opacity = "0.85"; };
    btnUpd.onmouseleave = function() { btnUpd.style.opacity = "1"; };
    btnUpd.textContent = T("Проверить обновления", "Check for updates");
    c3.appendChild(btnUpd);

    var CURRENT_VERSION = "3.0.9";
    var downloadedApkPath = "/storage/emulated/0/Download/update-temp.apk";
    var pendingApkUrl = null;
    var updState = "check"; // "check" | "available" | "downloading" | "ready"

    function triggerInstall(apkPath) {
      var p = apkPath || downloadedApkPath;
      try {
        if (window.AgyTools && typeof window.AgyTools.installApk === "function") {
          window.AgyTools.installApk(p);
          return true;
        }
      } catch (e) {
        console.warn("AgyTools.installApk error:", e);
      }
      return false;
    }

    btnUpd.onclick = function () {
      var b = bridge();
      if (!b) {
        updStatus.textContent = T("Мост недоступен.", "Bridge unavailable.");
        return;
      }

      if (updState === "ready") {
        updStatus.textContent = T("Запуск установщика пакетов…", "Launching package installer…");
        triggerInstall(downloadedApkPath);
        return;
      }

      if (updState === "check") {
        btnUpd.disabled = true;
        btnUpd.textContent = "";
        var spin = document.createElement("div");
        spin.style.cssText = "width:18px;height:18px;border:2px solid rgba(255,255,255,.3);border-top-color:#fff;border-radius:50%;animation:agy-usage-spin .7s linear infinite";
        btnUpd.appendChild(spin);
        var stx = document.createElement("span");
        stx.textContent = T(" Проверяем…", " Checking…");
        btnUpd.appendChild(stx);
        updStatus.textContent = "";

        var id = b.start("updatecheck", "");
        if (!id || /^ERR/.test(id)) {
          updStatus.textContent = T("Не удалось проверить обновления.", "Could not check for updates.");
          btnUpd.disabled = false;
          btnUpd.textContent = T("Проверить обновления", "Check for updates");
          return;
        }

        pollStandalone(id, function (r) {
          btnUpd.disabled = false;
          var m = /@@UPDATE (\S+) (\S+) (\S+)/.exec(r.log || "");
          if (m && m[1] && !m[1].startsWith("ERR")) {
            var tag = m[1], apkUrl = m[3];
            var cleanTag = tag.replace(/^v/, "");
            if (cleanTag === CURRENT_VERSION) {
              updStatus.textContent = T("Установлена актуальная версия (" + CURRENT_VERSION + ").", "Latest version is installed (" + CURRENT_VERSION + ").");
              btnUpd.textContent = T("Проверить обновления", "Check for updates");
              updState = "check";
            } else {
              pendingApkUrl = apkUrl;
              updState = "available";
              updStatus.textContent = T("Доступна новая версия: ", "Update available: ") + tag;
              btnUpd.textContent = T("Скачать обновление (" + tag + ")", "Download update (" + tag + ")");
            }
          } else {
            updStatus.textContent = T("Не удалось проверить обновления.", "Could not check for updates.");
            btnUpd.textContent = T("Проверить обновления", "Check for updates");
            updState = "check";
          }
        }, 0);
        return;
      }

      if (updState === "available") {
        if (!pendingApkUrl) return;
        btnUpd.disabled = true;
        btnUpd.textContent = T("Скачивание… 0%", "Downloading… 0%");
        updStatus.textContent = T("Загрузка APK…", "Downloading APK…");
        updState = "downloading";

        var dlId = b.start("updatedownload", pendingApkUrl);
        if (!dlId || /^ERR/.test(dlId)) {
          updStatus.textContent = T("Не удалось начать загрузку.", "Download failed to start.");
          btnUpd.disabled = false;
          btnUpd.textContent = T("Скачать обновление", "Download update");
          updState = "available";
          return;
        }

        /* Continuous progress polling */
        var dlPollTimer = setInterval(function () {
          var chunk = b.read(dlId);
          if (chunk) {
            var lines = chunk.split("\n");
            for (var i = lines.length - 1; i >= 0; i--) {
              var pm = /@@UPDPROGRESS (\d+) (\d+)/.exec(lines[i]);
              if (pm) {
                var done = parseInt(pm[1], 10);
                var total = parseInt(pm[2], 10);
                if (total > 0) {
                  var pct = Math.min(100, Math.round((done * 100) / total));
                  btnUpd.textContent = T("Скачивание… " + pct + "%", "Downloading… " + pct + "%");
                }
                break;
              }
            }
          }
        }, 350);

        pollStandalone(dlId, function (r2) {
          clearInterval(dlPollTimer);
          var log = r2.log || "";
          if (log.indexOf("@@UPDOK installed") >= 0) {
            btnUpd.disabled = false;
            btnUpd.textContent = T("Обновлено! Перезапустить", "Updated! Restart");
            btnUpd.onclick = function() { location.reload(); };
            updStatus.textContent = T("Обновление успешно установлено!", "Update successfully installed!");
            updState = "done";
          } else if (log.indexOf("@@UPDREADY") >= 0 || log.indexOf("@@UPD manual") >= 0 || log.indexOf("@@UPDOK") >= 0) {
            var rm = /@@UPDREADY (\S+)/.exec(log);
            if (rm && rm[1]) downloadedApkPath = rm[1];
            btnUpd.disabled = false;
            btnUpd.style.background = "#30d158";
            btnUpd.textContent = T("Обновить и установить", "Update & install");
            updStatus.textContent = T("Загрузка завершена! Запуск установщика…", "Download complete! Launching installer…");
            updState = "ready";
            /* Automatically launch the system package installer! */
            triggerInstall(downloadedApkPath);
          } else {
            updStatus.textContent = T("Ошибка загрузки.", "Download error.");
            btnUpd.disabled = false;
            btnUpd.textContent = T("Повторить скачивание", "Retry download");
            updState = "available";
          }
        }, 0);
      }
    };

    wrap.appendChild(c3);
    hostEl.appendChild(wrap);
  }
  window.__agyAboutMount = openAboutSection;

  /* AGY-FEEDBACK: Оставить отзыв — отправка по электронной почте */
  function openFeedbackSection(hostEl) {
    if (!hostEl) return;
    if (hostEl.querySelector("[data-feedback-section]") && hostEl.children.length === 1) return;
    hostEl.innerHTML = "";

    var ACCENT = "#0b84ff";
    var BORDER = "rgba(127,127,127,.18)";
    var BG = "rgba(255,255,255,.025)";

    var wrap = document.createElement("div");
    wrap.setAttribute("data-feedback-section", "");
    wrap.style.cssText = "padding:20px;max-width:560px;overflow-y:auto;height:100%;box-sizing:border-box";

    /* header */
    var header = document.createElement("div");
    header.style.cssText = "display:flex;align-items:center;padding:0 0 14px 0;margin-bottom:12px";
    var hTitle = document.createElement("div");
    hTitle.style.cssText = "font-size:18px;font-weight:600;color:var(--foreground,#eee)";
    hTitle.textContent = T("Обратная связь", "Feedback");
    header.appendChild(hTitle);
    wrap.appendChild(header);

    var intro = document.createElement("div");
    intro.style.cssText = "font-size:14px;line-height:1.55;color:#999;margin-bottom:16px";
    intro.textContent = T(
      "Отзывы и предложения отправляются напрямую на почту разработчика. Опишите проблему или идею — ответ приходит в течение нескольких дней.",
      "Feedback and suggestions go directly to the developer's email. Describe a problem or idea — you'll get a reply within a few days."
    );
    wrap.appendChild(intro);

    /* card: form */
    var card = document.createElement("div");
    card.style.cssText = "background:" + BG + ";border:1px solid " + BORDER + ";border-radius:16px;padding:16px;margin-bottom:12px";

    /* category */
    var catLabel = document.createElement("div");
    catLabel.style.cssText = "font-size:13px;color:#888;margin-bottom:8px";
    catLabel.textContent = T("Тип обращения:", "Category:");
    card.appendChild(catLabel);

    var catRow = document.createElement("div");
    catRow.style.cssText = "display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px";
    var categories = [
      { id: "bug", label: T("Ошибка", "Bug report"), icon: "🐛" },
      { id: "idea", label: T("Предложение", "Suggestion"), icon: "💡" },
      { id: "other", label: T("Другое", "Other"), icon: "✉️" }
    ];
    var selectedCat = "idea";
    categories.forEach(function (cat) {
      var chip = document.createElement("button");
      chip.style.cssText = "padding:8px 14px;border-radius:10px;border:1px solid " + (cat.id === selectedCat ? ACCENT : BORDER) + ";background:" + (cat.id === selectedCat ? "rgba(11,132,255,.12)" : "transparent") + ";color:" + (cat.id === selectedCat ? ACCENT : "#aaa") + ";font-size:13px;cursor:pointer;transition:all .15s;display:flex;align-items:center;gap:6px";
      chip.innerHTML = cat.icon + " " + cat.label;
      chip.onclick = function () {
        selectedCat = cat.id;
        catRow.querySelectorAll("button").forEach(function (b, i) {
          var active = categories[i].id === selectedCat;
          b.style.borderColor = active ? ACCENT : BORDER;
          b.style.background = active ? "rgba(11,132,255,.12)" : "transparent";
          b.style.color = active ? ACCENT : "#aaa";
        });
      };
      catRow.appendChild(chip);
    });
    card.appendChild(catRow);

    /* message */
    var msgLabel = document.createElement("div");
    msgLabel.style.cssText = "font-size:13px;color:#888;margin-bottom:6px";
    msgLabel.textContent = T("Сообщение:", "Message:");
    card.appendChild(msgLabel);

    var textarea = document.createElement("textarea");
    textarea.style.cssText = "width:100%;min-height:120px;padding:12px;border:1px solid " + BORDER + ";border-radius:12px;background:rgba(0,0,0,.2);color:var(--foreground,#eee);font-size:14px;line-height:1.5;resize:vertical;box-sizing:border-box;outline:none;font-family:inherit";
    textarea.placeholder = T("Опишите проблему или предложение...", "Describe a problem or suggestion...");
    textarea.onfocus = function() { textarea.style.borderColor = ACCENT; };
    textarea.onblur = function() { textarea.style.borderColor = BORDER; };
    card.appendChild(textarea);

    /* email to send from */
    var emailLabel = document.createElement("div");
    emailLabel.style.cssText = "font-size:13px;color:#888;margin:12px 0 6px";
    emailLabel.textContent = T("Ваш email для ответа (необязательно):", "Your email for reply (optional):");
    card.appendChild(emailLabel);

    var emailInput = document.createElement("input");
    emailInput.type = "email";
    emailInput.style.cssText = "width:100%;padding:10px 12px;border:1px solid " + BORDER + ";border-radius:12px;background:rgba(0,0,0,.2);color:var(--foreground,#eee);font-size:14px;box-sizing:border-box;outline:none";
    emailInput.placeholder = "email@example.com";
    emailInput.onfocus = function() { emailInput.style.borderColor = ACCENT; };
    emailInput.onblur = function() { emailInput.style.borderColor = BORDER; };
    card.appendChild(emailInput);

    /* send button */
    var btnSend = document.createElement("button");
    btnSend.style.cssText = "width:100%;margin-top:16px;padding:12px;border:0;border-radius:12px;background:" + ACCENT + ";color:#fff;font-size:14px;font-weight:500;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;transition:opacity .15s";
    btnSend.onmouseenter = function() { btnSend.style.opacity = "0.85"; };
    btnSend.onmouseleave = function() { btnSend.style.opacity = "1"; };
    btnSend.innerHTML = '<svg width="18" height="18" fill="none" stroke="#fff" stroke-width="1.5" viewBox="0 0 24 24"><path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg> ' + T("Отправить", "Send");
    card.appendChild(btnSend);

    wrap.appendChild(card);

    /* recipients info */
    var info = document.createElement("div");
    info.style.cssText = "font-size:12px;color:#666;line-height:1.5";
    info.innerHTML = T("Письмо откроется в вашем почтовом приложении. Также можно написать напрямую: ", "The email will open in your mail app. You can also write directly: ") +
      '<a href="mailto:xmetalcore@outlook.com" style="color:#888;text-decoration:underline">xmetalcore@outlook.com</a>';
    wrap.appendChild(info);

    /* send action — через Intent, т.к. window.open(mailto:) не работает в WebView */
    btnSend.onclick = function () {
      var text = textarea.value.trim();
      if (!text) {
        textarea.style.borderColor = "#d64545";
        textarea.focus();
        setTimeout(function() { textarea.style.borderColor = BORDER; }, 2000);
        return;
      }
      var catName = categories.filter(function(c) { return c.id === selectedCat; })[0];
      var subject = "[Leostryx] " + (catName ? catName.label : "");
      var body = text;
      if (emailInput.value.trim()) {
        body += "\n\n---\n" + T("Ответить на: ", "Reply to: ") + emailInput.value.trim();
      }
      var mailto = "mailto:xmetalcore@outlook.com?subject=" + encodeURIComponent(subject) + "&body=" + encodeURIComponent(body);
      /* Method 1: anchor click (WebView may handle mailto) */
      var a = document.createElement("a");
      a.href = mailto;
      document.body.appendChild(a);
      a.click();
      a.remove();
      /* Method 2: rish (Shizuku) → am start Intent */
      setTimeout(function () {
        var b = bridge();
        if (b) {
          var cmd = "rish -c \"am start -a android.intent.action.SENDTO -d '" + mailto.replace(/'/g, "'\\''") + "'\"";
          b.start("termrun", btoa(cmd));
        }
      }, 400);
    };

    hostEl.appendChild(wrap);
  }
  window.__agyFeedbackMount = openFeedbackSection;

  window.__agyToolsMount = function (el) {
    if (!el) return;
    host = el;
    if (root && root.parentElement === el && el.children.length === 1) return;
    el.innerHTML = "";
    root = document.createElement("div");
    root.className = "agy-tools";
    root.setAttribute("data-agy-no-translate", "");
    root.addEventListener("click", onClick);
    el.appendChild(root);
    // Re-attach to a job that was running when the page was closed.
    if (!job) {
      var saved = null;
      try { saved = JSON.parse(store("agyToolsJob") || "null"); } catch (e) {}
      if (saved && saved.id && bridge()) {
        job = { id: saved.id, op: saved.op, arg: saved.arg, label: saved.label, log: "", rc: "", t0: saved.t0 || Date.now() };
        lastLogChange = Date.now();
        logOpen = true;
        poll();
      }
    }
    render();
    if (!loaded) loadCache();
    render();
    // Opening this page only refreshes installed status; verification is explicit.
    if (!job) refresh(false);
  };
})();


