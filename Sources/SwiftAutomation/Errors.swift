//
//  Errors.swift
//  SwiftAutomation
//

#if canImport(Carbon)
import Carbon
#endif

import Foundation
import AppleEvents


// TO DO: currently Errors are mostly opaque to client code (even inits are internal only); what (if any) properties should be made public?

// TO DO: simplify? use AppleEvents.AppleEventError for internal/all errors?


/******************************************************************************/
// error descriptions from ASLG/MacErrors.h

// TO DO: integrate with AppleEventError

private let _descriptionForError: [Int:String] = [
        // OS errors
        -34: "Disk is full.",
        -35: "Disk wasn't found.",
        -37: "Bad name for file.",
        -38: "File wasn't open.",
        -39: "End of file error.",
        -42: "Too many files open.",
        -43: "File wasn't found.",
        -44: "Disk is write protected.",
        -45: "File is locked.",
        -46: "Disk is locked.",
        -47: "File is busy.",
        -48: "Duplicate file name.",
        -49: "File is already open.",
        -50: "Parameter error.",
        -51: "File reference number error.",
        -61: "File not open with write permission.",
        -108: "Out of memory.",
        -120: "Folder wasn't found.",
        -124: "Disk is disconnected.",
        -128: "User canceled.",
        -192: "A resource wasn't found.",
        -600: "Application isn't running.",
        -601: "Not enough room to launch application with special requirements.",
        -602: "Application is not 32-bit clean.",
        -605: "More memory is needed than is specified in the size resource.",
        -606: "Application is background-only.",
        -607: "Buffer is too small.",
        -608: "No outstanding high-level event.",
        -609: "Connection is invalid.",
        -610: "No user interaction allowed.",
        -904: "Not enough system memory to connect to remote application.",
        -905: "Remote access is not allowed.",
        -906: "Application isn't running or program linking isn't enabled.",
        -915: "Can't find remote machine.",
        -30720: "Invalid date and time.",
        // AE errors
        -1700: "Can't make some data into the expected type.",
        -1701: "Some parameter is missing for command.",
        -1702: "Some data could not be read.",
        -1703: "Some data was the wrong type.",
        -1704: "Some parameter was invalid.",
        -1705: "Operation involving a list item failed.",
        -1706: "Need a newer version of the Apple Event Manager.",
        -1707: "Event isn't an Apple event.",
        -1708: "Application could not handle this command.",
        -1709: "AEResetTimer was passed an invalid reply.",
        -1710: "Invalid sending mode was passed.",
        -1711: "User canceled out of wait loop for reply or receipt.",
        -1712: "Apple event timed out.",
        -1713: "No user interaction allowed.",
        -1714: "Wrong keyword for a special function.",
        -1715: "Some parameter wasn't understood.",
        -1716: "Unknown Apple event address type.",
        -1717: "The handler is not defined.",
        -1718: "Reply has not yet arrived.",
        -1719: "Can't get reference. Invalid index.",
        -1720: "Invalid range.",
        -1721: "Wrong number of parameters for command.",
        -1723: "Can't get reference. Access not allowed.",
        -1725: "Illegal logical operator called.",
        -1726: "Illegal comparison or logical.",
        -1727: "Expected a reference.",
        -1728: "Can't get reference.",
        -1729: "Object counting procedure returned a negative count.",
        -1730: "Container specified was an empty list.",
        -1731: "Unknown object type.",
        -1739: "Attempting to perform an invalid operation on a null descriptor.",
        // Application scripting errors
        -10000: "Apple event handler failed.",
        -10001: "Type error.",
        -10002: "Invalid key form.",
        -10003: "Can't set reference to given value. Access not allowed.",
        -10004: "A privilege violation occurred.",
        -10005: "The read operation wasn't allowed.",
        -10006: "Can't set reference to given value.",
        -10007: "The index of the event is too large to be valid.",
        -10008: "The specified object is a property, not an element.",
        -10009: "Can't supply the requested descriptor type for the data.",
        -10010: "The Apple event handler can't handle objects of this class.",
        -10011: "Couldn't handle this command because it wasn't part of the current transaction.",
        -10012: "The transaction to which this command belonged isn't a valid transaction.",
        -10013: "There is no user selection.",
        -10014: "Handler only handles single objects.",
        -10015: "Can't undo the previous Apple event or user action.",
        -10023: "Enumerated value is not allowed for this property.",
        -10024: "Class can't be an element of container.",
        -10025: "Illegal combination of properties settings."
]


