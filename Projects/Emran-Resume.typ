#import "@preview/basic-resume:0.2.8": *

// Put your personal information here, replacing mine
#let name = "Emran Hossain"
#let email = "clearlybestemran@gmail.com"
#let linkedin = "www.linkedin.com/in/emran-hossain-80ab17190/"
#let personal-site = "www.designwithemran.com"


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

/*
 * Lines that start with == are formatted into section headings
 * You can use the specific formatting functions if needed
 * The following formatting functions are listed below
 * #edu(dates: "", degree: "", gpa: "", institution: "", location: "", consistent: false)
 * #work(company: "", dates: "", location: "", title: "")
 * #project(dates: "", name: "", role: "", url: "")
 * certificates(name: "", issuer: "", url: "", date: "")
 * #extracurriculars(activity: "", dates: "")
 * There are also the following generic functions that don't apply any formatting
 * #generic-two-by-two(top-left: "", top-right: "", bottom-left: "", bottom-right: "")
 * #generic-one-by-two(left: "", right: "")
 */
== Education

#edu(
  institution: "University of Information Technologies and Sciences",
  dates: dates-helper(start-date: "Aug 2013", end-date: "May 2017"),
  degree: "Bachelor's of Science, Computer Science",

  // Uncomment the line below if you want edu formatting to be consistent with everything else
  // consistent: true
)
CGPA 3.6/4, Computer Science
== Work Experience

#work(
  title: "Product Lead and Software Engineer",
  location: "Copenhagen, Denmark",
  company: "Tiblo Digital",
  dates: dates-helper(start-date: "Jan 2024", end-date: "Present"),
)
- As a Team lead I streamlined the client on-boarding by Introducing new Framework for Requirement Analysis resulting in faster design delivery.
- Designed and Launched a B2B web application, a New innovative product in collboration with TyreProf resulting in a 90% new customers converted in the first quarter. Implemented a feature that supports real time collaboration and presence detection in React using conflict free replicated data (CRDT).
- Introduced a new collaboration style, design standards and documentation strategies with Storybook and Figma to simplify front end development.

#work(
  title: "Front-end Engineer, UX Lead",
  location: "Dubai, UAE",
  company: "The Total Office (Contract)",
  dates: dates-helper(start-date: "Apr 2023", end-date: "May 2024"),
)

- Played a key role in addressing security vulnerabilities (CVEs), reducing their count from 411 to 3 through diligent analysis and mitigation measures.
- Introduced ARIA attributes and customizable keyboard navigation, resulting in 98% user satisfaction from individuals with diverse abilities.
- Optimized Core Web Vitals (LCP, CLS, FID) for a high-traﬃc e-commerce platform by implementing image lazy loading, code splitting, and service workers, improving conversion rates by 20% and page load speed from 3.4s to 1.2s.

#work(
  title: "Lead UX/UI Designer",
  location: "Austin, Texas, USA",
  company: "MarketTime LLC (Contract)",
  dates: dates-helper(start-date: "May 2022", end-date: "Apr 2023"),
)

- Achieved WCAG compliance for an enterprise grade system in 2 months. Collaboratively designed a new payment processing feature named “mtPay” with a 95% user adoption rate and Ensured seamless migration from Angular 3 to Angular 10.
- Implemented enterprise Design System, saving 60% time on system upgrades, 50% increase in design delivery and simplifying developer project transitions.
- Boosted customer conversion rate from 20% to 88% and reduced drop off rate by 32% and Significantly reduced load time by 34% by redesigning and refactoring the website layout and artifacts.

#work(
  title: "Lead Product Designer, Front-end Developer",
  location: "Dhaka, Bangladesh",
  company: "Roxnor",
  dates: dates-helper(start-date: "Jan 2021", end-date: "May 2022"),
)

- Worked on Node JS and Apollo GraphQL to develop a GraphQL backend server, Implemented a robust que system using Bull MQ for processing heavy background jobs, Reduced Reporting API endpoint response from minutes to seconds by rewriting API using Nest JS.
- Implemented a Large scale design system, ensured WCAG standards, Standardized the design to dev workflow resulting in faster design delivery and almost 100% increase in User Adoption rate.
- As a Team lead I designed, developed and launched an AI Content Generator and Manager GetGenieAI from 0 to 1 which resulted in 98% user sign ups, 100% activation rate, 20k MAU and increased session depth.


== Skills
- *Programming Languages*: JavaScript, Typescript, Python, C/C++, HTML/CSS, Java, Bash, Rust, Lua, SQL.
- *Technologies*: React, Astro, Angular, SolidJS, Svelte, Artificial-Intelligence, Tailwind CSS, LangChain, Git, Linux, UNIX, Docker, Caddy, NGINX, Google Cloud Platform.
- *Design Skills*: User Experience Design, Product Design, Accessibility Design, Human Centered Design, Interaction Design, UI Design, 2D Animation, Graphics Design.
