# Release

Create a new release of the ElevenLabs Flutter SDK.

## Arguments

The user may provide a version number (e.g. `0.5.1`). If not provided, determine the next version by:
1. Running `git describe --tags --abbrev=0` to get the latest tag
2. Incrementing the patch version (e.g. `v0.5.0` -> `0.5.1`)
3. Confirming the version with the user before proceeding

## Version locations

The version string must be updated in exactly these 2 files:

| File | Pattern |
|------|---------|
| `pubspec.yaml` | `version: X.Y.Z` |
| `lib/version.dart` | `const packageVersion = 'X.Y.Z';` |

## Steps

1. **Verify clean state**: Run `git status` on `main` branch. Abort if there are uncommitted changes or if not on `main`.

2. **Update versions**: Edit both files listed above with the new version string.

3. **Update CHANGELOG**: Add a new entry at the top of the changelog (after the header) following the Keep a Changelog format:
   - Use today's date in `YYYY-MM-DD` format
   - Categorize changes as Added, Changed, Fixed, Removed, or Security
   - Derive the changelog entries from `git log` between the previous tag and HEAD
   - Add a release link at the bottom of the file in the format: `[X.Y.Z]: https://github.com/elevenlabs/elevenlabs-flutter/releases/tag/vX.Y.Z`

4. **Format**: Run `dart format .` and fix any issues.

5. **Analyze**: Run `flutter analyze` to verify no issues.

6. **Test**: Run `flutter test` to verify all tests pass.

7. **Commit**: Stage the changed files and commit:
   ```
   chore: bump version to X.Y.Z
   ```

8. **Grep for old version**: Search the repo for any remaining references to the previous version string to make sure nothing was missed. Ignore CHANGELOG.md entries for previous versions.

9. **Create PR**: Since `main` is protected, create a branch and open a PR:
   ```bash
   git checkout -b chore/bump-version-X.Y.Z
   git push -u origin chore/bump-version-X.Y.Z
   gh pr create --title "chore: bump version to X.Y.Z" ...
   ```

10. **Confirm with user**: After the PR is merged, ask the user for confirmation before tagging. Show a summary of what will happen (create tag, create GitHub release, trigger pub.dev publish).

11. **Tag and release** (after PR merge):
    ```bash
    git checkout main && git pull origin main
    git tag vX.Y.Z
    git push origin vX.Y.Z
    gh release create vX.Y.Z --generate-notes
    ```

12. **Report**: Share the release URL with the user.
