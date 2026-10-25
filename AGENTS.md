# ## Code style

- Before changing code, inspect the file and nearby implementations. Follow the existing style in that part of the iOS app rather than introducing a new formatting convention.
- Preserve the surrounding indentation, line breaks, blank lines, brace layout, import organization, naming patterns, and file headers. Give new files the same style as adjacent files.
- In particular, keep the existing spacing between declarations and logical steps. Do not compress method bodies, guards, or switch cases onto one line when surrounding code uses multiple lines.
- Put a blank line before each `guard` statement and after its `else` block's closing brace when another statement follows. Put a blank line before each `do`/`catch` block; keep each `catch` attached to the preceding closing brace as Swift syntax requires.
- Use shorthand optional binding in both `if let` and `guard let` when the local name matches an optional property, such as `if let restrictedContent` instead of `if let restrictedContent = self.restrictedContent`. Keep explicit comparisons and bindings whose names or expressions differ.
- Aim for function bodies of 15 lines or fewer. Up to 30 lines is acceptable when splitting the function would make it less clear; 40 lines is the hard limit for code you add or substantially change. Extract longer sections into meaningfully named private functions, especially complex `switch` cases.
- Keep formatting changes limited to the code being changed. Do not reformat unrelated code as part of a feature or fix.
- Preserve switch-case ordering and existing comma-separated case layout. Do not
  alphabetize cases or split a compact case list merely for formatting.
- Align a wrapped extension's `where` clause with the `extension` declaration,
  without an extra indentation level.

- Limit implementation lines and function declarations to 85 characters; split
  expressions, argument lists, and string literals manually when necessary.
  Compact typealias declarations may exceed 85 characters. Preserve their
  existing single-line layout instead of splitting at `=` or `->`.
- Keep function calls and definitions on one line when they fit within 85
  characters. Only when that limit is exceeded, place each argument or parameter
  on its own new line and put the closing parenthesis on a separate line.
  Keep closing braces on their own lines.

- Put each non-private struct, class, enum, actor, protocol, and standalone typealias
  in its own Swift file named after the declaration. Declare nested types in an
  extension in their own file to preserve their qualified names. Name a file
  defining `XXX.YYY` in an extension `XXX+YYY.swift`, not `YYY.swift`.
  Private helpers and associated-type witnesses may remain with their owning
  implementation.

## Unit tests

- Use the Swift Testing framework (`import Testing`, `@Test`, `#expect`, and `#require`) for all new unit tests instead of XCTest.
