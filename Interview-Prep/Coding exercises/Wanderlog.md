# 🔹 Exercise Set 1: Practical Web & Data Manipulation

### **1. JSON Transformation**

You’re given an API response like this:

`[   { "id": 1, "first_name": "Alice", "last_name": "Smith", "country": "US" },   { "id": 2, "first_name": "Bob", "last_name": "Lee", "country": "CA" },   { "id": 3, "first_name": "Charlie", "last_name": "Ng", "country": "US" } ]`

Write code that:

- Combines `first_name` + `last_name` into `full_name`
    
- Groups users by `country`
    
- Returns this structure:
    

`{   "US": ["Alice Smith", "Charlie Ng"],   "CA": ["Bob Lee"] }`

⏱ Expected: ~20 mins.  
📌 Tests: JSON parsing, transformations, data structures.

---

### **2. File I/O Utility**

Write a script that:

- Reads a `.csv` file with columns: `name,email,signup_date`
    
- Filters users who signed up in the **last 30 days**
    
- Saves them into a new `.csv` called `recent_users.csv`
    

⏱ Expected: ~30 mins.  
📌 Tests: File I/O, working with libraries (e.g., `pandas` in Python, `csv` in Node/Go), handling dates.

---

# 🔹 Exercise Set 2: Web / API Focus

### **3. Simple REST API**

Build a tiny REST API with two endpoints:

- `GET /notes` → returns all notes (from in-memory array)
    
- `POST /notes` → creates a new note (`{title, body}`)
    

Requirements:

- Use any web framework (Express.js / Flask / FastAPI / Go net/http).
    
- Notes don’t need a DB — just keep them in memory.
    

⏱ Expected: ~25–30 mins.  
📌 Tests: Web framework knowledge, clean API design, speed.

---

### **4. URL Shortener Lite**

Build a function:

`shorten("https://wanderlog.com/about")  # → "http://sho.rt/abc123"`

- Store mappings in memory.
    
- If the same URL is shortened again, return the same short link.
    
- Implement a `resolve(short_url)` function that returns the original.
    

⏱ Expected: ~30–40 mins.  
📌 Tests: Hashing/encoding, dictionaries/maps, practical utility function.

---

# 🔹 Exercise Set 3: Real Product-Like

### **5. Markdown to HTML Converter**

Write a script that converts text with Markdown-style headers to HTML:

`# Title ## Subtitle Normal text`

Output:

`<h1>Title</h1> <h2>Subtitle</h2> <p>Normal text</p>`

⏱ Expected: ~25 mins.  
📌 Tests: String parsing, regex, mapping formats.

---

### **6. Travel Itinerary Formatter (Wanderlog-flavored)**

Given input:

`[   { "city": "Paris", "days": 3 },   { "city": "Rome", "days": 2 },   { "city": "Barcelona", "days": 4 } ]`

Write a function that outputs:

`Itinerary: - Paris (3 days) - Rome (2 days) - Barcelona (4 days) Total: 9 days`

⏱ Expected: ~15–20 mins.  
📌 Tests: Loops, formatting, summation, real-world style.

---

# 🔹 Exercise Set 4: Frontend / UI

### **7. Search Bar Autocomplete**

Build a function/component that:

- Takes a list of destinations: `["Paris", "Rome", "Barcelona", "Berlin"]`
    
- As the user types `"B"`, it shows `["Barcelona", "Berlin"]`
    
- Case-insensitive.
    

⏱ Expected: ~20–30 mins.  
📌 Tests: Filtering, string handling, UI basics (React/Vue/Vanilla).

---

### **8. Responsive Card Grid**

Make a responsive UI:

- Cards with `title`, `image`, `description`.
    
- On mobile → 1 column, tablet → 2 columns, desktop → 3+ columns.
    

⏱ Expected: ~30–40 mins.  
📌 Tests: Frontend layout, CSS/Tailwind, quick component design.

---

✅ These are the **most popular types of real-world coding exercises** (used in **Wanderlog-style take-homes, SaaS companies, and product startups**):

- JSON/data transformations
    
- File parsing
    
- Small REST APIs
    
- Utilities like shorteners
    
- Markdown/formatting tasks
    
- UI tasks (search, grid layout)