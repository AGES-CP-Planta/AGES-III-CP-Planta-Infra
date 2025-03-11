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
ACTION="save"  # save or load
STORAGE_TYPE="s3"  # s3, azure, or github

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./save-terraform-state.sh [OPTIONS]${NC}"
    echo -e "Save or load Terraform state from a persistent storage location"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -r, --regions     Specify region mode (single or multi), default: single"
    echo -e "  -a, --action      Action to perform (save or load), default: save"
    echo -e "  -s, --storage     Storage type (s3, azure, or github), default: s3"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./save-terraform-state.sh --provider aws --regions single --action save --storage s3"
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
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -s|--storage)
            STORAGE_TYPE="$2"
            shift 2
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

# Set a bucket/container name based on provider
if [[ "$PROVIDER" == "aws" ]]; then
    if [[ -f .env ]]; then
        source .env
    fi
    # Create a bucket name using a consistent pattern
    BUCKET_NAME="cp-planta-terraform-state-${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
    BUCKET_REGION="${AWS_REGION:-us-east-2}"
    STATE_FILE_KEY="terraform-state/${TERRAFORM_DIR}/terraform.tfstate"
elif [[ "$PROVIDER" == "azure" ]]; then
    STORAGE_ACCOUNT="cpplantaterraformstate"
    CONTAINER_NAME="terraform-state"
    BLOB_NAME="${TERRAFORM_DIR}/terraform.tfstate"
fi

# GitHub-based storage variables
GITHUB_REPO="Saccilotto/AGES-III-CP-Planta-Infra"
GITHUB_BRANCH="terraform-state"
GITHUB_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"

# Check if we're in a GitHub Actions environment
if [[ -n "$GITHUB_ACTIONS" ]]; then
    echo -e "${YELLOW}Running in GitHub Actions environment${NC}"
    # In GitHub Actions, we can use the GitHub token for authentication
    GITHUB_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"
fi

# Function to create AWS S3 storage for state
function create_aws_s3_backend {
    echo -e "${YELLOW}Checking if S3 bucket exists: ${BUCKET_NAME}${NC}"
    if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
        echo -e "${YELLOW}Creating S3 bucket for Terraform state: ${BUCKET_NAME}${NC}"
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${BUCKET_REGION}" \
            --create-bucket-configuration LocationConstraint="${BUCKET_REGION}"
        
        # Enable versioning on the bucket
        aws s3api put-bucket-versioning \
            --bucket "${BUCKET_NAME}" \
            --versioning-configuration Status=Enabled
        
        # Add bucket encryption
        aws s3api put-bucket-encryption \
            --bucket "${BUCKET_NAME}" \
            --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
        
        echo -e "${GREEN}S3 bucket created and configured${NC}"
    else
        echo -e "${GREEN}S3 bucket already exists${NC}"
    fi
}

# Function to create Azure Storage for state
function create_azure_storage_backend {
    echo -e "${YELLOW}Checking if Azure Storage Account exists: ${STORAGE_ACCOUNT}${NC}"
    if ! az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "terraform-state" &>/dev/null; then
        echo -e "${YELLOW}Creating Azure Resource Group and Storage Account for Terraform state${NC}"
        az group create --name "terraform-state" --location "eastus"
        
        az storage account create \
            --name "${STORAGE_ACCOUNT}" \
            --resource-group "terraform-state" \
            --location "eastus" \
            --sku "Standard_LRS" \
            --encryption-services "blob"
        
        echo -e "${GREEN}Storage Account created${NC}"
    else
        echo -e "${GREEN}Storage Account already exists${NC}"
    fi
    
    # Create container if it doesn't exist
    az storage container create \
        --name "${CONTAINER_NAME}" \
        --account-name "${STORAGE_ACCOUNT}" \
        --auth-mode login
}

