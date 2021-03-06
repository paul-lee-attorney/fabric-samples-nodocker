#!/bin/bash
#
# Copyright 2020 Yiwenlong(wlong.yi#gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
WORK_HOME=$(pwd)

DAEMON_SUPPORT_SCRIPT="$DIR/daemon-support/config-daemon.sh"

TMP_ORDERER="$DIR/template/orderer.yaml"

# shellcheck source=utils/log-utils.sh
. "$DIR/utils/log-utils.sh"
# shellcheck source=utils/conf-utils.sh
. "$DIR/utils/conf-utils.sh"
# shellcheck source=utils/file-utils.sh
. "$DIR/utils/file-utils.sh"

function readConfOrgValue() {
  readConfValue "$CONF_FILE" org "$1"; echo
}

function readConfNodeValue() {
  readConfValue "$CONF_FILE" "$1" "$2"; echo
}

function checkSuccess() {
    if [[ $? != 0 ]]; then
        exit $?
    fi
}

function configNode {
  node_name=$1
  org_name=$2
  org_domain=$3
  org_mspid=$4
  logInfo "Start config node:" "$node_name"
  node_port=$(readConfNodeValue "$node_name" node.listen.port)
  node_address=$(readConfNodeValue "$node_name" node.listen.address)
  node_operations_port=$(readConfNodeValue "$node_name" node.operations.port)
  logInfo "Node port:" "$node_port"
  logInfo "Node operation port:" "$node_operations_port"

  org_home="$WORK_HOME/$org_name"
  node_home="$org_home/$node_name"
  if [ -d "$node_home" ]; then
      rm -fr "$node_home"
  fi
  mkdir -p "$node_home" && cd "$node_home" || exit
  logInfo "Node work home created:" "$node_home"

  cp -r "$org_home/crypto-config/ordererOrganizations/$org_domain/orderers/$node_name.$org_domain/"* "$node_home"
  logInfo "Node msp directory:" "$node_home/msp"
  logInfo "Node tls directory:" "$node_home/tls"

  orderer_config_file="$node_home/orderer.yaml"
  sed -e "s/<orderer.address>/${node_address}/
  s/<orderer.port>/${node_port}/
  s/<org.mspid>/${org_mspid}/
  s/<orderer.operations.port>/${node_operations_port}/" "$TMP_ORDERER" > "$orderer_config_file"
  logInfo "Node config file generated:" "$orderer_config_file"

  command=$(readConfNodeValue "$node_name" "node.command.binary")
  command=$(absolutefile "$command" "$WORK_HOME")

  # if node.command.binary is not set. Use binaries/arch/fabric/orderer by default.
  if [ ! -f "$command" ]; then
    arch=$(uname -s|tr '[:upper:]' '[:lower:]')
    command="$(cd "$DIR/.." && pwd)/binaries/$arch/fabric/orderer"
  fi

  if [ -f "$command" ]; then
    logInfo "Node binary file:" "$command"
    cp "$command" "$node_home/"
  else
    logError "Warming: no peer command binary found!!!" "$command"
  fi
  daemon=$(readConfNodeValue "$node_name" "node.daemon.type")
  node_process_name="FABRIC-NODOCKER-$org_name-$node_name"
  "$DAEMON_SUPPORT_SCRIPT" -d "$daemon" -n "$node_process_name" -h "$node_home" -c "orderer"
  checkSuccess

  logSuccess "Node config success:" "$node_name"
}

function config {
  org_name=$(readConfOrgValue org.name)
  org_mspid=$(readConfOrgValue org.mspid)
  org_domain=$(readConfOrgValue org.domain)
  org_node_count=$(readConfOrgValue org.node.count)
  logInfo "Start config orderer organization:" "$org_name"
  logInfo "Organization name:" "$org_name"
  logInfo "Organization mspid:" "$org_mspid"
  logInfo "Organization domain:" "$org_domain"
  logInfo "Organization node count:" "$org_node_count"

  org_home="$WORK_HOME/$org_name"
  if [ -d "$org_home" ]; then
    rm -fr "$org_home"
  fi

  mkdir -p "$org_home" && cd "$org_home" || exit
  logInfo "Organization work dir:" "$org_home"
  checkSuccess

  cp "$CONF_FILE" "$org_home/conf.ini"

  # generate msp config files.
  "$DIR/config-msp.sh" -t orderer -d "$org_home" -f "$CONF_FILE"
  checkSuccess

  for (( i = 0; i < "$org_node_count" ; ++i)); do
    configNode "orderer$i" "$org_name" "$org_domain" "$org_mspid"
  done

  cd "$WORK_HOME" || exit
  "$DIR/config-orderer-genesis.sh" -f "sys-channel.ini" -d "$org_home"
  checkSuccess

  for (( i = 0; i < "$org_node_count" ; ++i)); do
    cp "$org_home/genesis.block" "$org_home/orderer$i/"
  done

  logSuccess "Organization config success:" "$org_name"
}


function usage {
    echo "USAGE:"
    echo "  config-orderer.sh -f config.ini"
}

if [ ! "$FABRIC_BIN" ]; then
    logError "Missing environment variable: " "FABRIC_BIN"
    exit 1
fi 

while getopts f:d: opt
do 
  case $opt in
    f) CONF_FILE=$(absolutefile "$OPTARG" "$WORK_HOME")
      checkfileexist "$CONF_FILE";;
    d) CONF_DIR=$(absolutefile "$OPTARG" "$WORK_HOME")
      checkdirexist "$CONF_DIR";;
    *) usage; exit 1;;
  esac
done

checkfileexist "$CONF_FILE"
config