---
name: crm-marketing-campaigns
description: Build marketing features of a CRM: lists and segments, campaigns, email/SMS/WhatsApp/IVR messaging, templates, consent and opt-in/opt-out, preference centre, frequency caps, journeys/drip sequences, response tracking, attribution of revenue to campaigns, and multi-channel customer experience. Use when the user wants campaigns, mailing or messaging, nurturing, lifecycle messaging, notifications to customers, or to tie marketing spend to sales in a CRM.
---

# CRM Marketing and Campaigns

Marketing features should (1) target the right people, (2) respect consent, (3) persist the marketing thread through to sales and service so revenue can be tied to the activity (a challenge the book highlights), and (4) measure response.

## Building blocks

1. **Audience** = segment definition (saved query over the customer 360 projection) + exclusions (opted-out, recently contacted, open complaint, restricted risk tier) evaluated at send time, not list-build time.
2. **Campaign** = objective, audience, channel(s), budget, owner, dates, offer, success metric. Campaign members record status (targeted, sent, delivered, opened/read, clicked, replied, converted, unsubscribed, bounced).
3. **Message templates**: versioned, localised, variables with fallbacks, preview with real sample records, channel-specific constraints (length, buttons, media), approval workflow where the channel requires pre-approved templates (e.g., WhatsApp Business) so check provider rules at build time.
4. **Journeys** (drip/lifecycle): trigger -> steps with waits and branches -> exit conditions (replied, purchased, opted out). Reuse the rule engine from `crm-workflow-automation`; do not build a second automation system.
5. **Attribution**: stamp `source`, `campaign_id`, UTM/click-ids on leads/orders at capture; keep first-touch and last-touch; report by campaign, channel, and cohort. Multi-touch only if volume supports it.
6. **Experimentation**: A/B on subject/template/send time with a pre-declared success metric and a holdout.

## Consent and compliance (design first)

- Consent is per **contact x channel x purpose** (marketing vs transactional vs service). Record: status, timestamp, source/evidence, text/version, and withdrawal. Append-only; most restrictive wins.
- Transactional messages (order status, delivery) are not marketing, but still need a valid channel and honour opt-out for non-essential content. Keep purposes separate in code and templates.
- One-click unsubscribe, STOP keywords per channel, preference centre (channels, topics, frequency, language). Process opt-outs immediately and sync them to every sending provider.
- Quiet hours by recipient timezone; frequency caps per contact per channel per week; suppression lists; bounce/complaint handling (hard bounces suppress permanently).
- Respect local rules (e.g., data-protection and telecom/spam regulations in the markets you serve). They differ by country; flag this to the user and have them confirm requirements with counsel rather than assuming.
- Log every message: template version, rendered content hash, provider message id, status callbacks.

## Multi-channel principles (Handbook ch. 4)

- The same customer sees consistent offers and history across channels; log every channel into the one timeline.
- Choose channel by customer preference and moment: transactional notices on the highest-attention channel (often WhatsApp/SMS in MENA; email elsewhere), long-form content by email, rescue calls for high-value cases.
- Evaluate the experience *across* channels (hand-offs, repeated questions), not only within each.

## Deliverability and providers

Abstract providers behind a `MessageChannel` interface (send, status webhook, templates, opt-out sync). Retry with backoff; circuit-breaker per provider; failover for SMS/email; webhook signature verification; idempotent webhook handlers; rate limiting to provider quotas; sender reputation monitoring (email: SPF/DKIM/DMARC).

## Metrics

List size and growth, delivery/read/click/reply rates, unsubscribe and complaint rate, conversion and revenue per message, cost per acquisition by channel, incremental lift vs holdout, list health (invalid %, inactive %).

## Anti-patterns

- Buying lists or messaging without recorded consent.
- Blasting the whole database because it is easy ("mailing one-twelfth of the database each month regardless of relevance" is the Handbook's cautionary contrast with targeted campaigns).
- Separate unsubscribe lists per tool that drift apart.
- Campaign metrics (opens) without business outcomes (orders, margin).
