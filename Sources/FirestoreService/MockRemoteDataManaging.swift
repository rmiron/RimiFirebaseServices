//
//  MockRemoteDataManaging.swift
//  RimiFirebaseServices
//
//  Created by Ricardo Miron on 12/16/25.
//

import RimiDefinitions

struct TestItem: Identifiable, Codable, Equatable & Sendable {
    let id: String
    var value: String
}

final actor MockRemoteDataManager<T: Codable & Identifiable & Equatable & Sendable>: RemoteDataManaging {

    // MARK: - Storage
    private var storage: [String: T] = [:]

    // MARK: - Call Tracking
    private(set) var createdItems: [T] = []
    private(set) var updatedItems: [T] = []
    private(set) var deletedItems: [T] = []

    // MARK: - Errors
    var errorToThrow: Error?

    // MARK: - CRUD

    func createItem(_ item: T, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[item.id as! String] = item
        createdItems.append(item)
    }

    func createItem(_ item: T, withID id: String, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[id] = item
        createdItems.append(item)
    }

    func readItem(by id: String, inCollection collectionName: String?) async throws -> T? {
        try maybeThrow()
        return storage[id]
    }

    func readItems(
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

    func updateItem(_ item: T, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[item.id as! String] = item
        updatedItems.append(item)
    }

    func deleteItem(_ item: T, inCollection collectionName: String?) async throws {
        try maybeThrow()
        storage[item.id as! String] = nil
        deletedItems.append(item)
    }

    func deleteAllItems(inCollection collectionName: String?) async throws {
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
