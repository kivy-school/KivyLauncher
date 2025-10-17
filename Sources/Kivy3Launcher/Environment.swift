//
//  File.swift
//  
//
//  Created by CodeBuilder on 15/10/2024.
//

import Foundation


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
					setenv(_key, newValue, 1)
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
						setenv(_key, String(newValue), 1)
						return
					}
					setenv(_key, nil, 1)
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
					if let newValue = newValue, let boolValue = newValue ? "True" : "False" {
						setenv(_key, boolValue, 1)
						return
					}
					setenv(_key, nil, 1)
				}
			}
		}
		
	}
	

}
