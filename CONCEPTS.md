# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Reddit data access

### Atom feed (RSS)
Reddit's public, unauthenticated `.rss` endpoints (e.g. `search.rss`, `r/<sub>/search.rss`) that return search and listing results as Atom XML. As of 2026 this is the only unauthenticated surface still serving Reddit data — the `.json` equivalents are blocked for anonymous callers. Read-only and rate-limited.

### Fullname prefix
Reddit's type tag on an object's id: `t3_` marks a post (link/self submission), `t5_` marks a subreddit (and `t1_` a comment, `t2_` a user). A single search response can mix types — a post search returns matching subreddits alongside posts — so consumers filter by this prefix to keep the intended entity type.

### Grandfathered client_id
An OAuth API application registered **before** Reddit's ~November 2025 self-service shutdown, whose credentials still authorize API access. The distinction is the *app registration date*, not the account age — an old Reddit account with no pre-cutoff registered app has no grandfathered access. After the cutoff, new registrations require manual approval.

### Responsible Builder Policy
Reddit's policy (in force since ~November 2025) requiring explicit prior approval before any new client accesses the Data API, with no personal or hobby carve-out. It is why self-service OAuth credential issuance is closed to new external tools, and why unauthenticated reads fall back to the Atom feed.

### SC markers
The `<!-- SC_OFF -->` / `<!-- SC_ON -->` HTML comments Reddit wraps around the real body of a post in its feed `content`. The submission body sits between the markers; the "submitted by … [link] [comments]" navigation chrome is appended after `SC_ON`. Body extraction cuts on these markers structurally rather than on the literal phrase "submitted by", which can appear in legitimate post text.

## Raycast platform

### Command process isolation
Each command in a Raycast extension runs in its own operating-system process, so module-level variables and reactive framework state are private to one command and are never shared with another. State that must be honored across commands (a rate-limit cooldown, for example) has to live in the shared Raycast cache, and any *correctness gate* that reads it must read synchronously at the decision point — reactive/cached copies of that state lag across process boundaries and are safe only for display.
