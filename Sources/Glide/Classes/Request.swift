import NIOHTTP1
import Foundation
import NIO

public final class Request {
  public let application: Application
  public let header: HTTPRequestHead
  public var body: Data? = nil
  public var pathParameters = Parameters()
  public var queryParameters = Parameters()
  public var userInfo = [AnyHashable: Any]()
  public let eventLoop: EventLoop

  init(
    application: Application,
    header: HTTPRequestHead,
    eventLoop: EventLoop
  ) {
    self.application = application
    self.header = header
    self.eventLoop = eventLoop
  }
}

extension Request {
  public var fileIO: FileReader {
    return .init(
      fileIO: application.fileIO,
      allocator: application.allocator,
      request: self
    )
  }
}
