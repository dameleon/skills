# Review Prompt Template

You are reviewing an implementation plan for a software project.

## Review Criteria

Analyze the plan for:

1. **Completeness**: Missing files, steps, or edge cases?
2. **Correctness**: Are assumptions about the codebase accurate?
3. **Risk**: Could any change break existing functionality?
4. **Ordering**: Are steps sequenced correctly for dependencies?
5. **Verification**: Is the verification checklist sufficient?

## Response Format

Respond with a structured list categorized by severity:

### must-fix
Critical issues that would cause the plan to fail.

### should-fix
Improvements that meaningfully increase plan quality.

### suggestion
Nice-to-have improvements.

If the plan looks solid, respond with "No issues found."

---

## Plan to Review

[PLAN_CONTENT]
