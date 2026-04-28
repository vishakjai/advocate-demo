---
name: grafana-local-dev-dx
description: Local Grafana iteration workflow for DX dashboards in dashboards/dx/ — the ones backed by ClickHouse. Use when the user wants to work on, edit, create, or iterate on any Grafana dashboard in the DX folder (e.g. "I want to work on the CI Health Incidents dashboard", "improve the failure analysis dashboard", "add a panel to the DX dashboard", "create a new DX dashboard"). Starts a local Grafana Docker instance with the ClickHouse plugin, compiles Jsonnet to JSON, uploads the dashboard, and iterates via agent-driven API calls (no UI editing). Covers ClickHouse datasource registration, multi-select variable gotchas, and the full edit→compile→upload→validate loop. For dashboards outside dx/ (Prometheus/Mimir-based), this skill does not apply — extend or create a separate skill for those.
compatibility: Requires a working docker CLI (colima, Rancher Desktop, or equivalent). Also requires jq, jsonnet (via asdf .tool-versions in repo root), and the dashboards/ scripts (generate-dashboard.sh, grafana-tools.lib.sh).
---

# Grafana Local Dev — DX Dashboards (ClickHouse)

Agent-driven workflow for iterating on `dashboards/dx/` Grafana dashboards. These dashboards use ClickHouse as their datasource (uid `P3AA52CBE89C5194B`, defined in `dashboards/dx/common/config.libsonnet`).

The agent makes all changes via the Grafana HTTP API. You describe what you want; the agent updates the dashboard and you refresh the browser.

> **Scope**: This skill covers DX dashboards only. Other dashboards in this repo (e.g. `dashboards/ci/`, `dashboards/general/`) use Prometheus/Mimir and require different datasource setup — this skill does not apply to them.

## Prerequisites

- Docker CLI functional (colima, Rancher Desktop, or equivalent — `docker info` should succeed)
- `jb install` run from the repo root (installs jsonnet vendor deps)
- Working directory: repo root (`gitlab-com/runbooks`)
- `.env` file in repo root with ClickHouse credentials (see Phase 1, Step 2)

---

## Phase 0: Select and deploy a dashboard

At the start of a session, identify which dashboard to work on:

1. If the user names a dashboard that exists in `dashboards/dx/`, use it directly.
2. If the user names something that doesn't match an existing file (e.g. "master-broken dashboard"), check for partial matches by running `ls dashboards/dx/*.dashboard.jsonnet`, then ask: **"No exact match found. Do you want to work on one of these existing dashboards, or create a new one?"** — list the candidates and include "Create a new dashboard" as an option.
3. If the user hasn't mentioned a dashboard at all, ask: **"Which dashboard do you want to work on?"** and list available options plus "Create a new dashboard".

Once a dashboard is selected or the user confirms they want a new one:

- **Existing dashboard**: compile and upload it (Phases 2), tell the user the URL (`http://localhost:3000/d/<uid>`), then ask "What would you like to change?"
- **New dashboard**: follow the "Creating a new dashboard" section below, then enter the iteration loop

Do not wait for the user to ask you to deploy — always compile and upload as part of selecting a dashboard.

---

## Phase 1: One-time setup — Start local Grafana

Ensure your container runtime is running and `docker info` succeeds. Then start Grafana:

`dx/` dashboards use ClickHouse — start Grafana with the plugin pre-installed:

```bash
docker run -d \
  --name grafana-local-dev \
  -p 3000:3000 \
  -e GF_AUTH_ANONYMOUS_ENABLED=true \
  -e GF_AUTH_ANONYMOUS_ORG_ROLE=Admin \
  -e GF_AUTH_DISABLE_LOGIN_FORM=true \
  -e GF_INSTALL_PLUGINS=grafana-clickhouse-datasource \
  grafana/grafana:latest
```

Wait ~20s for the plugin to install, then verify:

```bash
curl -s http://localhost:3000/api/health | jq .version
```

Open `http://localhost:3000` in your browser.

To stop and remove the container when done:

```bash
docker rm -f grafana-local-dev
```

**Note:** No API token needed — anonymous admin access is enabled. All API calls use `http://localhost:3000` with no `Authorization` header.

### Step 2: Register the ClickHouse datasource

The `dx/` dashboards expect datasource uid `P3AA52CBE89C5194B` (defined in `dashboards/dx/common/config.libsonnet`).

Credentials are read from the repo's `.env` file (not committed — add to `.gitignore` if needed) or environment variables:

```
CLICKHOUSE_URL=<host>
CLICKHOUSE_USERNAME=<user>
CLICKHOUSE_PASSWORD=<password>
CLICKHOUSE_DATABASE=<database>
```

Load and register:

