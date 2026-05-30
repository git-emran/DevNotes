#import "@preview/basic-resume:0.2.8": *

// Put your personal information here, replacing mine
#let name = "Emran Hossain"
#let email = "clearlybestemran@gmail.com"
#let linkedin = "www.linkedin.com/in/emran-hossain-80ab17190/"
#let personal-site = "www.github.com/git-emran"


#show: resume.with(
  author: name,
  // All the lines below are optional.
  // For example, if you want to to hide your phone number:
  // feel free to comment those lines out and they will not show.
  email: email,
  linkedin: linkedin,
  personal-site: personal-site,
  accent-color: "#26428b",
  font: "New Computer Modern",
  paper: "us-letter",
  author-position: left,
  personal-info-position: left,
)

== Summary
Senior Front-End Engineer with 7+ years building high-performance B2B SaaS, AI/ML products end-to-end. Deep React/TypeScript, Golang and Python expertise paired with genuine Product Design fluency.

== Work Experience

#work(
  title: "Senior Front-End Engineer",
  location: "Copenhagen, Denmark",
  company: "Tiblo Digital",
  dates: dates-helper(start-date: "May 2024", end-date: "Present"),
)
- Designed and shipped WheelLog, a B2B tire-management SaaS, leading the full product lifecycle from discovery interviews with 20+ fleet managers through a 3-sprint prototype cycle, achieving *80% customer conversion in Q1*.
- Architected real-time multi-user collaboration with presence detection using CRDT in React, *eliminating write conflicts* in concurrent sessions and enabling live co-editing for the first time on the platform.
- Established a Figma-based design system and Storybook component library used by the full engineering team, *reducing design debt by 40%* and front-end development time by 30%.

#work(
  title: "Lead Front-end Engineer",
  location: "Dubai, UAE",
  company: "The Total Office (Contract)",
  dates: dates-helper(start-date: "Apr 2023", end-date: "May 2024"),
)
- Optimized Core Web Vitals (LCP, CLS, FID) for a high-traffic e-commerce platform implemented image lazy loading, code splitting, and service workers cutting page load from 3.4s to 1.2s and *lifting conversion rates by 20%*.
- Drove a full accessibility overhaul, Introduced ARIA attributes and customizable keyboard navigation across all core flows, achieving *98% user satisfaction* from testers with diverse abilities and full WCAG 2.1 AA compliance.
- Led security remediation effort in partnership with the backend team, triaging and resolving *411 CVEs down to 3* and embedding a design-review security checkpoint into the release pipeline to prevent regressions.

#work(
  title: "Lead UX/UI Developer",
  location: "Austin, Texas, USA",
  company: "MarketTime LLC",
  dates: dates-helper(start-date: "May 2022", end-date: "Apr 2023"),
)
- Built a company-wide UI component library from scratch standardizing design tokens, interaction patterns, and documentation *reducing front-end development time by 30%* and ensuring visual consistency across 4 product versions.
- Architected a Storybook-powered design system that decoupled component versioning from product releases, *cutting system upgrade costs by 60%* and accelerating design delivery speed by 90%.
- Designed and engineered mtPay, a Stripe-integrated in-app payment feature, leading 5 rounds of prototype usability testing before launch shipped to *95% user adoption* in the first month.

#work(
  title: "Front-end Engineer",
  location: "Dhaka, Bangladesh",
  company: "Roxnor (Contract)",
  dates: dates-helper(start-date: "Feb 2022", end-date: "May 2022"),
)
- Integrated the front end with AI REST APIs using React, implementing optimistic UI patterns that reduced perceived wait time by 40% and achieved a 4.7/5 user-satisfaction score in beta.
- Built a Gutenberg block-based editor for GetGenieAI, an AI-powered content-generation WordPress plugin handling async AI response streaming, loading states, and error fallbacks to deliver sub-200ms perceived latency.


== Project
#work(
  title: "Writer",
  dates: dates-helper(start-date: "Jun 2025", end-date: "Present")
)
- An open-source Markdown Editor with LSP, built in Terminal, AI assisted writing, Kanban board and a Freeform canvas to enhance agentic or general development workflow. Visit Project : https://github.com/git-emran/simple-notes


== Skills
- *Core Stack*: TypeScript, JavaScript (ES2022+), Node.js, HTML5/CSS3, Golang, Python
- *Technologies*: React, Astro, Angular, SolidJS, Svelte, Fast-API, Tailwind CSS, LangChain, REST-API, MongoDB, gRPC, Docker, Google Cloud Platform.
- *AI/ML*: LangChain, AI/ML product integration, Async AI streaming, OpenCV.
- *Tools*: Git, Linux, UNIX, CI/CD pipelines, Performance profiling(Lighthouse, Web Vitals).
