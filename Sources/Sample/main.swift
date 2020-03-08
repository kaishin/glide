import SwiftExpress
import Foundation
let app = SwiftExpress()

app.use { request, response, next in
  print("\(request.header.method):", request.header.uri)
  next()
}

app.use(
  parseParameters,
  cors(allowOrigin: "*")
)

app.get("/hello") { _, response, _ in
  response.send("Hello, world!")
}

}

app.get("/static") { _, response, _ in
  response.render(StaticPage())
}

app.listen(1337)
