
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
#align(center)[
  #text(size: 21pt, weight: "bold")[#name]

  #v(2pt)
  #text(size: 9pt, fill: accent)[
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

Senior Front-End Engineer with 6+ years of experience architecting complex B2B SaaS platforms, AI-powered products, and developer infrastructure. Specializes in React, TypeScript, real-time collaboration, design-system architecture, and performance engineering. I combine hands-on implementation with system-level thinking, translating ambiguous product requirements into resilient architectures, measurable customer outcomes, and engineering workflows that scale across teams.

#v(4pt)
#section("Education")

#entry(
  "University of Information Technologies and Sciences",
  "Mar 2013 – Jun 2017",
  "Bachelor's of Science, Computer Science and Mathematics",
  location: "Dhaka, Bangladesh",
)


#v(4pt)
#section("Work Experience")

#entry(
  "Tiblo Digital",
  "May 2024 – Present",
  "Lead Front-End Engineer",
  location: "Copenhagen, Denmark",
)
#v(2pt)
- Engineered WheelLog's front-end application from prototype to production, translating discovery findings from 20+ fleet-manager interviews into application workflows, reusable UI components, and production-ready feature implementations which help me achieve 80% customer conversion in Q1.

- Implemented CRDT-based state synchronization and presence tracking for a multi-user fleet-management application, coordinating concurrent edits without destructive write conflicts and supporting real-time collaboration across a platform with 100K daily active users.

- Developed a requirements-to-specification workflow that standardized technical scoping, acceptance criteria, and implementation handoffs, reducing discovery-to-specification time by 35% and cutting revision cycles from four rounds to one.

- Introduced architecture decision records (ADRs), explicit component contracts, and documented integration boundaries to reduce ambiguity between engineering teams, cutting cross-team integration defects by 50% and reducing engineer onboarding time from two weeks to four days.

#v(9pt)
#entry(
  "The Total Office (Contract)",
  "Apr 2023 – May 2024",
  "Lead Front-end Engineer",
  location: "Dubai, UAE",
)
- Reduced page-load time from 3.4s to 1.2s on an e-commerce application serving 500K+ monthly users by implementing route-level code splitting, deferred image loading, service-worker caching and it improved conversion by 20%.

- Refactored accessible interaction patterns across core application flows, implementing semantic HTML, ARIA attributes, and keyboard-navigation behavior to meet WCAG 2.1 AA requirements and achieve 98% satisfaction among accessibility testers.

- Audited the transitive dependency tree using Snyk and npm audit, triaged 411 vulnerability findings by CVSS severity, and remediated critical and high-severity issues within one sprint. Integrated dependency auditing into CI/CD to enforce security checks before code integration.

- Established a component-driven development pipeline using Storybook and visual regression testing, standardizing component isolation and UI verification across the team. Doubled team velocity, reduced QA cycles from five days to two, and decreased UI regression rates by 65%.

#v(9pt)
#entry(
  "MarketTime LLC",
  "May 2022 – Apr 2023",
  "Lead Front-end Engineer",
  location: "Austin, Texas, USA",
)
- Architected a design-token compilation pipeline with Style Dictionary, defining a canonical JSON token schema and generating platform-specific outputs for CSS custom properties, JavaScript constants, and Figma. Eliminated token inconsistencies across four product versions.

- Distributed the design system as independently versioned npm packages using semantic-release, decoupling component releases from application deployment schedules and enabling three product teams to upgrade asynchronously which reduced upgrade costs by 60% and accelerated design delivery by 90%.

- Integrated Chromatic visual regression testing into the component CI pipeline, validating visual changes across 200+ components before merge and preventing unintended UI changes from reaching production. Reduced production UI defects by 74% over six months and saved approximately 12 QA hours per release cycle.
#v(9pt)
#entry(
  "Roxnor (Contract)",
  "Feb 2022 – May 2022",
  "Front-end Engineer",
  location: "Dhaka, Bangladesh",
)
- Implemented optimistic state transitions using React's useReducer, separating immediate client-side updates from asynchronous server reconciliation and handling rollback on failed mutations; reduced perceived interaction latency by 40% and achieved a 4.7/5 beta satisfaction score.

- Developed the front end for GetGenieAI, a Gutenberg-based AI content-generation plugin, using the Streams API (ReadableStream) and TextDecoder to incrementally decode and render streamed model responses inside the editor, achieving sub-200ms perceived latency.

#v(9pt)
#entry(
  "Genex Infosys PLC",
  "May 2020 – Feb 2022",
  "Jr. Software Engineer",
  location: "Dhaka, Bangladesh",
)
- Implemented a conversational AI system for a government banking portal serving 1M+ monthly users, combining Dialogflow CX multi-turn intent routing with custom NLP fallback handlers to improve classification coverage and query resolution. Achieved 97% query-resolution accuracy, reduced average resolution time by 60%, and supported 50K concurrent sessions without latency degradation.

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
- Built a terminal-native Markdown editor integrating language-server support, AI-assisted writing, Kanban task management, and a freeform canvas into a unified development workspace.

- Optimized Markdown parsing, tokenization, and incremental rendering to maintain sub-16ms frame times during high-volume AI streaming, also implemented dynamic tagging for structured note organization and retrieval.

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
- Implemented a Markdown-to-slide rendering pipeline on Neovim's native buffer infrastructure, parsing document headings into a center-aligned presentation layout with custom parsing and rendering logic.


#v(9pt)
#section("Skills")

- *Languages:* TypeScript, JavaScript (ES2022+), Go, Python, HTML5, CSS3
- *Application Engineering:* React, Node.js, Astro, Angular, SolidJS, Svelte, state management, component architecture, rendering optimization, accessibility
- *Concurrency & Communication:* CRDTs, WebSockets, asynchronous processing, streaming APIs, gRPC
- *Design-System Infrastructure:* Style Dictionary, design tokens, Storybook, Chromatic, npm package architecture, semantic-release
- *AI & Data:* LangChain, OpenCV, FastAPI, MongoDB, AI streaming interfaces, NLP integration
- *Infrastructure & Quality:* Docker, Linux, Unix, Git, CI/CD, automated testing, dependency security, performance profiling
