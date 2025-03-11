#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROVIDER="aws"
REGIONS="single"
STORAGE_TYPE="s3"
INTERACTIVE=true

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./destroy-infrastructure.sh [OPTIONS]${NC}"
    echo -e "Destroy infrastructure created by Terraform"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -r, --regions     Specify region mode (single or multi), default: single"
    echo -e "  -s, --storage     Storage type for state (s3, azure, or github), default: s3"
    echo -e "  --no-interactive  Run in non-interactive mode (auto-approve destruction)"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./destroy-infrastructure.sh --provider aws --regions single --storage s3"
}

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
        -s|--storage)
            STORAGE_TYPE="$2"
            shift 2
            ;;
        --no-interactive)
            INTERACTIVE=false
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

# Set terraform directory based on provider and regions
if [[ "$PROVIDER" == "aws" ]]; then
    if [[ "$REGIONS" == "single" ]]; then
        TERRAFORM_DIR="SimpleTerraformAWS"
    else
        TERRAFORM_DIR="TerraformAWS"
    fi
elif [[ "$PROVIDER" == "azure" ]]; then
    TERRAFORM_DIR="TerraformAzure"
fi

# Check if the directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}Error: Terraform directory $TERRAFORM_DIR does not exist.${NC}"
    exit 1
fi

# Load the state from remote storage
echo -e "${YELLOW}Loading Terraform state from remote storage...${NC}"
./save-terraform-state.sh --provider "$PROVIDER" --regions "$REGIONS" --action load --storage "$STORAGE_TYPE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to load Terraform state from remote storage. Cannot continue with destroy operation.${NC}"
    exit 1
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform initialization failed. Cannot continue with destroy operation.${NC}"
    exit 1
fi

# Show what will be destroyed
echo -e "${YELLOW}Showing resources that will be destroyed:${NC}"
terraform plan -destroy

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform plan failed. Cannot continue with destroy operation.${NC}"
    exit 1
fi

# Ask for confirmation if in interactive mode
if [[ "$INTERACTIVE" == "true" ]]; then
    echo -e "${RED}WARNING: This will destroy all resources managed by Terraform. This action cannot be undone.${NC}"
    read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
    
    if [[ "$CONFIRM" != "yes" ]]; then
        echo -e "${YELLOW}Destruction canceled.${NC}"
        exit 0
    fi
fi

# Destroy infrastructure
echo -e "${YELLOW}Destroying infrastructure...${NC}"
if [[ "$INTERACTIVE" == "true" ]]; then
    terraform destroy
else
    terraform destroy -auto-approve
fi

DESTROY_EXIT_CODE=$?

# Return to project root
cd ..

# If destroy was successful, save the updated (empty) state back to remote storage
if [ $DESTROY_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Infrastructure destroyed successfully.${NC}"
    echo -e "${YELLOW}Saving updated Terraform state to remote storage...${NC}"
    ./save-terraform-state.sh --provider "$PROVIDER" --regions "$REGIONS" --action save --storage "$STORAGE_TYPE"
    
    # Clean up local state files
    echo -e "${YELLOW}Cleaning up local state files...${NC}"
    rm -f "$TERRAFORM_DIR/terraform.tfstate" "$TERRAFORM_DIR/terraform.tfstate.backup"
    
    # Clean up any generated SSH keys
    echo -e "${YELLOW}Cleaning up generated SSH keys...${NC}"
    rm -f ssh_keys/*.pem
    
    echo -e "${GREEN}Cleanup completed.${NC}"
else
    echo -e "${RED}Terraform destroy failed. Please check the error messages above.${NC}"
fi

exit $DESTROY_EXIT_CODE