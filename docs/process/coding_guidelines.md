# Coding Guidelines

## Purpose and scope

These guidelines establish consistent, readable, maintainable, and
well-documented source code. They apply to developers working in any
supported language. Shared engineering principles apply across languages;
detailed C++ rules apply to C++ source code. Other languages follow their
established conventions unless an explicit rule here takes precedence.

Guideline precedence:

1. Explicit rules in this document.
2. Established conventions of the programming language.
3. Existing codebase conventions that do not conflict with this document.
4. Readability and maintainability where no specific rule exists.

Code fragments illustrate individual rules; abbreviated class or function
declarations do not waive required documentation or special-member policies.

A **must** or **must not** indicates a requirement. **Prefer** indicates the
default choice, with a justified alternative permitted. Exceptions must be
intentional, limited in scope, and explainable during code review.

## 1. General engineering principles

### 1.1. Readability and responsibility

- Write clear code that communicates intent through names, types, interfaces,
  and structure.
- Each function must have one well-defined responsibility.
- Keep functions cohesive and split unrelated operations into separate
  functions.
- Prefer composition, low coupling, and clearly defined component boundaries.
- Do not introduce abstractions, indirection, or inheritance solely to reduce
  the number of lines in a function.
- Prefer proven language and standard-library facilities over custom mechanisms
  when they adequately solve the problem.
- Prefer straightforward control flow and guard clauses that reduce nesting.
- Write testable code and supply tests appropriate to the behavior and risks.

### 1.2. The 80x24 principle

**80 columns is a strict limit.** No source-code line, including comments and
preprocessor directives, may exceed 80 columns. Count displayed columns, not
merely bytes, when non-ASCII characters are present.

**24 lines is a function-size guideline, not an absolute prohibition.** Count
physical lines beginning with the opening brace and ending with the matching
closing brace, inclusive. Count statements, comments, and empty lines inside
those braces. Exclude the function signature before the opening brace.

- Design functions to be at most 24 physical lines in the usual case.
- Permit justified exceptions, such as a cohesive large `switch` statement.
- The purpose is appropriate granularity and single responsibility.
- Never fragment a cohesive function artificially to satisfy the number.
- The 80-column limit remains strict even when the 24-line guideline is waived.
- Apply the same principles to scripting languages using their corresponding
  function-body syntax.

### 1.3. Whitespace and source hygiene

- Use spaces for indentation; do not put literal tab characters in source files.
- C++: indent by **8 spaces** per nesting level.
- Scripting languages: indent by **4 spaces** per nesting level.
- Do not leave trailing whitespace.
- End every text source file with exactly one newline character.
- Use at most one consecutive empty line in normal code, unless a particular
  construct or language convention justifies otherwise.
- Use automated formatters when suitable, configured to preserve these rules.
  Formatting tools do not replace review of naming, behavior, or documentation.

Vim settings for C++:

```vim
set tabstop=8
set shiftwidth=8
set softtabstop=8
set expandtab
```

Vim settings for scripting languages:

```vim
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
```

### 1.4. Documentation and implementation comments

- Document interfaces comprehensively using each language's native
  documentation conventions.
- Explain purpose, behavior, parameters, results, constraints, and complexity
  where applicable. Documentation should be complete rather than artificially
  short.
- Implementation code should explain itself through good design and naming;
  do not add ordinary explanatory comments inside implementations.
- Permit actionable `TODO` and `FIXME` comments for incomplete work, preferably
  linked to an issue or task.
- Permit structural comments expressly required by these guidelines, such as
  include-group headings, namespace endings, and conditional-compilation labels.
- Keep comments accurate and remove obsolete documentation and work markers.

### 1.5. Errors, resources, and quality

- Use error-handling mechanisms idiomatic to the language; distinguish
  recoverable failures from programmer errors.
- Do not log a failure at each propagation level. Log where the error is
  handled or reported, preserving relevant diagnostic context.
- Prefer automatic resource management and narrowly scoped ownership.
- Avoid uninitialized or indeterminate values. Language-defined absence
  values are acceptable when handled safely.
- Test observable behavior, boundary conditions, error paths, and invariants.
  Concurrent code requires concurrency-specific verification.

## 2. C++ coding conventions

### 2.1. Identifiers and naming

- Use lowercase `snake_case` for classes, structures, functions, methods,
  namespaces, enumeration types and values, and type aliases.
