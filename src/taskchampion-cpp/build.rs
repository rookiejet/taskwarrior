use std::env;

#[allow(unused_must_use)]
fn main() {
    // Check if we're building in debug mode
    let profile = env::var("PROFILE").unwrap_or_else(|_| "release".to_string());

    // Check if CMake is building in debug mode
    let cmake_build_type = env::var("CMAKE_BUILD_TYPE").unwrap_or_else(|_| "Release".to_string());
    let is_debug_build = cmake_build_type.to_lowercase() == "debug" || profile == "debug";

    // Only apply Windows-specific MSVC flags on Windows
    if cfg!(target_os = "windows") && is_debug_build {
        // Force Debug mode and Debug MSVC runtime for Windows debug builds
        println!("cargo:rustc-link-arg=/MDd");
        println!("cargo:rustc-link-arg=/NODEFAULTLIB:MSVCRT");
        println!("cargo:rustc-link-arg=/DEFAULTLIB:MSVCRTD");
        println!("cargo:rustc-link-arg=/NODEFAULTLIB:LIBCMT");
        println!("cargo:rustc-link-arg=/DEFAULTLIB:LIBCMTD");

        // Set environment variable to force Debug runtime
        println!("cargo:rustc-env=_ITERATOR_DEBUG_LEVEL=2");
    }

    cxx_build::bridge("src/lib.rs");
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=src/lib.rs");
}
