import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient
import XCTest
@testable import Glide

final class RoutingTests: GlideTests {
  func testPathBuilder() throws {
    let literal = "/hello/{foo}/{bar:string}/baz/{qux:int}/"
    let segments = pathSegmentParser.run(literal).match ?? []
    XCTAssertFalse(segments.isEmpty)
    XCTAssertEqual(segments[0], .fixed("hello"))
    XCTAssertEqual(segments[1], .string("foo"))
    XCTAssertEqual(segments[2], .string("bar"))
    XCTAssertEqual(segments[4], .int("qux"))
  }

  func testPathMatching() throws {
    let expectation = XCTestExpectation()

    performHTTPTest { app, client in
      app.get("hello", .string("foo"), .int("bar")) { request, response in
        response.send(request.pathParameters.foo ?? "")

        XCTAssertEqual(request.pathParameters.foo, "test")
        XCTAssertEqual(request.pathParameters.bar, 58)
        expectation.fulfill()
      }

      let request = try HTTPClient.Request(
        url: "http://localhost:\(testPort)/hello/test/58",
        method: .GET,
        headers: .init()
      )

      _ = try client.execute(request: request).wait()
    }

    wait(for: [expectation], timeout: 5)
  }

  func testPathLiteralMatching() throws {
    let path = "/hello/{foo}/{bar:string}/baz/{qux:int}/"
    let expectation = XCTestExpectation()

    performHTTPTest { app, client in
      app.get(path) { request, response in
        response.send(request.pathParameters.foo ?? "")

        XCTAssertEqual(request.pathParameters.foo, "test")
        XCTAssertEqual(request.pathParameters.bar, "glide")
        XCTAssertEqual(request.pathParameters.qux, 58)
        expectation.fulfill()
      }

      let request = try HTTPClient.Request(
        url: "http://localhost:\(testPort)/hello/test/glide/baz/58",
        method: .GET,
        headers: .init()
      )

      _ = try client.execute(request: request).wait()
    }

    wait(for: [expectation], timeout: 5)
  }

  func testPathLiteralNotMatching() throws {
    let expectation = XCTestExpectation()

    performHTTPTest { app, client in
      app.get("/hello/{foo}/{bar:string}/baz/{qux:int}/") { request, response in
        response.send(request.pathParameters.foo ?? "")
      }

      app.get("/hello") { request, response in
        response.send(request.pathParameters.foo ?? "")
      }

      app.get("/help") { request, response in
        response.send(request.pathParameters.foo ?? "")
      }

      let request = try HTTPClient.Request(
        url: "http://localhost:\(testPort)/help/test/glide/baz/58",
        method: .GET,
        headers: .init()
      )

      let response = try client.execute(request: request).wait()
      var buffer = response.body ?? ByteBufferAllocator().buffer(capacity: 0)

      let data = buffer.readData(length: buffer.readableBytes)
      XCTAssertNotNil(data)

      let error = try? JSONDecoder().decode(Router.ErrorResponse.self, from: data!)
      XCTAssertNotNil(error)
      XCTAssertEqual(error!.error, "No middleware found to handle this route.")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5)
  }
}
