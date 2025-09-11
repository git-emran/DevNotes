
#### Creating variables:

```
dummy = ListNode() 
cur = dummy
```

##### Merging the List:

- We iterate through both lists until either `list1` or `list2` becomes None.
- At each iteration, we compare the values of the current nodes of `list1` and `list2`.
- If the value of the current node in `list1` is greater than that of `list2`, we append the current node of `list2` to the merged list and move `list2` pointer to the next node.
- Otherwise, we append the current node of `list1` to the merged list and move `list1` pointer to the next node.
- 
``` python

	while list1 and list2:
	
		if list1.val > list2.val:

			temp.next = list2
			
			list2 = list2.next

		else:

			temp.next = list1

			list1 = list1.next

		temp = temp.next
```
##### Appending the remaining node: 
+ After the loop, if there are remaining nodes in either `list1` or `list2`, we append them to the end of the merged list.

```python

	if list1:

		temp.next = list1

	else:

		temp.next = list2

  

	return dummy.next


```

#### Solution in Python:

```python

# Definition for singly-linked list.

# class ListNode:

# def __init__(self, val=0, next=None):

# self.val = val

# self.next = next

class Solution:

def mergeTwoLists(self, list1: Optional[ListNode], list2: Optional[ListNode]) -> Optional[ListNode]:

	dummy = ListNode()
	
	temp = dummy

  

	while list1 and list2:
	
		if list1.val > list2.val:

			temp.next = list2
			
			list2 = list2.next

		else:

			temp.next = list1

			list1 = list1.next

		temp = temp.next

  

	if list1:

		temp.next = list1

	else:

		temp.next = list2

  

	return dummy.next
```





  

