package templates

import (
	"bytes"
	"fmt"
	"net/url"
	"os"
	"testing"
	"text/template"

	amtemplate "github.com/prometheus/alertmanager/template"
)

// This test pulls some of the functionality from the Alertmanager repository and
// renders the alert templates to ensure they're being parsed as expected.
func TestTemplates(t *testing.T) {
	t.Parallel()

	type args struct {
		payload      Payload
		templatePath string
		templateName string
	}
	tests := []struct {
		name    string
		args    args
		want    string
		wantErr bool
	}{
		{
			name: "gitlab.text_mimir_.Alerts.Annotations.grafana_datasource_id",
			args: args{
				payload: Payload{
					Status: "firing",
					Alerts: []Alert{
						{
							Labels: amtemplate.KV{
								"alertname": "service_ops_out_of_bounds_upper_2sigma_5m",
							},
							Annotations: amtemplate.KV{
								"grafana_datasource_id": "mimir-gitlab-gstg",
								"title":                 "redis service operation rate alert",
								"description":           "Server is running outside of normal operation rate parameters\n",
							},
							GeneratorURL: "https://prometheus.gstg.gitlab.net/graph?g0.expr=gitlab_service_ops%3Arate+%3E+gitlab_service_ops%3Arate%3Aavg_over_time_1w+%2B+2.5+%2A+gitlab_service_ops%3Arate%3Astddev_over_time_1w%7Benv%3D%22gstg%22%7D&g0.tab=1",
						},
					},
					CommonLabels: amtemplate.KV{
						"environment": "gstg",
						"type":        "web",
					},
				},
				templatePath: "gitlab.tmpl",
				templateName: "gitlab.text",
			},
			want:    wantFromFile(t, "./testdata/gitlab.text_mimir_.Alerts.Annotations.grafana_datasource_id.txt"),
			wantErr: false,
		},
		{
			name: "gitlab.text_mimir_.Alerts.Annotations.promql_template_1",
			args: args{
				payload: Payload{
					Status: "firing",
					Alerts: []Alert{
						{
							Labels: amtemplate.KV{
								"alertname": "service_ops_out_of_bounds_upper_2sigma_5m",
							},
							Annotations: amtemplate.KV{
								"grafana_datasource_id": "mimir-gitlab-gstg",
								"title":                 "redis service operation rate alert",
								"description":           "Server is running outside of normal operation rate parameters\n",
								"promql_template_1":     "gitlab_workhorse_git_http_sessions_active:total{stage=\"main\"}",
							},
							GeneratorURL: "https://prometheus.gstg.gitlab.net/graph?g0.expr=gitlab_service_ops%3Arate+%3E+gitlab_service_ops%3Arate%3Aavg_over_time_1w+%2B+2.5+%2A+gitlab_service_ops%3Arate%3Astddev_over_time_1w%7Benv%3D%22gstg%22%7D&g0.tab=1",
						},
					},
					CommonLabels: amtemplate.KV{
						"environment": "gstg",
						"type":        "web",
					},
				},
				templatePath: "gitlab.tmpl",
				templateName: "gitlab.text",
			},
			want:    wantFromFile(t, "./testdata/gitlab.text_mimir_.Alerts.Annotations.promql_template_1.txt"),
			wantErr: false,
		},
		{
			name: "gitlab.text_mimir_.Alerts.Annotations.promql_template_2",
			args: args{
				payload: Payload{
					Status: "firing",
					Alerts: []Alert{
						{
							Labels: amtemplate.KV{
								"alertname": "service_ops_out_of_bounds_upper_2sigma_5m",
							},
							Annotations: amtemplate.KV{
								"grafana_datasource_id": "mimir-gitlab-gstg",
								"title":                 "redis service operation rate alert",
								"description":           "Server is running outside of normal operation rate parameters\n",
								"promql_template_1":     "gitlab_workhorse_git_http_sessions_active:total{stage=\"main\"}",
								"promql_template_2":     "avg_over_time(gitlab_workhorse_git_http_sessions_active{type=\"git\", tier=\"sv\", stage=\"$stage\"}[1m])",
							},
							GeneratorURL: "https://prometheus.gstg.gitlab.net/graph?g0.expr=gitlab_service_ops%3Arate+%3E+gitlab_service_ops%3Arate%3Aavg_over_time_1w+%2B+2.5+%2A+gitlab_service_ops%3Arate%3Astddev_over_time_1w%7Benv%3D%22gstg%22%7D&g0.tab=1",
						},
					},
					CommonLabels: amtemplate.KV{
						"environment": "gstg",
						"type":        "web",
					},
				},
				templatePath: "gitlab.tmpl",
				templateName: "gitlab.text",
			},
			want:    wantFromFile(t, "./testdata/gitlab.text_mimir_.Alerts.Annotations.promql_template_2.txt"),
			wantErr: false,
		},
		{
			name: "gitlab.text_mimir_.Alerts.GeneratorURL",
			args: args{
				payload: Payload{
					Status: "firing",
					Alerts: []Alert{
						{
							Annotations: amtemplate.KV{
								"grafana_datasource_id": "mimir-gitlab-gprd",
							},
							GeneratorURL: generatorURLFromExpr(`sum by (env,environment,tier,stage,region) (\n  rate(gitlab_workhorse_http_requests_total{code=~"^5.*",environment="gprd",job=~"gitlab-workhorse|gitlab-workhorse-git",region="us-east1-d",route!="^/-/health$",route!="^/-/(readiness|liveness)$",route!="^/api/",route!="\\A/api/v4/jobs/request\\z",route!="^/api/v4/jobs/request\\z",stage="main",type="git"}[5m])\n)`),
						},
					},
				},
				templatePath: "gitlab.tmpl",
				templateName: "gitlab.text",
			},
			want:    wantFromFile(t, "./testdata/gitlab.text_mimir_.Alerts.GeneratorURL.txt"),
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpl := &template.Template{}
			tmpl = tmpl.Funcs(template.FuncMap(amtemplate.DefaultFuncs))
			tmpl, err := tmpl.ParseFiles(tt.args.templatePath)
			if err != nil {
				t.Fatal(err)
			}

			got := bytes.Buffer{}
			if err := tmpl.ExecuteTemplate(&got, tt.args.templateName, tt.args.payload); err != nil {
				t.Fatal(err)
			}

			if (err != nil) != tt.wantErr {
				t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if got.String() != tt.want {
				t.Errorf("got %s, want %v", got.String(), tt.want)
			}
		})
	}
}

func generatorURLFromExpr(expr string) string {
	return fmt.Sprintf("https://prometheus.gstg.gitlab.net/graph?g0.expr=%s&g0.tab=1", url.QueryEscape(expr))
}

type Payload struct {
	Receiver          string        `json:"receiver"`
	Status            string        `json:"status"`
	Alerts            []Alert       `json:"alerts"`
	GroupLabels       amtemplate.KV `json:"groupLabels"`
	CommonLabels      amtemplate.KV `json:"commonLabels"`
	CommonAnnotations amtemplate.KV `json:"commonAnnotations"`
	ExternalURL       string        `json:"externalURL"`
	Version           string        `json:"version"`
	GroupKey          string        `json:"groupKey"`
}

type Alert struct {
	Status       string        `json:"status"`
	Labels       amtemplate.KV `json:"labels"`
	Annotations  amtemplate.KV `json:"annotations"`
	StartsAt     string        `json:"startsAt"`
	EndsAt       string        `json:"endsAt"`
	GeneratorURL string        `json:"generatorURL"`
}

func wantFromFile(t *testing.T, path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
