#!/bin/bash
# Quick deployment script for Kubernetes monitoring stack
# Usage: ./deploy.sh [local-path|longhorn]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default storage class
STORAGE_CLASS="${1:-local-path}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes Monitoring Stack Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Validate storage class argument
if [[ ! "$STORAGE_CLASS" =~ ^(local-path|longhorn)$ ]]; then
    echo -e "${RED}Error: Invalid storage class '$STORAGE_CLASS'${NC}"
    echo "Usage: $0 [local-path|longhorn]"
    exit 1
fi

echo -e "${YELLOW}Storage class: $STORAGE_CLASS${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# Check storage class exists
if ! kubectl get storageclass "$STORAGE_CLASS" &> /dev/null; then
    echo -e "${RED}Error: StorageClass '$STORAGE_CLASS' not found${NC}"
    echo "Available storage classes:"
    kubectl get storageclass
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Warn about default password
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}SECURITY WARNING${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "The default Grafana password is set to 'changeme-use-strong-password'"
echo ""
read -p "Have you changed the password in base/grafana/secret.yaml? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Please change the password before deploying!${NC}"
    echo "Edit: base/grafana/secret.yaml"
    echo "Change: GF_SECURITY_ADMIN_PASSWORD"
    exit 1
fi

echo ""
echo -e "${GREEN}Deploying monitoring stack...${NC}"
echo ""

# Deploy
kubectl apply -k "overlays/$STORAGE_CLASS"

echo ""
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
echo "This may take a few minutes..."
echo ""

# Wait for Prometheus
echo -n "Waiting for Prometheus... "
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

# Wait for Grafana
echo -n "Waiting for Grafana... "
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

# Wait for Alertmanager
echo -n "Waiting for Alertmanager... "
kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=300s && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

# Wait for Loki
echo -n "Waiting for Loki... "
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get pod status
echo "Pod Status:"
kubectl get pods -n monitoring
echo ""

# Get PVC status
echo "PVC Status:"
kubectl get pvc -n monitoring
echo ""

# Get Ingress info
echo "Access URLs:"
kubectl get ingress -n monitoring -o custom-columns=NAME:.metadata.name,HOST:.spec.rules[0].host,PATH:.spec.rules[0].http.paths[0].path
echo ""

# Get Grafana password reminder
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Login Information${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Grafana:"
echo "  URL: http://grafana.192.168.2.207.nip.io"
echo "  Username: admin"
echo "  Password: (the one you set in base/grafana/secret.yaml)"
echo ""
echo "Prometheus:"
echo "  URL: http://prometheus.192.168.2.207.nip.io"
echo ""
echo "Alertmanager:"
echo "  URL: http://alertmanager.192.168.2.207.nip.io"
echo ""

# Discord webhook reminder
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Next Steps${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "1. Configure Discord webhook (optional):"
echo "   kubectl edit configmap alertmanager-config -n monitoring"
echo "   Replace: DISCORD_WEBHOOK_URL"
echo ""
echo "2. Import Grafana dashboards:"
echo "   - Kubernetes Cluster: ID 15757"
echo "   - Node Exporter: ID 1860"
echo "   - Loki Dashboard: ID 13639"
echo ""
echo "3. Verify Prometheus targets:"
echo "   http://prometheus.192.168.2.207.nip.io/targets"
echo ""
echo "4. View logs in Grafana:"
echo "   Explore → Select Loki datasource"
echo ""
echo -e "${GREEN}For troubleshooting, see: DEPLOYMENT.md${NC}"
echo ""
