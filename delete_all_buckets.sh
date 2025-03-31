#!/bin/bash

# Get a list of all S3 buckets
buckets=$(aws s3 ls | awk '{print $3}')

if [ -z "$buckets" ]; then
    echo "No S3 buckets found."
    exit 0
fi

# Confirm before deletion
echo "WARNING: This will permanently delete all S3 buckets and their contents."
echo "Do you want to proceed? (yes/no)"
read confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Operation canceled."
    exit 1
fi

# Loop through each bucket and delete its contents and then the bucket
for bucket in $buckets; do
    echo "Deleting all object versions from bucket: $bucket"
    
    # Delete all versions using AWS CLI's built-in query
    echo "Checking for object versions..."
    versions=$(aws s3api list-object-versions --bucket "$bucket" --query 'Versions[*].[Key, VersionId]' --output text 2>/dev/null)
    
    if [ -n "$versions" ]; then
        echo "Deleting object versions..."
        echo "$versions" | while read -r key versionId; do
            if [ -n "$key" ] && [ -n "$versionId" ]; then
                echo "Deleting: $key (version: $versionId)"
                aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$versionId"
            fi
        done
    else
        echo "No object versions found."
    fi
    
    # Delete all delete markers
    echo "Checking for delete markers..."
    markers=$(aws s3api list-object-versions --bucket "$bucket" --query 'DeleteMarkers[*].[Key, VersionId]' --output text 2>/dev/null)
    
    if [ -n "$markers" ]; then
        echo "Deleting delete markers..."
        echo "$markers" | while read -r key versionId; do
            if [ -n "$key" ] && [ -n "$versionId" ]; then
                echo "Deleting marker: $key (version: $versionId)"
                aws s3api delete-object --bucket "$bucket" --key "$key" --version-id "$versionId"
            fi
        done
    else
        echo "No delete markers found."
    fi

    echo "Deleting bucket: $bucket"
    aws s3 rb s3://$bucket --force
done

echo "All S3 buckets deleted successfully."