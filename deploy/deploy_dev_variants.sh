#!/bin/bash
set -e

# Base directory for variants
BASE_DIR="./deploy/domain-garage/environments/dev"
CHART_DIR="./deploy/domain-garage"
NAMESPACE="default" # Modify if needed, or make configurable

# Function to deploy a single variant
deploy_variant() {
    local variant=$1
    local variant_dir="$BASE_DIR/$variant"

    if [ ! -d "$variant_dir" ]; then
        echo "Error: Variant config directory '$variant_dir' not found!"
        return 1
    fi

    echo "=================================================="
    echo "Deploying variant: $variant"
    echo "=================================================="

    local release_name="dev-domain-garage-$variant"

    # Helm upgrade --install
    # We pass config.environment=dev and config.variant=$variant
    # This allows the chart to pick up the correct config files.
    helm upgrade --install "$release_name" "$CHART_DIR" \
        --namespace "$NAMESPACE" \
        --set config.environment=dev \
        --set config.variant="$variant"

    echo "Successfully deployed release: $release_name"
    echo ""
}

# Main logic
if [ $# -eq 0 ]; then
    echo "No variants specified. Deploying ALL variants found in $BASE_DIR..."
    
    # Find all subdirectories in the dev environment folder
    # We use 'find' to robustly handle directory listing
    for dir in "$BASE_DIR"/*/; do
        # Extract directory name (variant name)
        # remove trailing slash
        dir=${dir%*/}
        # get basename
        variant=${dir##*/}
        
        deploy_variant "$variant"
    done
else
    echo "Deploying specified variants: $@"
    for variant in "$@"; do
        deploy_variant "$variant"
    done
fi

echo "Deployment complete."
