//
//  DataExporter.swift
//  MaLiang
//
//  Created by Harley-xk on 2019/4/23.
//

import Foundation
import CoreGraphics

/// class to export canvas data to disk
open class DataExporter {
    
    // MARK: - Saving
    
    /// create documents from specified canvas
    public init(canvas: Canvas) {
        let data = canvas.data
        content = CanvasContent(lineStrips: data?.elements.compactMap { $0 as? LineStrip } ?? [],
                                 chartlets: [])
        textures = canvas.textures
    }
    
    private var content: CanvasContent
    private var textures: [MLTexture]

    /// Save contents to disk
    ///
    /// - Parameters:
    ///   - directory: the folder where to place all datas
    /// - Throws: error while saving
    public func save(to directory: URL, progress: ProgressHandler? = nil, result: ResultHandler? = nil) {
        DispatchQueue(label: "com.maliang.saving").async {
            do {
                try self.saveSynchronously(to: directory, progress: progress)
                DispatchQueue.main.async {
                    result?(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    result?(.failure(error))
                }
            }
        }
    }
    
    open func saveSynchronously(to directory: URL, progress: ProgressHandler?) throws {
        /// make sure the directory is empty
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
        guard contents.count <= 0 else {
            throw MLError.directoryNotEmpty(directory)
        }
        
        // move on progress to 0.01 when passed directory check
        reportProgress(0.01, on: progress)
        
        let encoder = JSONEncoder()
        
        /// save document info
        var info = DocumentInfo.default
        info.lines = content.lineStrips.count
        info.chartlets = content.chartlets.count
        let infoData = try encoder.encode(info)
        try infoData.write(to: directory.appendingPathComponent("info"))
        
        // move on progress to 0.02 when info file saved
        reportProgress(0.02, on: progress)

        /// save vector datas to json file
        let contentData = try JSONEncoder().encode(content)
        try contentData.write(to: directory.appendingPathComponent("content"))
        
        // move on progress to 0.1 when contents file saved
        reportProgress(0.1, on: progress)

        /// save textures to folder
        // only chartlet textures will be saved
        let chartletTextureIDs = content.chartlets.map { $0.textureID }
        let idSet = Set<UUID>(chartletTextureIDs)
        let pendingTextures = textures.compactMap { idSet.contains($0.id) ? $0 : nil }
        
        for i in 0 ..< pendingTextures.count {
            let mlTexture = textures[i]
            try mlTexture.texture.toData()?.write(to: directory.appendingPathComponent("textures").appendingPathComponent(mlTexture.id.uuidString))
            // move on progress to 0.1 when contents file saved
            reportProgress(base: 0.1, unit: i, total: textures.count, on: progress)
        }
        
        reportProgress(1, on: progress)
    }
}
