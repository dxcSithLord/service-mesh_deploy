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

Load_Operator_Deps() {
  if (( $# == 2 )); then
    local operator_name=$1
    local op_ns=$2
  
    # test for the if does not exists, then create
    y=$(Test_object_exists namespace ${op_ns})
    case $? in 
        0 )   
          echo "Creating new objects" ;;
          oc create ns ${op_ns}
          if (( $? == 0 )); then
            oc apply -f "${operator_name}_service-account.yaml"
            if (( $? == 0 )); then
              oc create -f "${operator_name}_OperatorGroup.yaml"
              if (( $? == 0 )); then
                oc apply -f "${operator_name}_Subscription.yaml"
                if (( $? > 0 )); then
                  echo "WARNING: Applying ${operator_name} Subscription had a problem, please check"
                  exit 1
                fi
              else
                echo "WARNING: Creating ${operator_name} OperatorGroup had a problem, please check"
                exit 1
              fi
            else
              echo "WARNING: Applying ${operator_name} service-account had a problem, please check"
              exit 1
            fi
          else
            echo "WARNING: Creating ${operator_name} had a problem, please check"
            exit 1
          fi
      255 )   
        echo "already there" ;;
          # switch to the openshift-operators-redhat project namespace
          oc project ${op_ns}
          #  work out the values to pass from the yaml file - needs yq installed.
          y=$(Test_object_exists ServiceAccount XXXXX_FROM_YAML_XXXX )
          if (( $? == 0 )); then
            oc apply -f "${operator_name}_service-account.yaml"
            if (( $? == 0 )); then
              # get the number of existing OperatorGroups
              opgroups=$(oc get OperatorGroup --no-headers -o json )
              if (( $? == 0 && $(echo $opgroups | jq '.items | length') == 0 )); then
                # if none found and OK to create
                oc create -f "${operator_name}_OperatorGroup.yaml"
                if (( $? == 0 )); then
                  oc apply -f "${operator_name}_Subscription.yaml"
                else
                  echo "WARNING: ${operator_name} Subscription had a problem, please check"
                  exit 1
                fi
              else
                # Operator groups exist, so list them and exit
                echo "Operator groups exist - please verify openshift-operators-redhat-* exists"
                echo "$opgroups" | jq '.items'
            else
              echo "WARNING: ${operator_name} OperatorGroup had a problem, please check"
              exit 1
            fi
    
       99 )   
        echo "wrong args" ;;
          exit 1
    esac
  else
    echo "Incorrect number of arguments, operator_name and namespace expected"
    return 99
  fi
}  
 
# else
  
Load_Operator_Deps elasticsearch-operator openshift-operators-redhat
Load_Operator_Deps jaeger-operator openshift-distributed-tracing

# if does not already exist
  oc apply -f kiali-operator_subscription.yaml
# if does not already exist
  oc apply -f service-mesh_subscription.yaml

