import XCTest
@testable import wheel
import Combine

class HTTPServiceTests: XCTestCase {
  var sut: HTTPService!
  var mockSession: MockURLSession!
  var mockTokenRefresher: MockTokenRefresher!
  var mockTokenStorage: MockTokenStorage!

  override func setUp() {
    super.setUp()
    mockSession = MockURLSession()
    mockTokenRefresher = MockTokenRefresher()
    mockTokenStorage = MockTokenStorage()
    sut = HTTPService(tokenRefresher: mockTokenRefresher, tokenStorage: mockTokenStorage, session: mockSession)
  }

  override func tearDown() {
    sut = nil
    mockSession = nil
    mockTokenRefresher = nil
    mockTokenStorage = nil
    super.tearDown()
  }

  func testRequestDecodableCallsDataForRequest() async throws {
    let requestConfig = MockRequest()
    mockSession.dataResult = (Data(), HTTPURLResponse())
    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTAssertTrue(mockSession.callCount == 1)
    } catch {
      XCTFail("Expected successful decoding of EmptyResponse")
    }
  }

  func testRequestVoidCallsDataForRequest() async throws {
    let requestConfig = MockRequest()
    mockSession.dataResult = (Data(), HTTPURLResponse())
    do {
      try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTAssertTrue(mockSession.callCount == 1)
    } catch {
      XCTFail("Expected successful request")
    }
  }

  func testRequestDecodableCallsRefreshOnUnauthorizedErrorAndRepeats() async throws {
    let requestConfig = MockRequest()
    mockSession.dataResult = (Data(), HTTPURLResponse())
    mockSession.error = NetworkingError.unauthorized

    mockTokenRefresher.refreshCallback = { [weak self] in
      self?.mockSession.error = nil
    }
    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTAssertTrue(mockTokenRefresher.refreshCalled)
      XCTAssertTrue(mockSession.callCount == 2)
    } catch {
      XCTFail("Expected successful decoding of EmptyResponse")
    }
  }

  func testRequestVoidCallsRefreshOnUnauthorizedErrorAndRepeats() async throws {
    let requestConfig = MockRequest()
    mockSession.dataResult = (Data(), HTTPURLResponse())
    mockSession.error = NetworkingError.unauthorized

    mockTokenRefresher.refreshCallback = { [weak self] in
      self?.mockSession.error = nil
    }
    do {
      try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTAssertTrue(mockTokenRefresher.refreshCalled)
      XCTAssertTrue(mockSession.callCount == 2)
    } catch {
      XCTFail("Expected successful request")
    }
  }

  func testRequestDecodableThrowsErrorOnNoResponse() async throws {
    let requestConfig = MockRequest()
    mockSession.error = NetworkingError.noResponse
    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTFail("Expected no response error")
    } catch NetworkingError.noResponse {
      // Success
    } catch {
      XCTFail("Expected no response error")
    }
  }

  func testRequestVoidThrowsErrorOnNoResponse() async throws {
    let requestConfig = MockRequest()
    mockSession.error = NetworkingError.noResponse
    do {
      try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTFail("Expected no response error")
    } catch NetworkingError.noResponse {
      // Success
    } catch {
      XCTFail("Expected no response error")
    }
  }

  func testApplyCommonHeadersWithoutAuthentication() async {
    var request = MockRequest()
    request.headers = ["test": "value"]
    mockSession.dataResult = (Data(), HTTPURLResponse())

    do {
      try? await sut.request(authenticated: false, requestConfig: request)
      XCTAssertEqual(mockSession.requestUnderTest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
      XCTAssertEqual(mockSession.requestUnderTest?.value(forHTTPHeaderField: "cache-control"), "no-cache")
      XCTAssertEqual(mockSession.requestUnderTest?.value(forHTTPHeaderField: "test"), "value")
    }
  }

  func testApplyCommonHeadersWithAuthentication() async {
    mockSession.dataResult = (Data(), HTTPURLResponse())
    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: MockRequest())
      XCTAssertEqual(mockSession.requestUnderTest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
      XCTAssertEqual(mockSession.requestUnderTest?.value(forHTTPHeaderField: "cache-control"), "no-cache")
      XCTAssertEqual(mockSession.requestUnderTest?.value(forHTTPHeaderField: "Authorization"), "Bearer mock_token")
    } catch {
      XCTFail("Expected successful request with token presence")
    }
  }

  func testAddAuthenticationHeadersWithTokensPresent() async {
    mockTokenStorage.accessToken = "accessToken"
    mockTokenStorage.refreshToken = "refreshToken"
    mockSession.dataResult = (Data(), HTTPURLResponse())

    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: MockRequest())
      XCTAssertEqual(mockSession.requestUnderTest?.value(forHTTPHeaderField: "Authorization"), "Bearer accessToken")
    } catch {
      XCTFail("Expected successful request with token presence")
    }
  }

  func testAddAuthenticationHeadersWithMissingRefreshToken() async {
    mockTokenStorage.accessToken = nil
    mockTokenStorage.refreshToken = nil
    mockSession.dataResult = (Data(), HTTPURLResponse())

    do {
      try await sut.request(authenticated: true, requestConfig: MockRequest())
    } catch NetworkingError.unauthorized {
      XCTAssertTrue(mockTokenStorage.wipeTokensCalled)
    } catch {
      XCTFail("Expected unauthorized error")
    }
  }

  func testRequestDecodableWithSuccessResponse() async throws {
    let requestConfig = MockRequest()
    let mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    mockSession.dataResult = (Data(), mockResponse)

    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTAssertTrue(mockSession.callCount == 1)
    } catch {
      XCTFail("Expected successful decoding of EmptyResponse")
    }
  }

  func testRequestDecodableWithErrorResponse() async throws {
    let requestConfig = MockRequest()
    let mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 404, httpVersion: nil, headerFields: nil)!
    mockSession.dataResult = (Data(), mockResponse)

    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTFail("Expected error response")
    } catch NetworkingError.invalidErrorBody {
      // Success
    } catch {
      XCTFail("Expected not found error")
    }
  }

  func testRequestDecodableWithServerErrorResponse() async throws {
    let requestConfig = MockRequest()
    let jsonData = """
    {
      "error": "server error",
      "domainCode": 3
    }
    """.data(using: .utf8)!
    let mockResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 500, httpVersion: nil, headerFields: nil)!
    mockSession.dataResult = (jsonData, mockResponse)

    do {
      let _: EmptyResponse = try await sut.request(authenticated: true, requestConfig: requestConfig)
      XCTFail("Expected server error response")
    } catch NetworkingError.api(domainErrorMessage: "server error",
                                statusCode: 500,
                                domainCode: .AppRequiresUpdate) {
    } catch {
      XCTFail("Expected server error")
    }
  }
}

