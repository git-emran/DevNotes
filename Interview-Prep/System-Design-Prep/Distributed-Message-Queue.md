**We explore a popular question in system design interviews:** design a distributed message queue. In modern architecture, systems are broken up into small and independent building blocks with well-defined interfaces between them. Message queues provide communication and coordination for those building blocks. What benefits do message queues bring?

 - Decoupling. Message queues eliminate the tight coupling between components so they can be updated independently.
 
- Improved scalability. We can scale producers and consumers independently based on traffic load. For example, during peak hours, more consumers can be added to handle the increased traffic.

- Increased availability. If one part of the system goes offline, the other components can continue to interact with the queue.

- Better performance. Message queues make asynchronous communication easy. Producers can add messages to a queue without waiting for the response and consumers consume messages whenever they are available. They don’t need to wait for each other.
