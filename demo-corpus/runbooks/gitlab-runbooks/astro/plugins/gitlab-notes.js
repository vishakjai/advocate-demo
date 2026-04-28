// plugins/gitlab-notes.js
import { visit } from 'unist-util-visit';

/**
 * GitLab Notes Plugin - converts [!NOTE] syntax to Starlight asides
 */
export function remarkGitlabNotesSimple() {
  return (tree, file) => {
    visit(tree, 'blockquote', (node, index, parent) => {
      // Check if this blockquote has the GitLab alert pattern
      if (!node.children || node.children.length === 0) {
        return;
      }

      const firstChild = node.children[0];
      if (firstChild.type !== 'paragraph') {
        return;
      }

      if (!firstChild.children || firstChild.children.length === 0) {
        return;
      }

      const firstNode = firstChild.children[0];
      if (firstNode.type !== 'text') {
        return;
      }

      const lines = firstNode.value.split('\n');

      const match = lines[0].match(/^\[!(note|warning|tip|caution|important|error|danger|info)\](\s([^\n]+))?/i);

      if (!match) {
        return;
      }

      const noteType = match[1].toLowerCase();

      let customTitle = match[3];
      let content = lines
          .slice(1)
          .join('\n');

      // Map to Starlight types
      const typeMapping = {
        note: 'note',
        tip: 'tip',
        warning: 'caution',
        caution: 'caution',
        important: 'tip',
        error: 'danger',
        danger: 'danger',
        info: 'note',
      };

      const starlightType = typeMapping[noteType] || 'note';

      // Handle Important as a special case to preserve the title
      if (noteType === "important" && !customTitle) {
        customTitle = "Important";
      }

      // Create the aside node matching native Starlight structure
      const asideNode = {
        type: 'containerDirective',
        name: starlightType,
        attributes: {},
        children: []
      };

      if (customTitle) {
        asideNode.children.push({
          "type": "paragraph",
          "data": {
            "directiveLabel": true
          },
          "children": [
            {
              "type": "text",
              "value": customTitle
            }
          ]
        })
      }

      firstNode.value = content;
      firstChild.children[0] = firstNode;

      asideNode.children.push(firstChild);
      asideNode.children.push(...node.children.slice(1));

      parent.children[index] = asideNode;
    });
  };
}
