//
//  Shapefile.swift
//  ShapefileKit
//
//  Created by Eddie Craig on 08/03/2019.
//  Copyright © 2019 Box Farm Studios. All rights reserved.
//

import Foundation
import MapKit

public enum ShapefileError: Error {
    case parseError
}

public class Shapefile {
    
    private let shp: SHPFile
    private let dbf: DBFFile
    private let shx: SHXFile
    
    public var shapeType: Shape.ShapeType { return dbf.shapeType }
    public let fileName: String
    public var lastUpdate: Date { return dbf.lastUpdate }
    public var boundingMapRect: MKMapRect { return shp.boundingMapRect }
    public var shapes = [Shape]()
    
    public init(path: URL) throws {
        let baseURL = path.deletingPathExtension()
        self.fileName = baseURL.lastPathComponent
        
        self.shp = try SHPFile(path: baseURL.appendingPathExtension(SHPFile.pathExtension))
        self.dbf = try DBFFile(path: baseURL.appendingPathExtension(DBFFile.pathExtension))
        self.shx = try SHXFile(path: baseURL.appendingPathExtension(SHXFile.pathExtension))
    }
    
    private var isLoaded = false
    
    public func loadShapes() {
        guard !isLoaded else { return }
        isLoaded = true
        for i in 0 ..< shx.shapeCount {
            do {
                guard let shape = try shp.shapeAtOffset(shx.shapeOffsets[i]) else { throw ShapefileError.parseError }
                let record = try dbf.recordAtIndex(i)
                shape.info = Dictionary.init(uniqueKeysWithValues: zip(dbf.fields.map{$0.name}, record))
                shapes.append(shape)
            }
            catch {
                print(error)
                continue
            }
        }
    }
    
}
