#!/bin/bash

set -exu -o pipefail
[[ -f /VERSION ]] && cat /VERSION


echo "Remove the expired letsencrypt.org cert and update the CA certificates"
sudo apt-get install -y ca-certificates
sudo rm /usr/share/ca-certificates/mozilla/DST_Root_CA_X3.crt
sudo update-ca-certificates

cd github

export GOPATH="${HOME}/gopath"
pushd grpc-go/interop/xds/client
branch=$(git branch --all --no-color --contains "${KOKORO_GITHUB_COMMIT}" \
    | grep -v HEAD | head -1)
shopt -s extglob
branch="${branch//[[:space:]]}"
branch="${branch##remotes/origin/}"
shopt -u extglob
go build
popd

git clone -b "${branch}" --single-branch --depth=1 https://github.com/grpc/grpc.git

grpc/tools/run_tests/helper_scripts/prep_xds.sh

# Test cases "path_matching" and "header_matching" are not included in "all",
# because not all interop clients in all languages support these new tests.
#
# TODO: remove "path_matching" and "header_matching" from --test_case after
# they are added into "all".
GRPC_GO_LOG_VERBOSITY_LEVEL=99 GRPC_GO_LOG_SEVERITY_LEVEL=info \
  python3 grpc/tools/run_tests/run_xds_tests.py \
    --test_case="all,circuit_breaking,timeout,fault_injection,csds" \
    --project_id=grpc-testing \
    --project_num=830293263384 \
    --source_image=projects/grpc-testing/global/images/xds-test-server-4 \
    --path_to_server_binary=/java_server/grpc-java/interop-testing/build/install/grpc-interop-testing/bin/xds-test-server \
    --gcp_suffix=$(date '+%s') \
    --verbose \
    ${XDS_V3_OPT-} \
    --client_cmd="grpc-go/interop/xds/client/client \
      --server=xds:///{server_uri} \
      --stats_port={stats_port} \
      --qps={qps} \
      {fail_on_failed_rpc} \
      {rpcs_to_send} \
      {metadata_to_send}"

