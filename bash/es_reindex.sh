#!/bin/bash -e
##-------------------------------------------------------------------
## File : es_reindex.sh
## Description :
## --
## Created : <2017-03-27>
## Updated: Time-stamp: <2017-03-27 14:11:16>
##-------------------------------------------------------------------
old_index_name=${1?}

new_index_name=${2:-""}

if [ -z "$new_index_name" ]; then
    new_index_name="${old_index_name}-new"
fi
shard_count=${3:-5}
replica_count=${4:-1}
es_ip=${5:-""}
es_port=${6:-"9200"}

if [ -z "$es_ip" ]; then
    es_ip=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
fi
alias_index_name=$(echo "$old_index_name" | sed 's/-index//g')

##-------------------------------------------------------------------
echo "old_index_name: $old_index_name, new_index_name: $new_index_name"

echo "List all indices"
time curl -XGET "http://${es_ip}:${es_port}/_cat/indices?v"

echo "create new index with proper shards and replicas"
time curl -XPUT "http://${es_ip}:${es_port}/${new_index_name}?pretty" -d "
    {
       \"settings\" : {
       \"index\" : {
       \"number_of_shards\" : ${shard_count},
       \"number_of_replicas\" : ${replica_count}
       }
   }
}"

echo "Get the setting of the new index"
time curl -XGET "http://${es_ip}:${es_port}/${new_index_name}/_settings?pretty"

echo "Reindex index. Attention: this will take a very long time, if the index is big"
time curl -XPOST "http://${es_ip}:${es_port}/_reindex?pretty" -d "
    {
    \"conflicts\": \"proceed\",
    \"source\": {
    \"index\": \"${old_index_name}\"
    },
    \"dest\": {
    \"index\": \"${new_index_name}\",
    \"op_type\": \"create\"
    }
}"

# We can start a new terminal and check reindex status
echo "Get all re-index tasks"
time curl -XGET "http://${es_ip}:${es_port}/_tasks?detailed=true&actions=*reindex&pretty"

echo "Add index to existing alias and remove old index from that alias. alias: $alias_index_name"
time curl -XPOST "http://${es_ip}:${es_port}/_aliases" -d "
{
    \"actions\": [
    { \"remove\": {
    \"alias\": \"${alias_index_name}\",
    \"index\": \"${old_index_name}\"
    }},
    { \"add\": {
    \"alias\": \"${alias_index_name}\",
    \"index\": \"${new_index_name}\"
    }}
    ]
}"

# List alias
curl -XPGET "http://${es_ip}:${es_port}/_aliases?pretty" | grep -C 10 "$(echo "$old_index_name" | sed "s/.*-index-//g")"

# Close index
curl -XPOST "http://${es_ip}:${es_port}/${old_index_name}/_close"

# Delete index
# curl -XDELETE "http://${es_ip}:${es_port}/${old_index_name}?pretty"

## File : es_reindex.sh ends