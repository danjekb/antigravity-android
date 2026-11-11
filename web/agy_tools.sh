# agy-tools.sh — backend of Settings › Tools (Antigravity RU).
# Started only by the native AgyTools bridge:
#   bash agy-tools.sh <op> "<arg>"
# PREFIX/HOME come from the app; $PREFIX/etc/profile is already sourced.
# Machine-readable lines start with "@@" (parsed by agy_tools.js);
# everything else is the human log shown in the UI.
set -u
trap '' 36 37 2>/dev/null || true
OP="${1:-}"
shift 1 2>/dev/null || true
ARG="$*"

SDK="$HOME/android-sdk"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
NDK_REPO="lzhiyong/termux-ndk"
ENVF="$PREFIX/etc/profile.d/60-agy-android.sh"
AGENTS="$PREFIX/etc/antigravity/AGENTS.md"

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
fail() { printf '@@error %s\n' "$*"; exit 1; }

# pkg_retry <cmd...> — retry a pkg/network command on transient failures.
# Mobile/VPN links routinely reset connections (curl error 35 "Recv failure"),
# which pkg surfaces as "download failed"; most installs succeed on a retry.
pkg_retry() {
    local n=1 max=3 rc refreshed=0
    if [ "${1:-}" = pkg ] && { [ "${2:-}" = install ] || [ "${2:-}" = upgrade ]; }; then
        local fetch_dst="$PREFIX/libexec/pkg/lib/fetch.sh"
        if [ -f "$fetch_dst" ]; then
            cat > "$fetch_dst.agy-new" <<'AGY_PKG_FETCH_EOF'
#!/usr/bin/env bash
# fetch.sh -- download with sha256 verification and cache.
# Requires curl, sha256sum, log, die.

# human_size BYTES
human_size() {
    local bytes="$1"
    if [ -z "$bytes" ] || [ "$bytes" -le 0 ] 2>/dev/null; then
        echo ""
    elif [ "$bytes" -ge 1048576 ]; then
        awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b / 1048576 }'
    elif [ "$bytes" -ge 1024 ]; then
        awk -v b="$bytes" 'BEGIN { printf "%d kB", (b + 1023) / 1024 }'
    else
        printf '%d B' "$bytes"
    fi
}

# fetch URL SHA256 OUT [SIZE] [GET_INDEX]
fetch() {
    local url="$1" sha="$2" out="$3" size="${4:-}" idx="${5:-1}" have sz_str="" http_code curl_status
    if [ -f "$out" ] && [ -n "$sha" ]; then
        have="$(sha256sum "$out" | cut -d' ' -f1)"
        if [ "$have" = "$sha" ]; then
            return 0
        fi
    fi
    mkdir -p "$(dirname "$out")"
    if [ -n "$size" ]; then
        sz_str=" [$(human_size "$size")]"
    fi
    printf 'Get:%s %s%s\n' "$idx" "$url" "$sz_str"
    # Do not retry a permanent HTTP 404 six times. The caller can refresh
    # repository metadata once and retry the package using the new index.
    http_code=$(curl -# -fL --retry 3 --retry-delay 2 --retry-max-time 120 \
        --connect-timeout 20 --cacert "$PKG_CERT" -o "$out.part" \
        -w '%{http_code}' "$url") && curl_status=0 || curl_status=$?
    # The index contains a SHA-256, so an identical package can be fetched
    # safely from this listed Termux mirror if the primary returns 404.
    if [ "$curl_status" -ne 0 ] && [ "$http_code" = 404 ] && [ -n "$sha" ]; then
        case "$url" in
            https://packages-cf.termux.dev/apt/termux-main/*|https://packages.termux.dev/apt/termux-main/*)
                local rel mirror_url
                rel="${url#*/apt/termux-main/}"
                mirror_url="https://mirrors.bfsu.edu.cn/termux/apt/termux-main/$rel"
                printf 'Primary returned 404; trying a listed Termux mirror.\n' >&2
                rm -f "$out.part"
                http_code=$(curl -# -fL --retry 2 --retry-delay 2 --retry-max-time 120 \
                    --connect-timeout 20 --cacert "$PKG_CERT" -o "$out.part" \
                    -w '%{http_code}' "$mirror_url") && curl_status=0 || curl_status=$?
                ;;
        esac
    fi
    if [ "$curl_status" -ne 0 ]; then
        rm -f "$out.part"
        if [ "$http_code" = 404 ]; then
            printf 'pkg: error: HTTP 404: %s\n' "$url" >&2
            exit 44
        fi
        die "download failed: $url (curl $curl_status, HTTP ${http_code:-unknown})"
    fi
    if [ -n "$sha" ]; then
        have="$(sha256sum "$out.part" | cut -d' ' -f1)"
        [ "$have" = "$sha" ] || { rm -f "$out.part"; die "sha256 mismatch $(basename "$out"): got $have want $sha"; }
    fi
    mv "$out.part" "$out"
}
AGY_PKG_FETCH_EOF
            if cmp -s "$fetch_dst.agy-new" "$fetch_dst"; then rm -f "$fetch_dst.agy-new"; else mv -f "$fetch_dst.agy-new" "$fetch_dst" || return 1; fi
        fi
    fi
    while :; do
        "$@" && return 0 || rc=$?
        if [ "$rc" -eq 44 ]; then
            if [ "$refreshed" -eq 0 ] && [ "${1:-}" = pkg ] && [ "${2:-}" = install ]; then
                refreshed=1
                step "Package not found (HTTP 404); refreshing repository index once"
                pkg update || return 44
                continue
            fi
            return 44
        fi
        [ "$n" -ge "$max" ] && return 1
        n=$((n + 1))
        step "transient failure, retry $n/$max"
        sleep $((n * 3))
    done
}

index_fresh() {
    # pkg index younger than 6 hours?
    local f
    f="$(ls -t "$PREFIX"/var/lib/pkg/index/repo.*.Packages "$HOME"/.pkg/index/repo.*.Packages 2>/dev/null | head -n1)"
    [ -n "$f" ] || return 1
    [ -n "$(find "$f" -mmin -360 2>/dev/null)" ]
}
ensure_index() {
    if ! index_fresh; then
        step "pkg update"
        pkg_retry pkg update || fail "pkg update"
    fi
}

