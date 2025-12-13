import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'zigantic',
  description: 'Pydantic-like data validation and serialization for Zig',
  base: '/zigantic/',
  
  head: [
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { name: 'author', content: 'Muhammad Fiaz' }],
  ],

  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/types' },
      { text: 'GitHub', link: 'https://github.com/muhammad-fiaz/zigantic' }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Quick Start', link: '/guide/quick-start' },
            { text: 'Philosophy', link: '/guide/philosophy' }
          ]
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Validation Types', link: '/guide/validation-types' },
            { text: 'JSON Parsing', link: '/guide/json-parsing' },
            { text: 'Error Handling', link: '/guide/error-handling' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Types', link: '/api/types' },
            { text: 'Validators', link: '/api/validators' },
            { text: 'JSON', link: '/api/json' },
            { text: 'Errors', link: '/api/errors' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/zigantic' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2025 Muhammad Fiaz'
    },

    search: {
      provider: 'local'
    }
  }
})
