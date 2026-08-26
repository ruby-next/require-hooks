# Change log

## master

- Add `RequireHooks::Bootsnap.add_version_hash` for external cache inputs.

## 0.5.0 (2026-08-26)

- Use Bootsnap compiler namespaces for cache invalidation without changing Bootsnap's cache directory.

## 0.4.1 (2026-07-22)

- Bring back Ruby 2.3 compatibility.

## 0.4.0 (2026-04-29)

- Improved Bootsnap cache invalidation logic on hooks configuration changes.

- Latest Bootsnap compatibility

- Coverage compatibility (w/ some limitations)

## 0.3.0 (2026-04-22)

- Fix the order of around hooks execution (after part) when using `#load_iseq` driven hooks.

- Improve `Kernel#require` patch performance.

- Reduce context object creation and use a single object when only one context defined.

## 0.2.3 (2026-01-13)

- Gem metadata fixes.

## 0.2.2 (2023-12-19)

- Fix handing uncompilable source code with Bootsnap. ([@palkan][])

## 0.2.1 (2023-12-19)

- Fix constant resolution in Bootsnap error handling (`Bootsnap::CompileCache` -> `::Bootsnap::CompileCache`). ([@palkan][])

## 0.2.0 (2023-08-23)

- Add `patterns` and `exclude_patterns` options to hooks. ([@palkan][])

## 0.1.0 (2023-07-14)

- Extracted from Ruby Next. ([@palkan][])

[@palkan]: https://github.com/palkan