write_env() {
    mkdir -p "$(dirname "$ENVF")"
    cat > "$ENVF" <<EOF
# Written by Settings › Tools. Android SDK / NDK / Java for shells and Gradle.
export ANDROID_HOME="$SDK"
export ANDROID_SDK_ROOT="$SDK"
[ -d "$SDK/cmdline-tools/latest/bin" ] && export PATH="\$PATH:$SDK/cmdline-tools/latest/bin"
for _d in "$SDK"/ndk/*/; do [ -d "\$_d" ] && export ANDROID_NDK_HOME="\${_d%/}" ANDROID_NDK_ROOT="\${_d%/}"; done; unset _d
[ -n "\${JAVA_HOME:-}" ] && [ ! -x "\$JAVA_HOME/bin/java" ] && unset JAVA_HOME
[ -z "\${JAVA_HOME:-}" ] && [ -x "$PREFIX/lib/jvm/java-21-openjdk/bin/java" ] && export JAVA_HOME="$PREFIX/lib/jvm/java-21-openjdk"
[ -z "\${JAVA_HOME:-}" ] && [ -x "$PREFIX/lib/jvm/java-17-openjdk/bin/java" ] && export JAVA_HOME="$PREFIX/lib/jvm/java-17-openjdk"
[ -n "\${JAVA_HOME:-}" ] && [ -x "\$JAVA_HOME/bin/java" ] && export PATH="\$JAVA_HOME/bin:\$PATH"
[ -d "$HOME/flutter_sdk/bin" ] && export PATH="$HOME/flutter_sdk/bin:\$PATH" && export FLUTTER_ROOT="$HOME/flutter_sdk"
export GRADLE_USER_HOME="\$HOME/.gradle"
EOF
    mkdir -p "$HOME/.gradle" "$PREFIX/tmp"
    local gp="$HOME/.gradle/gradle.properties"
    touch "$gp"
    if [ -x "$PREFIX/bin/aapt2" ]; then
        grep -q '^android.aapt2FromMavenOverride=' "$gp" \
            && sed -i "s#^android.aapt2FromMavenOverride=.*#android.aapt2FromMavenOverride=$PREFIX/bin/aapt2#" "$gp" \
            || printf 'android.aapt2FromMavenOverride=%s\n' "$PREFIX/bin/aapt2" >> "$gp"
    fi
    grep -q '^org.gradle.daemon=' "$gp" || printf 'org.gradle.daemon=false\n' >> "$gp"
    grep -q '^org.gradle.native=' "$gp" || printf 'org.gradle.native=false\n' >> "$gp"
    grep -q '^org.gradle.jvmargs=' "$gp" || printf 'org.gradle.jvmargs=-Xmx1536m\n' >> "$gp"
    # Keep existing JVM options and add only missing Android-specific paths.
    local gp_tmp="$gp.agy-tmp-$$"
    awk -v tmp="$PREFIX/tmp" -v home="$HOME" '
      /^org[.]gradle[.]jvmargs=/ {
        if ($0 !~ /(^|[[:space:]])-Djava[.]io[.]tmpdir=/) $0=$0 " -Djava.io.tmpdir=" tmp
        if ($0 !~ /(^|[[:space:]])-Duser[.]home=/) $0=$0 " -Duser.home=" home
      } {print}
    ' "$gp" > "$gp_tmp" && mv "$gp_tmp" "$gp" || { rm -f "$gp_tmp"; fail "update Gradle JVM paths"; }
    # Let the agent know where everything is.
    if [ -f "$AGENTS" ] && ! grep -q 'AGY-TOOLS-ANDROID' "$AGENTS"; then
        cat >> "$AGENTS" <<EOF

<!-- AGY-TOOLS-ANDROID -->
## Android toolchain (installed from Settings › Tools)
- Before Gradle/SDK/NDK commands run: \`. "\$PREFIX/etc/profile.d/60-agy-android.sh"\` (sets ANDROID_HOME, JAVA_HOME, ANDROID_NDK_HOME).
- Android SDK: \`$SDK\` (write \`sdk.dir=$SDK\` into a project's local.properties).
- aapt2 is the native Termux build; Gradle uses it via android.aapt2FromMavenOverride in ~/.gradle/gradle.properties.
- Build with \`gradle assembleDebug --no-daemon\` or \`bash ./gradlew assembleDebug --no-daemon\` (never \`./gradlew\`: /bin/sh does not exist on Android).
- node, npm, java, gradle, sdkmanager, ndk-build, npm global CLIs have bridges in runtime/bin that load this environment automatically.
EOF
    fi
    if [ -f "$AGENTS" ] && ! grep -q 'AGY-KMP-COMPAT' "$AGENTS"; then
        cat >> "$AGENTS" <<'EOF'

<!-- AGY-KMP-COMPAT -->
## KMP/Compose compatibility
- Match compileSdk to the requirements of the project's dependencies; install the corresponding Android platform before building.
- When an older KMP androidTarget() project encounters AGP 9 new-DSL or built-in Kotlin conflicts, consult project compatibility and consider android.newDsl=false and android.builtInKotlin=false in that project's gradle.properties. Do not set them globally.
- For Gradle launcher issues on Android, check JAVA_TOOL_OPTIONS for user.home and java.io.tmpdir and use the configured Gradle bridge; keep project JVM options and build logs for diagnosis.
EOF
    fi
}

# ------------------------------------------------------------ agent bridges
# The agent's shell runs with the core environment: runtime/bin first, no
# LD_LIBRARY_PATH / LD_PRELOAD. pkg creates runtime/bin bridges only for binaries
# of packages it installs. Tools that come from npm, sdkmanager or the NDK (and
# scripts with "#!/usr/bin/env" / "#!/bin/sh" shebangs, which do not exist on
# Android) need bridges of their own; the Android/Java env is loaded in each.
RB="$PREFIX/../runtime/bin"
BRIDGED="node npm npx corepack yarn pnpm pnpx tsc tsserver java javac javap jdeps jshell jar keytool kotlin kotlinc gradle mvn sdkmanager avdmanager apkanalyzer lint ndk-build aapt aapt2 aidl d8 apksigner zipalign adb apktool jadx"
make_bridge() { # name
    local name="$1" target="$PREFIX/bin/$1" first runner="" tmp="$RB/.agy-bridge-$1-$$"
    [ -e "$target" ] || return 0
    [ -d "$RB" ] || return 0
    first="$(head -c 160 "$(readlink -f "$target")" 2>/dev/null | tr -d "\000" | head -n 1)"
    case "$first" in
        "#!"*node*)            runner='"$PREFIX/bin/node" ' ;;
        "#!"*sh*|"#!"*bash*)   runner='"$PREFIX/bin/bash" ' ;;
    esac
    cat > "$tmp" <<EOF
#!/system/bin/sh
# AGY tools bridge -> \$PREFIX/bin/$name
PREFIX='$PREFIX'
export PREFIX TERMUX__PREFIX="\$PREFIX"
[ -f "\$PREFIX/lib/libtermux-exec.so" ] && export LD_PRELOAD="\$PREFIX/lib/libtermux-exec.so"
export LD_LIBRARY_PATH="\$PREFIX/lib"
case "$name" in
  java|javac|javap|jdeps|jshell|jar|keytool|kotlin|kotlinc|gradle|mvn|sdkmanager|avdmanager|apkanalyzer|lint|d8|apksigner|apktool|jadx)
    case " \${JAVA_TOOL_OPTIONS:-} " in *" -Duser.home="*) ;; *) JAVA_TOOL_OPTIONS="\${JAVA_TOOL_OPTIONS:+\$JAVA_TOOL_OPTIONS }-Duser.home=\$HOME" ;; esac
    case " \$JAVA_TOOL_OPTIONS " in *" -Djava.io.tmpdir="*) ;; *) JAVA_TOOL_OPTIONS="\$JAVA_TOOL_OPTIONS -Djava.io.tmpdir=\$PREFIX/tmp" ;; esac
    export JAVA_TOOL_OPTIONS ;;
esac
case "$name" in
  gradle) case " \${GRADLE_OPTS:-} " in *" -Dorg.gradle.native="*) ;; *) export GRADLE_OPTS="\${GRADLE_OPTS:+\$GRADLE_OPTS }-Dorg.gradle.native=false" ;; esac ;;
esac
export PATH="\$PREFIX/../runtime/bin:\$PREFIX/bin:/system/bin"
TMPDIR="\$PREFIX/tmp"; export TMPDIR
export OPENSSL_CONF="\$PREFIX/etc/tls/openssl.cnf" SSL_CERT_FILE="\$PREFIX/etc/tls/cert.pem" CURL_CA_BUNDLE="\$PREFIX/etc/tls/cert.pem"
[ -f "\$PREFIX/etc/profile.d/60-agy-android.sh" ] && . "\$PREFIX/etc/profile.d/60-agy-android.sh"
# Resolve symlinks: scripts like ndk-build locate their resources via \$0.
exec $runner"\$(readlink -f "\$PREFIX/bin/$name")" "\$@"
EOF
    chmod 755 "$tmp" && mv -f "$tmp" "$RB/$name" || { rm -f "$tmp"; fail "bridge $name"; }
}
refresh_build_tools() {
    local bt t dest target
    for bt in "$SDK"/build-tools/*; do
        [ -d "$bt" ] || continue
        for t in aapt aapt2 aidl zipalign d8 apksigner; do
            target="$PREFIX/bin/$t"; dest="$bt/$t"
            [ -x "$target" ] || continue
            [ "$(readlink "$dest" 2>/dev/null || true)" = "$target" ] && continue
            # Preserve original SDK executables or user-created wrappers once.
            if [ -e "$dest" ] && [ ! -L "$dest" ] && [ ! -e "$dest.agy-original" ]; then
                cp -p "$dest" "$dest.agy-original" || fail "backup $dest"
            fi
            ln -sf "$target" "$dest.agy-new" || fail "prepare $dest"
            mv -f "$dest.agy-new" "$dest" || fail "update $dest"
        done
    done
}
refresh_bridges() {
    # Restore entry points omitted by package post-install scripts when the
    # actual executable exists. Never replace an existing working command.
    local j target selected existing
    selected="${JAVA_HOME:-}"
    if [ -z "$selected" ] || [ ! -x "$selected/bin/java" ]; then
        selected=""
        for target in "$PREFIX/lib/jvm/java-21-openjdk" "$PREFIX/lib/jvm/java-17-openjdk"; do
            if [ -x "$target/bin/java" ]; then selected="$target"; break; fi
        done
    fi
    for j in java javac javap jdeps jshell jar keytool; do
        [ -n "$selected" ] && [ -x "$selected/bin/$j" ] || continue
        # Replace only missing or previously generated links into the JDK tree.
        if [ -L "$PREFIX/bin/$j" ]; then
            existing="$(readlink -f "$PREFIX/bin/$j" 2>/dev/null || true)"
            case "$existing" in "$PREFIX"/lib/jvm/*/bin/"$j") ln -sf "$selected/bin/$j" "$PREFIX/bin/$j" ;; esac
        elif [ ! -e "$PREFIX/bin/$j" ]; then
            ln -s "$selected/bin/$j" "$PREFIX/bin/$j"
        fi
    done
    for j in npm npx; do
        target="$PREFIX/lib/node_modules/npm/bin/$j-cli.js"
        if [ ! -e "$PREFIX/bin/$j" ] && [ -f "$target" ]; then ln -sf "$target" "$PREFIX/bin/$j"; fi
    done
    # SDK / NDK entry points into $PREFIX/bin first.
    local t
    for t in sdkmanager avdmanager apkanalyzer lint; do
        [ -e "$SDK/cmdline-tools/latest/bin/$t" ] && [ ! -e "$PREFIX/bin/$t" ] && ln -s "$SDK/cmdline-tools/latest/bin/$t" "$PREFIX/bin/$t"
    done
    for t in "$SDK"/ndk/*/ndk-build; do [ -e "$t" ] && ln -sf "$t" "$PREFIX/bin/ndk-build"; done
    refresh_build_tools
    local n
    for n in $BRIDGED; do make_bridge "$n"; done
    # npm globals that are not in the list (new CLIs) get bridges too.
    if [ -d "$PREFIX/lib/node_modules" ]; then
        for t in "$PREFIX"/bin/*; do
            case "$(readlink "$t" 2>/dev/null)" in
                *node_modules*) make_bridge "$(basename "$t")" ;;
            esac
        done
    fi
}

# ------------------------------------------------------------ status
op_status() {
    # Fast: read pkg's own index/db files with one awk each (no pkg calls,
    # no network). Index is refreshed only by install/upgrade.
    local IDX="$PREFIX/var/lib/pkg/index" DB="$PREFIX/var/lib/pkg/installed"
    # Ensure TSV index exists if Packages file is available; fetch index if missing
    if [ -z "$(ls "$IDX"/repo.*.tsv 2>/dev/null)" ]; then
        for f in "$IDX"/repo.*.Packages "$HOME"/.pkg/index/repo.*.Packages; do
            [ -s "$f" ] && awk -f "$PREFIX/libexec/pkg/lib/index.awk" "$f" > "${f%.Packages}.tsv" 2>/dev/null || true
        done
    fi
    if [ -z "$(ls "$IDX"/repo.*.tsv "$IDX"/repo.*.Packages 2>/dev/null)" ]; then
        ensure_index 2>/dev/null || true
    fi
    local names="${ARG//,/ }"
    {
        # available: repo.N.tsv  (name<TAB>version<TAB>...)
        cat "$IDX"/repo.*.tsv 2>/dev/null | awk -F'\t' '{print "A\t"$1"\t"$2}'
        # installed by pkg: <name>.meta with version= (parsed fast in single awk)
        [ -d "$DB" ] && awk '
            FNR == 1 { n = FILENAME; sub(".*/", "", n); sub("[.]meta$", "", n); }
            /^version=/ && !(n in seen) { sub("^version=", ""); print "I\t" n "\t" $0; seen[n] = 1; }
        ' "$DB"/*.meta 2>/dev/null
        # installed by the bootstrap (dpkg status)
        [ -f "$PREFIX/var/lib/dpkg/status" ] && awk '
            /^Package:/ {p=$2} /^Version:/ {v=$2}
            /^Status:.*installed/ {s=1}
            /^$/ {if (s && p != "" && v != "") print "I\t"p"\t"v; p=""; v=""; s=0}' "$PREFIX/var/lib/dpkg/status"
    } | awk -F'\t' -v want="$names" '
        BEGIN { n = split(want, w, " "); for (i = 1; i <= n; i++) need[w[i]] = 1 }
        $1 == "A" && ($2 in need) { av[$2] = $3 }
        $1 == "I" && ($2 in need) { iv[$2] = $3 }
        END { for (k in need) printf "@@pkg %s %s %s\n", k, (k in av ? av[k] : "-"), (k in iv ? iv[k] : "-") }'
    [ -n "$(ls "$IDX"/repo.*.tsv "$IDX"/repo.*.Packages 2>/dev/null)" ] && say "@@index ok" || say "@@index -"
    [ -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ] && say "@@special cmdline-tools ok" || say "@@special cmdline-tools -"
    local p
    for p in "$SDK"/platforms/android-*; do
        [ -d "$p" ] || continue
        if [ -s "$p/android.jar" ] && [ -s "$p/source.properties" ]; then say "@@special platform $(basename "$p")"; else say "@@special platform $(basename "$p") incomplete"; fi
    done
    for p in "$SDK"/build-tools/*; do
        [ -d "$p" ] || continue
        if [ -s "$p/source.properties" ] && [ -s "$p/lib/d8.jar" ] && [ -s "$p/core-lambda-stubs.jar" ]; then say "@@special build-tools $(basename "$p")"; else say "@@special build-tools $(basename "$p") incomplete"; fi
    done
    for p in "$SDK"/ndk/*; do [ -d "$p" ] && say "@@special ndk $(basename "$p")"; done
    if [ -x "$HOME/flutter_sdk/bin/flutter" ] && [ -x "$HOME/flutter_sdk/bin/cache/dart-sdk/bin/dart" ] && [ -f "$HOME/flutter_sdk/bin/cache/flutter_tools.snapshot" ]; then say "@@special flutter ok"; else say "@@special flutter -"; fi
    command -v pnpm >/dev/null 2>&1 && say "@@npm pnpm ok" || say "@@npm pnpm -"
    command -v tsc  >/dev/null 2>&1 && say "@@npm typescript ok" || say "@@npm typescript -"
    say "@@done"
}
op_index() { step "pkg update"; pkg_retry pkg update || fail "pkg update"; say "@@done"; }

# ------------------------------------------------------------ install / remove / upgrade
sync_resolver() {
    local src="$PREFIX/../web/agy_resolver.sh" dst="$PREFIX/libexec/pkg/lib/resolver.sh"
    [ -s "$src" ] && [ -f "$dst" ] || fail "dependency resolver is missing"
    if ! cmp -s "$src" "$dst"; then
        cp "$src" "$dst.agy-new" && mv -f "$dst.agy-new" "$dst" || fail "cannot update dependency resolver"
    fi
}
node_package_installed() {
    [ -f "$PREFIX/var/lib/pkg/installed/$1.meta" ] ||
    awk -v pkg="$1" 'BEGIN{p=0} /^Package: /{p=($2==pkg)} p && /^Status: .* installed$/{found=1} END{exit !found}' "$PREFIX/var/lib/dpkg/status" 2>/dev/null
}
check_node_conflicts() {
    local n
    case " $ARG " in *" nodejs "*) case " $ARG " in *" nodejs-lts "*) fail "Node.js variants cannot be installed together; select one" ;; esac ;; esac
    for n in $ARG; do
        case "$n" in
            nodejs-lts) if ! node_package_installed nodejs-lts && node_package_installed nodejs; then fail "Node.js current is already installed; select one version before switching"; fi ;;
            nodejs) if ! node_package_installed nodejs && node_package_installed nodejs-lts; then fail "Node.js LTS is already installed; select one version before switching"; fi ;;
        esac
    done
}
op_install() {
    [ -n "$ARG" ] || fail "nothing to install"
    ensure_index
    sync_resolver
    check_node_conflicts
    step "pkg install $ARG"
    # shellcheck disable=SC2086
    if ! pkg_retry pkg install $ARG; then
        step "batch install failed; retrying package by package"
        local p ok=1 preferred_node=""
        case " $ARG " in *" nodejs-lts "*) preferred_node=nodejs-lts ;; *" nodejs "*) preferred_node=nodejs ;; esac
        if [ -n "$preferred_node" ]; then
            step "pkg install $preferred_node (selected Node.js version first)"
            pkg_retry pkg install "$preferred_node" || fail "selected Node.js installation failed; remaining packages were not installed"
        fi
        for p in $ARG; do
            [ "$p" = "$preferred_node" ] && continue
            step "pkg install $p"
            pkg_retry pkg install "$p" || { ok=0; say "@@warn failed: $p"; }
        done
        [ "$ok" = "1" ] || fail "pkg install (some packages failed)"
    fi
    case " $ARG " in
        *" nodejs "*|*" nodejs-lts "*)
            step "pkg install npm"
            pkg_retry pkg install npm || fail "npm installation failed"
            ;;
    esac
    # pkg rewrites paths per extracted package. Rescanning the whole prefix here
    # duplicates that work and can take minutes for large SDK/node trees.
    case " $ARG " in
        *" nodejs"*)
            npm config set prefix "$PREFIX" >/dev/null 2>&1 || true ;;
    esac
    write_env
    refresh_bridges
    case " $ARG " in
        *" nodejs "*|*" nodejs-lts "*)
            "$RB/node" --version || fail "Node.js verification failed"
            "$RB/npm" --version || fail "npm verification failed"
            ;;
    esac
    say "@@done"
}
op_remove() {
    [ -n "$ARG" ] || fail "nothing to remove"
    step "pkg remove $ARG"
    # shellcheck disable=SC2086
    pkg remove $ARG || fail "pkg remove"
    say "@@done"
}
# AGY-P2-11: сводка обновлений (JSON) для предпоказа перед pkg upgrade
op_pkgstats() {
    python3 - "$PREFIX/var/lib/pkg" <<'PSEOF'
import os, sys, json
base = sys.argv[1]
try:
    inst = {}
    d = os.path.join(base, "installed")
    for f in os.listdir(d):
        if f.endswith(".meta"):
            meta = {}
            for line in open(os.path.join(d, f)):
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    meta[k] = v
            inst[meta.get("name", f[:-5])] = meta.get("version", "")
    avail = {}
    for line in open(os.path.join(base, "index", "repo.1.tsv")):
        p = line.rstrip("\n").split("\t")
        if len(p) >= 11:
            avail[p[0]] = (p[1], int(p[9]))
    upd = [(n, v, avail[n][0], avail[n][1]) for n, v in inst.items()
           if n in avail and avail[n][0] != v]
    print(json.dumps({"rc": "0", "count": len(upd), "bytes": sum(u[3] for u in upd)}))
except Exception as e:
    print(json.dumps({"rc": "1", "error": str(e)}))
PSEOF
}
op_upgrade() {
    step "pkg update"; pkg_retry pkg update || fail "pkg update"
    step "pkg upgrade"; pkg_retry pkg upgrade || fail "pkg upgrade"
    # pkg upgrade rewrites each package during extraction.
    write_env
    refresh_bridges
    say "@@done"
}
op_npm() {
    # Global npm packages, e.g. "pnpm typescript"
    command -v npm >/dev/null 2>&1 || fail "npm missing: install Node.js first"
    # TypeScript 7+ ships a native per-platform binary (tsgo) that has no
    # Android build (process.platform = "android"), so tsc crashes there.
    # Pin the pure-JS 5.x compiler, which runs everywhere.
    local pkgs="" p
    for p in $ARG; do
        case "$p" in
            typescript) pkgs="$pkgs typescript@5" ;;
            *)          pkgs="$pkgs $p" ;;
        esac
    done
    step "npm install -g$pkgs"
    # shellcheck disable=SC2086
    pkg_retry npm install -g --fetch-retries=5 --fetch-retry-maxtimeout=60000$pkgs || fail "npm install"
    step "Fix paths in npm tools"
    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" || fail "fix paths"
    refresh_bridges
    for p in $ARG; do
        case "$p" in
            typescript) step "Verify TypeScript compiler"; "$RB/tsc" --version || fail "TypeScript compiler verification failed" ;;
            pnpm) step "Verify pnpm"; "$RB/pnpm" --version || fail "pnpm verification failed" ;;
        esac
    done
    say "@@done"
}

# ------------------------------------------------------------ Android SDK
need_java() {
    if ! command -v java >/dev/null 2>&1; then
        ensure_index
        step "pkg install openjdk-17 (required by sdkmanager)"
        pkg_retry pkg install openjdk-17 || fail "openjdk-17"
    fi
    write_env
    . "$ENVF"
}
op_sdk() {
    need_java
    mkdir -p "$SDK"
    if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
        step "Download Android command-line tools"
        local z="$PREFIX/tmp/cmdline-tools.zip" stage
        [ ! -e "$SDK/cmdline-tools/latest" ] || fail "Existing cmdline-tools/latest is incomplete; preserved for inspection"
        curl -# -fL --retry 5 --retry-all-errors --retry-delay 3 --retry-max-time 600 -o "$z" "$CMDLINE_URL" || fail "download cmdline-tools"
        mkdir -p "$SDK/cmdline-tools"
        stage="$(mktemp -d "$PREFIX/tmp/agy-cmdline.XXXXXX")" || fail "create temporary directory"
        if ! unzip -q "$z" -d "$stage" || [ ! -f "$stage/cmdline-tools/bin/sdkmanager" ]; then
            rm -rf "$stage"
            fail "invalid cmdline-tools archive"
        fi
        mv "$stage/cmdline-tools" "$SDK/cmdline-tools/latest" || fail "move cmdline-tools"
        rmdir "$stage" 2>/dev/null || true
        rm -f "$z"
    fi
    write_env
    . "$ENVF"
    local comps="${ARG:-platforms;android-35 build-tools;35.0.0}"
    # API 37.x lives in the canary channel (channel 3); add --channel=3 automatically
    local channel_flag=""
    case "$comps" in
        *android-37*|*build-tools\;37*) channel_flag="--channel=3" ;;
    esac
    step "Accept licenses"
    yes | bash "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" $channel_flag --licenses || fail "sdkmanager license acceptance failed"
    step "sdkmanager $comps"
    # shellcheck disable=SC2086
    bash "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" $channel_flag $comps || fail "sdkmanager"
    refresh_bridges
    local component dir
    for component in $comps; do
        case "$component" in
            platforms\;*) dir="$SDK/platforms/${component#*;}"; [ -s "$dir/android.jar" ] && [ -s "$dir/source.properties" ] || fail "$component: missing android.jar or source.properties" ;;
            build-tools\;*) dir="$SDK/build-tools/${component#*;}"; [ -s "$dir/source.properties" ] && [ -s "$dir/lib/d8.jar" ] && [ -s "$dir/core-lambda-stubs.jar" ] || fail "$component: missing SDK files; installation needs inspection" ;;
        esac
    done
    say "@@done"
}
op_sdkremove() {
    [ -n "$ARG" ] || fail "nothing to remove"
    . "$ENVF" 2>/dev/null || true
    # shellcheck disable=SC2086
    bash "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --uninstall $ARG || fail "sdkmanager --uninstall"
    say "@@done"
}

# ------------------------------------------------------------ NDK (Termux build for aarch64)
op_ndk() {
    ensure_index
    command -v unzip >/dev/null 2>&1 || pkg install unzip || fail "unzip"
    command -v tar   >/dev/null 2>&1 || pkg install tar   || fail "tar"
    step "Find latest $NDK_REPO release"
    local api url name tag
    api="$(curl -fsSL "https://api.github.com/repos/$NDK_REPO/releases/latest" 2>/dev/null || true)"
    # Releases ship .tar.xz (and historically .zip); match either.
    url="$(printf '%s' "$api" | grep -o '"browser_download_url": *"[^"]*aarch64[^"]*\.\(zip\|tar\.xz\|tar\.gz\)"' | head -n1 | sed 's/.*"\(http[^"]*\)"/\1/')"
    if [ -z "$url" ]; then
        # GitHub API may be rate-limited: follow the /releases/latest redirect
        # and scrape the expanded assets page for the aarch64 archive.
        step "GitHub API empty; fallback to release page"
        tag="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$NDK_REPO/releases/latest" 2>/dev/null | sed 's#.*/tag/##')"
        [ -n "$tag" ] || fail "GitHub API"
        url="$(curl -fsSL "https://github.com/$NDK_REPO/releases/expanded_assets/$tag" 2>/dev/null \
            | grep -o 'href="[^"]*aarch64[^"]*\.\(zip\|tar\.xz\|tar\.gz\)"' | head -n1 \
            | sed 's/^href="//; s/"$//; s#^#https://github.com#')"
    fi
    [ -n "$url" ] || fail "no aarch64 NDK asset in the latest release"
    name="$(basename "$url")"
    step "Download $name (large, ~1 GB)"
    mkdir -p "$SDK/ndk"
    local z="$PREFIX/tmp/$name"
    curl -# -fL --retry 5 --retry-all-errors --retry-delay 3 --retry-max-time 1800 -C - -o "$z" "$url" \
        || curl -# -fL --retry 5 --retry-all-errors --retry-delay 3 --retry-max-time 1800 -o "$z" "$url" \
        || fail "download NDK"
    step "Unpack"
    case "$name" in
        *.tar.xz|*.txz) tar -xJf "$z" -C "$SDK/ndk" || fail "unpack NDK" ;;
        *.tar.gz|*.tgz) tar -xzf "$z" -C "$SDK/ndk" || fail "unpack NDK" ;;
        *.zip)          unzip -q -o "$z" -d "$SDK/ndk" || fail "unzip NDK" ;;
        *)              fail "unsupported archive: $name" ;;
    esac
    rm -f "$z"
    write_env
    refresh_bridges
    say "@@done"
}
op_ndkremove() {
    rm -rf "$SDK/ndk"
    write_env
    say "@@done"
}
op_flutter() {
    ensure_index
    step "Installing required dependencies for Flutter (git, curl, unzip, tar, xz-utils, python, dart)"
    pkg_retry pkg install git curl unzip tar xz-utils python dart || fail "dependencies for flutter"
    step "Installing Flutter SDK (stable branch)"
    local FSDK="$HOME/flutter_sdk"
    if [ -d "$FSDK/.git" ]; then
        step "Using existing Flutter SDK checkout (local changes preserved)"
    elif [ -d "$FSDK" ]; then
        fail "Existing Flutter directory is not a git checkout; preserved at $FSDK"
    else
        git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FSDK" || fail "git clone flutter"
    fi
    export FLUTTER_ROOT="$FSDK"
    write_env
    # A fresh clone has no Dart cache. Download the exact engine-pinned SDK
    # before checking its version; invoking flutter itself here would try to
    # execute the downloaded Linux/glibc Dart binary on Android.
    if [ ! -s "$FSDK/bin/cache/dart-sdk/version" ]; then
        [ ! -L "$FSDK/bin/cache/dart-sdk" ] || fail "Flutter Dart symlink is broken; inspect before retrying"
        step "Preparing Flutter engine and Dart SDK metadata"
        export FLUTTER_ROOT="$FSDK"
        bash "$FSDK/bin/internal/update_engine_version.sh" || fail "Flutter engine metadata preparation failed"
        bash "$FSDK/bin/internal/update_dart_sdk.sh" || fail "Flutter Dart SDK preparation failed"
        [ -s "$FSDK/bin/cache/dart-sdk/version" ] || fail "Flutter Dart version unavailable after preparation"
    fi
    step "Running Antigravity Flutter/Dart bionic patcher (agy-fix-flutter)"
    agy-fix-flutter || fail "Flutter compatibility patch failed; inspect the log"
    export PATH="$FSDK/bin:$PATH"
    step "Verifying Flutter startup (first run may take several minutes)"
    "$FSDK/bin/flutter" --version || fail "Flutter startup failed; inspect the log"
    refresh_bridges
    say "@@done"
}
op_flutterremove() {
    step "Removing Flutter SDK"
    rm -rf "$HOME/flutter_sdk"
    write_env
    refresh_bridges
    say "@@done"
}

