import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'zigantic',
  description: 'Pydantic-like data validation and JSON serialization for Zig. 40+ validation types, compile-time driven, zero runtime overhead.',
  base: '/zigantic/',
  
  head: [
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { name: 'og:type', content: 'website' }],
    ['meta', { name: 'og:title', content: 'zigantic - Pydantic for Zig' }],
    ['meta', { name: 'og:description', content: 'Type-safe data validation with 40+ built-in types, human-readable errors, and zero runtime overhead.' }],
    ['meta', { name: 'og:url', content: 'https://muhammad-fiaz.github.io/zigantic/' }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { name: 'twitter:title', content: 'zigantic - Pydantic for Zig' }],
    ['meta', { name: 'twitter:description', content: 'Type-safe data validation with 40+ built-in types.' }],
    ['meta', { name: 'keywords', content: 'zig, zigantic, pydantic, validation, json, serialization, types, compile-time' }],
  ],

  themeConfig: {
    logo: '/logo.svg',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/types' },
      { 
        text: 'v0.0.1', 
        items: [
          { text: 'Changelog', link: 'https://github.com/muhammad-fiaz/zigantic/releases' },
          { text: 'Contributing', link: 'https://github.com/muhammad-fiaz/zigantic/blob/main/CONTRIBUTING.md' },
        ]
      },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Quick Start', link: '/guide/quick-start' },
            { text: 'Philosophy', link: '/guide/philosophy' },
          ],
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Validation Types', link: '/guide/validation-types' },
            { text: 'JSON Parsing', link: '/guide/json-parsing' },
            { text: 'Error Handling', link: '/guide/error-handling' },
          ],
        },
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Types', link: '/api/types' },
            { text: 'Validators', link: '/api/validators' },
            { text: 'JSON', link: '/api/json' },
            { text: 'Errors', link: '/api/errors' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/zigantic' },
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2025 Muhammad Fiaz',
    },

    search: {
      provider: 'local',
    },

    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/zigantic/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },

    lastUpdated: {
      text: 'Last updated',
      formatOptions: {
        dateStyle: 'medium',
        timeStyle: 'short',
      },
    },

    outline: {
      level: [2, 3],
      label: 'On this page',
    },

    docFooter: {
      prev: 'Previous',
      next: 'Next',
    },
  },

  markdown: {
    lineNumbers: true,
    theme: {
      light: 'github-light',
      dark: 'github-dark',
    },
  },

  sitemap: {
    hostname: 'https://muhammad-fiaz.github.io/zigantic/',
  },

  lastUpdated: true,
})
