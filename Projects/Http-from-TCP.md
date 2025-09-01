## Building HTTP from scratch

Using typescript

#### Easy way

```typescript
import net from "net";

const server = net.createServer((socket) => {
  socket.on("data", (data) => {
    const request = data.toString();
    console.log("Raw Request:\n", request);

    // Parse HTTP request line
    const [requestLine] = request.split("\r\n");
    const [method, path] = requestLine.split(" ");

    // Build response
    let body = "";
    let statusLine = "HTTP/1.1 200 OK\r\n";
    let headers = "Content-Type: text/plain\r\n";

    if (method === "GET" && path === "/") {
      body = "Hello from raw TCP server!";
    } else {
      statusLine = "HTTP/1.1 404 Not Found\r\n";
      body = "Not Found";
    }

    // Full HTTP response
    const response =
      statusLine +
      headers +
      `Content-Length: ${Buffer.byteLength(body)}\r\n` +
      "\r\n" +
      body;

    socket.write(response);
    socket.end(); // Close connection
  });
});

server.listen(3000, () => {
  console.log("🚀 Raw TCP HTTP server running at http://localhost:3000");
});
```
