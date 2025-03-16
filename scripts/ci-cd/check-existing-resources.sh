#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROVIDER="aws"
ACTION="check"  # check, import, delete, rename
TERRAFORM_DIR=""

# Help function
function show_help {
    echo -e "${BLUE}Usage: ./check-existing-resources.sh [OPTIONS]${NC}"
    echo -e "Check, import, or clean up existing cloud resources before Terraform deployment"
    echo ""
    echo -e "Options:"
    echo -e "  -p, --provider    Specify cloud provider (aws or azure), default: aws"
    echo -e "  -a, --action      Action to perform (check, import, delete, rename), default: check"
    echo -e "  -h, --help        Show this help message"
    echo ""
    echo -e "Example: ./check-existing-resources.sh --provider aws --action import"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
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

# Set terraform directory based on provider
if [[ "$PROVIDER" == "aws" ]]; then
    TERRAFORM_DIR="TerraformAWS"
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
elif [[ "$PROVIDER" == "azure" ]]; then
    echo -e "${YELLOW}Checking for existing Azure resources...${NC}"
    
    # Extract VM names from variables.tf
    VM_NAMES=$(grep -A5 'variable "vm_names"' variables.tf | grep 'default' | sed 's/.*default.*\[\(.*\)\].*/\1/' | sed 's/"//g' | sed 's/,/ /g')
    RESOURCE_GROUP=$(grep -A2 'variable "resource_group_name"' variables.tf | grep 'default' | sed 's/.*default.*"\(.*\)".*/\1/')
    
    # First check if the resource group exists
    echo -e "Checking for resource group: ${BLUE}$RESOURCE_GROUP${NC}"
    RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP")
    
    if [[ "$RG_EXISTS" == "true" ]]; then
        echo -e "${GREEN}Resource group $RESOURCE_GROUP exists${NC}"
        
        # Check for VMs in the resource group
        for vm in $VM_NAMES; do
            echo -e "Checking for VM: ${BLUE}$vm${NC} in resource group ${BLUE}$RESOURCE_GROUP${NC}"
            
            # Check if VM exists
            VM_EXISTS=$(az vm show --resource-group "$RESOURCE_GROUP" --name "$vm" --query "name" 2>/dev/null)
            
            if [[ -n "$VM_EXISTS" ]]; then
                echo -e "${GREEN}VM $vm exists${NC}"
                
                # Perform action based on specified option
                case "$ACTION" in
                    check)
                        echo -e "${YELLOW}VM $vm exists and might cause conflicts during Terraform apply${NC}"
                        ;;
                    import)
                        echo -e "${YELLOW}Importing VM $vm into Terraform state...${NC}"
                        terraform state rm "azurerm_linux_virtual_machine.vm[\"$vm\"]" 2>/dev/null
                        terraform import "azurerm_linux_virtual_machine.vm[\"$vm\"]" "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$vm"
                        ;;
                    delete)
                        echo -e "${YELLOW}Deleting VM $vm...${NC}"
                        az vm delete --resource-group "$RESOURCE_GROUP" --name "$vm" --yes
                        ;;
                    rename)
                        echo -e "${YELLOW}Cannot directly rename VMs in Azure. Recommend using delete or import actions.${NC}"
                        ;;
                esac
            else
                echo -e "${BLUE}VM $vm does not exist${NC}"
            fi
        done
        
        # Optionally check for other resources like NSGs, NICs, etc.
        echo -e "${YELLOW}Checking for network security group in $RESOURCE_GROUP...${NC}"
        NSG_EXISTS=$(az network nsg list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'cp-planta-nsg')].name" -o tsv)
        
        if [[ -n "$NSG_EXISTS" ]]; then
            echo -e "${GREEN}Network security group $NSG_EXISTS exists${NC}"
            
            case "$ACTION" in
                check)
                    echo -e "${YELLOW}NSG $NSG_EXISTS exists and might cause conflicts during Terraform apply${NC}"
                    ;;
                import)
                    echo -e "${YELLOW}Importing NSG $NSG_EXISTS into Terraform state...${NC}"
                    terraform state rm "azurerm_network_security_group.nsg" 2>/dev/null
                    terraform import "azurerm_network_security_group.nsg" "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/networkSecurityGroups/$NSG_EXISTS"
                    ;;
                delete)
                    echo -e "${YELLOW}Deleting NSG $NSG_EXISTS...${NC}"
                    az network nsg delete --resource-group "$RESOURCE_GROUP" --name "$NSG_EXISTS"
                    ;;
            esac
        else
            echo -e "${BLUE}No matching network security group found${NC}"
        fi
    else
        echo -e "${BLUE}Resource group $RESOURCE_GROUP does not exist${NC}"
    fi
fi

cd ..

echo -e "${GREEN}Resource check complete!${NC}"
exit 0