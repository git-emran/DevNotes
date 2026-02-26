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
  dates: dates-helper(start-date: "May 2024", end-date: "Present"),
)
- As a Team lead I streamlined the client on-boarding by Introducing new Framework for Requirement Analysis resulting in faster design delivery.
- Designed and Launched a B2B web application, a New innovative product in collboration with TyreProf resulting in a 90% new customers converted in the first quarter. Implemented a feature that supports real time collaboration and presence detection in React using conflict free replicated data (CRDT).
- Introduced a new collaboration style, design standards and documentation strategies with Storybook and Figma to simplify front end development.

#work(
  title: "Front-end Engineer, Product Lead",
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

- Documented and implemented core design requirements under the Lead UX Designer and Head of Design to ensure brand consistency across all digital touchpoints.
- Performed daily design tasks and iterative improvements, moving concepts through the approval pipeline to final implementation.
- Established a standardized UI component library that reduced front-end development time by 30% and ensured a unified visual language across multiple product versions.

#work(
  title: "Product Designer",
  location: "Silicon Valley, USA, Hybrid",
  company: "Insidemaps Inc.",
  dates: dates-helper(start-date: "Mar 2019", end-date: "Jan 2022"),
)

- Directed the end-to-end design and front-end development of an iOS-exclusive mobile app, corporate website, and comprehensive web app, resulting in a 25% increase in cross-platform user engagement.
- Collaborated with the Senior Product Manager and Marketing teams to define the product vision, contributing to a 15% growth in monthly active users (MAU) through data-driven feature prioritization.

== Skills
- *Programming Languages*: JavaScript, Typescript, Python, C/C++, HTML/CSS, Java, Bash, Rust, Lua, SQL.
- *Technologies*: React, Astro, Angular, SolidJS, Svelte, Artificial-Intelligence, Tailwind CSS, LangChain, Git, Linux, UNIX, Docker, Caddy, NGINX, Google Cloud Platform.
- *Design Skills*: User Experience Design, Product Design, Accessibility Design, Human Centered Design, Interaction Design, UI Design, 2D Animation, Graphics Design.
