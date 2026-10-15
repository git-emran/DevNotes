
#set document(title: "Emran Hossain - Resume")
#set page(
  paper: "us-letter",
  margin: (
    top: 0.45in,
    bottom: 0.45in,
    left: 0.55in,
    right: 0.55in,
  ),
)
#set text(
  font: "New Computer Modern",
  size: 11pt,
  lang: "en",
)
#set par(
  justify: false,
  leading: 0.45em,
  spacing: 6pt,
)
#set list(
  indent: 12pt,
  body-indent: 4pt,
  spacing: 8pt,
)

#let accent = rgb("#26428b")

// Personal information
#let name = "Emran Hossain"
#let email = "emrn.hossn@gmail.com"
#let linkedin = "www.linkedin.com/in/emran-hossain-80ab17190/"
#let personal-site = "www.github.com/git-emran"
#let phone = "880-1886-324-116"

// Section heading
#let section(title) = {
  v(5pt)
  text(size: 12pt, weight: "bold")[#title]
  v(-1pt)
  line(length: 100%, stroke: 0.4pt + accent)
  v(3pt)
}

// General entry with right-aligned italic dates
#let entry(title, dates, subtitle, location: "") = {
  grid(
    columns: (1fr, auto),
    column-gutter: 8pt,
    [#text(weight: "bold")[#title]],
    [#align(right)[#text(style: "italic")[#dates]]],
  )
  grid(
    columns: (1fr, auto),
    column-gutter: 8pt,
    [#subtitle],
    [#align(right)[#text(size: 9pt)[#location]]],
  )
  v(2pt)
}

// Header
#align(left)[
  #text(size: 21pt, weight: "bold")[#name]

  #v(2pt)
  #text(size: 8pt, fill: accent)[
    #link("mailto:" + email)[#email]
    #h(5pt) | #h(5pt)
    #link("https://" + linkedin)[LinkedIn]
    #h(5pt) | #h(5pt)
    #link("https://" + personal-site)[GitHub]
    #h(5pt) | #h(5pt)
    #phone
  ]

  #v(2pt)
]

#section("Summary")

Senior Front-End Engineer with 7+ years shipping high-impact B2B SaaS and AI products. Specialized in building complex, real-time React/TypeScript applications at scale. Proven ability to lead full product cycles, design systems, performance optimization, and cross-functional collaboration resulting in significant business outcomes.

#section("Education")

#entry(
  "University of Information Technologies and Sciences",
  "Mar 2013 – Jun 2017",
  "Bachelor's of Science, Computer Science and Mathematics",
  location: "Dhaka, Bangladesh",
)
- Cumulative GPA: 4.0/4.0 | Dean's List, Merit Scholarship

#v(9pt)

#section("Work Experience")

#entry(
  "Tiblo Digital",
  "May 2024 – Present",
  "Lead Front-End Engineer",
  location: "Copenhagen, Denmark",
)
#v(2pt)
- Designed and shipped WheelLog, a B2B tire-management SaaS, leading the full product lifecycle from discovery interviews with 20+ fleet managers through a 3-sprint prototype cycle, achieving *80% customer conversion in Q1*.
- Architected real-time multi-user collaboration with presence detection using CRDT in React, *eliminating write conflicts* in concurrent sessions and enabling live co-editing for the first time on the platform for 100k Daily Active Users.
- Streamlined client onboarding by building a requirements-analysis framework that cut discovery-to-spec time by 35% and reduced revision cycles from 4 rounds to 1, measurably improving engineering throughput.
- *Championed a documentation-first engineering culture*, introduced ADRs (Architecture Decision Records) and a component contract specification process, *cutting cross-team integration bugs by 50%* and reducing onboarding time for new engineers from 2 weeks to 4 days.

#v(9pt)
#entry(
  "The Total Office (Contract)",
  "Apr 2023 – May 2024",
  "Lead Front-end Engineer",
  location: "Dubai, UAE",
)
- Optimized Core Web Vitals (LCP, CLS, FID) for an e-commerce platform with serving 500k+ monthly users, implemented image lazy loading, code splitting, and service workers cutting page load from 3.4s to 1.2s and *lifting conversion rates by 20%*.
- Drove a full accessibility overhaul, introduced ARIA attributes and customizable keyboard navigation across all core flows, achieving *98% user satisfaction* from testers with diverse abilities and full WCAG 2.1 AA compliance.
- Neutralized 411 CVEs across the dependency tree and assessed vulnerabilities by CVSS score using Snyk + npm audit, shipped remediations to all critical/high-severity issues within a single sprint, and embedded a mandatory dependency-audit gate in the CI/CD pipeline—reducing future CVE exposure by 100% at merge time.
- *Scaled front-end team velocity 2×*, introduced a component-driven development workflow with Storybook visual regression testing, reducing QA cycles from 5 days to 2 and cutting UI bug regression rate by 65% across quarterly releases.

