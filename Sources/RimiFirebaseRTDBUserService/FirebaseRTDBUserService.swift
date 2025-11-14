//
//  UserDataContext.swift
//  Kiwi
//
//  Created by Ricardo Miron on 6/13/25.
//

import Foundation
@preconcurrency import FirebaseDatabase
import RimiDefinitions

/*
    Firebase Firestore - deals in documents and collections. Can encode/decode with codable directly.
    private let collection = Firestore.firestore().collection("users")

    Firebase Realtime Database(RTDB) - deals in references and child nodes. Requires work with [String: Any] references so
    we’ll use the toFirebaseDictionary and a decoding helper.
    private let rootRef = Database.database().reference().child("users")
 */

public final class FirebaseRTDBUserService<UserType: AppUserRepresentable>: AppUserRepository {
    public enum FirebaseRTDBUserServiceError: Error {
        case encodingFailed
        case decodingFailed
        case unknown
    }
    
    public typealias User = UserType
    
    private let rootRef: DatabaseReference
    private let profileNode: String
    
    public init(rootRef: DatabaseReference = Database.database().reference().child("users"),
         profileNode: String = "profile") {
        self.rootRef = rootRef
        self.profileNode = profileNode
    }

    // MARK: - AppUserRepository methods
    public func ensureUserExists(for appUser: AppUser) async throws -> (user: User, isNew: Bool) {
        let userRef = rootRef.child(appUser.id)
        let profileRef = userRef.child(profileNode)
        
        do {
            let snapshot = try await userRef.getValue()
            let profileSnapshot = try await profileRef.getValue()
            
            if var _ = snapshot.value as? [String: Any] {
                if let profileDict = profileSnapshot.value as? [String: Any] {
                    let data = try JSONSerialization.data(withJSONObject: profileDict)
                    let existing = try JSONDecoder().decode(User.self, from: data)
                    return (existing, false)
                } else {
                    let migratedUser = User.make(from: appUser)
                    try await profileRef.updateChildValues(toFirebaseDictionary(migratedUser))
                    return (migratedUser, false)
                }
            } else {
                let migratedUser = User.make(from: appUser)
                try await profileRef.setValue(toFirebaseDictionary(migratedUser))
                return (migratedUser, true)
            }
        } catch {
            throw error
        }
    }
    
    public func updateUser(_ user: User) async throws {
        let profileRef = rootRef.child(user.id).child(profileNode)
        do {
            let dict = try toFirebaseDictionary(user)
            try await profileRef.updateChildValues(dict)
        } catch {
            throw error
        }
    }
    
    public func deleteUser(withId id: String) async throws {
        let profileRef = rootRef.child(id)
        try await profileRef.removeValue()
    }
    
    private func toFirebaseDictionary(_ user: UserType) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(user)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FirebaseRTDBUserServiceError.encodingFailed
        }
        return dict
    }
}

// MARK: - Extensions
extension DatabaseReference {
    func getValue() async throws -> DataSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            self.observeSingleEvent(of: .value) { snapshot in
                continuation.resume(returning: snapshot)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }
}
