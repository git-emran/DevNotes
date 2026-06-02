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
Senior Front-End Engineer with 7+ years building high-performance B2B SaaS, AI/ML products end-to-end. Deep React/TypeScript, Golang and Python expertise paired with genuine Product Design fluency with a proven track record of shipping measurable outcomes.

== Work Experience

#work(
  title: "Senior Front-End Engineer",
  location: "Copenhagen, Denmark",
  company: "Tiblo Digital",
  dates: dates-helper(start-date: "May 2024", end-date: "Present"),
)
- Designed and shipped WheelLog, a B2B tire-management SaaS, leading the full product lifecycle from discovery interviews with 20+ fleet managers through a 3-sprint prototype cycle, achieving *80% customer conversion in Q1*.
- Architected real-time multi-user collaboration with presence detection using CRDT in React, *eliminating write conflicts* in concurrent sessions and enabling live co-editing for the first time on the platform.
- Streamlined client onboarding by building a requirements-analysis framework that cut discovery-to-spec time by 35% and reduced revision cycles from 4 rounds to 1, measurably improving engineering throughput.

#work(
  title: "Lead Front-end Engineer",
  location: "Dubai, UAE",
  company: "The Total Office (Contract)",
  dates: dates-helper(start-date: "Apr 2023", end-date: "May 2024"),
)
- Optimized Core Web Vitals (LCP, CLS, FID) for a high-traffic e-commerce platform; implemented image lazy loading, code splitting, and service workers cutting page load from 3.4s to 1.2s and *lifting conversion rates by 20%*.
- Drove a full accessibility overhaul, introduced ARIA attributes and customizable keyboard navigation across all core flows, achieving *98% user satisfaction* from testers with diverse abilities and full WCAG 2.1 AA compliance.
- Led security remediation in partnership with the backend team, tackled 411 CVEs using Snyk and npm audit, classified by CVSS score, and shipped fixes to 3 remaining low-severity issues while embedding a mandatory dependency-audit step into the CI/CD release pipeline.

#work(
  title: "Lead Front-end Engineer",
  location: "Austin, Texas, USA",
  company: "MarketTime LLC",
  dates: dates-helper(start-date: "May 2022", end-date: "Apr 2023"),
)
- Architected the token layer of the design system using Style Dictionary, defining a single source-of-truth JSON schema that compiled to CSS custom properties, JS constants, and Figma tokens simultaneously, *eliminating token drift across 4 product versions*.
- Decoupled component versioning from product releases via a Storybook-powered design system and independent npm package publishing, cutting system upgrade costs by 60% and accelerating design delivery speed by 90%.

#work(
  title: "Front-end Engineer",
  location: "Dhaka, Bangladesh",
  company: "Roxnor (Contract)",
  dates: dates-helper(start-date: "Feb 2022", end-date: "May 2022"),
)
- Implemented optimistic UI patterns using React's useReducer; dispatched local state updates immediately on user action, then reconciled with the API response, reducing perceived wait time by 40% and achieving a 4.7/5 beta satisfaction score.
- Built the full front end for GetGenieAI, a Gutenberg block-based AI content-generation WordPress plugin; implemented streaming AI responses via ReadableStream and TextDecoder, chunking token output into the editor in real time to deliver sub-200ms perceived latency.

== Project
#work(
  title: "Writer",
  company: "Open-source Creator & Maintainer",
  dates: dates-helper(start-date: "Jun 2025", end-date: "Present")
)
- An open-source Markdown Editor with LSP, built in Terminal, AI assisted writing, Kanban board and a Freeform canvas to enhance agentic or general development workflow. Visit Project : https://github.com/git-emran/simple-notes


== Skills
- *Core Stack*: TypeScript, JavaScript (ES2022+), Node.js, HTML5/CSS3, Golang, Python.
- *Technologies*: React, Astro, Angular, SolidJS, Svelte, Fast-API, WebSockets, LangChain, Open-CV, MongoDB, gRPC, Docker, Async AI streaming, Git, Linux, UNIX, CI/CD pipelines, AI/ML product integration.
