---
title: "Reading Reddit programmatically in 2026: use the Atom (RSS) feed, not the JSON API or OAuth"
date: 2026-07-23
category: tooling-decisions
module: RedditApi
component: reddit-search
problem_type: tooling-decisions
applies_when:
  - "Building or maintaining an integration that reads Reddit search results or subreddit content without a logged-in user session"
  - "An existing Reddit integration started returning HTTP 403 with a large HTML challenge page from www.reddit.com/*.json, old.reddit.com/*.json, or api.reddit.com"
  - "Evaluating whether unauthenticated oauth.reddit.com or self-service OAuth credentials are a viable path (they are not, as of Nov 2025)"
  - "Designing rate-limit handling against Reddit's ~1 request/minute/IP RSS budget using x-ratelimit-remaining / x-ratelimit-reset headers"
tags:
  - reddit
  - rss
  - atom-feed
  - rate-limiting
  - oauth
  - api-access
  - raycast
  - responsible-builder-policy
  - "http-403"
  - "http-429"
---

# Reading Reddit programmatically in 2026: use the Atom (RSS) feed, not the JSON API or OAuth

## Context

In late 2025, Reddit closed the door on the thing every hobbyist tool used to rely on: appending `.json` to any Reddit URL to get structured data back. As of this investigation (verified live 2026-07-22/23), anonymous access to Reddit's JSON API returns `403` across the board — not a soft rate limit, but a hard bot wall serving ~189KB of HTML. Spoofing a browser User-Agent does not help. The OAuth escape hatch is closed too: Reddit's Responsible Builder Policy (Nov 2025) requires manual approval before any new `client_id` can touch the API, and personal read-only projects are the most-rejected category.

This left a concrete engineering problem for any external tool (a Raycast extension, a desktop app, a CLI) that needs to read Reddit programmatically without a grandfathered credential: **every documented "read Reddit" path is dead except one.** The one that still works is the public Atom (RSS) feed, and it works well — but only if you handle its rate limit and parsing quirks correctly.

The measured landscape, so a future engineer can confirm the diagnosis matches theirs:

| Endpoint | Result (2026-07) |
|---|---|
| `www.reddit.com/search.json` (any UA, incl. browser spoof) | `403` + 189KB HTML bot wall |
| `old.reddit.com/*.json` | `403` |
| `api.reddit.com/search` | `403` |
| `r/<sub>/hot.json` | `403` |
| `oauth.reddit.com/*` without token | `403` |
| `www.reddit.com/api/v1/access_token` | `401` (endpoint alive; rejects on credentials only) |
| `www.reddit.com/search.rss` | **`200` with real Atom data** |

## Guidance

**Read Reddit through its public Atom (RSS) feed, not the JSON API.** The `.rss` endpoints are unauthenticated, return real data, and honor the query parameters you need. Treat this as the primary integration surface, not a fallback.

Four rules make this reliable:

1. **Use `.rss`, never `.json`.** The `.json` variants are 403-walled for anonymous callers. The `.rss` variants return `200`.

2. **Filter Atom entries by ID prefix.** A post search returns matching *subreddits* mixed in with posts. Reddit's fullname prefixes disambiguate: `t3_` = post (link/self), `t5_` = subreddit. Filter on the entry `id` prefix — do not assume every entry in a post search is a post.

3. **Strip Reddit's chrome structurally, not by phrase.** Reddit wraps the real post body between `<!-- SC_OFF -->` and `<!-- SC_ON -->`, then appends "submitted by … [link] [comments]" navigation chrome *after* `<!-- SC_ON -->`. Cut on the marker structure, never on the bare substring `"submitted by"` — a post whose body legitimately contains "submitted by" would be truncated.

4. **Arm the rate-limit cooldown from success-response headers, not only from 429s.** Reddit allows roughly **1 request/minute/IP**. Every response — including `200`s — carries `x-ratelimit-remaining` and `x-ratelimit-reset`. A *successful* response can report `remaining: 0`. If you only start a cooldown when you see a `429`, your guard engages one request too late and the very next request earns the `429` it was meant to prevent. Read the headers off the success response and cool down when `remaining < 1`.

