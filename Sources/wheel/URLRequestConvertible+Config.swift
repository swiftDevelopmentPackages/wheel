//
//  URLRequestConvertible+Config.swift
//  wheel
//
//  Created by Eren Kabakci
//

import Foundation

public enum HTTPMethod: String {
  case GET
  case POST
  case PUT
  case DELETE
  case PATCH
}

public protocol ConfigRequestConvertible {
  var baseURL: URL { get }
  var path: String { get }
  var method: HTTPMethod { get }
  var parameters: [String: Any] { get }
  var headers: [String: String]? { get }
  func asURLRequest() throws -> URLRequest
}

public extension ConfigRequestConvertible {
  var headers: [String : String]? {
    return nil
  }
}

public extension ConfigRequestConvertible {
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
