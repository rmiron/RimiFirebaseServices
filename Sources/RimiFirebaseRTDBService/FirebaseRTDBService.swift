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

/*
    THIS IS INTENDED TO WORK WITH FIREBASE REALTIME DATABASE
    PURPOSE: This service provides CRUD operations for any object in the Firebase Realtime Database.
 */


import Combine

enum RemoteServiceError: Error {
    case noUser
    case decodingError
    case noSnapshotValue
}

/*
    You cannot use a protocol with associatedtypes as a type directly because the compiler needs to know T.
    The compiler will complain:
        - Use of protocol 'FirebaseRTDBRepositoryProtocol' as a type must be written 'any FirebaseRTDBRepositoryProtocol'
    SOLUTION:
    Make the class generic over the repository
    - class AppContainer<UserRepo: AppUserRepository, ReadingRepo: FirebaseRTDBRepositoryProtocol>: ObservableObject
        where ReadingRepo.T == Reading {
 */



@MainActor
public final class FirebaseRTDBService<T: Codable & Identifiable>: ObservableObject, RepositoryManaging {

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
        let data = try encoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let childRef = ref.childByAutoId()
            childRef.setValue(json) { error, _ in
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
                    for (_, value) in dict {
                        do {
                            guard let itemDict = value as? [String: Any] else { continue }
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

    // MARK: - READ SINGLE ITEM
    public func readItem(by id: T.ID) async throws -> T? {
        let ref = try databaseReference("\(id)")
        return try await withCheckedThrowingContinuation { continuation in
            ref.getData { error, snapshot in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let value = snapshot?.value else {
                    continuation.resume(returning: nil) // item not found
                    return
                }

                do {
                    let data = try JSONSerialization.data(withJSONObject: value)
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
        try await ref.updateChildValues(json as! [AnyHashable: Any])
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
        try await ref.removeValue()
        items.removeAll()
    }
}
