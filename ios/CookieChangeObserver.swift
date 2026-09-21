import Foundation
import WebKit

enum CookieChangeStore: String, Equatable {
  case foundation
  case webKit
}

final class CookieChangeObservationLifecycle {
  typealias Handler = (CookieChangeStore) -> Void
  typealias StartObservation = (@escaping Handler) -> Void

  private let startObservation: StartObservation
  private let stopObservation: () -> Void
  private var handler: Handler?
  private(set) var isObserving = false

  init(
    startObservation: @escaping StartObservation,
    stopObservation: @escaping () -> Void
  ) {
    self.startObservation = startObservation
    self.stopObservation = stopObservation
  }

  func start(handler: @escaping Handler) {
    self.handler = handler
    guard !isObserving else { return }

    isObserving = true
    startObservation { [weak self] store in
      self?.handler?(store)
    }
  }

  func stop() {
    guard isObserving else { return }

    isObserving = false
    handler = nil
    stopObservation()
  }
}

final class SystemCookieChangeObserver: NSObject, WKHTTPCookieStoreObserver {
  typealias Handler = CookieChangeObservationLifecycle.Handler

  private var foundationToken: NSObjectProtocol?
  private var webKitStore: WKHTTPCookieStore?
  private var handler: Handler?

  func start(handler: @escaping Handler) {
    self.handler = handler

    foundationToken = NotificationCenter.default.addObserver(
      forName: .NSHTTPCookieManagerCookiesChanged,
      object: HTTPCookieStorage.shared,
      queue: .main
    ) { [weak self] _ in
      self?.handler?(.foundation)
    }

    let store = WKWebsiteDataStore.default().httpCookieStore
    store.add(self)
    webKitStore = store
  }

  func stop() {
    if let foundationToken {
      NotificationCenter.default.removeObserver(foundationToken)
      self.foundationToken = nil
    }
    webKitStore?.remove(self)
    webKitStore = nil
    handler = nil
  }

  func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
    handler?(.webKit)
  }
}

final class CookieChangeObserver {
  typealias Handler = CookieChangeObservationLifecycle.Handler

  private let backend: SystemCookieChangeObserver
  private let lifecycle: CookieChangeObservationLifecycle

  init() {
    let backend = SystemCookieChangeObserver()
    self.backend = backend
    lifecycle = CookieChangeObservationLifecycle(
      startObservation: { [weak backend] handler in
        backend?.start(handler: handler)
      },
      stopObservation: { [weak backend] in
        backend?.stop()
      }
    )
  }

  func start(handler: @escaping Handler) {
    onMain {
      self.lifecycle.start(handler: handler)
    }
  }

  func stop() {
    onMain {
      self.lifecycle.stop()
    }
  }

  private func onMain(_ action: @escaping () -> Void) {
    if Thread.isMainThread {
      action()
    } else {
      DispatchQueue.main.sync(execute: action)
    }
  }
}
