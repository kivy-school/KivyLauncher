

import PySwiftKit
import PySwiftObject
//// import PythonCore
import PythonLauncher
import PathKit

import OSLog

#if os(iOS)
import UIKit
#endif

public typealias SDL_main_func = @convention(c) (_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
public typealias SDL_UIKitRunApp = @convention(c) (
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>,
    _ mainFunction: SDL_main_func
) -> Int32


public final class KivyLauncher: PyLauncherIsolated {
    public static var pyswiftImports: [PySwiftModuleImport] = []
    
    
    
    public static let shared: KivyLauncher = try! .init()

    
    public var env: PythonLauncher.PyEnvironment = .init()
    
    public static var Env: PyEnvironment {
        get {
            shared.env
        }
        set {
            
        }
    }
    
	
	public let PYTHON_VERSION: String = "3.11"
	
	let IOS_IS_WINDOWED: Bool = false
	public var KIVY_CONSOLELOG: Bool = true
	public var prog: String?
	
	public init() throws {
    
        #if os(iOS)
		//self.pyswiftImports.append(.ios)
        
        #endif
        let YourApp = Bundle.main.url(forResource: "app", withExtension: nil)!
        chdir(YourApp.path)
		if let _prog = Bundle.main.path(forResource: "app/main", ofType: "py") {
			prog = _prog
		} else {
            print("app/main.py not found")
			throw CocoaError.error(.fileNoSuchFile)
		}
	}
	
	public func setup() {
		pythonSettings()
		kivySettings()
        #if os(iOS)
		export_orientation()
        #endif
	}
	
    private func pythonSettings() {
//        env.PYTHONOPTIMIZE = 2
//        env.PYTHONDONTWRITEBYTECODE = 1
//        env.PYTHONNOUSERSITE = 1
//        env.PYTHONPATH = "."
        #if os(iOS)

        
//        env.PYTHONUNBUFFERED = 1
//        env.LC_CTYPE = "UTF-8"
        // putenv("PYTHONVERBOSE=1")
        // putenv("PYOBJUS_DEBUG=1")
        #endif
    }
    
    private func kivySettings() {
        // Kivy environment to prefer some implementation on iOS platform
        #if os(iOS)
        env.KIVY_BUILD = "ios"
        env.KIVY_WINDOW = "sdl3"
        env.KIVY_IMAGE = "imageio,tex,gif,sdl3"
        env.KIVY_AUDIO = "sdl3"
        env.KIVY_GL_BACKEND = "angle"
        
        // IOS_IS_WINDOWED=True disables fullscreen and then statusbar is shown
        env.IOS_IS_WINDOWED = IOS_IS_WINDOWED
        #endif
        if !KIVY_CONSOLELOG {
            env.KIVY_NO_CONSOLELOG = "1"
        }
    }
	
    public func preLaunch() throws {
        kivySettings()
        #if os(iOS)
        export_orientation()
        #endif
    }
    
    public func onLaunch() throws -> Int32 {
        guard let prog else { return -1 }

        var fd: UnsafeMutablePointer<FILE>?
        var ret: Int32

        DispatchQueue.global().sync {
            fd = fopen(prog, "r")
        }

        if let fd {
            
        #if DEBUG
            print("Running main.py: \(prog)")
        #endif
            
            ret = PyRun_SimpleFileEx(fd, prog, 1)
            NSLog("App ended")
            PyErr_Print()
            fclose(fd)
            
        } else {
            ret = 1
            NSLog("Unable to open main.py, abort.")
        }
        return ret
    }
    
    public func onExit() throws {
        
    }
	
	
	
	private func export_orientation() {
		let info = Bundle.main.infoDictionary
		let orientations = info?["UISupportedInterfaceOrientations"] as? [AnyHashable]
		//var result = "KIVY_ORIENTATION="
		var result = ""
		for i in 0..<(orientations?.count ?? 0) {
			var item = orientations?[i] as? String
			item = (item as NSString?)?.substring(from: 22)
			if i > 0 {
				result = result + " "
			}
			result = result + (item ?? "")
		}
		
		//putenv(result)
        #if os(iOS)
		env.KIVY_ORIENTATION = result
        #endif
		#if DEBUG
		print("Available orientation: \(result)")
		#endif
	}
	
    
    public static func SDLmain() -> Int32 {
        //guard
            let sdl2Lib = Bundle.main.path(forResource: "Frameworks/SDL3.framework/SDL3", ofType: nil)!
            let handle = dlopen(sdl2Lib, RTLD_LAZY | RTLD_GLOBAL)!
            let symbol = dlsym(handle, "SDL_RunApp")!
//        else {
//            return -1
//        }
        let uikitrunapp = unsafeBitCast(symbol, to: SDL_UIKitRunApp.self)
        
        var argv: [UnsafeMutablePointer<CChar>?] = []
        
        return uikitrunapp(0, &argv) { _argc, _argv in
            KivyLauncher.run(_argc, _argv)
            return 0
        }
        
        
    }
}

//
//
//@freestanding(declaration, names: arbitrary)
//public macro SDL2Main(_ closure: (_ kivy: KivyLauncher)->Void) = #externalMacro(module: "KivyLauncherMacros", type: "CreateSDL2Main")



