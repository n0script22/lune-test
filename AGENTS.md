This is a luau test runner for the `lune` runtime, aimed to replicate roblox behavior and allow for a local Roblox testing environment. Tests are luau modules, and cases are functions exported by those modules.

## Instructions

* If you create user-facing APIs, ensure that they can be ran from test runtime-injected globals instead of requiring a module.
* Mirror Roblox classes and datatypes to the greatest extent. Do not invent new structures, with the exception of runner APIs such as `Environment`.
* Update markdown documentation when adding a new feature or changing user-facing API. All docs code examples should have their own test case.
* Ensure that individual files are not too large; split logic into multiple files grouped by their responsibilities.
* Create reusable functions when possible, and do not copy or repeat code.
* Do not implement backwards-compatibility, shims, or facades.
* All luau classes should use metatables, not closures or method-copying.
* Always add tests when implementing a feature or fixing a bug. Modify tests when changing a feature. Run all tests after every code change and ensure they pass.

## Testing

Run all project unit tests:
```sh
lune run src/main.lua
```

Or run specific test cases, separated by commas:
```sh
lune run src/main.lua test_case_name,other_case
```

Some tests require manifest modification to be registered. If you edited or added tests, look for a `manifest.lua` module inside of that directory and check if it uses absolute test/case declaration instead of auto-discovery through `testLocations`.