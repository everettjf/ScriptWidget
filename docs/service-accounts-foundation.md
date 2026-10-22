# Native service account foundation

Status: M4 development. This increment supplies native credential, PKCE, owner-grant and request-plan types. Connection settings, the network executor, refresh/revocation coordination, durable playback receipts, public runtime APIs, music adapters, templates and Web mocks still need integration. No service global is available to scripts yet.

Credentials are stored in a dedicated service-only Keychain group shared by the app and widget extension. The app-specific default group remains first in each entitlement list, preserving the existing AI credential boundary. The runtime accepts only the signed group configured in the native bundle, with the fixed service-group suffix; an unresolved build variable, missing group or AI/default group fails closed. macOS uses the Data Protection Keychain. Items are device-only, non-synchronizing and available after first unlock; reads do not present an authentication dialog. A locked or unavailable Keychain is an error rather than an empty account list. Real sharing requires a properly signed build and has not yet been tested on a physical device.

Credential envelopes are versioned, bounded to 16 KiB and tied to a service, local account UUID, credential revision and native OAuth client. Token strings cannot contain header injection. Spotify expiry is bounded relative to issue time, and refresh cannot change account, client or granted scopes. Unknown fields/versions and malformed stored records are rejected. Credential and request descriptions are redacted; no credential object or raw request is exported to JavaScript or stored in package files, UserDefaults, app-group snapshots or AI context.

The Spotify authorization session uses system randomness, PKCE S256, a five-minute lifetime and the exact native callback URI. It rejects wrong origins, paths, state, duplicate parameters and replay. A shared session can redeem only one callback, including concurrent deliveries. Codes/verifiers and refresh tokens go only in form-encoded POST bodies to the fixed Spotify token endpoint; they are not URL query parameters. The connection UI must obtain its client configuration from the trusted native application, not imported widgets or plugins. Spotify deployment still depends on an appropriately registered application and its [quota/access requirements](https://developer.spotify.com/documentation/web-api/concepts/quota-modes); this foundation is not evidence of production eligibility. The protocol follows [Spotify's PKCE flow](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow).

A separate Keychain access-policy item holds the account/connection, revision and up to 32 owner grants. New connections grant no widget access. Grants use the native storage owner UUID, never a package name or public manifest ID. They list concrete operations, cannot cross accounts/services, reject stale edits and can be revoked. App-group status/cache files do not authorize outgoing requests. The future bridge must construct owner, action and network facts from the current native execution snapshot and validated package manifest.

Fixed operation plans currently describe these first-party requests:

| Operation | Method and path | Required Spotify scope |
| --- | --- | --- |
| `github.profile` | `GET api.github.com/user` | — |
| `spotify.profile` | `GET api.spotify.com/v1/me` | `user-read-private` |
| `spotify.playback` | `GET api.spotify.com/v1/me/player` | `user-read-playback-state` |
| `spotify.pause` / `spotify.resume` | `PUT …/player/pause` / `…/player/play` | `user-modify-playback-state` |
| `spotify.next` / `spotify.previous` | `POST …/player/next` / `…/player/previous` | `user-modify-playback-state` |

The builder verifies the private owner grant, service/account/connection, provider scopes, network permission and every service host. Spotify also needs the token-refresh host allowed. Writes additionally require a native user action and a stable request UUID. A request plan alone does not implement durable replay prevention: the receipt layer must be connected before exposing writes. Redirect denial, response budgets, field extraction, secret-echo rejection and delivery-time revocation/identity checks belong in the executor and are still pending. Arbitrary authenticated URLs, headers and request bodies are not accepted by these plans. Data Source Plugin 1.0 remains a declarative, unauthenticated HTTPS mapping.

GitHub requests pin API version `2026-03-10`. Its [authenticated-user endpoint](https://docs.github.com/en/rest/users/users#get-the-authenticated-user) permits fine-grained tokens without additional permissions; optional private response fields depend on the token's authorization. The future profile adapter must keep missing private counts distinct from zero and omit unrelated sensitive fields.

`node Scripts/test-service-authorization.mjs` runs the same native implementation and XCTest methods without launching an app. Its 24 cases use an in-memory Keychain and fixed sample tokens; they make no network requests and do not prove real service login or signed Keychain sharing. The tests are also compiled into both native test targets, and the probe is included in `Scripts/release-readiness.sh`.
