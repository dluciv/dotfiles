---
name: web-search-fallback
description: Use when searching the web and the built-in `websearch` tool (Exa) is unavailable or fails or errors (e.g. 403 / transport error). Gives a fallback chain of HTML search engines to use via `webfetch`. Triggers on web searches, current/news/unknown-topic queries, any time web search is needed. Deep/multi-topic research is delegated to the `web-researcher` subagent.
---

# Web search with fallback

> Для глубокого или многотемного ресёрча делегируй задачу субагенту `web-researcher` (работает по правилам этого скилла и возвращает дистиллированный ответ с источниками).

Search order (prefer the first that works):

1. `websearch` (Exa) if available.
2. **web-search-mcp** (if connected) — local MCP server, engines Bing > Brave > DuckDuckGo, no API key. Three tools:
   - `get-web-search-summaries` — lightweight: query + snippets only. **Best default**: full search strategy but minimal output, fewest tokens.
   - `full-web-search` — also extracts full page content (masses of tokens); use only when summaries aren't enough and you actually need the body text.
   - `get-single-web-page-content` — extract content from a known URL; faster than searching.
   Advantage: higher-quality results via browser engines + relevance checking. Use it when it's available.
3. `webfetch` fallback chain below.

If some choice is unavailable or errors, move down the chain.

## webfetch fallback chain

If `websearch` is unavailable or results in errors (403 / transport / empty), don't give up — fall back to the engines below via `webfetch` (format `markdown`), in order, stopping at the first that returns results.

Use `q=` as the query param (spaces are fine).

1. DuckDuckGo HTML: `https://html.duckduckgo.com/html/?q=<query>`
2. DuckDuckGo Lite: `https://lite.duckduckgo.com/lite/?q=<query>`
3. Brave: `https://search.brave.com/search?q=<query>`
4. Yahoo: `https://search.yahoo.com/search?p=<query>`
5. Marginalia (English-only index): `https://search.marginalia.nu/search?query=<query>`

## Reading results

- Extract title + URL + short snippet per result.
- An engine that returns only boilerplate — captcha/anti-bot pages ("Verifying your request...", "Please solve the challenge", "Verification required"), or no real results — counts as **failed**; move to the next.
- Open the best result directly with `webfetch` before answering.
- If you already know the authoritative site, fetch it directly — faster and more reliable than searching.

Unreliable in this setup (captcha/JS/403): Bing, Startpage, Ecosia, Mojeek, Swisscows, and most public SearXNG instances (`searx.be`, `searx.tiekoetter.com`, `priv.au`) may not render results as static HTML. Consider them only if the chain above all fails.
