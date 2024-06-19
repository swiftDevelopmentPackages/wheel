//
//  HTTPService.swift
//  wheel
//
//  Created by Eren Kabakci
//

import Foundation

public protocol HTTPServing {
  func request<T: Decodable>(authenticated: Bool, requestConfig: ConfigRequestConvertible) async throws -> T
  func request(authenticated: Bool, requestConfig: ConfigRequestConvertible) async throws
}

public extension HTTPServing {
  func request<T: Decodable>(authenticated: Bool = true, requestConfig: ConfigRequestConvertible) async throws -> T {
    try await request(authenticated: authenticated, requestConfig: requestConfig)
  }

  func request(authenticated: Bool = true, requestConfig: ConfigRequestConvertible) async throws {
    try await request(authenticated: authenticated, requestConfig: requestConfig)
  }
}

final public class HTTPService: HTTPServing {
  let tokenRefresher: TokenRefreshing
  let tokenStorage: TokenStoring
  let commonHeaders: [String: String]
  private let session: URLSessionProtocol

  public init(tokenRefresher: TokenRefreshing,
              tokenStorage: TokenStoring,
              commonHeaders: [String: String] = [:],
              session: URLSessionProtocol = URLSession.shared) {
      self.tokenRefresher = tokenRefresher
      self.tokenStorage = tokenStorage
      self.commonHeaders = commonHeaders
      self.session = session
  }

  public func request<T: Decodable>(authenticated: Bool, requestConfig: ConfigRequestConvertible) async throws -> T {
    let request = try applyCommonHeaders(to: requestConfig, authenticated: authenticated)

    do {
      let result = try await session.data(for: request)
      return try process(result: result)
    } catch {
      if case NetworkingError.unauthorized = error {
        do {
          try await tokenRefresher.refresh()

          let repeatedRequest = try applyCommonHeaders(to: requestConfig, authenticated: authenticated)
          let repeatedResult = try await session.data(for: repeatedRequest)
          return try process(result: repeatedResult)
        }
      } else {
        throw error
      }
    }
  }

  public func request(authenticated: Bool, requestConfig: ConfigRequestConvertible) async throws {
    let request = try applyCommonHeaders(to: requestConfig, authenticated: authenticated)

    do {
      let result = try await session.data(for: request)
      let _: EmptyResponse = try process(result: result)
    } catch {
      if case NetworkingError.unauthorized = error {
        do {
          try await tokenRefresher.refresh()

          let repeatedRequest = try applyCommonHeaders(to: requestConfig, authenticated: authenticated)
          let repeatedResult = try await session.data(for: repeatedRequest)
          let _: EmptyResponse = try process(result: repeatedResult)
        }
      } else {
        throw error
      }
    }
  }

  private func applyCommonHeaders(to requestConfig: ConfigRequestConvertible, authenticated: Bool) throws -> URLRequest {
    var request = try requestConfig.asURLRequest()
    if authenticated { try addAuthenticationHeaders(to: &request) }

    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("no-cache", forHTTPHeaderField: "cache-control")
    for (key, value) in commonHeaders {
      request.addValue(value, forHTTPHeaderField: key)
    }
    return request
  }

  private func addAuthenticationHeaders(to request: inout URLRequest) throws {
    guard let accessToken = tokenStorage.accessToken,
          let _ = tokenStorage.refreshToken else {
      tokenStorage.wipeTokens()
      throw NetworkingError.unauthorized
    }
    request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
  }

  private func process<T: Decodable>(result: (Data, URLResponse)) throws -> T {
    guard let response = result.1 as? HTTPURLResponse else {
      throw NetworkingError.noResponse
    }
    switch response.statusCode {
    case 200...299:
      guard T.self != EmptyResponse.self else { return EmptyResponse() as! T }
      do {
        return try JSONDecoder().decode(T.self, from: result.0)
      } catch {
        throw NetworkingError.serializationError(underlying: error)
      }
    case 400...599:
      if response.statusCode == 401 {
        throw NetworkingError.unauthorized
      }

      let richError = try? JSONDecoder().decode(BaseErrorResponse.self, from: result.0)

      if let richError {
        throw NetworkingError.api(domainErrorMessage: richError.error,
                                  statusCode: response.statusCode,
                                  domainCode: richError.domainCode)
      } else {
        throw NetworkingError.invalidErrorBody
      }
    default:
      throw NetworkingError.unknown
    }
  }
}

public enum NetworkingError: Error {
  case noResponse
  case api(domainErrorMessage: String, statusCode: Int, domainCode: DomainErrorCode?)
  case serializationError(underlying: Error)
  case invalidErrorBody
  case unauthorized
  case other(Error)
  case unknown
}

public struct BaseErrorResponse: Decodable {
  public let error: String
  public let domainCode: DomainErrorCode?
}

public enum DomainErrorCode: Int, Decodable {
  case TrialExpired = 1
  case NotSubscribed
  case AppRequiresUpdate
  case DailyFreeUsageExceeded
  case RateLimitExceeded
}

struct EmptyResponse: Decodable {}

public protocol URLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
