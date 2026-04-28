local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

{
  generalGraphPanel(title, description=null, fill=0, decimals=2, legend_show=false, legend_min=true, legend_current=true)::
    grafana.graphPanel.new(
      title,
      description=description,
      linewidth=1,
      fill=fill,
      datasource='$PROMETHEUS_DS',
      decimals=decimals,
      legend_show=legend_show,
      legend_values=true,
      legend_min=legend_min,
      legend_max=true,
      legend_current=legend_current,
      legend_total=false,
      legend_avg=true,
      legend_alignAsTable=true,
      legend_hideEmpty=true,
    ),

  generalBytesGraphPanel(title, description=null, legend_show=true,)::
    self.generalGraphPanel(
      title,
      description=description,
      legend_show=legend_show,
    )
    .resetYaxes()
    .addYaxis(
      format='bytes',
      label='Size',
    )
    .addYaxis(
      format='short',
      max=1,
      min=0,
      show=false,
    ),

  generalPercentageGraphPanel(
    title, description=null, legend_show=false,
  )::
    self.generalGraphPanel(
      title,
      description=description,
      legend_show=legend_show,
    )
    .resetYaxes()
    .addYaxis(
      format='percentunit',
      max=1,
      label=title,
    )
    .addYaxis(
      format='short',
      max=1,
      min=0,
      show=false,
    ),

  generalTextPanel(title, content='', transparent=null, description=null)::
    grafana.text.new(
      title,
      span=null,
      mode='markdown',
      content=content,
      transparent=transparent,
      description=description,
      datasource='$PROMETHEUS_DS',
      repeat=null,
      repeatDirection=null,
      repeatMaxPerRow=null,
    ),
}
