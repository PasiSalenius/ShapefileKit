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
    private let cpg: CPGFile

    public var shapeType: Shape.ShapeType { return dbf.shapeType }
    public let fileName: String
    public var lastUpdate: Date { return dbf.lastUpdate }
    public var boundingMapRect: MKMapRect { return shp.boundingMapRect }
    public var shapes = [Shape]()
    
    public init(url: URL) throws {
        let baseURL = url.deletingPathExtension()
        self.fileName = baseURL.lastPathComponent
        
        self.cpg = try CPGFile(url: baseURL.appendingPathExtension(CPGFile.pathExtension))
        self.shp = try SHPFile(url: baseURL.appendingPathExtension(SHPFile.pathExtension))
        self.dbf = try DBFFile(url: baseURL.appendingPathExtension(DBFFile.pathExtension), encoding: self.cpg.encoding)
        self.shx = try SHXFile(url: baseURL.appendingPathExtension(SHXFile.pathExtension))
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
