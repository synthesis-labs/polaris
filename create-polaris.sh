#!/bin/bash
export KUBECONFIG=/root/.kube/config
export AWS_REGION=${REGION}
export AWS_DEFAULT_REGION=${REGION}
export KOPS_STATE_STORE=s3://${STATE_BUCKET}
echo 'AWS_REGION: ' ${AWS_REGION}
echo 'KOPS_STATE_STORE: ' ${KOPS_STATE_STORE}

# helm --tiller-connection-timeout 900

echo 'Getting certificate name from AWS'
TEMP_CRT_NAME=$(aws s3 ls ${KOPS_STATE_STORE}/${CLUSTER_NAME}/pki/issued/ca/ --recursive | awk '{print $4}' | grep -o [0-9]*.crt)
echo 'Certificate: '$TEMP_CRT_NAME
echo 'Making certificate public'
aws s3api put-object-acl --bucket kops-mimic --key ${CLUSTER_NAME}'/pki/issued/ca/'${TEMP_CRT_NAME} --acl public-read


TEMP_CRT_CREDS=$(cat dex/ca/dex-ca-cert.pem | base64 -w 0)
TEMP_CRT_NAME_ESCAPED=$(echo $TEMP_CRT_NAME | sed 's/\//\\\//g')

sed -i 's/<<CLUSTERNAME>>/'${CLUSTER_NAME}'/g' charts/polaris/values.yaml
sed -i 's/<<CLUSTERDESCRIPTION>>/'${CLUSTER_SHORT_DESCRIPTION}'/g' charts/polaris/values.yaml
sed -i 's/<<DEX_BASE64>>/'${TEMP_CRT_CREDS}'/g' charts/polaris/values.yaml
sed -i 's/<<DEX_CRT>>/https:\/\/s3-eu-west-1.amazonaws.com\/'${STATE_BUCKET}'\/'${CLUSTER_NAME}'\/pki\/issued\/ca\/'${TEMP_CRT_NAME_ESCAPED}'/g' charts/polaris/values.yaml

sed -i 's/<<CLUSTERNAME>>/'${CLUSTER_NAME}'/g' charts/polaris/charts/dex/values.yaml
sed -i 's/<<DEX_BASE64>>/'${TEMP_CRT_CREDS}'/g' charts/polaris/charts/dex/values.yaml
sed -i 's/<<DEX_CRT>>/https:\/\/s3-eu-west-1.amazonaws.com\/'${STATE_BUCKET}'\/'${CLUSTER_NAME}'\/pki\/issued\/ca\/'${TEMP_CRT_NAME_ESCAPED}'/g' charts/polaris/charts/dex/values.yaml

sed -i 's/<<CLUSTERNAME>>/'${CLUSTER_NAME}'/g' charts/polaris/charts/dex-k8s-authenticator/values.yaml
sed -i 's/<<CLUSTERDESCRIPTION>>/'${CLUSTER_SHORT_DESCRIPTION}'/g' charts/polaris/charts/dex-k8s-authenticator/values.yaml
sed -i 's/<<DEX_BASE64>>/'${TEMP_CRT_CREDS}'/g' charts/polaris/charts/dex-k8s-authenticator/values.yaml
sed -i 's/<<DEX_CRT>>/https:\/\/s3-eu-west-1.amazonaws.com\/'${STATE_BUCKET}'\/'${CLUSTER_NAME}'\/pki\/issued\/ca\/'${TEMP_CRT_NAME_ESCAPED}'/g' charts/polaris/charts/dex-k8s-authenticator/values.yaml

sed -i 's/<<CLUSTERNAME>>/'${CLUSTER_NAME}'/g' ingress/ingress.yaml
sed -i 's/<<CLUSTERNAME>>/'${CLUSTER_NAME}'/g' ingress/ingress.yaml

kubectl create namespace polaris
kubectl apply -f serviceaccounts/tiller-serviceaccount.yaml
helm init --service-account helm-tiller --upgrade --debug --wait

echo 'Installing helm charts this may take a few minutes'
helm upgrade --namespace polaris --install polaris charts/polaris

kubectl create configmap dex-ca --namespace polaris --from-file dex-ca.pem=dex/ca/dex-ca-cert.pem
kubectl create secret tls dex-ca --namespace polaris --cert=dex/ca/dex-ca-cert.pem --key=dex/ca/dex-ca-key.pem
kubectl create secret tls dex-tls --namespace polaris --cert=dex/ca/dex-issuer-cert.pem --key=dex/ca/dex-issuer-key.pem

kubectl apply -f ingress/ingress.yaml

helm upgrade --namespace polaris --install polaris-prometheus-operator stable/prometheus-operator
