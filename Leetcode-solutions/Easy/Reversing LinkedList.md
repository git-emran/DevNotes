
Problem:
Given the `head` of a singly linked list, reverse the list, and return _the reversed list_.


###### Solution Recursive:
```python

class Solution:

def reverseList(self, head: Optional[ListNode]) -> Optional[ListNode]:
	if not head:
		return None
	
	newHead = head
	if head.next:
		newHead = self.reverseList(head.next)
		head.next.next = head
		head.next = None
	return newHead
```