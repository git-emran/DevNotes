
#import "@preview/basic-resume:0.2.8": *

// Put your personal information here, replacing mine
#let name = "Emran Hossain"
#let email = "emrn.hossn@gmail.com"
#let linkedin = "www.linkedin.com/in/emran-hossain-80ab17190/"
#let personal-site = "www.github.com/git-emran"
#let phone = "+880-1886-324-116"


/*
* Lines that start with == are formatted into section headings
* You can use the specific formatting functions if needed
* The following formatting functions are listed below
* #edu(dates: "", degree: "", gpa: "", institution: "", location: "")
* #work(company: "", dates: "", location: "", title: "")
* #project(dates: "", name: "", role: "", url: "")
* #extracurriculars(activity: "", dates: "")
* There are also the following generic functions that don't apply any formatting
* #generic-two-by-two(top-left: "", top-right: "", bottom-left: "", bottom-right: "")
* #generic-one-by-two(left: "", right: "")
*/

#show: resume.with(
  author: name,
  // All the lines below are optional.
  // For example, if you want to to hide your phone number:
  // feel free to comment those lines out and they will not show.
  email: email,
  linkedin: linkedin,
  personal-site: personal-site,
  accent-color: "#26428b",
  phone: phone,
  font: "New Computer Modern",
  font-size: 10pt,
  paper: "us-letter",
  author-position: left,
  personal-info-position: left,
)

== Summary
Senior Front-End Engineer with 6+ years shipping high-impact B2B SaaS and AI products. Specialized in building complex, real-time React/TypeScript applications at scale. Proven ability to lead full product cycles, design systems, performance optimization, and cross-functional collaboration resulting in significant business outcomes.

== Education
#edu(
  institution: "University of Information Technologies and Sciences",
  location: "Dhaka, Bangladesh",
  dates: dates-helper(start-date: "Mar 2013", end-date: "Jun 2017"),
  degree: "Bachelor's of Science, Computer Science and Mathematics"
)
- Cumulative GPA: 4.0/4.0 | Dean's List, Merit Scholarship
== Work Experience

#work(
  title: "Senior Front-End Engineer",
  location: "Copenhagen, Denmark",
  company: "Tiblo Digital",
  dates: dates-helper(start-date: "May 2024", end-date: "Present"),
)
- Designed and shipped WheelLog, a B2B tire-management SaaS, leading the full product lifecycle from discovery interviews with 20+ fleet managers through a 3-sprint prototype cycle, achieving *80% customer conversion in Q1*.
- Architected real-time multi-user collaboration with presence detection using CRDT in React, *eliminating write conflicts* in concurrent sessions and enabling live co-editing for the first time on the platform for 100k Daily Active Users.
- Streamlined client onboarding by building a requirements-analysis framework that cut discovery-to-spec time by 35% and reduced revision cycles from 4 rounds to 1, measurably improving engineering throughput.
- *Championed a documentation-first engineering culture*; introduced ADRs (Architecture Decision Records) and a component contract specification process, *cutting cross-team integration bugs by 50%* and reducing onboarding time for new engineers from 2 weeks to 4 days.

#work(
  title: "Lead Front-end Engineer",
  location: "Dubai, UAE",
  company: "The Total Office (Contract)",
  dates: dates-helper(start-date: "Apr 2023", end-date: "May 2024"),
)
- Optimized Core Web Vitals (LCP, CLS, FID) for an e-commerce platform with serving 500k+ monthly users; implemented image lazy loading, code splitting, and service workers cutting page load from 3.4s to 1.2s and *lifting conversion rates by 20%*.
- Drove a full accessibility overhaul, introduced ARIA attributes and customizable keyboard navigation across all core flows, achieving *98% user satisfaction* from testers with diverse abilities and full WCAG 2.1 AA compliance.
- Neutralized 411 CVEs across the dependency tree; assessed vulnerabilities by CVSS score using Snyk + npm audit, shipped remediations to all critical/high-severity issues within a single sprint, and embedded a mandatory dependency-audit gate in the CI/CD pipeline—reducing future CVE exposure by 100% at merge time.
- *Scaled front-end team velocity 2×*; introduced a component-driven development workflow with Storybook visual regression testing, reducing QA cycles from 5 days to 2 and cutting UI bug regression rate by 65% across quarterly releases.

#work(
  title: "Lead Front-end Engineer",
  location: "Austin, Texas, USA",
  company: "MarketTime LLC",
  dates: dates-helper(start-date: "May 2022", end-date: "Apr 2023"),
)
- Architected the token layer of the design system using Style Dictionary, defining a single source-of-truth JSON schema that compiled to CSS custom properties, JS constants, and Figma tokens simultaneously, *eliminating token drift across 4 product versions*.
- *Decoupled design system versioning from product releases*; published components as independent npm packages versioned via semantic-release, enabling teams to adopt system upgrades asynchronously—cutting system upgrade costs by 60% and accelerating design delivery speed by 90% across 3 product teams.
- Engineered automated visual regression testing at component level: integrated Chromatic CI into the design system pipeline, catching pixel-level regressions across 200+ components before merge—reducing production UI defects by 74% over 6 months and saving ~12 QA hours per release cycle.


#work(
  title: "Front-end Engineer",
  location: "Dhaka, Bangladesh",
  company: "Roxnor (Contract)",
  dates: dates-helper(start-date: "Feb 2022", end-date: "May 2022"),
)
- Implemented optimistic UI patterns using React's useReducer; dispatched local state updates immediately on user action, then reconciled with the API response, reducing perceived wait time by 40% and achieving a 4.7/5 beta satisfaction score.
- Built the full front end for GetGenieAI, a Gutenberg block-based AI content-generation WordPress plugin; implemented streaming AI responses via ReadableStream and TextDecoder, chunking token output into the editor in real time to deliver sub-200ms perceived latency.

#work(
  title: "Jr. Software Engineer",
  location: "Dhaka, Bangladesh",
  company: "Genex Infosys PLC",
  dates: dates-helper(start-date: "May 2020", end-date: "Feb 2022")
)

- *Engineered a Conversational AI platform* for a government bank portal serving 1M+ monthly users; designed a multi-turn intent classification pipeline using Dialogflow CX with custom NLP fallback handlers, achieving 97% query resolution accuracy and reducing average resolution time by 60% while scaling to 50K concurrent sessions without latency degradation.

== Project
#project(
  name: "Writer",
  role: "Creator & Maintainer",
  dates: dates-helper(start-date: "Jun 2025", end-date: "Present"),
  url: "https://github.com/git-emran/simple-notes"
)
- An open-source Markdown Editor with LSP, built in Terminal, AI assisted writing, Kanban board and a Freeform canvas to enhance agentic or general development workflow.
- Optimized local markdown parsing and tokenization rendering to achieve sub-16ms frame times during heavy AI streaming sessions, dynamic tags to organize and maintain notes.

== Skills
- *Core Stack*: TypeScript, JavaScript (ES2022+), Node.js, HTML5/CSS3, Golang, Python.
- *Technologies*: React, Astro, Angular, SolidJS, Svelte, Fast-API, WebSockets, LangChain, Open-CV, MongoDB, gRPC, Docker, Async AI streaming, Git, Linux, UNIX, CI/CD pipelines, AI/ML product integration.
