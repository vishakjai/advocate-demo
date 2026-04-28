**Table of Contents**

[[_TOC_]]

# [Service/Feature Name]

* **Service Name** <!-- Replace with the actual name of your service or feature. -->
* **Descriptive Title** <!-- Keep it concise yet descriptive to clearly identify what the runbook covers. -->
* **Unique Identifier** <!-- Ensure the name is unique and follows the naming convention of other runbooks. -->

## About [Service/Feature Name]

* **Service Overview** <!-- Provide a comprehensive overview of your service or feature. -->
* **Purpose Description** <!-- Include enough detail for someone unfamiliar with the service to understand its purpose. -->
* **Business Impact** <!-- Cover the business impact of the service and why outages matter. -->
* **Core Components** <!-- Explain the basic functionality and core components. -->

### Contact Information

- **Group**:
  * **Team Identification** <!-- Specify the GitLab group responsible for this service/feature (e.g., "Create:Group Name"). -->
  * **Escalation Path** <!-- Include the full team hierarchy for clear escalation paths. -->
  * **Current Structure** <!-- Keep updated whenever team structures change. -->
- **Handbook**:
  * **Documentation Link** <!-- Provide a link to the relevant handbook page using proper markdown format. -->
  * **Access Verification** <!-- Ensure the link is accessible to all GitLab team members. -->
  * **Team Information** <!-- The handbook should contain additional team information and processes. -->
- **Slack**:
  * **Primary Channel** <!-- Include a link to the primary Slack channel for the team. -->
  * **Secondary Channels** <!-- Mention any secondary channels for different alert severities. -->
  * **Monitoring Coverage** <!-- Specify which channels are actively monitored and their hours of coverage. -->

### Core Functionality

* **Key Functions** <!-- Describe the primary functions and capabilities of the service/feature. -->
* **Component Breakdown** <!-- Break down complex services into distinct components or features. -->
* **Technical Stack** <!-- Include technical details about underlying technologies and frameworks. -->
* **Architectural Decisions** <!-- Explain key architectural decisions that might impact troubleshooting. -->
* **Response Characteristics** <!-- Provide information about typical response times and activation methods. -->
* **Service Dependencies** <!-- Detail any dependencies and operational characteristics. -->

### Integration

* **Available Platforms** <!-- List all platforms, applications, or environments where this feature is available. -->
* **Version Requirements** <!-- Include version requirements or compatibility information. -->
* **User Interaction** <!-- Describe how users interact with the feature through each integration point. -->
* **Platform Differences** <!-- Explain any differences in functionality across different platforms. -->
* **Failure Impact** <!-- Detail the impact if an integration fails. -->
* **Issue Detection** <!-- Provide ways to detect integration-specific issues versus core service issues. -->

### Connectivity

* **Network Methods** <!-- Detail connectivity methods and networks the service uses. -->
* **Connection Paths** <!-- Explain default connection paths including protocols and authentication methods. -->
* **Failover Mechanisms** <!-- Describe alternative connection methods or failover mechanisms. -->
* **Traffic Flow** <!-- Include information about network architecture and traffic flows. -->
* **Intermediary Systems** <!-- Mention any proxies, load balancers, or other intermediary systems. -->
* **Network Diagrams** <!-- Consider including simplified network diagrams if helpful. -->

### Requirements

* **Functional Requirements** <!-- List all requirements necessary for the service/feature to function properly. -->
* **Subscription Levels** <!-- Include subscription levels and licensing requirements. -->
* **Access Control** <!-- Detail authorization mechanisms and permission models. -->
* **Version Dependencies** <!-- Specify minimum version requirements for the service and dependencies. -->
* **Resource Needs** <!-- Document resource requirements (memory, CPU, disk space, bandwidth). -->
* **Feature Flags** <!-- Include any feature flags or configuration settings that must be enabled. -->

### Usage Patterns

* **Normal Behavior** <!-- Describe typical usage patterns to help identify abnormal behavior. -->
* **Traffic Patterns** <!-- Include information about daily, weekly, or seasonal traffic patterns. -->
* **Regional Differences** <!-- Provide data about regional usage differences and peak hours. -->
* **Load Distribution** <!-- Document expected load distribution across different components. -->
* **Metric Baselines** <!-- Define "normal" behavior for key metrics (request volume, error rates, response times). -->
* **Performance Benchmarks** <!-- Include baseline performance expectations to identify deviations quickly. -->

### Documentation

* **Resource Links** <!-- List all relevant documentation resources with descriptive links. -->
* **Engineering Docs** <!-- Include engineering documentation explaining internal workings. -->
* **Architecture Diagrams** <!-- Add links to architecture diagrams and data flow documentation. -->
* **User Documentation** <!-- Reference user-facing documentation for understanding expected behaviors. -->
* **Documentation Order** <!-- Organize documentation links logically, most important first. -->
* **Past Incidents** <!-- Include links to previous incident reports or postmortems if relevant. -->

## Initial Triage

