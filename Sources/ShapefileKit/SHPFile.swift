//
//  SHPFile.swift
//  ShapefileKit
//
//  Created by Eddie Craig on 10/03/2019.
//  Copyright © 2019 Box Farm Studios. All rights reserved.
//

import Foundation
import MapKit

public enum SHPFileError: Error {
    case parseError
}

class SHPFile {
    
    static let pathExtension = "shp"
    
    private var fileHandle: FileHandle
    private(set) var shapeType: Shape.ShapeType
    private(set) var boundingMapRect: MKMapRect
    private(set) var elevation: Range<Double>
    private var measure: Range<Double>
    private var shpLength: UInt64
    
    init(url: URL) throws {
        self.fileHandle = try FileHandle(forReadingFrom: url)
        fileHandle.seek(toFileOffset: 24)
        
        let l = try unpack(">i", fileHandle.readData(ofLength: 4))
        guard let int = l[0] as? Int else { throw SHPFileError.parseError }
        self.shpLength = UInt64(int * 2)
        
        let a = try unpack("<ii", fileHandle.readData(ofLength: 8))
        //let version = a[0] as! Int
        guard let shapeTypeInt = a[1] as? Int else { throw SHPFileError.parseError }
        self.shapeType = Shape.ShapeType(rawValue: shapeTypeInt) ?? .nullShape
        
        let b = try unpack("<4d", fileHandle.readData(ofLength: 32)).compactMap { $0 as? Double }
        guard b.count > 3 else { throw SHPFileError.parseError }
        let origin = MKMapPoint(CLLocationCoordinate2D(latitude: b[3], longitude: b[0]))
        let end = MKMapPoint(CLLocationCoordinate2D(latitude: b[1], longitude: b[2]))
        self.boundingMapRect = MKMapRect(x: origin.x, y: origin.y, width: end.x-origin.x, height: end.y-origin.y)
        
        let c = try unpack("<4d", fileHandle.readData(ofLength: 32)).compactMap { $0 as? Double }
        guard c.count > 3 else { throw SHPFileError.parseError }
        self.elevation = Range<Double>(uncheckedBounds: (c[0], c[1]))
        self.measure = Range<Double>(uncheckedBounds: (c[2], c[3]))
        
        // don't trust length declared in shp header
        fileHandle.seekToEndOfFile()
        let length = fileHandle.offsetInFile
        
        if length != self.shpLength {
            print("-- actual shp length \(length) != length in headers \(self.shpLength) -> use the actual one")
            self.shpLength = length
        }
    }
    
    deinit {
        self.fileHandle.closeFile()
    }
    
    func shapeAtOffset(_ offset:UInt64) throws -> Shape? {
        if offset == shpLength { return nil }
        assert(offset < shpLength, "trying to read shape at offset \(offset), but shpLength is only \(shpLength)")
        
        var nParts = 0
        var nPoints = 0
        
        fileHandle.seek(toFileOffset: offset + 8) //+8 skips reading header as it is not needed
        
        guard let shapeTypeInt = try unpack("<i", fileHandle.readData(ofLength: 4))[0] as? Int else { throw SHPFileError.parseError }
        
        guard let shapeType = Shape.ShapeType(rawValue: shapeTypeInt) else { throw SHPFileError.parseError }
        let shape = Shape(type: shapeType)
        
        if shapeType.hasBoundingBox {
            let a = try unpack("<4d", fileHandle.readData(ofLength: 32)).compactMap { $0 as? Double }
            guard a.count > 3 else { throw SHPFileError.parseError }
            let origin = MKMapPoint(CLLocationCoordinate2D(latitude: a[3], longitude: a[0]))
            let end = MKMapPoint(CLLocationCoordinate2D(latitude: a[1], longitude: a[2]))
            shape.boundingBox = MKMapRect(x: origin.x, y: origin.y, width: end.x-origin.x, height: end.y-origin.y)
        }
        
        if shapeType.hasParts {
            guard let int = try unpack("<i", fileHandle.readData(ofLength: 4))[0] as? Int else { throw SHPFileError.parseError }
            nParts = int
        }
        
        if shapeType.hasPoints {
            guard let int = try unpack("<i", fileHandle.readData(ofLength: 4))[0] as? Int else { throw SHPFileError.parseError }
            nPoints = int
        }
        
        if nParts > 0 {
            shape.parts = try unpack("<\(nParts)i", fileHandle.readData(ofLength: nParts * 4)).compactMap { $0 as? Int }
        }
        
        if shapeType == .multipatch {
            shape.partTypes = try unpack("<\(nParts)i", fileHandle.readData(ofLength: nParts * 4)).compactMap { $0 as? Int }
        }
        
        shape.coordinates.removeAll()
        for _ in 0 ..< nPoints {
            let points = try unpack("<2d", fileHandle.readData(ofLength: 16)).compactMap { $0 as? Double }
            guard points.count > 1 else { throw SHPFileError.parseError }
            shape.coordinates.append(CLLocationCoordinate2D(latitude: points[1], longitude: points[0]))
        }
        
        if shapeType.hasZValues {
            let a = try unpack("<2d", fileHandle.readData(ofLength: 16)).compactMap { $0 as? Double }
            guard a.count > 1 else { throw SHPFileError.parseError }
            let zmin = a[0]
            let zmax = a[1]
            print("zmin: \(zmin), zmax: \(zmax)")
            
            let doubles = try unpack("<\(nPoints)d", fileHandle.readData(ofLength: nPoints * 8)).compactMap { $0 as? Double }
            guard doubles.count > 0 else { throw SHPFileError.parseError }
            shape.z = doubles[0]
        }
        
        if shapeType.hasMValues && self.measure.lowerBound != 0.0 && self.measure.upperBound != 0.0 {
            let a = try unpack("<2d", fileHandle.readData(ofLength: 16)).compactMap { $0 as? Double }
            guard a.count > 1 else { throw SHPFileError.parseError }
            let mmin = a[0]
            let mmax = a[1]
            print("mmin: \(mmin), mmax: \(mmax)")
            
            // Spec: Any floating point number smaller than –10e38 is considered by a shapefile reader to represent a "no data" value.
            shape.m = []
            for m in try unpack("<\(nPoints)d", fileHandle.readData(ofLength: nPoints * 8)).compactMap({ $0 as? Double }) {
                shape.m.append(m < -10e38 ? nil : m)
            }
        }
        
        if shapeType.hasSinglePoint {
            let point = try unpack("<2d", fileHandle.readData(ofLength: 16)).compactMap { $0 as? Double }
            guard point.count > 1 else { throw SHPFileError.parseError }
            shape.boundingBox = MKMapRect(origin: MKMapPoint(CLLocationCoordinate2D(latitude: point[1], longitude: point[0])), size: MKMapSize(width: 0, height: 0))
        }
        
        if shapeType.hasSingleZ {
            let doubles = try unpack("<d", fileHandle.readData(ofLength: 8)).compactMap { $0 as? Double }
            guard doubles.count > 0 else { throw SHPFileError.parseError }
            shape.z = doubles[0]
        }
        
        if shapeType.hasSingleM {
            let a = try unpack("<d", fileHandle.readData(ofLength: 8)).compactMap { $0 as? Double }
            guard a.count > 0 else { throw SHPFileError.parseError }
            let m = a[0] < -10e38 ? nil : a[0]
            shape.m = [m]
        }
        
        return shape
    }
    
}