```bash
# Load credentials from .env
export $(grep -v '^#' .env | xargs)

curl -s -X POST http://localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"ClickHouse\",
    \"type\": \"grafana-clickhouse-datasource\",
    \"uid\": \"P3AA52CBE89C5194B\",
    \"access\": \"proxy\",
    \"jsonData\": {
      \"server\": \"${CLICKHOUSE_URL}\",
      \"port\": 8443,
      \"username\": \"${CLICKHOUSE_USERNAME}\",
      \"secure\": true,
      \"tlsSkipVerify\": false,
      \"protocol\": \"http\"
    },
    \"secureJsonData\": {
      \"password\": \"${CLICKHOUSE_PASSWORD}\"
    }
  }" | jq '{id, message}'
```

Verify connection:

```bash
curl -s -X POST http://localhost:3000/api/datasources/uid/P3AA52CBE89C5194B/health | jq '{status, message}'
# Expected: {"status": "OK", "message": "Data source is working"}
```

**Important notes:**

- ClickHouse Cloud only speaks HTTPS — use `"protocol": "http"` with port `8443`. Native protocol (port 9440) will fail with `[handshake] unexpected packet`.
- If the datasource already exists and you need to update credentials, use `PUT /api/datasources/uid/P3AA52CBE89C5194B` instead of `POST /api/datasources`.
- Never print or log the password — always source from `.env` or env vars.

---

## Phase 2: Load an existing dashboard

### Step 1: Compile Jsonnet to JSON

```bash
cd dashboards
./generate-dashboard.sh <folder>/<name>.dashboard.jsonnet
# Example: ./generate-dashboard.sh dx/failure-analysis.dashboard.jsonnet
```

Output goes to `dashboards/generated/<folder>/<uid>.json`.

**Note:** The `augment_dashboard` function in `grafana-tools.lib.sh` prefixes the UID and title with the folder name (e.g. `dashboards/dx/failure-analysis.dashboard.jsonnet` → uid `dashboards/dx-failure-analysis`, title `dashboards/dx: Failure Analysis Dashboard`). For local dev, strip these prefixes to keep the UID clean and the title readable — or just use the generated JSON as-is and note the actual UID from the output.

To get the UID from the generated file:

```bash
jq -r '.uid' dashboards/generated/<folder>/<uid>.json
```

### Step 2: Upload to local Grafana

```bash
DASHBOARD_JSON=$(cat dashboards/generated/<folder>/<uid>.json)
curl -s -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": $DASHBOARD_JSON, \"overwrite\": true, \"folderUid\": \"\"}" \
  | jq '{url: .url, uid: .uid, status: .status}'
```

Open the dashboard at `http://localhost:3000/d/<uid>`.

---

## Phase 3: Iteration loop

The agent holds the current dashboard JSON in context. For each change:

1. **User describes the change** (e.g. "make the overview stats span full width", "remove the big text panel", "add a third stat showing total failed jobs")
2. **Agent modifies the Jsonnet source** and compiles it
3. **Agent re-uploads** via the API:

```bash
curl -s -X POST http://localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d "{\"dashboard\": <updated-json>, \"overwrite\": true, \"folderUid\": \"\"}" \
  | jq '{status: .status, url: .url}'
```

4. **Agent validates** — after every upload, check that all panels are error-free by fetching the dashboard from the API and verifying the queries return data (not errors):

```bash
# Check panel queries by inspecting live Grafana state
curl -s http://localhost:3000/api/dashboards/uid/<uid> | jq '.dashboard.panels[] | {id, title, targets: [.targets[]?.rawSql]}'
```

Use ClickHouse MCP (`run_select_query`) to test the actual SQL with realistic variable values before uploading. This catches syntax errors and logic bugs before the user sees them.

5. **User refreshes** `http://localhost:3000/d/<uid>` to see the result
6. Repeat until satisfied

### Validation checklist after each upload

- [ ] Compile succeeded (no Jsonnet errors)
- [ ] Upload returned `"status": "success"`
- [ ] Test key SQL queries directly via ClickHouse MCP with realistic variable substitutions
- [ ] No HTTP 400/syntax errors in the expected query paths

**Do not wait for the user to report errors** — catch them proactively with the ClickHouse MCP before asking the user to refresh.

### Fetching current state from Grafana

If the agent's in-context JSON drifts from what's in Grafana, re-fetch the source of truth:

```bash
curl -s http://localhost:3000/api/dashboards/uid/<uid> | jq '.dashboard'
```

### Validating a query via Grafana datasource proxy API

Use this to execute a SQL query through Grafana's datasource proxy (same path as the browser) without going via ClickHouse MCP directly. Useful when you want to test with Grafana's own variable substitution or confirm a panel query works end-to-end:

```bash
curl -s -X POST "http://localhost:3000/api/ds/query" \
  -H "Content-Type: application/json" \
  -d '{
    "queries": [
      {
        "datasource": {"type": "grafana-clickhouse-datasource", "uid": "P3AA52CBE89C5194B"},
        "editorType": "sql",
        "format": 1,
        "queryType": "table",
        "rawSql": "<your SQL here>",
        "refId": "A"
      }
    ],
    "from": "now-30d",
    "to": "now"
  }' | jq '.results.A.frames[0].data.values'
```