Send a compliant, honest User-Agent: `<platform>:<app-id>:<version> (by /u/<username>)`. Never spoof a browser — that is what the JSON bot wall exists to reject, and it will reject you.

## Why This Matters

The failure modes here are silent, which is what makes this worth documenting. A naive implementation of any of these mistakes *looks like it works* and then quietly returns wrong or empty results:

- **The 429 has an empty body.** If you don't detect the status and treat the body as the payload, a rate-limited request renders as "no results found" — indistinguishable from a genuinely empty search. The user sees an empty list and concludes the tool is broken or their query matched nothing. Measured burst at 10s intervals: `429, 429, 429, 429, 200, 429`. Without status handling, that reads as four empty searches, one good one, and another empty one.

- **The cooldown-timing bug bites intermittently.** Arming only on `429` passes every test where requests are spaced out, then fails in real bursty use — the hardest kind of bug to reproduce from a bug report. Reading `remaining` off the `200` is the difference between a guard that works and one that works in the demo.

- **The `"submitted by"` truncation is a data-corruption bug, not a crash.** It silently mangles the body of any post that happens to contain that phrase, and you'll never see it in a fixture that doesn't include one. Verified both cases live: a normal post strips correctly on the marker; a post containing "submitted by" in its body survives intact only if you cut on `<!-- SC_ON -->` structurally.

- **The unfiltered-entries bug pollutes results with the wrong entity type.** Subreddits appear where the user expected posts.

And the strategic point: **OAuth is not a way out of this in 2026.** An engineer hitting the 403 wall will reasonably think "I'll just register an app and use OAuth." That path is closed for new credentials (see below). Time spent trying to register a client is wasted unless you already hold a grandfathered `client_id`. The RSS feed is not a stopgap until you get OAuth working — for most external tools it is the *only* option, and it is a good one.

## When to Apply

Apply this when:

- You are building an **external** tool (Raycast extension, desktop/CLI app, browser extension backend) that reads Reddit and you do **not** hold an API credential registered before ~Nov 2025.
- You see `403` on `*.json` Reddit endpoints, or your existing `.json`-based integration suddenly started returning HTML/403.
- You need **read-only** access: search posts, search within a subreddit, search for subreddits, list feed contents. RSS covers reads well.

Do **not** reach for RSS when:

- You already hold a **grandfathered `client_id`** (an app you *registered* before the Nov 2025 cutoff — note: an old *account* does not count, only a pre-cutoff *registered app*). Then OAuth's mechanics are fine — PKCE, `installed_client` grant, `read` scope, 100 QPM — and give you higher throughput and write access. The blocker for everyone else is credential *issuance*, not the OAuth flow itself.
- You need to **write** (post, comment, vote) or need higher-than-1-req/min throughput. RSS is read-only and rate-limited. If you have no grandfathered credential, these needs are currently unmet by any anonymous path.

On the two dead ends, so nobody re-investigates them:

- **Self-service API registration is closed.** Reddit's Responsible Builder Policy (support.reddithelp.com, updated June 2026): "Approval is required… before accessing any Reddit data through our API." No personal/hobby carve-out; new `client_id`s need manual approval; personal read-only projects are the most-rejected category.
- **Devvit is not a credential source.** Reddit's in-platform app framework (Devvit) *is* self-serve, but its apps run *inside* Reddit — in the subreddit UI, modqueue, and mobile app. They call *out* to allowlisted external services (Discord, Sightengine); nothing reaches *in* to hand an external tool usable credentials. Confirmed against the r/ModSupport Devvit-apps list and a real Devvit scaffold. Do not scaffold a Devvit app expecting to extract an API key from it.

## Examples

All examples verified live against Reddit 2026-07.

### Working endpoint table

