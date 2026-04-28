local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'aesthetics' });

{
  separator()::
    function(options)
      [
        toolingLinkDefinition({
          markdown: '---\n',
        }),
      ],
}
