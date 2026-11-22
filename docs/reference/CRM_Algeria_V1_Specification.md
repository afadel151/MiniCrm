# **Algerian CRM** V1 Specification 

Database schema, business logic and frontend functionality 

COD return handling, behavioural contact scoring, multi-mode integrations, client portal 

_Draft 0.1  |  5 November 2026  |  Working document for build kickoff_ 

Confidence tags used in this document: **[Certain]** hard evidence or our own design decision; **[Likely]** strong inference, verify before relying on it; **[Guessing]** placeholder or unverified assumption that needs data or a source. 

## **Contents** 

|**1. Scope and key design decisions**|**4**|
|---|---|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>1.1 What V1 is|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 4|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>1.2 In scope and out of scope|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 4|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>1.3 Eight design decisions that shape everything else|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 4|
|**2. Operating modes (adaptability to different businesses)**|**5**|
|**3. Roles, permissions and tenancy rules**|**6**|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>3.1 Role model|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 6|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>3.2 Permission keys|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 6|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>3.3 Permission presets (starting points, editable per member)|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 6|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>3.4 Enforcement rules|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 6|
|**4. Database schema (PostgreSQL)**|**8**|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.1 Conventions|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 8|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.2 Entity relationships (summary)|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 8|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.3 A. Identity, tenancy and access|.  .  .  .  .  .  .  .  .  .  .  .  .  .  . 8|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.4 B. Global phone layer (platform-owned, no business_id)|.  .  .  .  .  .  .  .  .  .  .  .  .  . 10|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.5 C. CRM core (tenant-scoped)|.  .  .  .  .  .  .  .  .  .  .  .  .  . 13|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.6 D. Catalog, orders, delivery and returns (tenant-scoped)|.  .  .  .  .  .  .  .  .  .  .  .  .  . 15|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.7 E. Integrations (tenant-scoped unless noted)|.  .  .  .  .  .  .  .  .  .  .  .  .  . 19|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.8 F. Client portal and public presence|.  .  .  .  .  .  .  .  .  .  .  .  .  . 21|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.9 G. Platform|.  .  .  .  .  .  .  .  .  .  .  .  .  . 22|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>4.10 Required indexes and extra constraints|.  .  .  .  .  .  .  .  .  .  .  .  .  . 23|
|**5. Business logic**|**24**|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.1 Authentication and onboarding|.  .  .  .  .  .  .  .  .  .  .  .  .  . 24|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.2 Phone normalisation and contact handling|.  .  .  .  .  .  .  .  .  .  .  .  .  . 24|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.3 Pipeline and opportunities|.  .  .  .  .  .  .  .  .  .  .  .  .  . 24|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.4 Calls and call dispositions|.  .  .  .  .  .  .  .  .  .  .  .  .  . 24|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.5 Order lifecycle (state machine)|.  .  .  .  .  .  .  .  .  .  .  .  .  . 25|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.6 Confirmation link (the seriousness test)|.  .  .  .  .  .  .  .  .  .  .  .  .  . 26|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.7 Returns|.  .  .  .  .  .  .  .  .  .  .  .  .  . 26|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.8 Integrations|.  .  .  .  .  .  .  .  .  .  .  .  .  . 27|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>5.9 Notifications|.  .  .  .  .  .  .  .  .  .  .  .  .  . 27|
|**6. Contact scoring**|**28**|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>6.1 Principles|.  .  .  .  .  .  .  .  .  .  .  .  .  . 28|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>6.2 Signal catalogue|.  .  .  .  .  .  .  .  .  .  .  .  .  . 28|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>6.3 Computation|.  .  .  .  .  .  .  .  .  .  .  .  .  . 28|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>6.4 Risk policy (what businesses do with the score)|.  .  .  .  .  .  .  .  .  .  .  .  .  . 29|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>6.5 Anti-abuse and fairness|.  .  .  .  .  .  .  .  .  .  .  .  .  . 29|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>6.6 Recompute strategy|.  .  .  .  .  .  .  .  .  .  .  .  .  . 29|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 2 

|.  .  .  .  .  .  .  .  .<br>6.7 Legal gate for the global score (must pass before enabling `global_score_visible`)|.  .  .  .  .  .  .  .  .  . 30|
|---|---|
|**7. Client portal and public presence**|**31**|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>7.1 Reviews|.  .  .  .  .  .  .  .  .  . 31|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>7.2 Chat|.  .  .  .  .  .  .  .  .  . 31|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>7.3 Business profile page|.  .  .  .  .  .  .  .  .  . 31|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>7.4 Client's own data|.  .  .  .  .  .  .  .  .  . 31|
|**8. Frontend functionality**|**32**|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>8.1 Global requirements|.  .  .  .  .  .  .  .  .  . 32|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>8.2 Public and authentication screens|.  .  .  .  .  .  .  .  .  . 32|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>8.3 Client area|.  .  .  .  .  .  .  .  .  . 32|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>8.4 Business application|.  .  .  .  .  .  .  .  .  . 33|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>8.5 Web master console|.  .  .  .  .  .  .  .  .  . 33|
|**9. Non-functional requirements**|**34**|
|**10. Build plan, acceptance criteria and open items**|**35**|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>10.1 Suggested milestones|.  .  .  .  .  .  .  .  .  . 35|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>10.2 V1 acceptance criteria|.  .  .  .  .  .  .  .  .  . 35|
|.  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .<br>10.3 Open decisions and unverified items|.  .  .  .  .  .  .  .  .  . 35|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 3 

## **1. Scope and key design decisions** 

### **1.1 What V1 is** 

A multi-tenant CRM for Algerian businesses selling with cash on delivery (COD), plus a lightweight client portal. A business records contacts, opportunities, orders, calls and deliveries. From that behaviour the platform computes a **risk score per phone number** : the likelihood that the person will receive the delivery rather than refuse or return it. V1 must work for a seller who types everything by hand and for a seller wired to a carrier, WhatsApp and a store. 

### **1.2 In scope and out of scope** 

|**In scope for V1**|**Out of scope for V1 (but schema-ready where noted)**|
|---|---|
|Auth: email+password and Google OAuth; businesses, owner/staff<br>roles with granular permissions|Real online payments (UI mockups only;<br>`payments.provider='mock'`)|
|Contacts (B2B/B2C), phones, tags, custom fields, merge, import/export|**Global cross-business score display**: tables exist,<br>`global_score_visible`flag ships OFF pending the legal gate<br>(Section 6.7)|
|Pipelines, opportunities, tasks, unified interaction timeline|Automatic telephony telemetry (ring time, call duration); V1 uses<br>structured manual call dispositions|
|COD orders with state machine, confirmation link, shipments, returns<br>with fault attribution|Marketplace discovery ranking, categories, geo search (V1 has profile<br>pages, direct links and a basic name search)|
|Private per-business risk score with confidence, reasons and risk policy|Machine-learned scoring (V1 is transparent rules; ML after enough<br>labelled outcomes)|
|Integrations: manual, CSV, custom store API, Shopify, WhatsApp<br>Cloud API, Yalidine (+ adapter for other carriers)|Invoicing, tax, accounting, multi-currency, multi-warehouse inventory|
|Client portal: profile page view, in-app chat, reviews, order tracking,<br>own data and disputes|Mobile native apps (V1 is a responsive web app, mobile-first)|
|Web master console: moderation, disputes, flags, audit|Subscriptions and billing for businesses|



### **1.3 Eight design decisions that shape everything else** 

1. **Roles are contextual, not a column.** One person can be a client, own business A and be staff in business B. `users.platform_role` only distinguishes `web_master` from everyone else; business role lives in `business_members` ; the client role is simply the presence of a `client_profiles` row. 

2. **Two data layers.** Private layer (contacts, interactions, orders) belongs to one business and is isolated by row-level security. Global layer ( `phone_identities` , `phone_signals` , `score_snapshots` ) holds only hashed numbers and aggregated behavioural events. 

3. **Every outcome carries provenance.** A delivery confirmed by a carrier API is worth far more than a checkbox ticked by an employee. Manual businesses are first-class, but their data counts for less. 

4. **Confirmation link instead of order falsification.** The seriousness test is a one-time link where the customer reviews the real recap and confirms or edits it. It yields the same signal without deceiving anyone. 

5. **Fault split on every return.** Returns caused by the business or carrier never count against a customer. Without this the score is unfair and businesses will not trust it. 

6. **Third-party number protection.** If a customer gives someone else's number, the owner of that number must not be punished. Wrong-number and 'I never ordered' outcomes carry zero weight. 

7. **Integrations sit behind one adapter interface with an event inbox.** Shopify, WhatsApp, carriers and custom stores all produce the same normalised events. Manual mode is an adapter too. 

8. **The score informs, it never decides.** No order is auto-cancelled by a score. Risk policy produces recommended actions that a human or an explicit business rule applies. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 4 

## **2. Operating modes (adaptability to different businesses)** 

Modes are not separate code paths. They describe which adapters a business has connected; a business can mix them (for example manual orders plus Yalidine). The only structural consequence is data quality, which feeds scoring confidence. 

|**Capability**|**Manual**|**Assisted (CSV / API keys)**|**Integrated (Shopify, WhatsApp, carrier)**|
|---|---|---|---|
|Contact entry|Typed in forms or quick-add by<br>phone number|CSV/XLSX import with column<br>mapping; custom store posts<br>contacts|Auto-upserted from store orders and<br>inbound WhatsApp|
|Order entry|Order form, 'phone order' shortcut|CSV import; custom store calls`POST`<br>`/v1/orders`|Webhook creates order automatically|
|Delivery status|Agent updates status; may attach<br>proof photo|Agent updates, or custom system<br>pushes status via API|Carrier statuses synced and normalised<br>automatically|
|Outcome<br>provenance|`manual_unverified`(0.3) or<br>`manual_with_proof`(0.6)|`webhook_verified`(0.9) if pushed<br>by signed API call; else manual|`carrier_api`(1.0)|
|Confirmation|Link copied and pasted into any chat<br>app, or call only|Same, link can be returned in API<br>response|Link sent automatically via WhatsApp<br>template|
|Messaging|In-app chat only|In-app chat only|Unified inbox: WhatsApp and in-app|
|Score confidence<br>ceiling|Medium in practice (low-weight data)|Medium to high|High|



