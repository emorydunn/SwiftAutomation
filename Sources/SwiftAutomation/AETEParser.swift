//
//  AETEParser.swift
//  SwiftAutomation
//
//

// TO DO: check endianness in read data methods
// TO DO: when is this still needed? (e.g. remote AEs)

#if canImport(Carbon)
import Carbon
#endif

import Foundation
import AppleEvents


/**********************************************************************/


public class AETEParser: ApplicationTerminology {
    
    public private(set) var types: [KeywordTerm] = []
    public private(set) var enumerators: [KeywordTerm] = []
    public private(set) var properties: [KeywordTerm] = []
    public private(set) var elements: [ClassTerm] = []
    public var commands: [CommandTerm] { return Array(self.commandsDict.values) }
    
    private var commandsDict = [String:CommandTerm]()
    private let keywordConverter: KeywordConverterProtocol
    
    // following are used in parse() to supply 'missing' singular/plural class names
    private var classDefinitionsByCode = [UInt32:ClassTerm]()
    
    private var aeteData: Data = Data()
    private var aeteSize: Int = 0
    private var cursor: Int = 0
    
    
    public init(keywordConverter: KeywordConverterProtocol = defaultSwiftKeywordConverter) {
        self.keywordConverter = keywordConverter
    }
    
    public func parse(_ desc: Descriptor) throws { // accepts AETE/AEUT, or AEList of AETE/AEUTs; this takes ownership
        switch desc.type {
        case OSType(typeAETE), OSType(typeAEUT):
            self.aeteSize = desc.data.count
            self.aeteData = desc.data
            self.cursor = 6 // skip version, language, script integers
            let n = self.short()
            do {
                for _ in 0..<n {
                    try self.parseSuite()
                }
                /* singular names are normally used in the classes table and plural names in the elements table. However, if an aete defines a singular name but not a plural name then the missing plural name is substituted with the singular name; and vice-versa if there's no singular equivalent for a plural name.
                */
                for var elementTerm in self.classDefinitionsByCode.values {
                    if elementTerm.singular == "" {
                        elementTerm = ClassTerm(singular: elementTerm.plural, plural: elementTerm.plural, code: elementTerm.code)
                    } else if elementTerm.plural == "" {
                        elementTerm = ClassTerm(singular: elementTerm.singular, plural: elementTerm.singular, code: elementTerm.code)
                    }
                    self.elements.append(elementTerm)
                    self.types.append(elementTerm)
                }
                self.classDefinitionsByCode.removeAll()
            } catch {
                throw TerminologyError("An error occurred while parsing AETE. \(error)")
            }
        case typeAEList:
            for item in (desc as! ListDescriptor) {
                try self.parse(item)
            }
        default:
            throw TerminologyError("An error occurred while parsing AETE. Unsupported descriptor type: \(literalFourCharCode(desc.type))")
        }
    }
    
    public func parse(_ descriptors: [Descriptor]) throws {
        for descriptor in descriptors {
            try self.parse(descriptor)
        }
    }
    
    // internal callbacks
    
    // read data methods
    
    private func readInteger<T: FixedWidthInteger>() -> T {
        let size = MemoryLayout<T>.size
        let value: T = try! decodeFixedWidthInteger(self.aeteData[self.cursor..<(self.cursor+size)])
        self.cursor += size
        return value
    }
    
    private func byte() -> UInt8 {
        return self.readInteger()
    }
    
    private func short() -> UInt16 { // unsigned short (2 bytes)
        return self.readInteger()
    }
    
    private func code() -> OSType { // (4 bytes)
        return self.readInteger() // confirm alignment isn't an issue
        /*
        // can't use aeteData.load() to read OSType as that requires correct 4-byte alignment, but aete is 2-byte…
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<OSType>.size,
                                                      alignment: MemoryLayout<OSType>.alignment)
        defer { buffer.deallocate() }
        // …so copy the raw 4-byte sequence to a new temporary buffer that is aligned to hold OSType, and read that
        buffer.copyMemory(from: self.aeteData.advanced(by: self.cursor), byteCount: MemoryLayout<OSType>.size)
        self.cursor += MemoryLayout<OSType>.size
        return buffer.bindMemory(to: OSType.self, capacity: 1).pointee
     */
    }
    
    private func string() -> String { // Pascal string (first byte indicates length, followed by 0-255 MacRoman chars)
        let size = Int(self.byte())
        if size > 0 {
            let result = String(data: self.aeteData[self.cursor..<(self.cursor+size)], encoding: .macOSRoman)!
            self.cursor += size
            return result
        } else {
            return ""
        }
    }
    
    // skip unneeded aete data
    
    private func skipShort() {
        self.cursor += MemoryLayout<UInt16>.size
    }
    private func skipCode() {
        self.cursor += MemoryLayout<OSType>.size
    }
    private func skipString() {
        self.cursor += Int(self.byte())
    }
    private func alignCursor() { // realign aete data cursor on even byte after reading strings
        if self.cursor % 2 != 0 {
            self.cursor += 1
        }
    }
    
    // perform a bounds check on aete data cursor to protect against malformed aete data
    
