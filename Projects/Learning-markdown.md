 
	 `#software #markdown #desktop-app

This is another attempt to create an web application to add it to my personal projects. This is one the biggest project. Gaining deep knowledge on each section will be the building blocks of the javascript.

> Goal is to create a completely polished project. And gain a better understanding of 
> how things work under the hood of electron, Jota. I will be sharing my notes as I go. 



##### ? 
Its a frame work for creating desktop application. It uses Javascript, HTML, CSS By embedding [Chromium](https://www.chromium.org/) and [Node.js](https://nodejs.org/) into its binary,

How it works under the hood: 
![[Screenshot 2025-07-21 at 8.42.54 PM.png]]


---


What I did:  
  - [x] Project Configuration 
         - Updating `ts.config.json` include properties to include `"src/shared/**/*"`
        the new shared folder into the project. For example, shared folder, hooks, store under the "Renderer" folder
         - Enable error reporting when a local variable isn't read.  `noUnusedLocals: False`
         - Including newly created folders. Everything under shared folder and rendered folder `"@shared/*": ["src/shared/*"], "@/*": ["src/renderer/src/*"], `
         - Inside `electron.vite.config.js` - configuring new folder structures that I created for example: `'@/hooks': resolve('src/renderer/src/hooks')` and so on to make sure the program finds the directories. This is an electron specific setup. 
         - Similarly including assets like `assetsInclude: 'src/renderer/assets/**',` inside the renderer. 
           
  - [x] Styling Setup 
        - Installing Tailwind CSS. Using Tailwind 3 to avoid prefixer and postcss issues. 
        - Since all the styling will be under the "Renderer" folder. Must include `content: ['./src/renderer/**/*,{js,ts,tsx,jsx}']` inside `tailwind.config.js`
          
  - [x] Creating the UI
        - UI component in react using ComponentProps type in React. Using `twMerge` to create dynamic style import. For example: 
	    `RootLayout = ({children, className, ...props}: ComponentProps<'main'>)=>{} `
	    `return className = {twMerge('tailwindCss', className)} {...props}`
	    - Then return children object in the return div. This way you can create multiple dynamic layouts using twMerge(tailwind merge). 
	    - Creating Dynamic UI components : 
	      Let's say I have a Button folder that has reusable buttons for different actions. In this case for example: Creating Notes button, Delete Notes button etc. So to create something reusable with dynamic button data : 
	      to create a Button Folder/ create `index.ts`  file and export * (everything) from the component './DeleteActionButton' this way 
	    - Instead of styling the parent component and props, its better to style the child components as we are passing the `className` as a prop with `twMerge` to avoid conflicting styling classes. 
	    - Utility type from react `NoteInfo & {isActive?: boolean} & ComponentProps<'div> `
	    - Here NoteInfo is model schema
	    - tailwind classes {`'bg-zinc-400/75': isActive, 'hover:bg-zinc-500/50': !isActive` }
	    - This makes the component behave like a normal `div`, fully compatible with all standard HTML props.
	    

  - [x] Adding the editor
        - Everything works fine according to `MDXeditor`, But it is essential to require `tailwindcss typography` inside the `tailwind.config.ts` other wise markdown plugins like `headingsPlugin()`

  - [x] Adding JOTAI
        - Jotai Docs makes it easy to implement the state management system. 
        - In the Store folder : I can create empty arrays within the `atoms` 
        - `const citiesAtom = atom(['Tokyo', 'Kyoto', 'Osaka'])` or pass the created model 
        - `export const notesAtom = atom<NoteInfo[]>(notesMock)`
        - Derive atoms: A derived atom can read from other atoms before returning its own value.
        - 
        - Then use atoms within React components to read or write state.
        - `const createEmptyNote = useSetAtom(createEmptyNoteAtom)`

  - [x] File system integration
        
        
        
  - [x] Reading the note from the Filesystem
        - Writing Notes with new write note context type.
        - Reading notes with new Read note context. (All the context goes inside the `preload`)
          

  - [x] Reading the content of the note
  - [x] Saving the note content
        ===- Defining the new function in `./shared/types` folder.=== #Error
        - solved the saving issue by downgrading electron. Problem was in electron builder and new electron context api restructure.
  - [x] Implementing auto saving
  - [x] Creating new notes
  - [x] Deleting the notes
  - [x] App bundling 
  - [x] Showcase on the website

###  Update 1.0.0: 
 - File system for the note 


Bug - 

- Link: When I click on the link it loads On the app browser itself