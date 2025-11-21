//
//  DefaultImageDiskCache.swift
//  EbayTrends
//
//  Created by Ricardo Miron on 11/19/25.
//
import UIKit
import RimiDefinitions
/*
    If needed
 */
final class DefaultImageDiskCache: ImageDiskCaching {
    private let directory: URL

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(key: String) async -> UIImage? {
        let url = directory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func save(_ image: UIImage, key: String) async {
        let url = directory.appendingPathComponent(key)
        if let data = image.pngData() {
            try? data.write(to: url)
        }
    }

    func remove(key: String) async {
        let url = directory.appendingPathComponent(key)
        try? FileManager.default.removeItem(at: url)
    }
}
