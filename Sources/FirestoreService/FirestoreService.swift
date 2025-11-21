//
//  Untitled.swift
//  Kiwi
//
//  Created by Ricardo Miron on 11/14/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import RimiDefinitions

@MainActor
public final class FirestoreService<T: Codable & Identifiable>: ObservableObject, RepositoryManaging {
    @Published public private(set) var items: [T] = []
    @Published public private(set) var isLoading: Bool = false
    
    public var itemsPublisher: AnyPublisher<[T], Never> {
        $items.eraseToAnyPublisher()

    }
    public var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }

    private let db = Firestore.firestore()
    private(set) var userID: String

    /// Default collection for protocol-conforming CRUD
    private let defaultCollection: String

    public init(userID: String? = nil, defaultCollection: String) {
        self.userID = userID ?? ""
        self.defaultCollection = defaultCollection
    }
    
    private func collectionRef(_ collectionName: String) -> CollectionReference {
        if userID.isEmpty {
            return db.collection(collectionName)
        } else {
            return db.collection("users").document(userID).collection(collectionName)
        }
    }
    
    func setUserID(_ userID: String) {
        self.userID = userID
    }

    private func defaultCollectionRef() -> CollectionReference {
        collectionRef(defaultCollection)
    }
    
    // MARK: - RepositoryManaging protocol conformance
    public func createItem(_ item: T) async throws {
        let ref = defaultCollectionRef().document(item.id as! String)
        try ref.setData(from: item)
        try await readItems()
    }

    public func readItems() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let snapshot = try await defaultCollectionRef().getDocuments()
        items = snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    public func readItem(by id: T.ID) async throws -> T? {
        let doc = try await defaultCollectionRef().document(id as! String).getDocument()
        return try doc.data(as: T.self)
    }

    public func updateItem(_ item: T) async throws {
        let ref = defaultCollectionRef().document(item.id as! String)
        try ref.setData(from: item, merge: true)
        try await readItems()
    }

    public func deleteItem(_ item: T) async throws {
        try await defaultCollectionRef().document(item.id as! String).delete()
        try await readItems()
    }

    public func deleteAllItems() async throws {
        let snapshot = try await defaultCollectionRef().getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
        items.removeAll()
    }

    public func readItems(startingAfter lastKey: String? = nil, limit: UInt = 50) async throws {
        var query: Query = defaultCollectionRef().limit(to: Int(limit))
        if let lastKey = lastKey {
            query = query.start(at: [lastKey])
        }
        isLoading = true
        defer { isLoading = false }
        
        let snapshot = try await query.getDocuments()
        items = snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }

    public func refreshItemsIfNeeded(force: Bool = false) async throws {
        if !items.isEmpty && !force { return }
        try await readItems()
    }
    
    // MARK: - Optional: dynamic collection methods
    public func createItem(_ item: T, inCollection collectionName: String) async throws {
        let ref = collectionRef(collectionName).document(item.id as! String)
        try ref.setData(from: item)
    }

    public func readItems(inCollection collectionName: String) async throws -> [T] {
        let snapshot = try await collectionRef(collectionName).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: T.self) }
    }
}
