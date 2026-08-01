# Idea: Homelab Auto-Repair System (HAL)

> An intelligent, self-healing homelab that detects issues via ntfy alerts and
> automatically resolves them using scripted playbooks and AI-driven decisions.

---

## Problem Statement

**Homelabs break silently and often.**

Running a homelab with dozens of services (Plex, *arr apps, databases,
reverse proxies, containers) means constant maintenance. Disks fill up,
containers crash, certificates expire, services hang, and networks glitch.
Currently, this means:
- Finding out hours later when something stops working
- Manual SSH sessions to diagnose and fix
- 2 AM alerts that require immediate action
- Services down while you're away from keyboard

**Current "solutions" are inadequate:**
- Uptime Kuma/Prometheus alerts = notification fatigue
- Manual runbooks = slow, error-prone, requires you to be available
- Paid AIOps = overkill and expensive for homelab scale

---

## Solution

**HAL (Homelab Auto-Repair)** -- A event-driven automation layer that turns
ntfy alerts into autonomous remediation workflows.

**Core loop:**
```
Service Issue -> Monitor Alert -> ntfy Notification -> n8n Webhook
    -> AI Analysis -> Script Execution -> Verification -> Resolution Report
```

**Key differentiators:**
- **Event-native**: Uses ntfy's action webhooks for instant triggering
- **AI-augmented**: LLM analyzes logs and selects appropriate fix scripts
- **Self-documenting**: Every action logged with before/after state
- **Human-in-the-loop**: Escalates to you when confidence is low
- **Extensible**: Easy to add new "sensors" and "actuators"

---

## Target Audience

| Segment | Description | Pain Level |
|---------|-------------|------------|
| **Primary** | Homelab enthusiasts with 10+ services | Very High |
| Secondary | Small self-hosting communities | High |
| Future | Small business IT (10-50 users) | Medium |

**User Persona:**
- **Name**: Alex
- **Role**: Software engineer / sysadmin hobbyist
- **Setup**: Proxmox cluster, Docker swarm, TrueNAS, multiple VMs
- **Pain**: "I spend more time fixing my lab than using it"
- **Current workaround**: Phone alerts + manual SSH at 11 PM

---

## Core Features (MVP)

**Detection Layer:**
1. **ntfy Integration** - Monitors subscribe to critical topics (alerts,
   errors, thresholds)
2. **Webhook Bridge** - ntfy actions POST to n8n with structured payload
3. **Severity Classification** - Auto-triage: Auto-fix / Notify / Escalate

**Intelligence Layer:**
4. **Log Ingestion** - Pull relevant logs from affected service
5. **AI Diagnosis** - LLM analyzes symptoms and suggests fix from playbook
6. **Confidence Scoring** - Skip auto-fix if uncertainty > threshold

**Action Layer:**
7. **Script Runner** - Execute pre-written bash/Python/Ansible scripts
8. **Docker Control** - Restart/recreate containers, prune images/volumes
9. **System Commands** - Clear caches, rotate logs, free disk space
10. **Verification** - Confirm fix worked before closing loop

**Reporting:**
11. **ntfy Report Back** - Send success/failure summary with logs
12. **Dashboard** - History of incidents and resolutions

---

## Technical Architecture

```
+---------------------------------------------------------------------+
|                         DETECTION LAYER                            |
+---------------------------------------------------------------------+
|  Uptime Kuma  |  Prometheus  |  TrueNAS  |  Custom Scripts         |
|       |              |             |              |                |
|       +--------------+-------------+--------------+                |
|                         |                                          |
|                    +----+----+                                     |
|                    |  ntfy   |  <- Self-hosted notification hub      |
|                    | Server  |                                     |
|                    +----+----+                                     |
+-------------------------+-------------------------------------------+
                          | POST webhook
                          v
+---------------------------------------------------------------------+
|                      ORCHESTRATION LAYER                           |
|                         (n8n Workflows)                            |
+---------------------------------------------------------------------+
|                                                                     |
|   +-------------+    +-------------+    +-------------+           |
|   | Webhook     |--->| Classify    |--->| Fetch Logs  |           |
|   | Trigger     |    | Severity    |    | (SSH/API)   |           |
|   +-------------+    +-------------+    +------+------+           |
|                                                  |                  |
|   +-------------+    +-------------+    +------+------+           |
|   | Execute     |<---| Select      |<---| AI Analysis |           |
|   | Fix Script  |    | Playbook    |    | (Venice AI) |           |
|   +------+------+    +-------------+    +-------------+           |
|          |                                                          |
|   +------+------+    +-------------+    +-------------+           |
|   | Verify      |--->| Report      |--->| Notify      |           |
|   | Health      |    | Outcome     |    | (ntfy)      |           |
|   +-------------+    +-------------+    +-------------+           |
|                                                                     |
+---------------------------------------------------------------------+
                          |
                          v
+---------------------------------------------------------------------+
|                        ACTION LAYER                                  |
+---------------------------------------------------------------------+
|  +----------+  +----------+  +----------+  +----------+            |
|  |  Docker  |  |  System  |  |  Network |  |  Service |            |
|  |  API     |  |  SSH     |  |  Router  |  |  APIs    |            |
|  +----------+  +----------+  +----------+  +----------+            |
+---------------------------------------------------------------------+
```

