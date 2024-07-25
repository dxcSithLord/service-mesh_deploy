#!/bin/bash -f
# Description : This script installs the dependencies for Red Hat Openshift Service Mesh
#               and then servicemesh operators.
#               Content based on content from 
#               https://github.com/jtarte/service-mesh/tree/master
#               and 
#               https://github.com/redhat-developer-demos/ossm-heading-to-production-and-day-2
# Author : A.J.Amabile
# Date   : 2024-July-19
# Modified : Updated to handle error conditions and improve messages on progress.

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

get_sa_name() {
  if (( $# == 2 )); then
    local operator_name="${1}"
    local op_ns="${2}"
    sa_name=$(yp '.metadata.name' "${operator_name}_Subscription.yaml")
    if [[ -z "${sa_name}" ]]; then
      echo "WARNING: Problem with ${operator_name}_Subscription.yaml - metadata.name missing"
      exit 1
    fi
    echo ${sa_name}
}

verify_deployment() {
  if (( $# == 2 )); then
    local operator_name="${1}"
    local op_ns="${2}"
    local RESOURCE
    local LOOP
    local STATUS
    local RC
    # small delay tp allow commands to settle before checking
    sleep 2
    sa_name=$(get_sa_name "${operator_name}" "${op_ns}")
    if (( $? == 0 )); then
      unset RESOURCE
      while [[ -z $RESOURCE ]]; do
        RESOURCE=$(oc get subscription \
              "${sa_name}"   \
              -n "${op_ns}" \
              -o template --template '{{.status.currentCSV}}')
        echo "Waiting for ${sa_name} version"
        sleep 10
      done
    else
      exit 1
    fi
    LOOP=1 # 1 evaluates to TRUE
    while (( LOOP )); do
      sleep 5
      # get the status of csv
      STATUS=""
      if oc get csv "${RESOURCE}" --no-headers 2>/dev/null; then
        STATUS=$(oc get csv "${RESOURCE}" -o template --template '{{.status.phase}}')
        RC=$?
      fi
      # Check the CSV state
      if (( RC == 0 )) && [[ "${STATUS}" == "Succeeded" ]]; then
        echo "${operator_name} operator is deployed"
        LOOP=0
      else
        echo "${operator_name} waiting for Succeeded state - currently ${STATUS:-"BLANK"}"
      fi
    done
  else
    echo "Incorrect number of arguments, operator_name and namespace expected"
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
    Test_object_exists namespace "${op_ns}"
    case $? in
        0 )   
          echo "Creating new objects"
          if oc create ns "${op_ns}"; then
            for obj in "${task_seq[@]}"; do
              if oc "${obj_types[${obj}]}" -f "${operator_name}_${obj}.yaml";  then
                echo "oc ${obj_types[${obj}]} -f ${operator_name}_${obj}.yaml OK"
              else
                echo "WARNING: Applying ${operator_name} ${obj} had a problem, please check"
                exit 1
              fi
            done
          else
            echo "WARNING: Creating namespace ${op_ns} had problem"
            exit 1
          fi ;;
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
  verify_deployment  "${operator_name}" "${op_ns}"
}  # end of Load_Operator_Deps
 
# else
  
Load_Operator_Deps elasticsearch-operator openshift-operators-redhat

Load_Operator_Deps jaeger-operator openshift-distributed-tracing

# if does not already exist
  oc apply -f kiali-ossm_Subscription.yaml
  verify_deployment kiali-ossm openshift-operators
  
# if does not already exist
  oc apply -f servicemeshoperator_Subscription.yaml
  verify_deployment  servicemeshoperator openshift-operators
