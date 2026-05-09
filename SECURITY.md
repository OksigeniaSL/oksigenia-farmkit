# Security policy

## Supported versions

Only the latest minor release receives security fixes. Older `0.x` lines are abandoned as soon as a newer one is published.

| Version    | Supported |
| ---------- | --------- |
| `0.1.x`    | ✅        |
| `< 0.1.0`  | ❌        |

## Reporting a vulnerability

**Do not open a public GitHub issue for security problems.**

Send a private report via [GitHub Security Advisories](https://github.com/OksigeniaSL/oksigenia-farmkit/security/advisories/new). Include:

- A description of the issue and a minimal reproduction.
- The version where you observed it.
- Any known mitigations.

Acknowledgement target: 5 working days.
Initial assessment target: 15 working days.

If you have not received an acknowledgement within 10 working days, you may follow up by opening a public issue stating only that a private report was filed and is awaiting response (no details).

## Scope

In scope:

- Code execution via crafted save data (deserialization).
- Logic flaws that allow data corruption inside a saved farm state.
- Dependency vulnerabilities surfaced by `flutter pub outdated`.

Out of scope:

- Issues that require a malicious host app already controlling the device.
- Theoretical attacks against `MockWeatherProvider` (it is deterministic by design and not security-relevant).
- Performance / DoS reports against the example (it is illustrative, not production).

## Disclosure

Once a fix is available, the advisory is published with credit to the reporter unless they request anonymity.