# ------------------------------------------------------------ shield policies
# op_policy "<field>[=<value>]" — read/write userSettings in config.json.
# The 2.4.1 JS settings store cannot round-trip these fields (its schema
# predates internetAccessPolicy etc.), so agy_shield.js persists every pick
# here; the Go core watches the file and applies the values.
op_policy() {
    local cfg="$HOME/.gemini/config/config.json"
    [ -f "$cfg" ] || fail "no config.json"
    python3 - "$cfg" "$ARG" <<'PY' || fail "policy write"
import json, os, sys
cfg, arg = sys.argv[1], sys.argv[2]
FIELDS = {
    "autoExecutionPolicy": "enum",
    "enableTerminalSandbox": "bool",
    "nonWorkspaceFileAccessPolicy": "enum",
    "internetAccessPolicy": "enum",
    "browserJsExecutionPolicy": "enum",
}
try:
    with open(cfg) as f:
        d = json.load(f)
except Exception as e:
    print("@@error config: %s" % e)
    raise SystemExit(1)
us = d.setdefault("userSettings", {})
if arg.startswith("init,"):
    for item in arg[5:].split(","):
        if "=" not in item:
            raise SystemExit(1)
        field, val = item.split("=", 1)
        if field not in FIELDS or not val:
            raise SystemExit(1)
        current = us.get(field)
        if current is None or current == "" or (not isinstance(current, bool) and current == 0) or (isinstance(current, str) and current.endswith("_UNSPECIFIED")):
            us[field] = (val.lower() == "true") if FIELDS[field] == "bool" else val
    tmp = cfg + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
    os.replace(tmp, cfg)
elif arg:
    if "=" not in arg:
        print("@@error usage: policy field=value")
        raise SystemExit(1)
    field, val = arg.split("=", 1)
    if field not in FIELDS:
        print("@@error unknown field: %s" % field)
        raise SystemExit(1)
    if FIELDS[field] == "bool":
        us[field] = val.strip().lower() in ("1", "true", "yes", "on")
    else:
        us[field] = val
    tmp = cfg + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
    os.replace(tmp, cfg)
for field in FIELDS:
    v = us.get(field, "")
    if isinstance(v, bool):
        v = "true" if v else "false"
    print("@@kv %s %s" % (field, v))
PY
    say "@@done"
}

# ------------------------------------------------------------ verify
op_verify() {
    local ok=0 bad=0
    verify_aidl() {
        local dir rc
        dir="$(mktemp -d "$PREFIX/tmp/agy-aidl-XXXXXX")" || return 1
        mkdir -p "$dir/com/agytest" "$dir/out" || { rm -rf "$dir"; return 1; }
        printf 'package com.agytest; interface ITest { int getVersion(); }\n' > "$dir/com/agytest/ITest.aidl"
        aidl -I"$dir" "$dir/com/agytest/ITest.aidl" -o "$dir/out"
        rc=$?
        if [ "$rc" -eq 0 ] && [ -s "$dir/out/com/agytest/ITest.java" ]; then echo "AIDL compilation succeeded"; else rc=1; echo "AIDL compilation failed or output is missing"; fi
        rm -rf "$dir"
        return "$rc"
    }
    chk() { # name, command...
        local name="$1"; shift
        local out code tmp="$PREFIX/tmp/agy-verify-$$-$name"
        mkdir -p "$PREFIX/tmp"
        "$@" >"$tmp" 2>&1; code=$?
        out="$(head -n 2 "$tmp" | tr '\n' ' ')"; rm -f "$tmp"
        if [ "$code" -eq 0 ]; then
            printf '@@ok %s %s\n' "$name" "$out"; ok=$((ok+1))
        else
            printf '@@fail %s %s\n' "$name" "$out"; bad=$((bad+1))
        fi
    }
    write_env
    refresh_bridges
    . "$ENVF" 2>/dev/null || true
    export TMPDIR="$PREFIX/tmp"
    export _JAVA_OPTIONS="${_JAVA_OPTIONS:-} -Djava.io.tmpdir=$PREFIX/tmp"
    # Run checks the way the agent does: core-like env, runtime/bin first.
    export PATH="$RB:$PREFIX/bin:/system/bin"
    unset LD_LIBRARY_PATH LD_PRELOAD
    local t
    for t in ${ARG//,/ }; do
        case "$t" in
            node)    chk node node -e 'console.log("node "+process.version)' ;;
            node-lts) chk node-lts sh -c 'v="$(node -p "process.versions.node")" || exit; meta="$PREFIX/var/lib/pkg/installed/nodejs-lts.meta"; want="$(sed -n "s/^version=//p" "$meta" | head -n1 | cut -d. -f1)"; [ -n "$want" ] && [ "${v%%.*}" = "$want" ] || { echo "active Node $v differs from installed LTS $want"; exit 1; }; echo "node $v"' ;;
            node-current) chk node-current sh -c 'v="$(node -p "process.versions.node")" || exit; meta="$PREFIX/var/lib/pkg/installed/nodejs.meta"; want="$(sed -n "s/^version=//p" "$meta" | head -n1 | cut -d. -f1)"; [ -n "$want" ] && [ "${v%%.*}" = "$want" ] || { echo "active Node $v differs from installed version $want"; exit 1; }; echo "node $v"' ;;
            npm)     chk npm npm -v ;;
            python)  chk python python -c 'import sys;print(sys.version.split()[0])' ;;
            java)    chk java java -version ;;
            javac)   chk javac javac -version ;;
            java17|java21|javac17|javac21)
                local v tool
                case "$t" in *17) v=17;; *) v=21;; esac
                case "$t" in javac*) tool=javac;; *) tool=java;; esac
                chk "$t" env LD_LIBRARY_PATH="$PREFIX/lib" "$PREFIX/lib/jvm/java-$v-openjdk/bin/$tool" -version ;;
            kotlin)  chk kotlin kotlinc -version ;;
            gradle)  chk gradle gradle -v --no-daemon -q ;;
            clang)   chk clang sh -c 'printf "int main(){return 0;}" > "$PREFIX/tmp/agy_t.c" && clang "$PREFIX/tmp/agy_t.c" -o "$PREFIX/tmp/agy_t" && "$PREFIX/tmp/agy_t" && echo compiled' ;;
            cmake)   chk cmake cmake --version ;;
            git)     chk git git --version ;;
            aapt)    chk aapt aapt version ;;
            aapt2)   chk aapt2 aapt2 version ;;
            aidl)    chk aidl verify_aidl ;;
            zipalign) chk zipalign sh -c 'zipalign 2>&1 | grep -q "Zip alignment utility"' ;;
            d8)      chk d8 d8 --version ;;
            apksigner) chk apksigner apksigner --version ;;
            apktool) chk apktool apktool -version ;;
            jadx)    chk jadx jadx --version ;;
            openssl) chk openssl openssl version ;;
            adb)     chk adb adb version ;;
            sdk)     chk sdk sdkmanager --sdk_root="$SDK" --version ;;
            tsc)     chk tsc tsc -v ;;
            pnpm)    chk pnpm pnpm -v ;;
            ndk)     chk ndk sh -c 'ls "$ANDROID_NDK_HOME"/source.properties >/dev/null && grep Revision "$ANDROID_NDK_HOME/source.properties"' ;;
            rust)    chk rust rustc --version ;;
            go)      chk go go version ;;
            flutter) chk flutter sh -c '[ -x "$HOME/flutter_sdk/bin/flutter" ] && "$HOME/flutter_sdk/bin/flutter" --version 2>&1 | head -n1' ;;
            dart)    chk dart dart --version ;;
            *)       chk "$t" sh -c "command -v '$t'" ;;
        esac
    done
    say "@@verified $ok $bad"
    say "@@done"
    [ "$bad" -eq 0 ]
}
# ------------------------------------------------------------ MCP management
op_mcp() {
    umask 077
    [ -f "$HOME/.gemini/config/mcp_config.json" ] && chmod 600 "$HOME/.gemini/config/mcp_config.json" 2>/dev/null || true
    local cmd="${ARG%% *}"
    local rest=""
    if [ "$cmd" != "$ARG" ]; then
        rest="${ARG#* }"
    fi
    local cfg="$HOME/.gemini/config/mcp_config.json"
    local node_exec="$HOME/runtime/bin/node"
    [ -x "$node_exec" ] || node_exec="$PREFIX/bin/node"

    case "$cmd" in
        status)
            # Wrap only the configured stdio GitHub server; preserve command,
            # arguments, environment and all other server settings.
            if [ -x "$node_exec" ] && [ -f "$HOME/web/agy_mcp_stdio_proxy.js" ] && [ -f "$cfg" ]; then
                python3 - "$cfg" "$node_exec" "$HOME/web/agy_mcp_stdio_proxy.js" <<'PYPROXY' || true
import json, os, sys
path, node, proxy = sys.argv[1:]
try:
    with open(path, encoding="utf-8") as f: data = json.load(f)
    server = data.get("mcpServers", {}).get("github-mcp-server")
    if isinstance(server, dict) and isinstance(server.get("command"), str) and server["command"] and not server.get("url"):
        args = server.get("args", [])
        if isinstance(args, list) and not (args and args[0] == proxy):
            server["args"] = [proxy, server["command"]] + args
            server["command"] = node
            tmp = path + ".agy-proxy-tmp"
            with open(tmp, "w", encoding="utf-8") as f: json.dump(data, f, ensure_ascii=False, indent=2)
            os.chmod(tmp, 0o600)
            os.replace(tmp, path)
except (OSError, ValueError, TypeError):
    pass
PYPROXY
            fi
            step "Checking MCP components and servers"
            command -v node >/dev/null 2>&1 && say "@@mcp_comp node ok $(node -v 2>/dev/null)" || say "@@mcp_comp node - missing"
            command -v npm >/dev/null 2>&1 && say "@@mcp_comp npm ok $(npm -v 2>/dev/null)" || say "@@mcp_comp npm - missing"
            [ -f "$PREFIX/lib/node_modules/@modelcontextprotocol/server-sequential-thinking/dist/index.js" ] && say "@@mcp_comp sequential ok installed" || say "@@mcp_comp sequential - missing"
            [ -f "$PREFIX/lib/node_modules/@modelcontextprotocol/server-memory/dist/index.js" ] && say "@@mcp_comp memory ok installed" || say "@@mcp_comp memory - missing"
            [ -f "$PREFIX/lib/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js" ] && say "@@mcp_comp filesystem ok installed" || say "@@mcp_comp filesystem - missing"
            [ -f "$PREFIX/lib/node_modules/@modelcontextprotocol/server-everything/dist/index.js" ] && say "@@mcp_comp everything ok installed" || say "@@mcp_comp everything - missing"
            [ -f "$PREFIX/lib/node_modules/exa-mcp-server/dist/stdio.cjs" ] && say "@@mcp_comp exa ok installed" || say "@@mcp_comp exa - missing"
            [ -f "$PREFIX/lib/node_modules/mcp-remote/dist/proxy.js" ] && say "@@mcp_comp remote ok installed" || say "@@mcp_comp remote - missing"
            [ -f "$PREFIX/lib/node_modules/@modelcontextprotocol/server-github/dist/index.js" ] && say "@@mcp_comp github ok installed" || say "@@mcp_comp github - missing"
            [ -f "$PREFIX/lib/node_modules/@upstash/context7-mcp/dist/index.js" ] && say "@@mcp_comp context7 ok installed" || say "@@mcp_comp context7 - missing"
            [ -f "$PREFIX/lib/node_modules/@modelcontextprotocol/server-brave-search/dist/index.js" ] && say "@@mcp_comp brave ok installed" || say "@@mcp_comp brave - missing"
            [ -f "$PREFIX/lib/node_modules/@utcp/mcp-bridge/dist/index.js" ] && say "@@mcp_comp utcp_bridge ok installed" || say "@@mcp_comp utcp_bridge - missing"
            for utcp_part in sdk http file; do
                if [ -f "$PREFIX/lib/node_modules/@utcp/$utcp_part/package.json" ] || [ -f "$PREFIX/lib/node_modules/@utcp/mcp-bridge/node_modules/@utcp/$utcp_part/package.json" ]; then
                    say "@@mcp_comp utcp_$utcp_part ok installed"
                else say "@@mcp_comp utcp_$utcp_part - missing"; fi
            done
            command -v gopls >/dev/null 2>&1 && say "@@mcp_comp gopls ok installed" || say "@@mcp_comp gopls - missing"
            command -v python3 >/dev/null 2>&1 && say "@@mcp_comp python ok $(python3 -V 2>/dev/null | awk '{print $2}')" || say "@@mcp_comp python - missing"
            command -v git >/dev/null 2>&1 && say "@@mcp_comp git ok $(git --version 2>/dev/null | awk '{print $3}')" || say "@@mcp_comp git - missing"

            python3 - "$cfg" "$PREFIX" "$HOME" <<'PY' || true
import json, sys, os
cfg, prefix, home = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = {"mcpServers": {}}
    if os.path.exists(cfg) and os.path.getsize(cfg) > 0:
        try:
            with open(cfg) as f:
                data = json.load(f)
        except Exception:
            data = {"mcpServers": {}}
    servers = data.get("mcpServers", {})
    for name, srv in servers.items():
            dis = "1" if srv.get("disabled") else "0"
            env = srv.get("env", {})
            keys = []
            for k, v in env.items():
                if k in ("EXA_API_KEY", "GITHUB_PERSONAL_ACCESS_TOKEN", "X-Goog-Api-Key", "NOTION_API_KEY", "SENTRY_AUTH_TOKEN", "BRAVE_API_KEY"):
                    keys.append("%s=%s" % (k, "***" if v else ""))
            if name == "StitchMCP":
                for a in srv.get("args", []):
                    if "X-Goog-Api-Key" in a:
                        keys.append("X-Goog-Api-Key=%s" % ("***" if a.split(":", 1)[-1].strip() else ""))
            print("@@mcp_srv %s %s %s" % (name, dis, ",".join(keys)))

    # UTCP status
    utcp_cfg = os.path.join(home, ".gemini/config/utcp_config.json")
    manuals_dir = os.path.join(home, ".gemini/config/utcp_manuals")
    os.makedirs(manuals_dir, exist_ok=True)
    if os.path.exists(utcp_cfg):
        with open(utcp_cfg) as uf:
            udata = json.load(uf)
        for m in udata.get("manual_call_templates", []):
            mname = m.get("name", "")
            mtype = m.get("call_template_type", "http")
            msrc = m.get("url") or m.get("file_path", "")
            mdis = "1" if m.get("disabled") else "0"
            summary = "1 инструмент"
            if mtype == "file" and os.path.exists(msrc):
                try:
                    with open(msrc) as mf:
                        c = json.load(mf)
                        tls = [t.get("name") for t in c.get("tools", [])]
                        summary = f"{len(tls)}: {', '.join(tls)}"
                except:
                    pass
            print(f"@@utcp_srv {mname} {mtype} {msrc} {mdis} {summary}")
except Exception as e:
    print("@@error parse: %s" % e)
PY
            say "@@done"
            ;;
        install-all)
            step "Checking Node.js and npm"
            if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
                fail "Node.js and npm are required. Install them in Settings > Tools."
            fi
            step "Installing MCP npm packages"
            pkg_retry npm install -g --fetch-retries=5 --fetch-retry-maxtimeout=60000 \
                @modelcontextprotocol/server-sequential-thinking \
                @modelcontextprotocol/server-memory \
                @modelcontextprotocol/server-filesystem \
                @modelcontextprotocol/server-everything \
                @modelcontextprotocol/server-brave-search \
                exa-mcp-server \
                mcp-remote \
                @modelcontextprotocol/server-github \
                @upstash/context7-mcp || fail "npm install mcp packages"
            step "Fixing tool paths"
            agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
            step "Normalizing mcp_config.json with native node paths"
            python3 - "$cfg" "$PREFIX" "$HOME" <<'PY' || true
