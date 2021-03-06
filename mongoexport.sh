#!/bin/bash
set -e

# Declare connection variable
dbname=$DBNAME
username=$USERNAME
password=$PASSWORD
host=$HOST
idValue=$ID
keyField=$KEY
bucket=$BUCKET
aws_access_key_id=$AWSACCESSKEYID
aws_secret_access_key=$AWSSECRETACCESSKEY

mongo --quiet "mongodb+srv://$username:$password@$host/$dbname" --eval "db.stats();"
RESULT=$? # returns 0 if mongo eval succeeds

if [ $RESULT -ne 0 ]; then
  echo "Can't connect to MongoDB server"
  exit 1
  break
else
  collections=$(mongo --quiet "mongodb+srv://$username:$password@$host/$dbname" --eval 'rs.slaveOk();db.getCollectionNames().join(" ");' | tail -1)
  IFS=', ' read -r -a collectionArray <<<"$collections"

  echo "Connected to $host @ $dbname with $username"
  echo " "
  exportDate=$(date -Iseconds)

  aws configure set aws_access_key_id $aws_access_key_id
  aws configure set aws_secret_access_key $aws_secret_access_key

fi

while true; do
  unset idValue
  unset keyField
  if [ -z "$keyField" ]; then
    echo "Enter Field to export (tenant, organization, group, etc.):"
    read keyField
  fi
  if [ -z "$idValue" ]; then
    echo "Enter ID value to export:"
    read idValue
  fi
  mkdir -p $PWD/$idValue/$exportDate
  for ((i = 0; i < ${#collectionArray[@]}; ++i)); do
    echo "Exporting $idValue from collection ${collectionArray[$i]}"

    mongoexport --uri="mongodb+srv://$username:$password@$host/$dbname" --collection ${collectionArray[$i]} --query="{\"$keyField\": {\"\$oid\": \"$idValue\"}}" --out $PWD/$idValue/$exportDate/${collectionArray[$i]}.json

    aws s3 cp $PWD/$idValue/$exportDate/${collectionArray[$i]}.json s3://$bucket/$idValue/$exportDate/${collectionArray[$i]}.json

    echo "${collectionArray[$i]} collection exported."
  done
  echo "Done. All collections have been exported here s3://$bucket/$idValue/$exportDate/"
  echo "Export another value of $keyField? [y/n] :"
  read response
  if [ "$response" != "y" ]; then
    break
  fi
done
