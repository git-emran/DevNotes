
#set document(title: "Emran Hossain - Resume")
#set page(
  paper: "us-letter",
  margin: (
    top: 0.35in,
    bottom: 0.55in,
    left: 0.55in,
    right: 0.55in,
  ),
)
#set text(
  font: "New Computer Modern",
  size: 10pt,
  lang: "en",
)
#set par(
  justify: false,
  leading: 0.65em,
  spacing: 4pt,
)
#set list(
  indent: 12pt,
  body-indent: 3pt,
  spacing: 10pt,
)

#let accent = rgb("#26428b")

// Personal information
#let name = "Emran Hossain"
#let email = "emrn.hossn@gmail.com"
#let linkedin = "www.linkedin.com/in/emran-hossain-80ab17190/"
#let personal-site = "emranh.vercel.app"
#let phone = "880-1886-324-116"
#let github = "www.github.com/git-emran"

// Reusable section heading
#let section(title) = {
  v(8pt)
  text(size: 10pt, weight: "bold")[#title]
  v(2pt)
  line(length: 100%, stroke: 0.3pt + accent)
  v(2pt)
}

// Reusable entry: title left, italic dates right,
// subtitle left, location right
#let entry(title, dates, subtitle, location: "") = {
  grid(
    columns: (4fr, auto),
    column-gutter: 9pt,
    [#text(weight: "bold")[#title]],
    [#align(right)[#text(style: "italic")[#dates]]],
  )
  v(3pt)
  grid(
    columns: (4fr, auto),
    column-gutter: 9pt,
    [#subtitle],
    [#align(right)[#text(size: 9pt)[#location]]],
  )
  v(2pt)
  // Space after each entry
  v(5pt)
}

// Header
#align(center)[
  #text(size: 21pt, weight: "bold")[#name]
  #text(size: 10pt, fill: accent)[
    #v(2pt)
    #phone
    #h(5pt) | #h(5pt)
    #link("mailto:" + email)[#email]
    #h(5pt) | #h(5pt)
    #link("https://" + personal-site)[Portfolio]
  ]
]

#section("Summary")

Senior Product Designer with 8+ years shipping high-impact B2B SaaS and AI products. I work across Product Design and Front-end Engineering with proven ability to lead full product cycles, design systems, performance optimization, and cross-functional collaboration resulting in significant business outcomes.

#section("Education")

#entry(
  "University of Information Technologies and Sciences",
  "Mar 2013 – Jun 2017",
  "Bachelor's of Science, Computer Science and Mathematics",
  location: "Dhaka, Bangladesh",
)

#section("Work Experience")
#entry(
  "Tiblo Digital",
  "May 2024 – Present",
  "Product Design Lead",
  location: "Copenhagen, Denmark",
)
- Took WheelLog from an early concept to a working fleet-management experience, grounding the first version in 20+ customer interviews and three sprints of prototyping. The work brought time to value forward by six weeks for a product serving 5K–10K operators.

- Built realistic fleet-telemetry prototypes with AI-assisted development, allowing the team to test three major features with remote users before committing to implementation.

#v(8pt)
#entry(
  "The Total Office (Contract)",
  "Apr 2023 – May 2024",
  "Product Design Lead",
  location: "Dubai, UAE",
)
- Worked with the PM to review user-behavior data every two weeks, turning recurring friction points into a prioritized backlog of improvements for a platform serving 500K+ users. Shipped changes over two quarters to address churn.

- Built a token-based design system from scratch to make components more reusable and give engineers a more consistent foundation for implementation. Used AI-assisted prototyping to explore ideas quickly.

#v(8pt)
#entry(
  "MarketTime LLC",
  "May 2022 – Apr 2023",
  "Lead UI/UX Designer",
  location: "Austin, Texas, USA",
)
- Reorganized a B2B order-management dashboard around task frequency and error severity, bringing high-frequency actions forward and reducing unnecessary cognitive load during order entry.

- Created a company-wide design system with 40+ reusable components, shared design tokens, interaction patterns, and implementation documentation to give design and engineering a consistent language.

#v(8pt)

#entry(
  "Roxnor (Contract)",
  "Feb 2022 – May 2022",
  "Lead Product Designer",
  location: "Dhaka, Bangladesh",
)
- Cut a spatial-scanning workflow from 15 steps to 5 using ML-assisted suggestions, inline error recovery, and step-level cognitive-load reviews, while reducing inbound onboarding support tickets.

- Brought design and engineering closer together on a six-person team, reducing design-related PR review cycles from four rounds to one over three months.

- Designed a computer-vision-powered 3D scanning experience and an interactive in-app guide, refining both through three rounds of moderated testing with 24 users.

#v(8pt)

#entry(
  "Genex Infosys PLC",
  "May 2020 – Feb 2022",
  "Jr. Software Engineer",
  location: "Dhaka, Bangladesh",
)
- Engineered a conversational AI platform for a government bank portal serving 1M+ monthly users. Built a multi-turn intent classification pipeline using Dialogflow CX and custom NLP fallback handlers, achieving 97% query resolution accuracy and reducing average resolution time by 60%, while supporting 50K concurrent sessions without latency degradation.

- Shaped the architecture and end-to-end user experience of an enterprise conversational AI platform for a major banking portal. Monthly customer interactions increased by 90% following deployment.

#v(8pt)

#section("Projects")

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
- Designed a slideshow experience with neovim's built in buffer creator, A custom parser for parsing Markdown headings into a center-aligned presentation layout with seamless, distraction-free rendering.

#section("Skills")

- *Product Design:* Figma, Origami, Prototyping, Design Systems, Information Architecture, User Research, Usability Testing, Product Strategy.

- *Design & Engineering:* Figma, Origami, TypeScript, JavaScript, HTML/CSS, React, Node.js, Python, Go.

- *Technologies:* React, Astro, Angular, SolidJS, Svelte, FastAPI, WebSockets, LangChain, OpenCV, MongoDB, gRPC, Docker, Async AI Streaming, Git, Linux, UNIX, CI/CD Pipelines, AI/ML Product Integration.
