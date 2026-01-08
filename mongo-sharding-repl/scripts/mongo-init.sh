#!/bin/bash
set -e

echo "===> Init config server"

docker-compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
})
EOF

sleep 3

echo "===> Init shard1"

docker-compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF

sleep 3

echo "===> Init shard2"

docker-compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27019" },
    { _id: 1, host: "shard2-2:27019" },
    { _id: 2, host: "shard2-3:27019" }
  ]
})
EOF

sleep 5

echo "===> Configure mongos"

docker-compose exec -T mongos mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018")
sh.addShard("shard2/shard2-1:27019")

sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { name: "hashed" })

use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: "ly" + i })
}

print("Total documents:")
db.helloDoc.countDocuments()
EOF

echo "===> Check shard1"

docker-compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "===> Check shard2"

docker-compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

echo "===> Replica status shard1"
docker-compose exec -T shard1-1 mongosh --port 27018 --quiet <<'EOF'
rs.status().members.forEach(m => print(m.name + " | " + m.stateStr))
EOF

echo "===> Replica status shard2"
docker-compose exec -T shard2-1 mongosh --port 27019 --quiet <<'EOF'
rs.status().members.forEach(m => print(m.name + " | " + m.stateStr))
EOF

echo "===> Sharding + replication init completed"