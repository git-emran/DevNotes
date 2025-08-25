# Learning Golang

Comprehensive guide to learn Golang.

Every go project starts with `go mod init project_name`. This command creates a file named go.mod, which is used to keep track of the packages a project
depends on and can also be used to publish the project if required.

## Party Invite

We will learn go as we work on a sample project named Party Invite.

Printing anything:

```go

package main
import "fmt"
func main() {
fmt.Println("TODO: add some features")
}

```

The syntax of Go will be familiar if you have used any C or C-like language, such as C# or Java

`go run .`

The go run command is useful during development because it performs the compilation and execution tasks in one step. The application produces the following output:
TO-DO: add some features

### Defining a Data type and a Collection

Defining a Data Type in the main.go File.

```go
package main
import "fmt"
type Rsvp struct {
Name, Email, Phone string
WillAttend bool
}
func main() {
fmt.Println("TODO: add some features");
}

```

Go allows custom types to be defined and given a name using the type keyword. Structs allow a set of related values to be grouped together.

### Defining a slice

Now we are Defining a Slice:

```go

package main
import "fmt"
type Rsvp struct {
Name, Email, Phone string
WillAttend bool
}
var responses = make([]*Rsvp, 0, 10)
func main() {
fmt.Println("TODO: add some features");
}

```

The square brackets []denote a slice. The asterisk, \*, denotes a pointer. The Rsvp part of the type denotes the struct type defined.

### Creating HTML templates

Go comes with a comprehensive standard library, which includes support for HTML templates. Add a file named layout.html

```html
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width" />
    <title>Let's Party!</title>
    <link
      href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.1.1/css/bootstrap.min.css"
      rel="stylesheet"
    />
  </head>
  <body class="p-2">
    {{ block "body" . }} Content Goes Here {{ end }}
  </body>
</html>
```

To create the content that will greet the user, add a file named welcome.html to the partyinvites folder. The Contents of the welcome.html File in the partyinvites Folder:

```html
{{ define "body"}}
<div class="text-center">
  <h3>We're going to have an exciting party!</h3>
  <h4>And YOU are invited!</h4>
  <a class="btn btn-primary" href="/form"> RSVP Now </a>
</div>
{{ end }}
```

To create the template that will allow the user to give their response to the RSVP, add a file named form.html to the partyinvites folder.

```html
{{ define "body"}}
<div class="h5 bg-primary text-white text-center m-2 p-2">RSVP</div>
{{ if gt (len .Errors) 0}}
<ul class="text-danger mt-3">
  {{ range .Errors }}
  <li>{{ . }}</li>
  {{ end }}
</ul>
{{ end }}
<form method="POST" class="m-2">
  <div class="form-group my-1">
    <label>Your name:</label>
    <input name="name" class="form-control" value="{{.Name}}" />
  </div>
  <div class="form-group my-1">
    <label>Your email:</label>
    <input name="email" class="form-control" value="{{.Email}}" />
  </div>
  <div class="form-group my-1">
    <label>Your phone number:</label>
    <input name="phone" class="form-control" value="{{.Phone}}" />
  </div>
  <div class="form-group my-1">
    <label>Will you attend?</label>
    <select name="willattend" class="form-select">
      <option value="true" {{if .WillAttend}}selected{{end}}></option>
      <option value="false" {{if not .WillAttend}}selected{{end}}>
        No, I can't come
      </option>
    </select>
  </div>
  <button class="btn btn-primary mt-3" type="submit">Submit RSVP</button>
</form>
{{ end }}
```