- Prefer complete words or common, widely understood abbreviations.
- Functions and methods must have **verb-based names** describing the operation
  they perform and should perform exactly one job.
- Classes should have **noun-based names** describing the represented concept,
  responsibilities, or worker role (for example, `analyzer`).
- Use `m_` for all non-static data members and `s_` for static data members.
  This also applies to data-oriented `struct` types.
- Local variables, block variables, and function parameters use **single
  lowercase-letter identifiers**.
- Type template parameters use **single uppercase-letter identifiers**.
- Boolean predicates should use intention-revealing names such as `is_valid`,
  `has_items`, `can_execute`, or `should_retry`.
- Follow the special naming rules for constants and macros described below.
- Abstract interfaces use ordinary descriptive names. Do not require `i_`,
  `I`, or `_interface` markers.

```cpp
class analyzer
{
public:
        bool is_ready() const;
        void process(const node& n);

private:
        int m_count = 0;
        static constexpr int s_max_count = 100;
};
```

#### Constants

- Local constants retain single-letter local-variable naming.
- Non-static and static class constants retain `m_` and `s_` respectively.
- Avoid namespace-scope and global constants unless justified by an
  architectural decision.
- When necessary, give namespace-scope and global constants descriptive
  `UPPER_SNAKE_CASE` names.
- Prefer the narrowest meaningful scope for every constant.

```cpp
void process()
{
        constexpr int n = 100;
        const double d = 0.5;
}

namespace limits {

inline constexpr int MAX_NODES = 1000;

} // end of namespace limits
```

### 2.2. Files, declarations, and includes

Use these file extensions:

| File kind | Extension |
| --- | --- |
| C++ header | `.hpp` |
| C++ implementation | `.cpp` |
| C-compatible header | `.h` |
| C implementation | `.c` |

- Use lowercase `snake_case` for filenames.
- Give corresponding header and implementation files the same base filename.
- Prefer one primary class per header/implementation pair. Small supporting
  types may share the file; header-only components need no `.cpp` file.
- Use `#pragma once` at the beginning of every project-owned C++ header;
  do not combine it with traditional include guards.
- Each header must be self-contained: include what its declarations and
  definitions need, rather than relying on a preceding include.
- Prefer a forward declaration when a complete type is unnecessary.
- Put forward declarations at the beginning of their actual namespaces,
  before class definitions, without extra section-heading comments.
- Include the complete definition in an implementation file when necessary.
- Do not use forward declarations where layout, inheritance, inline behavior,
  or an operation on the type requires its complete definition.
- Treat incomplete types held by templates or smart pointers carefully:
  destruction and instantiation may require a complete type.

#### Include groups and syntax

Every file using `#include` must retain these **four groups in this order**,
with their headings present even if a group is empty:

1. `// Includes from this build target`
2. `// Includes from other project targets`
3. `// Includes from third-party libraries`
4. `// Includes from standard libraries`

- Use double quotes only for headers of the same build target:
  `#include "analyzer.hpp"`.
- Use angle brackets for every other group. Headers from another target
  must use that target's public include-path prefix, for example
  `#include <database/design.hpp>`.
- A *build target* is an executable, static/shared library, or header-only
  library; it is not the same as a C++ translation unit.
- In a `.cpp` file, include its corresponding header **first**.
- Within each group, prefer dependent headers before foundational headers
  they use, to help expose missing direct includes.
- Do not require alphabetic sorting of independent headers.
- Include ordering helps reveal omissions but does not replace independent
  compilation checks for header self-sufficiency.

```cpp
// Includes from this build target
#include "analyzer.hpp"
#include "graph.hpp"

// Includes from other project targets
#include <database/design.hpp>

// Includes from third-party libraries
#include <fmt/format.h>

// Includes from standard libraries
#include <memory>
#include <vector>
```


#### Namespace usage

- Use explicit namespace qualification. Prohibit namespace using-directives
  (`using namespace ...`) and individual namespace using-declarations
  (`using std::vector;`).
- Type aliases declared with `using` remain permitted; inherited-member
  declarations such as `using base::method;` are a separate language feature.
- When names become excessively long or deeply nested, prefer namespace
  aliases with a single uppercase letter or a capitalized word:
  `namespace F = std::filesystem;`.
- Keep aliases in the narrowest practical scope.

### 2.3. Namespace layout

- Use compact nested namespace declarations when applicable:
  `namespace core::data {`.
