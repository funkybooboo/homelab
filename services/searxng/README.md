# SearXNG

Privacy-respecting metasearch engine that aggregates results from multiple search engines.

## Quick Start

```bash
# Generate secret key
openssl rand -hex 32

# Add to .env
nano .env

# Start service
./start.sh
```

Access: http://localhost:8889

## Features

- Privacy-focused (no tracking)
- Aggregates results from 70+ search engines
- Customizable search categories
- No ads
- Self-hosted

## Configuration

After first start, configure at: http://localhost:8889/preferences

- Choose search engines
- Set appearance theme
- Configure language
- Enable/disable categories

## Search Categories

- General (Google, Bing, DuckDuckGo, etc.)
- Images
- Videos
- News
- Maps
- Music
- IT (StackOverflow, GitHub, etc.)
- Science
- Files

## Set as Default Search Engine

**Firefox:**
1. Visit http://localhost:8889
2. Right-click search bar
3. "Add SearXNG"

**Chrome:**
1. Settings → Search engine
2. Manage search engines
3. Add: http://localhost:8889/search?q=%s

## More Info

[SearXNG Documentation](https://docs.searxng.org/)