# Function to set up GitHub-based storage
function setup_github_storage {
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI not found. Installing...${NC}"
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
    fi
    
    # Authenticate with GitHub if token is provided
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "${GITHUB_TOKEN}" | gh auth login --with-token
    fi
    
    # Check if the branch exists
    if ! gh api repos/${GITHUB_REPO}/branches/${GITHUB_BRANCH} &>/dev/null; then
        echo -e "${YELLOW}Creating terraform-state branch in the repository${NC}"
        # Create a temporary directory
        TEMP_DIR=$(mktemp -d)
        cd "${TEMP_DIR}"
        
        # Clone the repository
        gh repo clone "${GITHUB_REPO}" .
        
        # Create a new orphan branch for storing terraform state
        git checkout --orphan "${GITHUB_BRANCH}"
        git rm -rf .
        echo "# Terraform State Files" > README.md
        git add README.md
        git config --local user.email "github-actions@github.com"
        git config --local user.name "GitHub Actions"
        git commit -m "Initialize terraform-state branch"
        git push origin "${GITHUB_BRANCH}"
        
        cd - > /dev/null
        rm -rf "${TEMP_DIR}"
        
        echo -e "${GREEN}Created terraform-state branch${NC}"
    else
        echo -e "${GREEN}Terraform state branch already exists${NC}"
    fi
}

# Save Terraform state to the selected storage
function save_terraform_state {
    if [[ "$STORAGE_TYPE" == "s3" ]]; then
        create_aws_s3_backend
        
        echo -e "${YELLOW}Saving Terraform state to S3: s3://${BUCKET_NAME}/${STATE_FILE_KEY}${NC}"
        aws s3 cp "${TERRAFORM_DIR}/terraform.tfstate" "s3://${BUCKET_NAME}/${STATE_FILE_KEY}"
        
        if [[ -f "${TERRAFORM_DIR}/terraform.tfstate.backup" ]]; then
            aws s3 cp "${TERRAFORM_DIR}/terraform.tfstate.backup" "s3://${BUCKET_NAME}/${STATE_FILE_KEY}.backup"
        fi
        
        echo -e "${GREEN}State saved to S3 successfully${NC}"
        
    elif [[ "$STORAGE_TYPE" == "azure" ]]; then
        create_azure_storage_backend
        
        echo -e "${YELLOW}Saving Terraform state to Azure Blob Storage: ${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${BLOB_NAME}${NC}"
        az storage blob upload \
            --account-name "${STORAGE_ACCOUNT}" \
            --container-name "${CONTAINER_NAME}" \
            --name "${BLOB_NAME}" \
            --file "${TERRAFORM_DIR}/terraform.tfstate" \
            --auth-mode login
        
        if [[ -f "${TERRAFORM_DIR}/terraform.tfstate.backup" ]]; then
            az storage blob upload \
                --account-name "${STORAGE_ACCOUNT}" \
                --container-name "${CONTAINER_NAME}" \
                --name "${BLOB_NAME}.backup" \
                --file "${TERRAFORM_DIR}/terraform.tfstate.backup" \
                --auth-mode login
        fi
        
        echo -e "${GREEN}State saved to Azure Blob Storage successfully${NC}"
        
    elif [[ "$STORAGE_TYPE" == "github" ]]; then
        setup_github_storage
        
        echo -e "${YELLOW}Saving Terraform state to GitHub${NC}"
        # Create a temporary directory
        TEMP_DIR=$(mktemp -d)
        cd "${TEMP_DIR}"
        
        # Clone only the terraform-state branch
        gh repo clone "${GITHUB_REPO}" --branch "${GITHUB_BRANCH}" .
        
        # Create directory structure if it doesn't exist
        mkdir -p "${TERRAFORM_DIR}"
        
        # Copy the state file
        cp "../../${TERRAFORM_DIR}/terraform.tfstate" "${TERRAFORM_DIR}/"
        if [[ -f "../../${TERRAFORM_DIR}/terraform.tfstate.backup" ]]; then
            cp "../../${TERRAFORM_DIR}/terraform.tfstate.backup" "${TERRAFORM_DIR}/"
        fi
        
        # Push the changes
        git add "${TERRAFORM_DIR}"
        git config --local user.email "github-actions@github.com"
        git config --local user.name "GitHub Actions"
        git commit -m "Update Terraform state for ${TERRAFORM_DIR}"
        git push
        
        cd - > /dev/null
        rm -rf "${TEMP_DIR}"
        
        echo -e "${GREEN}State saved to GitHub successfully${NC}"
    fi
}

