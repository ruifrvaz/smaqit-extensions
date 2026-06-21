# Project Diagnose Report — {{DATE}}

## Run Metadata

| Field | Value |
|-------|-------|
| Date | {{DATE}} |
| Domains Scanned | {{DOMAINS}} |
| Total Checks Run | {{TOTAL_CHECKS}} |
| Total Findings | {{TOTAL_FINDINGS}} |
| P1 — Critical | {{P1_COUNT}} |
| P2 — High | {{P2_COUNT}} |
| P3 — Medium | {{P3_COUNT}} |
| P4 — Low | {{P4_COUNT}} |

> Inventory script: {{INVENTORY_STATUS}}

---

## Executive Summary

| Domain | Total | P1 | P2 | P3 | P4 |
|--------|-------|----|----|----|----|
| Testing | {{TEST_TOTAL}} | {{TEST_P1}} | {{TEST_P2}} | {{TEST_P3}} | {{TEST_P4}} |
| Security | {{SEC_TOTAL}} | {{SEC_P1}} | {{SEC_P2}} | {{SEC_P3}} | {{SEC_P4}} |
| Logging | {{LOG_TOTAL}} | {{LOG_P1}} | {{LOG_P2}} | {{LOG_P3}} | {{LOG_P4}} |
| Monitoring | {{MON_TOTAL}} | {{MON_P1}} | {{MON_P2}} | {{MON_P3}} | {{MON_P4}} |
| Provisioning | {{PRV_TOTAL}} | {{PRV_P1}} | {{PRV_P2}} | {{PRV_P3}} | {{PRV_P4}} |
| CI/CD | {{CICD_TOTAL}} | {{CICD_P1}} | {{CICD_P2}} | {{CICD_P3}} | {{CICD_P4}} |

---

## Findings: Testing

| Severity | Check | Affected File | Recommendation | Status |
|----------|-------|---------------|----------------|--------|
| {{SEV}} | {{CHECK}} | {{FILE}} | {{REC}} | {{STATUS}} |

---

## Findings: Security

| Severity | Check | Affected File | Recommendation | Status |
|----------|-------|---------------|----------------|--------|
| {{SEV}} | {{CHECK}} | {{FILE}} | {{REC}} | {{STATUS}} |

---

## Findings: Logging

| Severity | Check | Affected File | Recommendation | Status |
|----------|-------|---------------|----------------|--------|
| {{SEV}} | {{CHECK}} | {{FILE}} | {{REC}} | {{STATUS}} |

---

## Findings: Monitoring

| Severity | Check | Affected File | Recommendation | Status |
|----------|-------|---------------|----------------|--------|
| {{SEV}} | {{CHECK}} | {{FILE}} | {{REC}} | {{STATUS}} |

---

## Findings: Provisioning

| Severity | Check | Affected File | Recommendation | Status |
|----------|-------|---------------|----------------|--------|
| {{SEV}} | {{CHECK}} | {{FILE}} | {{REC}} | {{STATUS}} |

---

## Findings: CI/CD

| Severity | Check | Affected File | Recommendation | Status |
|----------|-------|---------------|----------------|--------|
| {{SEV}} | {{CHECK}} | {{FILE}} | {{REC}} | {{STATUS}} |

---

## Priority Matrix

### P1 — Critical

<!-- List each P1 finding with dependency hints -->
1. {{FINDING}} — depends on: {{DEPENDENCY_HINTS}}

### P2 — High

<!-- List each P2 finding -->
1. {{FINDING}}

### P3 — Medium

<!-- List each P3 finding -->
1. {{FINDING}}

### P4 — Low

<!-- List each P4 finding -->
1. {{FINDING}}

---

## Already-Tracked Cross-Reference

| Finding | Task ID | Task Title |
|---------|---------|------------|
| {{FINDING}} | {{TASK_ID}} | {{TASK_TITLE}} |

---

## Known Findings (Compendium)

| Finding | Compendium Category | Notes |
|---------|---------------------|-------|
| {{FINDING}} | {{CATEGORY}} | {{NOTES}} |