- Put the opening `{` on the namespace declaration line.
- Do **not** indent declarations merely because they are in a namespace.
- After every namespace closing brace, add the fully qualified closing
  comment using exactly `} // end of namespace <qualified_name>`.
- Use `} // end of namespace (anonymous)` for anonymous namespaces.
- Prefer anonymous namespaces over `static` for free functions intended for
  use exclusively within one `.cpp` file.

```cpp
namespace core::data {

class node
{
public:
        void reset();
};

} // end of namespace core::data
```

### 2.4. Braces, indentation, and control flow

- Put opening braces for functions, methods, classes, structures, unions, and
  enumerations on a **new line**.
- Put opening braces for `if`, `else`, `for`, `while`, `do`, `switch`, `try`,
  and `catch` on the **same line** as their controlling statement.
- **Always use braces** for control-flow bodies, even if they contain one
  statement.
- Place `else`, `catch`, and the trailing `while` of `do-while` on the **same
  line as the preceding closing brace**.
- Indent each ordinary C++ nesting level by 8 spaces.
- Align class access specifiers (`public:`, `protected:`, `private:`) with
  the class opening brace. Indent member declarations by 8 spaces.
- Indent `case` and `default` labels 8 spaces inside `switch`, and statements
  within each case by another 8 spaces.
- Every `case` and `default` must have a braced body, with its `{` following
  the label on the same line and the closing brace aligned with the label.
- Separate distinct cases by one blank line.
- Require `[[fallthrough]];` for intentional fallthrough; do not permit
  unmarked implicit fallthrough.
- Require `default` unless all enumerators of an enumeration are covered.
  Prefer compiler warnings such as `-Wswitch-enum` to detect new cases.
- Prefer early returns and guard clauses to reduce unnecessary nesting.

```cpp
void process(mode m)
{
        if (!is_ready()) {
                return;
        }

        switch (m) {
                case mode::first: {
                        process_first();
                        break;
                }

                case mode::second: {
                        process_second();
                        break;
                }
        }
}
```

An exhaustive enumeration switch may still receive an invalid underlying
value from external input; validate such inputs where necessary.

### 2.5. Spaces, expressions, and multiline layout

- Attach pointer and reference declarators to the type: `node*`,
  `const node&`, `node&&`.
- Use **West const**: `const node&`, not `node const&`.
- Use one variable per declaration statement.
- Use no spaces just inside function-call parentheses or template argument
  brackets. Put one space after commas separating arguments or parameters.
- Put one space between a control keyword and its opening `(`, but none
  between a function name and its opening `(`.
- Put exactly one space around binary operators and no spaces between unary
  operators and operands.
- Do not put spaces around `.`, `->`, or `::`.
- Write `template <typename T>`, with one space after `template`, none just
  inside `<...>`, and one space after template-argument commas.
- When wrapping function parameter or argument lists, align subsequent items
  with the first parameter or argument after the opening parenthesis.
  Alignment spaces need not be multiples of eight.
- Place a binary operator at the **beginning** of a continuation line,
  not at the end of the preceding line.
- Keep ternary expressions on one line when readable and within 80 columns;
  otherwise begin continuation lines with `?` and `:`.
- Prefer the return type and function name on the same line; wrap when
  necessary to satisfy the 80-column limit.
- Put function attributes such as `[[nodiscard]]` on their own lines.
- Keep a single-line lambda on one line when it is short and readable;
  otherwise use a multiline body with normal brace and indentation rules.
- Prefer explicit lambda captures (`[a, &b]`); avoid blanket `[=]` and `[&]`
  unless justified.
- Permit expression or call chaining only while it remains understandable.

```cpp
const node& get_node(int i);

void calculate(const graph& g,
               const constraints& c,
               const model& m);

bool v = is_ready() && is_valid()
         && has_dependencies();

int r = use_primary() ? primary_value() : fallback_value();

const auto f = [](int x) { return x * 2; };
```

### 2.6. Initialization and const correctness

- Initialize all variables at declaration; no uninitialized declarations.
- Prefer the actual intended initial value over a placeholder immediately
  overwritten later.
- There is **no universal preferred initialization syntax**: choose `=`,
  `{}`, or `()` according to semantics, avoiding unintended narrowing and
  surprising `initializer_list` overload resolution.
- Keep brace-enclosed initializer lists on one line when possible.
- For multiline initializer lists, put `{` on the declaration line,
  indent elements by 8 spaces, and put `}` on a separate line.
