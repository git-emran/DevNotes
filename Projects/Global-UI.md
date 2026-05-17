Create an Interface where One single prompt box, that can book uber-rides, check and summarize your email, list your latest emails, send emails, open linkedin,  etc. It should act as a browser and a central controlling unit. A UI that adapts to the app that is currently running. All different running apps should appear as tabs. Security should be a top priority for this app architecture. This tool should be agents first, so that adding agents should as easy as adding a json files with few names and api key in the config file like kitty terminal. 
This app should be a place for people and agent to come and interact with internet without needing to leave the app. It can become a browser, a book reader, it should be able to browse files, be book reader, 

Create a Markdown files with all the items that are needed to be done incrementally to make this work. Do them and strikethrough them so that you know what is done and what are the things left. Make sure all the tasks are modular and efficient. SO that each iteration can be seen and tested via the UI. Make sure the add unit test for everything. 

- Tech stack should be 
  - **Tauri (Rust + Web UI)**
	- React + TypeScript frontend
	- Rust backend for security + agent execution

Every feature should live in its own folder. Code should be maintainable and readable, function names should be relevant and self explanatory. Code like a Principal Software Engineer with all the experience. 

CORE FEATURE: COMMAND ENGINE
### Pipeline:

1. Parse intent
2. Match agent
3. Validate permissions
4. Execute tool
5. Return structured response
6. Render UI dynamically

