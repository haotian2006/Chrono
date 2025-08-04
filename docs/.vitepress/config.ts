import { defineConfig } from 'vitepress'

function sidebar() {
  return {
    "/Learn": [
       { text: "Quick Start", collapsed: false, items: [
          { text: "Why", link: "/Learn/Why" },
          { text: "Installation", link: "/Learn/Installation" },
          { text: "Usage", link: "/Learn/Usage" },
        ] },
        { text: "Learn", collapsed: false, items: [
            { text: "Interpolation Buffer", link: "/Learn/Interpolation-Buffer" },
            { text: "Snapshots", link: "/Learn/Snapshots" },
            { text: "Client Tick", link: "/Learn/Client-Tick" },
            { text: "Serialization", link: "/Learn/Serialization" },
            { text: "Disabling Default Replication", link: "/Learn/Disabling-Default-Replication" },
        ] },
    ],
    "/API": [
      {text: "API", collapsed: false, items: [
        { text: "ChronoClient", link: "/API/ChronoClient" },
        { text: "ChronoServer", link: "/API/ChronoServer" },
        { text: "Snapshots", link: "/API/Snapshots" },
        { text: "InterpolationBuffer", link: "/API/Interpolation-Buffer" },
        { text: "RenderCache", link: "/API/RenderCache" },
      ] }
    ]
  }
}

export default defineConfig({
  base: '/Chrono/',
  title: 'Chrono',
  description: 'Chrono',
  lang: 'en-US',
  head: [
    // ['link', { rel: 'icon', href: '/favicon.png' }],
  ],
  themeConfig: {
    // siteTitle: false,
    outline: 'deep',
    socialLinks: [
      { icon: 'github', link: 'https://github.com/Parihsz/Chrono' },
    ],
    sidebar: sidebar(),
  }
})
