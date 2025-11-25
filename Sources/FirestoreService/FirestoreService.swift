//
//  Untitled.swift
//  Kiwi
//
//  Created by Ricardo Miron on 11/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
//import Combine
import RimiDefinitions

/*
    Do not make into a singleton since we want to swap Firestore instances for different collections
    let userService = FirestoreService(userID: "user123", defaultCollection: "cards")
    let adminService = FirestoreService(userID: "admin", defaultCollection: "logs")
 */

public final class FirestoreService<T: Codable & Identifiable>: RemoteDataManaging {
    private let db = Firestore.firestore()
    private(set) var userID: String
    private let defaultCollection: String

    public init(userID: String? = nil, defaultCollection: String) {
        self.userID = userID ?? ""
        self.defaultCollection = defaultCollection
    }

    // MARK: - Collection References
    private func collectionRef(_ collectionName: String) -> CollectionReference {
        if userID.isEmpty {
            return db.collection(collectionName)
        } else {
            return db.collection("users").document(userID).collection(collectionName)
        }
    }

    private func defaultCollectionRef() -> CollectionReference {
        collectionRef(defaultCollection)
    }

    public func setUserID(_ userID: String) {
        self.userID = userID
    }

    // MARK: - CRUD Operations

    public func createItem(_ item: T, inCollection collectionName: String? = nil) async throws {
        let ref = (collectionName != nil ? collectionRef(collectionName!) : defaultCollectionRef())
            .document(item.id as! String)
        try ref.setData(from: item)
    }

    public func readItem(by id: T.ID, inCollection collectionName: String? = nil) async throws -> T? {
        let doc = try await (collectionName != nil ? collectionRef(collectionName!) : defaultCollectionRef())
            .document(id as! String)
            .getDocument()
        return try doc.data(as: T.self)
    }

    public func updateItem(_ item: T, inCollection collectionName: String? = nil) async throws {
        let ref = (collectionName != nil ? collectionRef(collectionName!) : defaultCollectionRef())
            .document(item.id as! String)
        try ref.setData(from: item, merge: true)
    }

    public func deleteItem(_ item: T, inCollection collectionName: String? = nil) async throws {
        let ref = (collectionName != nil ? collectionRef(collectionName!) : defaultCollectionRef())
            .document(item.id as! String)
        try await ref.delete()
    }

    public func deleteAllItems(inCollection collectionName: String? = nil) async throws {
        let snapshot = try await (collectionName != nil ? collectionRef(collectionName!) : defaultCollectionRef())
            .getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }

    // MARK: - Pagination using a key (document ID)
    public func readItems(
        startingAfter lastKey: String? = nil,
        limit: UInt = 50,
        inCollection collectionName: String? = nil
    ) async throws -> [T] {
        var query: Query = (collectionName != nil ? collectionRef(collectionName!) : defaultCollectionRef())
                    .limit(to: Int(limit))
        if let lastKey = lastKey, !lastKey.isEmpty {
            let lastDoc = try await (collectionName != nil ? collectionRef(collectionName!) : defaultCollectionRef())
                .document(lastKey)
                .getDocument()
            if lastDoc.exists {
                query = query.start(afterDocument: lastDoc)
            }
        }
        
        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }
}
