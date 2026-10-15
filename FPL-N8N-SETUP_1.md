# FPL n8n Workflow - Local Setup Guide

## Overview
This workflow syncs Fantasy Premier League (FPL) data to PostgreSQL every 6 hours, analyzes player form with Ollama, and exposes REST APIs for the FPL picker UI.

**Architecture:**
- **Data Source:** FPL Public API (no auth needed)
- **Storage:** PostgreSQL (your stack)
- **AI Analysis:** Ollama (llama2 locally)
- **Orchestration:** n8n (self-hosted)
- **Frontend:** HTML picker (consumes `/fpl/team` endpoint)

---

## Prerequisites

### 1. PostgreSQL (Already have)
Your existing PostgreSQL instance. Just run the schema setup.

### 2. Ollama (Local LLM)
```bash
# Install Ollama
curl https://ollama.ai/install.sh | sh

# Start Ollama service
ollama serve

# In another terminal, pull llama2
ollama pull llama2

# Verify it's running on http://localhost:11434
curl http://localhost:11434/api/tags
```

### 3. n8n (Self-hosted)
```bash
# Option A: Docker (recommended for local dev)
docker run -it \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=localhost \
  -e DB_POSTGRESDB_PORT=5432 \
  -e DB_POSTGRESDB_DATABASE=n8n \
  -e DB_POSTGRESDB_USER=postgres \
  -e DB_POSTGRESDB_PASSWORD=yourpassword \
  n8nio/n8n

# Option B: npm (local install)
npm install -g n8n
n8n start
```

n8n will be at `http://localhost:5678`

---

## Setup Steps

### Step 1: Create Database Schema
```bash
psql -U postgres -d your_fpl_db -f fpl-db-setup.sql
```

### Step 2: Configure n8n Environment
When you first open n8n, set these environment variables:

**In n8n's Settings → Environment Variables:**
```
FPL_TEAM_ID=YOUR_FPL_TEAM_ID_HERE
```

Find your Team ID:
- Go to `https://fantasy.premierleague.com/`
- Click your team
- URL will be: `fantasy.premierleague.com/entry/YOUR-ID/...`

### Step 3: Import Workflow
1. Open n8n at `http://localhost:5678`
2. Click **Workflows** → **Import from URL** or **Import from File**
3. Upload `fpl-n8n-workflow.json`
4. The workflow will load with all nodes

### Step 4: Configure Database Connection
In n8n, edit the workflow and click each **Postgres** node:
- **Host:** `localhost` (or your PostgreSQL host)
- **Port:** `5432`
- **Database:** Your database name
- **User:** `postgres` (or your user)
- **Password:** Your PostgreSQL password
- **SSL:** Off (for local dev)

Save the credentials and test the connection.

### Step 5: Activate Webhook Endpoints
The workflow creates two public webhooks. Activate them:
1. Click the **Webhook Team Data** node → copy the webhook URL
2. Click the **Webhook Suggestions** node → copy the webhook URL

The URLs will be like:
```
http://localhost:5678/webhook/abc123/fpl/team
http://localhost:5678/webhook/abc456/fpl/suggestions
```

### Step 6: Deploy Workflow
Click **Save** and toggle **Active** to ON. The workflow will:
- Fetch FPL data every 6 hours
- Analyze with Ollama
- Store in PostgreSQL
- Expose webhooks for queries

---

## Using the Workflow

### Fetch Team Data (from Picker UI)
```javascript
// In your HTML picker, replace direct FPL API calls with:
const response = await fetch('http://localhost:5678/webhook/abc123/fpl/team?teamId=YOUR_TEAM_ID');
const data = await response.json();
// data = { team: {...}, picks: {...}, bootstrap: {...} }
```

### Get Transfer Suggestions
```javascript
const response = await fetch('http://localhost:5678/webhook/abc456/fpl/suggestions?teamId=YOUR_TEAM_ID');
const suggestions = await response.json();
// suggestions = { suggestions: [...] }
```

### Manual Trigger
Right-click the **Schedule Trigger** node → **Execute Node** to sync immediately (useful for testing).

---

## Workflow Nodes Explained

| Node | Purpose |
|------|---------|
| **Schedule Trigger** | Runs every 6 hours |
| **Fetch FPL Bootstrap** | Gets all players, teams, fixtures |
| **Fetch Team Entry** | Gets your team info (name, rank, budget) |
| **Fetch Team Picks** | Gets your current squad for GW |
| **Store Bootstrap Data** | Saves to `fpl_bootstrap` table |
| **Store Team Entry** | Saves to `fpl_teams` table |
| **Store Team Picks** | Saves to `fpl_picks` table |
| **Ollama Form Analysis** | Uses llama2 to analyze player form & suggest transfers |
| **Store Suggestions** | Saves AI suggestions to `fpl_suggestions` table |
| **Webhook Team Data** | REST endpoint `/fpl/team` for UI |
| **Webhook Suggestions** | REST endpoint `/fpl/suggestions` for UI |

---

## Customization

### Change Sync Interval
Edit **Schedule Trigger** node:
- Default: Every 6 hours
- Change to hourly: Set `value: 1`, `unit: hours`

### Use Different Ollama Model
Edit **Ollama Form Analysis** node:
```json
{
  "model": "mistral"  // or neural-chat, orca-mini, etc.
}
```

Pull model first:
```bash
ollama pull mistral
```

### Extend Analysis Prompt
Edit the prompt in **Ollama Form Analysis**:
```
"prompt": "Analyze FPL data and suggest transfers considering: form, fixtures, price, ownership. Return JSON with: [{name, reason, risk_level}]"
```

### Add More Webhooks
Duplicate **Webhook Team Data** and create custom endpoints:
- `/fpl/fixtures` — get upcoming matches
- `/fpl/transfers` — get transfer history
- `/fpl/stats` — aggregate stats

---

## Troubleshooting

### Ollama Not Responding
```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Restart Ollama
ps aux | grep ollama  # find PID
kill <PID>
ollama serve
```

### Webhooks Not Firing
1. Check n8n logs: `docker logs <n8n-container>` or terminal output
2. Ensure workflow is **Active** (toggle ON)
3. Test webhook directly:
   ```bash
   curl http://localhost:5678/webhook/abc123/fpl/team?teamId=1234567
   ```

### PostgreSQL Connection Fails
1. Verify credentials in n8n Postgres node
2. Check PostgreSQL is running: `psql -U postgres -c "SELECT 1;"`
3. Run schema setup: `psql -U postgres -d your_db -f fpl-db-setup.sql`

### Data Not Updating
1. Click **Schedule Trigger** → **Execute Node** to test immediately
2. Check n8n **Execution History** tab for errors
3. Verify Ollama model exists: `ollama list`

---

## Next Steps

- **Scale:** Add more teams by passing `teamId` to webhooks
- **Alerts:** Add email/Slack notifications when form drops
- **Dashboard:** Create n8n UI to visualize stored FPL data
- **Advanced:** Use Ollama to predict captaincy, injury risk, etc.
- **Export:** Save weekly recommendations to a CRA-linked workflow

---

## File Reference

- `fpl-n8n-workflow.json` — Import into n8n
- `fpl-db-setup.sql` — Run in PostgreSQL
- `fpl-picker.html` — Updated UI to call n8n endpoints

Enjoy the automation! ⚽