import json, sys, os
cfg, prefix, home = sys.argv[1], sys.argv[2], sys.argv[3]
node_exec = os.path.join(home, "runtime/bin/node")
if not os.path.exists(node_exec):
    node_exec = os.path.join(prefix, "bin/node")
nm = os.path.join(prefix, "lib/node_modules")
env_std = {
    "LD_LIBRARY_PATH": os.path.join(prefix, "lib"),
    "PATH": f"{prefix}/bin:{home}/runtime/bin:/system/bin",
    "NODE_PATH": nm
}
data = {"mcpServers": {}}
if os.path.exists(cfg):
    try:
        with open(cfg) as f:
            data = json.load(f)
    except:
        pass
srvs = data.setdefault("mcpServers", {})

seq = srvs.setdefault("sequential-thinking", {})
seq["command"] = node_exec
seq["args"] = [os.path.join(nm, "@modelcontextprotocol/server-sequential-thinking/dist/index.js")]
seq["env"] = dict(env_std)

mem = srvs.setdefault("memory", {})
mem["command"] = node_exec
mem["args"] = [os.path.join(nm, "@modelcontextprotocol/server-memory/dist/index.js")]
mem["env"] = dict(env_std)

fs = srvs.setdefault("filesystem", {})
fs["command"] = node_exec
fs["args"] = [os.path.join(nm, "@modelcontextprotocol/server-filesystem/dist/index.js"), "/storage/emulated/0"]
fs["env"] = dict(env_std)

ev = srvs.setdefault("everything", {})
ev["command"] = node_exec
ev["args"] = [os.path.join(nm, "@modelcontextprotocol/server-everything/dist/index.js")]
ev["env"] = dict(env_std)

c7 = srvs.setdefault("context7", {})
c7["command"] = node_exec
c7["args"] = [os.path.join(nm, "@upstash/context7-mcp/dist/index.js")]
c7["env"] = dict(env_std)

ex = srvs.setdefault("exa", {})
old_exa_key = ex.get("env", {}).get("EXA_API_KEY", "")
ex["command"] = node_exec
ex["args"] = [os.path.join(nm, "exa-mcp-server/dist/stdio.cjs")]
ex["env"] = dict(env_std)
ex["env"]["EXA_API_KEY"] = old_exa_key or "YOUR_EXA_KEY"
ex["env"]["EXA_SOURCE"] = "antigravity"

br = srvs.setdefault("brave-search", {})
old_br_key = br.get("env", {}).get("BRAVE_API_KEY", "")
br["command"] = node_exec
br["args"] = [os.path.join(nm, "@modelcontextprotocol/server-brave-search/dist/index.js")]
br["env"] = dict(env_std)
br["env"]["BRAVE_API_KEY"] = old_br_key or "YOUR_BRAVE_KEY"

gh = srvs.setdefault("github-mcp-server", {})
old_gh_pat = gh.get("env", {}).get("GITHUB_PERSONAL_ACCESS_TOKEN", "")
gh["command"] = node_exec
gh["args"] = [os.path.join(nm, "@modelcontextprotocol/server-github/dist/index.js")]
gh["env"] = dict(env_std)
gh["env"]["GITHUB_PERSONAL_ACCESS_TOKEN"] = old_gh_pat or "YOUR_GITHUB_PAT"

st = srvs.setdefault("StitchMCP", {})
old_st_key = ""
for a in st.get("args", []):
    if "X-Goog-Api-Key" in a:
        old_st_key = a.split(":", 1)[-1].strip()
st["command"] = node_exec
st["args"] = [
    os.path.join(nm, "mcp-remote/dist/proxy.js"),
    "https://stitch.googleapis.com/mcp",
    "--header",
    f"X-Goog-Api-Key: {old_st_key or 'YOUR_KEY'}"
]
st["env"] = dict(env_std)

if os.path.exists(os.path.join(prefix, "bin/gopls")):
    gopls = srvs.setdefault("gopls-mcp-server", {})
    gopls["command"] = os.path.join(prefix, "bin/gopls")
    gopls["args"] = ["mcp"]
    gopls["env"] = {"PATH": f"{prefix}/bin:/system/bin"}

if "dart-mcp-server" in srvs:
    srvs["dart-mcp-server"]["disabled"] = True

os.makedirs(os.path.dirname(cfg), exist_ok=True)
tmp = cfg + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg)
print("Config normalized successfully.")
PY
            say "@@done"
            ;;
        install)
            case "$rest" in
                sequential)
                    step "Installing @modelcontextprotocol/server-sequential-thinking"
                    pkg_retry npm install -g @modelcontextprotocol/server-sequential-thinking || fail "npm install sequential"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                memory)
                    step "Installing @modelcontextprotocol/server-memory"
                    pkg_retry npm install -g @modelcontextprotocol/server-memory || fail "npm install memory"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                filesystem)
                    step "Installing @modelcontextprotocol/server-filesystem"
                    pkg_retry npm install -g @modelcontextprotocol/server-filesystem || fail "npm install filesystem"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                everything)
                    step "Installing @modelcontextprotocol/server-everything"
                    pkg_retry npm install -g @modelcontextprotocol/server-everything || fail "npm install everything"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                context7)
                    step "Installing @upstash/context7-mcp"
                    pkg_retry npm install -g @upstash/context7-mcp || fail "npm install context7"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                brave)
                    step "Installing @modelcontextprotocol/server-brave-search"
                    pkg_retry npm install -g @modelcontextprotocol/server-brave-search || fail "npm install brave"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                exa)
                    step "Installing exa-mcp-server"
                    pkg_retry npm install -g exa-mcp-server || fail "npm install exa"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                remote)
                    step "Installing mcp-remote"
                    pkg_retry npm install -g mcp-remote || fail "npm install mcp-remote"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                github)
                    step "Installing @modelcontextprotocol/server-github"
                    pkg_retry npm install -g @modelcontextprotocol/server-github || fail "npm install github"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                gopls)
                    fail "Install Go tools in Settings > Tools"
                    ;;
                node)
                    fail "Install Node.js in Settings > Tools"
                    ;;
                utcp_bridge|utcp_sdk|utcp_http|utcp_file|utcp-bridge|utcp-sdk|utcp-http|utcp-file|utcp-all)
                    step "Installing UTCP MCP bridge and its dependencies"
                    pkg_retry npm install -g --fetch-retries=5 --fetch-retry-maxtimeout=60000 \
                        @utcp/mcp-bridge || fail "npm install utcp"
                    [ -f "$PREFIX/lib/node_modules/@utcp/mcp-bridge/dist/index.js" ] || fail "UTCP bridge entry point not found after install"
                    agy-fix-paths "$PREFIX/bin" "$PREFIX/lib/node_modules" 2>/dev/null || true
                    ;;
                *)
                    fail "unknown package: $rest"
                    ;;
            esac
            say "@@done"
            ;;
        add-custom)
            local sname="${rest%% *}"
            local scmd_and_more="${rest#* }"
            python3 - "$cfg" "$sname" "$scmd_and_more" "$PREFIX" "$HOME" <<'PY' || fail "add-custom failed"
import json, sys, os
cfg, name, raw, prefix, home = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
# format: cmd|arg1,arg2|KEY1=VAL1,KEY2=VAL2
parts = raw.split("|")
cmd = parts[0] if len(parts) > 0 else ""
args = [a.strip() for a in parts[1].split(",") if a.strip()] if len(parts) > 1 else []
env_pairs = [p.strip() for p in parts[2].split(",") if p.strip()] if len(parts) > 2 else []
env = {
    "LD_LIBRARY_PATH": os.path.join(prefix, "lib"),
    "PATH": f"{prefix}/bin:{home}/runtime/bin:/system/bin",
    "NODE_PATH": os.path.join(prefix, "lib/node_modules")
}
for p in env_pairs:
    if "=" in p:
        k, v = p.split("=", 1)
        env[k.strip()] = v.strip()
data = {"mcpServers": {}}
if os.path.exists(cfg):
    try:
        with open(cfg) as f:
            data = json.load(f)
    except:
        pass
srvs = data.setdefault("mcpServers", {})
srvs[name] = {
    "command": cmd,
    "args": args,
    "env": env
}
tmp = cfg + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg)
print("Custom server added:", name)
PY
            say "@@done"
            ;;
        delete)
            local sname="$rest"
            python3 - "$cfg" "$sname" <<'PY' || fail "delete failed"
import json, sys, os
cfg, name = sys.argv[1], sys.argv[2]
if os.path.exists(cfg):
    with open(cfg) as f:
        data = json.load(f)
    if "mcpServers" in data and name in data["mcpServers"]:
        del data["mcpServers"][name]
        tmp = cfg + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp, cfg)
PY
            say "@@done"
            ;;
        set-key)
            local srv="${rest%% *}"
            local kv="${rest#* }"
            [ "$srv" != "$rest" ] || fail "missing key=value"
            python3 - "$cfg" "$srv" "$kv" "$PREFIX" "$HOME" <<'PY' || fail "set-key failed"
import json, sys, os
cfg, srv, kv, prefix, home = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
k, v = kv.split("=", 1)
if v == "***":
    sys.exit(0)
data = {"mcpServers": {}}
if os.path.exists(cfg) and os.path.getsize(cfg) > 0:
    try:
        with open(cfg) as f:
            data = json.load(f)
    except Exception:
        data = {"mcpServers": {}}
srvs = data.setdefault("mcpServers", {})
s = srvs.setdefault(srv, {})

node_exec = os.path.join(home, "runtime/bin/node")
if not os.path.exists(node_exec):
    node_exec = os.path.join(prefix, "bin/node")
nm = os.path.join(prefix, "lib/node_modules")
env_std = {
    "LD_LIBRARY_PATH": os.path.join(prefix, "lib"),
    "PATH": f"{prefix}/bin:{home}/runtime/bin:/system/bin",
    "NODE_PATH": nm
}

if srv == "StitchMCP":
    s.setdefault("command", node_exec)
    if not s.get("args"):
        s["args"] = [
            os.path.join(nm, "mcp-remote/dist/proxy.js"),
            "https://stitch.googleapis.com/mcp",
            "--header",
            f"X-Goog-Api-Key: {v}"
        ]
    else:
        found = False
        for i, a in enumerate(s["args"]):
            if "X-Goog-Api-Key" in a:
                s["args"][i] = f"X-Goog-Api-Key: {v}"
                found = True
                break
        if not found:
            s["args"].extend(["--header", f"X-Goog-Api-Key: {v}"])
    s.setdefault("env", dict(env_std))
else:
    s.setdefault("env", {})[k] = v

os.makedirs(os.path.dirname(cfg), exist_ok=True)
tmp = cfg + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg)
PY
            say "@@done"
            ;;
        toggle)
            local srv="${rest%% *}"
            local val="${rest#* }"
            python3 - "$cfg" "$srv" "$val" "$PREFIX" "$HOME" <<'PY' || fail "toggle failed"
import json, sys, os
cfg, srv, val, prefix, home = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
data = {"mcpServers": {}}
if os.path.exists(cfg) and os.path.getsize(cfg) > 0:
    try:
        with open(cfg) as f:
            data = json.load(f)
    except Exception:
        data = {"mcpServers": {}}
srvs = data.setdefault("mcpServers", {})
s = srvs.setdefault(srv, {})

node_exec = os.path.join(home, "runtime/bin/node")
if not os.path.exists(node_exec):
    node_exec = os.path.join(prefix, "bin/node")
nm = os.path.join(prefix, "lib/node_modules")
env_std = {
    "LD_LIBRARY_PATH": os.path.join(prefix, "lib"),
    "PATH": f"{prefix}/bin:{home}/runtime/bin:/system/bin",
    "NODE_PATH": nm
}

# Auto-initialize known server templates if enabled and empty
if not s.get("command"):
    if srv == "sequential-thinking":
        s["command"] = node_exec
        s["args"] = [os.path.join(nm, "@modelcontextprotocol/server-sequential-thinking/dist/index.js")]
        s["env"] = dict(env_std)
    elif srv == "memory":
        s["command"] = node_exec
        s["args"] = [os.path.join(nm, "@modelcontextprotocol/server-memory/dist/index.js")]
        s["env"] = dict(env_std)
    elif srv == "filesystem":
        s["command"] = node_exec
        s["args"] = [os.path.join(nm, "@modelcontextprotocol/server-filesystem/dist/index.js"), "/storage/emulated/0"]
        s["env"] = dict(env_std)
    elif srv == "context7":
        s["command"] = node_exec
        s["args"] = [os.path.join(nm, "@upstash/context7-mcp/dist/index.js")]
        s["env"] = dict(env_std)
    elif srv == "github-mcp-server":
        s["command"] = node_exec
        s["args"] = [os.path.join(nm, "@modelcontextprotocol/server-github/dist/index.js")]
        s["env"] = dict(env_std)
    elif srv == "StitchMCP":
        s["command"] = node_exec
        s["args"] = [
            os.path.join(nm, "mcp-remote/dist/proxy.js"),
            "https://stitch.googleapis.com/mcp",
            "--header",
            "X-Goog-Api-Key: YOUR_KEY"
        ]
        s["env"] = dict(env_std)
    elif srv == "microsoft-learn":
        s["command"] = node_exec
        s["args"] = [os.path.join(nm, "mcp-remote/dist/proxy.js"), "https://learn.microsoft.com/api/mcp"]
        s["env"] = dict(env_std)

if val == "1":
    s.pop("disabled", None)
else:
    s["disabled"] = True

os.makedirs(os.path.dirname(cfg), exist_ok=True)
tmp = cfg + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg)
PY
            say "@@done"
            ;;
        reset-config)
            step "Resetting config to clean native template"
            python3 - "$cfg" "$PREFIX" "$HOME" <<'PY' || true
import json, sys, os
cfg, prefix, home = sys.argv[1], sys.argv[2], sys.argv[3]
node_exec = os.path.join(home, "runtime/bin/node")
if not os.path.exists(node_exec):
    node_exec = os.path.join(prefix, "bin/node")
nm = os.path.join(prefix, "lib/node_modules")
env_std = {
    "LD_LIBRARY_PATH": os.path.join(prefix, "lib"),
    "PATH": f"{prefix}/bin:{home}/runtime/bin:/system/bin",
    "NODE_PATH": nm
}
data = {
  "mcpServers": {
    "sequential-thinking": {
      "command": node_exec,
      "args": [os.path.join(nm, "@modelcontextprotocol/server-sequential-thinking/dist/index.js")],
      "env": dict(env_std)
    },
    "exa": {
      "command": node_exec,
      "args": [os.path.join(nm, "exa-mcp-server/dist/stdio.cjs")],
      "env": {
        **env_std,
        "EXA_API_KEY": "YOUR_EXA_KEY",
        "EXA_SOURCE": "antigravity"
      }
    },
    "github-mcp-server": {
      "command": node_exec,
      "args": [os.path.join(nm, "@modelcontextprotocol/server-github/dist/index.js")],
      "env": {
        **env_std,
        "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_GITHUB_PAT"
      }
    },
    "StitchMCP": {
      "command": node_exec,
      "args": [
        os.path.join(nm, "mcp-remote/dist/proxy.js"),
        "https://stitch.googleapis.com/mcp",
        "--header",
        "X-Goog-Api-Key: YOUR_KEY"
      ],
      "env": dict(env_std)
    }
  }
}
os.makedirs(os.path.dirname(cfg), exist_ok=True)
tmp = cfg + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg)
PY
            say "@@done"
            ;;
        add-utcp)
            python3 - "$cfg" "$PREFIX" "$HOME" "$rest" <<'PY' || fail "add-utcp failed"
import json, sys, os
cfg, prefix, home, raw = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
# format: name|type|source|auth_header
parts = raw.split("|")
name = parts[0].strip() if len(parts) > 0 else ""
ctype = parts[1].strip() if len(parts) > 1 else "openapi"
source = parts[2].strip() if len(parts) > 2 else ""
auth = parts[3].strip() if len(parts) > 3 else ""

if not name or not source:
    print("Error: name and source required")
    sys.exit(1)

utcp_cfg = os.path.join(home, ".gemini/config/utcp_config.json")
manuals_dir = os.path.join(home, ".gemini/config/utcp_manuals")
os.makedirs(manuals_dir, exist_ok=True)

data = {"manual_call_templates": []}
if os.path.exists(utcp_cfg):
    try:
        with open(utcp_cfg) as f:
            data = json.load(f)
    except:
        pass

# Remove existing with same name if any
tmpls = [t for t in data.get("manual_call_templates", []) if t.get("name") != name]

new_tmpl = {"name": name}
if ctype == "file" or source.startswith("/") or source.startswith("~"):
    expanded_path = os.path.expanduser(source)
    new_tmpl["call_template_type"] = "file"
    new_tmpl["file_path"] = expanded_path
    new_tmpl["allowed_communication_protocols"] = ["http", "file", "cli"]
else:
    new_tmpl["call_template_type"] = "http"
    new_tmpl["http_method"] = "GET"
    new_tmpl["url"] = source
    if auth:
        new_tmpl["headers"] = {"Authorization": auth if " " in auth else f"Bearer {auth}"}

tmpls.append(new_tmpl)
data["manual_call_templates"] = tmpls

tmp = utcp_cfg + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, utcp_cfg)

# Ensure utcp in mcp_config.json
node_exec = os.path.join(home, "runtime/bin/node")
if not os.path.exists(node_exec):
    node_exec = os.path.join(prefix, "bin/node")
mcp_data = {"mcpServers": {}}
if os.path.exists(cfg):
    try:
        with open(cfg) as f:
            mcp_data = json.load(f)
    except:
        pass
