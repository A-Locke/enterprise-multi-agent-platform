# Assumptions and Constraints

## Assumptions

- **Single tenant, single subscription.** Azure resources and Power Platform/Dataverse share
  one Microsoft Entra tenant ([ADR-0004](../adr/0004-single-tenant-new-user.md)) — no
  cross-tenant identity federation. A real enterprise engagement might need to bridge an
  existing corporate tenant instead; the identity model here (Entra App Roles mirrored as
  Dataverse security roles) generalizes to that case without redesign.
- **Portfolio/demo scale, not production load.** Sizing (Container Apps `minReplicas: 1`,
  AI Search Free F0, Dataverse Developer Plan) assumes light, intermittent traffic. See
  [`cost-estimate.md`](cost-estimate.md) for what production-scale sizing would actually cost.
- **No real compliance requirement drove any decision.** Where a choice had a compliance
  dimension (e.g., `GlobalStandard` vs `DataZoneStandard` Azure OpenAI quota — no EU data
  residency guarantee), the lower-friction option was taken because nothing forced otherwise.
  A regulated engagement would need to revisit every such choice explicitly.
- **One person, one machine.** No team-based development workflow (branch protection, PR
  review gates, multiple contributors) was exercised — the CI/CD pipelines are real and
  working, but the human process around them (who approves a deploy, who reviews a PR) was
  never tested at team scale.

## Constraints (real, hit during the build — not hypothetical)

- **Power Platform environment creation had a region-picker quirk.** `pac admin create` and
  the quick-create panel both rejected every region string tried for this tenant's rollout
  group; the full admin-center wizard's Region dropdown was the only reliable path. Affects
  any tenant in the same "macro region geography" rollout — see `manual-setup.md` #3.
- **Azure OpenAI quota is model/SKU-specific, not just subscription-wide.** `gpt-5-mini` had
  zero default quota under `DataZoneStandard` but 500 under `GlobalStandard` on this
  subscription — check `az cognitiveservices usage list` before assuming a SKU is available,
  not just that the model itself is listed.
- **Some Copilot Studio consent/permission-card UI is preview-quality.** The Outlook
  connector's consent card failed to render or re-prompted repeatedly across three distinct
  investigation attempts (interactive mode, Maker mode, direct child-agent Preview) —
  concluded as an OAuth-grant-persistence issue in the platform, not something fixable from
  this project's side. Documented, not silently worked around.
- **`pac` CLI authentication has two different strength requirements.** Environment-scoped
  operations (`pac solution import`) work with a standing auth profile; tenant-admin-scoped
  operations (`pac admin`, `pac solution export`) periodically demand fresh interactive MFA
  re-authentication, even mid-session. Any automation involving `pac admin` should expect
  this, not treat it as a one-time setup cost.
- **GitHub's OIDC subject claim format is not fixed.** GitHub has moved to an "immutable ID"
  subject format (`repo:owner@id/repo@id:...`) that a federated credential created against
  the plain `repo:owner/repo:...` format silently fails to match — see
  [ADR-0013](../adr/0013-combined-release-process.md). Any OIDC-based pipeline should account
  for both formats existing simultaneously on the identity provider side.
- **`azd`'s CI behavior differs from its interactive/local behavior** in ways that aren't
  obvious from the docs — environment state (`AZURE_SUBSCRIPTION_ID`, `AZURE_PRINCIPAL_ID`)
  isn't inherited from process environment variables the way `${VAR}` substitution in
  parameter files is; it needs explicit `azd env set` calls. See ADR-0013 for the full chain.
- **This project's out-of-pocket ceiling ($20, [ADR-0002](../adr/0002-cost-policy.md)) was
  never actually approached** ($0.39 total Azure spend through Milestone 10) — a constraint
  that turned out not to bind, worth noting so it isn't mistaken for evidence the platform is
  inherently this cheap at any scale. See [`cost-estimate.md`](cost-estimate.md) for the
  production-scale picture, which is a very different number.
