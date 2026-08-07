# ADR-0013: Combined release process — Azure OIDC and Power Platform Build Tools

## Status

Accepted

## Context

Milestone 9 closes out ALM & Governance: this platform has two genuinely separate deployment
surfaces (Azure infra/app via `azd`, Power Platform solution via `pac`), and per ADR-0001's
Microsoft Platform Evaluation principle, each gets its own native CI/CD story rather than being
forced into one pipeline that pretends Power Platform is "just another Azure resource."

Two real gaps existed going in:
- GitHub Actions → Azure had no federated OIDC trust configured (`ci.yml` had carried a
  comment flagging this since Milestone 0/1 — see `manual-setup.md` #7).
- The Power Platform solution (ADR-0012) had a manual pack/import script
  (`deploy-business-data-solution.ps1`) but no CI validation and no promotion pipeline —
  only one Dataverse environment existed, so there was nowhere to "promote" to.

## Decision

**Azure side**: `azd pipeline config` provisions a User-Assigned Managed Identity
(`msi-enterprise-multi-agent-platform`, its own resource group `rg-<project>-msi`, separate
from `infra/main.bicep`) with GitHub OIDC federated credentials — no stored Azure secret.
`.github/workflows/azure-dev.yml` runs on `workflow_dispatch` only (this project's established
practice is deliberate, reviewed deployments — see the workflow's own header comment — not
silent auto-deploy-on-push, which is `azd`'s generated template default). `ci.yml` gained a
`validate-deploy` job running `azd provision --preview` (a what-if-style check) on every PR and
push to `main`, using the same OIDC identity scoped down for read/validate.

**Power Platform side**: rather than stopping at structural-only CI validation, a second,
genuinely free Dataverse environment (`test-em-3b9dc26e`, via a second Power Apps Developer
Plan signup — the same free, no-billing path as the first environment in ADR-0004) gives this
project a real dev→test promotion target. A dedicated Entra app registration
(`sp-enterprise-multi-agent-platform-pp-pipeline`) is registered as a **Dataverse Application
User** (`pac admin assign-user --application-user`) with System Administrator in both
environments, authenticating via client-credentials (secret in Key Vault + a GitHub secret,
never in source). `.github/workflows/ci.yml` gained a `validate-power-platform-solution` job
(pack → unpack roundtrip, no live credentials needed, runs on every PR touching
`power-platform/solutions/**`) and a new `.github/workflows/power-platform-deploy.yml`
(`workflow_dispatch`-only, matching the Azure side's practice) packs the solution **Managed**
and imports it into the test environment via `microsoft/powerplatform-actions`.

Dev stays on **Unmanaged** solutions (components remain editable via the maker portal, per
Microsoft's standard ALM guidance); test receives **Managed** packages. The committed solution
source declares `<Managed>0</Managed>` (matching the existing unmanaged dev-import script
unchanged); the deploy pipeline flips that flag to `1` on a throwaway copy at pack time, never
in the committed source — the `_managed.xml` sibling files needed to pack either type were
captured once via `pac solution unpack --packagetype Both`.

## What actually happened setting this up

Both halves required substantial live debugging before either pipeline actually worked —
worth recording in full since none of these were guessable from documentation alone, and each
was confirmed via a live re-run rather than assumed fixed:

**Azure OIDC, in the order hit:**
1. A bulk GitHub Secrets migration script (moving several config values from unmasked
   Variables to masked Secrets, itself a fix for a separate exposure risk) silently set
   multiple secrets — including `AZURE_TENANT_ID` and `AZURE_CLIENT_ID` — to a literal `-`
   character instead of their real values. The corruption was only obvious once two of them
   broke auth outright; the rest (`AZURE_ENV_NAME`, `AZURE_LOCATION`, `AZURE_SUBSCRIPTION_ID`,
   and others) stayed silently wrong until a later step's failure prompted checking all of
   them. One side effect: GitHub's log masking replaces *every* occurrence of a registered
   secret's exact value anywhere in a run's log — a secret whose value was `-` meant every
   hyphen in every log line (timestamps, unrelated GUIDs, flag names like `--tenant-id`)
   rendered as `***`, which is what made the logs unreadable at first glance and, in
   hindsight, was itself a clue something was wrong well before the actual cause was found.
2. GitHub now presents OIDC subject claims using an "immutable ID" format
   (`repo:OWNER@ownerId/REPO@repoId:ref:...`) that didn't match the federated credential
   `azd pipeline config` created (`repo:OWNER/REPO:ref:...`). Fixed by adding a second
   federated credential with the immutable-ID subject, for both the `main` ref and
   `pull_request` events (the latter needed for `ci.yml`'s what-if job).
3. `azd env new` in a fresh CI job does not inherit `AZURE_SUBSCRIPTION_ID`, `AZURE_LOCATION`,
   or a resolvable "current principal id" from process environment variables alone — even
   though `${VAR}` substitution in `infra/main.parameters.json` reads process env directly.
   `azd`'s own environment state needs these passed explicitly (`azd env new --subscription
   ... --location ...`) or set (`azd env set AZURE_PRINCIPAL_ID ...`), or `azd provision`
   fails resolving the current principal against an empty subscription segment.
4. `Contributor` (the role `azd pipeline config` grants the pipeline identity) does not
   include `Microsoft.Authorization/roleAssignments/write` — by design, Azure RBAC separates
   resource management from access management. The Bicep templates wire up RBAC between
   resources (Container App → OpenAI, AI Search → Storage), so the pipeline identity also
   needs `Role Based Access Control Administrator`, scoped to the app's resource group only
   (not subscription-wide — least privilege, since this pipeline never deploys outside it).
5. `azd deploy` needs `AZURE_CONTAINER_REGISTRY_ENDPOINT` as an exact-name environment
   variable — not a Bicep output it reads automatically, `azd`'s own convention duplicating
   the `ACR_LOGIN_SERVER` Bicep output specifically because its deploy tooling doesn't consult
   arbitrary Bicep outputs for this value. Same explicit-`azd env set` treatment as above.

**Power Platform Build Tools, in the order hit:**
1. The Application User needed `pac admin self-elevate` in the *new* test environment before
   `pac admin assign-user` would work at all — the tenant's Global Administrator (used for all
   `pac admin` operations) only had a Dataverse security role in the *original* dev
   environment (auto-granted there by the Developer Plan self-service signup); a
   manually-provisioned environment doesn't auto-grant that.
2. `pac solution pack --packagetype Managed` fails against source unpacked as Unmanaged-only
   (`Solution package type did not match requested type`) — packing either type from the same
   source requires the source to have been unpacked with `--packagetype Both` (two `pac
   solution export` calls, one managed and one unmanaged, unpacked into the same folder — the
   **second** unpack pass must run with `--allowDelete false`, or it deletes the first pass's
   files it considers "unnecessary" from its own single-type perspective).
3. A GitHub secret set via `az keyvault secret show ... | gh secret set ... --body -` produced
   an `AADSTS7000215: Invalid client secret` error despite the underlying value being verified
   correct moments earlier via a direct OAuth2 client-credentials test — the same class of pipe
   corruption as the Azure secrets above. Fixed by capturing the value into a shell variable
   first rather than piping directly.
4. `microsoft/powerplatform-actions/import-solution@v1`'s input is named `solution-file`, not
   `path` (the latter fails silently as an "unexpected input" warning, then a confusing
   `Input required and not supplied: solution-file` error).
5. A cold-start import into the new environment failed on `Some dependencies are missing`,
   naming the Admin Console app module as both the required and dependent component — Dataverse
   embeds a `<MissingDependencies>` snapshot directly in `Solution.xml` at export time,
   reflecting whatever platform-package versions (icons, app-framework settings) were present
   in the *source* environment; that snapshot replays as a real check on every import instead
   of being informational. Documented Microsoft workaround: clear the element's contents in the
   committed source, keeping the empty parent tags.
6. After clearing that snapshot, the *actual* remaining error was more specific: `App Module
   import failed because Sitemap with Unique Name crba7_PlatformAdminConsole doesn't exist in
   system` — the Admin Console app's SiteMap had never been added to the solution as its own
   explicit component (type 62) in the first place, only its AppModule (type 80). It worked
   fine importing into dev only because the sitemap already existed there outside the solution
   package. Fixed for real (not just papered over) via the Dataverse `AddSolutionComponent`
   Web API action, then re-captured through export/unpack.

## Consequences

**Positive:**
- Both release paths are genuinely verified working end-to-end via live re-runs — a real
  Container App image built and deployed via OIDC, a real managed solution confirmed present
  (`ismanaged: true`) in the test Dataverse environment — not just "the workflow file looks
  right."
- The second Dataverse environment is free (Power Apps Developer Plan, same no-billing path as
  the first), so this cost nothing to add and gives Power Platform ALM a genuine promotion
  target instead of a single-environment stand-in.
- Every fix above was root-caused against real server responses (HTTP status codes, ARM/Graph
  error bodies, Dataverse dependency XML) rather than pattern-matched from memory — consistent
  with this project's established debugging practice.

**Negative / accepted trade-offs:**
- Both pipelines now hold standing credentials with real write access (the Azure MSI has
  Contributor + RBAC Administrator on `rg-dev`; the Power Platform service principal has
  System Administrator in both Dataverse environments) — more surface to rotate and, at
  project teardown, more to explicitly delete rather than assume expires on its own.
- The Power Platform promotion pipeline only proves itself against `test-em-3b9dc26e`; there is
  still no Prod-tier environment, so "promotion pipeline" currently means dev → test, not a
  full three-stage story. Extending it would repeat this ADR's pattern (new environment, new
  Application User assignment) rather than needing new mechanism.
- This ADR is the first one built almost entirely from live incident diagnosis rather than an
  upfront design choice — a fair reflection of what "wire up CI/CD for an enterprise-native
  platform" actually costs in practice, not just what the two `workflow_dispatch` YAML files
  suggest on their own.

## References

- [ADR-0001](0001-microsoft-platform-evaluation.md) — Microsoft Platform Evaluation principle
- [ADR-0004](0004-single-tenant-new-user.md) — the Power Apps Developer Plan free-environment
  pattern reused for the test environment
- [ADR-0012](0012-dataverse-business-data.md) — the business-data solution this pipeline
  promotes
- `manual-setup.md` #7 — the original OIDC verification gap this ADR closes
- `.github/workflows/azure-dev.yml`, `.github/workflows/power-platform-deploy.yml`,
  `.github/workflows/ci.yml` — the actual pipeline definitions
