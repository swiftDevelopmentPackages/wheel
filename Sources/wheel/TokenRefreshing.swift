//
//  TokenRefreshing.swift
//  wheel
//
//  Created by Eren Kabakci
//

import Foundation
import Combine

public protocol TokenRefreshing {
  func refresh() async throws
  var tokenRefreshFailure: AnyPublisher<Void, Never> { get }
}