# Load Terraform state from the selected storage
function load_terraform_state {
    if [[ "$STORAGE_TYPE" == "s3" ]]; then
        echo -e "${YELLOW}Loading Terraform state from S3: s3://${BUCKET_NAME}/${STATE_FILE_KEY}${NC}"
        
        # Check if the state file exists in S3
        if aws s3 ls "s3://${BUCKET_NAME}/${STATE_FILE_KEY}" &>/dev/null; then
            # Create the directory structure if it doesn't exist
            mkdir -p "${TERRAFORM_DIR}"
            
            # Download the state file
            aws s3 cp "s3://${BUCKET_NAME}/${STATE_FILE_KEY}" "${TERRAFORM_DIR}/terraform.tfstate"
            
            # Check if there's a backup and download it too
            if aws s3 ls "s3://${BUCKET_NAME}/${STATE_FILE_KEY}.backup" &>/dev/null; then
                aws s3 cp "s3://${BUCKET_NAME}/${STATE_FILE_KEY}.backup" "${TERRAFORM_DIR}/terraform.tfstate.backup"
            fi
            
            echo -e "${GREEN}State loaded from S3 successfully${NC}"
        else
            echo -e "${RED}Terraform state not found in S3${NC}"
            exit 1
        fi
        
    elif [[ "$STORAGE_TYPE" == "azure" ]]; then
        echo -e "${YELLOW}Loading Terraform state from Azure Blob Storage: ${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${BLOB_NAME}${NC}"
        
        # Check if the blob exists
        if az storage blob exists --account-name "${STORAGE_ACCOUNT}" --container-name "${CONTAINER_NAME}" --name "${BLOB_NAME}" --auth-mode login --query exists -o tsv | grep -q "True"; then
            # Create the directory structure if it doesn't exist
            mkdir -p "${TERRAFORM_DIR}"
            
            # Download the state file
            az storage blob download \
                --account-name "${STORAGE_ACCOUNT}" \
                --container-name "${CONTAINER_NAME}" \
                --name "${BLOB_NAME}" \
                --file "${TERRAFORM_DIR}/terraform.tfstate" \
                --auth-mode login
            
            # Check if there's a backup and download it too
            if az storage blob exists --account-name "${STORAGE_ACCOUNT}" --container-name "${CONTAINER_NAME}" --name "${BLOB_NAME}.backup" --auth-mode login --query exists -o tsv | grep -q "True"; then
                az storage blob download \
                    --account-name "${STORAGE_ACCOUNT}" \
                    --container-name "${CONTAINER_NAME}" \
                    --name "${BLOB_NAME}.backup" \
                    --file "${TERRAFORM_DIR}/terraform.tfstate.backup" \
                    --auth-mode login
            fi
            
            echo -e "${GREEN}State loaded from Azure Blob Storage successfully${NC}"
        else
            echo -e "${RED}Terraform state not found in Azure Blob Storage${NC}"
            exit 1
        fi
        
    elif [[ "$STORAGE_TYPE" == "github" ]]; then
        echo -e "${YELLOW}Loading Terraform state from GitHub${NC}"
        
        # Create a temporary directory
        TEMP_DIR=$(mktemp -d)
        cd "${TEMP_DIR}"
        
        # Try to clone only the terraform-state branch
        if ! gh repo clone "${GITHUB_REPO}" --branch "${GITHUB_BRANCH}" . 2>/dev/null; then
            echo -e "${RED}Failed to clone terraform-state branch. Make sure it exists and you have access.${NC}"
            cd - > /dev/null
            rm -rf "${TEMP_DIR}"
            exit 1
        fi
        
        # Check if the state file exists
        if [[ -f "${TERRAFORM_DIR}/terraform.tfstate" ]]; then
            # Create the directory structure if it doesn't exist
            mkdir -p "../../${TERRAFORM_DIR}"
            
            # Copy the state file
            cp "${TERRAFORM_DIR}/terraform.tfstate" "../../${TERRAFORM_DIR}/"
            if [[ -f "${TERRAFORM_DIR}/terraform.tfstate.backup" ]]; then
                cp "${TERRAFORM_DIR}/terraform.tfstate.backup" "../../${TERRAFORM_DIR}/"
            fi
            
            cd - > /dev/null
            rm -rf "${TEMP_DIR}"
            
            echo -e "${GREEN}State loaded from GitHub successfully${NC}"
        else
            echo -e "${RED}Terraform state not found in GitHub repository${NC}"
            cd - > /dev/null
            rm -rf "${TEMP_DIR}"
            exit 1
        fi
    fi
}

# Perform the requested action
if [[ "$ACTION" == "save" ]]; then
    save_terraform_state
elif [[ "$ACTION" == "load" ]]; then
    load_terraform_state
else
    echo -e "${RED}Invalid action: ${ACTION}. Must be 'save' or 'load'.${NC}"
    show_help
    exit 1
fi

echo -e "${GREEN}Operation completed successfully!${NC}"
exit 0