- Never add a trailing comma after the last initializer or enumerator.
- Prefer default member initializers for ordinary defaults. Constructors
  explicitly initialize members that require constructor-specific values.
- Constructor member initializer lists place **one initializer per line**.
  Start the first with `:` and every subsequent line with `,`; align commas
  with the colon and put one space after each punctuation mark.
- List base classes and data members in their actual initialization order;
  members must appear in declaration order. Enable `-Wreorder` where available.
- Declare local variables `const` when not reassigned.
- Declare non-mutating methods `const`, and use `const` references and pointers
  for read-only access.
- Never use `const_cast` to bypass const-correctness.
- Use `mutable` only for justified logical-const exceptions such as caches
  or internal synchronization.

```cpp
struct point
{
        double m_x = 0.0;
        double m_y = 0.0;
};

std::array<int, 3> a{10, 20, 30};

point p{1.0, 2.0};
```

Constructor initializer style:

```cpp
node::node(int i, double d, bool a)
        : m_id{i}
        , m_delay{d}
        , m_active{a}
{
}
```

### 2.7. Class structure and object model

#### Class versus struct

- Use `class` for encapsulated state and behavior, invariants, and resource
  management.
- Use `struct` for simple related data intended to be publicly accessible.
- Class data members, including static members, must be private and placed
  at the end of the declaration. Public members are acceptable in data structs.

#### Declaration order

Inside a class, use this order:

1. Constructors, destructor, and copy/move special members.
2. Public methods, with related operations declared consecutively.
3. Protected methods.
4. Private methods, grouped by responsibility.
5. Private data members, grouped meaningfully and placed last.

Access and inheritance requirements may place a destructor in a protected
section instead of the initial public special-member section. Separate
meaningful method or member groups with one blank line.

#### Special member functions

- Explicitly declare the special member functions to make copy, move, and
  destruction capabilities visible.
- Use `= default` for appropriate compiler-generated behavior and `= delete`
  to prohibit unsupported operations.
- Implement custom special members only when required.
- Express the intended default construction policy explicitly when applicable.
- Document special members following the Doxygen requirements below.
- Prefer `explicit` for converting constructors and conversion operators.
  Permit implicit conversion only where it is semantically natural, safe,
  and deliberately part of the interface.

#### Methods in headers

- Permit short, trivial non-template methods inline in class declarations.
- Put nontrivial non-template implementations in `.cpp` files.
- Keep templates' declarations and definitions in `.hpp` files; do not use
  separate `.tpp` or `.ipp` template implementation files.
- Define long template members outside the class but in the same header.
- Explicit instantiation in `.cpp` files remains permissible when useful.

#### Inheritance and interfaces

- Prefer composition over inheritance.
- Use inheritance for a genuine *is-a* relationship or necessary polymorphism.
- Do not inherit solely for implementation reuse.
- Permit multiple inheritance **only from pure abstract interfaces**.
- Such interfaces have no instance data and no concrete behavioral methods;
  they may declare special members, aliases, and compile-time constants.
- Use `virtual` for newly declared virtual base operations.
- Use `override` for every override; do not redundantly add `virtual`.
- Use `final` when further overriding or subclassing must be prohibited.
  When both qualifiers are used, write `override final`.
- Use a public virtual destructor if deletion through a base pointer is
  supported; otherwise a protected non-virtual destructor may prevent it.
- Derived classes must preserve base-class behavioral contracts.

### 2.8. Types, templates, and standard language facilities

- Use `enum class` instead of unscoped `enum`, except for necessary external
  compatibility. Prefer implicit enumerator values and default underlying
  types unless representation requirements justify explicit values or types.
- Use `using` for type aliases instead of `typedef`. This does **not** permit
  namespace using-directives or imported names.
- Prefer explicit types. Use `auto` when the type is obvious from context or
  the exact type does not matter to understanding the code.
- Use `typename` for unconstrained type template parameters.
- Use concepts and `requires` instead of SFINAE where practical.
- Prefer `constexpr` for code meaningfully usable at compile time; reserve
  `consteval` for mandatory compile-time evaluation.
- Use named C++ casts (`static_cast`, `dynamic_cast`, `const_cast`, and
  `reinterpret_cast`) rather than C-style casts. `const_cast` remains subject
  to the stricter const-correctness rule.
- Prohibit implicit narrowing conversions; validate ranges before potentially
  lossy explicit conversions when necessary.
