# ADR-0007: Client secret (Key Vault-backed) for the Copilot Studio connector, superseding ADR-0006

## Status

Accepted

## Context

[ADR-0006](0006-copilot-connector-managed-identity.md) chose managed identity + federated
credential for the Copilot Studio connector's OAuth delegated auth, specifically to avoid
this project's first stored secret. In practice that path didn't hold up:

- The managed-identity option is labeled **"Managed Identity (Preview)"** in Microsoft's own
  current documentation — an undocumented, no-CLI-surface preview feature, exactly as
  ADR-0006 already flagged as a risk at the time.
- The maker portal's current UI for our connector doesn't surface a Security tab at all —
  the screen ADR-0006's entire plan depended on for reading back the redirect URL and
  managed-identity issuer/subject values isn't reachable the way Microsoft's docs describe.
- A prior attempt to reach the managed-identity toggle through a different portal flow
  deleted the connector outright when the operation failed, rather than failing safely and
  leaving the connector in its previous state. Re-checked via `pac connector list` after —
  confirmed gone, not just misconfigured.

Given the connector needs to be recreated regardless, and the managed-identity surface isn't
reliably reachable right now, this ADR evaluates the standard, documented alternative:
client-secret-based OAuth (the "OAuthAAD" template Microsoft's own tutorial walks through),
with the secret **stored in Key Vault** rather than pasted only into the Power Platform
connector config — so it has a system-of-record, can be rotated centrally, and isn't a
plaintext value that exists nowhere else to audit.

This is a deliberate, documented trade-off against this project's established
zero-stored-secrets posture (Milestone 1 API auth, Container App → ACR, Container App →
Azure OpenAI are all managed-identity/public-client with nothing to rotate) — the first
exception, made because the zero-secret path for this specific integration point isn't a
mature, reliable platform capability yet, not because the reasoning behind avoiding secrets
changed.

## Decision

1. Reuse the existing "Enterprise Multi-Agent Platform API" app registration (unchanged from
   ADR-0006) — only the connector's auth mechanism changes, not the identity model.
2. Create a client secret on the app registration (`az ad app credential reset --append`),
   store it in the existing Key Vault (`<KEY_VAULT_NAME>`, provisioned since Milestone 0 and
   otherwise unused) as a named secret, not in `.env` or any file that could be committed.
3. Grant the local dev principal `Key Vault Secrets Officer` on the vault (the same RBAC
   pattern already used for Azure OpenAI in Milestone 2) so the secret can be written and
   later read back for connector generation without broadening access beyond what's needed.
4. Recreate the connector via `pac connector create` now that it's gone (`apiProperties.json`
   unchanged in shape from ADR-0006 — client ID, scopes, tenant, resource ID, no secret
   field). Confirmed against Microsoft's own certified-connector examples
   (`microsoft/PowerPlatformConnectors`) that the `aad` identity provider's connector-level
   schema has no `clientSecret` field at all, matching what the original tutorial already
   showed: the secret is entered directly into the connector's Security tab in the maker
   portal, not templated into the connector definition. This one step stays manual — read
   the value from Key Vault (`az keyvault secret show`, run locally, never pasted into chat
   or a file) and paste it into the portal.
5. First-time user consent (creating a Connection) is still an interactive sign-in click —
   unchanged from ADR-0006, inherent to delegated OAuth regardless of credential type.

## Consequences

**Positive:**
- Uses the standard, fully-documented Microsoft custom-connector auth path — far more
  troubleshooting material available than the preview managed-identity option.
- The secret's system of record is Key Vault, not a value that only ever existed as
  something someone once typed into a portal field and can no longer find — when it needs
  rotating, the new value comes from Key Vault, not from re-deriving it from scratch.
- Unblocks Milestone 3 without waiting on a Microsoft preview feature to stabilize.

**Negative / accepted trade-offs:**
- This project's first stored secret. Needs rotation before its 1-year expiry — tracked the
  same way any operational credential would be, not swept under the rug.
- Key Vault read access for connector regeneration is one more local RBAC grant to maintain,
  on top of the Azure OpenAI one from Milestone 2.
- If Microsoft's managed-identity option matures (documented CLI surface, stable portal UI),
  revisiting this ADR to move back is a reasonable future item — not attempted now given
  effort-vs-payoff for a project at this scope.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle
- [ADR-0006](0006-copilot-connector-managed-identity.md) — superseded managed-identity decision
- `docs/security-model.md` — Identity section, now documents this one exception to the
  no-client-secrets posture
- `scripts/setup-copilot-connector.ps1`, `power-platform/solutions/connectors/platform-api/`
