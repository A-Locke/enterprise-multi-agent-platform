# ADR-0006: Managed identity + federated credential for the Copilot Studio connector, not a client secret

## Status

Accepted

## Context

Milestone 3 wires Copilot Studio to the platform API as a custom-engine-agent: a Power
Platform custom connector calls `/agent/chat` through APIM. For the per-user App Role
authorization we built in Milestone 1 (Admin / Agent.User / Auditor) to keep working through
Copilot Studio, the connector needs to call the API **as the signed-in user**, not as a
generic service identity — otherwise every Copilot Studio caller would look identical to the
API regardless of who's actually chatting, and the RBAC model built in Milestone 1 would be
bypassed rather than extended.

That requirement points at OAuth 2.0 delegated authorization (Microsoft Entra ID identity
provider) on the custom connector — the standard, documented pattern for this. The
conventional setup for this ("OAuthAAD" connector template) expects a **client secret**:
a confidential-client credential Power Platform's OAuth broker uses server-side to complete
the authorization code exchange. That would be the first stored secret anywhere in this
project — everything else (API auth, Container App → ACR, Container App → Azure OpenAI) is
managed-identity or public-client, zero stored credentials, per the security model
established since Milestone 1.

Microsoft has since added an alternative: custom connectors can use **managed identity**
instead of a client secret for this exact delegated-auth scenario (documented, GA as of the
April 2026 revision of Microsoft's custom-connector AAD-auth guide). The connector gets its
own system-assigned identity; that identity is added as a **federated credential** on our
existing Entra app registration (the same workload-identity-federation pattern already
planned for GitHub↔Azure OIDC in `manual-setup.md` #7, applied here to a different trust
relationship). No secret is created, stored, or rotated anywhere.

Constraint: this requires the app registration to be single-tenant. Ours already is
(`--sign-in-audience AzureADMyOrg` when created in Milestone 1) — no change needed there.

## Decision

Use the **managed identity + federated credential** path, not a client secret:

1. Reuse the existing "Enterprise Multi-Agent Platform API" app registration as both the
   connector's client and the protected resource — no new app registration needed. The
   managed-identity trust relationship doesn't require the traditional public/confidential
   client split a client-secret-based setup would have pushed toward.
2. Create the custom connector via `pac connector create` (scripted:
   `scripts/setup-copilot-connector.ps1`), using the `aad` identity provider template.
3. **Manual, portal-only** (no API surface for this exists): switch the connector's Security
   tab from client-secret to the managed-identity option, then retrieve the generated
   issuer/subject identifier strings.
4. Add those as a federated credential on the app registration (`az ad app
   federated-credential create` — scriptable once the issuer/subject values are known) and
   add the connector's generated redirect URI to the app's registered redirect URIs
   (`az ad app update`, also scriptable once the connector exists).
5. First-time user consent (creating a **Connection** from the connector) is still an
   interactive sign-in click — inherent to delegated OAuth, not something either credential
   approach avoids.

## Consequences

**Positive:**
- Zero stored secrets for this integration, consistent with every other integration point in
  the project. Nothing to rotate, nothing that can leak.
- No new app registration — one fewer identity to track, document, and secure.
- The federated-credential pattern here is a second real application of workload identity
  federation in this project (the first being planned for CI/CD OIDC), reinforcing it as a
  deliberate architectural pattern rather than a one-off.

**Negative / accepted trade-offs:**
- The managed-identity option is newer and less documented than the client-secret path —
  fewer troubleshooting resources if something goes wrong with it specifically.
- Genuinely portal-only for the "switch to managed identity" toggle and reading the
  issuer/subject values — no CLI/API surface found for this step, unlike almost everything
  else automated in this project. Documented in `manual-setup.md`.
- Connector definition/properties files are templated with placeholders
  (`power-platform/solutions/connectors/platform-api/*.template.json`) rather than committed
  with real values, consistent with the project's real-values-only-in-`.env` discipline —
  adds one generation step (`scripts/setup-copilot-connector.ps1`) most connector tutorials
  don't need, since they assume hardcoding real values directly.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle
- `docs/security-model.md` — Identity section, "no client secrets" posture
- `manual-setup.md` #7 (GitHub↔Azure OIDC) — the earlier, analogous use of federated credentials
- `scripts/setup-copilot-connector.ps1`, `power-platform/solutions/connectors/platform-api/`
