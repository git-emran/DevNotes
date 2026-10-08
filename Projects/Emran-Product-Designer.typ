#import "@preview/basic-resume:0.2.8": *

// Put your personal information here, replacing mine
#let name = "Emran Hossain"
#let email = "emrn.hossn@gmail.com"
#let linkedin = "www.linkedin.com/in/emran-hossain-80ab17190/"
#let personal-site = "www.github.com/git-emran"
#let phone = "880-1886-324-116"


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
  phone: phone,
  personal-site: personal-site,
  accent-color: "#26428b",
  font: "New Computer Modern",
  font-size: 10pt,
  paper: "us-letter",
  author-position: left,
  personal-info-position: left,
)

== Summary
Senior Product Designer with 8+ years shipping high-impact B2B SaaS and AI products. I work across Product Design and Front-end Engineering with proven ability to lead full product cycles, design systems, performance optimization, and cross-functional collaboration resulting in significant business outcomes.

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
  title: "Product Design Lead",
  location: "Copenhagen, Denmark",
  company: "Tiblo Digital",
  dates: dates-helper(start-date: "May 2024", end-date: "Present"),
)
- Led the 0→1 UX for WheelLog, a B2B fleet-management platform serving 5K–10K operators. Ran 20+ customer interviews and a three-sprint prototyping cycle that helped bring the product to value six weeks faster and built a markdown based design system from scratch for rapid agentic development.
- Helped increase MAU by 35% over two quarters by working with PM and Marketing to identify activation drop-offs and prioritize retention improvements by redesigning the core user flows.
- Used AI-assisted development to build realistic fleet-telemetry prototypes for remote user testing, helping the team validate three major features before development.
- Led a cross-functional team of 12 (design, eng, research, policy) to ship AI citation transparency patter ns used by 1M+ users in the EU, satisfying DSA compliance requirements 3 weeks ahead of deadline.

#work(
  title: "Product Design Lead",
  location: "Dubai, UAE",
  company: "The Total Office (Contract)",
  dates: dates-helper(start-date: "Apr 2023", end-date: "May 2024"),
)
- Successfully reduced churn rate for a 500K+ user platform by running bi-weekly user behavior analytics reviews with the PM, translated findings into a prioritized backlog of UI optimizations and shipped them across two quarters.
- Redesigned a legacy platform following latest WCAG 2.1 compliancy with custom keyboard and voice navigation patterns, Also conducted 3 rounds of moderated usability testing with 30 users with disabilities, passed external audit with zero critical violations.
- Built a design system from scratch utilizing tokenization method for optimal developer experience for reusability. Built rapid prototypes using agentic development.

#work(
  title: "Lead UI/UX Designer",
  location: "Austin, Texas, USA",
  company: "MarketTime LLC",
  dates: dates-helper(start-date: "May 2022", end-date: "Apr 2023"),
)
- Redesigned the B2B order-management dashboard using data-driven layout prioritization. Also reduced complex order-entry time and decreased user support tickets related to transaction errors by 30%.
- Built and shipped a company-wide UI component library from scratch, and design system 40+ components following the atomic design patterns, standardized design tokens, detailed interaction patterns, and rigorous documentation cutting cross-functional engineering handoff cycles.
- Led the end-to-end checkout and payment flow for “mtPay”(Stripe Integration), achieving 95% user adoption at launch by proactively resolving 12 critical friction points identified across 5 rounds of usability testing.


#work(
  title: "Lead Product Designer",
  location: "Dhaka, Bangladesh",
  company: "Roxnor (Contract)",
  dates: dates-helper(start-date: "Feb 2022", end-date: "May 2022"),
)
- Reduced spatial scanning error rates and cut onboarding time from 15 steps to 5 steps by redesigning the capture flow with ML assisted autocomplete, inline error recovery, and step-level cognitive-load audits, decreased inbound on-boarding support tickets.
- Acted as design-engineering bridge for a cross-functional team of 6, reduced design-related PR review cycles from 4 rounds to 1 in over 3 months.
- Designed the UX for a Computer Vision powered 3D spatial scanning workflow, built an in-app interactive guide which was validated with 3 rounds of moderated testing with a group of 24 users which made scanning easier for brand new users.

#work(
  title: "Jr. Software Engineer",
  location: "Dhaka, Bangladesh",
  company: "Genex Infosys PLC",
  dates: dates-helper(start-date: "May 2020", end-date: "Feb 2022")
)

- *Engineered a Conversational AI platform* for a government bank portal serving 1M+ monthly users; designed a multi-turn intent classification pipeline using Dialogflow CX with custom NLP fallback handlers, achieving 97% query resolution accuracy and reducing average resolution time by 60% while scaling to 50K concurrent sessions without latency degradation.
- Led the design architecture and built the end-to-end UX for an enterprise Conversational AI platform deployed across a major tier-1 banking portal, driving a 90% increase in monthly customer interactions and User Satisfaction (CSAT) scores.

== Project
#project(
  name: "Writer",
  dates: dates-helper(start-date: "Jun 2025", end-date: "Present"),
  url: "https://github.com/git-emran/simple-notes"
)
- An open-source Markdown Editor with LSP, built in Terminal, AI assisted writing, Kanban board and a Freeform canvas to enhance agentic or general development workflow.
- Optimized local markdown parsing and tokenization rendering to achieve sub-16ms frame times during heavy AI streaming sessions, dynamic tags to organize and maintain notes.

#project(
  name: "Slides",
  dates: dates-helper(start-date: "Sept 2026", end-date: "Present"),
  url: "https://github.com/git-emran/slides.nvim"
)
- Designed a slideshow experience that lives inside a developer's existing editor rather than a separate app parsing Markdown headings into a center-aligned presentation layout with seamless, distraction-free rendering.

== Skills
- *Product Design*: Figma, Origami, Prototyping, Design Systems, Information Architecture, User Research, Usability Testing, Product Strategy.
- *Core Stack*: TypeScript, JavaScript (ES2022+), Node.js, HTML5/CSS3, Golang, Python.
- *Technologies*: React, Astro, Angular, SolidJS, Svelte, Fast-API, WebSockets, LangChain, Open-CV, MongoDB, gRPC, Docker, Async AI streaming, Git, Linux, UNIX, CI/CD pipelines, AI/ML product integration.
