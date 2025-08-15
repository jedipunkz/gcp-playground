# Makefile for GCP Cloud SQL HA Configurations
# Usage: make <target>

# Configuration directories
TERRAFORM_DIRS := regional-ha read-replica cross-region-replica read-replica-autoscaling connection-pooling-lb enhanced-backup

# Default target
.PHONY: all
all: help

# Help target
.PHONY: help
help:
	@echo "GCP Cloud SQL HA Configuration Management"
	@echo ""
	@echo "Available targets:"
	@echo "  help                    - Show this help message"
	@echo "  init                    - Run terraform init in all directories"
	@echo "  validate                - Run terraform validate in all directories"
	@echo "  plan                    - Run terraform plan in all directories"
	@echo "  diagrams                - Generate PNG diagrams from all .mmd files"
	@echo "  clean                   - Clean terraform files (.terraform, *.tfstate, etc.)"
	@echo "  setup                   - Run init + validate + diagrams for all configurations"
	@echo ""
	@echo "Per-directory targets:"
	@echo "  init-<dir>              - Run terraform init for specific directory"
	@echo "  validate-<dir>          - Run terraform validate for specific directory"
	@echo "  plan-<dir>              - Run terraform plan for specific directory"
	@echo "  diagram-<dir>           - Generate PNG diagram for specific directory"
	@echo ""
	@echo "Available directories: $(TERRAFORM_DIRS)"
	@echo ""
	@echo "Example usage:"
	@echo "  make setup              - Initialize, validate all configs and generate diagrams"
	@echo "  make init-regional-ha   - Initialize only regional-ha configuration"
	@echo "  make diagrams           - Generate all PNG diagrams"

