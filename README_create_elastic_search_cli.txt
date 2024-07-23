#!/bin/bash -f
# Description : This script installs the dependencies for Red Hat Openshift Service Mesh
#               and then servicemesh operators.
#               Content based on content from 
#               https://github.com/jtarte/service-mesh/tree/master
#               and 
#               https://github.com/redhat-developer-demos/ossm-heading-to-production-and-day-2
# Author : A.J.Amabile
# Date   : 2024-July-19


#################
# Functions     #
#################

# Description: Test that an openshift object "name" of "type" exists and return
# 0 for does not exist
# 255 for object exists - also shows object status.phase
# 99 for incorrect number of arguments
# ------------------------------------------------------
Test_object_exists() {
  if (( $# == 2 )); then
    local obj_type=$1
    local obj_name=$2
    x=$(oc get ${obj_type} ${obj_name} -o template --template '{{.status.phase}}/{{.metadata.creationTimestamp}}' 2>/dev/null)
    if (( $? == 0 )); then
      echo "Object name '${obj_name}' of object type '${obj_type}' already exists - state/Created=${x}"
      return 255
    else
      echo "Object name '${obj_name}' of object type '${obj_type}'does not exist in '$(oc project -q)'"
      return 0
    fi
  else
    echo "Incorrect number of arguments, object_type and object_name expected"
    return 99
  fi
}

y=$(Test_object_exists namespace openshift-operators-redhat)
# if does not exists, then create
case $? in 
    0 )   
      echo "Creating new objects" ;;
      oc create ns openshift-operators-redhat
      if (( $? == 0 )); then
        oc apply -f elasticsearch-operator_service-account.yaml
        if (( $? == 0 )); then
          oc create -f elasticsearch-operator_OperatorGroup.yaml
          if (( $? == 0 )); then
            oc apply -f elasticsearch-operator_Subscription.yaml
          else
            echo "WARNING: elasticsearch-operator Subscription had a problem, please check"
            exit 1
          fi
        else
          echo "WARNING: elasticsearch-operator OperatorGroup had a problem, please check"
          exit 1
        fi
      else
        echo "WARNING: Creating openshift-operators-redhat had a problem, please check"
        exit 1
      fi
  255 )   
    echo "already there" ;;
      # switch to the openshift-operators-redhat project namespace
      oc project openshift-operators-redhat
      y=$(Test_object_exists ServiceAccount openshift-distributed-tracing)
      if (( $? == 0 )); then
        oc apply -f elasticsearch-operator_service-account.yaml
        if (( $? == 0 )); then
          # get the number of existing OperatorGroups
          opgroups=$(oc get OperatorGroup --no-headers -o json )
          if (( $? == 0 && $(echo $opgroups | jq '.items | length') == 0 )); then
            # if none found and OK to create
            oc create -f elasticsearch-operator_OperatorGroup.yaml
            if (( $? == 0 )); then
              oc apply -f elasticsearch-operator_Subscription.yaml
            else
              echo "WARNING: elasticsearch-operator Subscription had a problem, please check"
              exit 1
            fi
          else
            # Operator groups exist, so list them and exit
            echo "Operator groups exist - please verify openshift-operators-redhat-* exists"
            echo "$opgroups" | jq '.items'
        else
          echo "WARNING: elasticsearch-operator OperatorGroup had a problem, please check"
          exit 1
        fi

   99 )   
    echo "wrong args" ;;
esac

 
# else
  


y=$(Test_object_exists namespace openshift-distributed-tracing)
# if does not exists, then create
case $? in 
    0 )   
    echo "Creating new objects" ;;
    oc create ns openshift-distributed-tracing
    oc apply -f jaeger-operator_service-account.yaml
    oc create -f jaeger-operatorGroup.yaml
    oc apply -f jaeger-operator_subscription.yaml
  255 )   
    echo "already there" ;;
   99 )   
    echo "wrong args" ;;
esac


# check for existing service account and add if NOT found
  oc get ServiceAccount -n openshift-operators-redhat elasticsearch-operator 2>/dev/null
  (( $? > 0 )) && oc apply -f elasticsearch-operator_service-account.yaml
  oc get OperatorGroup openshift-operators-redhat- -n openshift-operators-redhat

# if does not exist, then create
# else

# check for existing service account and add if NOT found
  oc get ServiceAccount jaeger-operator -n openshift-distributed-tracing 2>/dev/null
  (( $? > 0 )) && oc apply -f elasticsearch-operator_service-account.yaml
  oc get OperatorGroup openshift-operators-redhat- -n openshift-operators-redhat

# if does not already exist
  oc apply -f kiali-operator_subscription.yaml
# if does not already exist
  oc apply -f service-mesh_subscription.yaml

