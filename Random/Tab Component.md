
1. Check if the tab is active. 
2. Dynamically load the tab using `ActiveTabComponent = tabs[activeTab].component`
3. Map over the items and index, then set the index on SetIsActive
   ```jsx
	   
     {tabs.map((item, index) => {
          return (
            <div key={item.id} onClick={() => SetIsActive(index)} className='tab-item'>{item.name}</div>
          )
        })}	
   ```

 