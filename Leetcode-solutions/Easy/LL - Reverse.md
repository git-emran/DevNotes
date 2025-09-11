
Lets reverse a singly linked list:

```javascript

var reverseList = function(head) {
	// Always go over the edge cases first
	if (head == null || head.next == null) return head
	
	// Call the function recursively set a new node that stores the next node from the head
	
	var rev_list = reverseList(head.next)
	
	// Point the Next pointer after head.next to head
	
	head.next.next = head	
	
	// set the next pointer from head to null 
	
	head.next = null
	
	// return that node we previously set
	
	return rev_list

}


```