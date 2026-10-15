-- FPL n8n Workflow Database Schema
-- Run this in your PostgreSQL database before importing the n8n workflow

CREATE TABLE IF NOT EXISTS fpl_bootstrap (
  gw INTEGER PRIMARY KEY,
  data JSONB NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fpl_teams (
  team_id INTEGER PRIMARY KEY,
  data JSONB NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fpl_picks (
  team_id INTEGER NOT NULL,
  gw INTEGER NOT NULL,
  data JSONB NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (team_id, gw)
);

CREATE TABLE IF NOT EXISTS fpl_suggestions (
  id SERIAL PRIMARY KEY,
  team_id INTEGER NOT NULL,
  gw INTEGER NOT NULL,
  suggestions TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_fpl_bootstrap_updated ON fpl_bootstrap(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_fpl_teams_updated ON fpl_teams(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_fpl_picks_team ON fpl_picks(team_id);
CREATE INDEX IF NOT EXISTS idx_fpl_suggestions_team_gw ON fpl_suggestions(team_id, gw DESC);

-- Optional: View for latest team data with all info
CREATE OR REPLACE VIEW fpl_team_view AS
SELECT
  t.team_id,
  t.data->>'name' as team_name,
  t.data->>'player_first_name' as manager_first,
  t.data->>'player_last_name' as manager_last,
  t.data->>'summary_overall_points' as total_points,
  p.gw,
  p.data as picks,
  b.data as bootstrap,
  t.updated_at as team_updated,
  p.updated_at as picks_updated,
  b.updated_at as bootstrap_updated
FROM fpl_teams t
LEFT JOIN fpl_picks p ON t.team_id = p.team_id AND p.gw = (
  SELECT gw FROM fpl_picks WHERE team_id = t.team_id ORDER BY gw DESC LIMIT 1
)
LEFT JOIN fpl_bootstrap b ON b.gw = p.gw;
