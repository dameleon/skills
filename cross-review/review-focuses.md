# Review Focuses

## general

Evaluate for overall quality:
- **Correctness**: Logical errors, incorrect assumptions, wrong behavior
- **Completeness**: Missing cases, unhandled scenarios, gaps
- **Clarity**: Clear intent, understandable naming and structure
- **Consistency**: Uniform patterns, conventions, and style

## code

Evaluate code quality:
- **Readability**: Clear naming, appropriate abstractions, self-documenting structure
- **Maintainability**: Low coupling, high cohesion, no duplication, easy to modify
- **Error handling**: Proper error propagation, no silent failures, meaningful messages
- **Type safety**: Correct types, no unsafe casts, null/undefined handling

## architecture

Evaluate architectural design:
- **Separation of concerns**: Clear boundaries, single responsibility per module
- **Dependencies**: Correct direction, no circular refs, appropriate coupling
- **Extensibility**: New features addable without modifying existing code
- **API design**: Clean interfaces, consistent contracts, backward compatibility

## security

Evaluate security posture:
- **Input validation**: All external inputs validated and sanitized
- **Authentication/Authorization**: Proper identity verification and access control
- **Secrets management**: No hardcoded credentials, proper secret storage
- **Injection prevention**: Protection against SQL, command, XSS, and other injection vectors

## performance

Evaluate performance characteristics:
- **Computational complexity**: Algorithm efficiency, avoidance of unnecessary work
- **I/O operations**: Minimized disk/network calls, proper batching and streaming
- **Memory usage**: No leaks, bounded allocations, efficient data structures
- **Caching**: Appropriate caching strategies, proper invalidation

## requirements

Evaluate requirements quality:
- **Completeness**: All functional/non-functional requirements addressed, no unstated assumptions
- **Consistency**: No contradictions between requirements, uniform terminology
- **Feasibility**: Technically achievable within stated constraints
- **Traceability**: Requirements traceable to planned or existing implementation when applicable, no orphaned code

## design

Evaluate design quality:
- **Responsibility assignment**: Clear distribution, no role ambiguity or god-object tendency
- **Interface design**: Clean, minimal, well-defined contracts between components
- **Design patterns**: Appropriate usage, no over-engineering or pattern misuse
- **Data flow**: Clear and predictable flow, explicit transformations and side effects

## test

Evaluate test quality:
- **Coverage**: Critical paths tested, edge cases and error paths covered
- **Behavioral verification**: Tests verify behavior not implementation, readable assertions
- **Assertions**: Specific checks, no overly broad matchers, clear failure messages
- **Mocking**: Minimal mocking, no mock-heavy tests that test nothing real
