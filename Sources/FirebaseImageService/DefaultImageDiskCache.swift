//
//  DefaultImageDiskCache.swift
//  EbayTrends
//
//  Created by Ricardo Miron on 11/19/25.
//
import UIKit
import RimiDefinitions
/*
    FileManager itself is thread-safe for most operations, as long as you don’t mutate the same
    directory simultaneously from multiple threads.
    - Reading a file (load) while another thread writes (save) is usually safe — the read may fail if the file is mid-write, but no crash occurs.
    - Writing to the same file concurrently could corrupt data.
 
    If you call diskCache.load/save/remove from your FirebaseImageService actor and all accesses to the same path happen through the actor, then it is safe:
    Actor guarantees single-threaded access to its state, so multiple tasks won’t call diskCache simultaneously through the actor.
    The code you have captures diskCache inside the actor, so calls like await diskCache?.remove(key:) are isolated. ✅
    Problem only arises if:
    - Multiple threads outside the actor call the same DefaultImageDiskCache instance directly.
    - You call save/remove concurrently on the same file path outside the actor.
 
    To make it fully safe even outside the actor add a queue.
 */
final class DefaultImageDiskCache: ImageDiskCaching {
    private let directory: URL // immutable → thread-safe / safe to call from a Swift actor
    private let queue = DispatchQueue(label: "com.arqive.diskcache", attributes: .concurrent) // Make it fully safe across threads


    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(key: String) async -> UIImage? {
        queue.sync {
            let url = directory.appendingPathComponent(key)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }

    func save(_ image: UIImage, key: String) async {
        let directory = self.directory // capture only the URL, not self to make it sendable
        queue.async(flags: .barrier) {
            let url = directory.appendingPathComponent(key)
            if let data = image.pngData() {
                try? data.write(to: url)
            }
        }
    }

    func remove(key: String) async {
        let directory = self.directory // capture only the URL, not self to make it sendable
        queue.async(flags: .barrier) {
            let url = directory.appendingPathComponent(key)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
