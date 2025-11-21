//
//  FirebaseImageService.swift
//  EbayTrends
//
//  Created by Ricardo Miron on 11/19/25.
//

import FirebaseStorage
import UIKit
import RimiDefinitions

/*
    actor for service ensures no race conditions.
 
    Why FirebaseImageService Should Be a Singleton
    1. You want a single shared cache
    Your service holds:
    NSCache for images
    ongoingTasks dictionary to avoid duplicate fetches
    possibly a disk cache later
    
    Alternatively, if you create multiple service instances:
    Each one has its own cache → no shared memory cache
    Duplicate downloads → waste bandwidth
    Duplicate decodes → waste CPU
    No coordination of cancellation
    A singleton ensures all parts of your app share the same cache and same in-flight task registry.
 
    2. Image fetching is a cross-cutting concern
    Image fetching is not domain-specific; it’s infrastructure.
    Infrastructure services should be shared globally rather than instanced per feature/module.
 
    3. The service is an actor
    Since it’s an actor, you’re guaranteed thread safety — but only inside a single instance.
    If you have multiple actors:
    Their states are independent
    Their caches do not synchronize
    Two lists scrolling in parallel may fetch the same image twice
    You lose the whole benefit of using an actor for synchronization.
 
    4. Single point of task cancellation
    If each feature created its own service:
    Cancelling a fetch in a row wouldn't stop the task started by another instance
    Memory bloat increases because each instance tracks tasks separately
    Singleton solves this cleanly.
 */

public actor FirebaseImageService: ImageFetching {
    
    static let shared = FirebaseImageService(diskCache: ImageDiskCaching())
    static let memoryOnly = FirebaseImageService(diskCache: nil)
    
    private init(diskCache: ImageDiskCaching?) {
        self.diskCache = diskCache
    }

    private var ongoingTasks: [String: Task<UIImage, Error>] = [:]
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCache: ImageDiskCaching?
    
    /// Upload an image to Firebase Storage at a specific path.
    /// Optionally overwrites existing data at that path.
    /// let path = "users/\(userID)/profile.png"
    func uploadImage(_ image: UIImage, to path: String) async throws -> URL {
        guard let data = image.pngData() else {
            throw NSError(domain: "FirebaseImageService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to convert UIImage to PNG"])
        }
        
        let ref = Storage.storage().reference(withPath: path)
        let _ = try await ref.putDataAsync(data, metadata: nil)
        let url = try await ref.downloadURL()
        print("Image is available at: \(url.absoluteString)")
        
        // Optional: clear cache so next fetch returns fresh image
        memoryCache.removeObject(forKey: path as NSString)
        await diskCache?.remove(key: path)
        ongoingTasks[path]?.cancel()
        ongoingTasks[path] = nil
        
        return url
    }

    func fetchImage(path: String) async throws -> UIImage {
        // If its in memory return it
        if let cached = memoryCache.object(forKey: path as NSString) {
            return cached
        }
        
        // If we have a disk cache and image exists, store it in memory and return it
        if let diskCache, let diskImage = await diskCache.load(key: path) {
            memoryCache.setObject(diskImage, forKey: path as NSString)
            return diskImage
        }
        
        // Is there a task fetching it? Continue it
        if let task = ongoingTasks[path] {
            return try await task.value
        }
        
        // If we reach this point then get it from Firebase
        let task = Task { () throws -> UIImage in
            defer { ongoingTasks[path] = nil }
            
            let ref = Storage.storage().reference(withPath: path)
            let data = try await ref.data(maxSize: 8 * 1024 * 1024)
            
            guard let uiImage = UIImage(data: data) else {
                throw NSError(domain: "FirebaseImageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
            }
            
            memoryCache.setObject(uiImage, forKey: path as NSString)
            if let diskCache { await diskCache.save(uiImage, key: path) }
            
            return uiImage
        }
        
        ongoingTasks[path] = task
        return try await task.value
    }
    
    /// Replace an existing image at the given path with a new UIImage.
    /// Uploads to Firebase Storage, clears caches, and fetches the updated image.
    func replaceImage(at path: String, with newImage: UIImage) async throws -> UIImage {
        try await uploadImage(newImage, to: path)
        return try await fetchImage(path: path)
    }

    func cancelFetch(for path: String) async {
        ongoingTasks[path]?.cancel()
        ongoingTasks[path] = nil
    }
    
    func cancelAll() async {
        for (_, task) in ongoingTasks {
            task.cancel()
        }
        ongoingTasks.removeAll()
    }
    
    private func removeTask(for path: String) async {
        ongoingTasks[path] = nil
    }
}
