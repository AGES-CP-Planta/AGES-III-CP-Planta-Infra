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
ACTION="check"  # check, import, delete, rename
TERRAFORM_DIR=""

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./check-existing-resources.sh [OPTIONS]${NC}"
    echo -e "Check, import, or clean up existing cloud resources before Terraform deployment"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -r, --regions     Specify region mode (single or multi), default: single"
    echo -e "  -a, --action      Action to perform (check, import, delete, rename), default: check"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./check-existing-resources.sh --provider aws --regions single --action import"
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
        TERRAFORM_DIR="TerraformAWS"
    else
        TERRAFORM_DIR=""
    fi
elif [[ "$PROVIDER" == "azure" ]]; then
    TERRAFORM_DIR="TerraformAzure"
fi

# Check if directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}Error: Terraform directory $TERRAFORM_DIR does not exist.${NC}"
    exit 1
fi

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Check for AWS key pairs
if [[ "$PROVIDER" == "aws" ]]; then
    echo -e "${YELLOW}Checking for existing AWS key pairs...${NC}"
    
    # Get instance names from variables.tf (for single region)
    if [[ "$REGIONS" == "single" ]]; then
        # Extract instance names array from variables.tf
        INSTANCE_NAMES=$(grep -A5 'variable "instance_names"' variables.tf | grep 'default' | sed 's/.*default.*\[\(.*\)\].*/\1/' | sed 's/"//g' | sed 's/,/ /g')
        REGION=$(grep -A2 'variable "region"' variables.tf | grep 'default' | sed 's/.*default.*"\(.*\)".*/\1/')
        
        # Check for each key pair
        for instance in $INSTANCE_NAMES; do
            KEY_NAME="${instance}-key"
            echo -e "Checking for key pair: ${BLUE}$KEY_NAME${NC} in region ${BLUE}$REGION${NC}"
            
            # Check if key pair exists
            KEY_EXISTS=$(aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" 2>/dev/null)
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Key pair $KEY_NAME exists${NC}"
                
                # Perform action based on specified option
                case "$ACTION" in
                    check)
                        echo -e "${YELLOW}Key pair $KEY_NAME exists and might cause conflicts during Terraform apply${NC}"
                        ;;
                    import)
                        echo -e "${YELLOW}Importing key pair $KEY_NAME into Terraform state...${NC}"
                        terraform state rm "aws_key_pair.generated_key[\"$instance\"]" 2>/dev/null
                        terraform import "aws_key_pair.generated_key[\"$instance\"]" "$KEY_NAME"
                        ;;
                    delete)
                        echo -e "${YELLOW}Deleting key pair $KEY_NAME...${NC}"
                        aws ec2 delete-key-pair --region "$REGION" --key-name "$KEY_NAME"
                        ;;
                    rename)
                        NEW_KEY_NAME="${KEY_NAME}-$(date +%s)"
                        echo -e "${YELLOW}Cannot directly rename key pairs in AWS. Recommend using delete or import actions.${NC}"
                        ;;
                esac
            else
                echo -e "${BLUE}Key pair $KEY_NAME does not exist${NC}"
            fi
        done
    else
        # For multi-region setup
        PRIMARY_REGION=$(grep -A2 'variable "primary_region"' variables.tf | grep 'default' | sed 's/.*default.*"\(.*\)".*/\1/')
        SECONDARY_REGION=$(grep -A2 'variable "secondary_region"' variables.tf | grep 'default' | sed 's/.*default.*"\(.*\)".*/\1/')
        
        # Extract instance names for each region
        INSTANCE_NAMES=$(grep -A10 'variable "instance_names"' variables.tf | grep -A10 'default' | grep -o '"[^"]*"' | sed 's/"//g')
        
        # Check primary region instances
        echo -e "${YELLOW}Checking primary region ($PRIMARY_REGION) key pairs...${NC}"
        for instance in $INSTANCE_NAMES; do
            KEY_NAME="${instance}-key"
            echo -e "Checking for key pair: ${BLUE}$KEY_NAME${NC} in region ${BLUE}$PRIMARY_REGION${NC}"
            
            # Check if key pair exists in primary region
            KEY_EXISTS=$(aws ec2 describe-key-pairs --region "$PRIMARY_REGION" --key-names "$KEY_NAME" 2>/dev/null)
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Key pair $KEY_NAME exists in $PRIMARY_REGION${NC}"
                
                # Perform action based on specified option
                case "$ACTION" in
                    check)
                        echo -e "${YELLOW}Key pair $KEY_NAME exists and might cause conflicts during Terraform apply${NC}"
                        ;;
                    import)
                        echo -e "${YELLOW}Importing key pair $KEY_NAME into Terraform state...${NC}"
                        terraform state rm "aws_key_pair.primary_key_pair[\"$instance\"]" 2>/dev/null
                        terraform import "aws_key_pair.primary_key_pair[\"$instance\"]" "$KEY_NAME"
                        ;;
                    delete)
                        echo -e "${YELLOW}Deleting key pair $KEY_NAME from $PRIMARY_REGION...${NC}"
                        aws ec2 delete-key-pair --region "$PRIMARY_REGION" --key-name "$KEY_NAME"
                        ;;
                    rename)
                        echo -e "${YELLOW}Cannot directly rename key pairs in AWS. Recommend using delete or import actions.${NC}"
                        ;;
                esac
            else
                echo -e "${BLUE}Key pair $KEY_NAME does not exist in $PRIMARY_REGION${NC}"
            fi
        done
        
        # Check secondary region instances
        echo -e "${YELLOW}Checking secondary region ($SECONDARY_REGION) key pairs...${NC}"
        for instance in $INSTANCE_NAMES; do
            KEY_NAME="${instance}-key"
            echo -e "Checking for key pair: ${BLUE}$KEY_NAME${NC} in region ${BLUE}$SECONDARY_REGION${NC}"
            
            # Check if key pair exists in secondary region
            KEY_EXISTS=$(aws ec2 describe-key-pairs --region "$SECONDARY_REGION" --key-names "$KEY_NAME" 2>/dev/null)
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}Key pair $KEY_NAME exists in $SECONDARY_REGION${NC}"
                
                # Perform action based on specified option
                case "$ACTION" in
                    check)
                        echo -e "${YELLOW}Key pair $KEY_NAME exists and might cause conflicts during Terraform apply${NC}"
                        ;;
                    import)
                        echo -e "${YELLOW}Importing key pair $KEY_NAME into Terraform state...${NC}"
                        terraform state rm "aws_key_pair.secondary_key_pair[\"$instance\"]" 2>/dev/null
                        terraform import "aws_key_pair.secondary_key_pair[\"$instance\"]" "$KEY_NAME"
                        ;;
                    delete)
                        echo -e "${YELLOW}Deleting key pair $KEY_NAME from $SECONDARY_REGION...${NC}"
                        aws ec2 delete-key-pair --region "$SECONDARY_REGION" --key-name "$KEY_NAME"
                        ;;
                    rename)
                        echo -e "${YELLOW}Cannot directly rename key pairs in AWS. Recommend using delete or import actions.${NC}"
                        ;;
                esac
            else
                echo -e "${BLUE}Key pair $KEY_NAME does not exist in $SECONDARY_REGION${NC}"
            fi
        done
    fi
elif [[ "$PROVIDER" == "azure" ]]; then
    echo -e "${YELLOW}Checking for existing Azure resources...${NC}"
    # Azure resource checking logic would go here
    echo -e "${BLUE}Azure resource checking not implemented yet${NC}"
fi

# Return to original directory
cd ..

echo -e "${GREEN}Resource check complete!${NC}"
exit 0