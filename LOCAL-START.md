# Run the local FPL agent

From PowerShell in this directory, run `./start.ps1`. Docker Desktop must be running.
This starts PostgreSQL, n8n, Ollama, and SearXNG, downloads the reasoning model,
and imports the database credential and repaired workflow. Re-running the script
reimports the supplied workflow; export any UI edits you want to preserve first.

Open http://localhost:5678 and create your n8n owner account if prompted.
If the initial import needs an owner account, finish that setup and rerun the script.
There is no separate picker frontend in the supplied project.

Set `FPL_TEAM_ID` in `.env` to the number from your FPL entry URL. Apply changes with
`docker compose up -d n8n`. Open **FPL Team Sync & Analysis**, run it manually,
then publish/activate it to enable the six-hour schedule and webhooks:

- http://localhost:5678/webhook/fpl/team?teamId=YOUR_ID
- http://localhost:5678/webhook/fpl/suggestions?teamId=YOUR_ID

The workflow uses current FPL squad, player and fixture data plus recent web-search
snippets from SearXNG. Search evidence and retrieval times are stored with the
recommendations. Empty web results stop analysis rather than invent current news.
Search snippets are evidence, not full-page verification; check linked sources for
injury and lineup decisions. Search engines can rate-limit requests.

Qwen3 8B uses Ollama's `think: true` control and JSON output. Model quality is bounded
by the model and hardware; CPU inference can take several minutes. Docker currently
has approximately 8 GB RAM, so increase its allocation if model loading runs out of
memory, or set `OLLAMA_MODEL=qwen3:4b` in `.env` and rerun startup for a smaller model.
The default does not enable GPU access. This machine has Intel Iris Xe graphics;
the initial 8B CPU check generated approximately one token per second while the
stack was initializing, so full analysis may be slow. Models and application data
persist in named volumes. PostgreSQL 17 uses its own `postgres17_data` volume;
the initial PostgreSQL 15 volume is preserved separately.

Check status with `docker compose ps -a`, model download with
`docker compose logs --tail 10 ollama-init`, and errors with
`docker compose logs --tail 50 n8n ollama search`.
Use `docker compose stop` to stop services while retaining data.

For a detached manual analysis, run
`docker compose --profile manual up -d analysis` and follow
`docker compose logs -f analysis`. This job has no HTTP health check, runs once,
and exits when finished. An exit code of 0 indicates success. To run it again,
use `docker compose --profile manual up -d --force-recreate analysis`.
The default startup does not launch this optional job.

Ollama is available at http://localhost:11434 (model list: `/api/tags`).
Use `http://ollama:11434` from n8n containers and `http://localhost:11434` from Windows.
n8n, Ollama, and PostgreSQL publish ports, bound to localhost. The provided database
credential is for this local development stack. Search uses the internal
Docker network. No paid API key is required.

Canonical files are `docker-compose.yml`, `fpl-n8n-workflow.json`, and
`fpl-db-setup.sql`. The numbered duplicates are the original supplied backups.
`repair_workflow.py` regenerates the repaired workflow; it is unnecessary for normal startup.

References: [Ollama thinking](https://docs.ollama.com/capabilities/thinking),
[SearXNG JSON search](https://docs.searxng.org/admin/settings/settings_search.html).
