template:
	helm template --release-name jitsi-example . -f example-configurations/custom-defaults.yaml
package:
	helm package .