mcp_srvs = mcp_data.setdefault("mcpServers", {})
mcp_srvs["utcp"] = {
    "command": node_exec,
    "args": [os.path.join(prefix, "lib/node_modules/@utcp/mcp-bridge/dist/index.js")],
    "env": {
        "UTCP_CONFIG_FILE": utcp_cfg,
        "LD_LIBRARY_PATH": os.path.join(prefix, "lib"),
        "PATH": f"{prefix}/bin:{home}/runtime/bin:/system/bin",
        "NODE_PATH": os.path.join(prefix, "lib/node_modules")
    }
}
mcp_srvs["utcp"].pop("disabled", None)
mtmp = cfg + ".tmp"
with open(mtmp, "w", encoding="utf-8") as f:
    json.dump(mcp_data, f, ensure_ascii=False, indent=2)
os.replace(mtmp, cfg)

print(f"UTCP manual {name} added and bridge registered")
PY
            say "@@done"
            ;;
        delete-utcp)
            local uname="$rest"
            python3 - "$cfg" "$HOME" "$uname" <<'PY' || fail "delete-utcp failed"
import json, sys, os
cfg, home, uname = sys.argv[1], sys.argv[2], sys.argv[3]
utcp_cfg = os.path.join(home, ".gemini/config/utcp_config.json")
if os.path.exists(utcp_cfg):
    with open(utcp_cfg) as f:
        data = json.load(f)
    tmpls = [t for t in data.get("manual_call_templates", []) if t.get("name") != uname]
    data["manual_call_templates"] = tmpls
    tmp = utcp_cfg + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, utcp_cfg)
print(f"UTCP manual {uname} deleted")
PY
            say "@@done"
            ;;
        toggle-utcp)
            local uname="${rest%% *}"
            local val="${rest#* }"
            python3 - "$HOME" "$uname" "$val" <<'PY' || fail "toggle-utcp failed"
import json, sys, os
home, uname, val = sys.argv[1], sys.argv[2], sys.argv[3]
utcp_cfg = os.path.join(home, ".gemini/config/utcp_config.json")
if os.path.exists(utcp_cfg):
    with open(utcp_cfg) as f:
        data = json.load(f)
    for t in data.get("manual_call_templates", []):
        if t.get("name") == uname:
            if val == "1":
                t.pop("disabled", None)
            else:
                t["disabled"] = True
    tmp = utcp_cfg + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, utcp_cfg)
print(f"UTCP manual {uname} toggle {val}")
PY
            say "@@done"
            ;;
        test-utcp)
            local uname="$rest"
            step "Testing UTCP manual: $uname"
            python3 - "$HOME" "$PREFIX" "$uname" <<'PY' || true
import json, sys, os, subprocess
home, prefix, uname = sys.argv[1], sys.argv[2], sys.argv[3]
utcp_cfg = os.path.join(home, ".gemini/config/utcp_config.json")
manual = None
if os.path.exists(utcp_cfg):
    with open(utcp_cfg) as f:
        data = json.load(f)
    for t in data.get("manual_call_templates", []):
        if t.get("name") == uname:
            manual = t
            break

if not manual:
    print(f"@@utcp_test_fail {uname} Мануал не найден в конфигурации")
    sys.exit(0)

# Quick discovery check
ctype = manual.get("call_template_type", "http")
source = manual.get("url") or manual.get("file_path", "")

node_exec = os.path.join(home, "runtime/bin/node")
if not os.path.exists(node_exec):
    node_exec = os.path.join(prefix, "bin/node")

js_code = f"""
import '@utcp/http';
import '@utcp/file';
import {{ UtcpClient, ensureCorePluginsInitialized, UtcpClientConfigSerializer }} from '@utcp/sdk';
ensureCorePluginsInitialized();
const tmpl = {json.dumps(manual)};
const ser = new UtcpClientConfigSerializer();
const parsed = ser.validateDict({{ manual_call_templates: [tmpl] }});
const client = await UtcpClient.create(process.cwd(), parsed);
const tools = await client.config.tool_repository.getTools();
const toolInfo = tools.map(t => ({{ name: t.name, desc: t.description }}));
console.log('@@UTCP_RES:' + JSON.stringify(toolInfo));
"""

try:
    proc = subprocess.run(
        [node_exec, "--input-type=module", "-e", js_code],
        cwd=os.path.join(prefix, "lib/node_modules/@utcp/mcp-bridge"),
        env=dict(os.environ, NODE_PATH=os.path.join(prefix, "lib/node_modules")),
        capture_output=True,
        text=True,
        timeout=15
    )
    res_line = [l for l in proc.stdout.splitlines() if l.startswith("@@UTCP_RES:")]
    if res_line:
        raw_json = res_line[0].split(":", 1)[1]
        tools = json.loads(raw_json)
        names = [t.get("name") for t in tools]
        print(f"@@utcp_test_ok {uname} Обнаружено {len(names)} инструментов: {', '.join(names)}")
    else:
        err = (proc.stderr or proc.stdout).strip().replace("\n", " ")[:200]
        print(f"@@utcp_test_fail {uname} {err or 'Ошибка обнаружения инструментов'}")
except Exception as ex:
    print(f"@@utcp_test_fail {uname} {str(ex)}")
PY
            say "@@done"
            ;;
        *)
            fail "unknown mcp subcommand: $cmd"
            ;;
    esac
}

# ------------------------------------------------------------ Customizations (Skills, Rules, Plugins)
op_customizations() {
    local cmd="${ARG%% *}"
    local rest=""
    if [ "$cmd" != "$ARG" ]; then
        rest="${ARG#* }"
    fi
    local cfg_dir="$HOME/.gemini/config"
    local app_dir="$HOME/.gemini/antigravity-app"

    case "$cmd" in
        status)
            step "Scanning skills, rules and plugins"
            python3 - "$cfg_dir" "$app_dir" <<'PY'
import json, os, glob, sys, re

cfg_dir, app_dir = sys.argv[1], sys.argv[2]
config_file = os.path.join(cfg_dir, "config.json")
agents_file = os.path.join(cfg_dir, "AGENTS.md")

cfg_data = {}
if os.path.exists(config_file):
    try:
        with open(config_file) as f:
            cfg_data = json.load(f)
    except:
        pass

plugins_cfg = cfg_data.get("plugins", {})
disabled_skills = set(cfg_data.get("disabledSkills", []))

def parse_skill(path, stype, plugin_name=""):
    name = os.path.basename(os.path.dirname(path))
    desc = ""
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            content = f.read(3000)
        m = re.search(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
        if m:
            fm = m.group(1)
            nm = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
            if nm: name = nm.group(1).strip()
            dm = re.search(r"^description:\s*(?:>-\s*|\s*)(.+?)(?=\n[a-zA-Z0-9_-]+:|\Z)", fm, re.DOTALL | re.MULTILINE)
            if dm: desc = " ".join(dm.group(1).split())
    except:
        pass
    en = "0" if name in disabled_skills else "1"
    clean_desc = desc.replace("|", " ").replace("\n", " ")
    print("@@cust_skill %s|%s|%s|%s|%s|%s" % (stype, name, plugin_name, en, path, clean_desc[:250]))

for p in sorted(glob.glob(f"{app_dir}/builtin/skills/*/SKILL.md")):
    parse_skill(p, "builtin")

for pdir in sorted(glob.glob(f"{cfg_dir}/plugins/*")):
    pname = os.path.basename(pdir)
    for sp in sorted(glob.glob(f"{pdir}/**/SKILL.md", recursive=True)):
        parse_skill(sp, "plugin", pname)

user_skills_dir = os.path.join(cfg_dir, "skills")
if os.path.exists(user_skills_dir):
    for sp in sorted(glob.glob(f"{user_skills_dir}/*/SKILL.md")):
        parse_skill(sp, "user")

for pdir in sorted(glob.glob(f"{cfg_dir}/plugins/*")):
    pname = os.path.basename(pdir)
    pmanifest = os.path.join(pdir, "plugin.json")
    title = pname
    desc = ""
    if os.path.exists(pmanifest):
        try:
            with open(pmanifest) as f:
                pdata = json.load(f)
                title = pdata.get("name", pname)
                desc = pdata.get("description", "")
            if "skills" in pdata:
                del pdata["skills"]
                with open(pmanifest, "w", encoding="utf-8") as fw:
                    json.dump(pdata, fw, ensure_ascii=False, indent=2)
        except:
            pass
    if not desc:
        readme = os.path.join(pdir, "README.md")
        if os.path.exists(readme):
            try:
                with open(readme, encoding="utf-8", errors="replace") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#"):
                            desc = line[:150]
                            break
            except:
                pass
    skills_count = len(glob.glob(f"{pdir}/**/SKILL.md", recursive=True))
    has_rules = "1" if os.path.exists(os.path.join(pdir, "rules")) else "0"
    has_mcp = "1" if os.path.exists(os.path.join(pdir, "mcp_config.json")) else "0"
    is_enabled = "1" if plugins_cfg.get(pname, {}).get("enabled", True) else "0"
    clean_desc = desc.replace("|", " ").replace("\n", " ")
    print("@@cust_plugin %s|%s|%s|%s|%s|%s|%s" % (pname, title, is_enabled, skills_count, has_rules, has_mcp, clean_desc))

disabled_agents = set(cfg_data.get("disabledAgents", []))

builtin_agents = [
    ("builtin", "self", "Полный агент (Self)", "inherit", "1", "1", "1", "1", "builtin://self",
     "Универсальный субагент с полным набором инструментов родительского агента (чтение/запись файлов, терминал, браузер, MCP) в отдельном контексте."),
    ("builtin", "research", "Исследователь (Research)", "flash", "0", "1", "0", "1", "builtin://research",
     "Быстрый субагент только для чтения: исследование кодовой базы, поиск по файлам, документации и веб-поиск без изменения файлов."),
    ("builtin", "image-generator", "Генератор графики (Image)", "inherit", "1", "0", "0", "1", "builtin://image-generator",
     "Специализированный субагент для генерации и редактирования изображений, иконок и визуальных ассетов по текстовому ТЗ.")
]
for ba in builtin_agents:
    print("@@cust_agent %s" % "|".join(ba))

agents_dir = os.path.join(cfg_dir, "agents")
os.makedirs(agents_dir, exist_ok=True)
enabled_custom_agents = []

for ap in sorted(glob.glob(f"{agents_dir}/*.md")):
    aname = os.path.splitext(os.path.basename(ap))[0]
    atitle = aname
    adesc = ""
    amodel = "inherit"
    awrite = "1"
    amcp = "1"
    asub = "0"
    abody = ""
    try:
        with open(ap, encoding="utf-8", errors="replace") as f:
            content = f.read()
        abody = content
        m = re.search(r"^---\s*\n(.*?)\n---(.*)", content, re.DOTALL)
        if m:
            fm = m.group(1)
            abody = m.group(2).strip()
            nm = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
            if nm: aname = nm.group(1).strip()
            tm = re.search(r"^title:\s*(.+)$", fm, re.MULTILINE)
            if tm: atitle = tm.group(1).strip()
            mm = re.search(r"^model:\s*(.+)$", fm, re.MULTILINE)
            if mm: amodel = mm.group(1).strip()
            wm = re.search(r"^enable_write_tools:\s*(.+)$", fm, re.MULTILINE)
            if wm: awrite = "1" if wm.group(1).strip().lower() in ("true", "1", "yes") else "0"
            cm = re.search(r"^enable_mcp_tools:\s*(.+)$", fm, re.MULTILINE)
            if cm: amcp = "1" if cm.group(1).strip().lower() in ("true", "1", "yes") else "0"
            sm = re.search(r"^enable_subagent_tools:\s*(.+)$", fm, re.MULTILINE)
            if sm: asub = "1" if sm.group(1).strip().lower() in ("true", "1", "yes") else "0"
            dm = re.search(r"^description:\s*(?:>-\s*|\s*)(.+?)(?=\n[a-zA-Z0-9_-]+:|\Z)", fm, re.DOTALL | re.MULTILINE)
            if dm: adesc = " ".join(dm.group(1).split())
    except:
        pass
    aen = "0" if aname in disabled_agents else "1"
    clean_adesc = adesc.replace("|", " ").replace("\n", " ")[:250]
    clean_atitle = atitle.replace("|", " ").replace("\n", " ")[:80]
    print("@@cust_agent user|%s|%s|%s|%s|%s|%s|%s|%s|%s" % (
        aname, clean_atitle, amodel, awrite, amcp, asub, aen, ap, clean_adesc
    ))
    if aen == "1":
        enabled_custom_agents.append((aname, clean_atitle, amodel, awrite == "1", amcp == "1", asub == "1", clean_adesc, ap))

# Sync active custom subagents into ~/.gemini/config/rules/custom_subagents.md
rules_dir = os.path.join(cfg_dir, "rules")
os.makedirs(rules_dir, exist_ok=True)
rule_file = os.path.join(rules_dir, "custom_subagents.md")
if enabled_custom_agents:
    lines = [
        "# Custom User Subagents Registry",
        "",
        "The user has configured the following custom subagents in `~/.gemini/config/agents/`.",
        "To use any of these custom subagents, first register it in the current conversation with `define_subagent` (reading its full system prompt from the file path or using the summary below) and then launch it with `invoke_subagent`:",
        ""
    ]
    for aname, atitle, amodel, awrite, amcp, asub, adesc, ap in enabled_custom_agents:
        lines.append(f"- **`{aname}`** ({atitle}): {adesc}")
        lines.append(f"  - Model: `{amodel}` | `enable_write_tools={awrite}` | `enable_mcp_tools={amcp}` | `enable_subagent_tools={asub}`")
        lines.append(f"  - System prompt file: `{ap}`")
    try:
        with open(rule_file, "w", encoding="utf-8") as rf:
            rf.write("\n".join(lines) + "\n")
    except:
        pass
elif os.path.exists(rule_file):
    try:
        os.remove(rule_file)
    except:
        pass

instr_len = os.path.getsize(agents_file) if os.path.exists(agents_file) else 0
print("@@cust_instr_size %d" % instr_len)
PY
            say "@@done"
            ;;
        add-agent)
            python3 - "$cfg_dir" "$rest" <<'PY' || fail "add-agent failed"
import sys, base64, os

cfg_dir, raw = sys.argv[1], sys.argv[2]
parts = raw.split("|")
name = parts[0].strip()
title = base64.b64decode(parts[1]).decode("utf-8").strip() if len(parts) > 1 and parts[1] else name
desc = base64.b64decode(parts[2]).decode("utf-8").strip() if len(parts) > 2 and parts[2] else ""
model = parts[3].strip() if len(parts) > 3 and parts[3].strip() else "inherit"
write_en = "true" if (len(parts) <= 4 or parts[4].strip() == "1") else "false"
mcp_en = "true" if (len(parts) <= 5 or parts[5].strip() == "1") else "false"
sub_en = "true" if (len(parts) > 6 and parts[6].strip() == "1") else "false"
body = base64.b64decode(parts[7]).decode("utf-8").strip() if len(parts) > 7 and parts[7] else ""

agents_dir = os.path.join(cfg_dir, "agents")
os.makedirs(agents_dir, exist_ok=True)
agent_md = os.path.join(agents_dir, f"{name}.md")

file_content = f"""---
name: {name}
title: {title}
model: {model}
enable_write_tools: {write_en}
enable_mcp_tools: {mcp_en}
enable_subagent_tools: {sub_en}
description: >-
  {desc}
---

{body}
"""
tmp = agent_md + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(file_content)
os.replace(tmp, agent_md)
print("Subagent saved:", agent_md)
PY
            say "@@done"
            ;;
        read-agent)
            python3 - "$rest" <<'PY' || fail "read-agent failed"
import sys, os, re, base64

apath = sys.argv[1].strip()
if apath.startswith("builtin://"):
    bname = apath.split("builtin://", 1)[1]
    builtins = {
        "self": ("Полный агент (Self)", "Универсальный субагент с полным набором инструментов родительского агента в отдельном контексте.", "inherit", "1", "1", "1",
                 "# Системный субагент `self`\n\nНаследует полный системный промпт, модель и все инструменты основного агента (чтение и запись файлов, выполнение команд в терминале, работа с git и MCP).\n\nИспользуйте его для параллельного выполнения независимых задач разработки или глубокой отладки в изолированном контексте."),
        "research": ("Исследователь (Research)", "Быстрый субагент только для чтения: исследование кодовой базы, поиск по файлам и веб-поиск.", "flash", "0", "1", "0",
                     "# Системный субагент `research`\n\nОснащён только безопасными инструментами чтения (`view_file`, `grep_search`, `find_by_name`, `search_web`, `read_url_content`).\n\nИдеально подходит для быстрого обзора архитектуры проекта, поиска причин багов или изучения документации без риска изменения файлов."),
        "image-generator": ("Генератор графики (Image)", "Специализированный субагент для генерации и редактирования изображений по описанию.", "inherit", "1", "0", "0",
                            "# Системный субагент `image-generator`\n\nГенерирует или редактирует изображения, иконки и баннеры по текстовому заданию и возвращает пути к сохранённым файлам.")
    }
    title, desc, model, wr, mcp, sub, body = builtins.get(bname, (bname, "", "inherit", "1", "1", "0", ""))
    print("@@cust_agent_data %s|%s|%s|%s|%s|%s|%s|%s" % (
        bname,
        base64.b64encode(title.encode("utf-8")).decode("ascii"),
        base64.b64encode(desc.encode("utf-8")).decode("ascii"),
        model, wr, mcp, sub,
        base64.b64encode(body.encode("utf-8")).decode("ascii")
    ))
    sys.exit(0)

