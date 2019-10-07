//
//  Glyph.swift
//  
//
//  Created by Dave DeLong on 8/16/19.
//

import Foundation
import SPMUtility

struct Glyph {
    
    enum Size: String, CaseIterable, ArgumentKind {
        
        init(argument: String) throws {
            guard let s = Size(rawValue: argument) else {
                throw ArgumentConversionError.custom("Unknown symbol size '\(argument)'")
            }
            self = s
        }
        
        static var completion: ShellCompletion {
            return .values(allCases.map { (value: $0.rawValue, description: $0.rawValue) })
        }
        
        case small
        case medium
        case large
    }
    
    enum Element {
        case move(CGPoint)
        case line(CGPoint)
        case quadCurve(CGPoint, CGPoint)
        case curve(CGPoint, CGPoint, CGPoint)
        case close
    }
    
    private let font: CTFont
    private let originOffset: CGPoint
    private let glyph: CGGlyph
    
    let cgPath: CGPath
    
    let identifierName: String
    let fullName: String
    
    let boundingBox: CGRect
    let allowsMirroring: Bool
    let restrictionNote: String?
    
    
    init?(size: Size, pieces: Array<String>, inFont font: CTFont) {
        guard pieces.count == 12 else { return nil }
        let name = "uni\(pieces[3]).\(size.rawValue)"
        var glyph = CTFontGetGlyphWithName(font, name as CFString)
        if glyph == 0 { return nil }
        
        self.font = font
        self.glyph = glyph
        
        var box = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .default, &glyph, &box, 1)
        let paddedBox: CGRect
        let paddedBoxMultiplier: CGFloat = box.origin.y > 0 ? 2 : -2
        paddedBox = CGRect(x: 0, y: 0, width: box.width + (2 * box.origin.x), height: box.height + (paddedBoxMultiplier * box.origin.y))
        
        self.boundingBox = paddedBox
        self.originOffset = box.origin
        
        let path = CTFontCreatePathForGlyph(font, glyph, nil)
        
        let copy: CGPath?
        if box.origin.y > 0 {
          copy = path
        } else {
          var transform = CGAffineTransform(translationX: 0, y: -2 * originOffset.y)
          copy = path?.copy(using: &transform)
        }
        self.cgPath = copy ?? CGPath(rect: CGRect(origin: .zero, size: paddedBox.size), transform: nil)
        
        self.fullName = pieces[10]
        self.identifierName = "symbol" + fullName.components(separatedBy: ".").map { $0.capitalized }.joined()
        self.allowsMirroring = Bool(pieces[6] != "")
        
        if pieces[5].isEmpty == true {
            self.restrictionNote = nil
        } else {
            self.restrictionNote = pieces[5]
        }
    }
    
    func enumerateElements(enumerator: (CGPoint?, Element) -> Void) {
        
        var currentPoint: CGPoint?
        cgPath.applyWithBlock { elementRef in
            let pathElement = elementRef.pointee
            
            let points = [
                pathElement.points[0],
                pathElement.points[1],
                pathElement.points[2]
            ]
            
            let element: Element
            let newCurrentPoint: CGPoint?
            
            switch pathElement.type {
                case .moveToPoint:
                    element = .move(points[0])
                    newCurrentPoint = points[0]
                
                case .addLineToPoint:
                    element = .line(points[0])
                    newCurrentPoint = points[0]
                
                case .addQuadCurveToPoint:
                    element = .quadCurve(points[0], points[1])
                    newCurrentPoint = points[0]
                
                case .addCurveToPoint:
                    element = .curve(points[0], points[1], points[2])
                    newCurrentPoint = points[0]
                
                case .closeSubpath:
                    element = .close
                    newCurrentPoint = nil
                
                @unknown default: return
            }
            
            enumerator(currentPoint, element)
            currentPoint = newCurrentPoint
        }
    }
    
}
