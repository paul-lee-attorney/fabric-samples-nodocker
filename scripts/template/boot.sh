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
BOOT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
export FABRIC_CFG_PATH=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

function checkSuccess() {
  if [[ $? != 0 ]]; then
      exit $?
  fi
}

dst_file="_supervisor_conf_dir_/_supervisor_conf_file_name_._suffix_"
if [ -f "$dst_file" ]; then
  rm "$dst_file"
fi

if [ ! -d "_supervisor_conf_dir_/" ]; then
  mkdir -p "_supervisor_conf_dir_/"
fi

echo "[program:_supervisor_conf_file_name_]" > "$dst_file"
echo "command=$BOOT_DIR/_command_" >> "$dst_file"
echo "directory=$BOOT_DIR" >> "$dst_file"
echo "redirect_stderr=true" >> "$dst_file"
echo "stdout_logfile=$BOOT_DIR/_supervisor_conf_file_name_.log" >> "$dst_file"
echo "Supervisor config file generate:" "$dst_file"

supervisorctl update
echo Staring: "_supervisor_conf_file_name_"
sleep 3
supervisorctl status | grep "_supervisor_conf_file_name_"