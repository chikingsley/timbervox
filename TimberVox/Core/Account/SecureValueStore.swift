import Foundation
import Security

enum SecureValueStoreError: Error {
  case invalidData
  case unexpectedStatus(OSStatus)
}

struct SecureValueStore: Sendable {
  let service: String

  func string(for account: String, synchronizable: Bool) throws -> String? {
    var query = baseQuery(
      account: account,
      synchronizable: synchronizable
    )
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw SecureValueStoreError.unexpectedStatus(status)
    }
    guard
      let data = result as? Data,
      let value = String(data: data, encoding: .utf8)
    else {
      throw SecureValueStoreError.invalidData
    }
    return value
  }

  func set(
    _ value: String,
    for account: String,
    synchronizable: Bool
  ) throws {
    let query = baseQuery(
      account: account,
      synchronizable: synchronizable
    )
    let data = Data(value.utf8)
    let update: [String: Any] = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(
      query as CFDictionary,
      update as CFDictionary
    )
    if updateStatus == errSecSuccess {
      return
    }
    guard updateStatus == errSecItemNotFound else {
      throw SecureValueStoreError.unexpectedStatus(updateStatus)
    }

    var attributes = query
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] =
      synchronizable
      ? kSecAttrAccessibleAfterFirstUnlock
      : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(attributes as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw SecureValueStoreError.unexpectedStatus(addStatus)
    }
  }

  func remove(account: String, synchronizable: Bool) throws {
    let status = SecItemDelete(
      baseQuery(
        account: account,
        synchronizable: synchronizable
      ) as CFDictionary
    )
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw SecureValueStoreError.unexpectedStatus(status)
    }
  }

  private func baseQuery(
    account: String,
    synchronizable: Bool
  ) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrSynchronizable as String: synchronizable,
    ]
  }
}
