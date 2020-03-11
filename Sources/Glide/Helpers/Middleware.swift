import Foundation

let requestParameterKey = "com.redalemeden.glide.parameter"

public typealias Handler = () -> Void
public typealias HTTPHandler = (Request, Response) throws -> Void
public typealias ErrorHandler = ([Error], Request, Response) -> Void

public typealias Middleware = (
  _ request: Request,
  _ response: Response,
  _ next: @escaping () -> Void
) throws -> Void

public func passthrough(_ perform: @escaping HTTPHandler) -> Middleware {
  return { request, response, nextHandler in
    try perform(request, response)
    nextHandler()
  }
}

public func finalize(_ perform: @escaping HTTPHandler) -> Middleware {
  return { request, response, _ in
    try perform(request, response)
  }
}

// MARK: - Built-in Middleware

public let parameterParser = {
  passthrough { request, response in
    guard let queryItems = URLComponents(string: request.header.uri)?.queryItems else { return }

    request.userInfo[requestParameterKey] = Dictionary(grouping: queryItems, by: { $0.name })
      .mapValues {
        $0.compactMap({ $0.value })
          .joined(separator: ",")
      }
  }
}()

public let consoleLogger = {
  passthrough { request, response in
    print("\(request.header.method):", request.header.uri)
  }
}()

public let errorLogger: ErrorHandler = { errors, request, response in
  errors.forEach {
    print("Error:", $0.localizedDescription)
  }
}

public func corsHandler(allowOrigin origin: String) -> Middleware {
  { request, response, nextHandler in
    response["Access-Control-Allow-Origin"] = origin
    response["Access-Control-Allow-Headers"] = "Accept, Content-Type"
    response["Access-Control-Allow-Methods"] = "GET, OPTIONS"

    if request.header.method == .OPTIONS {
      response["Allow"] = "GET, OPTIONS"
      response.send("")
    } else {
      nextHandler()
    }
  }
}


