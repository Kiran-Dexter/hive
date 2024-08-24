#!/bin/bash

# List of packages typically associated with the container-tools module
PACKAGES=(
    "podman"
    "buildah"
    "skopeo"
    "conmon"
    "podman-plugins"
    "cri-o"
    "runc"
)

# List of modules related to container-tools
MODULES=(
    "container-tools"
)

# Function to print a table line
print_line() {
    printf "%-20s | %-20s | %-40s\n" "$1" "$2" "$3"
}

# Print the header
echo "Validating the system for Docker installation..."
print_line "Package" "Installed" "Dependencies"
print_line "--------------------" "--------------------" "----------------------------------------"

# Check for installed packages and their dependencies
INSTALLED_PACKAGES=()
DEPENDENT_PACKAGES=()
for PACKAGE in "${PACKAGES[@]}"; do
    if rpm -q $PACKAGE &> /dev/null; then
        DEPENDENCIES=$(rpm -q --whatrequires $PACKAGE)
        if [ -n "$DEPENDENCIES" ]; then
            print_line "$PACKAGE" "Yes" "$DEPENDENCIES"
            DEPENDENT_PACKAGES+=("$PACKAGE (required by: $DEPENDENCIES)")
        else
            print_line "$PACKAGE" "Yes" "None"
        fi
        INSTALLED_PACKAGES+=($PACKAGE)
    else
        print_line "$PACKAGE" "No" "N/A"
    fi
done

# Print the header for modules
echo
print_line "Module" "Enabled" "Dependencies"
print_line "--------------------" "--------------------" "----------------------------------------"

# Check for enabled modules
ENABLED_MODULES=()
for MODULE in "${MODULES[@]}"; do
    if sudo dnf module list --enabled | grep -q "^${MODULE}"; then
        print_line "$MODULE" "Yes" "N/A"
        ENABLED_MODULES+=($MODULE)
    else
        print_line "$MODULE" "No" "N/A"
    fi
done

# Summary of findings
echo
echo "Summary of findings:"
if [ ${#INSTALLED_PACKAGES[@]} -eq 0 ] && [ ${#ENABLED_MODULES[@]} -eq 0 ]; then
    echo "No conflicting packages or modules found. System is ready for Docker installation."
else
    if [ ${#INSTALLED_PACKAGES[@]} -ne 0 ]; then
        echo "Installed packages that are not required by Docker:"
        for PACKAGE in "${INSTALLED_PACKAGES[@]}"; do
            echo " - $PACKAGE"
        done
    fi
    if [ ${#DEPENDENT_PACKAGES[@]} -ne 0 ]; then
        echo "Packages that are required by others:"
        for DEP_PACKAGE in "${DEPENDENT_PACKAGES[@]}"; do
            echo " - $DEP_PACKAGE"
        done
    fi
    if [ ${#ENABLED_MODULES[@]} -ne 0 ]; then
        echo "Enabled modules that are not required by Docker:"
        for MODULE in "${ENABLED_MODULES[@]}"; do
            echo " - $MODULE"
        done
    fi
    echo "Please consider these findings before installing Docker."
fi

echo "Validation complete."
