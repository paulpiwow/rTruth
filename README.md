# rTruth

Local telemetry stack for the testharness/rhobot work. Data flows:

```
devices --MQTT--> Mosquitto --> Telegraf --> InfluxDB 3 --> Grafana
```

## Prerequisites

- Docker Desktop (or Docker Engine + Compose v2)

## Quick start

```bash
cp .env.example .env
docker compose up -d
```

That's it — no tokens to generate, no networks to create. InfluxDB runs with
`--without-auth` for local dev and auto-creates its database on the first write.

Check everything is running:

```bash
docker compose ps
docker compose logs -f telegraf
```

## Services & ports

| Service   | URL / endpoint                 | Notes                                   |
|-----------|--------------------------------|-----------------------------------------|
| Grafana   | `http://localhost:3003`        | the UI — login `admin` / `admin`        |
| Mosquitto | `localhost:1883`               | MQTT broker, anonymous access           |
| InfluxDB  | `http://localhost:8087/health` | API only — **no web UI** (see below)    |
| Telegraf  | (no exposed port)              | MQTT → InfluxDB bridge                   |

All host ports are overridable in `.env` (`GRAFANA_PORT`, `INFLUX_PORT`,
`MQTT_PORT`) — change any that clash with another project, then
`docker compose up -d`.

> **Use `127.0.0.1`, not `localhost`, if a page won't load.** Ports are
> published on `127.0.0.1` only. Docker Desktop on Windows resets connections
> over IPv6 loopback (`::1`), which is what the browser tries first for
> `localhost` — so `http://localhost:3003` can fail with
> `ERR_CONNECTION_RESET`. `http://127.0.0.1:3003` always works.

> **InfluxDB 3 Core has no browser UI.** Opening `http://localhost:8087` in a
> browser gives "connection reset" / 404 — that's expected; it's a headless
> database. Check it's alive with `http://localhost:8087/health` (returns `OK`),
> view data in **Grafana**, or query it with the `influxdb3` CLI:
> ```bash
> docker compose exec influxdb influxdb3 query --database raw_bucket \
>   'SELECT * FROM raw_measurement ORDER BY time DESC LIMIT 10'
> ```
>
> Host port **8087** (not the usual 8086) avoids clashing with other InfluxDB
> instances on this machine, and is exposed on all interfaces so the rPipes
> connector (a separate docker stack) can reach it via `host.docker.internal`.

## Data flow details

- **Telegraf** subscribes to `rhobot/testcase/+/+/+/+`, parses JSON payloads,
  and writes them to the InfluxDB database **`raw_bucket`** as the
  `raw_measurement` table. Tag/field mapping lives in
  `configs/telegraf/telegraf.conf`.
- **Grafana** is pre-provisioned with an InfluxDB (SQL) datasource and loads
  dashboards from `configs/grafana/dashboards/`.

## Producing data (the testharness)

Target flow:

```
your app  ->  JSON  ->  testharness app  ->  MQTT  ->  (this stack)
```

The testharness publishes JSON to MQTT following the
**[MQTT contract](docs/mqtt-contract.md)** — a fixed topic pattern and JSON
shape. As long as messages match that contract, they are ingested with no
changes to this stack.

To exercise the pipeline before the app side exists:

```bash
# zero-dependency: fire a few rounds through the running broker
./scripts/send-test-messages.sh 10

# realistic reference publisher (model for the testharness integration)
pip install paho-mqtt
python scripts/sample_publisher.py --count 0   # 0 = run continuously
```

Then open Grafana (`localhost:3003`) → dashboard **rTruth — Live Site View**.

## Layout

```
docker-compose.yml          # the stack
.env.example                # copy to .env
configs/
  mosquitto/mosquitto.conf  # broker config
  telegraf/telegraf.conf    # MQTT -> InfluxDB ingestion
  grafana/provisioning/     # datasource + dashboard providers
  grafana/dashboards/       # dashboard JSON
```

## Notes for the team

- **Auth is off** (`--without-auth`) so the stack is zero-config for everyone.
  `INFLUX_TOKEN` in `.env` is passed to Telegraf/Grafana but not enforced.
- **InfluxDB's port is exposed** (host `8087`, all interfaces) so the rPipes
  connector — which runs as a separate docker stack — can reach it at
  `host.docker.internal:8087`. Local-dev only; lock it down before it leaves a
  laptop.
- **`.env` is gitignored.** Never commit real secrets — update `.env.example`
  instead when adding new variables.
- To wipe all data and start clean: `docker compose down -v && docker compose up -d`.
