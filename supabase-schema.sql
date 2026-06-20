-- ============================================================
-- N8N COMMAND CENTER — Supabase Schema
-- Versão: 1.0.0
-- Uso:   Rodar no SQL Editor do Supabase
--        (projeto: gswzuzetverulcgzhynb)
-- ============================================================

-- 1. WORKFLOWS (populado pelo Collector a cada 2 min)
CREATE TABLE IF NOT EXISTS n8n_workflows (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  n8n_id                 TEXT UNIQUE NOT NULL,
  name                   TEXT NOT NULL,
  active                 BOOLEAN DEFAULT false,
  tags                   TEXT[] DEFAULT '{}',
  status                 TEXT DEFAULT 'unknown',
  last_execution_status  TEXT,
  last_executed_at       TIMESTAMPTZ,
  last_execution_id      TEXT,
  executions_24h         INTEGER DEFAULT 0,
  success_24h            INTEGER DEFAULT 0,
  error_24h              INTEGER DEFAULT 0,
  avg_execution_ms       INTEGER,
  updated_at             TIMESTAMPTZ DEFAULT now(),
  created_at             TIMESTAMPTZ DEFAULT now()
);

-- 2. EVENTS (populado pelo Collector + futuros webhooks SDR)
CREATE TABLE IF NOT EXISTS n8n_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workflow_id   TEXT,
  workflow_name TEXT,
  event_type    TEXT NOT NULL,
  status        TEXT DEFAULT 'success'
    CHECK (status IN ('success','error','pending','warning')),
  message       TEXT,
  error_message TEXT,
  execution_ms  INTEGER,
  metadata      JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- 3. METRICS (snapshots históricos — populado a cada 1h)
CREATE TABLE IF NOT EXISTS n8n_metrics (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_at           TIMESTAMPTZ DEFAULT now(),
  total_workflows       INTEGER DEFAULT 0,
  active_workflows      INTEGER DEFAULT 0,
  total_executions_24h  INTEGER DEFAULT 0,
  total_success_24h     INTEGER DEFAULT 0,
  total_error_24h       INTEGER DEFAULT 0,
  overall_success_rate  DECIMAL(5,4),
  avg_execution_time_ms INTEGER
);

-- 4. HEARTBEAT (populado a cada 5 min)
CREATE TABLE IF NOT EXISTS n8n_heartbeat (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  checked_at        TIMESTAMPTZ DEFAULT now(),
  is_alive          BOOLEAN DEFAULT true,
  n8n_version       TEXT,
  active_workflows  INTEGER,
  api_response_ms   INTEGER,
  details           JSONB DEFAULT '{}'
);

-- 5. SDR AGENTS (cadastro manual das SDRs)
CREATE TABLE IF NOT EXISTS sdr_agents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id    TEXT UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  squad       TEXT DEFAULT 'matriz',
  status      TEXT DEFAULT 'active'
    CHECK (status IN ('active','paused','error','offline')),
  config      JSONB DEFAULT '{}',
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- 6. SDR EVENTS (granular — para quando webhooks SDR forem adicionados)
CREATE TABLE IF NOT EXISTS sdr_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id      TEXT REFERENCES sdr_agents(agent_id),
  event_type    TEXT NOT NULL,
  lead_id       TEXT,
  lead_name     TEXT,
  company       TEXT,
  email         TEXT,
  message       TEXT,
  status        TEXT DEFAULT 'success'
    CHECK (status IN ('success','error','pending')),
  error_message TEXT,
  execution_ms  INTEGER,
  metadata      JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- VIEWS
-- ============================================================

-- Visão dos workflows com status derivado
CREATE OR REPLACE VIEW vw_workflows_status AS
SELECT
  *,
  CASE
    WHEN active = false THEN 'inactive'
    WHEN last_execution_status = 'error' OR status = 'error' THEN 'error'
    WHEN active = true THEN 'active'
    ELSE 'unknown'
  END as derived_status,
  CASE
    WHEN UPPER(name) LIKE '%SDR%' THEN true
    ELSE false
  END as is_sdr
FROM n8n_workflows;

-- Resumo diário
CREATE OR REPLACE VIEW vw_daily_summary AS
SELECT
  COUNT(*) as total_workflows,
  COUNT(*) FILTER (WHERE active = true) as active_workflows,
  COALESCE(SUM(executions_24h), 0) as total_executions,
  COALESCE(SUM(success_24h), 0) as total_success,
  COALESCE(SUM(error_24h), 0) as total_errors,
  CASE
    WHEN SUM(executions_24h) > 0
    THEN ROUND(SUM(success_24h)::DECIMAL / SUM(executions_24h) * 100, 1)
    ELSE 0
  END as success_rate_pct
FROM n8n_workflows;

-- ============================================================
-- REALTIME
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE n8n_workflows;
ALTER PUBLICATION supabase_realtime ADD TABLE n8n_events;
ALTER PUBLICATION supabase_realtime ADD TABLE n8n_heartbeat;
ALTER PUBLICATION supabase_realtime ADD TABLE sdr_events;

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_n8n_workflows_active ON n8n_workflows(active);
CREATE INDEX IF NOT EXISTS idx_n8n_workflows_name ON n8n_workflows(name);
CREATE INDEX IF NOT EXISTS idx_n8n_events_created ON n8n_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_n8n_heartbeat_time ON n8n_heartbeat(checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_n8n_metrics_time ON n8n_metrics(snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_sdr_events_agent ON sdr_events(agent_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sdr_events_type ON sdr_events(event_type, created_at DESC);
