#!/bin/bash

set -e

echo "========== Applying Jenkins configuration =========="
kubectl apply -k ~/k3s/

echo "========== Waiting for PVC to be bound =========="
kubectl wait --for=condition=Bound pvc/jenkins-home -n jenkins --timeout=30s 2>/dev/null || true

echo "========== Waiting for Jenkins pod to start =========="
sleep 30

echo "========== Waiting for Jenkins to be ready (2-3 minutes) =========="
kubectl wait --for=condition=Ready pod -l app=jenkins -n jenkins --timeout=300s

echo "========== Waiting for TLS certificate generation =========="
sleep 60

echo "========== Verification =========="
echo "Jenkins pods:"
kubectl get pods -n jenkins

echo ""
echo "Jenkins Ingress:"
kubectl get ingress -n jenkins

echo ""
echo "✓ Jenkins is deployed!"
echo "✓ Access at: https://jenkins.jonathanlore.fr"