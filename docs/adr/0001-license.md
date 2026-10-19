# 0001. Use LGPL-3.0-or-later

- **Status:** Accepted
- **Date:** 2026-10-19
- **Related:** issue #3, [README license statement](../../README.md#license)

## Context

Kastor STA needs a license before further development. The project follows the
free software principles of the GNU project. We want to preserve those freedoms
for the library while allowing it to be linked with proprietary applications
under the license's conditions.

## Decision

We will license Kastor STA under LGPL-3.0-or-later, consistent with the README.
The repository includes the license texts in `COPYING.LESSER` and `COPYING`.

## Alternatives considered

- **GPL-3.0:** Its stronger copyleft requirements for combined works do not match
  our intention to allow proprietary applications to link with the library.
  The [GNU license guidance](https://www.gnu.org/licenses/license-list.html#LGPLv3)
  explains this distinction.

## Consequences

- **Easier:** Applications can link with the library under the LGPL's conditions
  without requiring the entire application to adopt the LGPL.
- **Harder:** Distribution must comply with the license's requirements, and
  dependency licenses must be checked for compatibility.
- **Revisit when:** No review is currently planned; this choice reflects the
  project's free software principles.
