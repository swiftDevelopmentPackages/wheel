# wheel
Yet another wheel. Reinvented.

A modern, lightweight (literally two methods) networking layer for Swift using async-await. 

## Features

- Built in OAuth 2.0 support using Bearer tokens and refresh mechanism.
   - Auto-retry with existing `refreshToken` in case of a `401`
   - Auto saves newly exchanged tokens or wipe them in case of invalidation.
- Asynchronous API using Swift's async-await
- Token refreshing and storing interfaces out of the box.
- HTTP service with request configuration to accommodate GET, POST, PATCH, PUT, DELETE along with urlParams, request bodies.
- Supports encode/decode of any `Codable` types along with `204` empty responses.
- Rich error body support. Any statusCode `400...599` can decode a custom `RichErrorBody` in case of a failure if your server responds in the following format,
```
{
  "error": "Your Server Error Message",
  "domainCode": Your custom domain error code(Int)
}
```


## Installation

### Swift Package Manager

You can install Wheel using the [Swift Package Manager](https://swift.org/package-manager/) by adding the following line to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/swiftDevelopmentPackages/wheel.git", from: "1.0.0")
]
```
Then, add wheel to your target's dependencies:
```
targets: [
    .target(name: "YourTarget", dependencies: ["wheel"]),
]
```

Or, simply add using XCode's package dependencies tab.

## Usage

Using wheel is easy with built-in interfaces. 

```swift
public protocol HTTPServing {
  func request<T: Decodable>(authenticated: Bool, requestConfig: ConfigRequestConvertible) async throws -> T
  func request(authenticated: Bool, requestConfig: ConfigRequestConvertible) async throws
}
```

There are literally only two methods to perform a request 🚀


### Creating the HTTPService

First, you need to create an instance of `HTTPService`. You can do this by passing the required dependencies to its initializer:

```swift
let tokenRefresher = YourTokenRefresher() // Your implementation of TokenRefreshing
let tokenStorage = YourTokenStorage() // Your implementation of TokenStoring
let commonHeaders = ["Custom-Header": "CustomValue"] // Your domain specific custom headers you want to append to every request. Content-Type, Authorization etc. is added automatically

let httpService = HTTPService(tokenRefresher: tokenRefresher,
                              tokenStorage: tokenStorage,
                              commonHeaders: commonHeaders)
```

### Creating a ConfigRequestConvertible

The `ConfigRequestConvertible` protocol is used to configure the HTTP request. You need to create a type that conforms to this protocol for each type of request you want to make.

Here's an example of a `ConfigRequestConvertible` for a GET request to fetch a user:

```swift
enum YourRequestConfig: ConfigRequestConvertible {
    case useCaseOne
    case useCaseTwo

    var baseURL: URL {
      URL(string: yourAPIBaseURL)!
    }

    var path: String {
      switch self {
      case .useCaseOne:
        return "useCaseOnePath"
      case .useCaseTwo:
        return "useCaseTwoPath"
      }
    }

    var method: HTTPMethod {
      switch self {
      case .useCaseOne:
        return .GET
      case .useCaseTwo:
        return .POST
      }
    }

    var parameters: [String: Any] {
      return [:] // your urlParams or request body
    }

    var headers: [String : String]? {
      return [:] // your endpoint specific headers
    }
  }
```

### Decodable request, authenticated/unauthenticated

```swift
struct User: Decodable {
  let id: Int
  let name: String
  // other properties...
}

do {
  let user: User = try await httpService.request(authenticated: true, requestConfig: YourRequestConfig().useCaseOne)
  print("Received user: \(user)")
} catch {
  print("Failed to fetch user: \(error)")
}
```
In this example, User is a `Decodable` struct that represents a user. `YourRequestConfig` is a `ConfigRequestConvertible` that configures a `GET` request to fetch a user. `authenticated: true` assumes that your `TokenRefreshing` injectable holds a valid `accessToken` & `refreshToken` pair, if not tries to refresh or invalidates.

### Void request, authenticated/unauthenticated

```swift

do {
  try await httpService.request(authenticated: false, requestConfig: YourRequestConfig().useCasetTwo)
  print("User updated successfully.")
} catch {
  print("Failed to update user: \(error)")
}
```
In this example, `YourRequestConfig` is a `ConfigRequestConvertible` that configures a `PUT` request to update a user. Since the response does not need to be decoded into a model, the return type of the request method is `Void`. Same rules of `authenticated: Bool` applies as in the previous example.