/******************************************************************************/


let defaultErrorCode = 1
let packErrorCode = errAECoercionFail
let unpackErrorCode = errAECoercionFail


func errorMessage(_ err: Any) -> String {
    switch err {
    case let e as AutomationError:
        return e.message ?? "Error \(e.code)."
    case let e as NSError: // TO DO: needed?
        return e.localizedDescription
    default:
        return String(describing: err)
    }
}


/******************************************************************************/
// error classes

// base class for all SwiftAutomation-raised errors (not including NSErrors raised by underlying Cocoa APIs)
public class AutomationError: Error, CustomStringConvertible {
    public let _domain = "SwiftAutomation"
    public let _code: Int // the OSStatus if known, or generic error code if not
    public let cause: Error? // the error that triggered this failure, if any
    
    let _message: String?
    
    public init(code: Int, message: String? = nil, cause: Error? = nil) {
        self._code = code
        self._message = message
        self.cause = cause
    }
    
    public var code: Int { return self._code }
    public var message: String? { return self._message } // TO DO: make non-optional?
    
    func description(_ previousCode: Int, separator: String = " ") -> String {
        let msg = self.message ?? _descriptionForError[self._code]
        var string = self._code == previousCode ? "" : "Error \(self._code)\(msg == nil ? "." : ": ")"
        if let msg = msg { string += msg }
        if let error = self.cause as? AutomationError {
            string += "\(separator)\(error.description(self._code))"
        } else if let error = self.cause {
            string += "\(separator)\(error)"
        }
        return string
    }

    public var description: String {
        return self.description(0)
    }
}


public class ConnectionError: AutomationError {
    
    public let target: TargetApplication
    
    public init(target: TargetApplication, message: String, cause: Error? = nil) {
        self.target = target
        super.init(code: defaultErrorCode, message: message, cause: cause)
    }
    
    // TO DO: include target description in message?
}


public class PackError: AutomationError {
    
    let object: Any
    
    public init(object: Any, message: String? = nil, cause: Error? = nil) {
        self.object = object
        super.init(code: packErrorCode, message: message, cause: cause)
    }
    
    public override var message: String? {
        return "Can't pack unsupported \(type(of: self.object)) value:\n\n\t\(self.object)"
                + (self._message != nil ? "\n\n\(self._message!)" : "")
    }
}

public class UnpackError: AutomationError {
    
    let type: Any.Type
    let appData: AppData
    let desc: Descriptor
    
    public init(appData: AppData, desc: Descriptor, type: Any.Type, message: String? = nil, cause: Error? = nil) {
        self.appData = appData
        self.desc = desc
        self.type = type
        super.init(code: unpackErrorCode, message: message, cause: cause)
    }
    
    var descriptor: Descriptor { return self.desc }
    
    // TO DO: worth including a method for trying to unpack desc as Any; this should be used when constructing full error message (might also be useful to caller); or what about a var that returns the type it would unpack as? (caveat: that probably won't work so well for AEList/AERecord descs due to their complexity and the obvious challenges of fabricating generic type objects on the fly)
    
    public override var message: String? { // TO DO: how best to phrase error message?
        var value: Any = self.desc
        var string = "Can't unpack value as \(self.type)"
        do {
            value = try self.appData.unpackAsAny(self.desc)
        } catch {
            string = "Can't unpack malformed \(literalFourCharCode(self.desc.type)) descriptor" // TO DO: better error message
        }
        return "\(string):\n\n\t\(value)" + (self._message != nil ? "\n\n\(self._message!)" : "")
    }
}


/******************************************************************************/
// standard command error


public class CommandError: AutomationError { // raised whenever an application command fails
    
    let commandInfo: CommandDescription // TO DO: this should always be given
    let appData: AppData
    private let event: AppleEventDescriptor? // non-nil if event was built and sent
    private let reply: ReplyEventDescriptor? // non-nil if reply event was received
    
