//
//  TokenStoring.swift
//  wheel
//
//  Created by Eren Kabakci
//

import Foundation
import Combine

public protocol TokenStoring {
  var accessToken: String? { get }
  var refreshToken: String? { get }
  var tokensWiped: AnyPublisher<Void, Never> { get }
  var lastSocialLoginProvider: LoginMethod? { get }
  var isLoggedIn: AnyPublisher<Bool, Never> { get }
  func wipeTokens()
  func saveTokens(tokenResponse: AuthenticationResponse)
}

public struct AuthenticationResponse: Codable {
  public let accessToken: String
  public let refreshToken: String
  public let provider: LoginMethod
}

public enum LoginMethod: String, Codable {
  case google
  case email
}