**Product consequence [Likely]:** manual-mode businesses will dominate early. If their outcomes carry weight 0.3, scores stay low-confidence for a long time. The compensation is UX, not maths: make attaching proof (delivery receipt photo, carrier tracking screenshot) a two-tap action so weight rises to 0.6. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 5 

## **3. Roles, permissions and tenancy rules** 

### **3.1 Role model** 

|**Role**|**How it is represented**|**Can do**|
|---|---|---|
|web_master|`users.platform_role='web_mast`<br>`er'`|Platform administration: approve/verify/suspend businesses, moderate reviews,<br>resolve disputes, invalidate signals, manage flags, score models, carrier mappings,<br>read audit logs.**Cannot read a business's private contacts or message**<br>**content by default.**|
|business owner|`business_members.role='owner'`|Everything within their business including team, integrations, risk policy, public<br>profile, deletion. At least one owner at all times.|
|business staff|`business_members.role='staff'`<br>+`permissions[]`+`data_scope`|Only the permissions granted; optionally limited to contacts assigned to them.|
|client|`client_profiles`row exists (B2C or<br>B2B)|Browse published profiles, chat with businesses, review after verified interaction,<br>track own orders, manage own data, dispute own signals.|



### **3.2 Permission keys** 

|**Key**|**Grants**|
|---|---|
|contacts.read / contacts.write /<br>contacts.delete / contacts.export|View, create/edit, archive/delete, export contacts|
|pipeline.manage|Edit pipelines and stages; move opportunities|
|orders.read / orders.write / orders.cancel|View, create/edit, cancel orders|
|orders.override_status|Set terminal statuses without carrier proof; edit terminal orders (always requires a note, always<br>audited)|
|shipments.manage|Create shipments, push to carriers, enter tracking numbers|
|returns.manage|Open/close return cases, set fault, restock|
|calls.log|Use the call workbench and log call dispositions|
|inbox.reply|Read and answer conversations|
|products.manage|Catalogue CRUD|
|reviews.reply|Reply to and report reviews|
|profile.edit|Edit and publish the public profile page|
|integrations.manage|Connect/disconnect integrations, API keys, templates (owner by default)|
|team.manage|Invite staff, change permissions (owner only in V1)|
|analytics.view|Dashboards and reports|
|score.view|See score badges, tiers, reason codes|



### **3.3 Permission presets (starting points, editable per member)** 

|**Preset**|**Permissions**|**data_scope**|
|---|---|---|
|Manager|all except`team.manage`|all|
|Call agent|`contacts.read`,`contacts.write`,`orders.read`,`orders.write`,`calls.log`,|assigned_only|
||`inbox.reply`,`score.view`||
|Logistics|`orders.read`,`shipments.manage`,`returns.manage`,`products.manage`|all|
|Viewer|`contacts.read`,`orders.read`,`analytics.view`|all|



### **3.4 Enforcement rules** 

- **Tenant is derived from membership, never from the request.** The API takes `business_id` from the authenticated member context (selected business in session) and sets it on the database connection for the transaction. 

- **PostgreSQL row-level security** on every tenant table: `business_id = current_setting('app.business_id')::uuid` . Application bugs then cannot leak across tenants. **[Likely]** This is the single most valuable safeguard in the whole schema. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 6 

- **Permission check before data scope.** Staff with `assigned_only` see contacts where `owner_member_id` is theirs, plus their orders, tasks and conversations. 

- **Global layer access is code-gated.** Business-facing endpoints return only `score` , `tier` , `confidence` , `reason_codes` for a phone; never raw signals and never other businesses' identities. 

- **web_master 'break glass'.** Reading a tenant's private records requires an explicit, reasoned, time-boxed access grant that writes to `audit_logs` and notifies the business owner. 

- **Clients only reach their own rows:** orders where their verified phone identity matches, their conversations, reviews, consents, disputes. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 7 

## **4. Database schema (PostgreSQL)** 

### **4.1 Conventions** 

- Primary keys: `uuid` (v7 preferred for index locality). Every table also has `created_at` and `updated_at` ( `timestamptz` , UTC); the UI converts to `Africa/Algiers` . These columns are omitted from the tables below. 

- Tenant tables carry `business_id uuid NOT NULL` with a foreign key and an RLS policy. Tables in groups A (partly), B and G are platform-level. 

- Enumerations are `text` with `CHECK` constraints (easier to migrate than native enums). Values are listed in the Notes column. 

- Money is `numeric(12,2)` in DZD. Never floats. 

- Phone numbers: stored as typed ( `phone_raw` ) and normalised E.164 ( `phone_e164` ) in private tables; only an HMAC hash in the global layer. 

- Deletion: soft delete ( `deleted_at` ) for contacts/products; orders and history are never deleted. Erasure requests anonymise contact PII; treatment of `phone_identities` and `phone_signals` on erasure is a **legal question** (Section 10.3). 

- Append-only tables (never UPDATE, enforce with permissions/triggers): `order_status_history` , `shipment_events` , `phone_signals` (only `is_valid` may flip), `audit_logs` . 

### **4.2 Entity relationships (summary)** 

- `users` 1-N `business_members` N-1 `businesses` ; `users` 1-0..1 `client_profiles` 

- `businesses` 1-N `contacts` 1-N `contact_phones` N-1 `phone_identities` (the bridge from private to global) 

- `contacts` 1-N `interactions` 1-0..1 `call_logs` ; `contacts` 1-N `opportunities` N-1 `pipeline_stages` 

- `contacts` 1-N `orders` 1-N `order_items` ; `orders` 1-N `order_status_history` , `confirmation_requests` , `shipments` (1-N `shipment_events` ); `orders` 1-0..1 `return_cases` 

- `phone_identities` 1-N `phone_signals` , `score_snapshots` , `consents` , `disputes` 

- `businesses` 1-1 `business_profiles` ; 1-N `reviews` (N-1 `users` ) 1-0..1 `review_replies` ; 1-N `conversations` 1-N `messages` 

- `integration_connections` 1-N `webhook_events` , `external_refs` , `message_templates` 

### **4.3 A. Identity, tenancy and access** 

#### **`users`** 

_One row per human. Roles are contextual (see Section 3), not stored as a single enum._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`email`|citext UNIQUE NOT NULL|login identifier|
|`email_verified_at`|timestamptz|NULL until verified|
|`password_hash`|text|argon2id; NULL for Google-only accounts|
|`full_name`|text NOT NULL||
|`avatar_file_id`|uuid FK files||
|`locale`|text|ar / fr / en (UI language)|
|`platform_role`|text|'member' (default) or 'web_master'|
|`status`|text|active / suspended / deleted|
|`last_login_at`|timestamptz||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 8 

```
auth_identities
```

_Login methods linked to a user (email+password and Google can coexist)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`user_id`|uuid FK users||
|`provider`|text|'password' / 'google'|
|`provider_subject`|text|Google 'sub' claim; the email for 'password'|
|**UNIQUE**|(provider, provider_subject)||



#### **`auth_sessions`** 

_Refresh-token sessions, one row per device._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`user_id`|uuid FK users||
|`refresh_token_hash`|text|store hash only, rotate on use|
|`user_agent / ip`|text / inet||
|`expires_at /`|timestamptz||
|`revoked_at`|||



#### **`auth_tokens`** 

_Single-use tokens for email verification and password reset._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`user_id`|uuid FK users||
|`purpose`|text|'verify_email' / 'reset_password'|
|`token_hash`|text|hash only|
|`expires_at /`|timestamptz||
|`used_at`|||



#### **`businesses`** 

_The tenant. Everything in groups C, D, E is scoped to a business._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`name`|text NOT NULL||
|`slug`|text UNIQUE|public URL: /b/{slug}|
|`business_kind`|text|'B2C' / 'B2B' / 'BOTH' (who it sells to)|
|`category`|text|free list in v1, taxonomy in v2|
|`status`|text|pending / active / suspended|
|`verified_at`|timestamptz|badge granted by web_master|
|`trust_weight`|numeric(3,2)|default 0.50; scales how much this business's signals count in scoring|
|`wilaya_code`|smallint FK wilayas||
|`address_text`|text||
|`public_phone /`<br>`public_email`|text||
|`currency`|char(3)|default 'DZD'|
|`timezone`|text|default 'Africa/Algiers'|
|`operating_mode`|text|'manual' / 'assisted' / 'integrated' (informational, drives onboarding UI)|
|`settings`|jsonb|risk_policy, confirmation rules, order number format, working hours|
|`created_by`|uuid FK users||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 9 

#### **`business_members`** 

_Membership of a user in a business. A user can be owner of one business and staff of another._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`business_id`|uuid FK businesses||
|`user_id`|uuid FK users||
|`role`|text|'owner' / 'staff'|
|`permissions`|text[]|permission keys (Section 3.2); owners implicitly have all|
|`data_scope`|text|'all' / 'assigned_only' (staff sees only contacts assigned to them)|
|`status`|text|invited / active / revoked|
|**UNIQUE**|(business_id, user_id)||
|**RULE**|enforced in app + trigger|a business always keeps at least one active owner|



#### **`business_invitations`** 

_Staff invitations by email._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`business_id`|uuid FK businesses||
|`email`|citext NOT NULL||
|`role / permissions`|as in business_members|assigned on acceptance|
|`/ data_scope`|||
|`token_hash`|text|hash only|
|`invited_by`|uuid FK users||
|`expires_at /`<br>`accepted_at`|timestamptz|7-day expiry**[Guessing]**|



#### **`client_profiles`** 

_Presence of the 'client' capability on a user. Optional extra data for B2B/B2C clients._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`user_id`|uuid UNIQUE FK users||
|`client_type`|text|'B2C' / 'B2B'|
|`company_name`|text|B2B only|
|`wilaya_code`|smallint FK wilayas||
|`default_address`|text||
|`phone_identity_id`|uuid FK phone_identities NULL|set only after phone ownership is proven|
|`phone_verified_at`|timestamptz|via OTP or via a clicked confirmation link|



### **4.4 B. Global phone layer (platform-owned, no business_id)** 

#### **`phone_identities`** 

