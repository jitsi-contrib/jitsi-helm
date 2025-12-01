# Releasing

Overall, the release process looks like this:

- Add some changes to the chart.
- Test these changes on a test installation.
- Test again on production installation.
- Update `version` in [Chart.yaml](/Chart.yaml).
- Create the package:
  ```bash
  # Use your GPG signing identity (email or Key ID)
  helm package . -d ./docs/ --sign --key "$KEY_EMAIL_OR_ID" --keyring ~/.gnupg/secring.gpg
  ```
- Update the index:
  ```bash
  cd docs
  helm repo index . --url https://jitsi-contrib.github.io/jitsi-helm/ --merge index.yaml
  ```
- Review the diff for [/docs/index.yaml](/docs/index.yaml). Sometimes Helm adds
  a new release to the index and also changes timestamps for **all** old
  releases as well. **Fix the corrupted timestamps by discarding those hunks
  from the staged changes.**
- Add the release files and index changes, commit and push:
  ```bash
  git add ...
  git commit -m 'Release Chart version vX.Y.Z'
  git push
  ```
- Create a release on GitHub. This step will also create a tag for the release.