* **Diagnostic Approach** <!-- Provide a systematic approach to diagnosing issues. -->
* **Step Procedures** <!-- Include clear, step-by-step procedures that anyone can follow. -->
* **Impact Assessment** <!-- Explain how to assess the scope and impact of an issue. -->
* **Severity Guidelines** <!-- Guide how to determine the appropriate severity level. -->
* **Known Issues** <!-- Provide ways to quickly identify known issues with established workarounds. -->
* **Data Collection** <!-- Include initial data gathering steps before deeper investigation. -->

### Alerting

* **Alert Types** <!-- Describe all alerts related to this service/feature. -->
* **Alert Sources** <!-- Explain where alerts appear and how they are triggered. -->
* **Alert Thresholds** <!-- Detail thresholds or conditions that cause each alert to fire. -->
* **Health Context** <!-- Provide context about what each alert means for service health. -->
* **Dashboard Links** <!-- Include direct links to alerting dashboards or systems. -->
* **Pattern Recognition** <!-- Document common alert patterns and known false positives. -->
* **Escalation Criteria** <!-- Provide guidance on when to escalate based on alert combinations. -->

### [Alert Type] Error

* **Alert Naming** <!-- Name this section after specific alert types (e.g., "Service Apdex Error"). -->
* **Health Indicators** <!-- Include context about what this alert indicates about service health. -->
* **Common Causes** <!-- Explain the typical causes based on historical incidents. -->
* **User Impact** <!-- Detail the potential user impact of this alert type. -->
* **Initial Steps** <!-- Provide initial assessment steps before detailed troubleshooting. -->

**Step 1: Determine which [component] is affected**

* **Component Identification** <!-- Provide instructions for identifying the specific problem component. -->
* **Monitoring Tools** <!-- Include links to dashboards or monitoring tools that help isolate issues. -->
* **Data Interpretation** <!-- Explain how to interpret data from these tools. -->
* **Error Patterns** <!-- List specific error patterns, log entries, or metric anomalies to look for. -->
* **Issue Differentiation** <!-- Detail how to differentiate between similar-looking issues. -->
* **Normal vs. Abnormal** <!-- Provide examples of what "normal" versus "problematic" looks like. -->

**Step 2: Investigate [Component] Issues**

* **Investigation Steps** <!-- Provide component-specific investigation steps. -->
* **Logical Sequence** <!-- Break down the investigation into clear, logical steps. -->
* **Data Collection** <!-- Explain what information to gather at each step and how to interpret it. -->
* **Dashboard Links** <!-- Include links to specific dashboard panels or log queries. -->
* **Metric Patterns** <!-- Describe normal versus abnormal patterns for key metrics. -->
* **Root Cause** <!-- Provide guidance on determining root cause from available data. -->
* **Case Studies** <!-- Include examples of previous incidents and their resolution paths. -->

## Common Resolution Steps

* **Solution Overview** <!-- Cover the most frequent issues and their solutions. -->
* **Symptom Organization** <!-- Organize solutions by symptom or issue type, not by component. -->
* **Expected Outcomes** <!-- Include expected outcomes for each resolution step. -->
* **Verification Methods** <!-- Provide verification methods to confirm issues are resolved. -->
* **User Impact** <!-- Explain how to implement resolutions with minimal user impact. -->
* **Implementation Factors** <!-- Consider timing, communication, and potential side effects. -->

### High Error Rates

* **Error Troubleshooting** <!-- Provide troubleshooting steps for elevated error rates. -->
* **Error Classification** <!-- Include approaches based on different error types (auth failures, timeouts, etc.). -->
* **Root Causes** <!-- Explain how to identify root causes for various error patterns. -->
* **Solution Mapping** <!-- Detail corresponding solutions for each cause. -->
* **Safe Implementation** <!-- Include implementation steps for fixes with safety considerations. -->
* **Resolution Verification** <!-- Provide verification methods to confirm error rates have normalized. -->
* **Prevention Measures** <!-- Document preventive measures to avoid similar issues in future. -->

### Latency Issues

* **Performance Analysis** <!-- Detail steps to diagnose and resolve performance problems. -->
* **Latency Classification** <!-- Explain how to differentiate between various causes of latency. -->
* **Specific Remedies** <!-- Include specific remediation for each type of latency issue. -->
* **Configuration Changes** <!-- Document configuration changes, scaling operations, or traffic management techniques. -->
* **Impact Measurement** <!-- Provide methods to measure impact of changes. -->
* **Performance Verification** <!-- Include verification steps to confirm latency has returned to acceptable levels. -->
* **Remediation Tradeoffs** <!-- Detail any potential trade-offs in resolution approaches. -->

### Database Issues

* **Database Troubleshooting** <!-- Provide guidance on identifying and resolving database-related problems. -->
* **Performance Checks** <!-- Include instructions for checking database performance and connection issues. -->
* **Metrics Interpretation** <!-- Explain how to interpret database metrics and logs. -->
* **Common Solutions** <!-- Detail steps for common database resolutions (index optimization, query tuning). -->
* **Scaling Procedures** <!-- Include information about database scaling or failover procedures. -->
* **Impact Assessment** <!-- Document how to assess database impact on overall service performance. -->
* **Useful Queries** <!-- Provide queries or commands useful for troubleshooting specific database issues. -->

