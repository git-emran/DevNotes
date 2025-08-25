
Reversing a doubly linked list :
Assigning a pointer to the head. While the head is not empty , swap next and prev and move to the next node. Only after that swap the head tail.

``` 
def reverse(self):
        current = self.head
        while current is not None:
            # Swap next and prev
            current.prev, current.next = current.next, current.prev
            # Move to next node (which is actually previous before swap)
            current = current.prev

        # Swap head and tail
        self.head, self.tail = self.tail, self.head
```
