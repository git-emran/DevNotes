Design an algorithm to encode **a list of strings** to **a string**. The encoded string is then sent over the network and is decoded back to the original list of strings.


Machine 1 (sender) has the function:

```text
string encode(vector<string> strs) {
    // ... your code
    return encoded_string;
}
```


Machine 2 (sender) has the function:

```text

vector<string> decode(string s) {
    //... your code
    return strs;
}
```


So Machine 1 does:

```text
string encoded_string = encode(strs);
```

and Machine 2 does:

```text
vector<string> strs2 = decode(encoded_string);
```

`strs2` in Machine 2 should be the same as `strs` in Machine 1.

Implement the `encode` and `decode` methods.


Example:1

```java
Input: dummy_input = ["Hello","World"]

Output: ["Hello","World"]

Explanation:
Machine 1:
Codec encoder = new Codec();
String msg = encoder.encode(strs);
Machine 1 ---msg---> Machine 2

Machine 2:
Codec decoder = new Codec();
String[] strs = decoder.decode(msg);
```


**Example 2:**

```java
Input: dummy_input = [""]

Output: [""]
```


## Prerequisites

Before attempting this problem, you should be comfortable with:

- **String Manipulation** - Building strings by concatenation and extracting substrings based on indices
- **Delimiter Design** - Understanding how to choose separators that won't conflict with input content
- **Length-Prefix Encoding** - Using string lengths to unambiguously mark boundaries between encoded segmentso


## 1. Encoding & Decoding

### Intuition

To encode a list of strings into a single string, we need a way to store each string so that we can later separate them correctly during decoding.  
A simple and reliable strategy is to record the **length of each string** first, followed by a special separator, and then append all the strings together.  
During decoding, we can read the recorded lengths to know exactly how many characters to extract for each original string.  
This avoids any issues with special characters, commas, or symbols inside the strings because the lengths tell us precisely where each string starts and ends.

### Algorithm

#### Encoding

1. If the input list is empty, return an empty string.
2. Create an empty list to store the sizes of each string.
3. For each string, append its length to the sizes list.
4. Build a single string by:
    - Writing all sizes separated by commas.
    - Adding a `'#'` to mark the end of the size section.
    - Appending all the actual strings in order.
5. Return the final encoded string.

#### Decoding

1. If the encoded string is empty, return an empty list.
2. Read characters from the start until reaching `'#'` to extract all recorded sizes:
    - Parse each size by reading until a comma.
3. After the `'#'`, extract substrings according to the sizes list:
    - For each size, read that many characters and append the substring to the result.
4. Return the list of decoded strings.