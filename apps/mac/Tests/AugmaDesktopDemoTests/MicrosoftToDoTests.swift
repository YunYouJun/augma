import CryptoKit
import XCTest
@testable import AugmaDesktopDemo

private actor MicrosoftRequestLog {
  var requests: [URLRequest] = []
  func record(_ request: URLRequest) { requests.append(request) }
}

private func microsoftResponse(_ request: URLRequest, status: Int = 200, body: String) -> (Data, HTTPURLResponse) {
  (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!)
}

final class MicrosoftToDoTests: XCTestCase {
  func testOAuthUsesPKCEAndRejectsWrongStateOrRedirect() throws {
    let request = try MicrosoftOAuthRequest()
    let url = request.authorizationURL(clientID: "client-id")
    let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    XCTAssertEqual(items.first(where: { $0.name == "code_challenge_method" })?.value, "S256")
    XCTAssertEqual(items.first(where: { $0.name == "code_challenge" })?.value,
                   MicrosoftOAuthRequest.base64URL(Data(SHA256.hash(data: Data(request.verifier.utf8)))))
    XCTAssertFalse(url.absoluteString.contains(request.verifier))
    XCTAssertFalse(url.absoluteString.contains("client_secret"))
    XCTAssertEqual(items.first(where: { $0.name == "scope" })?.value, "https://graph.microsoft.com/Tasks.ReadWrite offline_access")
    let callback = URL(string: "\(MicrosoftOAuthRequest.redirectURI)?state=\(request.state)&code=accepted")!
    XCTAssertEqual(try request.code(from: callback), "accepted")
    XCTAssertThrowsError(try request.code(from: URL(string: "\(MicrosoftOAuthRequest.redirectURI)?state=wrong&code=accepted")!))
    XCTAssertThrowsError(try request.code(from: URL(string: "https://attacker.example/auth?state=\(request.state)&code=accepted")!))
    XCTAssertThrowsError(try request.code(from: URL(string: "\(callback.absoluteString)&state=\(request.state)")!))
  }

  func testFormEncodingEscapesTokenSeparators() {
    XCTAssertEqual(String(decoding: MicrosoftGraphClient.form(["code": "a+b&c=d /中文"]), as: UTF8.self),
                   "code=a%2Bb%26c%3Dd%20%2F%E4%B8%AD%E6%96%87")
  }

  func testCreateTaskPreservesFullTextAndEncodesListID() async throws {
    let log = MicrosoftRequestLog()
    let client = MicrosoftGraphClient { request in
      await log.record(request)
      return microsoftResponse(request, status: 201, body: "{\"id\":\"created-task\"}")
    }
    let text = String(repeating: "字", count: 300) + "\nbody & <tags>"
    let id = try await client.createTask(text: text, listID: "a/b+?=", token: "test-access-token")
    XCTAssertEqual(id, "created-task")
    let requests = await log.requests
    let request = try XCTUnwrap(requests.first)
    XCTAssertEqual(request.url?.absoluteString, "https://graph.microsoft.com/v1.0/me/todo/lists/a%2Fb%2B%3F%3D/tasks")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    XCTAssertEqual((body["title"] as? String)?.count, 256)
    XCTAssertEqual((body["body"] as? [String: String])?["content"], text)
    XCTAssertEqual((body["body"] as? [String: String])?["contentType"], "text")
  }

  func testPaginationRejectsForeignHostBeforeSendingBearerToken() async throws {
    let log = MicrosoftRequestLog()
    let client = MicrosoftGraphClient { request in
      await log.record(request)
      return microsoftResponse(request, body: "{\"value\":[],\"@odata.nextLink\":\"https://attacker.example/v1.0/me/todo/lists\"}")
    }
    do { _ = try await client.lists(token: "secret"); XCTFail("Expected rejected pagination") }
    catch { XCTAssertTrue(error is CaptureError) }
    let requests = await log.requests
    XCTAssertEqual(requests.count, 1)
  }

  func testPaginationCollectsAllLists() async throws {
    let client = MicrosoftGraphClient { request in
      if request.url?.query == nil {
        return microsoftResponse(request, body: "{\"value\":[{\"id\":\"one\",\"displayName\":\"One\"}],\"@odata.nextLink\":\"https://graph.microsoft.com/v1.0/me/todo/lists?$skip=1\"}")
      }
      return microsoftResponse(request, body: "{\"value\":[{\"id\":\"two\",\"displayName\":\"Two\"}]}")
    }
    let lists = try await client.lists(token: "token")
    XCTAssertEqual(lists.map(\.id), ["one", "two"])
  }