Note: variable interpolation (e.g. `${failure_category_var:pipe}`) does **not** happen here — substitute real values manually when testing. Use ClickHouse MCP (`run_select_query`) for testing with substituted values; use the proxy API to verify the Grafana JSON wire format is correct.

### Checking for HTTP 400 errors in the browser

If the user reports a 400 error on a specific panel, identify which panel is failing by fetching all panel queries and testing each SQL manually with the ClickHouse MCP. Grafana's browser error messages include a snippet of the failing SQL — use that to narrow down the panel. The most common cause with multi-select variables is an incorrect All-guard pattern (see below).

---

## Phase 4: Export + rewrite as Jsonnet

### Step 1: Export the final dashboard JSON

```bash
curl -s http://localhost:3000/api/dashboards/uid/<uid> | jq '.dashboard' > /tmp/final-dashboard.json
```

### Step 2: Agent rewrites as clean Jsonnet

The agent converts the exported JSON back to idiomatic Jsonnet following the project's conventions:

- Use helpers from `dashboards/dx/common/panels.libsonnet` where applicable (`panels.statPanel()`, `panels.tablePanel()`, `panels.timeSeriesPanel()`, `panels.piePanel()`)
- Use `panels.clickHouseDatasource` for the datasource field
- Structure with `.addTemplate()`, `.addPanel()`, and `row.new().addPanels()` for collapsed rows
- Keep SQL queries in `|||` heredoc strings
- Each panel gets a `gridPos={ x:, y:, w:, h: }` argument
- Match the style of the existing file being edited

The agent writes the result directly to the source file:

```
dashboards/<folder>/<name>.dashboard.jsonnet
```

### Step 3: Verify it compiles

```bash
cd dashboards && ./generate-dashboard.sh <folder>/<name>.dashboard.jsonnet
```

If it compiles cleanly, the updated Jsonnet is ready. The user can commit and open an MR.

---

## Creating a new dashboard (vs editing existing)

If the target dashboard does not yet exist in production Grafana:

1. Determine the right **folder**: existing dashboards live in `dashboards/dx/`, `dashboards/ci/`, etc. Match the domain.
2. Check if the **Grafana folder** exists:

   ```bash
   ls dashboards/ | grep <folder-name>
   ```

   If it doesn't exist, create it:

   ```bash
   cd dashboards && ./create-grafana-folder.sh <folder_uid> '<Folder Title>'
   ```

   This requires `GRAFANA_API_TOKEN` (production Grafana token) — skip for local dev.
3. Create the new `.dashboard.jsonnet` file following the structure of an existing one in the same folder.
4. Follow Phases 1–4 above.

---

## ClickHouse variable interpolation gotchas

### Multi-select `allValue` + `:pipe` — correct All-guard pattern

When a template variable has `includeAll: true` and `allValue: ''`, you need a safe way to detect "All selected" in SQL. Two common approaches **fail**:

- `IN (${var:singlequote})` — when All is selected and `allValue: ''`, ClickHouse receives `IN ('')` which silently returns zero rows (no syntax error, but wrong result). If `allValue` is left as the Grafana default `__all__`, it receives `IN (__all__)` (unquoted identifier) → syntax error (HTTP 400).
- `'${var}' = ''` — when multiple specific values are selected, `'${var}'` (no format) expands to `'val1','val2','val3'` → breaks SQL string context → syntax error (HTTP 400)

**Correct pattern — use `length('${var:pipe}') = 0`:**

```sql
AND (length('${failure_category_var:pipe}') = 0 OR match(f.failure_category, '^(${failure_category_var:pipe})$'))
AND (length('${failure_signature_var:pipe}') = 0 OR match(f.failure_signature, '^(${failure_signature_var:pipe})$'))
```

- `allValue: ''` (empty string) — when All selected, `:pipe` sends `''` → `length('') = 0` is TRUE → short-circuits
- When specific values selected, `:pipe` sends `val1|val2` → `length('val1|val2') = 0` is FALSE → evaluates `match()`
- `:pipe` always produces a single quoted string — **never breaks SQL context regardless of values selected**
- Use `match()` with `^(...)$` anchors to avoid partial matches

Apply this pattern to **every** filter variable in every panel query. Test all four combinations: All+All, specific+All, All+specific, specific+specific.

**Do not use** `IN (${var:singlequote})` or `'${var}' = ''` for multi-select variables.

---

## Key API reference

All calls target `http://localhost:3000` with no auth header (anonymous admin mode).

| Operation | Method | Path |
| --- | --- | --- |
| Health check | GET | `/api/health` |
| Upload/update dashboard | POST | `/api/dashboards/db` |
| Fetch dashboard by UID | GET | `/api/dashboards/uid/<uid>` |
| List all dashboards | GET | `/api/search?type=dash-db` |
| Delete dashboard | DELETE | `/api/dashboards/uid/<uid>` |

Upload body format:

```json
{
  "dashboard": { ...dashboard JSON... },
  "overwrite": true,
  "folderUid": ""
}
```
