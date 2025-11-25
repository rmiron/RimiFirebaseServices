//
//  FirebaseRTDBService.swift
//
//  Created by Ricardo Miron on 8/29/22.
//

import Foundation
import Firebase
import FirebaseAuth
@preconcurrency import FirebaseDatabase
import RimiDefinitions
import Combine

/*
    THIS IS INTENDED TO WORK WITH FIREBASE REALTIME DATABASE
    PURPOSE: This service provides CRUD operations for any object in the Firebase Realtime Database.
 
    You cannot use a protocol with associatedtypes as a type directly because the compiler needs to know T.
    The compiler will complain:
        - Use of protocol 'FirebaseRTDBRepositoryProtocol' as a type must be written 'any FirebaseRTDBRepositoryProtocol'
    SOLUTION:
    Make the class generic over the repository
    - class AppContainer<UserRepo: AppUserRepository, ReadingRepo: FirebaseRTDBRepositoryProtocol>: ObservableObject
        where ReadingRepo.T == Reading {
 */


// MIGRATE TO RemoteDataManaging FROM RepositoryManaging

@MainActor
public final class FirebaseRTDBService<T: Codable & Identifiable & Sendable>: ObservableObject, RepositoryManaging {

    @Published public private(set) var items: [T] = []
    @Published public private(set)var isLoading: Bool = false

    private let collectionName: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public var itemsPublisher: AnyPublisher<[T], Never> { $items.eraseToAnyPublisher() }
    public var isLoadingPublisher: AnyPublisher<Bool, Never> { $isLoading.eraseToAnyPublisher() }

    public init(collectionName: String) {
        self.collectionName = collectionName
        let _ = Auth.auth().addStateDidChangeListener { _, user in
            if user != nil {
                Task { try await self.readItems() }
            } else {
                self.items.removeAll()
            }
        }
    }

    private nonisolated func databaseReference(_ childPath: String? = nil) throws -> DatabaseReference {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw RemoteServiceError.noUser
        }
        
        // Base path is always under "users/<uid>/<logicalPath>"
        var ref = Database.database().reference().child("users").child(uid).child(collectionName)
        
        // Append optional child path
        if let child = childPath { ref = ref.child(child) }
        
        return ref
    }

    // MARK: - CREATE
    public func createItem(_ item: T) async throws {
        let ref = try databaseReference()
        
        // Use the item's ID instead of auto-id. id should be the same as the item.uuid 
        let itemRef = ref.child(item.id as! String)
        
        let data = try encoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            itemRef.setValue(json) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        try await readItems()
    }

    // MARK: - READ ALL
    public func readItems() async throws -> Void {
        let ref = try databaseReference()
        DispatchQueue.main.async { self.isLoading = true }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.getData { error, snapshot in
                DispatchQueue.main.async { self.isLoading = false }

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var fetchedItems: [T] = []

                if
                    let snapshot = snapshot,
                    let dict = snapshot.value as? [String: Any]
                {
                    for (key, value) in dict {
                        do {
                            guard var itemDict = value as? [String: Any] else { continue }
                            
                            // If your model has an optional `id` property, assign Firebase key
                            itemDict["id"] = key
                            
                            let data = try JSONSerialization.data(withJSONObject: itemDict)
                            let item = try self.decoder.decode(T.self, from: data)
                            fetchedItems.append(item)
                        } catch {
                            continuation.resume(throwing: RemoteServiceError.decodingError)
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.items = fetchedItems
                }

                continuation.resume(returning: ()) // always resume exactly once
            }
        }
    }
    
    // MARK: - READ ALL (PAGINATION)
    public func readItems(startingAfter lastKey: String? = nil, limit: UInt = 50) async throws {
        let ref = try databaseReference()
        var query: DatabaseQuery = ref.queryOrderedByKey().queryLimited(toFirst: limit)

        if let lastKey = lastKey {
            query = query.queryStarting(atValue: lastKey)
        }

        self.isLoading = true
        defer { self.isLoading = false }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            query.getData { error, snapshot in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var fetchedItems: [T] = []

                if let snapshot = snapshot,
                   let dict = snapshot.value as? [String: Any] {
                    for (key, value) in dict {
                        do {
                            guard var itemDict = value as? [String: Any] else { continue }
                            
                            // If your model has an optional `id` property, assign Firebase key
                            itemDict["id"] = key
                            
                            let data = try JSONSerialization.data(withJSONObject: itemDict)
                            let item = try self.decoder.decode(T.self, from: data)
                            fetchedItems.append(item)
                        } catch {
                            continuation.resume(throwing: RemoteServiceError.decodingError)
                            return
                        }
                    }
                }

                // Items should not be held by this service
                self.items = fetchedItems
                continuation.resume(returning: ())
            }
        }
    }


    // MARK: - READ SINGLE ITEM
    public func readItem(by id: T.ID) async throws -> T? {
        let ref = try databaseReference("\(id)")
        return try await withCheckedThrowingContinuation { continuation in
            ref.getData { error, snapshot in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard var itemDict = snapshot?.value as? [String: Any] else {
                    continuation.resume(throwing: RemoteServiceError.noSnapshotValue) // item not found
                    return
                }
                
                // Inject Firebase key
                itemDict["id"] = id

                do {
                    let data = try JSONSerialization.data(withJSONObject: itemDict)
                    let item = try self.decoder.decode(T.self, from: data)
                    continuation.resume(returning: item)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - UPDATE
    public func updateItem(_ item: T) async throws {
        guard let id = item.id as? String else { return }
        let ref = try databaseReference("\(id)")
        let data = try encoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data)
        
        guard let dict = json as? [AnyHashable: Any] else {
            throw RemoteServiceError.decodingError
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.updateChildValues(dict) { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        try await readItems()
    }

    // MARK: - DELETE
    public func deleteItem(_ item: T) async throws {
        guard let id = item.id as? String else { return }
        let ref = try databaseReference("\(id)")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.removeValue { error, _ in
                if let err = error {
                    continuation.resume(throwing: err)
                } else {
                    continuation.resume()
                }
            }
        }
        try await readItems()
    }

    // MARK: - DELETE ALL
    public func deleteAllItems() async throws {
        let ref = try databaseReference()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.removeValue { error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        items.removeAll()
    }
    
    /// Refresh items from the backend only if needed
    /// - Parameter force: If true, always fetch from the backend
    // MARK: - REFRESH ONLY IF NEEDED
    public func refreshItemsIfNeeded(force: Bool = false) async throws {
        // If we already have items and force is false, do nothing
        if !items.isEmpty && !force {
            return
        }
        
        // Otherwise, fetch from backend
        try await readItems()
    }
}
