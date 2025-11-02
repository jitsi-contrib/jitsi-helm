# Releasing

Overall, the release process looks like this:

- Add some changes to the chart.
- Test these changes on a test installation.
- Test again on production installation.
- Update `version` and `dependencies.version` in [Chart.yaml](/Chart.yaml) and
  [charts/prosody/Chart.yaml](/charts/prosody/Chart.yaml)
- Create the package:
  ```bash
  helm package . -d ./docs/ --sign --key "$my_email" --keyring ~/.gnupg/secring.gpg
  ```
- Update the index:
  ```bash
  cd docs
  helm repo index . --url https://jitsi-contrib.github.io/jitsi-helm/ --merge index.yaml
  ```
- Review the diff for [/docs/index.yaml](/docs/index.yaml). Sometimes Helm adds
  a new release to the index and also changes timestamps for **all** old
  releases as well. So, discard these from the commit.
- Add the release files and index changes, commit and push:
  ```bash
  git add ...
  git commit -m 'Release Chart version vX.Y.Z'
  git push
  ```
- Create a release on GitHub. This step will also create a tag for the release.
