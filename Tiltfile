# OSMS local development: `make up` (or `tilt up`) at the repo root.
# Tilt UI: http://localhost:10350. Rules: AGENTS.md, "Local development with Tilt".
#
# A resource joins when its code exists. The backend ones (milvus, glimmer, api,
# worker, overnight-agent, backend-checks, eval) arrive with the backend code. SQLite
# needs none: it is a file in data/.

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

# ── Frontend ─────────────────────────────────────────────────────────────────

flutter_web('app', 'frontend', 8080, watch=['frontend/lib'])

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

local_resource(
    'flutter-checks',
    cmd='make check',
    trigger_mode=TRIGGER_MODE_MANUAL,
    auto_init=False,
    allow_parallel=True,
    labels=['checks'],
)