#v(9pt)
#entry(
  "MarketTime LLC",
  "May 2022 – Apr 2023",
  "Lead Front-end Engineer",
  location: "Austin, Texas, USA",
)
- Architected the token layer of the design system using Style Dictionary, defining a single source-of-truth JSON schema that compiled to CSS custom properties, JS constants, and Figma tokens simultaneously, *eliminating token drift across 4 product versions*.
- *Decoupled design system versioning from product releases* and published components as independent npm packages versioned via semantic-release, enabling teams to adopt system upgrades asynchronously—cutting system upgrade costs by 60% and accelerating design delivery speed by 90% across 3 product teams.
- Engineered automated visual regression testing at component level, integrated Chromatic CI into the design system pipeline, catching pixel-level regressions across 200+ components before merge—reducing production UI defects by 74% over 6 months and saving ~12 QA hours per release cycle.

#v(9pt)
#entry(
  "Roxnor (Contract)",
  "Feb 2022 – May 2022",
  "Front-end Engineer",
  location: "Dhaka, Bangladesh",
)
- Implemented optimistic UI patterns using React's useReducer and dispatched local state updates immediately on user action, then reconciled with the API response, reducing perceived wait time by 40% and achieving a 4.7/5 beta satisfaction score.
- Built the full front end for GetGenieAI, a Gutenberg block-based AI content-generation WordPress plugin, implemented streaming AI responses via ReadableStream and TextDecoder, chunking token output into the editor in real time to deliver sub-200ms perceived latency.

#v(9pt)
#entry(
  "Genex Infosys PLC",
  "May 2020 – Feb 2022",
  "Jr. Software Engineer",
  location: "Dhaka, Bangladesh",
)
- *Engineered a Conversational AI platform* for a government bank portal serving 1M+ monthly users, designed a multi-turn intent classification pipeline using Dialogflow CX with custom NLP fallback handlers, achieving 97% query resolution accuracy and reducing average resolution time by 60% while scaling to 50K concurrent sessions without latency degradation.

#v(9pt)
#section("Project")

#grid(
  columns: (1fr, auto),
  column-gutter: 8pt,
  [
    #text(weight: "bold")[Writer]
    #text(size: 9pt, fill: accent)[
      #link("https://github.com/git-emran/simple-notes")[GitHub]
    ]
  ],
  [
    #align(right)[
      #text(style: "italic")[Jun 2025 – Present]
    ]
  ],

)

#text(style: "italic")[Creator & Maintainer]
- An open-source Markdown Editor with LSP, built in Terminal, AI assisted writing, Kanban board and a Freeform canvas to enhance agentic or general development workflow.
- Optimized local markdown parsing and tokenization rendering to achieve sub-16ms frame times during heavy AI streaming sessions, dynamic tags to organize and maintain notes.

#v(9pt)
#grid(
  columns: (1fr, auto),
  column-gutter: 8pt,
  [
    #text(weight: "bold")[Slides]
    #text(size: 9pt, fill: accent)[
      #link("https://github.com/git-emran/slides.nvim")[GitHub]
    ]
  ],
  [
    #align(right)[
      #text(style: "italic")[Oct 2026 – Present]
    ]
  ],

)

#text(style: "italic")[Creator & Maintainer]
- Designed a slideshow experience inside neovim's built in buffer creator, A custom parser for parsing Markdown headings into a center-aligned presentation layout with seamless, distraction-free rendering.


#v(9pt)
#section("Skills")

- *Core Stack*: TypeScript, JavaScript (ES2022+), Node.js, HTML5/CSS3, Golang, Python.
- *Technologies*: React, Astro, Angular, SolidJS, Svelte, Fast-API, WebSockets, LangChain, Open-CV, MongoDB, gRPC, Docker, Async AI streaming, Git, Linux, UNIX, CI/CD pipelines, AI/ML product integration.
