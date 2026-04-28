// @ts-check
import { defineConfig } from 'astro/config';
import mermaid from 'astro-mermaid';
import mermaidZoom from './src/astro-mermaid-zoom.ts';
import starlight from '@astrojs/starlight';
import starlightAutoSidebar from 'starlight-auto-sidebar';
import starlightImageZoom from 'starlight-image-zoom';
import { remarkGitlabNotesSimple } from './plugins/gitlab-notes.js';

// https://astro.build/config
export default defineConfig({
  integrations: [
    starlight({
      plugins: [starlightAutoSidebar(), starlightImageZoom()],
      title: 'Runbooks',
      social: [
        { icon: 'gitlab', label: 'GitLab', href: 'https://gitlab.com/gitlab-com/runbooks' },
        { icon: 'puzzle', label: 'Code Context', href: 'https://code-context.runway.gitlab.net/runbooks-docs' },
      ],
    }),
    mermaid({
      theme: 'neutral',
      autoTheme: true,
      mermaidConfig: {
        startOnLoad: false,
        logLevel: 'error',
        securityLevel: 'strict',
      }
    }),
    mermaidZoom(),
  ],
  markdown: {
    remarkPlugins: [
      remarkGitlabNotesSimple,
    ],
  },
});
