# OSMS developer commands. `make` (or `make help`) lists them.
# Every target wraps a plain command; see AGENTS.md, "Common commands".
# More backend targets (worker, ...) arrive with their code.

FLUTTER ?= flutter
DART ?= dart
TILT ?= tilt
NPM ?= npm
UV ?= uv

APP_DIR := frontend
WIDGETBOOK_DIR := frontend/widgetbook
AUTH_DIR := auth
BACKEND_DIR := backend

# Where `make app` runs: chrome (default), macos (needs Xcode) or web-server (no browser).
DEVICE ?= chrome
# On the web the app always uses port 8080: sign-in only trusts the origins it knows.
WEB_PORT := $(if $(filter macos,$(DEVICE)),,--web-port=8080)

# Run files (gitignored): pid files, so `make stop...` can stop what make started,
# and Tilt's empty kubeconfig.
RUN_DIR := $(CURDIR)/.tilt
APP_PID := $(RUN_DIR)/app.pid
WIDGETBOOK_PID := $(RUN_DIR)/widgetbook.pid
AUTH_PID := $(RUN_DIR)/auth.pid
API_PID := $(RUN_DIR)/api.pid
TILT_PID := $(RUN_DIR)/tilt.pid

# Tilt never sends usage data from this project.
export TILT_DISABLE_ANALYTICS := true

# OSMS never uses Kubernetes: Tilt gets an empty kubeconfig, so it can't see (or
# reach) any cluster in ~/.kube/config. The Tiltfile refuses to load if it can.
TILT_KUBECONFIG := $(RUN_DIR)/kubeconfig
TILT_RUN := KUBECONFIG="$(TILT_KUBECONFIG)" $(TILT)

# True while a Tilt session answers on its API (http://localhost:10350).
tilt_up = command -v $(TILT) >/dev/null && $(TILT_RUN) get session >/dev/null 2>&1

# $(call stop_pid,label,pid file,command): SIGINT (like Ctrl+C) to a process make
# started, only while that pid still belongs to the expected command.
stop_pid = pid=$$(cat "$(2)" 2>/dev/null); \
  if [ -n "$$pid" ] && ps -p "$$pid" -o command= 2>/dev/null | grep -q "$(3)"; then \
    kill -INT "$$pid" && echo "$(1): stopped"; \
  else echo "$(1): not running"; fi; rm -f "$(2)"

# $(call show_pid,label,pid file,command)
show_pid = pid=$$(cat "$(2)" 2>/dev/null); \
  if [ -n "$$pid" ] && ps -p "$$pid" -o command= 2>/dev/null | grep -q "$(3)"; then \
    echo "$(1): running (pid $$pid)"; \
  else echo "$(1): not running"; fi

# $(call tilt_disable,label,resources): stop resources inside the running Tilt session.
# Turn them back on from the Tilt UI, or with `tilt enable <resources>`.
tilt_disable = if $(tilt_up); then \
    $(TILT_RUN) disable $(2) >/dev/null && echo "$(1) (in Tilt): stopped"; \
  else echo "$(1) (in Tilt): Tilt isn't running"; fi

.DEFAULT_GOAL := help
.PHONY: help tools env setup app widgetbook auth api up ci stop-app stop-widgetbook stop-auth \
  stop-api stop down status widgetbook-gen widgetbook-build build-macos test-macos check \
  check-flutter check-backend check-auth clean _run-dir _need-tilt

help: ## List the commands
	@awk 'BEGIN {FS = ":.*## "} \
	  /^##@ / {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} \
	  /^[a-zA-Z0-9_-]+:.*## / {printf "  %-17s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Set up

tools: ## Check that Flutter, Node, uv, Tilt and (for DEVICE=macos) Xcode are installed
	@command -v $(FLUTTER) >/dev/null && echo "ok      flutter" || echo "missing flutter: brew install --cask flutter"
	@command -v node >/dev/null && echo "ok      node" || echo "missing node (24 or newer): brew install node"
	@command -v $(UV) >/dev/null && echo "ok      uv" || echo "missing uv: brew install uv"
	@command -v $(TILT) >/dev/null && echo "ok      tilt" || echo "missing tilt: brew install tilt"
	@xcodebuild -version >/dev/null 2>&1 && echo "ok      Xcode" || echo "missing Xcode: only for DEVICE=macos, from the App Store"

