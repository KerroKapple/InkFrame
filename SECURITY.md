# Security Policy

## Supported Versions / 支持版本

InkFrame is currently in **alpha**. Security fixes land on the latest tag (`v0.1.0-alpha.x`) and the unreleased `dev` branch. Earlier alpha tags do not receive backported fixes.

InkFrame 当前处于 **alpha** 阶段。安全修复合入最新 tag (`v0.1.0-alpha.x`) 与未发布的 `dev` 分支，不再回溯更早的 alpha tag。

| Version | Supported |
|---------|-----------|
| latest `v0.1.0-alpha.x` | ✅ |
| earlier `alpha.*` | ❌ |

## Reporting a Vulnerability / 漏洞上报

**Please do NOT open a public GitHub issue for security vulnerabilities.**

**请勿通过公开 GitHub issue 上报安全漏洞。**

Use one of the following private channels:

1. **GitHub Security Advisories** (preferred): <https://github.com/KerroKapple/InkFrame/security/advisories/new>
2. **Email**: kerro99920+inkframe-security@gmail.com — please encrypt sensitive payloads or request a PGP key first.

We aim to:

- **Acknowledge** receipt within **72 hours**
- Provide a **fix or mitigation timeline** within **14 days**
- Coordinate disclosure once a fix is shipped

## Scope / 涵盖范围

**In scope:**

- Provider API key leakage paths — secure storage, logs, telemetry, error stack traces
- Script editor / canvas node XSS, command injection, or arbitrary code execution
- Local PostgreSQL data integrity / unauthorised read paths
- Third-party AI provider credential abuse — HMAC signing, JWT renewal, token replay
- Update / release artefact tampering surfaces

**Out of scope:**

- User-introduced modifications in personal forks
- Vulnerabilities in upstream AI provider services — please report those to the provider
- Local file disclosure under physical device access (assumed threat model)
- Denial of service via resource exhaustion on a self-hosted single-user install

## Disclosure / 披露

After a fix is released, we will publish a public advisory within **30 days**. Reporters who consent will be credited in the advisory and release notes.

漏洞修复发布后 30 天内公开 advisory。Reporter 同意可在 advisory 与 release notes 内署名致谢。

## Coordinated Disclosure Etiquette

- Give us reasonable time to fix before public disclosure
- Avoid testing against systems you do not own
- Do not destroy or exfiltrate data belonging to other users
- We will not pursue legal action against good-faith research that follows this policy
