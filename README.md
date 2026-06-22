# rTruth

Local telemetry stack for the testharness/rhobot work. Data flows:

```
devices --MQTT--> Mosquitto --> Telegraf --> InfluxDB v2 --> Grafana
```

## Prerequisites

- Docker Desktop (or Docker Engine + Compose v2)

## Quick start

```bash
cp .env.example .env
docker compose up -d
```

That's it — no networks to create, no manual setup. InfluxDB v2 self-provisions
on first boot (org, bucket, and an admin token) from the env vars in
`docker-compose.yml`; the shared dev token lives in `.env`.

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
| InfluxDB  | `http://localhost:8087`        | v2 web UI + API — login `admin` / `admin12345` |
| Telegraf  | (no exposed port)              | MQTT → InfluxDB bridge                   |

All host ports are overridable in `.env` (`GRAFANA_PORT`, `INFLUX_PORT`,
`MQTT_PORT`) — change any that clash with another project, then
`docker compose up -d`.

> **Use `127.0.0.1`, not `localhost`, if a page won't load.** Ports are
> published on `127.0.0.1` only. Docker Desktop on Windows resets connections
> over IPv6 loopback (`::1`), which is what the browser tries first for
> `localhost` — so `http://localhost:3003` can fail with
> `ERR_CONNECTION_RESET`. `http://127.0.0.1:3003` always works.

> **InfluxDB v2 has a browser UI** at `http://localhost:8087` (login
> `admin` / `admin12345`) where you can explore buckets and run Flux. Check it's
> alive with `http://localhost:8087/health` (returns `{"status":"pass"}`), view
> data in **Grafana**, or query it from the CLI (the container's `influx` CLI is
> pre-authenticated with the admin token):
> ```bash
> docker compose exec influxdb influx query --org rhobot \
>   'from(bucket:"raw_bucket") |> range(start:-10m) |> limit(n:10)'
> ```
>
> Host port **8087** (not v2's usual 8086) avoids clashing with other InfluxDB
> instances on this machine — including the rhobot stack's own Influx.

## Data flow details

- **Telegraf** subscribes to `rhobot/testcase/+/+/+/+`, parses JSON payloads,
  and writes them to the InfluxDB database **`raw_bucket`** as the
  `raw_measurement` table. Tag/field mapping lives in
  `configs/telegraf/telegraf.conf`.
- **Grafana** is pre-provisioned with an InfluxDB (Flux) datasource and loads
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

- **Auth is on** (InfluxDB v2's default). The stack is still zero-config: v2
  self-provisions on first boot, and `INFLUX_TOKEN` in `.env` is the shared
  admin token Telegraf and Grafana use automatically — no per-user credentials.
  *(This is a temporary downgrade from InfluxDB v3 so Nathan's existing v2/Flux
  connector works unchanged; we'll move back to v3 later.)*
- **`.env` is gitignored.** Never commit real secrets — update `.env.example`
  instead when adding new variables.
- To wipe all data and start clean: `docker compose down -v && docker compose up -d`.