### External Dependencies

* **Dependency Issues** <!-- Detail how to identify and resolve dependency-related issues. -->
* **Contact Information** <!-- Include contact information and escalation paths for each dependency. -->
* **Status Verification** <!-- Explain how to determine if dependencies are experiencing issues. -->
* **Validation Methods** <!-- Provide methods to validate external system status. -->
* **Fallback Options** <!-- Document workarounds or fallback options during dependency outages. -->
* **Recovery Steps** <!-- Include recovery steps once dependencies are restored. -->
* **Communication Templates** <!-- Detail communication templates for updates during dependency issues. -->

## Dashboards

* **Tool Catalog** <!-- Catalog all relevant dashboards and monitoring tools. -->
* **Logical Organization** <!-- Organize by type and purpose for quick information finding. -->
* **Dashboard Usage** <!-- Include guidance on effective dashboard usage. -->
* **Key Metrics** <!-- Explain key metrics to check first and how to interpret data. -->
* **Dashboard Relationships** <!-- Document relationships between different dashboards. -->
* **Correlation Tips** <!-- Provide tips for correlating information across monitoring systems. -->

### Logging

* **Logging Systems** <!-- Detail all logging systems and dashboards for this service. -->
* **Search Queries** <!-- Provide specific queries or filters for isolating relevant log entries. -->
* **Pattern Interpretation** <!-- Explain how to interpret common log patterns. -->
* **Key Information** <!-- Document key information to look for in log messages. -->
* **Retention Policies** <!-- Include information about log retention periods and logging levels. -->
* **Verbosity Adjustment** <!-- Explain how to adjust logging verbosity during troubleshooting. -->
* **Log Examples** <!-- Provide examples of both normal and problematic log patterns. -->

### Grafana Dashboards

* **Dashboard List** <!-- List all Grafana dashboards relevant to this service/feature. -->
* **Information Content** <!-- Describe what information each dashboard provides. -->
* **Important Panels** <!-- Explain the most important panels and metrics on each dashboard. -->
* **Metric Ranges** <!-- Document normal ranges for key metrics and what deviations indicate. -->
* **Dashboard Organization** <!-- Include information about dashboard organization (by region, component, etc.). -->
* **Navigation Tips** <!-- Provide tips on navigating between related dashboards. -->
* **Special Features** <!-- Explain any dashboard-specific features or functionality. -->

### Tableau Dashboards

* **Tableau Reports** <!-- List all Tableau dashboards used for monitoring this service. -->
* **Direct Links** <!-- Provide direct links using the format compatible with GitLab's SSO. -->
* **Dashboard Purpose** <!-- Explain the purpose of each dashboard and its data sources. -->
* **Refresh Frequency** <!-- Document data refresh frequency and staleness considerations. -->
* **Filter Usage** <!-- Detail how to filter or interact with visualizations. -->
* **Trend Analysis** <!-- Explain pattern interpretation and trend analysis. -->
* **Monitoring Complement** <!-- Describe how Tableau complements real-time monitoring. -->
* **Business Insights** <!-- Highlight business metrics and user behavior insights available. -->

### Kibana Dashboards

* **Kibana Searches** <!-- Document all Kibana dashboards and saved searches for this service. -->
* **Investigation Queries** <!-- Provide specific search queries for incident investigation. -->
* **Interface Navigation** <!-- Explain Kibana interface navigation to find relevant logs. -->
* **Index Selection** <!-- Detail which indices to select and useful time ranges. -->
* **Log Interpretation** <!-- Provide guidance on interpreting log patterns and levels. -->
* **Cross-Component Correlation** <!-- Explain how to correlate logs across different components. -->
* **Custom Fields** <!-- Document any custom fields or JSON structures in the logs. -->
* **Log Examples** <!-- Include examples of both normal and error log patterns. -->

### Sentry

* **Project List** <!-- Document all Sentry projects and issue types for this service. -->
* **Filtered Views** <!-- Include direct links to filtered views for specific components. -->
* **Data Interpretation** <!-- Explain interpretation of Sentry data (stack traces, breadcrumbs). -->
* **Impact Assessment** <!-- Provide impact assessment guidance (frequency, affected users). -->
* **Grouping Features** <!-- Detail effective use of Sentry's grouping and tagging features. -->
* **Trend Identification** <!-- Explain how to identify trends or regressions in error rates. -->
* **Issue Triage** <!-- Document triage and prioritization approaches for Sentry issues. -->
* **Custom Configuration** <!-- Include any Sentry-specific configuration for this service. -->

### Additional Monitoring Tools

* **Other Tools** <!-- Document any other monitoring tools for this service. -->
* **Unique Information** <!-- Explain what unique information each tool provides. -->
* **Tool Usage** <!-- Detail when to use each tool during troubleshooting. -->
* **Access Procedures** <!-- Include access procedures and authentication requirements. -->
* **Data Correlation** <!-- Explain data correlation across different monitoring platforms. -->
* **Tool Tips** <!-- Provide tool-specific tips and tricks for effective usage. -->
* **Custom Views** <!-- Document any custom configurations or views created for this service. -->

/label ~runbook ~documentation
