#!/bin/bash

RED='\033[0;31m' # Error color
YELLOW='\033[0;33m' # Warning color
NC='\033[0m' # No Color

set -u
DIR="."
GetPathToCurrentlyExecutingScript () {
	# Absolute path of this script, e.g. /opt/corda/node/foo.sh
	set +e
	ABS_PATH=$(readlink -f "$0" 2>&1)
	if [ "$?" -ne "0" ]; then
		echo "Using macOS alternative to readlink -f command..."
		# Unfortunate MacOs issue with readlink functionality, see https://github.com/corda/corda-kubernetes-deployment/issues/4
		TARGET_FILE=$0

		cd $(dirname $TARGET_FILE)
		TARGET_FILE=$(basename $TARGET_FILE)
		ITERATIONS=0

		# Iterate down a (possible) chain of symlinks
		while [ -L "$TARGET_FILE" ]
		do
			TARGET_FILE=$(readlink $TARGET_FILE)
			cd $(dirname $TARGET_FILE)
			TARGET_FILE=$(basename $TARGET_FILE)
			ITERATIONS=$((ITERATIONS + 1))
			if [ "$ITERATIONS" -gt 1000 ]; then
				echo "symlink loop. Critical exit."
				exit 1
			fi
		done

		# Compute the canonicalized name by finding the physical path 
		# for the directory we're in and appending the target file.
		PHYS_DIR=$(pwd -P)
		ABS_PATH=$PHYS_DIR/$TARGET_FILE
	fi

	# Absolute path of the directory this script is in, thus /opt/corda/node/
	DIR=$(dirname "$ABS_PATH")
}
GetPathToCurrentlyExecutingScript
set -eu

checkStatus () {
	status=$1
	if [ $status -eq 0 ]
		then
			echo "."
		else
			echo -e "${RED}ERROR${NC}"
			echo "The previous step failed"
			exit 1
	fi	
	return 0
}

ensureFileExistsAndCopy () {
    FROM=$1
    TO=$2
    if [ -f "$FROM" ]
    then
        if [ -f "$TO" ]
        then
			echo "Existing certificate already existed, but it is safe to replace, since this is just the Corda Firewall tunnel keys."
        fi
		cp -f $FROM $TO
    else
		echo -e "${RED}ERROR${NC}"
		echo "File did not exist, probably an issue with certificate creation: $FROM"
        exit 1
    fi
}

CopyCertificatesToHelmFolder () {
	echo "====== Copying PKI certificates to Helm folder next ... ====== "
	echo "Copying trust.jks ..."
	ensureFileExistsAndCopy $DIR/pki-firewall/certs/trust.jks $DIR/../helm/files/certificates/firewall_tunnel/trust.jks
	echo "Copying float.jks ..."
	ensureFileExistsAndCopy $DIR/pki-firewall/certs/float.jks $DIR/../helm/files/certificates/firewall_tunnel/float.jks
	echo "Copying bridge.jks ..."
	ensureFileExistsAndCopy $DIR/pki-firewall/certs/bridge.jks $DIR/../helm/files/certificates/firewall_tunnel/bridge.jks
	echo "====== Copying PKI certificates to Helm folder completed. ====== "
}
CopyCertificatesToHelmFolder
