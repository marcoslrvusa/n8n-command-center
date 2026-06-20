# N8N Command Center

Dashboard em tempo real para monitorar **todos os workflows do N8N** + SDR IAs.

## Arquitetura

```
N8N Instance (n8n.fvmarketing.com.br)
  │
  ├── [CC] Collector (a cada 2 min)
  │     └── Lê API → UPSERT em n8n_workflows
  │
  ├── [CC] Heartbeat (a cada 5 min)
  │     └── Health check → INSERT em n8n_heartbeat
  │
  └── [CC] Metrics (a cada 1h)
        └── Agrega → INSERT em n8n_metrics
          │
          ▼
    Supabase (gswzuzetverulcgzhynb)
      │
      ▼ Realtime WebSocket
    Dashboard (GitHub Pages)
```

## Setup

### 1. Schema no Supabase

1. Acesse [app.supabase.com](https://app.supabase.com)
2. Projeto: `gswzuzetverulcgzhynb`
3. Vá em **SQL Editor**
4. Cole o conteúdo de `supabase-schema.sql`
5. Execute

### 2. Credencial Supabase no N8N

1. No N8N, Settings → Credentials → Add
2. Tipo: **Supabase API**
3. Nome: `Command Center Supabase`
4. Host: `https://gswzuzetverulcgzhynb.supabase.co`
5. Service Role Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdzd3p1emV0dmVydWxjZ3poeW5iIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1OTkyNTk3OCwiZXhwIjoyMDc1NTAxOTc4fQ.5ZIRLus3BM2IPr57xjRuJrVsa0dE3IR0U5UU5kgpZfY`

### 3. Importar Workflows no N8N

1. Settings → Workflows → Import
2. Importe cada arquivo de `workflows/`:
   - `collector-workflow.json`
   - `heartbeat-workflow.json`
   - `metrics-workflow.json`
3. Para cada workflow, adicione as variáveis de ambiente:
   - `N8N_URL`: `https://n8n.fvmarketing.com.br`
   - `N8N_API_KEY`: (a mesma que está no n8n-manager)
4. Ative os 3 workflows

### 4. Dashboard

O dashboard no GitHub Pages já está lendo os dados do Supabase automaticamente.

- **URL**: `https://marcoslrvusa.github.io/n8n-command-center/`

## Dados Monitorados

| Tabela | Populado por | Conteúdo |
|--------|-------------|----------|
| `n8n_workflows` | Collector (2 min) | Todos os workflows com métricas 24h |
| `n8n_heartbeat` | Heartbeat (5 min) | Saúde da instância N8N |
| `n8n_metrics` | Metrics (1h) | Snapshots históricos para gráficos |
| `sdr_agents` | Manual | Catálogo das SDR IAs |
| `sdr_events` | (futuro) | Eventos granulares das SDRs |

## Personalizar

Para mudar a URL, edite `index.html` e altere:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
