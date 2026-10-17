
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

Product Designer with a software engineering background, building B2B SaaS and AI products from early exploration through launch. I bring research, interaction design, prototyping, and technical implementation together to make complex workflows easier to use and products easier to build.

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
- Led the 0→1 UX for WheelLog, a B2B fleet-management platform serving an average of 5K–10K operators daily in a realtime environment. Ran 20+ customer interviews and a three-sprint prototyping cycle that helped bring the product to value six weeks faster.

- Helped grow monthly active users by 35% over two quarters by partnering with Product and Marketing to identify activation drop-offs and redesign core flows on the user dashboard.

- Built realistic fleet-telemetry prototypes with AI-assisted development, enabling remote user testing, A/B testing and evaluation of three major features before development.


#v(8pt)
#entry(
  "The Total Office (Contract)",
  "Apr 2023 – May 2024",
  "Product Design Lead",
  location: "Dubai, UAE",
)
- Reduced churn for a 500K+ user platform by running bi-weekly user behavior analytics reviews with the PM, translating findings into a prioritized backlog of UI optimizations, and shipping improvements across two quarters.

- Redesigned a legacy platform around WCAG 2.1 accessibility requirements, incorporating custom keyboard and voice-navigation patterns to make core interactions more accessible. Validated the experience through three rounds of moderated testing with 30 users with disabilities and passed an external audit with zero critical violations.

- Built a design system from scratch using "token method" to standardize user interface design decisions and component reusability. Built rapid prototypes using agentic development.

#v(8pt)
#entry(
  "MarketTime LLC",
  "May 2022 – Apr 2023",
  "Lead UI/UX Designer",
  location: "Austin, Texas, USA",
)
- Reorganized the B2B order-management dashboard using task frequency and error severity to guide information hierarchy, bringing high-use actions forward and making critical order-entry workflows easier to scan.

- Designed and shipped a company-wide design system with 40+ components, standardizing existing design tokens, reusable patterns, and interaction documentation to improve interface consistency and give engineering a more reliable implementation reference.

- Led the end-to-end checkout and payment flow for mtPay (Stripe integration), achieving 95% user adoption at launch by resolving 12 critical friction points identified across five rounds of usability testing.

#v(8pt)

#entry(
  "Roxnor (Contract)",
  "Feb 2022 – May 2022",
  "Lead Product Designer",
  location: "Dhaka, Bangladesh",
)
- Cut the spatial-scanning workflow from 15 steps to five by introducing ML-assisted autocomplete, inline error recovery, and step-level cognitive-load audits. Simplified the path through onboarding while decreasing inbound support tickets

- Reduced design-related PR review cycles from four rounds to one over three months by bridging design and engineering on a six-person cross-functional team and resolving implementation ambiguities earlier.

- Designed the user experience for a computer-vision-powered 3D spatial-scanning workflow and created an interactive in-app guide to help users navigate the process. Validated the experience through three rounds of moderated testing with 24 users

#v(8pt)

#entry(
  "Genex Infosys PLC",
  "May 2020 – Feb 2022",
  "Jr. Software Engineer",
  location: "Dhaka, Bangladesh",
)
- Engineered a conversational AI platform for a government bank portal serving 1M+ monthly users. Built a multi-turn intent classification pipeline using Dialogflow CX and custom NLP fallback handlers, achieving 97% query resolution accuracy and reducing average resolution time by 60%, while supporting 50K concurrent sessions without latency degradation.

- Led the design architecture and end-to-end UX for an enterprise conversational AI platform deployed across a major tier-1 banking portal, driving a 90% increase in monthly customer interactions.

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
- *Core Stack:* TypeScript, JavaScript (ES2022+), Node.js, HTML5/CSS3, Golang, Python.
- *Technologies:* React, Astro, Angular, SolidJS, Svelte, FastAPI, WebSockets, LangChain, OpenCV, MongoDB, gRPC, Docker, Async AI Streaming, Git, Linux, UNIX, CI/CD Pipelines, AI/ML Product Integration.