if not os.path.exists(apath):
    print("Error: agent file not found:", apath)
    sys.exit(1)

with open(apath, encoding="utf-8", errors="replace") as f:
    content = f.read()

name = os.path.splitext(os.path.basename(apath))[0]
title = name
desc = ""
model = "inherit"
wr = "1"
mcp = "1"
sub = "0"
body = content

m = re.search(r"^---\s*\n(.*?)\n---(.*)", content, re.DOTALL)
if m:
    fm = m.group(1)
    body = m.group(2).strip()
    nm = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
    if nm: name = nm.group(1).strip()
    tm = re.search(r"^title:\s*(.+)$", fm, re.MULTILINE)
    if tm: title = tm.group(1).strip()
    mm = re.search(r"^model:\s*(.+)$", fm, re.MULTILINE)
    if mm: model = mm.group(1).strip()
    wm = re.search(r"^enable_write_tools:\s*(.+)$", fm, re.MULTILINE)
    if wm: wr = "1" if wm.group(1).strip().lower() in ("true", "1", "yes") else "0"
    cm = re.search(r"^enable_mcp_tools:\s*(.+)$", fm, re.MULTILINE)
    if cm: mcp = "1" if cm.group(1).strip().lower() in ("true", "1", "yes") else "0"
    sm = re.search(r"^enable_subagent_tools:\s*(.+)$", fm, re.MULTILINE)
    if sm: sub = "1" if sm.group(1).strip().lower() in ("true", "1", "yes") else "0"
    dm = re.search(r"^description:\s*(?:>-\s*|\s*)(.+?)(?=\n[a-zA-Z0-9_-]+:|\Z)", fm, re.DOTALL | re.MULTILINE)
    if dm: desc = " ".join(dm.group(1).split())

print("@@cust_agent_data %s|%s|%s|%s|%s|%s|%s|%s" % (
    name,
    base64.b64encode(title.encode("utf-8")).decode("ascii"),
    base64.b64encode(desc.encode("utf-8")).decode("ascii"),
    model, wr, mcp, sub,
    base64.b64encode(body.encode("utf-8")).decode("ascii")
))
PY
            say "@@done"
            ;;
        delete-agent)
            local aname="$rest"
            local afile="$cfg_dir/agents/$aname.md"
            if [ -f "$afile" ]; then
                rm -f "$afile"
                say "Subagent deleted: $aname"
            else
                fail "Subagent not found: $aname"
            fi
            say "@@done"
            ;;
        toggle-agent)
            local aname="${rest%% *}"
            local val="${rest#* }"
            python3 - "$cfg_dir/config.json" "$aname" "$val" <<'PY' || fail "toggle-agent failed"
import json, sys, os
cfg_file, name, val = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(cfg_file):
    try:
        with open(cfg_file) as f:
            data = json.load(f)
    except:
        pass
disabled = set(data.get("disabledAgents", []))
if val == "1":
    disabled.discard(name)
else:
    disabled.add(name)
data["disabledAgents"] = sorted(list(disabled))
tmp = cfg_file + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg_file)
print("Subagent toggle saved:", name, val)
PY
            say "@@done"
            ;;
        install-agent)
            python3 - "$cfg_dir" "$rest" <<'PY' || fail "install-agent failed"
import sys, os

cfg_dir, aid = sys.argv[1], sys.argv[2].strip()
agents_dir = os.path.join(cfg_dir, "agents")
os.makedirs(agents_dir, exist_ok=True)

PRESET_AGENTS = {
    "code-reviewer": {
        "title": "Ревьюер кода (Code Reviewer)",
        "model": "pro",
        "write": "false",
        "mcp": "true",
        "sub": "false",
        "desc": "Глубокое код-ревью изменений, поиск багов, гонок данных, утечек памяти и нарушений архитектуры без модификации файлов.",
        "body": """# Роль: Старший ревьюер кода (Code Reviewer)

Ты — специализированный субагент для проведения строгого и конструктивного ревью кода.

## Алгоритм работы:
1. Проанализируй изменённые или указанные файлы (`git diff`, `git status`, чтение файлов).
2. Проверь код на:
   - Логические ошибки, граничные случаи (`null`/`undefined`, переполнения, гонки потоков).
   - Утечки памяти, незакрытые дескрипторы/потоки и неоптимальные алгоритмы.
   - Соответствие архитектуре и стилю проекта.
3. Сформируй чёткий отчёт с приоритетами (`Критично`, `Важно`, `Рекомендация`), точными ссылками на строки и готовыми фрагментами исправлений."""
    },
    "android-debugger": {
        "title": "Android-отладчик (Logcat & APK)",
        "model": "inherit",
        "write": "true",
        "mcp": "true",
        "sub": "false",
        "desc": "Диагностика крашей Android, анализ logcat/stacktrace, проверка манифестов, Gradle, JNI и декомпиляция через jadx-agy/apktool.",
        "body": """# Роль: Инженер отладки Android (Android Debugger)

Ты — специализированный субагент по отладке Android-приложений, нативных библиотек (JNI/NDK) и сборке APK в среде Leostryx (ARM64).

## Правила и инструменты:
1. При анализе APK всегда используй `jadx-agy -j 2 --no-res` (вместо обычного `jadx`) и `apktool`.
2. При наличии Shizuku (`rish -c "..."`) проверяй живой `logcat -d -t 200`, `dumpsys package` и `am start`.
3. Находи первопричину исключений (`NullPointerException`, `UnsatisfiedLinkError`, `SecurityException`, `OutOfMemoryError`) и предлагай или вноси точечный фикс."""
    },
    "security-auditor": {
        "title": "Аудитор безопасности (Security Auditor)",
        "model": "pro",
        "write": "false",
        "mcp": "true",
        "sub": "false",
        "desc": "Аудит безопасности по OWASP Top 10, поиск инъекций, XSS/CSRF, небезопасных прав Android и утечек API-ключей/секретов.",
        "body": """# Роль: Аудитор информационной безопасности (Security Auditor)

Ты — субагент по безопасности приложений и анализу защищённости кода.

## Задачи аудита:
1. Поиск захардкоженных токенов, приватных ключей и паролей в коде и истории коммитов.
2. Проверка командных вызовов, SQL-запросов, WebView (`addJavascriptInterface`, `setAllowFileAccess`), Intent-фильтров и сетевых политик.
3. Выдача структурированного отчёта с оценкой риска (CVSS / High / Medium / Low) и безопасным патчем для каждой находки."""
    },
    "test-engineer": {
        "title": "Инженер тестирования (QA & Tests)",
        "model": "inherit",
        "write": "true",
        "mcp": "true",
        "sub": "false",
        "desc": "Написание и запуск модульных и интеграционных тестов (pytest, vitest, jest, JUnit, go test) и проверка покрытия.",
        "body": """# Роль: Инженер по автоматизации тестирования (Test Engineer)

Ты — субагент, отвечающий за написание, запуск и починку автотестов.

## Алгоритм работы:
1. Определи используемый фреймворк тестирования в проекте (`pytest`, `jest`/`vitest`, `go test`, `cargo test`, `gradle test`).
2. Напиши компактные, детерминированные тесты, покрывающие основную функциональность и граничные случаи (edge cases).
3. Запусти тестовый раннер в терминале, убедись в зелёном статусе всех тестов и верни сводку результатов."""
    },
    "docs-architect": {
        "title": "Архитектор документации (Docs & README)",
        "model": "flash",
        "write": "true",
        "mcp": "true",
        "sub": "false",
        "desc": "Генерация и актуализация README.md, CHANGELOG.md, архитектурных Mermaid-диаграмм и документации API.",
        "body": """# Роль: Архитектор технической документации (Docs Architect)

Ты — субагент по документированию кодовой базы и поддержанию актуальности `README.md` и `CHANGELOG.md`.

## Правила:
1. Изучи реальную структуру модулей, CLI-флаги, публичные API и конфигурационные файлы перед написанием документации.
2. Оформляй документацию лаконично: таблицы параметров, примеры команд, схемы `mermaid` (`flowchart LR`/`sequenceDiagram`) и кликабельные ссылки на файлы."""
    }
}

p = PRESET_AGENTS.get(aid)
if not p:
    print("Unknown preset subagent:", aid)
    sys.exit(1)

agent_md = os.path.join(agents_dir, f"{aid}.md")
content = f"""---
name: {aid}
title: {p['title']}
model: {p['model']}
enable_write_tools: {p['write']}
enable_mcp_tools: {p['mcp']}
enable_subagent_tools: {p['sub']}
description: >-
  {p['desc']}
---

{p['body']}
"""
with open(agent_md, "w", encoding="utf-8") as f:
    f.write(content)
print("Preset subagent installed:", agent_md)
PY
            say "@@done"
            ;;
        read-instructions)
            local agents_file="$cfg_dir/AGENTS.md"
            if [ -f "$agents_file" ]; then
                say "@@cust_instr_start"
                cat "$agents_file"
                say ""
                say "@@cust_instr_end"
            else
                say "@@cust_instr_start"
                say "# Antigravity Custom Instructions"
                say ""
                say "@@cust_instr_end"
            fi
            say "@@done"
            ;;
        save-instructions)
            local b64="$rest"
            python3 - "$cfg_dir/AGENTS.md" "$b64" <<'PY' || fail "save-instructions failed"
import sys, base64, os
dest, b64_data = sys.argv[1], sys.argv[2]
content = base64.b64decode(b64_data).decode("utf-8")
os.makedirs(os.path.dirname(dest), exist_ok=True)
tmp = dest + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(content)
os.replace(tmp, dest)
print("Saved instructions:", len(content), "bytes")
PY
            say "@@done"
            ;;
        add-skill)
            python3 - "$cfg_dir" "$rest" <<'PY' || fail "add-skill failed"
import sys, base64, os
cfg_dir, raw = sys.argv[1], sys.argv[2]
parts = raw.split("|")
name = parts[0].strip()
desc = base64.b64decode(parts[1]).decode("utf-8").strip() if len(parts) > 1 else ""
body = base64.b64decode(parts[2]).decode("utf-8") if len(parts) > 2 else ""

skill_dir = os.path.join(cfg_dir, "skills", name)
os.makedirs(skill_dir, exist_ok=True)
skill_md = os.path.join(skill_dir, "SKILL.md")

file_content = f"""---
name: {name}
description: >-
  {desc}
---

{body}
"""
tmp = skill_md + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(file_content)
os.replace(tmp, skill_md)
print("Skill created:", skill_md)
PY
            say "@@done"
            ;;
        delete-skill)
            local sname="$rest"
            local sdir="$cfg_dir/skills/$sname"
            if [ -d "$sdir" ]; then
                rm -rf "$sdir"
                say "Skill deleted: $sname"
            else
                fail "Skill not found: $sname"
            fi
            say "@@done"
            ;;
        toggle-skill)
            local sname="${rest%% *}"
            local val="${rest#* }"
            python3 - "$cfg_dir/config.json" "$sname" "$val" <<'PY' || fail "toggle-skill failed"
import json, sys, os
cfg_file, name, val = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(cfg_file):
    try:
        with open(cfg_file) as f:
            data = json.load(f)
    except:
        pass
disabled = set(data.get("disabledSkills", []))
if val == "1":
    disabled.discard(name)
else:
    disabled.add(name)
data["disabledSkills"] = sorted(list(disabled))
tmp = cfg_file + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg_file)
print("Skill toggle saved:", name, val)
PY
            say "@@done"
            ;;
        toggle-plugin)
            local pname="${rest%% *}"
            local val="${rest#* }"
            python3 - "$cfg_dir/config.json" "$pname" "$val" <<'PY' || fail "toggle-plugin failed"
import json, sys, os
cfg_file, name, val = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.exists(cfg_file):
    try:
        with open(cfg_file) as f:
            data = json.load(f)
    except:
        pass
plugins = data.setdefault("plugins", {})
pcfg = plugins.setdefault(name, {})
pcfg["enabled"] = (val == "1")
tmp = cfg_file + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
os.replace(tmp, cfg_file)
print("Plugin toggle saved:", name, val)
PY
            say "@@done"
            ;;
        copy-skill)
            python3 - "$cfg_dir" "$rest" <<'PY' || fail "copy-skill failed"
import sys, os, shutil

cfg_dir, raw = sys.argv[1], sys.argv[2]
parts = raw.split("|")
src_path = parts[0].strip()
target_name = parts[1].strip() if len(parts) > 1 and parts[1].strip() else ""

if not src_path or not os.path.exists(src_path):
    print("Error: Source skill path does not exist:", src_path)
    sys.exit(1)

src_dir = os.path.dirname(src_path) if os.path.isfile(src_path) else src_path
orig_name = os.path.basename(src_dir)
if not target_name:
    target_name = orig_name

user_skills_dir = os.path.join(cfg_dir, "skills")
os.makedirs(user_skills_dir, exist_ok=True)
dest_dir = os.path.join(user_skills_dir, target_name)

if os.path.abspath(src_dir) == os.path.abspath(dest_dir) or (os.path.exists(dest_dir) and len(parts) <= 1):
    dest_dir = os.path.join(user_skills_dir, target_name + "-custom")
    target_name = target_name + "-custom"

if os.path.exists(dest_dir):
    shutil.rmtree(dest_dir)

shutil.copytree(src_dir, dest_dir)
print(f"@@cust_skill_copied {target_name}|{dest_dir}")
print(f"Skill copied to user skills: {dest_dir}")
PY
            say "@@done"
            ;;
        read-skill)
            python3 - "$rest" <<'PY' || fail "read-skill failed"
import sys, os, re, base64

spath = sys.argv[1].strip()
if not os.path.exists(spath):
    print("Error: skill not found:", spath)
    sys.exit(1)

if os.path.isdir(spath):
    spath = os.path.join(spath, "SKILL.md")

with open(spath, encoding="utf-8", errors="replace") as f:
    content = f.read()

name = os.path.basename(os.path.dirname(spath))
desc = ""
body = content

m = re.search(r"^---\s*\n(.*?)\n---(.*)", content, re.DOTALL)
if m:
    fm = m.group(1)
    body = m.group(2).strip()
    nm = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
    if nm: name = nm.group(1).strip()
    dm = re.search(r"^description:\s*(?:>-\s*|\s*)(.+?)(?=\n[a-zA-Z0-9_-]+:|\Z)", fm, re.DOTALL | re.MULTILINE)
    if dm: desc = " ".join(dm.group(1).split())

b64_desc = base64.b64encode(desc.encode("utf-8")).decode("ascii")
b64_body = base64.b64encode(body.encode("utf-8")).decode("ascii")

print(f"@@cust_skill_data {name}|{b64_desc}|{b64_body}")
PY
            say "@@done"
            ;;
        install-plugin)
            if [ "$rest" = "android-cli-plugin" ] || [ "$rest" = "modern-web-guidance" ]; then
                command -v git >/dev/null 2>&1 || fail "Git is required; install it in Settings > Tools"
                python3 - "$cfg_dir" "$rest" <<'PYOFFICIAL' || fail "Official plugin installation failed"
