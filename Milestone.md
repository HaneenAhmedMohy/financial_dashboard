
##### Milestone 1

# Accomplishment

I started the project by using Aider to help create the initial setup. I made a monorepo structure to keep both the Phoenix backend and the Svelte frontend in one place. Then, I set up the Phoenix app to handle real-time updates and built the Svelte app to show the data in the browser. Finally, I connected the frontend and backend so they could talk to each other and share data.

# Challenges

When I first tried to run the project, I faced several errors in the backend that made it difficult to get the app up and running.  However, with the help of Opto-GPT, I was able to quickly troubleshoot the errors and understand the solutions. Once the backend was working, I successfully added the stocks view, displaying the data for the required companies, and everything started to run smoothly.

# Aider and opto-gpt utilization

Throughout this milestone, I used Aider as my primary coding assistant to scaffold the monorepo, generate boilerplate code, and progressively build out features in both the backend and frontend. It helped maintain consistent structure across the application. When I encountered more complex bugs or architectural decisions , I turned to Opto-GPT for deeper guidance and debugging help. Together, Aider and Opto-GPT enabled me to move quickly through this milestone by combining code generation with problem-solving and architectural support.

# Lessons

During Milestone 1, I learned the importance of having a clear project structure and how helpful tools like Aider can be in setting up a monorepo efficiently. I also gained practical experience integrating Elixir with Svelte, especially in establishing communication between the backend and frontend. Additionally, troubleshooting early backend issues taught me how to investigate and resolve dependency and compilation errors in Elixir projects. I learned how to balance code automation with manual debugging to get the project running smoothly.

### ------------------------------------------------------------------------------------------------ ###


##### Milestone 2

# Accomplishment


# Challenges
For the second milestone, the challenges involved setting up the real data flow and ensuring everything worked seamlessly with live data. One of the key challenges was ensuring that the Finnhub API integration was correctly authenticated and that the WebSocket connection was stable and maintained throughout the application. Testing the entire flow to ensure that data was accurately retrieved, processed, and displayed in real-time without any interruptions was also a significant hurdle. Moreover, adding all the required keys and ensuring that they were correctly integrated into the system for smooth operation involved dealing with potential configuration issues and environment variables. Despite these challenges, with the help of Aider and OptoGPT, I was able to troubleshoot the problems, integrate the necessary components, and successfully implement the required features for this milestone.

# Aider and opto-gpt utilization

To complete this milestone, I used both Aider and opto-gpt in a complementary way. I relied on opto-gpt to help me understand the steps required to implement this part of the project, such as setting up the WebSocket connection or handling ETS storage. Once I had a clear plan, I used Aider to apply those steps directly in the codebase by giving it clear and focused commands. This approach allowed me to break down the work into manageable pieces and execute them efficiently using Aider's code editing capabilities.

# Lessons
