//
//  File.swift
//  
//
//  Created by CodeBuilder on 15/10/2024.
//

#if os(Android)
import Android
#else
import Foundation
#endif


public extension KivyLauncher {

    @dynamicMemberLookup
    struct Environment {
        
        public subscript(dynamicMember key: String) -> String? {
            get {
                if let result = key.withCString(getenv) {
                    return .init(cString: result)
                }
                return nil
            }
            set {
                _ = key.withCString { _key in
                    if let newValue = newValue {
                        _ = newValue.withCString { _value in
                            setenv(_key, _value, 1)
                        }
                    } else {
                        unsetenv(_key)
                    }
                }
            }
        }

        public subscript(dynamicMember key: String) -> Int? {
            get {
                if let result = key.withCString(getenv) {
                    return .init(String(cString: result))
                }
                return nil
            }
            set {
                key.withCString { _key in
                    if let newValue = newValue {
                        _ = String(newValue).withCString { _value in
                            setenv(_key, _value, 1)
                        }
                        return
                    }
                    unsetenv(_key)
                }
            }
        }

        public subscript(dynamicMember key: String) -> Bool? {
            get {
                if let result = key.withCString(getenv) {
                    return .init(String(cString: result).lowercased())
                }
                return nil
            }
            set {
                key.withCString { _key in
                    if let newValue = newValue {
                        let boolValue = newValue ? "True" : "False"
                        _ = boolValue.withCString { _value in
                            setenv(_key, _value, 1)
                        }
                        return
                    }
                    unsetenv(_key)
                }
            }
        }
    }
}
