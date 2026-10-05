# Architecture & Component Guide (`where.md`)

This document details the exact structure of the website, what each component does, how data flows through the application, and step-by-step instructions for adding new sections, projects, case studies, videos, or interactions.

---

## 📁 Directory Structure & File Map

```
gasp-new/
├── app/
│   ├── layout.js                         # Root layout (Fonts, Meta, GA4, Background Shader Provider, ScrollToTop FAB)
│   ├── globals.css                       # Global styles, Tailwind base, and dark mode overrides
│   ├── page.js                           # Work / Home page (Showcase stream of featured projects)
│   ├── about/
│   │   └── page.jsx                      # About page (Bio, Profile photo, Videos showcase, Testimonials, Off-duty interests)
│   ├── notes/
│   │   └── page.jsx                      # Notes / Writings list (Articles & reflections)
│   ├── interaction-archive/
│   │   └── page.jsx                      # Interactions gallery with Category Tabs & Lightbox modal
│   ├── case-study/
│   │   ├── README.md                     # Case study quick reference
│   │   └── [slug]/
│   │       ├── page.jsx                  # Dynamic static params & metadata generator
│   │       └── CaseStudyClient.jsx       # Case study page (Hero, Challenge, Research, Solutions, Impact, Lightbox, Nav)
│   ├── constants/
│   │   └── index.js                      # Central data store (Projects, Case Studies, Testimonials, Interactions)
│   └── components/
│       ├── HoverBackgroundProvider.jsx   # Context provider & canvas layer for interactive fluid shader background
│       ├── FluidBackgroundShader.jsx     # WebGL fragment shader rendering smooth liquid organic colors
│       ├── HoverLink.jsx                 # Interactive link wrapper that triggers fluid shader color transitions on hover
│       ├── ScrollToTopFab.jsx            # Floating action button (FAB) that smoothly scrolls to top on all pages
│       ├── AboutVideos.jsx               # Interactive video showcase with tabbed playback on About page
│       ├── Testimonials.jsx              # Animated card deck for client & colleague recommendations
│       └── ui/
│           └── animated-testimonials.jsx # Framer Motion spring-physics 3D rotating testimonial card deck
└── lib/
    └── utils.js                          # Class merging utility (clsx + tailwind-merge)
```

---

## 🧩 Component Directory & Responsibilities

### 1. `HoverBackgroundProvider.jsx` & `FluidBackgroundShader.jsx`
- **Location**: `app/components/HoverBackgroundProvider.jsx`, `app/components/FluidBackgroundShader.jsx`
- **Purpose**: Provides a full-screen interactive fluid WebGL shader that reacts to hovering over links across the site.
- **How it works**:
  - `HoverBackgroundProvider` wraps the entire app in `app/layout.js`.
  - Exposes `setPreset(presetName)` and `resetPreset()` via React Context.
  - When idle, smoothly transitions back to the default warm terracotta palette (`#38241f` / `#94432c`).
  - Supports custom palette presets configured in `PRESETS`.

### 2. `HoverLink.jsx`
- **Location**: `app/components/HoverLink.jsx`
- **Purpose**: Drop-in replacement for standard Next.js `<Link>` or `<a>` tags.
- **Presets Available**:
  - `work`, `about`, `notes`, `interactions_nav`
  - `ai` (GetGenie - emerald / violet)
  - `writer` (indigo / violet)
  - `biotech` (FujiFilm - cyan / teal)
  - `spatial` (InsideMaps - orange / rose)
  - `tennis` (MatchTrack - lime / emerald)
  - `office` (The Office Outlet - amber / orange)
  - `redesign` (blue / indigo)
  - `linkedin`, `github`, `instagram`, `blog`

### 3. `ScrollToTopFab.jsx`
- **Location**: `app/components/ScrollToTopFab.jsx`
- **Purpose**: A floating action button positioned at the bottom right (`bottom-6 right-6`).
- **Behavior**: Appears smoothly with scale animation once the user scrolls past 300px. Supports both light and dark modes with backdrop blur.

