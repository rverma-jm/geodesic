if [ -n "${AWS_PROFILE}" ] && [ -f "${AWS_CONFIG_FILE}" ] && [ -f "${AWS_SHARED_CREDENTIALS_FILE}" ]; then
	assume-role ${AWS_PROFILE}
fi
