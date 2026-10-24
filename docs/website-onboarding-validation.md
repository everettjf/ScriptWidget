# Website first-widget experience

This delivery is limited to four improvements: two primary homepage actions,
three readable native template examples, copyable Creator setup/prompt text,
and a first-visit Studio shortcut to existing Gallery templates. No native App,
CLI, runtime, package format, template source, or storage behavior changed.

The Studio banner appears only when this load created the initial browser draft.
Opening an example previews its existing Gallery entry; creating a copy preserves
the original draft. Returning browsers retain their chosen project and do not get
the first-visit banner. Incoming Agent preview links keep their existing flow.

## Verification

`node Web/studio/scripts/onboarding-smoke.ts` checks both homepage actions,
all three image loads, 390 px page overflow, exact multiline clipboard payloads,
clipboard-denial fallback, all three starter queries, creation of a separate
copy, existing draft preservation, persisted selection after reload, and reset
of the generic Gallery filter. It is included in `release-readiness.sh`.

The existing Linux/Windows Chromium, Firefox and WebKit matrix also exercises
the first-visit shortcut and verifies its removal after importing a package.
The broader existing persistence, automatic Agent handoff, layout, export and
browser-preview tests remain enabled. Exact completed release-gate and deployment
runs are recorded in the delivery PR.

## Visual review

- [Before homepage](images/creator-home-after.png)
- [After homepage, desktop](images/website-onboarding/home-desktop.png)
- [After homepage, 390 px phone](images/website-onboarding/home-mobile.png)
- [Studio first visit, light appearance](images/website-onboarding/studio-starter.png)

Homepage screenshots are unedited native renders of our built-in templates;
[render inputs](../site/assets/examples/README.md) document their sample data.