### 4. `AboutVideos.jsx`
- **Location**: `app/components/AboutVideos.jsx`
- **Purpose**: Renders the video showcase section on `/about`. Includes video tabs, custom video player, badges, and view on YouTube links.

### 5. `Testimonials.jsx` & `animated-testimonials.jsx`
- **Location**: `app/components/Testimonials.jsx`, `app/components/ui/animated-testimonials.jsx`
- **Purpose**: Displays high-profile testimonials (Todd Litzman, Anders Tidemand, Richard Wohnsiedler, Anders Blomqvist) with interactive swipe/arrow controls and smooth rotation animations.

---

## 🛠 How-To Guides

### How to Add a New Project to the Homepage & Case Study
1. Open `app/constants/index.js`.
2. Add a new object to the `projects` array:
```javascript
{
  id: 9,
  name: "My New Project - Subtitle",
  slug: "my-new-project",
  description: "Brief overview of what was built and impact.",
  href: "/case-study/my-new-project",
  image: "/assets/projects/my-new-project.webp",
  bgImage: "/assets/backgrounds/blanket.jpg",
  frameworks: [
    { id: 1, name: "Next.js" },
    { id: 2, name: "TypeScript" },
  ],
  visitUrl: "https://my-live-url.com",
  caseStudy: {
    role: "Lead Designer & Developer",
    team: "Design Lead, Engineering Lead",
    techStack: "Next.js, Tailwind, Node.js",
    overview: "In-depth summary of the project goals...",
    problemTitle: "The Core Problem",
    problemContent: "Detailed breakdown of friction points...",
    problemImages: ["/assets/projects/problem1.webp"],
    researchTitle: "Discovery & User Testing",
    researchPhases: [
      {
        title: "Phase 1: User Workflow Audit",
        content: "Findings from user observation sessions...",
        image: "/assets/projects/research1.webp"
      }
    ],
    solutionTitle: "The Engineering Solution",
    solutionContent: "How the challenges were solved...",
    solutionImages: ["/assets/projects/solution1.webp"],
    features: [
      "Feature 1: Key benefit description",
      "Feature 2: Key benefit description",
    ],
    resultsTitle: "Quantifiable Impact",
    resultsMetric: "3.5x",
    resultsContent: "Metrics achieved after production deployment...",
    resultsImages: ["/assets/projects/results1.webp"]
  }
}
```
3. In `app/page.js`, add an `<article>` card with `<HoverLink>` pointing to `/case-study/my-new-project`.
4. The dynamic case study route (`/case-study/[slug]`) automatically generates the page and metadata.

---

### How to Add a New Interaction to the Interaction Archive
1. Open `app/constants/index.js`.
2. Locate `interactionDesignsByCategory`.
3. Add your item under the relevant category (or create a new category key):
```javascript
const interactionDesignsByCategory = {
  "Restaurant": [ ... ],
  "New Category": [
    { title: "My Micro-Interaction", image: "/assets/projects/my-anim.gif" }
  ]
};
```
4. The `/interaction-archive` page will automatically create filter tabs, calculate counts, and display the new interaction in the responsive grid.

---

### How to Add Videos to the About Page
1. Open `app/components/AboutVideos.jsx`.
2. Add an entry to the `videos` array:
```javascript
{
  id: "video-id",
  title: "Title of your video",
  badge: "Case Study / Reel / Tutorial",
  description: "Brief summary of what is demonstrated in the video.",
  youtubeUrl: "https://youtube.com/watch?v=...",
  embedUrl: "https://www.youtube.com/embed/...",
}
```

---

### How to Add or Edit Testimonials
1. Open `app/constants/index.js`.
2. Modify or append to `testimonials`:
```javascript
{
  quote: "Emran delivered stellar work...",
  name: "Client Name",
  designation: "VP of Engineering, Company",
  src: "/images/client.jpeg",
}
```sdfds