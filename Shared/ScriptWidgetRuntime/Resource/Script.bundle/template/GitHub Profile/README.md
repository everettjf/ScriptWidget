# GitHub Profile

Install this template, then open ScriptWidget Settings > Service Accounts. Connect a GitHub personal access token and allow this installed widget to read the account profile. Reconnecting clears widget grants; deleting and reinstalling the widget creates a new identity and requires a new grant. No token belongs in the script, manifest, parameters or Web Studio mocks.

The template reads `$services.status("github")` and `$services.profile("github")`. It displays repository/follower counts, preserves an unshared private repository count as missing, and shows setup, expiry, rate-limit and offline states. A zero count is real data, not an error. It does not store profile data, send mutations or perform a login. Future entries and Live Activity presentations cannot query live services; prepare the display data in the current execution before composing such presentations.

Web Studio starts with a healthy sample profile. Connected Services mocks let you edit names/counts and simulate missing authorization, disconnection, expiry, rate limits or offline behavior. These samples do not connect a real account. See [Services API](../../../../../../docs/services-api.md).
