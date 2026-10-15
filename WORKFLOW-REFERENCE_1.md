# FPL n8n Workflow - Technical Reference

## Quick Reference

### Commands

**Start everything:**
```bash
bash quickstart.sh <YOUR_FPL_TEAM_ID>
```

**Manual start:**
```bash
docker-compose up -d
export FPL_TEAM_ID=1234567  # Your team ID
```

**View logs:**
```bash
docker-compose logs -f n8n
docker-compose logs -f postgres
```

**Stop:**
```bash
docker-compose down
```

**Reset everything (fresh start):**
```bash
docker-compose down -v  # -v removes volumes
docker-compose up -d
```

---

## Workflow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FPL n8n Workflow                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Schedule: Every 6h]                                           │
│         │                                                       │
│    ┌────┴──────────────────────────────────────────────────┐   │
│    │                                                        │   │
│    ▼                    ▼                     ▼             │   │
│  [Bootstrap]      [Team Entry]          [Team Picks]        │   │
│  (Get all         (Get rank,            (Get squad)         │   │
│   players)        name, budget)                             │   │
│    │                   │                     │              │   │
│    ▼                   ▼                     ▼              │   │
│  [Store]           [Store]                [Store]           │   │
│  PostgreSQL        PostgreSQL             PostgreSQL        │   │
│    │                   │                     │              │   │
│    └───────────────────┼─────────────────────┘              │   │
│                        │                                     │   │
│                        ▼                                     │   │
│                  [Ollama Analysis]                           │   │
│                  (llama2 form review)                        │   │
│                        │                                     │   │
│                        ▼                                     │   │
│                   [Store Suggestions]                        │   │
│                      PostgreSQL                              │   │
│                                                              │   │
├─────────────────────────────────────────────────────────────────┤
│                         Webhooks                              │   │
│                      (Always Active)                          │   │
│                                                              │   │
│  GET /fpl/team?teamId=<ID>    → {team, picks, bootstrap}    │   │
│  GET /fpl/suggestions?teamId=<ID> → {suggestions}           │   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Database Schema

### fpl_bootstrap
Stores all FPL static data (players, teams, fixtures, gameweeks)
```sql
SELECT gw, data->>'meta' as metadata 
FROM fpl_bootstrap 
ORDER BY updated_at DESC 
LIMIT 1;
```

### fpl_teams
Your team info (name, manager, rank, budget)
```sql
SELECT data->>'name' as team_name,
       data->>'player_first_name' || ' ' || data->>'player_last_name' as manager,
       data->>'summary_overall_points' as total_points,
       data->>'summary_overall_rank' as rank
FROM fpl_teams 
WHERE team_id = YOUR_TEAM_ID;
```

### fpl_picks
Your squad for each gameweek
```sql
SELECT gw, data->>'entry_history'->>'event_transfers' as transfers,
       data->>'picks' as squad
FROM fpl_picks 
WHERE team_id = YOUR_TEAM_ID
ORDER BY gw DESC 
LIMIT 5;
```

### fpl_suggestions
AI-generated transfer suggestions
```sql
SELECT gw, suggestions 
FROM fpl_suggestions 
WHERE team_id = YOUR_TEAM_ID
ORDER BY created_at DESC 
LIMIT 10;
```

---

## Ollama Model Options

Default: `llama2` (7B params, good balance)

### Replace with:

**Faster (3-4B):**
```json
"model": "neural-chat"     // Good for quick analysis
"model": "orca-mini"       // Fast, accurate
"model": "phi"             // Lightweight, fast
```

**Smarter (13B+, slower):**
```json
"model": "mistral"         // Better reasoning
"model": "neural-chat-7b"  // Larger neural-chat
"model": "llama2-uncensored" // Less filtered
```

**Pull models:**
```bash
ollama pull mistral
ollama pull neural-chat
ollama list  # See what you have
```

---

## Custom Ollama Prompts

Edit the **Ollama Form Analysis** node's prompt. Examples:

### Form-Based Transfer Suggestions
```
Analyze FPL player form data.
Players to recommend: 
{{ $nodeData['Fetch FPL Bootstrap'].json.elements
  .filter(p => p.form > 30 && p.selected_by_percent > 5)
  .slice(0, 20)
  .map(p => `${p.web_name} (${p.team_name}, Form: ${p.form}, Price: £${p.now_cost/10}m)`)
  .join(', ')
}}

Generate 5 transfer suggestions in JSON:
[
  {
    "name": "...",
    "current_price": "...",
    "form": "...",
    "reason": "...",
    "risk": "low|medium|high"
  }
]

Only return JSON, no other text.
```

### Injury & Fixture Analysis
```
Analyze FPL data for injuries and fixtures.
Team: {{ $nodeData['Fetch Team Entry'].json.name }}
Players in squad: {{ $nodeData['Fetch Team Picks'].json.picks.map(p => p.element).join(',') }}

Rank these by injury risk and fixture difficulty over next 4 GWs.
Format: [{player, risk_level, action}]
```