class MockURLSession: URLSessionProtocol {
  var dataResult: (Data, URLResponse)?
  var error: Error?
  var callCount = 0
  var dataForRequestCalledCompletion: (() -> Void)?
  var requestUnderTest: URLRequest?

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    requestUnderTest = request
    callCount += 1
    dataForRequestCalledCompletion?()
    if let error = error {
      throw error
    }
    if let dataResult = dataResult {
      return dataResult
    }
    throw NetworkingError.noResponse
  }
}

class MockTokenRefresher: TokenRefreshing {
  var refreshCalled = false
  var refreshSuccess = true
  var refreshCallback: (() -> Void)?

  var tokenRefreshFailure: AnyPublisher<Void, Never> { tokenRefreshFailureSubject.eraseToAnyPublisher() }
  var tokenRefreshFailureSubject = PassthroughSubject<Void, Never>()

  func refresh() async throws {
    refreshCalled = true
    if !refreshSuccess {
      throw NetworkingError.unauthorized
    }
    refreshCallback?()
  }
}

class MockTokenStorage: TokenStoring {
  var accessToken: String? = "mock_token"
  var refreshToken: String? = "mock_refresh_token"
  var tokensWiped: AnyPublisher<Void, Never> { tokensWipedSubject.eraseToAnyPublisher() }
  private let tokensWipedSubject = PassthroughSubject<Void, Never>()
  var lastSocialLoginProvider: LoginMethod? = .email
  var isLoggedIn = PassthroughSubject<Bool, Never>().eraseToAnyPublisher()
  var wipeTokensCalled = false

  func wipeTokens() {
    wipeTokensCalled = true
    tokensWipedSubject.send(())
  }

  func saveTokens(tokenResponse: AuthenticationResponse) {
    accessToken = tokenResponse.accessToken
    refreshToken = tokenResponse.refreshToken
    lastSocialLoginProvider = tokenResponse.provider
  }
}

struct MockRequest: ConfigRequestConvertible {
  var baseURL: URL = URL(string: "https://example.com")!
  var path: String = "/path"
  var method: HTTPMethod = .GET
  var parameters: [String: Any] = [:]
  var headers: [String: String]? = nil

  func asURLRequest() throws -> URLRequest {
    var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)

    var request = URLRequest(url: urlComponents!.url!)
    request.httpMethod = method.rawValue

    headers?.forEach({ header in
      request.setValue(header.value, forHTTPHeaderField: header.key)
    })

    switch method {
    case .GET, .DELETE:
      var queryItems: [URLQueryItem] = []
      for (key, value) in parameters {
        queryItems.append(URLQueryItem(name: key, value: "\(value)"))
      }
      urlComponents?.queryItems = queryItems
    case .POST, .PUT, .PATCH:
      let jsonData = try? JSONSerialization.data(withJSONObject: parameters)
      request.httpBody = jsonData
    }

    return request
  }
}
