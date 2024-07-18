

oc create ns openshift-operators-redhat
oc apply -f elasticsearch-operator_service-account.yaml
oc create -f elasticsearch-operator_OperatorGroup.yaml
oc apply -f elasticsearch-operator_Subscription.yaml

oc create ns openshift-distributed-tracing
oc apply -f jaeger-operator_service-account.yaml
oc create -f jaeger-operatorGroup.yaml
oc apply -f jaeger-operator_subscription.yaml

oc apply -f kiali-operator_subscription.yaml

oc apply -f service-mesh_subscription.yaml