_One row per distinct phone number across the platform. This is the key the score hangs on. Raw numbers are NEVER stored here._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`phone_hash`|bytea UNIQUE NOT NULL|HMAC-SHA256(E.164, server-side secret pepper)|
|`operator_hint`|text|ooredoo / mobilis / djezzy / landline / unknown (derived from prefix)**[Likely]**|
|`first_seen_at`|timestamptz||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 10 

#### **`consents`** 

_Who agreed to what, for a given phone number. Required before any data feeds the global layer._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`phone_identity_id`|uuid FK||
|`business_id`|uuid FK NULL|the business that collected it (NULL if platform-level)|
|`purpose`|text|crm_processing / score_contribution / score_display / marketing|
|`status`|text|granted / withdrawn|
|`method`|text|confirmation_link / client_account / declared_by_business / import_declared|
|`policy_version`|text||
|`evidence`|jsonb|timestamp, ip, user agent, link token id, checkbox text shown|
|`granted_at /`|timestamptz||
|`withdrawn_at`|||



#### **`phone_signals`** 

_Append-only behavioural events about a phone number. The score is computed from these. Never edited, only invalidated._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`phone_identity_id`|uuid FK||
|`business_id`|uuid FK|the contributing business|
|`signal_type`|text|see Section 6.2|
|`value`|jsonb|e.g. {attempt_no: 3} or {delay_minutes: 240}|
|`provenance`|text|carrier_api / webhook_verified / manual_with_proof / manual_unverified / system|
|`order_id /`<br>`interaction_id`|uuid FK NULL|source record|
|`occurred_at`|timestamptz||
|`is_valid`|boolean|false after upheld dispute or web_master invalidation|
|`invalid_reason`|text||
|**INDEX**|(phone_identity_id,<br>occurred_at)||



#### **`score_models`** 

_Versioned scoring parameters so scores are reproducible and auditable._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`version`|text UNIQUE|e.g. 'v1.0'|
|`params`|jsonb|priors, weights, decay half-life, tier cut-offs|
|`status`|text|shadow / active / retired|
|`active_from`|timestamptz||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 11 

#### **`score_snapshots`** 

_Computed scores. business_id set = private per-business score (v1). business_id NULL = global score (built, but hidden behind a feature flag in v1)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`phone_identity_id`|uuid FK||
|`business_id`|uuid FK NULL|NULL = global|
|`model_version`|text FK score_models||
|`score`|numeric(5,2)|0-100, NULL when unscored|
|`tier`|text|A / B / C / D / UNSCORED|
|`confidence`|text|none / low / medium / high|
|`effective_n`|numeric(6,2)|weighted number of outcomes behind the score|
|`contributing_busine`<br>`sses`|int|for global rows; display only if >= k (default 3)|
|`reason_codes`|text[]|e.g. REFUSED_AT_DOOR_x2, NEEDED_3_CALL_ATTEMPTS|
|`is_current`|boolean||
|`computed_at`|timestamptz||
|**INDEX**|(phone_identity_id,<br>business_id) WHERE<br>is_current||



#### **`disputes`** 

_A person contests a signal or an order outcome that counted against them._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`phone_identity_id`|uuid FK||
|`raised_by_user_id`|uuid FK users|must have verified that phone|
|`signal_id /`<br>`order_id`|uuid FK NULL||
|`reason`|text||
|`status`|text|open / under_review / upheld / rejected|
|`resolved_by`|uuid FK users|web_master|
|`resolution_note`|text||
|`resolved_at`|timestamptz|upheld => signal.is_valid=false and score recomputed|



#### **`data_subject_requests`** 

_Access / rectification / deletion / objection requests._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`user_id`|uuid FK NULL||
|`phone_identity_id`|uuid FK NULL||
|`type`|text|access / rectify / delete / object|
|`status`|text|open / in_progress / done / refused|
|`due_at`|timestamptz||
|`handled_by`|uuid FK users||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 12 

### **4.5 C. CRM core (tenant-scoped)** 

#### **`contacts`** 

_A person or company known to ONE business. Private to that business._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`contact_type`|text|'B2C' / 'B2B'|
|`first_name /`|text||
|`last_name`|||
|`display_name`|text NOT NULL|derived if empty|
|`organization_name`|text|B2B|
|`email`|citext||
|`wilaya_code /`<br>`commune /`<br>`address_text`|smallint / text / text||
|`source`|text|manual / import / shopify / whatsapp / carrier / api / client_portal|
|`owner_member_id`|uuid FK business_members|assigned staff|
|`client_user_id`|uuid FK users NULL|linked platform account, if the person is registered|
|`status`|text|active / archived / blocked_by_business|
|`custom_fields`|jsonb|validated against custom_field_definitions|
|`last_interaction_at`|timestamptz|denormalised for sorting|
|`merged_into_id`|uuid FK contacts NULL|set on merge|
|`deleted_at`|timestamptz|soft delete|



#### **`contact_phones`** 

_Phone numbers of a contact. Links the private contact to the global phone identity._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`contact_id`|uuid FK contacts||
|`phone_raw`|text|exactly what was typed or imported|
|`phone_e164`|text NOT NULL|normalised (+213...)|
|`phone_identity_id`|uuid FK phone_identities|created on first sight|
|`is_primary`|boolean||
|`label`|text|mobile / work / whatsapp|
|`whatsapp_capable`|boolean NULL||
|**UNIQUE**|(business_id, phone_e164)|duplicates trigger the merge flow, not an error page|



#### **`tags / contact_tags`** 

_Free-form labels. tags(name UNIQUE per business, color); contact_tags(contact_id, tag_id)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`tags.name / color`|text||
|`contact_tags`|(contact_id, tag_id) PK||



#### **`custom_field_definitions`** 

_Lets each business shape the CRM to its sector without schema changes._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`entity`|text|contact / opportunity / order|
|`key`|text|machine key, UNIQUE per (business_id, entity)|
|`label`|text|display label (ar/fr/en map in jsonb if needed)|
|`field_type`|text|text / number / date / select / multiselect / boolean|
|`options`|jsonb|for select types|
|`required`|boolean||
|`position`|int||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 13 

#### **`pipelines / pipeline_stages`** 

_Sales pipelines. A default pipeline is seeded per business._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`pipelines.name /`<br>`is_default`|text / boolean||
|`pipeline_stages.pip`<br>`eline_id`|uuid FK||
|`pipeline_stages.nam`<br>`e`|text||
|`pipeline_stages.pos`<br>`ition`|int||
|`pipeline_stages.sta`<br>`ge_type`|text|open / won / lost|
|`pipeline_stages.pro`<br>`bability`|smallint|0-100|



#### **`opportunities`** 

_A potential sale to a contact, before it becomes an order._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`contact_id`|uuid FK||
|`pipeline_id /`<br>`stage_id`|uuid FK||
|`title`|text||
|`expected_value`|numeric(12,2)||
|`expected_close_date`|date||
|`owner_member_id`|uuid FK business_members||
|`status`|text|open / won / lost|
|`lost_reason`|text||
|`source`|text||
|`order_id`|uuid FK orders NULL|set when converted|
|`custom_fields`|jsonb||
|`won_at / lost_at`|timestamptz||



#### **`interactions`** 

_The unified timeline: everything that happens with a contact, including system events._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`contact_id`|uuid FK||
|`opportunity_id /`<br>`order_id`|uuid FK NULL||
|`type`|text|call / whatsapp / sms / email / chat / note / visit / system|
|`direction`|text|in / out / internal|
|`actor_member_id`|uuid FK NULL|NULL for system or client-originated|
|`occurred_at`|timestamptz||
|`summary`|text||
|`payload`|jsonb|channel-specific data|
|`external_message_id`|text|for dedup of integration messages|
|`source`|text|manual / integration / system|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 14 

```
call_logs
```

_Structured detail for interactions of type 'call'. This is the raw material of behavioural scoring._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`interaction_id`|uuid PK/FK||
|`purpose`|text|confirm_order / delivery_followup / sales / support / other|
|`attempt_group_id`|uuid|groups attempts for the same purpose (e.g., one order confirmation)|
|`attempt_no`|int|1,2,3... within the attempt group|
|`disposition`|text|answered / no_answer / busy / switched_off / rejected / wrong_number / voicemail|
|`outcome`|text NULL|confirmed / cancelled / postponed / callback_requested / undecided|
|`started_at /`<br>`answered_at`|timestamptz|answered_at NULL if not answered|
|`ring_seconds /`<br>`talk_seconds`|int NULL|only when telemetry exists|
|`telemetry_source`|text|manual (v1) / telephony (later)|



#### **`tasks`** 

_Follow-ups and call-backs._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`assignee_member_id`|uuid FK||
|`contact_id /`|uuid FK NULL||
|`opportunity_id /`<br>`order_id`|||
|`type`|text|call_back / follow_up / confirm_order / other|
|`title`|text||
|`due_at / done_at`|timestamptz||



### **4.6 D. Catalog, orders, delivery and returns (tenant-scoped)** 

#### **`products`** 

_Sellable items or services; optionally shown on the public profile._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`name / description`|text||
|`sku`|text|UNIQUE per business when set|
|`category`|text||
|`base_price`|numeric(12,2)||
|`track_stock /`|boolean / int||
|`stock_qty`|||
|`status`|text|draft / active / archived|
|`is_public`|boolean|appears on the business profile page|



#### **`product_variants / product_images`** 

_Variants (size, colour) and ordered images._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`product_variants.pr`<br>`oduct_id`|uuid FK||
|`product_variants.na`|text|e.g. 'Black / 42'|
|`me / sku`|||
|`product_variants.pr`<br>`ice_override`|numeric(12,2) NULL||
|`product_variants.st`<br>`ock_qty`|int||
|`product_images.prod`<br>`uct_id / file_id /`<br>`position`|uuid / uuid / int||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 15 

#### **`orders`** 