**Stack:**
- **Trigger**: ntfy (self-hosted)
- **Orchestration**: n8n (self-hosted)
- **AI**: Venice AI API (or local LLM via Ollama)
- **Script Runner**: Node-SSH, Execute Command nodes, or Ansible
- **Monitoring**: Uptime Kuma, Prometheus, or custom scripts
- **Storage**: SQLite for incident history

---

## Playbook Library (Auto-Fix Scripts)

**Category: Disk Space**
| Issue | Detection | Fix Script | Confidence |
|-------|-----------|------------|------------|
| Docker overlay full | >90% /var/lib/docker | `docker system prune -af` | 95% |
| Log bloat | >5GB /var/log | `journalctl --vacuum-size=500M` | 95% |
| *arr app cache | Sonarr/Radarr alert | Clear image cache via API | 90% |

**Category: Container Health**
| Issue | Detection | Fix Script | Confidence |
|-------|-----------|------------|------------|
| Container exited | Exit code != 0 | `docker compose restart` | 85% |
| Unhealthy status | Health check fail | Recreate with `up --force-recreate` | 80% |
| Image outdated | Watchtower notify | Pull and recreate | 90% |

**Category: Service Recovery**
| Issue | Detection | Fix Script | Confidence |
|-------|-----------|------------|------------|
| Plex unreachable | HTTP 502/503 | Restart container, clear transcode | 85% |
| DB connection fail | App logs show timeout | Restart dependent services in order | 75% |
| Certificate expired | TLS error | Run certbot renew | 95% |

**Category: Network**
| Issue | Detection | Fix Script | Confidence |
|-------|-----------|------------|------------|
| DNS resolution fail | nslookup timeout | Restart pihole/unbound, flush cache | 85% |
| VPN down | WireGuard handshake fail | Restart wg-quick, check endpoint | 70% |

---

## ntfy -> n8n Integration

**ntfy Topic Structure:**
```
homelab/
+- critical/     # Immediate auto-fix attempt
+- warning/       # Queue for review, auto-fix if confidence high
+- info/          # Log only, no action
\-- manual/       # Require human approval
```

**Example ntfy Action (in your monitoring tool):**
```bash
curl -X POST https://ntfy.yourdomain.com/homelab-critical \
  -H "Title: Docker Disk Full" \
  -H "Priority: urgent" \
  -H "Tags: warning,disk,auto" \
  -H "Action: http, Auto-Fix, https://n8n.yourdomain.com/webhook/hal-repair, method=POST, headers.authorization=Bearer HAL_API_KEY, body={\"alert\":\"disk_full\",\"host\":\"{{hostname}}\",\"service\":\"docker\",\"severity\":\"critical\",\"timestamp\":\"{{ts}}\"}" \
  -d "Disk usage on {{hostname}} is at {{disk_pct}}%. Attempting auto-repair."
```

**n8n Webhook Payload Structure:**
```json
{
  "topic": "homelab-critical",
  "title": "Docker Disk Full",
  "message": "Disk usage on proxmox-01 is at 95%",
  "priority": 5,
  "tags": ["warning", "disk", "auto"],
  "alert": "disk_full",
  "host": "proxmox-01",
  "service": "docker",
  "severity": "critical",
  "timestamp": "2026-08-01T14:32:00Z"
}
```

---

## AI Integration (Venice AI)