env: ## Create .env from .env.example with a fresh sign-in secret (never overwrites a value)
	@if [ -f .env ]; then echo ".env: exists, values kept"; else cp .env.example .env && echo ".env: created"; fi
	@if grep -q '^BETTER_AUTH_SECRET=$$' .env; then \
	  secret=$$(openssl rand -hex 32) && sed -i.bak "s/^BETTER_AUTH_SECRET=$$/BETTER_AUTH_SECRET=$$secret/" .env && \
	  rm -f .env.bak && echo ".env: set BETTER_AUTH_SECRET to a new random value (it stays in .env)"; fi
	@if grep -q '^OSMS_DEV_SIGN_IN=$$' .env; then sed -i.bak 's/^OSMS_DEV_SIGN_IN=$$/OSMS_DEV_SIGN_IN=1/' .env && \
	  rm -f .env.bak && echo ".env: development sign-in links on (local only)"; fi

setup: env ## Create .env if needed, fetch every package, generate Widgetbook's navigation
	cd $(APP_DIR) && $(FLUTTER) pub get
	cd $(WIDGETBOOK_DIR) && $(FLUTTER) pub get && $(DART) run build_runner build
	cd $(AUTH_DIR) && $(NPM) ci
	cd $(BACKEND_DIR) && $(UV) sync

##@ Run one thing on its own

app: _run-dir ## Run the app (DEVICE=chrome, macos or web-server); stop with q or make stop-app
	cd $(APP_DIR) && $(FLUTTER) run -d $(DEVICE) $(WEB_PORT) --pid-file="$(APP_PID)"

widgetbook: _run-dir widgetbook-gen ## Run Widgetbook in Chrome; stop with q or make stop-widgetbook
	cd $(WIDGETBOOK_DIR) && $(FLUTTER) run -d chrome --pid-file="$(WIDGETBOOK_PID)"

auth: _run-dir ## Run sign-in (Better Auth) on http://localhost:3000; stop with Ctrl+C or make stop-auth
	@cd $(AUTH_DIR) && sh -c 'echo $$$$ > "$(AUTH_PID)"; exec $(NPM) start'

api: _run-dir ## Run the API on http://localhost:8000, reloading on save; stop with Ctrl+C or make stop-api
	@cd $(BACKEND_DIR) && sh -c 'echo $$$$ > "$(API_PID)"; \
	  exec $(UV) run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000'

##@ Run everything at once (Tilt)

up: _need-tilt ## Run everything with Tilt (UI at http://localhost:10350); stop with make stop
	@sh -c 'echo $$$$ > "$(TILT_PID)"; exec env KUBECONFIG="$(TILT_KUBECONFIG)" $(TILT) up'

ci: _need-tilt ## Start everything with Tilt, wait until it is all healthy, then exit
	$(TILT_RUN) ci --timeout 15m

##@ Stop and status

stop-app: ## Stop the app (web or macOS), whether it runs on its own or in Tilt
	@$(call stop_pid,app (on its own),$(APP_PID),flutter)
	@$(call tilt_disable,app,app app-reload app-macos app-macos-reload)

stop-widgetbook: ## Stop Widgetbook, whether it runs on its own or in Tilt
	@$(call stop_pid,widgetbook (on its own),$(WIDGETBOOK_PID),flutter)
	@$(call tilt_disable,widgetbook,widgetbook widgetbook-reload widgetbook-gen)

stop-auth: ## Stop sign-in, whether it runs on its own or in Tilt
	@$(call stop_pid,auth (on its own),$(AUTH_PID),npm)
	@$(call tilt_disable,auth,auth)

stop-api: ## Stop the API, whether it runs on its own or in Tilt
	@$(call stop_pid,api (on its own),$(API_PID),uvicorn)
	@$(call tilt_disable,api,api)

