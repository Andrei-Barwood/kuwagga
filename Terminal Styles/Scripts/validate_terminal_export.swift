#!/usr/bin/env swift
import AppKit
import Foundation

// Inline minimal validation of .terminal export for CI/manual checks.
func archivedColor(r: Int, g: Int, b: Int) throws -> Data {
    let color = NSColor(calibratedRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    return try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
}

let template = "/System/Applications/Utilities/Terminal.app/Contents/Resources/Initial Settings/Grass.terminal"
var format = PropertyListSerialization.PropertyListFormat.xml
let data = try Data(contentsOf: URL(fileURLWithPath: template))
var profile = try PropertyListSerialization.propertyList(from: data, options: [], format: &format) as! [String: Any]

profile["name"] = "Remar Nocturna"
profile["BackgroundColor"] = try archivedColor(r: 0x12, g: 0x16, b: 0x2C)
profile["TextColor"] = try archivedColor(r: 0x36, g: 0x3E, b: 0x7A)
profile["CursorColor"] = try archivedColor(r: 0x09, g: 0x0E, b: 0x1D)
profile["ANSIRedColor"] = try archivedColor(r: 0x84, g: 0x4F, b: 0xDE)

let out = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Remar_Nocturna.terminal")
let plist = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
try plist.write(to: out)
print("OK:", out.path)