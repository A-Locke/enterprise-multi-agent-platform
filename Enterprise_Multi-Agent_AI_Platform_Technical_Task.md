# Technical Task: Enterprise Multi-Agent AI Platform

## Objective

Design and implement an enterprise-grade AI platform suitable for a
medium or large organization. The emphasis is on production-quality
architecture, maintainability, security, observability, extensibility,
and clear documentation rather than building a quick prototype.

The implementation should be modular and capable of demonstrating
solution architecture, AI orchestration, enterprise integrations,
governance, and operational readiness.

## General Requirements

-   Produce clean, maintainable, production-quality code.
-   Favor modular architecture and separation of concerns.
-   Configuration should be environment-driven.
-   All implementation decisions (frameworks, libraries, services,
    patterns, etc.) are left to the engineering agent unless explicitly
    constrained below.
-   Infrastructure should be defined using **Bicep** wherever supported.
-   Prefer automation over manual configuration.
-   Treat the project as something that could realistically be delivered
    to an enterprise customer.

## Functional Goals

Implement an enterprise AI platform that: - Supports authentication and
authorization. - Supports role-based access. - Supports multiple
specialized AI agents coordinated by an orchestration layer. -
Integrates with enterprise systems. - Supports knowledge retrieval over
enterprise documentation. - Includes an administrative interface for
configuration and operations. - Persists required business data. -
Includes monitoring, logging, auditing, and error handling. - Is
structured for future expansion.

## Non-Functional Requirements

-   Modular architecture.
-   Security-first design.
-   Reusable components.
-   Configuration-driven behavior.
-   Automated testing where practical.
-   CI/CD-ready repository structure.
-   Enterprise coding standards.
-   Graceful error handling.
-   Cost-conscious implementation.

## Azure Requirements

The solution should make appropriate use of Azure services where
beneficial.

Requirements: - Provision Azure infrastructure using **Bicep**. -
Minimize manual Azure configuration. - Use managed identities and secure
secret management where appropriate. - Ensure resources are suitable for
development and portfolio-scale cost. - Document the estimated monthly
running cost of Azure resources. - Prefer automation whenever Azure
supports it.

If a required Azure or Microsoft capability cannot currently be
provisioned automatically, document it clearly rather than working
around it.

## Documentation Requirements

Documentation is considered a first-class deliverable.

Maintain documentation throughout development instead of writing it only
at the end.

Required documentation includes: - Comprehensive README - Architecture
overview - Architecture Decision Records (ADRs) - Context, container and
component diagrams - Sequence diagrams for major workflows - Data model
documentation - Security model - Deployment guide - Local development
guide - Operations guide - Troubleshooting guide - Configuration
reference - Cost analysis - Demo guide - Future improvements roadmap

Documentation should evolve together with the implementation.

## Milestones

Implement the project incrementally.

Each milestone should include: - Working implementation - Updated
documentation - Updated diagrams - Architecture decisions -
Demonstration material (screenshots or recordings where appropriate) -
Known limitations - Next steps

The repository should clearly show project progression from foundation
through production readiness.

## Manual Setup

Produce a dedicated file named:

manual-setup.md

Its purpose is to document **only** the manual actions that cannot
reasonably be automated.

Guidelines: - Keep manual steps to an absolute minimum. - Every manual
step should explain why automation is not currently feasible. -
Everything else should be automated. - The document should serve as a
bootstrap guide for reproducing the environment.

## Deliverables

The completed repository should include: - Source code - Infrastructure
as Code (Bicep) - CI/CD configuration - Complete documentation -
Architecture diagrams - ADRs - Cost estimate - manual-setup.md -
CHANGELOG.md - PROJECT_JOURNAL.md documenting milestones, technical
decisions, blockers, resolutions, and lessons learned.

Success should be measured by architecture quality, maintainability,
documentation quality, automation, and enterprise readiness rather than
feature count.
