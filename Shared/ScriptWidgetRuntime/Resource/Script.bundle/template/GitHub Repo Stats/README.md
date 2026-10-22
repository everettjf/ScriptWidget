# Public repository stats

Save a public `owner/repository` and accent in Records & Configuration. The legacy `owner/repository` instance parameter is supported; JSON may override `repository` and `accent` (`blue`, `green`, `rose`). URLs, credentials and unknown settings are rejected. The package declares only `api.github.com` network access and local storage.

This template uses GitHub's public REST API without credentials. Anonymous requests share an IP-based rate limit. It uses at least a one-hour cache, conditional Last-Modified requests where supplied and retry backoff. HTTP 403/429 shows a rate-limit state, not invented zeros. A missing/deleted/private repository (404) discards its old displayed counts. Invalid bodies, unexpected repository names, private payloads and invalid counts are never accepted as current data.

Offline cached values are labelled with the time last received or validated; counts older than seven days are unavailable. The cache holds at most four repositories. Daily star history is created only from successful payloads, using UTC day buckets, replacing the latest check on the same day and retaining fourteen recorded days. Missing days are not filled. The graph appears after two recorded days; its categories are actual check dates. It is not a reconstruction of historical GitHub counts. GitHub's `open_issues_count` includes issues and pull requests, so the card labels it “Issues + PRs”.

The template never requests an access token. Private repositories and authenticated services require a separate native credential capability, not a token pasted into this package. Record backups contain configuration only; transient counts and their history are excluded. Future timeline entries may display the cache but cannot request data or modify storage. Widget refresh remains system scheduled.

Web Studio defaults and the bundled preview contain explicitly synthetic sample counts. They do not claim the real repository has these counts.

GitHub guidance: https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api and https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api. Conditional requests are not universally free of rate limits; do not infer an authenticated quota from this anonymous template.