### Captain Pick Advisor
```
You are an FPL captain pick advisor.

Team budget: £{{ $nodeData['Fetch Team Entry'].json.summary_team_value / 10 }}m
Transfers available: {{ $nodeData['Fetch Team Entry'].json.transfers_available }}

Current squad players and stats:
{{ JSON.stringify($nodeData['Fetch Team Picks'].json.picks, null, 2) }}

Recommend the best captain for GW {{ $nodeData['Fetch Team Entry'].json.current_event }} 
considering: form, fixture, xG, xA, ownership %.

Format: {player_name, reason, confidence}
```

---

## Webhook Examples

### Fetch Team & Picks
```bash
curl "http://localhost:5678/webhook/YOUR-WEBHOOK-ID/fpl/team?teamId=1234567"
```

Response:
```json
{
  "team": {
    "name": "My FPL Team",
    "player_first_name": "John",
    "summary_overall_points": 1250,
    "summary_overall_rank": 50000
  },
  "picks": {
    "picks": [
      { "element": 1, "position": 1, "is_captain": false, "is_vice_captain": false },
      ...
    ]
  },
  "bootstrap": {
    "events": [...],
    "elements": [...],
    "teams": [...]
  }
}
```

### Fetch Suggestions
```bash
curl "http://localhost:5678/webhook/YOUR-WEBHOOK-ID/fpl/suggestions?teamId=1234567"
```

Response:
```json
{
  "suggestions": [
    {
      "suggestions": "[{\"name\": \"Haaland\", \"reason\": \"High form...\"}]"
    }
  ]
}
```

---

## Environment Variables

Set in n8n Settings → Environment Variables:

| Variable | Value | Required |
|----------|-------|----------|
| `FPL_TEAM_ID` | Your FPL team ID | ✓ |
| `OLLAMA_MODEL` | llama2 (default) | Optional |
| `SYNC_INTERVAL` | 6 (hours) | Optional |

---

## Advanced Customization

### Add Email Alerts
Add an **Email** node after **Store Suggestions**:
```
To: your-email@example.com
Subject: FPL GW {{ $nodeData['...'].json.events[0].id }} Suggestions
Body: {{ JSON.stringify($nodeData['Ollama Form Analysis'].json) }}
```

### Add Slack Notifications
Add a **Slack** node:
```
Message: "FPL Data Synced ✓ 
Team: {{ $nodeData['Fetch Team Entry'].json.name }}
Form suggestions available at /fpl/suggestions"
```

### Multi-Team Support
Duplicate the workflow for each team:
1. Clone the workflow
2. Change `FPL_TEAM_ID` in the new workflow's env vars
3. Create separate webhooks: `/fpl/team2`, `/fpl/team3`, etc.

### Add Fixtures Preview
Insert new nodes after **Fetch FPL Bootstrap**:
```
Filter fixtures for your team's next 5 games
Calculate difficulty rating
Store in new `fpl_fixtures` table
Expose via new webhook `/fpl/fixtures`
```

---

## Troubleshooting

### Ollama Model Not Found
```bash
# Check installed models
ollama list

# Pull missing model
ollama pull llama2

# Check Ollama is running
curl http://localhost:11434/api/tags
```

### PostgreSQL Connection Error
```bash
# Check container is running
docker-compose ps

# Check logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres psql -U postgres -c "SELECT 1;"
```

### Webhook Returns Empty Data
1. Run **Schedule Trigger** manually first (right-click → Execute)
2. Check n8n execution history for errors
3. Verify data is in PostgreSQL:
   ```bash
   docker-compose exec postgres psql -U postgres -d fpl_db -c "SELECT * FROM fpl_teams LIMIT 1;"
   ```

### n8n Won't Start
```bash
# View logs
docker-compose logs n8n

# Restart
docker-compose restart n8n

# Check port 5678 is free
lsof -i :5678
```

---

## Files Included

| File | Purpose |
|------|---------|
| `fpl-n8n-workflow.json` | n8n workflow export (import this) |
| `fpl-db-setup.sql` | PostgreSQL schema |
| `docker-compose.yml` | Docker services config |
| `quickstart.sh` | One-command setup script |
| `FPL-N8N-SETUP.md` | Full setup guide |
| `WORKFLOW-REFERENCE.md` | This file |
| `fpl-picker.html` | Updated UI with n8n integration |

---

## Performance Notes

- **Bootstrap data:** ~2-3 MB (cached every 6 hours)
- **Team entry:** ~50 KB per team
- **Picks:** ~20 KB per team per GW
- **Ollama analysis:** ~5-10 seconds per run (depends on model)

For **multiple teams**, add separate schedules or extend the workflow to loop through team IDs.

---

## Next Steps

- **Monitoring:** Add Prometheus metrics export
- **Dashboard:** Build n8n UI with stats and charts
- **History:** Store GW-by-GW data for trend analysis
- **Predictions:** Use Ollama to predict next GW captaincy
- **Automation:** Auto-make transfers based on thresholds

Enjoy! ⚽🚀
