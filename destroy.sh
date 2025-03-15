#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./terraform-destroy.sh [OPTIONS]${NC}"
    echo -e "Destroy infrastructure on AWS or Azure using a specific Terraform state file"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -r, --regions     Specify region mode (single or multi), default: single"
    echo -e "  -s, --state       Path to an existing tfstate file to use (optional)"
    echo -e "  -y, --yes         Auto-approve destruction (no confirmation prompt)"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./terraform-destroy.sh --provider aws --regions multi --state ./my-terraform.tfstate"
}

# Default values
PROVIDER="aws"
REGIONS="single"
STATE_FILE=""
AUTO_APPROVE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -r|--regions)
            REGIONS="$2"
            shift 2
            ;;
        -s|--state)
            STATE_FILE="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Set project vars from .env file if it exists
if [[ -f .env ]]; then
    echo -e "${YELLOW}Loading environment variables from .env file...${NC}"
    export $(grep -v '^#' .env | xargs)

    
    # Export Terraform-specific variables
    if [[ "$PROVIDER" == "azure" ]]; then
        export TF_VAR_azure_subscription_id="$AZURE_SUBSCRIPTION_ID"
    fi
fi

# Determine the Terraform directory based on provider and regions
if [[ "$PROVIDER" == "aws" ]]; then
    if [[ "$REGIONS" == "single" ]]; then
        TF_DIR="TerraformAWS"
    else
        TF_DIR="TerraformAWS"
    fi
elif [[ "$PROVIDER" == "azure" ]]; then
    TF_DIR="TerraformAzure"
else
    echo -e "${RED}Error: Invalid provider specified. Use 'aws' or 'azure'.${NC}"
    exit 1
fi

# Create a temporary directory for state file if needed
if [[ -n "$STATE_FILE" ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
        echo -e "${RED}Error: Specified state file does not exist: $STATE_FILE${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Using provided state file: $STATE_FILE${NC}"
    
    # Create temp directory for state operations
    TEMP_DIR=$(mktemp -d)
    STATE_FILENAME=$(basename "$STATE_FILE")
    
    # Copy the state file to the temp directory
    cp "$STATE_FILE" "$TEMP_DIR/$STATE_FILENAME"
    
    # If the state file isn't named terraform.tfstate, rename it
    if [[ "$STATE_FILENAME" != "terraform.tfstate" ]]; then
        mv "$TEMP_DIR/$STATE_FILENAME" "$TEMP_DIR/terraform.tfstate"
    fi
fi

# Check if the Terraform directory exists
if [[ ! -d "$TF_DIR" ]]; then
    echo -e "${RED}Error: Terraform directory not found: $TF_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}Preparing to destroy infrastructure in $TF_DIR...${NC}"

# Navigate to the Terraform directory
cd "$TF_DIR"

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Copy the state file if provided
if [[ -n "$STATE_FILE" ]]; then
    # Copy the state file from temp directory
    cp "$TEMP_DIR/terraform.tfstate" .
    echo -e "${YELLOW}Terraform state file copied.${NC}"
fi

# Show what will be destroyed
echo -e "${YELLOW}Generating destroy plan...${NC}"
terraform plan -destroy -out=destroy.tfplan

# Confirm destruction if auto-approve is not set
if [[ "$AUTO_APPROVE" != "true" ]]; then
    echo -e "${RED}WARNING: This will destroy all resources managed by this Terraform configuration.${NC}"
    echo -e "${RED}There is NO UNDO. Resources will be permanently DELETED.${NC}"
    echo -e "${YELLOW}Do you really want to destroy all resources?${NC}"
    echo -e "  Type ${GREEN}yes${NC} to confirm."
    
    read -p "Enter response: " CONFIRMATION
    
    if [[ "$CONFIRMATION" != "yes" ]]; then
        echo -e "${YELLOW}Destruction aborted.${NC}"
        exit 0
    fi
fi

# Destroy resources
echo -e "${YELLOW}Destroying infrastructure...${NC}"
terraform apply destroy.tfplan

# Check if destroy was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Infrastructure successfully destroyed!${NC}"
    
    # Clean up state in parent directory if we were using a custom state
    if [[ -n "$STATE_FILE" ]]; then
        # If the directory has a terraform.tfstate, it's because we placed it there and should clean it up
        rm -f terraform.tfstate terraform.tfstate.backup
        rm -rf "$TEMP_DIR"
    fi
else
    echo -e "${RED}Failed to destroy infrastructure. Check the error messages above.${NC}"
    exit 1
fi

cd ..
echo -e "${GREEN}All done!${NC}"
exit 0