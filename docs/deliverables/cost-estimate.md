# Cost Estimate: Portfolio Build vs. Production Scale

See [`docs/cost-analysis.md`](../cost-analysis.md) for the full per-resource breakdown of
*this project's actual spend* ($0.39 through Milestone 10, against a $180 monthly guardrail).
This document answers the different question a client would actually ask: **what would this
architecture cost run for real?**

## Why the numbers are so different

Every free-tier choice in this build was deliberate and documented, and every one of them has
a real, known production-tier alternative:

| Component | Portfolio build | Production equivalent | Why the jump |
|---|---|---|---|
| Azure Container Apps | `minReplicas: 1`, 0.5 vCPU / 1 GiB | Multiple replicas, autoscale, larger SKU | Real user load needs horizontal scale and headroom this build never needed to prove |
| Azure API Management | Consumption tier | Standard/Premium tier (~$700–$3,000+/month) | Consumption has no SLA and limited throughput ceiling; enterprise APIs need the VNet integration, multi-region, and higher throughput Standard/Premium provide |
| Azure AI Search | Free F0 (50 MB, 3 indexes, no SLA) | Basic/Standard tier (~$75–$250+/month) | F0 has a hard storage ceiling and zero SLA — unusable past a small demo corpus |
| Azure OpenAI | `GlobalStandard`, on-demand pay-per-token | Provisioned Throughput Units (PTU) for predictable latency at volume | Pay-per-token has no throughput guarantee under load; PTU pricing is a substantial fixed monthly commitment but buys predictability |
| Dataverse | Developer Plan (free, non-production, single-user) | Production Dataverse capacity (storage + database capacity add-ons, licensed per user) | Developer Plan is explicitly non-production-licensed — a real deployment needs paid Power Apps/Power Automate per-user or per-app licensing plus Dataverse capacity |
| Copilot Studio | Free trial (build/test only) | Pay-as-you-go message capacity or a Copilot Studio-inclusive M365 license tier | Publishing to real users at volume consumes paid message credits, not just build/test |
| Log Analytics / App Insights | ~5 GB/month free ingestion | Real ingestion volume at production traffic, likely tens of GB/month | Free tier ingestion is far below what real request/dependency tracing generates at scale |

## A directional production estimate

For a mid-size internal deployment (a few hundred active users, moderate daily conversation
volume) rather than this project's demo scale, expect the *floor* to be in the **low
thousands of USD/month**, dominated by three lines: APIM Standard/Premium, Azure OpenAI
provisioned throughput (if latency SLAs matter) or sustained pay-per-token spend at real
volume, and Power Platform per-user/per-app licensing. Everything else in this architecture
(Container Apps, AI Search Basic, Content Safety, Dataverse capacity) is a smaller, more
predictable increment on top of those three.

This is a **directional** estimate, not a quote — actual numbers depend on region, committed-use
discounts, exact licensing tier, and real usage patterns that don't exist for a portfolio
build. The right next step for a real engagement is the
[Azure pricing calculator](https://azure.microsoft.com/pricing/calculator/) against actual
projected load, plus a Power Platform licensing conversation with Microsoft or a licensing
partner — both explicitly out of scope for this document.

## What doesn't change with scale

Notably, the *architecture* itself doesn't need to change to go from this build to production
scale — every component here is the same Azure/Power Platform service, just at a higher SKU
tier or licensing plan. That's the point of evaluating Microsoft-native services throughout:
there's no "now rip this out and rebuild it properly" step hiding in the transition from demo
to production, which is not something a custom pro-code equivalent could promise as cleanly.
