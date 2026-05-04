
import PySwiftKit
//import PySwiftObject
//// import PythonCore
import PythonLauncher
import PathKit

#if os(Android)
import Android

// Android logging support
@_silgen_name("__android_log_write")
func android_log_write(_ priority: Int32, _ tag: UnsafePointer<CChar>?, _ msg: UnsafePointer<CChar>?) -> Int32

private func logKivy(_ message: String) {
    "KivyLauncher".withCString { tag in
        message.withCString { msg in
            _ = android_log_write(4, tag, msg) // 4 = ANDROID_LOG_INFO
        }
    }
}
#else
import Foundation
import OSLog

private func logKivy(_ message: String) {
    print(message)
}
#endif

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
    

        public let PYTHON_VERSION: String = "3.13"

        let IOS_IS_WINDOWED: Bool = false
        public var KIVY_CONSOLELOG: Bool = true
        public var prog: String?
        
        #if os(Android)
        public var appDir: String?
        public var sitePackagesDir: String?
        #endif

        public init() throws {
    #if os(Android)
        // On Android, paths will be set via initWithPaths()
    #else
        #if os(iOS)
                //self.pyswiftImports.append(.ios)
        let YourApp = Bundle.main.url(forResource: "app", withExtension: nil)!
        let main_py = Bundle.main.path(forResource: "app/__main__", ofType: "py")
        #else
        let YourApp = Bundle.main.url(forResource: "app", withExtension: nil)!
        let main_py = Bundle.main.path(forResource: "app/__main__", ofType: "py")
        #endif
        
        chdir(YourApp.path)
                if let _prog = main_py {
                        prog = _prog
                } else {
            print("app/__main__.py not found")
                        throw CocoaError.error(.fileNoSuchFile)
                }
    #endif
        }
        
    #if os(Android)
        /// Initialize with paths provided from Java/Kotlin
        public func initWithPaths(pythonHome: String, appDir: String, sitePackagesDir: String?) {
            self.appDir = appDir
            self.sitePackagesDir = sitePackagesDir
            self.prog = appDir + "/__main__.py"
            
            // Set Python home
            env.PYTHONHOME = pythonHome
            
            // Set up Python path
            var pythonPath = appDir
            if let sitePkgs = sitePackagesDir {
                pythonPath = sitePkgs + ":" + pythonPath
            }
            env.PYTHONPATH = pythonPath
            
            // Change to app directory
            chdir(appDir)
        }
        
        /// Store the python home for initPython
        private var pythonHomePath: String?
        
        /// A simple error type for Android
        struct KivyInitError: Error {
            let message: String
        }
        
        /// Android-specific Python initialization.
        /// Overrides the protocol extension's default implementation which uses Bundle.main.
        public func initPython() throws {
            logKivy("initPython called")
            
            guard let appDir = self.appDir else {
                logKivy("ERROR: appDir not set")
                crash_dialog("appDir not set. Call initWithPaths() first.")
                throw KivyInitError(message: "appDir not set")
            }
            
            // Derive pythonHome from appDir - it should be sibling directory
            // appDir = /data/user/0/.../files/app
            // pythonHome = /data/user/0/.../files/python
            // Use simple string manipulation instead of NSString
            logKivy("appDir: \(appDir)")
            var filesDir = appDir
            if let lastSlash = appDir.lastIndex(of: "/") {
                filesDir = String(appDir[..<lastSlash])
            }
            let pythonHome = filesDir + "/python"
            logKivy("pythonHome: \(pythonHome)")
            
            var preconfig = PyPreConfig()
            var config = PyConfig()
            
            var wtmp_str: UnsafeMutablePointer<wchar_t>?
            var status: PyStatus
            
            logKivy("Configuring isolated Python for Android (Kivy)...")
            PyPreConfig_InitIsolatedConfig(&preconfig)
            PyConfig_InitIsolatedConfig(&config)
            
            preconfig.utf8_mode = 1
            config.buffered_stdio = 0
            config.write_bytecode = 0
            // Don't set module_search_paths_set = 1 here - we'll add paths after PyConfig_Read
            // config.module_search_paths_set = 1
            
            setenv("LC_CTYPE", "UTF-8", 1)
            
            // Set environment variables required by Kivy
            logKivy("Setting environment variables for Kivy...")
            setenv("ANDROID_APP_PATH", appDir, 1)
            setenv("ANDROID_ARGUMENT", appDir, 1)
            setenv("ANDROID_PRIVATE", filesDir, 1)
            setenv("ANDROID_UNPACK", filesDir, 1)
            setenv("PYTHONDONTWRITEBYTECODE", "1", 1)
            setenv("PYTHONHOME", pythonHome, 1)
            
            // Set site-packages path for Kivy
            if let sitePkgs = self.sitePackagesDir {
                setenv("PYTHON_SITEPACKAGES", sitePkgs, 1)
            }
            logKivy("Environment variables set")
            
            logKivy("Pre-initializing Python runtime...")
            status = Py_PreInitialize(&preconfig)
            if _PyStatus_Exception(status) {
                logKivy("ERROR: Unable to pre-initialize: \(status.error)")
                crash_dialog("Unable to pre-initialize Python interpreter: \(status.error)")
                PyConfig_Clear(&config)
                Py_ExitStatusException(status)
            }
            logKivy("Pre-initialize done")
            
            let python_tag = "3.13"
            logKivy("Setting Python home: \(pythonHome)")
            
            wtmp_str = Py_DecodeLocale(pythonHome, nil)
            var config_home = config.home
            status = PyConfig_SetString(&config, &config_home, wtmp_str)
            config.home = config_home
            if _PyStatus_Exception(status) {
                logKivy("ERROR: Unable to set PYTHONHOME: \(status.error)")
                crash_dialog("Unable to set PYTHONHOME: \(status.error)")
                PyConfig_Clear(&config)
                Py_ExitStatusException(status)
            }
            PyMem_RawFree(wtmp_str)
            logKivy("PYTHONHOME set")
            
            logKivy("Reading site config...")
            status = PyConfig_Read(&config)
            if _PyStatus_Exception(status) {
                logKivy("ERROR: Unable to read site config: \(status.error)")
                crash_dialog("Unable to read site config: \(status.error)")
                PyConfig_Clear(&config)
                Py_ExitStatusException(status)
            }
            logKivy("Site config read")
            
            logKivy("Setting PYTHONPATH:")
            var path = "\(pythonHome)/lib/python\(python_tag)"
            logKivy(" - \(path)")
            wtmp_str = Py_DecodeLocale(path, nil)
            status = PyWideStringList_Append(&config.module_search_paths, wtmp_str)
            if _PyStatus_Exception(status) {
                logKivy("ERROR: Unable to add stdlib path: \(status.error)")
                crash_dialog("Unable to add stdlib path: \(status.error)")
                PyConfig_Clear(&config)
                Py_ExitStatusException(status)
            }
            PyMem_RawFree(wtmp_str)
            
            path = "\(pythonHome)/lib/python\(python_tag)/lib-dynload"
            logKivy(" - \(path)")
            wtmp_str = Py_DecodeLocale(path, nil)
            status = PyWideStringList_Append(&config.module_search_paths, wtmp_str)
            if _PyStatus_Exception(status) {
                logKivy("ERROR: Unable to add lib-dynload path: \(status.error)")
                crash_dialog("Unable to add lib-dynload path: \(status.error)")
                PyConfig_Clear(&config)
                Py_ExitStatusException(status)
            }
            PyMem_RawFree(wtmp_str)
            
            // Add site-packages if specified
            if let sitePkgs = self.sitePackagesDir {
                path = sitePkgs
                logKivy(" - \(path)")
                wtmp_str = Py_DecodeLocale(path, nil)
                status = PyWideStringList_Append(&config.module_search_paths, wtmp_str)
                if _PyStatus_Exception(status) {
                    logKivy("ERROR: Unable to add site-packages path: \(status.error)")
                    crash_dialog("Unable to add site-packages path: \(status.error)")
                    PyConfig_Clear(&config)
                    Py_ExitStatusException(status)
                }
                PyMem_RawFree(wtmp_str)
            }
            
            // Add app directory to path
            path = appDir
            logKivy(" - \(path)")
            wtmp_str = Py_DecodeLocale(path, nil)
            status = PyWideStringList_Append(&config.module_search_paths, wtmp_str)
            if _PyStatus_Exception(status) {
                logKivy("ERROR: Unable to add app path: \(status.error)")
                crash_dialog("Unable to add app path: \(status.error)")
                PyConfig_Clear(&config)
                Py_ExitStatusException(status)
            }
            PyMem_RawFree(wtmp_str)
            logKivy("PYTHONPATH configured")
            
            // Mark that we've set up the module search paths ourselves
            config.module_search_paths_set = 1
            
            // Add PySwift module imports
            logKivy("Adding PySwift module imports...")
            for _import in Self.pyswiftImports {
                logKivy("Importing PySwiftModule: \(String(cString: _import.name))")
                if PyImport_AppendInittab(_import.name, _import.module) == -1 {
                    logKivy("ERROR: Failed to add module")
                    PyErr_Print()
                    fatalError()
                }
            }
            logKivy("PySwift modules added")
            
            logKivy("Initializing Python runtime...")
            status = Py_InitializeFromConfig(&config)
            if _PyStatus_Exception(status) {
                logKivy("ERROR: Unable to initialize Python: \(status.error)")
                crash_dialog("Unable to initialize Python interpreter: \(status.error)")
                PyConfig_Clear(&config)
                Py_ExitStatusException(status)
            }
            
            logKivy("Python runtime initialized successfully!")
            PyConfig_Clear(&config)
        }
        
        private func _PyStatus_Exception(_ status: PyStatus) -> Bool {
            return PyStatus_Exception(status) == 1
        }
    #endif

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
        #if os(Android)
        env.KIVY_BUILD = "android"
        env.KIVY_WINDOW = "sdl3"
        env.KIVY_IMAGE = "imageio,tex,gif,sdl3"
        env.KIVY_AUDIO = "sdl3"
        env.KIVY_GL_BACKEND = "gl"
        #elseif os(iOS)
        // Kivy environment to prefer some implementation on iOS platform
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

        #if os(Android)
        // On Android, FILE is exposed as OpaquePointer from Bionic
        var fd: OpaquePointer?
        var ret: Int32
        
        fd = fopen(prog, "r")
        
        if let fd {
            #if DEBUG
            print("Running __main__.py: \(prog)")
            #endif
            
            ret = PyRun_SimpleFileEx(fd, prog, 1)
            print("App ended")
            PyErr_Print()
            fclose(fd)
        } else {
            ret = 1
            print("Unable to open main.py, abort.")
        }
        return ret
        #else
        var fd: UnsafeMutablePointer<FILE>?
        var ret: Int32

        DispatchQueue.global().sync {
            fd = fopen(prog, "r")
        }

        if let fd {
            
        #if DEBUG
            print("Running __main__.py: \(prog)")
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
        #endif
    }
    
    public func onExit() throws {
        
    }


    #if !os(Android)
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
    #endif

    #if os(iOS)
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
    #else
    public static func SDLmain() -> Int32 {
        var argv: [UnsafeMutablePointer<CChar>?] = []
        KivyLauncher.run(0, &argv)
        return 0
    }
    #endif
}

//
//
//@freestanding(declaration, names: arbitrary)
//public macro SDL2Main(_ closure: (_ kivy: KivyLauncher)->Void) = #externalMacro(module: "KivyLauncherMacros", type: "CreateSDL2Main")
