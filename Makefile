template:
	helm template --release-name jitsi-8960 .
templateWithCustomDefaults:
	helm template --release-name jitsi-8960 . -f example-configurations/custom-defaults.yaml
package:
	helm package .
