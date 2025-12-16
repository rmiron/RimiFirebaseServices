//
//  MockRemoteDataManaging.swift
//  RimiFirebaseServices
//
//  Created by Ricardo Miron on 12/16/25.
//

import RimiDefinitions

public struct TestItem: Identifiable, Codable, Equatable & Sendable {
    public let id: String
    var value: String
}

public final actor MockRemoteDataManager<T: Codable & Identifiable & Equatable & Sendable>: RemoteDataManaging {

    // MARK: - Storage
    private var storage: [String: T] = [:]

    // MARK: - Call Tracking
    private(set) var createdItems: [T] = []
    private(set) var updatedItems: [T] = []
    private(set) var deletedItems: [T] = []

    // MARK: - Errors
    var errorToThrow: Error?

    // MARK: - CRUD

    public func createItem(_ item: T, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[item.id as! String] = item
        createdItems.append(item)
    }

    public func createItem(_ item: T, withID id: String, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[id] = item
        createdItems.append(item)
    }

    public func readItem(by id: String, inCollection collectionName: String?) async throws -> T? {
        try maybeThrow()
        return storage[id]
    }

    public func readItems(
        startingAfter lastKey: String?,
        limit: UInt,
        inCollection collectionName: String?
    ) async throws -> [T] {
        try maybeThrow()

        let sortedKeys = storage.keys.sorted()
        let startIndex = lastKey.flatMap { sortedKeys.firstIndex(of: $0).map { $0 + 1 } } ?? 0

        return sortedKeys
            .dropFirst(startIndex)
            .prefix(Int(limit))
            .compactMap { storage[$0] }
    }

    public func updateItem(_ item: T, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[item.id as! String] = item
        updatedItems.append(item)
    }

    public func deleteItem(_ item: T, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[item.id as! String] = nil
        deletedItems.append(item)
    }

    public func deleteAllItems(inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage.removeAll()
    }

    // MARK: - Helpers

    private func maybeThrow() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