- Prefer C++ standard C-header wrappers (`<cstdio>`, `<cstdlib>`,
  `<cstring>`) over their traditional C header names in C++ code.
- Prefer standard library containers over custom alternatives unless
  requirements or measurements justify a custom implementation.
- In C++23, prefer `std::format` and `std::print` when supported by the
  available standard library.

### 2.9. API design and parameter passing

- Prefer a maximum of four function parameters. Review larger signatures for
  cohesion and possible parameter objects; justified exceptions are allowed.
- Pass small, inexpensive-to-copy objects by value.
- Pass expensive read-only objects by `const T&`.
- Pass required mutable objects by `T&`; use pointers when optionality or
  pointer semantics are meaningful.
- Use `std::span` for non-owning contiguous ranges and `std::string_view`
  for suitable read-only, non-owning string input. Respect view lifetimes.
- Express ownership transfers with ownership-aware types.
- Prefer returning results directly; use a `struct` for multiple related
  results. Use output parameters only when technically justified.
- Permit function overloads when they represent the same conceptual action.
- Overload operators only with behavior consistent with their conventional
  semantics.
- Avoid multiple side-effecting expressions as arguments in one function
  call. Do not depend on unspecified evaluation order.
- Prefer guard clauses and early returns over unnecessarily nested control
  flow.
- Prefer standard algorithms and ranges to explicit iteration when they
  express the operation more clearly.

### 2.10. Errors, assertions, attributes, and exceptions

For **C++23 and later**, use the following error-handling convention:

- Use `std::expected<T, E>` for anticipated, recoverable failures and
  `std::expected<void, E>` when there is no success value.
- Use `std::optional<T>` for ordinary absence that is not an error.
- Avoid throwing exceptions in project-owned error handling. At external
  library boundaries, catch and translate exceptions when appropriate.
- Avoid error messages carried only as unstructured strings.
- Choose lightweight `enum class` errors for simple operations and structured
  error types when contextual diagnostics are necessary.
- Prefer subsystem-specific error types. Convert or aggregate them into an
  application-level representation at appropriate boundaries.
- Propagate errors without logging them repeatedly; log at the level that
  handles or reports them.
- Use `assert()` only for programming defects and violated internal invariants.
  Use runtime validation for recoverable or externally caused failures.
- Do not rely on assertions for required behavior: expressions in assertions
  must have no necessary side effects, since `NDEBUG` may disable them.
- Require `[[nodiscard]]` for error-bearing return values, including
  `std::expected` and error/status codes that must be checked.
- Use `[[nodiscard]]` selectively for other results that callers should not
  discard.
- Use `noexcept` selectively where a non-throwing guarantee is both useful
  and real, notably for suitable move and swap operations. Include library
  and allocation behavior in that assessment.

The `std::expected`-based policy is specific to C++23 or later. Earlier
language standards need their own appropriate error-handling conventions.
Not throwing explicitly does not prove that a function cannot throw.

### 2.11. Resource management and memory

- Prefer RAII and standard-library resource-owning abstractions.
- Avoid direct `new` and `delete` in ordinary code; allow them where necessary
  to implement low-level memory-management facilities.
- Prefer `std::unique_ptr` for dynamic ownership. Use `std::shared_ptr` only
  when multiple parties genuinely share ownership of the object's lifetime.
- Do not use owning raw pointers.
- Use non-owning pointers, references, spans, and views with clear lifetime
  requirements.
- Prefer standard containers. Justify custom allocators, containers, or
  memory-management mechanisms through actual constraints or measurements.

### 2.12. Preprocessor rules

- Avoid macros where standard C++ constructs can express the same behavior.
- Permit macros for necessary conditional compilation, compiler integration,
  platform support, interoperability, and similar tasks.
- Give every project-defined macro an `UPPER_SNAKE_CASE` name beginning with
  a unique project-specific prefix.
- Avoid C++ reserved identifier patterns, including double underscores and
  an underscore followed by an uppercase letter.
- Start all preprocessor directives with `#` in **column 1**, even when
  directives are nested. Put no spaces between `#` and the directive name.
- Use `#if defined(NAME)` and `#if !defined(NAME)` rather than `#ifdef`
  and `#ifndef`.
- Add condition-identifying comments to closing `#endif` directives for
  nested or complex conditions; simple conditions need no closing comment.
- For unavoidable multiline macros, indent replacement lines by 8 spaces
  and further nesting by 8 spaces per level.
