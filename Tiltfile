# OSMS local development: `make up` (or `tilt up`) at the repo root.
# Tilt UI: http://localhost:10350. Rules: AGENTS.md, "Local development with Tilt".
#
# A resource joins when its code exists. Running today: glimmer (Ollama, when installed),
# auth (Better Auth), api, worker (the story pipeline, with Fetch now, Make briefing now and
# Pipeline status buttons), app, Widgetbook and the check buttons. Still to come with its
# code: eval. SQLite needs no resource; Milvus Lite runs as the worker's child process.

load('ext://uibutton', 'cmd_button')

# OSMS never uses Kubernetes. `make up` hides every kube context from Tilt; if one is
# still visible (plain `tilt up`), stop here so Tilt can never act on a real cluster.
# Never add allow_k8s_contexts() to this file.
if k8s_context():
    fail('OSMS does not use Kubernetes, but Tilt can see the kube context "%s". ' % k8s_context() +
         'Start it with `make up`, which hides kube contexts from Tilt.')

# Never send Tilt usage data from this project.
analytics_settings(False)

PIDS = os.path.join(config.main_dir, '.tilt')

def signal_flutter(sig, pid_file):
    """Send `sig` only if the pid is still a Flutter process: pid files go stale when
    Tilt stops Flutter, and a reused pid could belong to anything."""
    return ('pid=$(cat "%s" 2>/dev/null) && ps -p "$pid" -o command= | grep -q flutter ' +
            '&& kill -%s "$pid" || true') % (pid_file, sig)

def flutter_web(name, project_dir, port, watch, resource_deps=[]):
    """A Flutter web server, hot-reloaded on save, with a Hot restart button.

    Flutter can't read keys under Tilt, so reloads go through its pid file:
    SIGUSR1 hot-reloads and SIGUSR2 hot-restarts (`flutter run --help`).
    """
    # `tilt-` keeps these apart from `make app` / `make widgetbook`'s own pid files.
    pid_file = os.path.join(PIDS, 'tilt-' + name + '.pid')
    local_resource(
        name,
        serve_cmd='mkdir -p "%s" && rm -f "%s" && flutter run -d web-server --web-port=%d --pid-file="%s"' % (
            PIDS, pid_file, port, pid_file),
        serve_dir=project_dir,
        resource_deps=resource_deps,
        labels=['frontend'],
        links=[link('http://localhost:%d' % port, 'Open %s' % name)],
        # A port check: an HTTP probe would log the whole index.html on success.
        readiness_probe=probe(tcp_socket=tcp_socket_action(port=port), period_secs=5),
    )
    local_resource(
        name + '-reload',
        cmd=signal_flutter('USR1', pid_file),
        deps=watch,
        resource_deps=[name],
        auto_init=False,
        allow_parallel=True,
        labels=['frontend'],
    )
    cmd_button(
        name + '-restart',
        resource=name,
        argv=['sh', '-c', signal_flutter('USR2', pid_file)],
        text='Hot restart',
        icon_name='restart_alt',
    )

# ── Models ───────────────────────────────────────────────────────────────────

# Muse Glimmer for the triage agent: Ollama, on 127.0.0.1 only. Only when Ollama is
# installed (without it the worker triages with its word list); an Ollama already running
# (the menu-bar app, say) is reused rather than fought over the port. Its model, once:
# `make glimmer-model`.
HAS_OLLAMA = str(local('command -v ollama || true', quiet=True)).strip() != ''
if HAS_OLLAMA:
    local_resource(
        'glimmer',
        serve_cmd='if curl -sf http://127.0.0.1:11434/api/version >/dev/null; then ' +
                  'echo "Ollama is already running on 127.0.0.1:11434: using it"; exec tail -f /dev/null; ' +
                  'else OLLAMA_HOST=127.0.0.1:11434 exec ollama serve; fi',
        labels=['models'],
        readiness_probe=probe(http_get=http_get_action(port=11434, path='/api/version'), period_secs=5),
    )

# ── Backend ──────────────────────────────────────────────────────────────────

