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
    local obj_type="${1}"
    local obj_name="${2}"
    x=$(oc get "${obj_type}" "${obj_name}" -o template \
        --template '{{.status.phase}}/{{.metadata.creationTimestamp}}' 2>/dev/null)
    (( $? == 0 )) && \
      echo "Object name '${obj_name}' of object type '${obj_type}' already exists - state/Created=${x}" && \
      return 255 || \
      echo "Object name '${obj_name}' of object type '${obj_type}'does not exist in '$(oc project -q)'" && \
      return 0
  else
    echo "Incorrect number of arguments, object_type and object_name expected"
    return 99
  fi
}

Load_Operator_Deps() {
  if (( $# == 2 )); then
    local operator_name="${1}"
    local op_ns="${2}"
    set -a task_seq
    task_seq=( "service-account" "OperatorGroup" "Subscription" )
    declare -rA obj_types=( ["service-account"]="apply" \
                            ["OperatorGroup"]="create" \
                            ["Subscription"]="apply" )
    # test for the if does not exists, then create

    case $(Test_object_exists namespace "${op_ns}") in
        0 )   
          echo "Creating new objects"
          if oc create ns "${op_ns}"; then
            for obj in "${task_seq[@]}"; do
              if oc "${obj_types[obj]}" -f "${operator_name}_${obj}.yaml";  then
                echo "oc ${obj_types[obj]} -f ${operator_name}_${obj}.yaml OK"
              else
                echo "WARNING: Applying ${operator_name} ${obj} had a problem, please check"
                exit 1
              fi
            done
          else
            echo "WARNING: Creating namespace ${op_ns} had problem"
          fi;;
      255 )   
        echo "already there"
          # Hence switch to the openshift-operators-redhat project namespace
          #  to perform checks
          oc project "${op_ns}"
          #  work out the values to pass from the yaml file - needs yq installed.
          sa_name=$(yq '.metadata.name' "${operator_name}_service-account.yaml")
          if Test_object_exists ServiceAccount "${sa_name}"; then
            # True is does NOT exist
            if oc apply -f "${operator_name}_service-account.yaml"; then
              # get the number of existing OperatorGroups
              op_groups=$(oc get OperatorGroup --no-headers -o json )
              if (( $? == 0 && $(echo "$op_groups" | jq '.items | length' ) == 0 )); then
                # if none found and OK to create
                if oc create -f "${operator_name}_OperatorGroup.yaml"; then
                  oc apply -f "${operator_name}_Subscription.yaml"
                else
                  echo "WARNING: ${operator_name} Subscription had a problem, please check"
                  exit 1
                fi
              else
                # Operator groups exist, so list them and exit
                echo "Operator groups exist - please verify openshift-operators-redhat-* exists"
                echo "$op_groups" | jq '.items'
              fi
            else
              echo "WARNING: ${operator_name} OperatorGroup had a problem, please check"
              exit 1
            fi
          else
            echo "Well that didn't work"
          fi ;;
       99 )   
        echo "wrong args"
          exit 1 ;;
    esac
  else
    echo "Incorrect number of arguments, operator_name and namespace expected"
    return 99
  fi
}  # end of Load_Operator_Deps
 
# else
  
Load_Operator_Deps elasticsearch-operator openshift-operators-redhat
Load_Operator_Deps jaeger-operator openshift-distributed-tracing

# if does not already exist
  oc apply -f kiali-ossm_subscription.yaml
# if does not already exist
  oc apply -f servicemeshoperator_Subscription.yaml