_The core COD entity. 'status' is the workflow state; 'outcome_class' is the terminal classification the score reads._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`order_number`|text|UNIQUE per business, sequence-based|
|`contact_id`|uuid FK||
|`contact_phone_id`|uuid FK contact_phones|the exact number used for this order|
|`opportunity_id`|uuid FK NULL||
|`channel`|text|manual / phone / whatsapp / shopify / custom_store / api / client_portal|
|`status`|text|draft / pending_confirmation / confirmed / processing / shipped / out_for_delivery /<br>delivered / delivery_failed / return_in_transit / returned / cancelled|
|`confirmation_status`|text|not_requested / pending / confirmed / rejected / expired|
|`confirmed_at /`<br>`confirmed_via`|timestamptz / text|via: call / link / whatsapp / manual|
|`outcome_class`|text NULL|success / customer_failure / business_failure / neutral (set at terminal state)|
|`outcome_source`|text|carrier_api / webhook_verified / manual_with_proof / manual_unverified|
|`payment_method`|text|'cod' (real in v1); 'card_mock', 'bank_transfer_mock' (UI mockups)|
|`payment_status`|text|unpaid / cod_pending / collected / refunded_mock|
|`subtotal /`<br>`delivery_fee /`<br>`discount / total`|numeric(12,2)||
|`cod_amount`|numeric(12,2)|amount to collect at the door|
|`delivery_type`|text|home / stopdesk|
|`delivery_wilaya_cod`<br>`e / commune /`<br>`address_text /`<br>`address_notes`|smallint / text / text / text||
|`risk_snapshot_id`|uuid FK score_snapshots<br>NULL|score shown at order time (audit)|
|`placed_at /`<br>`shipped_at /`<br>`delivered_at /`<br>`closed_at`|timestamptz||
|`custom_fields`|jsonb||



#### **`order_items`** 

_Snapshot lines (names and prices frozen at order time)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`order_id`|uuid FK||
|`product_id /`|uuid FK NULL|NULL for free-text lines|
|`variant_id`|||
|`name_snapshot /`|text||
|`sku_snapshot`|||
|`qty`|int||
|`unit_price /`|numeric(12,2)||
|`line_total`|||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 16 

#### **`order_status_history`** 

_Append-only log of every status change, with its source and evidence._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`order_id`|uuid FK||
|`from_status /`|text||
|`to_status`|||
|`source`|text|manual / webhook / carrier_api / confirmation_link / system|
|`changed_by_member_i`<br>`d`|uuid FK NULL||
|`external_event_id`|text|dedup key for integration events|
|`evidence_file_id`|uuid FK files NULL|e.g. photo/proof for manual outcomes|
|`note`|text||
|`occurred_at`|timestamptz||



#### **`payments`** 

_MOCKUP in v1: records only COD collection; card/bank rows are UI demos with provider='mock'._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`order_id`|uuid FK||
|`method`|text|cod / card_mock / bank_transfer_mock|
|`amount`|numeric(12,2)||
|`status`|text|pending / collected / failed / refunded_mock|
|`provider`|text|'mock' (v1)|
|`collected_by`|text|carrier / business|
|`collected_at`|timestamptz||



#### **`confirmation_requests`** 

_The 'serious customer' check: a one-time link where the customer reviews the real order recap and confirms. Replaces order falsification._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`order_id`|uuid FK||
|`token_hash`|text UNIQUE|single-use, bound to the order and phone|
|`channel`|text|whatsapp / sms / manual_copy|
|`sent_at / opened_at`<br>`/ completed_at /`<br>`expires_at`|timestamptz||
|`result`|text|confirmed / edited_and_confirmed / rejected / expired|
|`recap_snapshot`|jsonb|what the customer saw|
|`edits`|jsonb|address/quantity changes made by the customer|
|`consent_id`|uuid FK consents NULL|consent captured on the page|
|`ip / user_agent`|inet / text||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 17 

#### **`shipments`** 

_One delivery attempt chain with a carrier (or manual tracking)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`order_id`|uuid FK||
|`carrier`|text|yalidine / zr_express / noest / other / manual|
|`tracking_number`|text||
|`carrier_shipment_id`|text||
|`status_raw /`<br>`status_normalized`|text|normalised via carrier_status_mappings|
|`attempts_count`|int||
|`cod_amount /`<br>`carrier_fee`|numeric(12,2)||
|`created_via`|text|api / manual / csv|
|`label_file_id`|uuid FK files NULL||
|`dispatched_at /`<br>`delivered_at /`<br>`returned_at /`<br>`last_synced_at`|timestamptz||



#### **`shipment_events`** 

_Raw carrier events, kept as received._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`shipment_id`|uuid FK||
|`external_event_id`|text|UNIQUE per shipment|
|`status_raw /`|text||
|`status_normalized`|||
|`location`|text||
|`payload`|jsonb||
|`event_at`|timestamptz||



#### **`carrier_status_mappings`** 

_Platform-maintained dictionary: each carrier's raw status -> our normalised status and outcome class. (Global table, not tenant-scoped.)_ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`carrier`|text||
|`status_raw`|text|UNIQUE per carrier|
|`status_normalized`|text||
|`outcome_class`|text NULL|success / customer_failure / business_failure / neutral|



#### **`return_reason_codes`** 

_Reference table. The fault split is what keeps the score fair. (Global.)_ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`code`|text UNIQUE|REFUSED_AT_DOOR, NOT_REACHABLE, ABSENT_REPEATED,<br>WRONG_ADDRESS_BY_CUSTOMER, WRONG_ITEM_SENT,<br>LATE_DELIVERY, DAMAGED, CARRIER_ISSUE,<br>CUSTOMER_CHANGED_MIND ...|
|`label`|jsonb|{ar, fr, en}|
|`default_fault`|text|customer / business / carrier / unknown|
|`counts_against_cont`<br>`act`|boolean|false for business/carrier fault|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 18 

#### **`return_cases`** 

_One per returned or failed order; drives restocking and signals._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`order_id /`<br>`shipment_id`|uuid FK||
|`contact_id`|uuid FK||
|`reason_code`|text FK return_reason_codes||
|`fault`|text|customer / business / carrier / unknown (default from code, editable with<br>justification)|
|`refused_at_door`|boolean||
|`status`|text|open / received / restocked / written_off / disputed|
|`cost_amount`|numeric(12,2)|return shipping + lost fees (for analytics)|
|`received_at`|timestamptz||
|`evidence_file_id`|uuid FK files NULL||



### **4.7 E. Integrations (tenant-scoped unless noted)** 

#### **`integration_connections`** 

_One row per connected system. Manual-only businesses simply have none._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`provider`|text|yalidine / zr_express / noest / shopify / whatsapp_cloud / custom_api / csv|
|`status`|text|pending_auth / active / error / disabled|
|`config`|jsonb|non-secret settings (store URL, phone number id, mapping options)|
|`credentials_encrypt`<br>`ed`|bytea|envelope encryption (KMS or app-level master key); never logged|
|`webhook_secret_hash`|text||
|`last_sync_at`|timestamptz||
|`last_error`|text||
|`created_by`|uuid FK users||



#### **`webhook_events`** 

_Inbox for inbound webhooks. Store first, process asynchronously, replay safely._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`connection_id`|uuid FK||
|`event_type`|text||
|`external_event_id`|text|UNIQUE per connection (idempotency)|
|`payload`|jsonb||
|`signature_valid`|boolean|invalid events are stored but never processed|
|`status`|text|pending / processed / failed / ignored / dead|
|`attempts`|int|exponential backoff, then 'dead'|
|`error`|text||
|`received_at /`<br>`processed_at`|timestamptz||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 19 

#### **`external_refs`** 

_Maps our records to the other system's IDs._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`connection_id`|uuid FK||
|`entity_type`|text|contact / order / product / shipment|
|`entity_id`|uuid||
|`external_id`|text||
|`external_data`|jsonb||
|**UNIQUE**|(connection_id, entity_type,<br>external_id)||



#### **`import_jobs`** 

_CSV/XLSX imports (contacts, products, orders) with column mapping and an error report._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`type`|text|contacts / products / orders|
|`file_id`|uuid FK files||
|`mapping`|jsonb|source column -> field|
|`status`|text|uploaded / validating / running / done / failed|
|`rows_total /`<br>`rows_ok /`<br>`rows_failed`|int||
|`error_report_file_i`<br>`d`|uuid FK files NULL||



#### **`api_keys`** 

_For custom stores calling the public REST API._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`name`|text||
|`key_prefix`|text|shown in UI|
|`key_hash`|text|full key shown once at creation|
|`scopes`|text[]|orders:write, contacts:write, products:read ...|
|`last_used_at /`|timestamptz||
|`revoked_at`|||



#### **`message_templates`** 

_WhatsApp-approved templates (confirmation, delivery notice)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`connection_id`|uuid FK||
|`name / language`|text||
|`purpose`|text|order_confirmation / delivery_update / followup|
|`body`|text|with {{variables}}|
|`status`|text|draft / submitted / approved / rejected|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 20 

### **4.8 F. Client portal and public presence** 

#### **`business_profiles`** 

_The public page of a business._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`business_id`|uuid UNIQUE FK||
|`headline / about`|text||
|`logo_file_id /`<br>`cover_file_id`|uuid FK files||
|`gallery`|uuid[]|file ids|
|`opening_hours`|jsonb||
|`social_links`|jsonb||
|`categories`|text[]||
|`is_published`|boolean|default false until owner publishes|
|`show_products`|boolean||
|`rating_avg /`<br>`rating_count`|numeric(3,2) / int|denormalised (Bayesian average, Section 7.1)|



#### **`reviews`** 

_Client -> business only. Public text opinions about clients do not exist in this system._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`business_id`|uuid FK||
|`author_user_id`|uuid FK users||
|`basis`|text|'order' / 'conversation'|
|`order_id /`<br>`conversation_id`|uuid FK NULL||
|`rating`|smallint|1-5|
|`title / body`|text||
|`status`|text|published / hidden / removed|
|`moderation_reason`|text||
|`edited_at`|timestamptz||
|**UNIQUE**|(author_user_id, order_id),<br>(author_user_id,<br>conversation_id)|one review per interaction|



#### **`review_replies / review_reports`** 

_A single business reply per review; user reports for moderation._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`review_replies.revi`|uuid UNIQUE FK||
|`ew_id`|||
|`review_replies.memb`|uuid / text||
|`er_id / body`|||
|`review_reports.revi`|uuid / uuid||
|`ew_id /`|||
|`reporter_user_id`|||
|`review_reports.reas`|text / text|open / dismissed / actioned|
|`on / status`|||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 21 