stop: ## Stop everything at once: the app, Widgetbook, sign-in, the API and the whole Tilt session
	@$(call stop_pid,app (on its own),$(APP_PID),flutter)
	@$(call stop_pid,widgetbook (on its own),$(WIDGETBOOK_PID),flutter)
	@$(call stop_pid,auth (on its own),$(AUTH_PID),npm)
	@$(call stop_pid,api (on its own),$(API_PID),uvicorn)
	@$(call stop_pid,Tilt and everything in it,$(TILT_PID),tilt)
	@rm -f "$(RUN_DIR)"/tilt-*.pid
	@if command -v $(TILT) >/dev/null; then mkdir -p "$(RUN_DIR)" && : > "$(TILT_KUBECONFIG)" && \
	  $(TILT_RUN) down >/dev/null 2>&1 || true; fi

down: stop

status: ## Show what is running
	@$(call show_pid,app (on its own),$(APP_PID),flutter)
	@$(call show_pid,widgetbook (on its own),$(WIDGETBOOK_PID),flutter)
	@$(call show_pid,auth (on its own),$(AUTH_PID),npm)
	@$(call show_pid,api (on its own),$(API_PID),uvicorn)
	@if $(tilt_up); then \
	  echo "Tilt: running at http://localhost:10350"; \
	  $(TILT_RUN) get uiresources -o \
	    custom-columns='SERVICE:.metadata.name,STATE:.status.runtimeStatus,ENABLED:.status.disableStatus.state' \
	    | grep -v '(Tiltfile)' | sed 's/^/  /'; \
	else echo "Tilt: not running"; fi

##@ Widgetbook and checks

widgetbook-gen: ## Regenerate Widgetbook's navigation after adding or renaming use cases
	cd $(WIDGETBOOK_DIR) && $(DART) run build_runner build

widgetbook-build: widgetbook-gen ## Build Widgetbook as a static site in frontend/widgetbook/build/web
	cd $(WIDGETBOOK_DIR) && $(FLUTTER) build web --release --no-web-resources-cdn

build-macos: ## Build the macOS app (needs Xcode): frontend/build/macos/Build/Products/Release/OSMS.app
	cd $(APP_DIR) && $(FLUTTER) build macos --release

# How test-macos reads the sign-in log: Tilt's by default.
AUTH_LOG ?= env KUBECONFIG=$(TILT_KUBECONFIG) $(TILT) logs auth

test-macos: ## With `make up` running: the real macOS app against sign-in and the API (opens a window)
	@cookie=$$(AUTH_LOG="$(AUTH_LOG)" sh $(AUTH_DIR)/scripts/dev-session.sh macos-test@users.example) && \
	  cd $(APP_DIR) && $(FLUTTER) test integration_test -d macos --dart-define=OSMS_TEST_SESSION_COOKIE="$$cookie"

check: check-flutter check-backend check-auth ## Analyze and test everything

check-flutter: ## Analyze and test the app and Widgetbook (Tilt's "flutter-checks" button)
	cd $(APP_DIR) && $(FLUTTER) analyze && $(FLUTTER) test
	cd $(WIDGETBOOK_DIR) && $(FLUTTER) analyze && $(FLUTTER) test

check-backend: ## Lint and test the API (Tilt's "backend-checks" button)
	cd $(BACKEND_DIR) && $(UV) run ruff check . && $(UV) run pytest -q

check-auth: ## Type-check and test the sign-in service (Tilt's "auth-checks" button)
	cd $(AUTH_DIR) && $(NPM) run typecheck && $(NPM) test

clean: stop ## Stop everything, then remove Flutter build output and run files
	cd $(APP_DIR) && $(FLUTTER) clean
	cd $(WIDGETBOOK_DIR) && $(FLUTTER) clean
	rm -rf "$(RUN_DIR)"

_run-dir:
	@mkdir -p "$(RUN_DIR)"

_need-tilt: _run-dir
	@command -v $(TILT) >/dev/null || { echo "Tilt isn't installed. Install it with: brew install tilt"; exit 1; }
	@: > "$(TILT_KUBECONFIG)"
