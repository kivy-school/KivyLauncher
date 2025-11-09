// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport


let local = false

let pykit_package: Package.Dependency = if local {
    .package(path: "../PySwiftKit")
} else {
    .package(url: "https://github.com/py-swift/PySwiftKit", from: .init(313, 0, 0))
}


let py_launcher_package : Package.Dependency = if local {
    .package(path: "../PythonLauncher")
} else {
    .package(url: "https://github.com/py-swift/PythonLauncher", .upToNextMajor(from: "313.0.0"))
}

//let kivycore_package: Package.Dependency = if local {
//    .package(path: "../KivyCore")
//} else {
//    .package(url: "https://github.com/kv-swift/KivyCore", from: .init(311, 0, 0))
//}


let pykit: Target.Dependency = .product(name: "PySwiftKitBase", package: "PySwiftKit")



let package = Package(
    name: "KivyLauncher",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "KivyLauncher",
            targets: ["KivyLauncher"]
        ),
        .library(
            name: "Kivy3Launcher",
            targets: ["Kivy3Launcher"]
        ),
    ],
	dependencies: [
        pykit_package,
        py_launcher_package
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "KivyLauncher",
			dependencies: [
				.product(name: "PySwiftKitBase", package: "PySwiftKit"),
                "PythonLauncher"
			],
            swiftSettings: [
            ]
		),
        .target(
            name: "Kivy3Launcher",
            dependencies: [
                .product(name: "PySwiftKitBase", package: "PySwiftKit"),
                "PythonLauncher"
            ],
            swiftSettings: [
            ]
        ),
		

    ]
)
