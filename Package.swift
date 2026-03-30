// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AiLockEmployee",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AiLockEmployee",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "AiLockEmployee"
        )
    ]
)
