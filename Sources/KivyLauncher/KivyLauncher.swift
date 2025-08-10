

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
	//public var site_packages: URL
	//public var site_paths: [String]
	//public var pyswiftImports: [PySwiftModuleImport]
	
	//public var env = Environment()
	
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
        //putenv("KIVY_BUILD=ios")
        #if os(iOS)
        env.KIVY_BUILD = "ios"
//        putenv("KIVY_WINDOW=sdl2")
        env.KIVY_WINDOW = "sdl2"
        //putenv("KIVY_IMAGE=imageio,tex,gif,sdl2")
        env.KIVY_IMAGE = "imageio,tex,gif,sdl2"
        //putenv("KIVY_AUDIO=sdl2")
        env.KIVY_AUDIO = "sdl2"
        //putenv("KIVY_GL_BACKEND=sdl2")
        env.KIVY_GL_BACKEND = "sdl2"
        
        // IOS_IS_WINDOWED=True disables fullscreen and then statusbar is shown
        //putenv("IOS_IS_WINDOWED=\(IOS_IS_WINDOWED ? "True" : "False")")
        env.IOS_IS_WINDOWED = IOS_IS_WINDOWED
        //#if DEBUG
        //putenv("KIVY_NO_CONSOLELOG=\(KIVY_NO_CONSOLELOG)")
        #endif
        if !KIVY_CONSOLELOG {
            env.KIVY_NO_CONSOLELOG = "1"
        }
        //#endif
    }
	
    public func preLaunch() throws {
        kivySettings()
        #if os(iOS)
        export_orientation()
        #endif
    }
    
    public func onLaunch() throws -> Int32 {
        guard let prog else { return -1 }
        #if os(iOS)
        //*load_custom_builtin_importer()
        #endif
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
	
	
    @discardableResult
    private func load_custom_builtin_importer() -> Int32 {
        """
        import sys, imp, types
        from os import environ
        from os.path import exists, join
        try:
            # python 3
            import _imp
            EXTS = _imp.extension_suffixes()
            sys.modules['subprocess'] = types.ModuleType(name='subprocess')
            sys.modules['subprocess'].PIPE = None
            sys.modules['subprocess'].STDOUT = None
            sys.modules['subprocess'].DEVNULL = None
            sys.modules['subprocess'].CalledProcessError = Exception
            sys.modules['subprocess'].CompletedProcess = None
            sys.modules['subprocess'].check_output = None
        except ImportError:
            EXTS = ['.so']
        # Fake redirection to supress console output
        if environ.get('KIVY_NO_CONSOLE', '0') == '1':
            class fakestd(object):
                def write(self, *args, **kw): pass
                def flush(self, *args, **kw): pass
            sys.stdout = fakestd()
            sys.stderr = fakestd()
        # Custom builtin importer for precompiled modules
        class CustomBuiltinImporter(object):
            def find_module(self, fullname, mpath=None):
                # print(f'find_module() fullname={fullname} mpath={mpath}')
                if '.' not in fullname:
                    return
                if not mpath:
                    return
                part = fullname.rsplit('.')[-1]
                for ext in EXTS:
                   fn = join(list(mpath)[0], '{}{}'.format(part, ext))
                   # print('find_module() {}'.format(fn))
                   if exists(fn):
                       return self
                return
            def load_module(self, fullname):
                f = fullname.replace('.', '_')
                mod = sys.modules.get(f)
                if mod is None:
                    # print('LOAD DYNAMIC', f, sys.modules.keys())
                    try:
                        mod = imp.load_dynamic(f, f)
                    except ImportError:
                        # import traceback; traceback.print_exc();
                        # print('LOAD DYNAMIC FALLBACK', fullname)
                        mod = imp.load_dynamic(fullname, fullname)
                    sys.modules[fullname] = mod
                    return mod
                return mod
        sys.meta_path.insert(0, CustomBuiltinImporter())
        """.withCString(PyRun_SimpleString)
    }
	
    func run_kivy(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Int32 {
		
		
        #if os(iOS)
		load_custom_builtin_importer()
        #endif
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
		
		Py_Finalize()
		return ret
	}
    
    public static func SDLmain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
        guard
            let sdl2Lib = Bundle.main.path(forResource: "Frameworks/SDL2.framework/SDL2", ofType: nil),
            let handle = dlopen(sdl2Lib, RTLD_LAZY | RTLD_GLOBAL),
            let symbol = dlsym(handle, "SDL_UIKitRunApp")
        else {
            return -1
        }
        let uikitrunapp = unsafeBitCast(symbol, to: SDL_UIKitRunApp.self)
        return uikitrunapp(argc, argv) { _argc, _argv in
            KivyLauncher.run(_argc, _argv)
            return 0
        }
        
        
    }
}

//
//
//@freestanding(declaration, names: arbitrary)
//public macro SDL2Main(_ closure: (_ kivy: KivyLauncher)->Void) = #externalMacro(module: "KivyLauncherMacros", type: "CreateSDL2Main")