import json, os, shutil, subprocess, sys, tempfile, urllib.request
cfg, name = sys.argv[1:]
plugins = os.path.join(cfg, "plugins")
os.makedirs(plugins, exist_ok=True)
target = os.path.join(plugins, name)
with tempfile.TemporaryDirectory(prefix="agy-plugin-", dir=plugins) as tmp:
    if name == "android-cli-plugin":
        home = os.environ["HOME"]
        loader = os.path.join(home, "runtime", "bin", "libloader.so")
        libdir = os.path.join(home, "runtime", "lib")
        dest = os.path.join(home, "opt", "android-cli", "android")
        bridge = os.path.join(home, "runtime", "bin", "android")
        if not os.path.isfile(loader) or not os.path.isfile(os.path.join(libdir, "libc.so.6")):
            raise SystemExit("Android CLI requires the bundled ARM64 glibc runtime")
        if os.path.lexists(bridge):
            try:
                with open(bridge, encoding="utf-8") as f:
                    managed = "# AGY_ANDROID_CLI_BRIDGE" in f.read(512)
            except (OSError, UnicodeError):
                managed = False
            if not managed:
                raise SystemExit("An existing android command was preserved; cannot replace its bridge")
        print("Downloading the official Linux ARM64 Android CLI (approximately 90 MB)...", flush=True)
        candidate = os.path.join(tmp, "android-cli")
        with urllib.request.urlopen("https://dl.google.com/android/cli/latest/linux_arm64/android-cli", timeout=60) as response, open(candidate, "wb") as out:
            shutil.copyfileobj(response, out, 1024 * 1024)
        with open(candidate, "rb") as f:
            hdr = f.read(20)
        if hdr[:4] != b"\x7fELF" or hdr[4:6] != b"\x02\x01" or hdr[18:20] != b"\xb7\x00":
            raise SystemExit("Downloaded Android CLI is not an ARM64 ELF executable")
        os.chmod(candidate, 0o755)
        env = dict(os.environ)
        env.pop("LD_PRELOAD", None)
        env.pop("LD_LIBRARY_PATH", None)
        print("Checking Android CLI with the bundled loader...", flush=True)
        try:
            check = subprocess.run([loader, "--library-path", libdir, candidate, "--version"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise SystemExit("Android CLI could not be started: " + str(exc))
        print(check.stdout[-4000:], flush=True)
        if check.returncode != 0:
            raise SystemExit("Android CLI compatibility check failed; existing tools were not replaced")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copyfile(candidate, dest + ".new")
        os.chmod(dest + ".new", 0o755)
        os.replace(dest + ".new", dest)
        bridge_text = '#!/system/bin/sh\n# AGY_ANDROID_CLI_BRIDGE\nunset LD_PRELOAD LD_LIBRARY_PATH\nexec "$HOME/runtime/bin/libloader.so" --library-path "$HOME/runtime/lib" "$HOME/opt/android-cli/android" "$@"\n'
        with open(bridge + ".new", "w", encoding="utf-8") as f:
            f.write(bridge_text)
        os.chmod(bridge + ".new", 0o755)
        os.replace(bridge + ".new", bridge)
        print("Android CLI installed and version check passed", flush=True)
    if os.path.exists(target):
        print("Plugin already installed; retained existing files", flush=True)
        raise SystemExit(0)
    checkout = os.path.join(tmp, "checkout")
    url = {"android-cli-plugin": "https://github.com/android/android-cli-plugin.git", "modern-web-guidance": "https://github.com/GoogleChrome/modern-web-guidance.git"}[name]
    subprocess.run(["git", "clone", "--depth", "1", url, checkout], check=True)
    if name == "android-cli-plugin":
        source = os.path.join(checkout, "plugins", "android-cli-codex")
        if not os.path.isfile(os.path.join(source, "skills", "android-cli", "SKILL.md")):
            raise SystemExit("Official Android CLI skill not found in repository")
        with open(os.path.join(source, "plugin.json"), "w", encoding="utf-8") as f:
            json.dump({"name": "Android CLI", "description": "Official Android CLI skill from android/android-cli-plugin", "version": "1"}, f)
    else:
        source = checkout
        if not os.path.isfile(os.path.join(source, "plugin.json")) or not os.path.isfile(os.path.join(source, "skills", "modern-web-guidance", "SKILL.md")):
            raise SystemExit("Official Modern Web Guidance files not found")
        shutil.rmtree(os.path.join(source, ".git"), ignore_errors=True)
    os.rename(source, target)
print("Official plugin installed:", name)
PYOFFICIAL
                say "@@done"
                return
            fi
            python3 - "$cfg_dir" "$rest" <<'PY' || fail "install-plugin failed"
import sys, os, json, shutil

cfg_dir, pname = sys.argv[1], sys.argv[2].strip()
plugins_dir = os.path.join(cfg_dir, "plugins")
os.makedirs(plugins_dir, exist_ok=True)
target_dir = os.path.join(plugins_dir, pname)

presets = {
    "google-workspace": {
        "name": "Google Workspace & Cloud",
        "desc": "Инструменты для работы с Google Docs, Sheets, Slides, Drive и Cloud API.",
        "skills": {
            "gdocs-editor": ("Создание и форматирование документов Google Docs", "# Google Docs Editor\n\nИнструкции для структурирования и экспорта документов в Google Docs."),
            "gsheets-analyzer": ("Анализ и редактирование таблиц Google Sheets", "# Google Sheets Analyzer\n\nПравила парсинга и анализа табличных данных Google Sheets."),
            "gdrive-manager": ("Поиск, выгрузка и управление файлами Google Drive", "# Google Drive Manager\n\nСценарии работы с облачным файловым хранилищем.")
        }
    },
    "python-data-science": {
        "name": "Python Data Science & ML",
        "desc": "Пакет навыков для анализа данных, машинного обучения, работы с Pandas, NumPy и Jupyter.",
        "skills": {
            "python-eda": ("Разведочный анализ данных (EDA), очистка и статистика", "# Python EDA Guide\n\nРегламент проведения эксплораторного анализа данных и предобработки."),
            "data-visualization": ("Построение графиков Matplotlib/Seaborn/Plotly", "# Data Visualization\n\nПравила визуализации и оформления графиков.")
        }
    },
    "database-tools": {
        "name": "SQLite & Mobile Databases",
        "desc": "Проектирование схем и оптимизация запросов для SQLite — нативной БД Android.",
        "skills": {
            "sqlite-optimizer": ("Анализ планов запросов и тюнинг индексов SQLite", "# SQLite Query Optimizer\n\nМетодология анализа планов запросов (EXPLAIN QUERY PLAN) и оптимизации индексов SQLite."),
            "schema-design": ("Проектирование нормализованных схем БД и миграций", "# Database Schema Design\n\nПравила нормализации, внешних ключей и версионирования миграций.")
        }
    },
    "security-audit": {
        "name": "Security Audit & Hardening",
        "desc": "Статический анализ уязвимостей, проверка зависимостей (CVE) и защита от утечки секретов.",
        "skills": {
            "security-review": ("Поиск уязвимостей OWASP Top 10 в исходном коде", "# Security Code Review\n\nПаттерны выявления инъекций, XSS, CSRF и небезопасной десериализации."),
            "secret-scanner": ("Обнаружение захардкоженных токенов и API ключей", "# Secret Scanner\n\nРегулярные выражения и правила детекции токенов в кодовой базе.")
        }
    },
    "git-advanced": {
        "name": "Git Automation & Conventional Flow",
        "desc": "Автоматизация веток, генерация Conventional Commits и подготовка Pull Request.",
        "skills": {
            "git-conventional-commits": ("Формирование семантических сообщений коммитов", "# Conventional Commits\n\nСтандарт feat/fix/docs/refactor/chore с краткими описаниями."),
            "git-pr-review": ("Подготовка описаний и чеклистов для Pull Request", "# Pull Request Guidelines\n\nШаблон оформления PR и самопроверки перед мерджем.")
        }
    },
    "antigravity-sdk": {
        "name": "Google Antigravity SDK",
        "desc": "Создание AI-агентов с помощью Python SDK для Antigravity.",
        "skills": {
            "antigravity-sdk-guide": ("Разработка агентов на Python SDK Antigravity", "# Antigravity Python SDK Guide\n\nПаттерны создания агентов, подключения инструментов и управления сессиями через Python SDK Antigravity.")
        }
    },
    "science": {
        "name": "Science",
        "desc": "Подборка навыков агента для научных задач: методы, статистика, оформление исследований.",
        "skills": {
            "scientific-research": ("Научные исследования: методы, статистика, оформление", "# Scientific Research\n\nРегламент планирования экспериментов, статистической обработки данных и оформления научных работ.")
        }
    },
    "firebase": {
        "name": "Firebase",
        "desc": "Проектирование, создание и запуск проектов Firebase: Auth, Firestore, Functions.",
        "skills": {
            "firebase-architect": ("Проектирование схем Firestore и правил безопасности", "# Firebase Architect\n\nПроектирование коллекций Firestore, структуры Auth и правил безопасности (Security Rules)."),
            "firebase-deploy": ("Деплой проекта Firebase и управление индексами", "# Firebase Deploy\n\nКонфигурация firebase.json, индексы, деплой Functions и проверка после публикации.")
        }
    }
}

pdata = presets.get(pname, {
    "name": pname,
    "desc": f"Пользовательский плагин {pname}",
    "skills": {
        f"{pname}-guide": (f"Руководство для плагина {pname}", f"# {pname} Guide\n\nИнструкции плагина.")
    }
})

os.makedirs(target_dir, exist_ok=True)
manifest = {
    "name": pdata["name"],
    "version": "1.0.0",
    "description": pdata["desc"]
}
with open(os.path.join(target_dir, "plugin.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)

with open(os.path.join(target_dir, "README.md"), "w", encoding="utf-8") as f:
    f.write(f"# {pdata['name']}\n\n{pdata['desc']}\n")

skills_base = os.path.join(target_dir, "skills")
for sk_name, (sk_desc, sk_body) in pdata["skills"].items():
    sdir = os.path.join(skills_base, sk_name)
    os.makedirs(sdir, exist_ok=True)
    with open(os.path.join(sdir, "SKILL.md"), "w", encoding="utf-8") as f:
        f.write(f"---\nname: {sk_name}\ndescription: >-\n  {sk_desc}\n---\n\n{sk_body}\n")

print(f"Plugin installed successfully: {target_dir}")
PY
            say "@@done"
            ;;
        uninstall-plugin)
            local pname="$rest"
            local pdir="$cfg_dir/plugins/$pname"
            if [ -d "$pdir" ]; then
                rm -rf "$pdir"
                say "Plugin uninstalled: $pname"
            else
                fail "Plugin directory not found: $pname"
            fi
            say "@@done"
            ;;
        reset-instructions)
            step "Resetting AGENTS.md to standard seed guidelines"
            local seed="$HOME/runtime/seed/AGENTS.md"
            [ -f "$seed" ] || seed="$PREFIX/etc/antigravity/AGENTS.md"
            if [ -f "$seed" ]; then
                cp "$seed" "$cfg_dir/AGENTS.md"
                say "Restored from seed."
            else
                fail "Seed AGENTS.md not found"
            fi
            say "@@done"
            ;;
        *)
            fail "unknown customizations subcommand: $cmd"
            ;;
    esac
}

# The tools console uses a PTY so a shell session retains cwd and environment.
op_termopen() {
    python3 -u - <<'PYTERM'
import os, pty, select, sys, errno
home=os.environ['HOME']; prefix=os.environ['PREFIX']
fifo=home+'/.agy-tools-terminal.fifo'; pidfile=home+'/.agy-tools-terminal.pid'
def owner_alive():  # AGY-P2-15: жив ли владелец прежней сессии
    try:
        with open(pidfile) as f: pid=int(f.read().strip())
        os.kill(pid,0); return True
    except (ValueError,OSError): return False
if os.path.lexists(fifo):
    if owner_alive():
        print('Terminal already exists or was not closed; restart the app to recover.', flush=True)
        sys.exit(1)
    try: os.unlink(fifo)
    except OSError: pass  # AGY-P2-15: stale FIFO от погибшей сессии — самоочистка
try:
    with open(pidfile,'w') as f: f.write(str(os.getpid()))
except OSError: pass
os.mkfifo(fifo,0o600)
pid,master=pty.fork()
if pid==0:
    os.environ['TERM']='xterm'; os.environ['PATH']=prefix+'/bin:'+home+'/runtime/bin:/system/bin'
    os.execv(prefix+'/bin/bash',[prefix+'/bin/bash','--noprofile','--norc','-i'])
try:
    rd=os.open(fifo,os.O_RDWR|os.O_NONBLOCK)
    print('@@TERMINAL_READY',flush=True)
    while True:
        ready,_,_=select.select([master,rd],[],[],0.25)
        if master in ready:
            try: data=os.read(master,8192)
            except OSError as e:
                if e.errno==errno.EIO: break
                raise
            if not data: break
            os.write(sys.stdout.fileno(),data)
        if rd in ready:
            data=os.read(rd,4096)
            if data: os.write(master,data)
        got,status=os.waitpid(pid,os.WNOHANG)
        if got==pid: break
finally:
    try: os.unlink(fifo)
    except OSError: pass
    try: os.unlink(pidfile)  # AGY-P2-15
    except OSError: pass
    try: os.close(master)
    except OSError: pass
PYTERM
}
op_terminput() {
    AGY_INPUT="$ARG" python3 - <<'PYINPUT'
import base64, os, sys
try:
    data=base64.b64decode(os.environ['AGY_INPUT'],validate=True)
    if not data or len(data)>400: raise ValueError('input size')
    fd=os.open(os.environ['HOME']+'/.agy-tools-terminal.fifo',os.O_WRONLY|os.O_NONBLOCK)
    os.write(fd,data); os.close(fd)
except Exception as e:
    print('Terminal input failed:', e); sys.exit(1)
PYINPUT
}
# AGY-P2-15: принудительное завершение зависшей терминальной сессии
op_termkill() {
    python3 - <<'PYKILL'
import os, sys
home=os.environ['HOME']; pidfile=home+'/.agy-tools-terminal.pid'
try:
    with open(pidfile) as f: pid=int(f.read().strip())
    os.kill(pid,15); print('terminal killed:', pid)
except FileNotFoundError:
    print('no terminal session')
except ProcessLookupError:
    print('terminal owner already dead; cleaning')
except Exception as e:
    print('termkill failed:', e); sys.exit(1)
for p in (home+'/.agy-tools-terminal.fifo', pidfile):
    try: os.unlink(p)
    except OSError: pass
PYKILL
}
op_histread() {
    AGY_OFFSET="$ARG" python3 - <<'PYHIST'
import os, glob, base64
try: off=int(os.environ['AGY_OFFSET'] or '0')
except ValueError: raise SystemExit(1)
if off<0: raise SystemExit(1)
root=os.path.join(os.environ['HOME'],'agy-tools')
chunks=[]
for d in sorted(glob.glob(os.path.join(root,'job-*'))):
    if d==os.environ.get('AGY_JOB_DIR'): continue
    try:
        with open(os.path.join(d,'log'),'rb') as f: data=f.read()
        try:
            with open(os.path.join(d,'rc'),'r') as f: rc=f.read().strip()
        except OSError: rc=''
        # AGY-P2-23: слово "error" в лицензиях/прогрессе не ошибка. Только rc!=0 или @@fail.
        if (rc and rc!='0') or b'@@fail ' in data:
            chunks.append(('\n=== '+os.path.basename(d)+' (rc='+rc+') ===\n').encode()+data+b'\n')
    except OSError: pass
all_data=b''.join(chunks); end=min(len(all_data),off+12000)
print('@@HISTORY %d %d %s' % (end,len(all_data),base64.b64encode(all_data[off:end]).decode()))
PYHIST
}


# AGY-P2-19: HTML → PDF (pymupdf), минуя пустой системный принтер.
op_pdfin() {
    AGY_PDF_CHUNK="$ARG" python3 - <<'PYPDFIN'
import os, sys, base64
home = os.environ["HOME"]
d = os.path.join(home, ".agy-pdf")
os.makedirs(d, exist_ok=True)
raw = os.environ.get("AGY_PDF_CHUNK", "")
if raw == "RESET":
    open(os.path.join(d, "in.html"), "w").close()
    print("pdfin reset")
    sys.exit(0)
try:
    data = base64.b64decode(raw)
except Exception as e:
    print("pdfin bad chunk:", e); sys.exit(1)
if len(data) > 200000:
    print("pdfin chunk too large"); sys.exit(1)
path = os.path.join(d, "in.html")
if os.path.exists(path) and os.path.getsize(path) > 8000000:
    print("pdfin html too large"); sys.exit(1)
with open(path, "ab") as f:
    f.write(data)
print("pdfin", len(data))
PYPDFIN
}
op_pdf() {
    python3 - <<'PYPDF'
import os, sys, base64
home = os.environ["HOME"]
src = os.path.join(home, ".agy-pdf", "in.html")
dst = os.path.join(home, ".agy-pdf", "out.pdf")
if not os.path.isfile(src) or os.path.getsize(src) == 0:
    print("pdf: empty html"); sys.exit(1)
html = open(src, encoding="utf-8", errors="replace").read()
try:
    import pymupdf
except Exception as e:
    print("pdf: pymupdf missing:", e); sys.exit(1)
css = "body{font-family:sans-serif;font-size:12px;line-height:1.35} h1{font-size:20px} h2{font-size:16px} pre,code{font-family:monospace;font-size:10px} table{border-collapse:collapse} td,th{border:1px solid #999;padding:4px}"
story = pymupdf.Story(html=html, user_css=css)
mediabox = pymupdf.paper_rect("a4")
where = mediabox + (36, 36, -36, -36)
writer = pymupdf.DocumentWriter(dst)
more = True
pages = 0
while more and pages < 80:
    dev = writer.begin_page(mediabox)
    more, _ = story.place(where)
    story.draw(dev)
    writer.end_page()
    pages += 1
writer.close()
data = open(dst, "rb").read()
if len(data) < 500 or not data.startswith(b"%PDF"):
    print("pdf: empty or invalid output", len(data)); sys.exit(1)
print("PDF pages", pages, "bytes", len(data))
b64 = base64.b64encode(data).decode("ascii")
step = 12000
for i in range(0, len(b64), step):
    print("@@PDFB64 " + b64[i:i+step])
PYPDF
}


# AGY-P2-20: одна команда консоли инструментов (не PTY проекта).
# Нужна, потому что FIFO сессии termopen умирает вместе с джобой:
# terminput тогда падает с ENXIO/ENOENT.
op_termrun() {
    AGY_TERM_B64="$ARG" python3 - <<'PYRUN'
import os, sys, base64, subprocess
raw = os.environ.get("AGY_TERM_B64", "")
try:
    cmd = base64.b64decode(raw).decode("utf-8", "replace")
except Exception as e:
    print("bad command:", e); sys.exit(1)
cmd = cmd.replace("\r", "").strip("\n")
if not cmd.strip():
    print("(empty)"); sys.exit(0)
if len(cmd) > 4000:
    print("command too long"); sys.exit(1)
home = os.environ.get("HOME", "/")
prefix = os.environ.get("PREFIX", "")
env = os.environ.copy()
env["PATH"] = ":".join(x for x in [
    prefix + "/bin" if prefix else "",
    home + "/runtime/bin",
    "/system/bin",
    env.get("PATH", ""),
] if x)
env["TERM"] = "dumb"
env["HOME"] = home
try:
    p = subprocess.run(
        [prefix + "/bin/bash", "--noprofile", "--norc", "-lc", cmd],
        cwd=home,
        env=env,
        capture_output=True,
        timeout=25,
    )
except subprocess.TimeoutExpired as e:
    out = (e.stdout or b"") + (e.stderr or b"")
    sys.stdout.buffer.write(out)
    print("\n(timeout 25s)")
    sys.exit(124)
data = (p.stdout or b"") + (p.stderr or b"")
if len(data) > 200000:
    data = data[:200000] + b"\n...(truncated)"
sys.stdout.buffer.write(data)
if data and not data.endswith(b"\n"):
    sys.stdout.buffer.write(b"\n")
print("(exit %d)" % p.returncode)
sys.exit(0 if p.returncode == 0 else 1)
PYRUN
}