```
# Post search (returns t3_ entries; may include t5_ subreddits — filter!)
GET https://www.reddit.com/search.rss?q=<q>&limit=<n>&sort=<relevance|hot|top|new|comments>

# Search within a subreddit (correctly scoped)
GET https://www.reddit.com/r/<sub>/search.rss?q=<q>&restrict_sr=true

# Search for subreddits (returns t5_ entries)
GET https://www.reddit.com/search.rss?q=<q>&type=sr
```

Parameters verified honored: `q`, `limit` (`limit=5` → exactly 5 entries; `limit=100` → 100 entries), `sort`, `restrict_sr`, `type=sr`.

Required request header:

```
User-Agent: <platform>:<app-id>:<version> (by /u/<username>)
# e.g.  macos:com.example.redditsearch:1.0.0 (by /u/example)
```

### Parsing Atom entries

Parse with a real XML parser (e.g. `fast-xml-parser`), not a regex over the document. Relevant Atom entry fields:

- `title`
- `link` — the `alternate` `href` is the permalink
- `id` — fullname-prefixed (`t3_…` post, `t5_…` subreddit); **filter on this prefix**
- `author` — `name` and `uri`
- `updated` / `published`
- `content` — escaped HTML (the post body wrapped in Reddit chrome; see below)
- `media:thumbnail`
- `category` — the subreddit

Filtering by entity type:

```js
// A post search mixes in matching subreddits. Keep only posts.
const posts = entries.filter((e) => e.id.startsWith("t3_"));
const subs = entries.filter((e) => e.id.startsWith("t5_"));
```

### Stripping post-body chrome (cut on the marker, not the phrase)

The `content` field looks like:

```
<!-- SC_OFF --> …the real post body… <!-- SC_ON --> submitted by <a>/u/author</a> [link] [comments]
```

Cut on the `SC_ON` marker — everything before it is the body, everything after is chrome. This preserves a body that legitimately contains the words "submitted by":

```js
function extractBody(contentHtml) {
  // Drop everything from SC_ON onward (the "submitted by … [link] [comments]"
  // nav chrome). NEVER split on the bare substring "submitted by".
  const close = contentHtml.indexOf("<!-- SC_ON -->");
  return (close >= 0 ? contentHtml.slice(0, close) : contentHtml).trim();
}
```

Verified both cases: a normal post strips correctly, and a post whose body contains "submitted by" survives intact — which the naive `content.split("submitted by")[0]` approach would truncate.

### Arming the cooldown from the success response

```js
async function fetchWithRateGuard(url, headers) {
  const res = await fetch(url, { headers });

  // 429 has an EMPTY body — detect by status, do not treat body as results.
  if (res.status === 429) {
    const reset = Number(res.headers.get("x-ratelimit-reset")) || 60;
    await cooldown(reset); // wait, then let caller retry
    throw new RateLimitedError(reset);
  }

  // CRITICAL: even a 200 can report remaining: 0. Arm the cooldown NOW,
  // off the success headers, so the NEXT request doesn't earn the 429.
  const remaining = Number(res.headers.get("x-ratelimit-remaining"));
  const reset = Number(res.headers.get("x-ratelimit-reset")) || 60;
  if (!Number.isNaN(remaining) && remaining < 1) {
    scheduleCooldown(reset); // measured live: remaining:0, reset:42 on a 200
  }

  return res; // ~1 req/min/IP; measured burst: 429,429,429,429,200,429
}
```

The load-bearing line is arming the cooldown on the `200`. Without it, the guard engages one request too late and the next call takes the `429` it existed to prevent.

## Related

- Upstream bug report this explains: [raycast/extensions#28601](https://github.com/raycast/extensions/issues/28601) — "[Reddit Search]" (open), the broken-search report caused by the JSON API block.
- Fix implementing this guidance: [raycast/extensions#29703](https://github.com/raycast/extensions/pull/29703) — "[Reddit Search] Fix broken search (Reddit blocked the JSON API) + rebuild on RSS" (open as of this writing).
