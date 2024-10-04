# service-mesh_deploy
Deployment of service mesh into Openshift 4.14 cluster

From the current directory, run:

bash ./Deploy_ServiceMeshOperator.sh

and wait for install.  It may be a few minutes.

See also https://github.com/dxcSithLord/ossm-heading-to-production-and-day-2/tree/main/scenario-3-prod-basic-setup/scripts

check issues

### Working in lab with SSL terminated on Service Mesh Gateway as below

Added new files:

1) Create route_on_istio_system_namespace -> ext hostname to handover connection to service mesh
2) Create create_opaque_secret_with_ca_chain -> Create the opaque secret with the ca chain cert, tested with both, didn't have time to remove the in-app-namespace secret and test. Try adding it just to istio-system and see if it works first.
3) Create template_gateway_example -> Template for gateway - should be largely similar/identical to the ones in the files but do not have them handy to reference.
4) Create template_vs_example -> Template for vs - should be largely similar/identical to the ones in the files but do not have them handy to reference.

Give me a call if you need to
