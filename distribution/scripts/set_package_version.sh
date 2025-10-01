source ./export.sh

sui client ptb \
--move-call $PACKAGE::distribution_config::set_package_version @$DISTRIBUTION_CONFIG @$DISTRIBUTION_CONFIG_PUBLISHER 2