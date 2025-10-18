#!/bin/bash

set -e

echo "========== WARNING: This will delete Jenkins completely =========="
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

echo "========== Deleting Jenkins namespace =========="
kubectl delete namespace jenkins --ignore-not-found=true

echo "========== Waiting for namespace deletion =========="
sleep 15

echo "========== Verifying everything is deleted =========="
kubectl get all -n jenkins 2>/dev/null && echo "WARNING: Jenkins still exists!" || echo "✓ Jenkins deleted"

echo ""
echo "========== Ready to redeploy =========="
echo "Run: ~/k3s/deploy.sh"