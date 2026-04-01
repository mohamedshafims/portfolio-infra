#!/bin/bash
# =============================================================================
# Deploy Website to S3 and Recreate EC2 Instances
# =============================================================================
# This script uploads website files to S3 and recreates EC2 instances
# to pull the latest changes (user_data runs on instance launch).
#
# Usage: ./deploy-website.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
WEBSITE_DIR="${SCRIPT_DIR}/website"

echo "🚀 Deploying portfolio website..."
echo ""

# Step 1: Get S3 bucket name from Terraform outputs
echo "📦 Getting S3 bucket name..."
cd "${TERRAFORM_DIR}"
S3_BUCKET=$(terraform output -raw s3_bucket_name)

if [ -z "${S3_BUCKET}" ]; then
    echo "❌ Error: Could not get S3 bucket name from Terraform outputs"
    echo "   Make sure you have run 'terraform apply' first."
    exit 1
fi

echo "   S3 Bucket: ${S3_BUCKET}"
echo ""

# Step 2: Upload website files to S3
echo "📤 Uploading website files to S3..."
cd "${WEBSITE_DIR}"
aws s3 sync . "s3://${S3_BUCKET}/website/" --exclude ".DS_Store"

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to upload files to S3"
    exit 1
fi

echo "   ✅ Files uploaded successfully!"
echo ""

# Step 3: Verify upload
echo "🔍 Verifying uploaded files..."
aws s3 ls "s3://${S3_BUCKET}/website/" --recursive
echo ""

# Step 4: Get ASG name
echo "🖥️  Finding Auto Scaling Group..."
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
    --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `shafi-portfolio`)].AutoScalingGroupName' \
    --output text)

if [ -z "${ASG_NAME}" ]; then
    echo "   No ASG found. Skipping instance recreation."
    echo ""
else
    echo "   ASG Name: ${ASG_NAME}"
    
    # Get current instance IDs
    INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "${ASG_NAME}" \
        --query 'Instances[*].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${INSTANCE_IDS}" ] || [ "${INSTANCE_IDS}" = "None" ]; then
        echo "   No running instances found. ASG will launch new instance automatically."
        echo ""
    else
        echo "   Current Instances: ${INSTANCE_IDS}"
        echo ""
        
        # Step 5: Terminate instances (ASG will create new ones)
        echo "🔄 Terminating EC2 instances (ASG will launch new ones)..."
        for INSTANCE_ID in ${INSTANCE_IDS}; do
            echo "   Terminating ${INSTANCE_ID}..."
            aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}"
        done
        
        echo "   ✅ Instances terminating!"
        echo ""
        echo "   ⏳ Waiting 90 seconds for new instance to launch and initialize..."
    fi
fi

# Step 6: Wait for new instance
sleep 90

# Step 7: Get website URL
echo ""
echo "🌐 Website URL:"
WEBSITE_URL=$(terraform output -raw website_url)
echo "   ${WEBSITE_URL}"
echo ""

echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Visit: ${WEBSITE_URL}"
echo "2. If you see 'Welcome to nginx', wait another 30 seconds and refresh"
echo "3. Force refresh in browser: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)"
