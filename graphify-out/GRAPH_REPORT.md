# Graph Report - reference  (2026-11-20)

## Corpus Check
- 5 files · ~393,259 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1120 nodes · 1683 edges · 94 communities (82 shown, 12 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 82 edges (avg confidence: 0.79)
- Token cost: 1,563,198 input · 0 output

## Community Hubs (Navigation)
- Schemas and Data Contracts
- Workflows, Sagas and FaaS
- CRM Implementation and Migration
- CDC, Outbox and Eventification
- CRM Reporting and Design
- Performance Measurement Linkage
- CRM Strategic Framework
- Spec: Global Phone Score Schema
- Spec: Identity and Tenancy
- CRM Concepts and Types
- Spec: Confirmation, Consent, Legal
- Multi-tenancy Models (Analysis)
- CRM Project Success Factors
- Stateful Streams and Partitioning
- Event Streams Fundamentals
- Spec: Integrations Schema
- Spec: Orders and Delivery
- CRM Application Functionality
- COD Reputation Market (Analysis)
- Event-Driven Microservice Basics
- Handling Bad Data
- Event Design and Materialization
- Deterministic Stream Processing
- Tech Decisions: Architecture Core
- Spec: CRM Core and Calls
- CLV, ACURA and Loyalty
- Customer Value Proposition
- CRM Audit and Shareholder Value
- Supportive Tooling
- Spec: Portal, Chat, Tenants
- CRM Governance and Change Control
- CRM Roadmap and Pillars
- Sources of CRM Value
- CRM Readiness and Maturity
- Information Management Process
- Competitor CRMs (Analysis)
- Heavyweight Framework Scaling
- Tech Decisions: Frontend and Auth
- CRM Pitfalls and Training
- Service, Portal and Licensing
- CRM Project Management
- Eventual Consistency Operations
- Event Types and Consistency
- Scoring Service Design (Analysis)
- Heavyweight Streaming Frameworks
- Kafka Streams Lightweight
- Spec: Platform, Audit, Notify
- CRM Administration Team
- Testing Environments and Micro-FE
- Streaming SQL
- Testing and Deployment Patterns
- Consumer Groups and State
- Tech Decisions: Survival Rules
- Spec: Frontend and Risk Policy
- Segmentation and Trade-off
- Industry and Vision Analysis
- Algerian Data Law (Analysis)
- Bayesian Score and OTP (Analysis)
- Algerian Carriers (Analysis)
- Tech Decisions: Data and Events
- Spec: Eight Design Decisions
- Data Mining and Analytics
- CRM Strategy Matrix
- Generic Strategy Frameworks
- Single Customer View Cases
- Algerian Phone Normalisation
- DDD and Bounded Contexts
- Microservice Tax and Containers
- Tech Decisions: Spikes and Inbox
- CRM Hosting and Environments
- Employee Engagement
- Multi-channel Strategy
- CRM Change Management
- Outbox and Webhook Idempotence
- Apache Flink
- Breaking Schema Changes
- Conway and Communication
- Event Sourcing and Logs
- Delta Events and Lambda
- Channel Options
- Customer Experience
- CRM Project Plan
- CRM Metrics and KPIs
- One-to-one Marketing
- Request-Response Coupling
- Windowing
- Vendor Contracts
- Misc 88
- Misc 89
- Misc 90
- Misc 91
- Misc 92
- Misc 93

## God Nodes (most connected - your core abstractions)
1. `Analyse approfondie des CRM existants (CRM e-commerce algerien)` - 27 edges
2. `Algerian CRM V1 Specification` - 25 edges
3. `Customer Relationship Management (CRM)` - 19 edges
4. `Chapter 19: Supportive Tooling` - 16 edges
5. `Performance Assessment Process` - 15 edges
6. `Schema Registry` - 14 edges
7. `Score global de fiabilite par numero de telephone` - 14 edges
8. `Streaming SQL` - 12 edges
9. `Change-Data Capture` - 12 edges
10. `Durable Execution Engine` - 12 edges

## Surprising Connections (you probably didn't know these)
- `CRM Algeria V1 Specification` --semantically_similar_to--> `Algerian CRM V1 Specification`  [INFERRED] [semantically similar]
  CRM_Algeria_Technology_Decisions_v0.2.md → CRM_Algeria_V1_Specification.md
- `In-App Chat and Unified Inbox` --conceptually_related_to--> `messaging service`  [INFERRED]
  CRM_Algeria_V1_Specification.md → CRM_Algeria_Technology_Decisions_v0.2.md
- `Group C: CRM Core` --conceptually_related_to--> `crm service`  [INFERRED]
  CRM_Algeria_V1_Specification.md → CRM_Algeria_Technology_Decisions_v0.2.md
- `Operational Data Store (ODS)` --conceptually_related_to--> `Data Warehouse`  [EXTRACTED]
  Handbook of CRM.md → CRM_funcamentals.md
- `Integration Adapter Interface` --conceptually_related_to--> `integrations service`  [INFERRED]
  CRM_Algeria_V1_Specification.md → CRM_Algeria_Technology_Decisions_v0.2.md

## Hyperedges (group relationships)
- **JWT with BFF Authentication Flow** — crm_algeria_technology_decisions_v0_2_nuxt_bff, crm_algeria_technology_decisions_v0_2_openiddict, crm_algeria_technology_decisions_v0_2_jwt_token_design, crm_algeria_technology_decisions_v0_2_oidc_code_pkce, crm_algeria_technology_decisions_v0_2_yarp_gateway, crm_algeria_technology_decisions_v0_2_valkey [EXTRACTED 1.00]
- **Event Messaging Reliability Pattern** — crm_algeria_technology_decisions_v0_2_rabbitmq, crm_algeria_technology_decisions_v0_2_transactional_outbox, crm_algeria_technology_decisions_v0_2_idempotent_consumer_inbox, crm_algeria_technology_decisions_v0_2_cloudevents_envelope, crm_algeria_technology_decisions_v0_2_wolverine [EXTRACTED 1.00]
- **Eight-service Map Staged by Milestone** — crm_algeria_technology_decisions_v0_2_identity_access_service, crm_algeria_technology_decisions_v0_2_crm_service, crm_algeria_technology_decisions_v0_2_orders_service, crm_algeria_technology_decisions_v0_2_scoring_service, crm_algeria_technology_decisions_v0_2_integrations_service, crm_algeria_technology_decisions_v0_2_messaging_service, crm_algeria_technology_decisions_v0_2_presence_service, crm_algeria_technology_decisions_v0_2_platform_service [EXTRACTED 1.00]
- **Event stream properties enabling state sharing** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_event_stream, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_event_immutability, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_partition, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_offset, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_indefinite_and_tiered_storage [EXTRACTED 1.00]
- **State sharing via entity events** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_entity_event, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_event_carried_state_transfer, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_materialization, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_stream_table_duality, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_tombstone, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_event_stream_compaction [EXTRACTED 1.00]
- **Data contract components** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_data_contract, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_schema, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_service_level_objectives, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_field_level_encryption, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_schema_evolution, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_schema_registry [EXTRACTED 1.00]
- **Data Liberation Patterns** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_query_based_data_liberation, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_change_data_capture, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_transactional_outbox, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_change_data_capture_triggers [EXTRACTED 1.00]
- **Event Type Taxonomy** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_state_event, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_delta_event, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_hybrid_event, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_measurement_event, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_notification_event [EXTRACTED 1.00]
- **Effectively Once Mechanisms** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_client_broker_transactions, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_idempotent_writes, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_deduplication_store, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_state_store_transactions_with_offsets [EXTRACTED 1.00]
- **Microservice Workflow Patterns** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_choreography_pattern, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_orchestration_pattern, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_saga_pattern_distributed_transactions, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_compensation_workflow_pattern, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_durable_execution_engine [EXTRACTED 1.00]
- **Event-Driven Microservice Framework Options** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_basic_producer_and_consumer_bpc_microservice, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_heavyweight_streaming_framework, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_lightweight_streaming_framework, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_streaming_sql, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_functions_as_a_service_faas [EXTRACTED 1.00]
- **Stateful Recovery Mechanisms** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_checkpoints, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_changelog_streams, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_hot_replicas, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_state_restoration_phase, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_durable_append_only_log [INFERRED 0.85]
- **Bad Data Handling Strategies (prevent, event design, rewind)** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_prevention_of_bad_data, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_fix_it_once_and_fix_it_right_with_state_events, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_build_forward_with_undo_deltas, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_rewind_rebuild_and_retry [EXTRACTED 1.00]
- **Event-Driven Microservice Deployment Patterns** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_basic_full_stop_deployment_pattern, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_rolling_update_pattern, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_breaking_schema_change_pattern, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_blue_green_deployment_pattern [EXTRACTED 1.00]
- **Remote Integration Testing Environment Options** — building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_temporary_single_tenant_testing_environment, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_durable_multitenant_testing_environment, building_event_driven_microservices__leveraging____adam_bellemare____2__2025_oct_21____o_reilly_media____b9d99e8ae80161679388dbe8a33c8c22____anna_s_archive_testing_in_production [EXTRACTED 1.00]
- **Five cross-functional CRM processes of the Strategic Framework** — handbook_of_crm_strategic_framework_for_crm, handbook_of_crm_strategy_development_process, handbook_of_crm_value_creation_process, handbook_of_crm_multi_channel_integration_process, handbook_of_crm_information_management_process, handbook_of_crm_performance_assessment_process [EXTRACTED 1.00]
- **Four CRM strategy matrix positions** — handbook_of_crm_crm_strategy_matrix, handbook_of_crm_product_based_selling, handbook_of_crm_managed_service_and_support, handbook_of_crm_customer_based_marketing, handbook_of_crm_individualized_crm [EXTRACTED 1.00]
- **Operational, analytical and collaborative CRM integration** — handbook_of_crm_operational_crm, handbook_of_crm_analytical_crm, handbook_of_crm_collaborative_crm [EXTRACTED 1.00]
- **ACURA profit levers** — handbook_of_crm_customer_acquisition, handbook_of_crm_cross_selling, handbook_of_crm_upselling, handbook_of_crm_customer_retention, handbook_of_crm_customer_advocacy [EXTRACTED 1.00]
- **CRM data repository technology levels** — handbook_of_crm_tactical_database_and_dss, handbook_of_crm_data_mart, crm_funcamentals_data_warehouse, handbook_of_crm_integrated_crm_solution [EXTRACTED 1.00]
- **Key drivers of shareholder results** — handbook_of_crm_employee_value, handbook_of_crm_value_customer_receives, handbook_of_crm_shareholder_value, handbook_of_crm_cost_reduction [EXTRACTED 1.00]
- **Four Elements of Organizing for CRM Implementation** — handbook_of_crm_crm_readiness_assessment, handbook_of_crm_crm_change_management, handbook_of_crm_crm_project_management, handbook_of_crm_employee_engagement [EXTRACTED 1.00]
- **Five Stages of CRM Maturity** — handbook_of_crm_pre_crm_planning, handbook_of_crm_building_a_data_repository, handbook_of_crm_moderately_developed_crm, handbook_of_crm_well_developed_crm, handbook_of_crm_highly_advanced_crm [EXTRACTED 1.00]
- **Employee-Customer-Shareholder Linkage Models** — handbook_of_crm_service_profit_chain, handbook_of_crm_employee_customer_profit_chain, handbook_of_crm_nortel_business_value_cycle, handbook_of_crm_balanced_scorecard [INFERRED 0.85]
- **CRM Enhancement Processes (change control + roadmap)** — crm_funcamentals_change_control_process, crm_funcamentals_crm_roadmap, crm_funcamentals_steering_committee, crm_funcamentals_crm_administration_team [EXTRACTED 1.00]
- **Core CRM Suite: marketing, sales, service** — crm_funcamentals_marketing_functionality, crm_funcamentals_sales_functionality_sfa, crm_funcamentals_service_functionality_cases, crm_funcamentals_customer_records_accounts_and_contacts [EXTRACTED 1.00]
- **Service maturity path: issue tracking, knowledge base, self-service** — crm_funcamentals_service_functionality_cases, crm_funcamentals_knowledge_base, crm_funcamentals_customer_self_service_portal [EXTRACTED 1.00]
- **Data Migration Mapping Levels** — crm_funcamentals_entity_mapping, crm_funcamentals_field_mapping, crm_funcamentals_value_mapping [EXTRACTED 1.00]
- **CRM Application Testing Types** — crm_funcamentals_unit_testing, crm_funcamentals_system_testing, crm_funcamentals_integration_testing, crm_funcamentals_performance_testing, crm_funcamentals_user_acceptance_testing_uat, crm_funcamentals_regression_testing [EXTRACTED 1.00]
- **Design Stage Deliverables** — crm_funcamentals_as_is_process_definition, crm_funcamentals_to_be_process_definition, crm_funcamentals_business_rules_and_escalations, crm_funcamentals_use_case_definition, crm_funcamentals_functional_specification, crm_funcamentals_technical_specification [EXTRACTED 1.00]
- **COD order outcome to risk score flow** — crm_algeria_v1_specification_order_state_machine, crm_algeria_v1_specification_outcome_classification, crm_algeria_v1_specification_phone_signals, crm_algeria_v1_specification_score_computation, crm_algeria_v1_specification_score_snapshots, crm_algeria_v1_specification_risk_policy [EXTRACTED 1.00]
- **Integration event inbox pipeline** — crm_algeria_v1_specification_adapter_interface, crm_algeria_v1_specification_webhook_events, crm_algeria_v1_specification_normalised_domain_events, crm_algeria_v1_specification_external_refs, crm_algeria_v1_specification_integration_connections [EXTRACTED 1.00]
- **Global score legal safeguards** — crm_algeria_v1_specification_legal_gate, crm_algeria_v1_specification_global_score_visible, crm_algeria_v1_specification_consents, crm_algeria_v1_specification_k_anonymity, crm_algeria_v1_specification_data_subject_requests, crm_algeria_v1_specification_law_18_07, crm_algeria_v1_specification_anpdp [EXTRACTED 1.00]
- **Transporteurs algeriens integres** — analyse_crm_existants_ecommerce_algerie_yalidine, analyse_crm_existants_ecommerce_algerie_zr_express, analyse_crm_existants_ecommerce_algerie_maystro, analyse_crm_existants_ecommerce_algerie_ecotrack, analyse_crm_existants_ecommerce_algerie_noest [EXTRACTED 1.00]
- **Concurrents score de risque / blacklist COD** — analyse_crm_existants_ecommerce_algerie_egrow, analyse_crm_existants_ecommerce_algerie_returnsx, analyse_crm_existants_ecommerce_algerie_cod_blacklist_shopify, analyse_crm_existants_ecommerce_algerie_kolonell, analyse_crm_existants_ecommerce_algerie_gokwik_shiprocket [EXTRACTED 1.00]
- **Cadre juridique algerien de protection des donnees** — analyse_crm_existants_ecommerce_algerie_law_18_07, analyse_crm_existants_ecommerce_algerie_law_25_11, analyse_crm_existants_ecommerce_algerie_anpdp, analyse_crm_existants_ecommerce_algerie_law_18_05, analyse_crm_existants_ecommerce_algerie_privacy_by_design [EXTRACTED 1.00]

## Communities (94 total, 12 thin omitted)

### Community 0 - "Schemas and Data Contracts"
Cohesion: 0.05
Nodes (32): Apache Avro, Apache Kafka, Asynchronous UI, Backward Compatibility, Chapter 17: Integrating Event-Driven and Request-Response Microservices, Chapter 4: Schemas and Data Contracts, Code Generation from Schemas, Dedicated Ingestion Endpoint (+24 more)

### Community 1 - "Workflows, Sagas and FaaS"
Cohesion: 0.06
Nodes (30): Amazon States Language, Approval Pattern, Asynchronous Event-Driven Function Communication, AWS Step Functions, Azure Durable Functions, Batch Size and Batch Window, Cadence, Chapter 10: Building Workflows with Microservices (+22 more)

### Community 2 - "CRM Implementation and Migration"
Cohesion: 0.05
Nodes (48): 360-Degree Customer View, Accounting System Integration, Application Integration, Business Process Automation, Classroom Training, Custom Data Migration Tools, Custom Development, Cutover / Go-Live (+40 more)

### Community 3 - "CDC, Outbox and Eventification"
Cohesion: 0.08
Nodes (9): At-Least-Once Delivery, Chapter 6: Integrating Event-Driven Architectures with Existing Systems, Chapter 7: Denormalization and Eventification, Debezium, Exchange (Publish-Subscribe Routing), Kafka Connect, Queue, RabbitMQ (+1 more)

### Community 4 - "CRM Reporting and Design"
Cohesion: 0.09
Nodes (21): As Is Process Definition, Business Rules and Escalations, Data Analysis Tools, Data Warehouse, Forecasted Revenue Metric, Key Performance Indicators (KPIs), KPI Targets, Presentation Reporting Tools (+13 more)

### Community 5 - "Performance Measurement Linkage"
Cohesion: 0.10
Nodes (23): Total Cost of Ownership, Andy Neely, Balanced Scorecard, CFI Group, CRM Margin, CRM Performance Monitoring System, CRM Return on Investment, Customer Experience Scorecard (+15 more)

### Community 6 - "CRM Strategic Framework"
Cohesion: 0.16
Nodes (19): Phone Pepper / phone_hash, scoring service, Business Trust Weight, Duplicate Detection and Contact Merge, contact_phones, Contact Scoring (per-phone risk score), disputes, Group B: Global Phone Layer (+11 more)

### Community 7 - "Spec: Global Phone Score Schema"
Cohesion: 0.14
Nodes (17): Adrian Payne, Business Strategy, Buyer-oriented Intermediaries, Channel Participants, Command and Control Organizational Structure, Customer Relationship Life-cycle, Customer Strategy, Disintermediation (+9 more)

### Community 8 - "Spec: Identity and Tenancy"
Cohesion: 0.15
Nodes (18): crm service, identity-access service, auth_identities, auth_sessions, auth_tokens, web_master Break-Glass Access, business_members, client_profiles (+10 more)

### Community 9 - "CRM Concepts and Types"
Cohesion: 0.12
Nodes (17): Analytical CRM, Collaborative CRM, CRM Continuum (Three Perspectives of CRM), CRM Application and Service Provider Segments (Gartner), Customer Lifetime Value, Customer Management, Customer Relationship Management (CRM), e-CRM (+9 more)

### Community 10 - "Spec: Confirmation, Consent, Legal"
Cohesion: 0.15
Nodes (16): V1 Acceptance Criteria, ANPDP (Algerian data protection authority), Client Area Screens, Confirmation Link (Seriousness Test), confirmation_requests, Yalidine and Other Carriers Connector, consents, data_subject_requests (+8 more)

### Community 11 - "Multi-tenancy Models (Analysis)"
Cohesion: 0.15
Nodes (17): Cellules / pods (cell-based tenancy), Salesforce Data 360, Microsoft Dynamics 365 / Dataverse, Colonnes JSONB indexees pour champs personnalises, Estimation de charge (600 000 commandes/jour, ~104 evts/s), CRM gagnants = plateformes de metadonnees, Sur-ingenierie (microservices, Kafka prematures), Monolithe modulaire + service de scoring separe (+9 more)

### Community 12 - "CRM Project Success Factors"
Cohesion: 0.12
Nodes (11): Executive Communications, Executive Support, Iterative Methodology, Kickoff Meeting, KPIs Tied to Compensation, Project Charter, Scrum Methodology, Software Development Life Cycle (+3 more)

### Community 13 - "Stateful Streams and Partitioning"
Cohesion: 0.19
Nodes (9): Aggregation, Chapter 8: Stateful Event-Driven Microservices, Copartitioning, Event Record Structure (Key, Value, Header), Inventory Accounting Service Example, Keyed Event, Partition, Repartitioning (+1 more)

### Community 14 - "Event Streams Fundamentals"
Cohesion: 0.17
Nodes (7): Event, Event Broker, Event Stream, Hydration Time, Indefinite and Tiered Storage, Jay Kreps, Legacy Application Connectors

### Community 15 - "Spec: Integrations Schema"
Cohesion: 0.21
Nodes (15): integrations service, Shopify Integration, WhatsApp Cloud API, Integration Adapter Interface, api_keys, Custom Store REST API Connector, Manual / CSV / XLSX Connector, Shopify Connector (+7 more)

### Community 16 - "Spec: Orders and Delivery"
Cohesion: 0.25
Nodes (14): orders service, presence service, carrier_status_mappings, Group D: Catalog, Orders, Delivery and Returns, order_items, Order Lifecycle State Machine, order_status_history, orders (+6 more)

### Community 17 - "CRM Application Functionality"
Cohesion: 0.17
Nodes (14): Analytics and Reporting, Closed-Loop Marketing Attribution, CRM Application, Customer Handoffs Between Departments, Customer ID Crosswalk, Customer Records (Accounts and Contacts), Field-Level Security, Marketing Functionality (+6 more)

### Community 18 - "COD Reputation Market (Analysis)"
Cohesion: 0.16
Nodes (14): Marche e-commerce algerien (> 1,5 Md USD), Paiement a la livraison (COD), Bureau de credit du paiement a la livraison (reseau de donnees), Demarrage a froid (cold start), eGrow, Boucle de retroaction (groupe de controle), Lacune : prediction de retours COD et identite globale par telephone absentes des CRM generalistes, GoKwik / Shiprocket (Inde) (+6 more)

### Community 19 - "Event-Driven Microservice Basics"
Cohesion: 0.16
Nodes (10): Adam Bellemare, Basic Producer/Consumer, Building Event-Driven Microservices (2nd Edition), Designing Data-Intensive Applications, Ephemeral Messaging, Martin Kleppmann, Message-Passing Architecture, NATS (+2 more)

### Community 20 - "Handling Bad Data"
Cohesion: 0.15
Nodes (11): Bad Data, Chapter 18: Handling Bad Data in Event Streams, Data Contracts, Data Quality Rules, Dead-Letter Queue (DLQ), Idempotent Producer, Immutable Log, Incompatible Schema Evolution (+3 more)

### Community 21 - "Event Design and Materialization"
Cohesion: 0.22
Nodes (5): Chapter 5: Designing Events, Entity Event, Event-Stream Compaction, Materialization, Tombstone

### Community 23 - "Tech Decisions: Architecture Core"
Cohesion: 0.15
Nodes (12): Algerian CRM: Technology Decisions v0.2, building-event-driven-microservices-dotnet skill, CRM Algeria V1 Specification, Decision Drivers D1-D10, IFileStorage, Kafka (runner-up), Keycloak (runner-up), Kubernetes (managed, GitOps) (+4 more)

### Community 24 - "Spec: CRM Core and Calls"
Cohesion: 0.24
Nodes (13): Business Application Screens, Call Dispositions and Outcomes, call_logs, Call Workbench, contacts, Convert Opportunity to Order, custom_field_definitions, Group C: CRM Core (+5 more)

### Community 25 - "CLV, ACURA and Loyalty"
Cohesion: 0.19
Nodes (12): Computer Telephony Integration (CTI), Contact Centre, Cross-selling, Customer Acquisition, Customer Advocacy and Referral, Customer Ladder of Loyalty, Customer Lifetime Value (CLV), Customer Segment Lifetime Value (+4 more)

### Community 26 - "Customer Value Proposition"
Cohesion: 0.15
Nodes (14): Brand Value and Brand Equity, BT Customer Value Propositions Case, Case 3.1 BT Value Propositions, Case 3.2 Zurich Financial Services Value Propositions, Don Peppers and Martha Rogers, Supplementary Services Model (Flower of Service), Total Value Offer (Core, Expected, Augmented, Potential), Value the Customer Receives (+6 more)

### Community 27 - "CRM Audit and Shareholder Value"
Cohesion: 0.16
Nodes (12): CMAT, Comprehensive CRM Audit, COPC Standard, Employee Value, Key Drivers of Shareholder Results, Output and Comparative Metrics, Performance Assessment Process, Process Metrics (+4 more)

### Community 28 - "Supportive Tooling"
Cohesion: 0.23
Nodes (11): Access Control Lists (ACLs) and RBAC, Chapter 19: Supportive Tooling, Consumer Offset Management, Continuous Integration, Delivery, and Deployment, Dependency Tracking and Topology Visualization, Identity and Access Management (IAM), Microservice-to-Team Assignment System, Schema Creation and Modification Notifications (+3 more)

### Community 29 - "Spec: Portal, Chat, Tenants"
Cohesion: 0.22
Nodes (11): Authentication and Onboarding, business_invitations, business_profiles, businesses (tenant), WhatsApp Cloud API Connector, conversations, Group F: Client Portal and Public Presence, In-App Chat and Unified Inbox (+3 more)

### Community 30 - "CRM Governance and Change Control"
Cohesion: 0.17
Nodes (13): Application Betas, Budget Management, Change Control Process, Change Management, Change Request, Change Requests, On-Premises CRM, Project Impact Statement (+5 more)

### Community 31 - "CRM Roadmap and Pillars"
Cohesion: 0.22
Nodes (11): CRM Fundamentals, CRM Program, CRM Roadmap, Current State Assessment, Evaluation Assessment Guide, IdeaShare Sample Roadmap, Lead Scoring, Pilot Project (+3 more)

### Community 32 - "Sources of CRM Value"
Cohesion: 0.17
Nodes (12): Employee Productivity and Efficiency, Informing Business Decisions, Lead Auto-Assignment, Lead Management, Metrics and Visibility (Instrumentation), Quote Generation, Sales Forecasting, Sales Functionality (SFA) (+4 more)

### Community 33 - "CRM Readiness and Maturity"
Cohesion: 0.17
Nodes (11): Barriers to CRM Success, Building a Data Repository, CRM Maturity Assessment, CRM Readiness Assessment, CRM Readiness Audit, Highly Advanced CRM, Moderately Developed CRM, Operational Data Store (+3 more)

### Community 34 - "Information Management Process"
Cohesion: 0.15
Nodes (13): Back-office Applications, BPO, ASP and BSP, Campaign Management, Case 2.1 DnB NOR Bank with Teradata, Data Protection and Privacy, Data Repository, Enterprise Data Warehouse, Front-office Applications (+5 more)

### Community 35 - "Competitor CRMs (Analysis)"
Cohesion: 0.20
Nodes (12): COD Blacklist (Shopify), Niveaux de confiance Certain/Likely/Guessing, Taxonomie des CRM (operationnel, analytique/CDP, collaboratif, antifraude, e-commerce), Analyse approfondie des CRM existants (CRM e-commerce algerien), Antifraude / reputation (Sift, Riskified, Signifyd, Ekata, Telesign, Truecaller), Pipedrive, ReturnsX (Shopify), Boutiques (Shopify, WooCommerce, YouCan) (+4 more)

### Community 36 - "Heavyweight Framework Scaling"
Cohesion: 0.18
Nodes (11): Chapter 12: Heavyweight Framework Microservices, Cluster Mode, Data Shuffling, Driver Mode, External Shuffle Service, Hosted Managed Stream Processing Service, Key State, Multitenancy Namespacing (+3 more)

### Community 37 - "Tech Decisions: Frontend and Auth"
Cohesion: 0.20
Nodes (11): Aspire AppHost, JWT Token Design, MassTransit, Nuxt (Vue 3, TypeScript), Nuxt BFF, OIDC Authorization Code + PKCE Login, PrimeVue, REST + OpenAPI Edge APIs (+3 more)

### Community 38 - "CRM Pitfalls and Training"
Cohesion: 0.20
Nodes (10): CRM Maintenance Processes, CRM Pitfalls, Executive Sponsor, Implementation Team, Portals as Project Management Tools, Project Communication Plan, Project Manager, Project Scheduling and Milestones (+2 more)

### Community 39 - "Service, Portal and Licensing"
Cohesion: 0.18
Nodes (12): Configuration vs Customization, Consultant Evaluation Criteria, Consulting Partner, CRM Licensing Models, Customer Self-Service Portal, Knowledge Base, Partner Portal, Reference Checks (+4 more)

### Community 40 - "CRM Project Management"
Cohesion: 0.18
Nodes (12): Benefits Dependency Network, CAPEX vs OPEX, CRM Budget, CRM Project Management, CRM Vendor Selection, Detica Vendor Evaluation Criteria, Gartner, Michael Gentle (+4 more)

### Community 41 - "Eventual Consistency Operations"
Cohesion: 0.18
Nodes (8): Autoscaling, Consumer Lag, Consumer Offset Lag Monitoring, Doug Terry, Eventual Convergence, Pat Helland, Peter Alvaro, Producer Lag

### Community 42 - "Event Types and Consistency"
Cohesion: 0.22
Nodes (8): Chapter 16: Eventual Consistency, Chapter 22: Conclusion, Delta Events, Event-Carried State Transfer (ECST), Hybrid Events, Microservice Implementation Options, Request-Response Services, State Events (Entity Events)

### Community 43 - "Scoring Service Design (Analysis)"
Cohesion: 0.24
Nodes (10): Enumeration de l'API de scoring, Modele de donnees minimal (tenants, customers, orders, shipments, phone_identity, outcome_events, phone_score), Chiffrement par champ + index aveugle HMAC, Pseudonymisation par HMAC (cle secrete KMS), Plan reseau (donnees pseudonymisees partagees), RBAC par tenant + journal d'audit append-only, Bandes de score (vert/orange/rouge/inconnu) + codes de raison, API de scoring (p99 < 150 ms) (+2 more)

### Community 44 - "Heavyweight Streaming Frameworks"
Cohesion: 0.20
Nodes (9): Apache Beam, Apache Hadoop, Apache Spark, Apache ZooKeeper, Google Dataflow, MapReduce, Resource Manager, Spark SQL (+1 more)

### Community 45 - "Kafka Streams Lightweight"
Cohesion: 0.33
Nodes (7): Apache Samza, Changelog Streams, Chapter 13: Lightweight Framework Microservices, Hot Replicas, Kafka Streams, KTable, State Restoration Phase

### Community 46 - "Spec: Platform, Audit, Notify"
Cohesion: 0.22
Nodes (8): messaging service, audit_logs, files, Group G: Platform, notifications, Notification Events and Preferences, Database Schema (PostgreSQL), wilayas

### Community 47 - "CRM Administration Team"
Cohesion: 0.20
Nodes (10): Centralized Feedback Capture, CRM Administration Team, CRM Administrator, CRM Business Analyst, CRM Developer, CRM Program Lead, CRM Trainer, Departmental Champions (+2 more)

### Community 48 - "Testing Environments and Micro-FE"
Cohesion: 0.22
Nodes (8): Acquirers, Retainers and Profit Maximizers, Customer Acquisition Economics, Customer Profitability, Customer Referral, Customer Retention Economics, Reichheld and Sasser Retention Research, United Electricity plc Case, Value the Organization Receives

### Community 49 - "Streaming SQL"
Cohesion: 0.25
Nodes (5): Aggregation Layer, Infrastructure as Code (IaC), Multicluster Event-Stream Replication, Remote Integration Testing, Test Data Population Strategies

### Community 50 - "Testing and Deployment Patterns"
Cohesion: 0.33
Nodes (8): Append-Only Table, Chapter 14: Streaming SQL, Continuous Query, Retraction Table, SQL Gateway, Streaming SQL, Upsert Table, User-Defined Function (UDF)

### Community 51 - "Consumer Groups and State"
Cohesion: 0.25
Nodes (7): Chapter 20: Testing Event-Driven Microservices, Chapter 21: Deploying Event-Driven Microservices, Local Integration Testing, Schema Evolution Compatibility Testing, Testcontainers, Topology Testing (TopologyTestDriver), Unit Testing Stateless and Stateful Functions

### Community 52 - "Tech Decisions: Survival Rules"
Cohesion: 0.25
Nodes (4): Consumer Group, Offset, Rebalancing, RocksDB

### Community 54 - "Segmentation and Trade-off"
Cohesion: 0.22
Nodes (7): feature_flags, Frontend Functionality, Phone Input Component, Risk Policy (tier -> recommended actions), Score Badge Component, Score Tiers A/B/C/D/UNSCORED and Confidence, Web Master Console

### Community 55 - "Industry and Vision Analysis"
Cohesion: 0.25
Nodes (7): Benefit / Value-sought Segmentation, Communities or Segments, Market Segmentation, Robotic Components Inc. Case, Criteria for Market Segment Viability, Trade-off (Conjoint) Analysis, Value Assessment

### Community 56 - "Algerian Data Law (Analysis)"
Cohesion: 0.22
Nodes (9): Business Vision, Co-opetition and Networks, Disruptive Technologies, Industry Analysis Framework (Eight Dimensions), Key Factors for Success, PESTE Analysis, Porter's Five Forces, Purpose, Vision and Values (Davidson) (+1 more)

### Community 57 - "Bayesian Score and OTP (Analysis)"
Cohesion: 0.29
Nodes (8): ANPDP (Autorite nationale de protection des donnees), Procedure de contestation, Partage inter-vendeurs = profilage inter-responsables (risque juridique majeur), Faux positifs et equite, Loi 18-07 (protection des donnees personnelles), Loi 25-11 (modification de la 18-07, juillet 2025), Consequences de conception (minimisation, limitation de duree, transparence, contestation, explicabilite), Feuille de route en 5 phases (Fondations -> Largeur CRM)

### Community 58 - "Algerian Carriers (Analysis)"
Cohesion: 0.25
Nodes (8): Estimation bayesienne Beta-Binomiale avec decroissance temporelle, Freshsales (Freshworks), Niveau 3 : modele hierarchique multi-facteurs (regression logistique calibree), Kolonell, Verification OTP / WhatsApp, Niveau 1 : regles transparentes + OTP, Signaux mesurables (refus, injoignable, decroche, delai de reponse, livraison encaissee, diversite vendeurs), Telephonie integree au CRM (journal d'appels)

### Community 59 - "Tech Decisions: Data and Events"
Cohesion: 0.39
Nodes (8): Statuts transporteurs comme source de verite (livre/refuse/injoignable), DZBuild / dzship, Ecotrack, Maystro, Noest, Questions restant a trancher (CRM ou score ? source de verite ?), Yalidine, ZR Express

### Community 60 - "Spec: Eight Design Decisions"
Cohesion: 0.25
Nodes (4): CloudEvents-style Event Envelope, EF Core 10 (Npgsql) + Dapper, First-cut Event Catalogue, PostgreSQL

### Community 62 - "CRM Strategy Matrix"
Cohesion: 0.25
Nodes (8): Affinity Grouping (Market Basket Analysis), Analytical Tools, Churn Management, Customer Profiling, Data Mining, Decision Trees, Neural Networks, OLAP

### Community 63 - "Generic Strategy Frameworks"
Cohesion: 0.36
Nodes (8): BroadVision, Case 2.2 RS Components with BroadVision, Migration (Transition) Paths for CRM, CRM Strategy Matrix, Customer-based Marketing, Individualized CRM, Managed Service and Support, Product-based Selling

### Community 64 - "Single Customer View Cases"
Cohesion: 0.29
Nodes (8): Cost Leadership Strategy, Customer Intimacy, Differentiation Strategy, Focus Strategy, Generic Strategies Framework (Porter), Operational Excellence, Product Leadership, Value Disciplines (Market Leaders Framework)

### Community 65 - "Algerian Phone Normalisation"
Cohesion: 0.25
Nodes (8): CRM Pilot Projects, CRM Training and Development, Mercedes-Benz DaimlerChrysler UK, Nationwide, Operational Data Store (ODS), Senior CRM Sponsorship, Single Customer View, Unisys

### Community 66 - "DDD and Bounded Contexts"
Cohesion: 0.29
Nodes (7): Djezzy (prefixe 07), libphonenumber, Positionnement : le score COD pense pour l'Algerie, Mobilis (prefixe 06), Ooredoo (prefixe 05), Normalisation des numeros algeriens vers E.164 (05/06/07), 58 wilayas

### Community 67 - "Microservice Tax and Containers"
Cohesion: 0.38
Nodes (3): Domain, Domain Model, Subdomain

### Community 68 - "Tech Decisions: Spikes and Inbox"
Cohesion: 0.29
Nodes (6): Container Management System, Container Management System (CMS), Containerization, Kubernetes, MicroVMs, Modular Monolith

### Community 69 - "CRM Hosting and Environments"
Cohesion: 0.33
Nodes (5): Carrier Adapters (Yalidine, ZR Express, Maystro, Ecotrack, Noest, E-com Delivery), Risks and Spikes (S1-S6, R1-R4), Spike S1: Walking Skeleton, Webhook Inbox, Wolverine

### Community 70 - "Employee Engagement"
Cohesion: 0.33
Nodes (7): Application Hosting and Colocation, CRM Application Architecture, Dev Test Production Environments, Disaster Recovery, On-Premises Deployment, Software-as-a-Service, Source Control

### Community 71 - "Multi-channel Strategy"
Cohesion: 0.29
Nodes (6): Au Bon Pain, Disney Corporation, Employee Engagement, Employee Loyalty Segments, Internal Marketing, McKean Human Touch Areas

### Community 73 - "Outbox and Webhook Idempotence"
Cohesion: 0.33
Nodes (7): CRM Change Management, CRM Vision, Cross-Functional Working, Cultural Web, Hard vs Soft CRM Implementation, McKinsey Seven S Framework, Orange

### Community 74 - "Apache Flink"
Cohesion: 0.33
Nodes (6): Journal d'evenements immuable, HubSpot, Idempotence des webhooks transporteurs, Pattern Outbox, Piege du perimetre tout HubSpot + Salesforce, Vitess (MySQL sharde)

### Community 75 - "Breaking Schema Changes"
Cohesion: 0.33
Nodes (5): Apache Flink, Flink SQL, Metadata Catalog (Hive API), Session Windowing, Stream-Processing Framework Microservice

### Community 77 - "Event Sourcing and Logs"
Cohesion: 0.33
Nodes (4): Business Communication Structure, Business Topology, Implementation Communication Structure, Microservice Topology

### Community 80 - "Channel Options"
Cohesion: 0.33
Nodes (4): Below Zero Customers (BZ), Customer Defection, Customer Retention, Most Valuable Customers (MVC)

### Community 81 - "Customer Experience"
Cohesion: 0.33
Nodes (6): Channel Options, Cost Reduction, Customer Self-service, Ideal Boilers Mobile Case, M-commerce, Six Channel Categories

### Community 82 - "CRM Project Plan"
Cohesion: 0.33
Nodes (5): Customer Experience, Emotional Reservoir of Goodwill, Guinness Perfect Pint Case, Jones and Sasser Loyalty Study, TNT Perfect Customer Transaction

### Community 83 - "CRM Metrics and KPIs"
Cohesion: 0.40
Nodes (3): Audit Issue Classification Matrix, Business Benefits Implementation Matrix, CRM Project Plan

### Community 84 - "One-to-one Marketing"
Cohesion: 0.40
Nodes (5): CRM Metrics and KPIs, Customer Metrics, People and Process Metrics, Second Tier Customers (STC), Share of Wallet

### Community 85 - "Request-Response Coupling"
Cohesion: 0.70
Nodes (5): Learning Relationship, Mass Customization, One-to-one Marketing, Permission Marketing, Segment Granularity

### Community 87 - "Vendor Contracts"
Cohesion: 0.50
Nodes (3): Session Window, Sliding Window, Tumbling Window

### Community 88 - "Misc 88"
Cohesion: 0.67
Nodes (4): Professional Services Agreement (PSA), Resource/Vendor Management, Rights in Data, Statement of Work (SOW)

### Community 89 - "Misc 89"
Cohesion: 0.67
Nodes (3): buf (proto lint and breaking-change checks), gRPC (fresh-read queries only, one hop), Quality Engineering Practices

## Knowledge Gaps
- **280 isolated node(s):** `Aspire AppHost`, `OIDC Authorization Code + PKCE Login`, `REST + OpenAPI Edge APIs`, `Arabic RTL / French i18n`, `LocalDiskFileStorage` (+275 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 339 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Data Warehouse` connect `CRM Reporting and Design` to `Algerian Phone Normalisation`, `CRM Readiness and Maturity`, `Information Management Process`, `Performance Measurement Linkage`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **What connects `Aspire AppHost`, `OIDC Authorization Code + PKCE Login`, `REST + OpenAPI Edge APIs` to the rest of the system?**
  _280 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Schemas and Data Contracts` be split into smaller, more focused modules?**
  _Cohesion score 0.05079825834542816 - nodes in this community are weakly interconnected._
- **Why does `Multi-channel Integration Process` connect `Spec: Global Phone Score Schema` to `CRM Change Management`, `Customer Experience`, `CRM Project Plan`, `CRM Audit and Shareholder Value`, `Generic Strategy Frameworks`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Should `Workflows, Sagas and FaaS` be split into smaller, more focused modules?**
  _Cohesion score 0.058673469387755105 - nodes in this community are weakly interconnected._
- **Should `CRM Implementation and Migration` be split into smaller, more focused modules?**
  _Cohesion score 0.04591836734693878 - nodes in this community are weakly interconnected._
- **Should `CDC, Outbox and Eventification` be split into smaller, more focused modules?**
  _Cohesion score 0.07957957957957958 - nodes in this community are weakly interconnected._