#### **`conversations`** 

_A thread between a business and a person: in-app (client account) or WhatsApp (contact only)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`contact_id`|uuid FK contacts|the CRM contact (auto-created/linked)|
|`client_user_id`|uuid FK users NULL|NULL for WhatsApp-only threads|
|`channel`|text|in_app / whatsapp|
|`status`|text|open / closed|
|`assigned_member_id`|uuid FK NULL||
|`last_message_at`|timestamptz||
|**UNIQUE**|partial (business_id,<br>client_user_id) WHERE<br>channel='in_app'||



#### **`messages`** 

_Messages in a conversation. Each message also yields an interaction row for the timeline._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`conversation_id`|uuid FK||
|`sender_type`|text|client / member / system / external|
|`sender_user_id`|uuid FK NULL||
|`body`|text||
|`attachment_file_ids`|uuid[]||
|`external_message_id`|text|WhatsApp message id for dedup|
|`status`|text|sent / delivered / read / failed|
|`sent_at / read_at`|timestamptz||



### **4.9 G. Platform** 

#### **`files`** 

_Metadata for uploaded files (object storage holds the bytes)._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`business_id`|uuid NULL|NULL for user-level files (avatars)|
|`uploader_user_id`|uuid FK||
|`storage_key`|text||
|`mime / size_bytes /`|text / bigint / text||
|`sha256`|||
|`purpose`|text|avatar / product_image / evidence / label / import / attachment|



#### **`notifications`** 

_In-app and email notifications._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`user_id`|uuid FK||
|`business_id`|uuid NULL||
|`type`|text|new_message / order_confirmed / delivery_failed / review_posted / invite ...|
|`payload`|jsonb||
|`channel`|text|in_app / email|
|`read_at / sent_at`|timestamptz||



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 22 

#### **`audit_logs`** 

_Append-only. Written for every sensitive action._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`actor_user_id`|uuid FK NULL|NULL for system|
|`business_id`|uuid NULL||
|`action`|text|e.g. order.status_changed, member.permission_changed, signal.invalidated|
|`entity_type /`<br>`entity_id`|text / uuid||
|`diff`|jsonb||
|`ip`|inet||
|`occurred_at`|timestamptz||



#### **`feature_flags`** 

_Controls risky features. 'global_score_visible' ships OFF._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`key`|text||
|`scope`|text|global / business|
|`business_id`|uuid NULL||
|`enabled`|boolean||
|**UNIQUE**|(key, scope, business_id)||



#### **`wilayas`** 

_Reference list of Algerian wilayas (code, ar/fr names). Communes as a second table if you need address dropdowns._ 

|**Column**|**Type**|**Notes**|
|---|---|---|
|`code`|smallint PK|1..58**[Likely]**|
|`name_ar / name_fr`|text||



### **4.10 Required indexes and extra constraints** 

- `contact_phones (business_id, phone_e164)` UNIQUE; `phone_identities (phone_hash)` UNIQUE; `webhook_events (connection_id, external_event_id)` UNIQUE; `external_refs (connection_id, entity_type, external_id)` UNIQUE; `orders (business_id, order_number)` UNIQUE. 

- `contacts (business_id, last_interaction_at DESC)` ; `orders (business_id, status, placed_at DESC)` ; `orders (business_id, contact_id)` ; `interactions (business_id, contact_id, occurred_at DESC)` ; `phone_signals (phone_identity_id, occurred_at)` ; partial index on `webhook_events (received_at) WHERE status='pending'` . 

- Foreign keys from orders/history use `ON DELETE RESTRICT` ; cascade only for pure children (items, images, tags links). 

- A trigger or application-level transaction guard enforces 'business has at least one active owner'. 

- A `CHECK` ensures `reviews.rating BETWEEN 1 AND 5` and that exactly one of `order_id` / `conversation_id` is set according to `basis` . 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 23 

## **5. Business logic** 

### **5.1 Authentication and onboarding** 

- **Register:** email + password (argon2id, minimum length enforced, breached-password check optional) or Google OAuth. Email verification is required before creating a business or posting a review. Google sign-in marks the email verified. Both methods link to one `users` row by verified email. 

- **Business creation:** any verified user can create a business; it starts `pending` (or `active` with limits, a product decision). The creator becomes `owner` . The onboarding wizard asks: business type (B2C/B2B/both), sector, wilaya, and which tools they use (manual, CSV, Shopify, WhatsApp, a carrier). That choice only sets which integration cards are highlighted. 

- **Staff invitation:** owner enters email + preset/permissions; invitation email carries a single-use token. Accepting requires login or sign-up with that email. Revocation is immediate (session claims are re-checked against `business_members.status` on each request). 

- **Client registration:** same signup; user picks B2C/B2B; creates a `client_profiles` row. A person can be both client and staff with one account. 

- **Phone ownership is proven separately [Certain].** Email or Google login proves nothing about a phone number, and the score is keyed on phone numbers. A client links `phone_identity_id` only after proof: a WhatsApp/SMS OTP, or by completing a confirmation link that was delivered to that number. Until proven, the client cannot see order history, scores, or file disputes, and cannot leave an order-based review. 

- Rate limits on login, signup, OTP and password reset; session refresh-token rotation; suspended users are rejected at the session layer. 

### **5.2 Phone normalisation and contact handling** 

- Normalise on input to E.164: strip spaces, dashes and dots; accept `05XXXXXXXX` , `5XXXXXXXX` , `+2135XXXXXXXX` , `002135XXXXXXXX` for mobiles (prefixes 5, 6, 7 after +213) **[Likely]** ; treat other numbers as landline or international and flag `line_type` . Validate with a library (for example libphonenumber) rather than hand-written regex. 

- On creating a `contact_phones` row: compute HMAC hash, upsert `phone_identities` , link. The same number typed three ways must resolve to one identity. 

- **Duplicate detection:** if `(business_id, phone_e164)` exists, offer 'open existing contact' or 'merge'. Merge moves phones, interactions, orders, opportunities, tags to the surviving contact, sets `merged_into_id` on the loser, and writes an audit entry. 

- **Quick-add:** a phone number alone is enough to create a contact (name optional). This is essential for sellers who start from a WhatsApp message. 

- B2B contacts require `organization_name` ; B2C do not. Custom fields are validated against `custom_field_definitions` on write. 

- `contacts.last_interaction_at` is updated by whichever service writes an interaction. 

### **5.3 Pipeline and opportunities** 

- Each business gets a default pipeline: New, Contacted, Quote sent, Negotiation, Won, Lost (editable). Stage types `won` and `lost` close the opportunity and stamp `won_at` / `lost_at` ; `lost` requires a reason. 

- **Convert to order:** a button on an opportunity creates a draft order prefilled with contact, phone and expected value, and sets `opportunities.order_id` . Moving to a `won` stage does not create an order automatically, to avoid phantom orders. 

- COD sellers often skip the pipeline: an order created directly (or via webhook) can auto-create a won opportunity for reporting, controlled by a business setting. 

### **5.4 Calls and call dispositions** 

V1 captures call behaviour through structured manual logging in the call workbench (Section 8). Later, telephony can fill the same fields automatically without a schema change ( `telemetry_source` ). 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 24 

