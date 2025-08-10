import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

import Foundation



public struct CreateSDL2Main: DeclarationMacro {
	public static func expansion(of node: some SwiftSyntax.FreestandingMacroExpansionSyntax, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
		guard let closure = node.trailingClosure else {
			fatalError("compiler bug: the macro does not have any closure")
		}
		
		
		return [
			
"""
@_cdecl("SDL_main")
func main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
	print("running main")
 
	var ret: Int32 = 0
 
	do {
		let kivy = try KivyLauncher(
			site_paths: extra_pip_folders,
			pyswiftImports: pythonSwiftImportList
		)
	  
		#if DEBUG
		kivy.KIVY_CONSOLELOG = true
		#endif
		
		//python.prog = PyCoreBluetooth.main_py.path
		\(closure.statements)
		//kivy.setup()
		kivy.start()
	  
		ret = try kivy.run_main(argc, argv)
	} catch let err {
		print(err.localizedDescription)
	}
 
	return ret
 
}
"""
		]
	}
	
	
}
