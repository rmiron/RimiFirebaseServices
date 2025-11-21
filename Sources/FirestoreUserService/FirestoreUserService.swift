//
//  UserDataContext 2.swift
//  Kiwi
//
//  Created by Ricardo Miron on 11/14/25.
//


import Foundation
@preconcurrency import FirebaseFirestore
import RimiDefinitions

public final class FirestoreUserService<UserType: AppUserRepresentable>: AppUserRepository {
    
    public typealias User = UserType

    private let db = Firestore.firestore()
    private let collection = "users"
    
    public init() {}
    
    // MARK: - Ensure User Exists
    public func ensureUserExists(for appUser: AppUser) async throws -> (user: User, isNew: Bool) {
        let docRef = db.collection(collection).document(appUser.id)
        
        // Try to read existing user
        if let existing = try? await docRef.getDocument(as: User.self) {
            return (existing, false)
        }
        
        // Create new user
        var newUser = User.make(from: appUser)
        try docRef.setData(from: newUser)
        return (newUser, true)
    }
    
    // MARK: - Update User
    public func updateUser(_ user: User) async throws {
        let docRef = db.collection(collection).document(user.id)
        try docRef.setData(from: user, merge: true)
    }
    
    // MARK: - Delete User
    public func deleteUser(withId id: String) async throws {
        try await db.collection(collection).document(id).delete()
    }
}