    public init(commandInfo: CommandDescription, appData: AppData,
                event: AppleEventDescriptor? = nil, reply: ReplyEventDescriptor? = nil, cause: Error? = nil) {
        self.appData = appData
        self.event = event
        self.reply = reply
        self.commandInfo = commandInfo
        var errorNumber = 1
        if let error = cause {
            //            print("! DEBUG: SwiftAutomation/AppleEventManager error: \(error)")
            errorNumber = error._code
        } else if let replyEvent = reply {
            //            print("! DEBUG: App reply event: \(reply)")
            errorNumber = replyEvent.errorNumber
        }
        super.init(code: (errorNumber == 0 ? defaultErrorCode : errorNumber), cause: cause)
    }
    
    public override var message: String? {
        if let desc = self.reply?.parameter(AEKeyword(keyErrorString))
                    ?? self.reply?.parameter(AEKeyword(kOSAErrorBriefMessage)) { // TO DO: get rid of this?
            if let result = try? unpackAsString(desc) { return result }
        }
        return _descriptionForError[self._code]
    }
    
    public var expectedType: Symbol? {
        if let desc = self.reply?.parameter(AEKeyword(kOSAErrorExpectedType)) {
            return try? self.appData.unpack(desc) as Symbol
        } else {
            return nil
        }
    }
    
    public var offendingObject: Any? {
        if let desc = self.reply?.parameter(AEKeyword(kOSAErrorOffendingObject)) {
            return try? self.appData.unpack(desc) as Any
        } else {
            return nil
        }
    }
    
    public var partialResult: Any? {
        if let desc = self.reply?.parameter(AEKeyword(kOSAErrorPartialResult)) {
            return try? self.appData.unpack(desc) as Any
        } else {
            return nil
        }
    }
    
    public var commandDescription: String {
        return self.appData.formatter.formatCommand(self.commandInfo, applicationObject: self.appData.application)
    }
    
    public override var description: String {
        var string = "CommandError \(self._code): \(self.message ?? "")\n\n\t\(self.commandDescription)"
        if let expectedType = self.expectedType { string += "\n\n\tExpected type: \(expectedType)" }
        if let offendingObject = self.offendingObject { string += "\n\n\tOffending object: \(offendingObject)" }
        if let error = self.cause as? AutomationError {
            string += "\n\n" + error.description(self._code, separator: "\n\n")
        } else if let error = self.cause {
            string += "\n\n\(error)"
        }
        return string
    }
}