- Each call is an `interactions` row (type `call` ) plus a `call_logs` row. Calls for the same purpose (e.g. confirming order #123) share an `attempt_group_id` ; `attempt_no` increments automatically. 

- Dispositions: `answered` , `no_answer` , `busy` , `switched_off` , `rejected` , `wrong_number` , `voicemail` . If `answered` , an outcome is required: `confirmed` , `cancelled` , `postponed` , `callback_requested` , `undecided` . 

- `callback_requested` creates a task at the requested time. `wrong_number` flags the phone on that contact and emits no negative signal. 

- **Escalation rule (business-configurable, default):** after 3 unanswered attempts spread across at least 2 different time windows (for example morning and evening, or two different days), the workbench proposes 'mark unreachable and cancel'. A human clicks; nothing auto-cancels. 

- Signals are emitted by a post-commit handler: `answered_on_attempt_n` , `never_answered` , `callback_fast` (customer rings back within 2 hours of a missed call, if the business logs inbound calls). 

### **5.5 Order lifecycle (state machine)** 

Statuses: `draft` , `pending_confirmation` , `confirmed` , `processing` , `shipped` , `out_for_delivery` , `delivered` , `delivery_failed` , `return_in_transit` , `returned` , `cancelled` . Transitions are validated server-side; anything not listed is rejected. 

|**From -> To**|**Trigger**|**Actor / source**|**Side effects**|
|---|---|---|---|
|draft -><br>pending_confirmation|Order saved with confirmation<br>required (default for COD)|Agent, integration|Create`confirmation_requests`(link) and a<br>`confirm_order`task; store<br>`risk_snapshot_id`|
|draft -> confirmed|Agent confirms immediately<br>(customer present, or policy allows<br>auto-confirm for tier A)|Agent|`confirmed_via='manual'`|
|pending_confirmation -><br>confirmed|Call outcome`confirmed`, or link<br>confirmed, or WhatsApp reply 'yes'|Agent, customer link,<br>WhatsApp|Signals`confirmation_link_completed`/ call<br>signals; consent stored if captured; stock reserved|
|pending_confirmation -><br>cancelled|Customer rejects, or agent accepts<br>the escalation proposal, or<br>confirmation expired|Agent, customer, system<br>(expiry after N days,<br>default 3)|Stock released;`never_answered`signal if<br>applicable; outcome neutral or customer-weak per<br>5.5.2|
|confirmed -> processing|Order packed|Agent|Stock decremented|
|confirmed / processing<br>-> shipped|Shipment created via carrier API, or<br>tracking number entered|Agent, carrier adapter|`shipments`row;`shipped_at`; customer notified<br>(WhatsApp/in-app)|
|shipped -><br>out_for_delivery|Carrier reports out for delivery|Carrier API / webhook /<br>manual|Optional heads-up message to customer|
|out_for_delivery -><br>delivered|Carrier reports delivered, or agent<br>marks delivered|Carrier API / manual<br>(proof optional)|`outcome_class=success`; payment<br>`collected`; signal`delivered_success`; review<br>invitation scheduled|
|shipped /<br>out_for_delivery -><br>delivery_failed|Failed attempt reported|Carrier / manual|Failure reason required (5.5.2); may return to<br>`out_for_delivery`on retry|
|delivery_failed -><br>return_in_transit|Carrier returns parcel or business<br>stops retries|Carrier / agent|`return_cases`row opened|
|return_in_transit -><br>returned|Parcel physically received back|Agent (must confirm)|`outcome_class`set from fault; signals emitted;<br>restock prompt|
|delivered -><br>return_in_transit|Post-delivery return within window<br>(default 7 days)**[Guessing]**|Agent|Reason code required|
|any pre-ship status -><br>cancelled|Cancelled before shipping|Agent (`orders.cancel`)|Release stock; classify per 5.5.2|



#### **5.5.1 Transition rules** 

- Every transition writes `order_status_history` (source, actor, external event id, optional evidence) and an audit entry. Integration events are idempotent on `external_event_id` . 

- Carrier events cannot move an order backwards (for example `delivered` -> `shipped` ); such anomalies are stored in `shipment_events` , flagged, and surfaced in an anomaly list, not applied. 

- Manual terminal transitions ( `delivered` , `returned` ) are stored with provenance `manual_unverified` unless evidence is attached, which upgrades to `manual_with_proof` . 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 25 

- Terminal orders are immutable except for members with `orders.override_status` ; an override requires a note, rewrites provenance, and triggers invalidation and recomputation of the affected signals. 

- A rejected business-side status change returns a specific error code the UI can explain (e.g. `ORDER_ALREADY_TERMINAL` ). 

#### **5.5.2 Outcome classification (what the score reads)** 

|**Terminal situation**|**Fault**|**outcome_class**|**Signal emitted**|**Weight**|
|---|---|---|---|---|
|Delivered and collected|-|success|`delivered_success`|1.0|
|Refused at the door|customer|customer_failure|`refused_at_door`|1.0 (strongest negative)|
|Unreachable after confirmation (2+<br>delivery attempts)|customer|customer_failure|`unreachable_after_confirm`|1.0|
|Absent on repeated attempts|customer|customer_failure|`absent_repeated`|0.7|
|Wrong address supplied by<br>customer|customer|customer_failure|`wrong_address`|0.5 (0 if business typed it)|
|Customer cancels after confirming,<br>before shipping|customer|customer_failure|`cancelled_after_confirm`|0.5|
|Wrong item, damaged, late delivery|business|business_failure|none|0|
|Parcel lost / carrier error|carrier|neutral|none|0|
|Wrong number or 'I never ordered'|third party|neutral|`identity_disclaimed`(flag<br>only)|0; raises 'suspected fake<br>order' flag on the business<br>side|
|Business cancels|business|neutral|none|0|



### **5.6 Confirmation link (the seriousness test)** 

1. On entering `pending_confirmation` , the system creates a `confirmation_requests` row with a single-use token (stored hashed) bound to the order and phone, expiring in 24-72 hours **[Guessing]** . 

2. Delivery: automatic WhatsApp template message (integrated mode) or a copyable link (manual mode). The page `/c/{token}` needs no login. 

3. The page shows the **real** recap: items, total, delivery fee, address, wilaya, delivery type. The customer can confirm, edit address or quantity, or reject. A consent checkbox (Arabic/French) covers CRM processing and, once enabled, score contribution; the exact text shown is stored in `consents.evidence` . 

4. Opening the link proves possession of that number. If the person is logged in (or signs up), this can set `client_profiles.phone_verified_at` . 

5. Outcome writes `confirmation_requests.result` , updates `orders.confirmation_status` , and emits signals: `confirmation_link_completed` (+), `confirmation_edited_details` (small +, shows engagement), `confirmation_link_ignored` (small -, if unopened after 48 hours and a call also failed). 

6. A sent-but-unopened link is **not** by itself proof of unseriousness; many customers simply do not read WhatsApp promptly. It carries a deliberately small weight. 

### **5.7 Returns** 

- A `return_cases` row opens when an order enters `delivery_failed` with no retry, or `return_in_transit` . The reason code comes from `return_reason_codes` ; `fault` defaults from the code and may be changed by a member with `returns.manage` , with a justification stored. 

- Receiving the parcel back is an explicit action ('Mark received'), followed by a restock decision: `restocked` (stock quantity +n) or `written_off` . 

- `cost_amount` captures return shipping and lost fees for analytics (return cost by wilaya, carrier, channel, staff member, product). 

- Changing fault after the fact (for example business admits it shipped the wrong item) invalidates the earlier customer-failure signal and triggers recomputation. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 26 

### **5.8 Integrations** 

#### **5.8.1 Adapter interface and event inbox** 

- Every provider implements: `connect()` , `verifyWebhook(request)` , `normalizeEvent(raw)` , `push(entity)` (for example create a shipment), `pull(since)` (polling fallback), `healthcheck()` . 

- Inbound webhooks are written to `webhook_events` first (with signature result), acknowledged immediately, then processed by a worker. Failures retry with exponential backoff and end in `dead` , visible and re-playable in the Integrations screen. 

- Normalised domain events: `contact.upserted` , `order.created` , `order.updated` , `shipment.status_changed` , `message.received` , `message.status_changed` . All handlers are idempotent via `external_refs` and `external_event_id` . 

- Credentials live in `integration_connections.credentials_encrypted` (envelope encryption), are never returned by any API, and never written to logs. 

- Per-connection health: last successful sync, last error, queue depth. A failing integration raises an in-app notification to owners. 

#### **5.8.2 Connectors in V1** 

|**Connector**|**Mechanism**|**Key behaviour**|**What is verified**|
|---|---|---|---|
|Manual / CSV /<br>XLSX|Forms; import wizard with<br>column mapping and dry-run|All fields optional except phone for contacts; errors<br>exported as a downloadable report|**[Certain]**our own design|
|Custom store /<br>API|REST API with API keys<br>(scoped) + outbound webhooks|`POST /v1/orders`with`Idempotency-Key`;<br>contacts and products endpoints; outbound<br>`order.status_changed`; signed webhooks|**[Certain]**our own design|
|Shopify|Admin API + webhooks<br>(`orders/create`,<br>`orders/updated`), HMAC<br>verification|Create or update contact and order; map shipping<br>address to wilaya; write status back as tag or note|**[Likely]**HMAC verification and<br>order webhooks are standard<br>Shopify features; confirm current<br>app scopes and review<br>requirements|
|WhatsApp<br>Cloud API|Webhooks for inbound<br>messages and statuses;<br>template messages outbound|Inbound messages become`messages`+<br>`interactions`in the unified inbox; confirmation<br>links sent via approved template; free-form replies<br>only inside the provider's customer-service window|**[Likely]**template/window rules;<br>**unverified:**onboarding for Algerian<br>businesses, template approval<br>times, pricing|
|Yalidine (and<br>other carriers)|Create parcel from a confirmed<br>order; statuses via polling or<br>webhook|COD amount sent with parcel; raw statuses stored,<br>mapped via`carrier_status_mappings`; terminal<br>statuses become`carrier_api`provenance|**[Guessing]**I have not verified<br>Yalidine's current API (auth, fields,<br>webhook availability). Read their live<br>docs before building; same adapter<br>pattern for ZR Express, Noest, etc.|



### **5.9 Notifications** 

- In-app + email in V1; WhatsApp notifications to customers only through approved templates. 

- Events: new message, order confirmed/rejected, delivery failed, return received, review posted, integration error, staff invitation, dispute update, consent withdrawn. 

- Per-user preferences for channel per event type; owners always receive integration errors. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 27 

## **6. Contact scoring** 

### **6.1 Principles** 

- Score = probability-like estimate (0-100) that a delivery to this phone number ends in `delivered` rather than refusal, return or ghosting, **attributable to the customer** . 

- Always shown with **confidence** and **reason codes** . A number with one order and a number with fifty orders must not look equally certain. 

- V1 computes a **private score per business** from that business's own history with that phone, using platform-wide priors only. Global scores are computed by the same code but are hidden (flag OFF) until the legal gate in 6.7 is passed. 

- Rules are transparent and versioned ( `score_models` ). Recompute is deterministic from `phone_signals` ; any dispute outcome can be replayed. 

### **6.2 Signal catalogue** 

|**Signal**|**Trigger**|**Effect**|**Starting value [Guessing]**|
|---|---|---|---|
|`call_answered_attem`<br>`pt_1`|Confirmation call answered on first attempt|Behaviour +|+4 pts|
|`call_answered_attem`<br>`pt_2`|Answered on second attempt|Behaviour +|+2 pts|
|`call_answered_attem`<br>`pt_3plus`|Answered only on third or later attempt|Behaviour -|-3 pts|
|`call_never_answered`|3+ attempts across 2+ time windows, never<br>answered|Behaviour -|-6 pts|
|`callback_fast`|Customer calls back within 2h of missed call|Behaviour +|+2 pts|
|`confirmation_link_c`<br>`ompleted`|Link confirmed within 24h|Behaviour +|+5 pts|
|`confirmation_edited`<br>`_details`|Customer corrected address/quantity on link|Behaviour +|+1 pt|
|`confirmation_link_i`<br>`gnored`|Sent, unopened after 48h and call also failed|Behaviour -|-2 pts|
|`delivered_success`|Order delivered and cash collected|Outcome (success)|weight 1.0|
|`refused_at_door`|Customer refused delivery|Outcome (failure)|weight 1.0|
|`unreachable_after_c`<br>`onfirm`|Confirmed order, unreachable on delivery|Outcome (failure)|weight 1.0|
|`absent_repeated`|Absent at repeated attempts|Outcome (failure)|weight 0.7|
|`wrong_address`|Customer-supplied address unusable|Outcome (failure)|weight 0.5|
|`cancelled_after_con`<br>`firm`|Customer cancels after confirming|Outcome (failure)|weight 0.5|
|`identity_disclaimed`|'Wrong number' / 'I never ordered'|Flag only|weight 0|



### **6.3 Computation** 

**Outcome component.** Over all attributable outcomes of a phone: `S_out = 100 x (D + a) / (N + a + b)` where `D` = sum of weights of successes, `N` = sum of weights of all attributable outcomes (success + customer failures), and `a` , `b` are prior pseudo-counts (start `a=2.1` , `b=0.9` , a 70% prior worth 3 orders) **[Guessing]** . A small prior stops one bad event from condemning a number while letting a second or third event move the score decisively. 

**Weight of each outcome:** `w = w_outcome x w_provenance x w_recency x w_trust` . Provenance: `carrier_api` 1.0, `system` 1.0, `webhook_verified` 0.9, `manual_with_proof` 0.6, `manual_unverified` 0.3. Recency: `0.5 ^ (age_days / 180)` (half-life 180 days). Trust: `businesses.trust_weight` (constant inside a private score, relevant for the global score). Business- and carrier-fault outcomes have `w = 0` . 

**Behaviour modifier.** `M = clamp(sum of signal points over the contact's last 5 orders, -15, +10)` . 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 28 

**Final:** `score = clamp(S_out + M, 0, 100)` . **Effective n** = `N` . **Confidence:** none (N = 0), low (0 < N < 2), medium (2 <= N < 5), high (N >= 5). 

**Tiers:** A >= 80, B 60-79.9, C 40-59.9, D < 40, and UNSCORED when confidence is none (displayed as 'New customer', not as a number). 

#### **Worked examples (all outcomes carrier-verified, same business)** 

|**Customer history**|**D**|**N**|**S_out**|**Tier / confidence**|
|---|---|---|---|---|
|1 delivered (10 days ago, w=0.96) + 1 refused at<br>door (40 days ago, w=0.86)|0.96|1.82|100 x (0.96+2.1)/(1.82+3) = 63.5|B / low|
|2 refusals at the door (w=0.96 and 0.86)|0|1.82|100 x 2.1/4.82 = 43.6|C / low|
|3 deliveries (w ~0.9 each)|2.7|2.7|100 x 4.8/5.7 = 84.2|A / medium|
|No history|0|0|-|UNSCORED / none|



**These parameters are placeholders [Guessing].** The shape (smoothed rate, provenance, recency, fault split, capped behaviour modifier) is the design; the numbers must be calibrated on real outcomes. Log every computation input so you can backtest: for each tier, what share of orders actually came back? A tier D that returns 40% and a tier A that returns 5% is the target; if the tiers do not separate, the weights are wrong. Adopt a model only if it beats the rule-based baseline. 

### **6.4 Risk policy (what businesses do with the score)** 

- Business setting `risk_policy` maps tier -> recommended actions. Defaults: **A** allow auto-confirm; **B** send confirmation link; **C** link + mandatory phone call; **D** link + call + manager approval before shipping (and, when available, prefer stop-desk pickup). 

- UNSCORED: link only. The UI shows the recommendation as a banner on the order; the user applies it. No automatic cancellation or refusal, ever [Guessing on legal necessity; keep it regardless, it is the safer design]. 

- The score at creation time is stored in `orders.risk_snapshot_id` so you can later measure how well the score predicted that very order. 

### **6.5 Anti-abuse and fairness** 

- **Provenance weighting** limits what a false manual report can do (0.3). 

- **One outcome signal per order** , and only for orders that exist for at least a minimum period and reached a terminal state through the state machine. 

- **Velocity limits:** reject or flag when a business creates many orders for the same phone in a short time, or many orders ending in failure for many different phones (sabotage pattern). 

- **Business trust weight:** new businesses (< 30 days or < 20 terminal orders) start at 0.5; web_master can raise or zero it. A business flagged for abuse can have all its signals invalidated in one action. 

- **Third-party number protection:** `wrong_number` and `identity_disclaimed` never lower a score; repeated disclaimers instead lower the **business's** trust weight if they come from the same business's orders, which exposes fake-order fraud or number typos. 

- **Dispute path:** a phone-verified client can contest a signal; upheld disputes flip `phone_signals.is_valid=false` and trigger recompute; the rejecting or upholding decision is logged with the web_master's identity. 

- **Nothing public about people.** Only businesses with `score.view` see a tier and reason codes, never raw history from other businesses, and never free-text opinions about a person. 

### **6.6 Recompute strategy** 

- Event-driven: any new or invalidated `phone_signals` row enqueues a recompute for that `(phone_identity_id, business_id)` and, if enabled, the global row. Recompute is idempotent and writes a new `score_snapshots` row, flipping `is_current` . 

- A nightly job applies recency decay and refreshes platform priors from the baseline return rate. 

- New `score_models` versions run in `shadow` mode first: scores are computed and stored but not shown, so you can compare them with the active model before switching. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 29 

### **6.7 Legal gate for the global score (must pass before enabling `global_score_visible`)** 

This is the highest-risk part of the product. The checklist below is what I would require before turning on any cross-business sharing. 

|**Item**|**Why**|**Status**|
|---|---|---|
|Written opinion from an Algerian data-protection<br>lawyer, covering Law 18-07 and its July 2025<br>amendment (Law 25-11)|Scoring and cross-business sharing are the core of<br>the processing|**[Certain]**that the law and<br>amendment exist;**opinion not**<br>**obtained**|
|Declaration or authorisation filed with the ANPDP<br>for each processing|Law 18-07 subjects processing to prior declaration<br>(art. 12 per public summaries)|**[Certain]**per public sources;<br>process to confirm with the lawyer|
|Express consent captured per person, with stored<br>evidence, Arabic/French wording, and a working<br>withdrawal path|Law 18-07 requires express consent and allows<br>withdrawal (art. 7 per public summaries)|Designed (`consents`, confirmation<br>link); wording not drafted|
|Cross-border transfer analysis for hosting|The ANPDP has to authorise transfers of personal<br>data out of Algeria; hosting abroad is a transfer|**[Certain]**that authorisation is<br>required per public summary;<br>hosting decision**open**|
|Retention periods and erasure behaviour for<br>`phone_signals`|Erasure vs. score integrity must be decided, not<br>improvised|Open|
|Access, rectification, dispute workflows live|Data-subject rights|Designed (`disputes`,<br>`data_subject_requests`), UI in<br>client portal|
|Business terms of service on contribution and use<br>of shared scores|Legal basis between platform and businesses|Open|
|k-anonymity threshold (default k=3) and 'tier only'<br>display|Limits re-identification of which business reported<br>what|Designed<br>(`contributing_businesses`)|
|Check whether a data protection officer is<br>required|A bill reported in the press would require one for each<br>entity**[Likely]**; status unknown to me|Open|
|Security review (encryption, access control,<br>logging)|Hashed numbers are still personal data in practice|Partly designed|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 30 

## **7. Client portal and public presence** 

### **7.1 Reviews** 

- **Eligibility [Certain, our rule]:** a client may review a business only after (a) a **delivered order** linked to their phone-verified identity, or (b) a **conversation** in which the client sent at least 2 messages and the business replied at least once. One review per order or conversation (unique constraints). 

- Reviews are published immediately (no pre-moderation) and can be reported; web_master reviews reports. Businesses cannot delete or hide reviews, only reply once ( `reviews.reply` ) and report. 

- Edit window for the author: 7 days **[Guessing]** ; edits are marked 'edited'. 

- **Displayed rating** is a Bayesian average to stop one 5-star review outranking fifty good ones: `(C x m + sum of ratings) / (C + n)` with `m` = platform mean rating and `C = 5` **[Guessing]** . Raw average and count are also shown. 

- Businesses can request reviews: after `delivered` , an invitation (in-app + optional WhatsApp template) links to the review form. Incentivised or gated review requests (only asking happy customers) are forbidden in the terms. 

- Reviews are **client to business only** . The business's opinion of a client exists only as scored behavioural signals, never as public or free text. 

### **7.2 Chat** 

- A client starts a conversation from a business profile ('Message'). The system creates or links the CRM `contacts` row (using the verified phone if available, otherwise an email-only contact) and a `conversations` row ( `channel='in_app'` ). 

- Staff with `inbox.reply` see it in the **unified inbox** , alongside WhatsApp threads ( `channel='whatsapp'` ). Messages are mirrored into `interactions` so the contact timeline is complete. 

- Delivery uses WebSocket or Server-Sent Events with polling fallback **[Likely]** ; unread counts; attachments (images, PDF) with size/type limits; email/in-app notifications for offline recipients. 

- Abuse handling: block/report conversation; web_master can review reported threads (break-glass rules apply). 

- **Honest expectation [Likely]:** businesses already live in WhatsApp. In-app chat will only get answered if notifications are reliable and the unified inbox makes replying as easy as WhatsApp. 

### **7.3 Business profile page** 

- Public URL `/b/{slug}` : logo, cover, headline, about, opening hours, wilaya, social links, verified badge, rating (Bayesian + count), public products (if enabled), reviews with business replies, and actions: Message, Call, WhatsApp, Report. 

- Unpublished by default; the owner previews and publishes. Suspended businesses disappear instantly. 

- V1 discovery: direct links and a basic search by name, wilaya and category. Ranking, recommendations and geo search are V2. 

### **7.4 Client's own data** 

- **My orders:** only orders whose phone identity matches the client's verified phone. Tracking timeline from `order_status_history` and shipment events. 

- **Privacy center:** list of consents and withdrawal buttons; request my data / correction / deletion ( `data_subject_requests` ); when the global score is enabled, **my score** with tier, reason codes and 'dispute this' per signal. 

- A client profile can be B2C or B2B; B2B clients add a company name and appear on the business side as a B2B contact. 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 31 

## **8. Frontend functionality** 

### **8.1 Global requirements** 

- **Languages:** Arabic (RTL) and French (LTR) from day one; English optional **[Likely]** . All strings through i18n; layout mirrors for RTL; numbers/dates localised; timezone Africa/Algiers; currency DZD. 

- **Mobile-first responsive web.** Sellers run their business from phones. Every business screen must be usable at 360 px width; the call workbench and order form are designed for one-hand use. 

- **Phone input component:** accepts Algerian formats, shows the normalised number, flags invalid input, detects duplicates live. 

- **Permission-aware UI:** hide or disable what the member cannot do, but never rely on the UI; the API enforces everything. 

- **Score badge component:** tier colour + confidence marker + tooltip with reason codes; shown consistently on contacts, orders, call workbench. 

- Empty states with a next action; skeleton loading; optimistic updates with rollback; undo for destructive actions where possible; accessible (keyboard, contrast, labels). 

### **8.2 Public and authentication screens** 

|**Screen**|**Key elements and actions**|
|---|---|
|Landing|Value proposition for businesses and clients; sign-up / login; search box for businesses|
|Sign-up / Login / Reset|Email+password, Google button, email verification, role intent (business or client), password reset|
|Business profile<br>`/b/{slug}`|Section 7.3: header, rating, products, reviews, Message/Call/WhatsApp, Report|
|Business search|Name, wilaya, category filters; result cards; links to profiles (V1-lite)|
|Confirmation page<br>`/c/{token}`|No login; mobile-first; real order recap; confirm / edit address & quantity / reject; consent checkbox; success state;<br>expired-token state|
|Tracking page|Order timeline by token or from the client area|



### **8.3 Client area** 

|**Screen**|**Key elements and actions**|
|---|---|
|Home|Active orders, recent conversations, prompts to review delivered orders|
|Orders and tracking|List, order detail with status timeline, business contact shortcut|
|Messages|Conversation list and thread; attachments; unread badge|
|Reviews|Write review (eligible items only), edit within window, see replies|
|Profile and phone<br>verification|Name, B2C/B2B, company, wilaya; add phone and verify via OTP or confirmation link|
|Privacy center|Consents with withdraw, data requests, my score + disputes (visible only when flag enabled)|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 32 

### **8.4 Business application** 

|**Screen**<br>Onboarding wizard|**Key elements and actions**<br>Business type, sector, wilaya, tools used; connect-now or later; invite team|**Permission**<br>owner|
|---|---|---|
|Dashboard|Today's orders to confirm, deliveries in progress, returns to receive, tasks, unread<br>messages; key rates (confirmation, delivery, return)|any|
|Contacts list|Search by name/phone, filters (tag, type, owner, tier, source), bulk tag/assign, import, export,<br>quick-add by phone|`contacts.read`|
|Contact detail|Header with score card (tier, confidence, reasons); phones; unified timeline; orders;<br>opportunities; tasks; notes; merge; custom fields|`contacts.read`|
|Pipeline board|Kanban by stage; drag to move; opportunity drawer; convert to order|`pipeline.manage`|
|Orders list|Filters: status, tier, carrier, channel, wilaya, date; bulk actions (send confirmation links,<br>create shipments, export)|`orders.read`|
|New order|Contact picker with live risk badge and recommended action; items and totals; delivery<br>type/wilaya/address; confirmation method; duplicate-order warning|`orders.write`|
|Order detail|Status stepper with allowed next actions; history; shipment and tracking; confirmation<br>request status; risk snapshot; return case; evidence upload; override with justification|`orders.read`|
|Call workbench|Queue of orders to confirm and deliveries to follow up; one-screen card: contact, score,<br>recap, call button (tel link), attempt counter, big disposition buttons, outcome, callback<br>scheduler, quick note; auto-advance to next; escalation proposal after 3 failed attempts|`calls.log`|
|Returns|List of open cases; reason and fault editor; mark received; restock/write-off; cost|`returns.manage`|
|Products|Catalogue, variants, images, stock, public toggle; CSV import|`products.manage`|
|Inbox|Unified in-app + WhatsApp threads; assign; templates; link to contact; unread|`inbox.reply`|
|Tasks|My tasks / team tasks; due soon; created from calls and orders|any|
|Reviews|List with filters; reply; report|`reviews.reply`|
|Public profile editor|Edit fields, upload media, choose public products, preview, publish/unpublish|`profile.edit`|
|Integrations|Provider cards with status, last sync, errors; connect flows; webhook/event log with replay;<br>carrier status mapping preview; API keys; WhatsApp templates|`integrations.manage`|
|Imports|Upload, mapping, dry-run, progress, error report download|`contacts.write`|
|Team|Invite, preset/permissions editor, data scope, revoke|`team.manage`|
|Analytics|Confirmation rate, delivery rate, return rate by wilaya / carrier / channel / staff / product;<br>attempts-to-confirm; score distribution; return cost|`analytics.view`|
|Settings|Business info, risk policy, order numbering, working hours and call windows, custom fields,<br>pipeline editor, notification preferences|owner|



### **8.5 Web master console** 

|**Screen**|**Key elements and actions**|
|---|---|
|Businesses|Approve, verify (badge), suspend, set`trust_weight`, view metrics; break-glass access request|
|Users|Search, suspend, force logout, view memberships|
|Review moderation|Reports queue; hide/restore with reason|
|Disputes|Queue; view signal context; uphold/reject with note; triggers recompute|
|Signal tools|Invalidate signals by business, order or time range; abuse patterns report|
|Carrier mappings|Edit raw status -> normalised status / outcome class|
|Score models|Versions, parameters, shadow vs active, backtest report|
|Feature flags|Global and per-business flags (`global_score_visible`default OFF)|
|Data subject requests|Queue with due dates|
|Audit log|Filter by actor, business, action, entity; export|
|Reference data|Wilayas, return reason codes, categories|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 33 

## **9. Non-functional requirements** 

- **Security:** argon2id; HTTPS everywhere; short-lived access tokens + rotating refresh tokens; CSRF protection for cookie auth; rate limiting; encrypted integration credentials; secrets in a vault; signed webhooks verified; file uploads scanned and type-checked; PII never in logs. 

- **Isolation:** RLS on all tenant tables; automated tests that try cross-tenant reads on every endpoint. 

- **Auditability:** audit log for permission changes, status overrides, signal invalidation, break-glass access, exports. 

- **Reliability:** webhook inbox with retries and dead-letter; idempotency keys on write APIs; daily backups with tested restore; migrations versioned. 

- **Performance (starting targets) [Guessing]:** list pages < 500 ms at 100k contacts per tenant; score read < 100 ms (always read the snapshot, never compute on request); webhook acknowledged < 1 s. 

- **Observability:** structured logs with request and tenant ids, error tracking, integration health dashboard, job-queue metrics. 

- **Data protection:** retention schedule per table; export and erasure tooling; consent evidence retention; documentation of processing for ANPDP. 

- **Hosting:** decide location early; it determines cross-border transfer obligations (Section 6.7). 

Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 34 

## **10. Build plan, acceptance criteria and open items** 

### **10.1 Suggested milestones** 

|**Milestone**|**Contents**|**Done when**|
|---|---|---|
|M0 Foundations|Auth (email, Google), tenancy, RLS, members/permissions, audit log,<br>i18n (ar/fr), file storage, CI with cross-tenant tests|Two businesses cannot see each other's data<br>under automated tests; staff permissions<br>enforced|
|M1 CRM core|Contacts, phones + normalisation + dedupe/merge, tags, custom fields,<br>pipelines, opportunities, interactions, tasks, CSV import|A seller can import 1,000 contacts and run a<br>pipeline|
|M2 Orders and<br>delivery|Products, orders, state machine, history, confirmation link page, manual<br>shipments, returns + fault codes, payments mock|Full COD flow works end to end by hand|
|M3 Scoring and<br>calls|Call workbench, call logs, signals, private score, tiers, risk policy, score<br>components in UI, backtest report|Every terminal order produces signals; tiers<br>visible on contacts and orders|
|M4 Integrations|Order: API keys + custom store API, Yalidine adapter, WhatsApp Cloud<br>API (confirmation + inbox), Shopify; event inbox, replay UI|A connected business needs no manual status<br>updates|
|M5 Client portal|Client area, phone verification, public profile, basic search, in-app chat,<br>reviews, privacy center|A client can find a business, chat, receive an<br>order, track it and review it|
|M6 Admin and<br>hardening|Web master console, disputes, moderation, flags, security review, load<br>tests, legal gate work in parallel|Pilot-ready; global score still OFF unless the<br>gate is passed|



### **10.2 V1 acceptance criteria** 

- A business can run entirely by hand (manual mode) and entirely through integrations, or a mix, with the same screens. 

- Entering the same phone in three formats yields one contact and one phone identity. 

- An order cannot reach an illegal status; every status change appears in history with source and actor. 

- A returned order with business fault produces no negative signal; a refusal at the door with carrier proof does. 

- A wrong-number outcome never changes a score. 

- Score badges always display tier, confidence and reasons; UNSCORED displays as 'New customer'. 

- Staff with `assigned_only` cannot see other members' contacts via UI or API. 

- Webhooks received twice produce one effect; invalid signatures are stored and ignored. 

- A client cannot review without a verified interaction; a business cannot delete a review. 

- Withdrawing consent and upholding a dispute both change the stored data and trigger recomputation. 

- No code path exposes another business's raw interactions, and `global_score_visible` is OFF by default. 

### **10.3 Open decisions and unverified items** 

|**#**|**Item**|**Owner / next step**|
|---|---|---|
|1|**Legal opinion**on Law 18-07 / Law 25-11 for scoring and cross-business sharing; ANPDP<br>declaration; consent wording (ar/fr)|Lawyer, before enabling global score|
|2|**Hosting location**and cross-border transfer authorisation|Decide before choosing a cloud provider|
|3|Yalidine (and ZR Express, Noest)**API specifics**(auth, parcel fields, status vocabulary,<br>webhooks)|Read live docs; fill<br>`carrier_status_mappings`|
|4|WhatsApp Cloud API onboarding, template approval, pricing for Algerian businesses;**OTP**<br>**channel**(WhatsApp vs SMS provider) cost and reliability|Spike before M4/M5|
|5|Scoring parameters (priors, weights, half-life, tier cut-offs)|Calibrate from pilot data; backtest per tier|
|6|Erasure behaviour for`phone_signals`and`phone_identities`|With the lawyer|
|7|Do new businesses start`pending`(manual approval) or`active`with limits?|Product decision|
|8|Languages beyond Arabic/French; Arabic copy for consent and legal text|Product + legal|
|9|Telephony integration for automatic call telemetry|V2; schema is ready|
|10|Primary go-to-market wedge (COD social sellers vs established B2B)|Determines default presets, onboarding and<br>pricing|



Algerian CRM - V1 Specification - Draft 0.1 - 5 Nov 2026 

Page 35 

