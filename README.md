
# RimiFirebaseServices

**RimiFirebaseServices** is a Swift Package that provides a clean and modular abstraction layer for interacting with Firebase.  
It defines a common set of protocols for performing CRUD operations on remote data, allowing any model type to seamlessly integrate with Firebase without exposing Firebase-specific logic to higher layers of your app.

---

## 🔧 Architecture

This package follows a **Repository pattern** that separates data access logic from application logic.  
You can define any model conforming to your data protocol (e.g. `Identifiable`, `Codable`) and the repository handles:

- Creating new records  
- Reading all or filtered records  
- Updating existing records  
- Deleting records  

By abstracting Firebase behind these protocols, your app remains testable, decoupled, and easy to extend with new backends in the future.

---

## 🧱 Example Usage

```swift
// Define your model
struct SportsCard: Identifiable, Codable {
    var id: String
    var player: String
    var year: Int
    var set: String
}

// Create a repository
let repository = FirebaseRepository<SportsCard>(collectionName: "cards")

// Perform CRUD operations
Task {
    try await repository.createItem(SportsCard(id: "123", player: "LeBron James", year: 2003, set: "Topps Chrome"))
    let allCards = try await repository.readAll()
}

## FirebaseRTDBUserService

`FirebaseRTDBUserService` is a generic service class that bridges your app’s authentication layer (`AppUser`) with your app-specific user representation (`AppUserRepresentable`).  

It provides full CRUD operations on the `AppUserRepresentable` type in Firebase Realtime Database and ensures that each user has a corresponding profile stored in the database.  

### Key Features

- **Generic User Handling**: Works with any type conforming to `AppUserRepresentable`, allowing each app to define its own user model with app-specific fields.  
- **Automatic User Creation**: Checks if an `AppUserRepresentable` exists for a given `AppUser`. If not, it automatically creates a new instance.  
- **CRUD Operations**: Supports creating, reading, updating, and deleting users from Firebase Realtime Database.  
- **Firebase Mapping**: Converts `AppUserRepresentable` instances to a Firebase-compatible dictionary format for storage.  

### Usage

This service is ideal for apps that need to maintain a persistent, app-specific user profile in Firebase RTDB while leveraging Firebase Authentication for identity management.  

