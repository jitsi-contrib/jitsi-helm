NAME := jitsi-meet-example
NAMESPACE :=
OUTFILE :=

ifeq "$(strip $(OUTFILE))" ""
OUT_FLAGS :=
else
OUT_FLAGS := > $(OUTFILE)
endif

ifeq "$(strip $(NAMESPACE))" ""
NS_FLAGS :=
else
NS_FLAGS := -n $(NAMESPACE)
endif

ifeq "$(strip $(VALUES))" ""
VAL_FLAGS :=
else
VAL_FLAGS := -f $(VALUES)
endif

template:
	echo helm template ${NS_FLAGS} ${VAL_FLAGS} --release-name ${NAME} . ${OUT_FLAGS}

package:
	echo helm package .