// TO DO: what about convenience constructors for common error types?
/*

extension AEError {
    // convenience constructors
 
    static var userCanceled               : AEError { return self.init(-128) } // "User canceled.",
    static var resourceNotFound           : AEError { return self.init(-192) } // "A resource wasn't found.",
    static var processNotFound            : AEError { return self.init(-600) } // "Application isn't running.",
    static var appIsDaemon                : AEError { return self.init(-606) } // "Application is background-only.",
    static var connectionInvalid          : AEError { return self.init(-609) } // "Connection is invalid.",
    static var noUserInteractionAllowed   : AEError { return self.init(-610) } // "No user interaction allowed.",
    static var remoteAccessNotAllowed     : AEError { return self.init(-905) } // "Remote access is not allowed.",
    static var remoteProcessNotFound      : AEError { return self.init(-906) } // "Application isn't running or program linking isn't enabled.",
    static var remoteMachineNotFound      : AEError { return self.init(-915) } // "Can't find remote machine.",
    static var invalidDateTime            : AEError { return self.init(-30720) } // "Invalid date and time.",
    // AE errors
    static var coercionFailed             : AEError { return self.init(-1700) } // errAECoercionFail
    static var parameterNotFound          : AEError { return self.init(-1701) } // errAEDescNotFound
    static var corruptData                : AEError { return self.init(-1702) } // errAECorruptData
    static var wrongDataType              : AEError { return self.init(-1703) } // errAEWrongDataType
    static var invalidParameter           : AEError { return self.init(-1704) } // errAENotAEDesc
    static var listItemNotFound           : AEError { return self.init(-1705) } // errAEBadListItem
    static var invalidAppleEvent          : AEError { return self.init(-1706) } // errAENotAppleEvent
    static var eventNotHandled            : AEError { return self.init(-1708) } // errAEEventNotHandled
    //errAEReplyNotValid            = -1709, /* AEResetTimer was passed an invalid reply parameter */
    //errAEUnknownSendMode          = -1710, /* mode wasn't NoReply, WaitReply, or QueueReply or Interaction level is unknown */
    static var eventTimedOut              : AEError { return self.init(-1712) } // errAETimeout
    static var userInteractionNotAllowed  : AEError { return self.init(-1713) } // errAENoUserInteraction
    //errAENotASpecialFunction      = -1714, /* there is no special function for/with this keyword */
    //errAEParamMissed              = -1715, /* a required parameter was not accessed */
    //errAEUnknownAddressType       = -1716, /* the target address type is not known */
    //errAEHandlerNotFound          = -1717, /* no handler in the dispatch tables fits the parameters to AEGetEventHandler or AEGetCoercionHandler */
    //errAEReplyNotArrived          = -1718, /* the contents of the reply you are accessing have not arrived yet */
    static var invalidIndex               : AEError { return self.init(-1719) } // errAEIllegalIndex
    static var invalidRange               : AEError { return self.init(-1720) } // errAEImpossibleRange /* A range like 3rd to 2nd, or 1st to all. */
    //errAEWrongNumberArgs          = -1721, /* Logical op kAENOT used with other than 1 term */
    //errAEAccessorNotFound         = -1723, /* Accessor proc matching wantClass and containerType or wildcards not found */
    //errAENoSuchLogical            = -1725, /* Something other than AND, OR, or NOT */
    //errAEBadTestKey               = -1726, /* Test is neither typeLogicalDescriptor nor typeCompDescriptor */
    //errAENotAnObjSpec             = -1727, /* Param to AEResolve not of type 'obj ' */
    static var objectNotFound             : AEError { return self.init(-1728) } // errAENoSuchObject /* e.g.,: specifier asked for the 3rd, but there are only 2. Basically, this indicates a run-time resolution error. */
    //errAENegativeCount            = -1729, /* CountProc returned negative value */
    //errAEEmptyListContainer       = -1730, /* Attempt to pass empty list as container to accessor */
    //errAEUnknownObjectType        = -1731, /* available only in version 1.0.1 or greater */
    //errAERecordingIsAlreadyOn     = -1732, /* available only in version 1.0.1 or greater */
    //errAEReceiveTerminate         = -1733, /* break out of all levels of AEReceive to the topmost (1.1 or greater) */
    //errAEReceiveEscapeCurrent     = -1734, /* break out of only lowest level of AEReceive (1.1 or greater) */
    //errAEEventFiltered            = -1735, /* event has been filtered, and should not be propogated (1.1 or greater) */
    //errAEDuplicateHandler         = -1736, /* attempt to install handler in table for identical class and id (1.1 or greater) */
    //errAEStreamBadNesting         = -1737, /* nesting violation while streaming */
    //errAEStreamAlreadyConverted   = -1738, /* attempt to convert a stream that has already been converted */
    //errAEDescIsNull               = -1739, /* attempting to perform an invalid operation on a null descriptor */
    //errAEBuildSyntaxError         = -1740, /* AEBuildDesc and friends detected a syntax error */
    //errAEBufferTooSmall           = -1741 /* buffer for AEFlattenDesc too small */
 
    static var userPermissionDenied       : AEError { return self.init(-1743) } // errAEEventNotPermitted
    static var userPermissionRequired     : AEError { return self.init(-1744) } // errAEEventWouldRequireUserConsent
    /*
     // Application scripting errors
     -10000: "Apple event handler failed.",
     -10001: "Type error.",
     -10002: "Invalid key form.",
     -10003: "Can't set reference to given value. Access not allowed.",
     -10004: "A privilege violation occurred.",
     -10005: "The read operation wasn't allowed.",
     -10006: "Can't set reference to given value.",
     -10007: "The index of the event is too large to be valid.",
     -10008: "The specified object is a property, not an element.",
     -10009: "Can't supply the requested descriptor type for the data.",
     -10010: "The Apple event handler can't handle objects of this class.",
     -10011: "Couldn't handle this command because it wasn't part of the current transaction.",
     -10012: "The transaction to which this command belonged isn't a valid transaction.",
     -10013: "There is no user selection.",
     -10014: "Handler only handles single objects.",
     -10015: "Can't undo the previous Apple event or user action.",
     -10023: "Enumerated value is not allowed for this property.",
     -10024: "Class can't be an element of container.",
     -10025: "Illegal combination of properties settings."
     */
 
    //static func coercionError
}

*/