  func testAmbiguousPostFailureIsNeverAutomaticallyRetried() async throws {
    for status in [408, 500, 502] {
      let log = MicrosoftRequestLog()
      let client = MicrosoftGraphClient { request in
        await log.record(request)
        return microsoftResponse(request, status: status, body: "{}")
      }
      do { _ = try await client.createTask(text: "task", listID: "list", token: "token"); XCTFail("Expected uncertainty") }
      catch { guard case CaptureError.uncertain = error else { return XCTFail("Unexpected error: \(error)") } }
      let requests = await log.requests
      XCTAssertEqual(requests.count, 1)
    }
    let client = MicrosoftGraphClient { _ in throw URLError(.timedOut) }
    do { _ = try await client.createTask(text: "task", listID: "list", token: "token"); XCTFail("Expected uncertainty") }
    catch { guard case CaptureError.uncertain = error else { return XCTFail("Expected uncertainty") } }
  }

  func testRejectedPostDoesNotExposeServerBody() async throws {
    let client = MicrosoftGraphClient { request in
      microsoftResponse(request, status: 403, body: "{\"error\":{\"code\":\"Forbidden\",\"message\":\"sensitive user content\"}}")
    }
    do { _ = try await client.createTask(text: "task", listID: "list", token: "token"); XCTFail("Expected rejection") }
    catch {
      let failure = try XCTUnwrap(error as? MicrosoftHTTPError)
      XCTAssertEqual(failure.status, 403)
      XCTAssertEqual(failure.code, "Forbidden")
      XCTAssertFalse(error.localizedDescription.contains("sensitive"))
    }
  }

  @MainActor func testRefreshRotationAndTargetBindingUseKeychainAndPreserveSelection() async throws {
    let suite = "augma.microsoft.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(UUID().uuidString, forKey: "captureMicrosoftClientID")
    let credentials = MicrosoftCredentials(refreshToken: "old-refresh", connectionID: UUID())
    let vault = MemoryMicrosoftCredentials(credentials)
    let log = MicrosoftRequestLog()
    let client = MicrosoftGraphClient { request in
      await log.record(request)
      if request.url!.path.hasSuffix("/token") {
        return microsoftResponse(request, body: "{\"access_token\":\"access\",\"refresh_token\":\"rotated-refresh\",\"expires_in\":3600}")
      }
      if request.httpMethod == "POST" {
        return microsoftResponse(request, status: 201, body: "{\"id\":\"task\"}")
      }
      return microsoftResponse(request, body: "{\"value\":[{\"id\":\"default\",\"displayName\":\"Tasks\",\"wellknownListName\":\"defaultList\"},{\"id\":\"work\",\"displayName\":\"Work\"}]}")
    }
    let store = MicrosoftToDoStore(defaults: defaults, vault: vault, client: client)
    XCTAssertTrue(store.connected)
    await store.refreshLists()
    XCTAssertEqual(vault.value?.refreshToken, "rotated-refresh")
    XCTAssertEqual(vault.value?.connectionID, credentials.connectionID)
    XCTAssertEqual(store.selectedListID, "default")
    let snapshot = store.deliveryTarget()
    store.selectedListID = "work"
    let prepared = try await store.prepare(snapshot)
    XCTAssertEqual(prepared.listID, "default")
    let receipt = try await store.createTask(QuickNote(text: "task", createdAt: .now, updatedAt: .now, delivery: prepared))
    XCTAssertEqual(receipt.remoteID, "task")
    let requests = await log.requests
    XCTAssertEqual(requests.filter { $0.url!.path.hasSuffix("/token") }.count, 1)
    XCTAssertTrue(requests.last!.url!.path.contains("/default/tasks"))
    XCTAssertFalse(String(describing: defaults.dictionaryRepresentation()).contains("rotated-refresh"))
    var otherAccount = prepared
    otherAccount.connectionID = UUID()
    do { _ = try await store.prepare(otherAccount); XCTFail("Expected account mismatch") }
    catch { XCTAssertTrue(error is CaptureError) }
    store.disconnect()
    XCTAssertNil(vault.value)
    XCTAssertFalse(store.connected)
  }
}