# Sign-in: Better Auth (Node). Restarts when its code or .env changes.
local_resource(
    'auth',
    serve_cmd='npm start',
    serve_dir='auth',
    deps=['auth/src', '.env'],
    labels=['backend'],
    links=[link('http://localhost:3000/providers', 'Sign-in methods')],
    readiness_probe=probe(http_get=http_get_action(port=3000, path='/health'), period_secs=5),
)

# The API. Uvicorn reloads on code changes; Tilt restarts it when .env changes.
local_resource(
    'api',
    serve_cmd='uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000',
    serve_dir='backend',
    deps=['.env'],
    resource_deps=['auth'],
    labels=['backend'],
    links=[link('http://localhost:8000/docs', 'API docs')],
    readiness_probe=probe(http_get=http_get_action(port=8000, path='/health'), period_secs=5),
)

# The story pipeline: scheduled fetches, the jobs queue, triage, BGE-M3, Milvus Lite (a
# child process on 127.0.0.1, the only one that opens data/milvus.db), clustering, the
# agents, the morning briefing and illustrations. Restarts on code or .env changes; a
# restart loses nothing (the queue is in SQLite). It checks for Glimmer when it starts.
local_resource(
    'worker',
    serve_cmd='uv run python -m app.worker run',
    serve_dir='backend',
    deps=['.env', 'backend/app'],
    resource_deps=['api'] + (['glimmer'] if HAS_OLLAMA else []),
    labels=['backend'],
)
cmd_button(
    'worker:fetch-now',
    argv=['sh', '-c', 'cd backend && uv run python -m app.worker fetch-now'],
    resource='worker',
    icon_name='refresh',
    text='Fetch now',
)
cmd_button(
    'worker:briefing',
    argv=['sh', '-c', 'cd backend && uv run python -m app.worker briefing'],
    resource='worker',
    icon_name='podcasts',
    text='Make briefing now',
)
cmd_button(
    'worker:status',
    argv=['sh', '-c', 'cd backend && uv run python -m app.worker status'],
    resource='worker',
    icon_name='insights',
    text='Pipeline status',
)

# ── Frontend ─────────────────────────────────────────────────────────────────

flutter_web('app', 'frontend', 8080, watch=['frontend/lib'])

# The macOS desktop app (needs Xcode). It opens a window, so it starts from its button,
# never on `tilt up`; saving a file hot-reloads it like the web app.
MAC_PID = os.path.join(PIDS, 'tilt-app-macos.pid')
local_resource(
    'app-macos',
    serve_cmd='mkdir -p "%s" && rm -f "%s" && flutter run -d macos --pid-file="%s"' % (PIDS, MAC_PID, MAC_PID),
    serve_dir='frontend',
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
    labels=['frontend'],
)
local_resource(
    'app-macos-reload',
    cmd=signal_flutter('USR1', MAC_PID),
    deps=['frontend/lib'],
    resource_deps=['app-macos'],
    auto_init=False,
    allow_parallel=True,
    labels=['frontend'],
)
cmd_button(
    'app-macos-restart',
    resource='app-macos',
    argv=['sh', '-c', signal_flutter('USR2', MAC_PID)],
    text='Hot restart',
    icon_name='restart_alt',
)

local_resource(
    'widgetbook-gen',
    serve_cmd='dart run build_runner watch',
    serve_dir='frontend/widgetbook',
    labels=['frontend'],
)

flutter_web(
    'widgetbook',
    'frontend/widgetbook',
    8090,
    watch=['frontend/lib', 'frontend/widgetbook/lib'],
    resource_deps=['widgetbook-gen'],
)

# ── Checks (buttons) ─────────────────────────────────────────────────────────

for name, target in [('flutter-checks', 'check-flutter'), ('backend-checks', 'check-backend'), ('auth-checks', 'check-auth')]:
    local_resource(
        name,
        cmd='make ' + target,
        trigger_mode=TRIGGER_MODE_MANUAL,
        auto_init=False,
        allow_parallel=True,
        labels=['checks'],
    )