- Put exactly **one space** before each continuation backslash. The backslash
  must be the last character on its line; do not align backslashes to a column.
- Parenthesize macro arguments and resulting expressions where syntactically
  appropriate. Exceptions include stringification, token concatenation,
  and statement-like macros.
- Avoid repeated evaluation of side-effecting macro arguments.

```cpp
#if defined(EXAMPLE_FEATURE)
#define EXAMPLE_DOUBLE(a) ((a) * 2)
#endif

#define EXAMPLE_EXECUTE(a, b) \
        do { \
                execute(a); \
                execute(b); \
        } while (false)
```

A check for `defined(NAME)` tests whether the macro exists, not whether its
replacement value is nonzero.

### 2.13. Concurrency and thread safety

These rules apply when concurrency is part of an implementation; they do not
require making otherwise sequential code concurrent.

- Prefer `std::jthread` for scoped thread ownership and automatic joining;
  use `std::thread` when its particular lifecycle semantics are needed.
- Manage mutex ownership with RAII (`std::lock_guard`, `std::unique_lock`,
  `std::scoped_lock`). Avoid manual lock/unlock except inside synchronization
  primitives or similarly justified infrastructure.
- Minimize shared mutable state. Prefer isolated ownership and immutable data
  where practical; synchronize all shared mutable access correctly.
- There is **no strict preference** for atomic memory-order syntax or a
  universally mandated memory order. Choose correct orders for the operation.
  Weaker orders require understood and justified synchronization semantics.
- Select synchronization primitives according to the problem; no fixed
  hierarchy of mutexes, atomics, barriers, latches, semaphores, or condition
  variables is mandated. Condition-variable waits must handle spurious wakes.
- Keep critical sections as small as practical, and avoid blocking I/O or
  unknown external callbacks while holding locks unless justified.
- Prefer mutexes over elaborate atomic protocols for complex multi-value
  invariants.
- Support cooperative cancellation when required by the interface; use
  `std::stop_token` where appropriate, but do not require cancellation for
  every concurrent operation.
- Document the thread-safety contract of **every public method of a
  concurrency-related class**, not just the class overall.
- Test race conditions, lifetime, termination, synchronization, and relevant
  cancellation. Use ThreadSanitizer where supported.

### 2.14. C++ API documentation with Doxygen

#### Location and scope

Use comprehensive block-style Doxygen comments for:

- Every class and structure.
- Every public and protected method, and every special member function
  regardless of its access level.
- Every free function declared in a header, including internal header APIs.
- Every enumeration (document all enumerator meanings in the enumeration's
  single documentation block, **not** in separate comments per enumerator).
- Type aliases with domain meaning, non-obvious semantics, or constraints;
  simple aliases do not need comments.

Private methods need no documentation by default. When non-obvious internal
constraints need explanation, permit a short Doxygen comment at the private
method declaration, optionally marked `@internal`. Do not document individual
data members separately. Instead, document their meanings, invariants, units,
and relationships collectively in the containing class or structure's block.

Place documentation immediately before the **declaration**; do not repeat it
in implementation files. Implementation bodies do not receive ordinary
explanatory comments.

Document significant namespaces in authoritative **`.dox` source files**, using
fully qualified `@namespace` commands. Do not duplicate namespace documentation
in individual headers. Include `@brief` and `@details` in those blocks.
Directory placement and file subdivision are outside the scope of these
coding guidelines.

#### Required content and format

- Use `/**` to open, prefix every interior line with ` *`, and close with
  ` */`. Separate logical documentation sections with blank comment lines.
- Require `@brief` and `@details` for documentable entities.
- Require `@param` for each named parameter and `@tparam` for template
  parameters. Use `@param[out]` for outputs, `@param[in,out]` for values read
  and modified; ordinary inputs use `@param` without a direction label.
- Require `@return` for a value-returning function; omit it for `void`.
- Include `@pre` and `@post` when meaningful; omit them if no relevant
  conditions or guarantees exist beyond the ordinary contract.
- Require `@par Complexity` for functions and methods, including special
  members, describing time and auxiliary space complexity with assumptions.
- Add other applicable information such as errors, exceptions, warnings,
  thread safety, lifecycle, units, valid ranges, ownership, and side effects.
- For concurrency-related public methods, document thread safety and
  synchronization requirements individually.
