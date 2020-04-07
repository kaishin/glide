import Foundation
import NIO
import NIOHTTP1

public final class Application: Router {
  public private(set) var didShutdown: Bool
  public private(set) var environment: Environment

  var allocator: ByteBufferAllocator = .init()

  private let loopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
  private var serverChannel: Channel?
  private let threadPool = { () -> NIOThreadPool in
    let threadPool = NIOThreadPool(numberOfThreads: NonBlockingFileIO.defaultThreadPoolSize)
    threadPool.start()
    return threadPool
  }()

  public init(_ environment: Environment = .development) {
    self.didShutdown = false
    self.environment = environment
    super.init()
    configure()
  }

  private func configure() {
    use(parameterParser)
  }
  public func listen(
    _ port: Int,
    _ host: String = "localhost",
    _ backlog: Int = 256
  ) {
    let bootstrap = makeServerBootstrap(backlog)

    do {
      serverChannel = try bootstrap.bind(host: host, port: port).wait()

      guard let localAddress = serverChannel?.localAddress else {
        fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
      }

      print("Server running on http://localhost:\(localAddress.port!)")
      if environment != .testing {
        try serverChannel!.closeFuture.wait()
      }
    } catch {
      fatalError("Failed to start server: \(error)")
    }
  }

  public func listen(
    unixSocket: String = "glide-app.socket",
    backlog: Int = 256
  ) {
    let bootstrap = makeServerBootstrap(backlog)

    do {
      serverChannel = try bootstrap.bind(unixDomainSocketPath: unixSocket).wait()
      print("Server running on:", socket)
      if environment != .testing {
        try serverChannel!.closeFuture.wait()
      }
    } catch {
      fatalError("Failed to start server: \(error.localizedDescription)")
    }
  }

  private func makeServerBootstrap(_ backlog: Int) -> ServerBootstrap {
    let localAddressReuseOption = ChannelOptions.socket(
      SocketOptionLevel(SOL_SOCKET),
      SO_REUSEADDR
    )

    let bootstrap = ServerBootstrap(group: loopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: Int32(backlog))
      .serverChannelOption(localAddressReuseOption, value: 1)
      .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
          channel.pipeline.addHandlers([
            HTTPRequestSerializer(application: self),
            HTTPResponseSerializer(),
            HTTPConnectionHandler(router: self)
          ])
        }
      }
      .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
      .childChannelOption(localAddressReuseOption, value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

    return bootstrap

  }

  public func shutdown() {
    assert(!self.didShutdown, "Server has already shut down")
    do {
      try serverChannel?.close().wait()
      try loopGroup.syncShutdownGracefully()
    } catch {
      print("Error while shutting down:", error.localizedDescription)
    }

    self.didShutdown = true
    print("Server shut down successfully.")
  }

  deinit {
    if !self.didShutdown {
      assertionFailure("Server shut down before the app was deinitialized.")
    }
  }
}

extension Application {
  public var fileIO: NonBlockingFileIO {
    .init(threadPool: self.threadPool)
  }
}
