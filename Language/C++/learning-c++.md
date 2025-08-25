# C++

A comprehensive guide from Emran, to learn C++ Software Design & Architecture.

> Dependency is the key problem in software development.

### Three Levels of software development

_Software Architecture_ and _Software Design_ are just two of the three levels
of software development. They are complemented by the level of Implementation Details.

#### Example of Aritificial Coupling

Let's start with bad example of code

```C++
class Document
{
public:
// ...
virtual ~Document() = default;
virtual void exportToJSON( /*...*/ ) const = 0;
virtual void serialize( ByteStream&, /*...*/ ) const = 0;
// ...
};

```

Both `exportToJSON()` and `serialize()` function poses artificial dependencies which will make the code harder to maintain in the future.

More appropriate way of writing it would be:

```C++
class Document
{
public:
// ...
virtual ~Document() = default;
// No more 'exportToJSON()' and 'serialize()' functions.
// Only the very basic document operations, that do not
// cause strong coupling, remain.
// ...
};

```

The JSON and serialization aspects are just not part of the fundamental pieces of functionality of a Document class. The Document class should merely represent the very basic operations of different kinds of documents. All orthogonal aspects should be separated.