# AGY-P2-20: очистка журнала ошибок инструментов (логи джоб с rc!=0).
op_histclear() {
    python3 - <<'PYCLR'
import os, glob, shutil
root = os.path.join(os.environ["HOME"], "agy-tools")
n = 0
for d in glob.glob(os.path.join(root, "job-*")):
    rc = ""
    try:
        with open(os.path.join(d, "rc")) as f:
            rc = f.read().strip()
    except OSError:
        continue
    if rc and rc != "0":
        shutil.rmtree(d, ignore_errors=True)
        n += 1
print("cleared", n)
PYCLR
}

# AGY-BRAND: swap the login-screen logo for the chosen Leostryx pack.
# Web-side assets live under $HOME/web/brand/<pack>/. The APK-bound resources
# (splash drawable, mipmap launcher icon, app label) are recorded in
# $HOME/web/brand/config.json for rebuild.py to pick up on the next build.
op_brand() {
    # ARG is "pack" or "pack@colour" (colour is optional and only recorded).
    local raw="$ARG" pack="" colour=""
    [ -n "$raw" ] || fail "brand: pack name required"
    pack="${raw%%@*}"
    case "$raw" in *@*) colour="${raw#*@}" ;; esac
    case "$pack" in
        01_owl|02_lynx|03_lsx|04_angular_x) ;;
        *) fail "brand: unknown pack '$pack'" ;;
    esac
    if [ -n "$colour" ]; then
        case "$colour" in
            [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) colour="#$colour" ;;
            \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;;
            *) fail "brand: invalid colour '$colour'" ;;
        esac
    fi
    local web="$HOME/web"
    local src="$web/brand/$pack"
    [ -d "$src" ] || fail "brand: pack assets missing at $src"
    [ -f "$src/ic_launcher_logo.png" ] || fail "brand: ic_launcher_logo.png missing in pack"

    step "Applying logo pack: $pack"
    # Login screen logo (agy_firstrun.html references ./agy_firstrun_logo.png).
    cp -f "$src/ic_launcher_logo.png" "$web/agy_firstrun_logo.png" \
        || fail "brand: cannot write agy_firstrun_logo.png"
    # Keep a copy the web UI can re-read for previews/verification.
    cp -f "$src/ic_launcher_logo.png" "$web/brand/current_logo.png" 2>/dev/null || true

    # Persist for the next APK build (splash + launcher icon + label + colour).
    AGY_BRAND_PACK="$pack" AGY_BRAND_COLOUR="$colour" AGY_BRAND_WEB="$web" python3 - <<'PYBR'
import json, os, pathlib
web = pathlib.Path(os.environ["AGY_BRAND_WEB"])
pack = os.environ["AGY_BRAND_PACK"]
colour = os.environ.get("AGY_BRAND_COLOUR", "").strip()
cfg = {"pack": pack, "name": "Leostryx"}
try:
    old = json.loads((web / "brand" / "config.json").read_text(encoding="utf-8"))
    if isinstance(old, dict):
        cfg.update(old)
except Exception:
    pass
cfg["pack"] = pack
cfg["name"] = "Leostryx"
if colour:
    cfg["color"] = colour
(web / "brand" / "config.json").write_text(
    json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("brand: recorded pack=%s color=%s" % (pack, cfg.get("color", "-")))
PYBR
    local alias_name=""
    case "$pack" in
        01_owl)       alias_name="LauncherOwl" ;;
        02_lynx)      alias_name="LauncherLynx" ;;
        03_lsx)       alias_name="LauncherLsx" ;;
        04_angular_x) alias_name="LauncherAngularX" ;;
    esac

    if [ -n "$alias_name" ]; then
        step "Switching launcher icon to $alias_name"
        local pkg_name="${RISH_APPLICATION_ID:-com.agy}"
        local all_aliases="LauncherOwl LauncherLynx LauncherLsx LauncherAngularX"
        for al in $all_aliases; do
            if [ "$al" = "$alias_name" ]; then
                pm enable "$pkg_name/com.agy.ui.launcher.$al" 2>/dev/null || true
                rish -c "cmd package set-component-enabled --user 0 $pkg_name/com.agy.ui.launcher.$al 1" 2>/dev/null || true
            else
                pm disable "$pkg_name/com.agy.ui.launcher.$al" 2>/dev/null || true
                rish -c "cmd package set-component-enabled --user 0 $pkg_name/com.agy.ui.launcher.$al 2" 2>/dev/null || true
            fi
        done
    fi

    say "@@done brand $pack"
}

# AGY-BACKUP: экспорт всех данных приложения (провайдеры, MCP, настройки, чаты, фото)
op_backup() {
    AGY_BACKUP_ARG="$ARG" python3 - << 'PYBK'
import os, json, time, zipfile, shutil

home = os.environ["HOME"]
ts = time.strftime("%Y%m%d-%H%M%S")
# Parse ARG: path@items (items = comma-separated: providers,mcp,settings,chats,attachments)
raw = os.environ.get("AGY_BACKUP_ARG", "").strip()
if "@" in raw:
    custom, items_str = raw.split("@", 1)
else:
    custom, items_str = raw, ""
items = set(x.strip() for x in items_str.split(",") if x.strip())
if not items:
    items = {"providers", "mcp", "settings", "chats", "attachments"}
ext = "/storage/emulated/0"
default_dir = os.path.join(ext, "Leostryx Backup") if os.path.isdir(ext) and os.access(ext, os.W_OK) else os.path.join(home, "agy-backup")
outdir = custom.strip() if custom.strip() else default_dir
os.makedirs(outdir, exist_ok=True)
outpath = os.path.join(outdir, f"agy-backup-{ts}.zip")

z = zipfile.ZipFile(outpath, "w")
count = 0

# Binary files (databases, images, audio) don't compress well - use STORED (fast)
# Text configs are small - use DEFLATED (compact)
import zipfile as _zf
def _add(z, src, dst):
    ext = os.path.splitext(dst)[1].lower()
    if ext in ('.db', '.db-wal', '.db-shm', '.jpg', '.jpeg', '.png', '.webp', '.mp3', '.so', '.bin', '.tflite'):
        info = zipfile.ZipInfo(dst)
        info.compress_type = zipfile.ZIP_STORED
        with open(src, 'rb') as f:
            z.writestr(info, f.read())
    else:
        z.write(src, dst, compress_type=zipfile.ZIP_DEFLATED)

# providers
if "providers" in items:
    src = os.path.join(home, "agy-providers", "providers.json")
    if os.path.isfile(src):
        _add(z, src, "providers.json")
        count += 1

# config (mcp + settings + agents + skills + AGENTS.md)
if "mcp" in items:
    src = os.path.join(home, ".gemini", "config", "mcp_config.json")
    if os.path.isfile(src):
        _add(z, src, "config/mcp_config.json")
        count += 1
if "settings" in items:
    for fn in ("config.json", "AGENTS.md"):
        src = os.path.join(home, ".gemini", "config", fn)
        if os.path.isfile(src):
            _add(z, src, f"config/{fn}")
            count += 1
    for sub in ("agents", "skills", "rules"):
        sdir = os.path.join(home, ".gemini", "config", sub)
        if os.path.isdir(sdir):
            for dirpath, dirs, files in os.walk(sdir):
                for f in files:
                    full = os.path.join(dirpath, f)
                    rel = os.path.relpath(full, os.path.join(home, ".gemini"))
                    _add(z, full, rel)
                    count += 1

# conversations (SQLite DBs)
if "chats" in items:
    conv_dir = os.path.join(home, ".gemini/antigravity-app/conversations")
    if os.path.isdir(conv_dir):
        for f in os.listdir(conv_dir):
            if f.endswith(".db") or f.endswith(".db-wal") or f.endswith(".db-shm"):
                _add(z, os.path.join(conv_dir, f), f"conversations/{f}")
                count += 1

# brain data (attachments, artifacts, user uploads)
if "attachments" in items:
    brain_dir = os.path.join(home, ".gemini/antigravity-app/brain")
    if os.path.isdir(brain_dir):
        for dirpath, dirs, files in os.walk(brain_dir):
            for f in files:
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, brain_dir)
                _add(z, full, f"brain/{rel}")
                count += 1

# manifest
manifest = {
    "version": 1,
    "created": ts,
    "files": count,
    "items": sorted(items),
    "app_version": "3.0.6",
}
z.writestr("manifest.json", json.dumps(manifest, indent=2))
z.close()

size = os.path.getsize(outpath)
print(f"@@BACKUP {outpath} {size} {count}")
PYBK
}

# AGY-BACKUP: восстановление данных из архива
op_restore() {
    AGY_RESTORE="$ARG" python3 - << 'PYRS'
import os, sys, json, zipfile, shutil

home = os.environ["HOME"]
src = os.environ.get("AGY_RESTORE", "")
if not src or not os.path.isfile(src):
    print("@@RESTORE ERR: file not found:", src); sys.exit(1)

try:
    z = zipfile.ZipFile(src)
except Exception as e:
    print("@@RESTORE ERR: bad zip:", e); sys.exit(1)

# manifest
try:
    m = json.loads(z.read("manifest.json"))
    print("@@RESTORE manifest version=%s files=%s" % (m.get("version"), m.get("files")))
except Exception:
    pass

restored = 0

# providers
if "providers.json" in z.namelist():
    dst = os.path.join(home, "agy-providers", "providers.json")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "wb") as f:
        f.write(z.read("providers.json"))
    restored += 1

# config files
for name in z.namelist():
    if name.startswith("config/"):
        dst = os.path.join(home, ".gemini", name)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(z.read(name))
        restored += 1

# conversations
conv_dir = os.path.join(home, ".gemini/antigravity-app/conversations")
os.makedirs(conv_dir, exist_ok=True)
for name in z.namelist():
    if name.startswith("conversations/"):
        dst = os.path.join(conv_dir, os.path.basename(name))
        with open(dst, "wb") as f:
            f.write(z.read(name))
        restored += 1

# brain
brain_dir = os.path.join(home, ".gemini/antigravity-app/brain")
for name in z.namelist():
    if name.startswith("brain/"):
        rel = name[6:]  # strip "brain/"
        if not rel or rel.endswith("/"): continue
        dst = os.path.join(brain_dir, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(z.read(name))
        restored += 1

z.close()
print(f"@@RESTORE OK {restored}")
PYRS
}

# AGY-BACKUP: список бэкапов по времени (новые первые)
op_bklist() {
    python3 - << 'PYBL'
import os, glob, time
dirs = [
    "/storage/emulated/0/Leostryx Backup",
    "/storage/emulated/0/Antigravity Backup",
    os.path.join(os.environ["HOME"], "agy-backup"),
]
seen = set()
all_files = []
for d in dirs:
    if os.path.isdir(d):
        for f in glob.glob(os.path.join(d, "agy-backup-*.zip")):
            bn = os.path.basename(f)
            if bn not in seen:
                seen.add(bn)
                all_files.append(f)
files = sorted(all_files, key=os.path.getmtime, reverse=True)
for f in files[:30]:
    sz = os.path.getsize(f)
    ts = time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(f)))
    print("@@BKFILE %s %d %s" % (os.path.basename(f), sz, ts))
PYBL
}

# AGY-BACKUP: удаление одного бэкапа
op_bkdelete() {
    AGY_BKDEL="$ARG" python3 - << 'PYBD'
import os, sys
name = os.environ.get("AGY_BKDEL", "").strip()
if not name or "/" in name or ".." in name:
    print("@@BKDEL ERR:bad name"); sys.exit(1)
dirs = [
    "/storage/emulated/0/Leostryx Backup",
    "/storage/emulated/0/Antigravity Backup",
    os.path.join(os.environ["HOME"], "agy-backup"),
]
deleted = False
for d in dirs:
    path = os.path.join(d, name)
    if os.path.isfile(path):
        os.unlink(path)
        deleted = True
if not deleted:
    print("@@BKDEL ERR:not found"); sys.exit(1)
print("@@BKDEL OK", name)
PYBD
}

# AGY-UPDATE: проверка обновления на GitHub
op_updatecheck() {
    python3 - << 'PYUC'
import json, urllib.request, ssl
ctx = ssl._create_unverified_context()
try:
    req = urllib.request.Request(
        "https://api.github.com/repos/Leostrange/Leostryx/releases/latest",
        headers={"Accept": "application/vnd.github.v3+json", "User-Agent": "Leostryx-App"}
    )
    data = json.loads(urllib.request.urlopen(req, timeout=10, context=ctx).read())
    tag = (data.get("tag_name", "") or "-").strip().replace(" ", "_")
    name = (data.get("name", "") or tag or "-").strip().replace(" ", "_")
    apk_url = ""
    for a in data.get("assets", []):
        if a["name"].endswith("-bypass.apk") or a["name"].endswith("bypass.apk"):
            apk_url = a["browser_download_url"]
            break
    if not apk_url:
        for a in data.get("assets", []):
            if a["name"].endswith("-standard.apk"):
                apk_url = a["browser_download_url"]
                break
    if not apk_url:
        for a in data.get("assets", []):
            if a["name"].endswith(".apk"):
                apk_url = a["browser_download_url"]
                break
    print("@@UPDATE %s %s %s" % (tag, name, apk_url))
except Exception as e:
    print("@@UPDATE ERR", e)
PYUC
}

# AGY-UPDATE: скачивание и установка APK
op_updatedownload() {
    AGY_APKURL="$ARG" python3 - << 'PYUD'
import os, sys, subprocess, urllib.request, ssl
url = os.environ.get("AGY_APKURL", "").strip()
if not url.startswith("https://"):
    print("@@UPD ERR:bad url", flush=True); sys.exit(1)
dst = "/storage/emulated/0/Download/update-temp.apk"
print("@@UPD downloading...", flush=True)
ctx = ssl._create_unverified_context()
try:
    req = urllib.request.Request(url, headers={"User-Agent": "Antigravity-App"})
    with urllib.request.urlopen(req, timeout=180, context=ctx) as r, open(dst, "wb") as f:
        total = int(r.headers.get("Content-Length", 0))
        done = 0
        while True:
            chunk = r.read(262144)
            if not chunk: break
            f.write(chunk)
            done += len(chunk)
            if total > 0:
                print("@@UPDPROGRESS %d %d" % (done, total), flush=True)
    sz = os.path.getsize(dst)
    print("@@UPD downloaded %d" % sz, flush=True)
    installed = False
    try:
        r = subprocess.run(["rish", "-c", "pm install -r " + dst], capture_output=True, text=True, timeout=60)
        out = (r.stdout + r.stderr).strip()
        if r.returncode == 0 or "Success" in out:
            installed = True
    except Exception:
        pass
    if not installed:
        try:
            r = subprocess.run(["pm", "install", "-r", dst], capture_output=True, text=True, timeout=60)
            out = (r.stdout + r.stderr).strip()
            if r.returncode == 0 or "Success" in out:
                installed = True
        except Exception:
            pass
    if installed:
        print("@@UPDOK installed", flush=True)
    else:
        # Fallback intent via rish
        try:
            subprocess.run(["rish", "-c", "am start -a android.intent.action.VIEW -d file://" + dst + " -t application/vnd.android.package-archive --grant-read-uri-permission"], capture_output=True, text=True, timeout=10)
        except Exception:
            pass
        print("@@UPDREADY " + dst, flush=True)
except Exception as e:
    print("@@UPD ERR", e, flush=True)
PYUD
}

case "$OP" in
    termopen)       op_termopen ;;
    terminput)      op_terminput ;;
    termkill)       op_termkill ;;  # AGY-P2-15
    termrun)        op_termrun ;;   # AGY-P2-20
    histread)       op_histread ;;
    histclear)      op_histclear ;;  # AGY-P2-20
    brand)          op_brand ;;      # AGY-BRAND
    backup)         op_backup ;;    # AGY-BACKUP
    restore)        op_restore ;;   # AGY-BACKUP
    bklist)         op_bklist ;;    # AGY-BACKUP
    bkdelete)       op_bkdelete ;;  # AGY-BACKUP
    updatecheck)    op_updatecheck ;; # AGY-UPDATE
    updatedownload) op_updatedownload ;; # AGY-UPDATE
    pdfin)          op_pdfin ;;  # AGY-P2-19
    pdf)            op_pdf ;;    # AGY-P2-19
    status)         op_status ;;
    index)          op_index ;;
    install)        op_install ;;
    remove)         op_remove ;;
    upgrade)        op_upgrade ;;
    pkgstats)       op_pkgstats ;;
    npm)            op_npm ;;
    sdk)            op_sdk ;;
    sdkremove)      op_sdkremove ;;
    ndk)            op_ndk ;;
    ndkremove)      op_ndkremove ;;
    flutter)        op_flutter ;;
    flutterremove)  op_flutterremove ;;
    policy)         op_policy ;;
    verify)         op_verify ;;
    mcp)            op_mcp ;;
    customizations) op_customizations ;;
    *)              fail "unknown op: $OP" ;;
esac