- Avoid filler statements that merely repeat a name; documentation may be
  lengthy when completeness requires it.
- Respect the strict 80-column limit in documentation text.

Doxygen recognizes `@par Complexity` as a named paragraph; no custom
`@complexity` command is assumed.

```cpp
/**
 * @brief Computes the difference between two time values.
 *
 * @details
 * Subtracts arrival time from required time. Both inputs must
 * be measured in the same units.
 *
 * @param a Arrival time in nanoseconds.
 * @param r Required time in nanoseconds.
 *
 * @return Required time minus arrival time, in nanoseconds.
 *
 * @pre Both parameters must be finite.
 *
 * @par Complexity
 * Time: O(1).
 * Auxiliary space: O(1).
 */
double calculate_slack(double a, double r);
```

When generating public API documentation, typical Doxygen settings are:

```ini
EXTRACT_PRIVATE = NO
INTERNAL_DOCS   = NO
```

`@internal` may mark an internal documentation fragment; `@cond` and
`@endcond` can hide exceptional internal sections. There is no need to add
`@internal` to every private method.

## 3. Other programming languages

Do not reproduce all C++ formatting decisions in other languages. Use each
language's standard or widely adopted style for names, declarations,
control flow, modules, documentation, and idiomatic error handling. Retain
applicable shared principles from Section 1, including the strict 80-column
limit, preferred 24-line function size, comprehensive interface documentation,
and four-space indentation with spaces rather than tab characters.

### 3.1. Python

- Follow PEP 8 naming: `snake_case` for functions and variables,
  `PascalCase` for classes, and `UPPER_SNAKE_CASE` for constants.
- Prefer descriptive variables; short identifiers are acceptable in small,
  unambiguous scopes.
- Follow Python conventions for members (for example, `_name` for non-public
  attributes); do not import C++ `m_` and `s_` rules.
- Use **Google-style docstrings** and comprehensive API contracts, including
  parameters, returns, exceptions, preconditions, postconditions, and
  complexity where relevant.
- Require type annotations for all function parameters and return types;
  annotate local variables when useful.
- Prefer f-strings for string interpolation.
- Prefer `with` and context managers for resource lifetimes.
- Catch specific exceptions; broad exception handlers require a clear
  handling-boundary justification.
- Use the `if __name__ == "__main__":` guard for directly executable modules.
- Do not execute application workflows as side effects of importing a module.
- Do not use mutable default parameter values; create mutable values during
  execution when needed.
- Follow standard Python import grouping and the language's established
  conventions rather than imposing C++ dependency-oriented include ordering.
- `None` is a well-defined absence value; check for it when the operation
  requires a present value. An annotation alone does not initialize a variable.

```python
def calculate_delay(a: float, b: float) -> float:
    """Calculate a combined delay.

    Args:
        a: First delay component.
        b: Second delay component.

    Returns:
        Sum of the two delay components.

    Complexity:
        Time: O(1). Auxiliary space: O(1).
    """
    return a + b
```

### 3.2. JavaScript, Lua, Tcl, shell, and other scripting languages

- Follow the established naming and formatting conventions for the language
  and its ecosystem. Do not impose C++ class names, member prefixes, or
  implementation patterns on other languages.
- Document exported/public functionality with the language's native
  documentation mechanisms, including contracts and complexity as applicable.
- Follow idiomatic error-handling, module/import, and resource-management
  conventions.
- Use type annotations or comparable type documentation when the language
  supports them and when appropriate.
- Use shebang lines for scripts designed to run directly on Unix-like systems;
  do not require shebangs in imported modules.
- Use appropriate language-specific automated formatters and linters,
  configured to preserve explicit requirements of this document.

## 4. Applying and enforcing the guidelines

- Configure editors and formatters for the required line width and indentation.
- Use compiler warnings, static analysis, format checks, and relevant tests
  in automated validation where practical.
- Check that headers can be included independently and that each one declares
  its own dependencies.
- Use sanitizers and relevant runtime checks; concurrency tests should include
  ThreadSanitizer when available.
- Review behaviors that formatters cannot verify: function responsibility,
  interface documentation, naming intent, ownership, error propagation,
  data-race freedom, and the justification for exceptions.
- Preserve existing external APIs or compatibility contracts when necessary,
  and isolate any intentional deviations from the local style.

A guideline exception must preserve the primary goals: correctness,
readability, clear contracts, and maintainability. The strict 80-column
limit is not waived by other preferences in this document.