    private func checkCursor() throws {
        if cursor > self.aeteSize {
            throw TerminologyError("The AETE ended prematurely: (self.aeteData.length) bytes expected, (self.cursor) bytes read.")
        }
    }
    
    
    // Parse methods
    
    func parseCommand() throws {
        let name = self.keywordConverter.convertSpecifierName(self.string())
        self.skipString()   // description
        self.alignCursor()
        let classCode = self.code()
        let code = self.code()
        // skip result
        self.skipCode()     // datatype
        self.skipString()   // description
        self.alignCursor()
        self.skipShort()    // flags
        // skip direct parameter
        self.skipCode()     // datatype
        self.skipString()   // description
        self.alignCursor()
        self.skipShort()    // flags
        // parse keyword parameters
        /* Note: overlapping command definitions (e.g. InDesign) should be processed as follows:
        - If their names and codes are the same, only the last definition is used; other definitions are ignored and will not compile.
        - If their names are the same but their codes are different, only the first definition is used; other definitions are ignored and will not compile.
        - If a dictionary-defined command has the same name but different code to a built-in definition, escape its name so it doesn't conflict with the default built-in definition.
        */
        var parameters = [KeywordTerm]()
        let n = self.short()
        for _ in 0..<n {
            let paramName = self.string()
            self.alignCursor()
            let paramCode = self.code()
            self.skipCode()     // datatype
            self.skipString()   // description
            self.alignCursor()
            self.skipShort()    // flags
            parameters.append(KeywordTerm(name: self.keywordConverter.convertParameterName(paramName), code: paramCode))
            try self.checkCursor()
        }
        let commandDef = CommandTerm(name: name, event: eventIdentifier(classCode, code), parameters: parameters)
        let otherCommandDef: CommandTerm! = self.commandsDict[name]
        if otherCommandDef == nil || (commandDef.event == otherCommandDef.event) {
            self.commandsDict[name] = commandDef
        }
    }
    
    
    func parseClass() throws {
        var isPlural = false
        let className = self.keywordConverter.convertSpecifierName(self.string())
        self.alignCursor()
        let classCode = self.code()
        self.skipString()   // description
        self.alignCursor()
        // properties
        let n = self.short()
        for _ in 0..<n {
            let propertyName = self.keywordConverter.convertSpecifierName(self.string())
            self.alignCursor()
            let propertyCode = self.code()
            self.skipCode()     // datatype
            self.skipString()   // description
            self.alignCursor()
            let flags = self.short()
            if propertyCode != kAEInheritedProperties { // it's a normal property definition, not a superclass  definition
                let propertyDef = KeywordTerm(name: propertyName, code: propertyCode)
                if (flags % 2 != 0) { // class name is plural
                    isPlural = true
                } else if !properties.contains(propertyDef) { // add to list of property definitions
                    self.properties.append(propertyDef)
                }
            }
            try self.checkCursor()
        }
        // skip elements
        let n2 = self.short()
        for _ in 0..<n2 {
            self.skipCode()         // code
            let m = self.short()    // number of reference forms
            self.cursor += 4 * Int(m)
            try self.checkCursor()
        }
        // add either singular (class) or plural (element) name definition
        let elementDef: ClassTerm
        let oldDef = self.classDefinitionsByCode[classCode]
        if isPlural {
            elementDef = ClassTerm(singular: oldDef?.singular ?? "", plural: className, code: classCode)
        } else {
            elementDef = ClassTerm(singular: className, plural: oldDef?.plural ?? "", code: classCode)
        }
        self.classDefinitionsByCode[classCode] = elementDef
    }
    
    func parseComparison() throws {  // comparison info isn't used
        self.skipString()   // name
        self.alignCursor()
        self.skipCode()     // code
        self.skipString()   // description
        self.alignCursor()
    }
    
    func parseEnumeration() throws {
        self.skipCode()         // code
        let n = self.short()
        // enumerators
        for _ in 0..<n {
            let name = self.keywordConverter.convertSpecifierName(self.string())
            self.alignCursor()
            let enumeratorDef = KeywordTerm(name: name, code: self.code())
            self.skipString()    // description
            self.alignCursor()
            if !self.enumerators.contains(enumeratorDef) {
                self.enumerators.append(enumeratorDef)
            }
            try self.checkCursor()
        }
    }
    
    func parseSuite() throws {
        self.skipString()   // name string
        self.skipString()   // description
        self.alignCursor()
        self.skipCode()     // code
        self.skipShort()    // level
        self.skipShort()    // version
        let n = self.short()
        for _ in 0..<n {
            try self.parseCommand()
            try self.checkCursor()
        }
        let n2 = self.short()
        for _ in 0..<n2 {
            try self.parseClass()
            try self.checkCursor()
        }
        let n3 = self.short()
        for _ in 0..<n3 {
            try self.parseComparison()
            try self.checkCursor()
        }
        let n4 = self.short()
        for _ in 0..<n4 {
            try self.parseEnumeration()
            try self.checkCursor()
        }
    }
}





extension AEApplication { // extends the built-in Application object with convenience method for getting its AETE resource

    public func getAETE() throws -> Descriptor { // caller takes ownership
        return try self.sendAppleEvent(miscEventGetAETE, [keyDirectObject:0])
    }
}


