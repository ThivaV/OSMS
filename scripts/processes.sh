#!/bin/sh
# OSMS's processes, however they were started: by make, by Tilt, in a terminal or by
# another tool. `make status` lists them and `make stop` stops them.
#
#   sh scripts/processes.sh list [service ...]
#   sh scripts/processes.sh stop [service ...]   # Ctrl+C first; a plain kill after 15 s
#
# Services: tilt, app, widgetbook, auth, api, worker, milvus, glimmer (all by default).
# A process counts as OSMS's only when it runs one of these services' programs AND its
# command line or working directory is inside this repo, so shells, editors and other
# projects are never touched. Ollama's server (glimmer) is the one exception: it counts
# wherever it was started.
set -u

repo=$(cd "$(dirname "$0")/.." && pwd -P)
me=$(id -u)
action=${1:-list}
[ $# -gt 0 ] && shift
named="$*"
all="tilt app widgetbook auth api worker milvus glimmer"
wanted=" ${*:-$all} "

# The service a process belongs to, or nothing.
service_of() {
  pid=$1 prog=$2
  args=$(ps -o args= -p "$pid" 2>/dev/null) || return 0
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  if [ "$prog" = ollama ]; then
    case "$args" in *" serve"*) echo glimmer ;; esac
    return 0
  fi
  case "$args $cwd/" in *"$repo/"*) ;; *) return 0 ;; esac
  case "$prog" in
    python*|uv|uvicorn)
      case "$args" in
        *"-m app.db.milvus_server"*) echo milvus ;;
        *"-m app.worker"*) echo worker ;;
        *"uvicorn app.main:app"*) echo api ;;
      esac ;;
    node|npm)
      case "$args" in *src/main.ts*) echo auth ;; esac ;;
    dart|flutter)
      case "$args" in
        *"flutter_tools.snapshot run"*|*build_runner*)
          case "$cwd/" in
            "$repo/frontend/widgetbook/"*) echo widgetbook ;;
            "$repo/frontend/"*) echo app ;;
          esac ;;
      esac ;;
    OSMS) echo app ;;
    tilt)
      case "$args" in *" up"*|*" ci"*) echo tilt ;; esac ;;
  esac
}

# "pid service" for each wanted OSMS process; only programs a service can run are looked at.
find_pids() {
  ps -axo pid=,uid=,comm= | while read -r pid uid comm; do
    [ "$uid" = "$me" ] && [ "$pid" != "$$" ] || continue
    prog=${comm##*/}  # (not basename: login shells are named "-zsh")
    case "$prog" in python*|uv|uvicorn|node|npm|dart|flutter|OSMS|tilt|ollama) ;; *) continue ;; esac
    svc=$(service_of "$pid" "$prog")
    case "$wanted" in *" $svc "*) [ -n "$svc" ] && echo "$pid $svc" ;; esac
  done
}

# Lines of "pid service" still alive.
alive() {
  printf '%s\n' "$1" | while read -r pid svc; do
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "$pid $svc"
  done
}

# One line per service: "worker: running (pid 7521 7530)".
show() {
  printf '%s\n' "$1" | awk -v verb="$2" 'NF { p[$2] = p[$2] " " $1 }
    END { for (s in p) printf "%s: %s (pid%s)\n", s, verb, p[s] }' | sort
}

# Ctrl+C to every process in "pid service" lines, then a plain kill to what is left.
stop_these() {
  [ -n "$1" ] || return 0
  show "$1" stopping
  printf '%s\n' "$1" | while read -r pid svc; do kill -INT "$pid" 2>/dev/null; done
  left=$1
  for _ in $(seq 1 30); do
    left=$(alive "$left")
    [ -z "$left" ] && return 0
    sleep 0.5
  done
  show "$left" "didn't stop on Ctrl+C, killing"
  printf '%s\n' "$left" | while read -r pid svc; do kill -TERM "$pid" 2>/dev/null; done
  sleep 2
  left=$(alive "$left")
  [ -z "$left" ] && return 0
  show "$left" "still running; stop it by hand"
  return 1
}

case "$action" in
  list)
    found=$(find_pids)
    if [ -z "$found" ]; then echo "Nothing of OSMS's is running."; else show "$found" running; fi
    ;;
  stop)
    # Tilt first, so it can't restart what it was running.
    status=0
    case "$wanted" in
      *" tilt "*) stop_these "$(wanted=" tilt " find_pids)" || status=1 ;;
    esac
    found=$(find_pids)
    if [ -z "$found" ] && [ $status -eq 0 ]; then
      if [ -n "$named" ]; then echo "$named: not running"; else echo "Nothing (else) of OSMS's was running."; fi
    else
      stop_these "$found" || status=1
    fi
    exit $status
    ;;
  *)
    echo "usage: sh scripts/processes.sh list|stop [service ...]" >&2
    exit 2
    ;;
esac
