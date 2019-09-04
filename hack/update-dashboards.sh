#!/usr/bin/env bash

# Copyright 2019 The Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

cd $(dirname $0)/..

clean_dashbaord() {
  local dashboard="$1"

  echo "$dashboard"
  tmpfile="$dashboard.tmp"

  cat "$dashboard" | \
    jq '(.templating.list[] | select(.type=="query") | .options) = []' | \
    jq '(.templating.list[] | select(.type=="query") | .refresh) = 2' | \
    jq '(.templating.list[] | select(.type=="query") | .current) = {}' | \
    jq '(.templating.list[] | select(.type=="interval") | .current) = {}' | \
    jq '(.panels[] | select(.scopedVars!=null) | .scopedVars) = {}' | \
    jq '(.annotations.list) = []' | \
    jq '(.links) = []' | \
    jq '(.panels[] | select(.type!="row") | .editable) = true' | \
    jq '(.panels[] | select(.type!="row") | .transparent) = true' | \
    jq '(.panels[] | select(.type!="row") | .timeRegions) = []' | \
    jq '(.panels[] | select(.type=="row") | .panels[].editable) = true' | \
    jq '(.panels[] | select(.type=="row") | .panels[].transparent) = true' | \
    jq '(.panels[] | select(.type=="row") | .panels[].timeRegions) = []' | \
    jq '(.panels[] | select(.type=="row") | .panels[].scopedVars) = {}' | \
    jq '(.refresh) = "30s"' | \
    jq '(.time.from) = "now-3h"' | \
    jq '(.time.to) = "now"' | \
    jq '(.editable) = true' | \
    jq '(.hideControls) = false' | \
    jq '(.timezone) = ""' | \
    jq '(.graphTooltip) = 1' | \
    jq '(.version) = 1' | \
    jq 'del(.panels[] | select(.repeatPanelId!=null))' | \
    jq 'del(.id)' | \
    jq 'del(.iteration)' | \
    jq --sort-keys '.' > "$tmpfile"

  mv "$tmpfile" "$dashboard"
}

for dashboard in dashboards/*.json; do
  clean_dashbaord "$dashboard"
done

manifest=dashboards-configmap.yaml

cat << YAML > $manifest
# This file has been generated, do not edit.
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-prow-dashboards
  namespace: monitoring
  labels:
    # make the Grafana sidecar automatically find and mount this ConfigMap
    grafana_dashboard: "1"
data:
YAML

for dashboard in dashboards/*.json; do
  echo "  $(basename $dashboard): |" >> $manifest
  echo -n "    " >> $manifest
  jq -cM . $dashboard >> $manifest
done
