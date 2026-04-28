# Incidents

General documentation about our incident workflow itself. Service-specific
information, including what to do in response to an incident relating to that
service, is found in the docs for that service.

## Overview

We use [Incident.io](https://app.incident.io/gitlab/dashboard) as the primary automation tool for our incident process.
Most incident information exchange takes place in an incident Slack channel, an incident Zoom meeting, and an Incident.io incident.

### Notifications

Alertmanager, Deadmansnitch, and Pingdom are the sources of alerts from automated systems attempting to detect and inform our on-call of potential incidents.
All three of these sytems will notify Pagerduty, which will then notify the current engineer on call (EoC).

Incident.io can also use Pagerduty to notify the EoC, IMoC, and CMoC that a new high severity incident has been declared.

### Declaring an incident

The Slack command, `/incident`, can be used to declare an incident.
This integration depends on Slack and Incident.io in order to work.

### Create a Google doc

- Navigate to <https://drive.google.com/>
- Create a new Google Doc
- Click "Share" in the top-right corner
- In the "Get link" section of the modal, click "Change link to GitLab" to make
  the doc shareable with the whole company.
- Change the "Anyone with the link in GitLab" permissions to "Editor"
- Click done.
- Post a link to the doc in Slack
- Good luck!