**Prompt Template for Diagnosis:**
```
You are HAL, a homelab auto-repair system. Analyze this alert and select
the best fix from the playbook.

ALERT:
- Host: {{host}}
- Service: {{service}}
- Issue: {{alert_type}}
- Recent logs: {{logs}}

AVAILABLE PLAYBOOKS:
1. docker_prune - clears unused images/volumes
2. service_restart - restarts the container
3. log_rotate - clears old logs
4. cert_renew - renews SSL certificates
5. escalate_human - requires manual intervention

Respond in JSON:
{
  "playbook": "name",
  "confidence": 0-100,
  "reasoning": "brief explanation",
  "commands": ["cmd1", "cmd2"],
  "risk_level": "low/medium/high"
}

Only auto-execute if confidence >= 85 and risk_level == "low".
```

---

## Execution Flow

**Success Path:**
1. Monitor detects issue -> publishes to ntfy
2. ntfy action fires webhook to n8n
3. n8n classifies severity from topic/tags
4. If auto-eligible: fetch logs from host via SSH
5. Send logs + context to AI for diagnosis
6. AI returns playbook recommendation
7. If confidence >= threshold: execute script
8. Verify fix (health check, HTTP ping, log check)
9. Report success back to ntfy with summary

**Escalation Path:**
- Confidence < 85% -> Queue for manual review
- Risk level = "high" -> Notify only, don't auto-fix
- Fix fails verification -> Rollback + escalate
- Multiple failures in 1 hour -> Circuit breaker, stop auto-fix

---

## Safety & Guardrails

| Guardrail | Implementation |
|-----------|----------------|
| Dry-run mode | AI suggests, human approves first |
| Rate limiting | Max 3 auto-fixes per hour per service |
| Circuit breaker | Stop after 3 consecutive failures |
| Exclusion list | Never auto-touch: networking, storage pools, backups |
| Rollback | Snapshot state before destructive actions |
| Audit log | Every action logged with full context |

---

## Success Metrics

**Week 1-2 (MVP):**
- [ ] Successfully trigger n8n from ntfy manually
- [ ] 3 working playbooks (disk, restart, cert)
- [ ] 1 end-to-end auto-fix

**Month 1:**
- [ ] 10+ playbooks covering common issues
- [ ] 80% of "disk full" alerts auto-resolved
- [ ] Average MTTR (mean time to repair) < 2 minutes

**Month 3:**
- [ ] 50% of all alerts handled without human
- [ ] Zero false-positive fixes (no "fixed" what wasn't broken)
- [ ] < 5% escalation rate

---

## Phase 1 Build Plan

**Week 1: Plumbing**
- [ ] Set up ntfy with topic hierarchy
- [ ] Create n8n webhook workflow
- [ ] Test ntfy -> n8n -> ntfy roundtrip

**Week 2: First Playbook**
- [ ] Build "disk full" detection (script/cron)
- [ ] Write docker_prune playbook
- [ ] Integrate AI for log analysis
- [ ] Test end-to-end

**Week 3: Expand & Harden**
- [ ] Add 3 more playbooks
- [ ] Implement confidence scoring
- [ ] Add verification steps
- [ ] Create dashboard

**Week 4: Polish**
- [ ] Dry-run mode testing
- [ ] Documentation
- [ ] Share with homelab community

---

## Open Questions

1. Should AI run locally (Ollama) or via API (Venice/OpenAI)?
   - Local = private, no cost
   - API = smarter, faster

2. How to handle stateful services (databases) safely?

3. Should there be a "maintenance mode" that pauses auto-fix?

4. Integration with existing tools: Ansible, Terraform, Proxmox API?

---

## Resources Needed

- **Time**: ~20 hours for MVP
- **Money**: $0 (all self-hosted)
- **Hardware**: Existing homelab + n8n container
- **Skills**: Docker, n8n, bash, basic API knowledge

---

## Why Now?

- n8n has mature webhook and SSH nodes
- LLMs are cheap enough for homelab use
- ntfy provides simple, reliable mobile notifications
- "Self-healing infrastructure" usually requires $$$$ enterprise tools
- You already have the homelab pain -- time to automate the fix

---

## One-Sentence Pitch

> "HAL turns your homelab's 2 AM alerts into 30-second auto-fixes by routing
> ntfy notifications through AI-powered n8n workflows that safely execute
> repair scripts without waking you up."

---

*Status: Idea -> Ready to build*