# Initialize all terraform configurations
.PHONY: init
init:
	@echo "Initializing all Terraform configurations..."
	@for dir in $(TERRAFORM_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "Initializing $$dir..."; \
			(cd "$$dir" && terraform init) || exit 1; \
		else \
			echo "Directory $$dir does not exist, skipping..."; \
		fi; \
	done
	@echo "All configurations initialized."

# Validate all terraform configurations
.PHONY: validate
validate:
	@echo "Validating all Terraform configurations..."
	@for dir in $(TERRAFORM_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "Validating $$dir..."; \
			(cd "$$dir" && terraform validate) || exit 1; \
		else \
			echo "Directory $$dir does not exist, skipping..."; \
		fi; \
	done
	@echo "All configurations validated."

# Plan all terraform configurations
.PHONY: plan
plan:
	@echo "Planning all Terraform configurations..."
	@for dir in $(TERRAFORM_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "Planning $$dir..."; \
			if [ -f "$$dir/terraform.tfvars" ]; then \
				(cd "$$dir" && terraform plan) || exit 1; \
			else \
				echo "No terraform.tfvars found in $$dir. Please copy terraform.tfvars.example to terraform.tfvars and configure it."; \
			fi; \
		else \
			echo "Directory $$dir does not exist, skipping..."; \
		fi; \
	done
	@echo "All configurations planned."

# Generate PNG diagrams from Mermaid files
.PHONY: diagrams
diagrams:
	@echo "Generating PNG diagrams from Mermaid files..."
	@if ! command -v mmdc >/dev/null 2>&1; then \
		echo "Error: mermaid-cli (mmdc) is not installed."; \
		echo "Please install it with: npm install -g @mermaid-js/mermaid-cli"; \
		exit 1; \
	fi
	@for dir in $(TERRAFORM_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "Processing $$dir..."; \
			(cd "$$dir" && \
			for mmd_file in *.mmd; do \
				if [ -f "$$mmd_file" ]; then \
					echo "  Converting $$mmd_file to PNG..."; \
					mmdc -i "$$mmd_file" -o diagram.png -t dark -b transparent -w 1600 -H 1200 --scale 1.5; \
				fi; \
			done) || exit 1; \
		fi; \
	done
	@echo "All diagrams generated."

# Clean terraform files
.PHONY: clean
clean:
	@echo "Cleaning Terraform files..."
	@for dir in $(TERRAFORM_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "Cleaning $$dir..."; \
			(cd "$$dir" && rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup); \
		fi; \
	done
	@echo "Cleanup completed."

# Setup target: init + validate + diagrams
.PHONY: setup
setup: init validate diagrams
	@echo "Setup completed for all configurations."

# Per-directory targets
define TERRAFORM_RULES
.PHONY: init-$(1)
init-$(1):
	@if [ -d "$(1)" ]; then \
		echo "Initializing $(1)..."; \
		cd "$(1)" && terraform init; \
	else \
		echo "Directory $(1) does not exist."; \
		exit 1; \
	fi

.PHONY: validate-$(1)
validate-$(1):
	@if [ -d "$(1)" ]; then \
		echo "Validating $(1)..."; \
		cd "$(1)" && terraform validate; \
	else \
		echo "Directory $(1) does not exist."; \
		exit 1; \
	fi

.PHONY: plan-$(1)
plan-$(1):
	@if [ -d "$(1)" ]; then \
		echo "Planning $(1)..."; \
		if [ -f "$(1)/terraform.tfvars" ]; then \
			cd "$(1)" && terraform plan; \
		else \
			echo "No terraform.tfvars found in $(1). Please copy terraform.tfvars.example to terraform.tfvars and configure it."; \
			exit 1; \
		fi; \
	else \
		echo "Directory $(1) does not exist."; \
		exit 1; \
	fi

.PHONY: diagram-$(1)
diagram-$(1):
	@if [ -d "$(1)" ]; then \
		echo "Generating diagram for $(1)..."; \
		if ! command -v mmdc >/dev/null 2>&1; then \
			echo "Error: mermaid-cli (mmdc) is not installed."; \
			echo "Please install it with: npm install -g @mermaid-js/mermaid-cli"; \
			exit 1; \
		fi; \
		cd "$(1)"; \
		for mmd_file in *.mmd; do \
			if [ -f "$$$$mmd_file" ]; then \
				echo "  Converting $$$$mmd_file to PNG..."; \
				mmdc -i "$$$$mmd_file" -o diagram.png -t dark -b transparent -w 1600 -H 1200 --scale 1.5; \
			fi; \
		done; \
	else \
		echo "Directory $(1) does not exist."; \
		exit 1; \
	fi
endef

# Generate rules for each directory
$(foreach dir,$(TERRAFORM_DIRS),$(eval $(call TERRAFORM_RULES,$(dir))))

# Additional utility targets
.PHONY: check-requirements
check-requirements:
	@echo "Checking requirements..."
	@command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is not installed."; exit 1; }
	@command -v mmdc >/dev/null 2>&1 || { echo "Warning: mermaid-cli (mmdc) is not installed. Diagram generation will not work."; }
	@echo "Requirements check completed."

.PHONY: list-configs
list-configs:
	@echo "Available configurations:"
	@for dir in $(TERRAFORM_DIRS); do \
		if [ -d "$$dir" ]; then \
			echo "  ✓ $$dir"; \
		else \
			echo "  ✗ $$dir (missing)"; \
		fi; \
	done

.PHONY: status
status:
	@echo "Configuration Status:"
	@for dir in $(TERRAFORM_DIRS); do \
		if [ -d "$$dir" ]; then \
			printf "  %-25s " "$$dir:"; \
			if [ -d "$$dir/.terraform" ]; then \
				printf "initialized "; \
			else \
				printf "not-init   "; \
			fi; \
			if [ -f "$$dir/terraform.tfvars" ]; then \
				printf "configured "; \
			else \
				printf "no-tfvars  "; \
			fi; \
			if [ -f "$$dir/diagram.png" ]; then \
				printf "has-diagram"; \
			else \
				printf "no-diagram "; \
			fi; \
			echo ""; \
		fi; \
	done