#!/bin/sh
#Usage: sh $0 2>/dev/null

rand="1"
TEMPDIR="/tmp/MM/$rand"

while [ -d $TEMPDIR ] ; do
  rand=$(echo "($rand * $$) % 10000" | bc)
  TEMPDIR="/tmp/MM/$rand"
done

mkdir /tmp/MM 2>/dev/null
mkdir "$TEMPDIR"

echo Using $TEMPDIR 1>&2

for reg in $(aws ec2 describe-regions --query 'Regions[].{Name:RegionName}' \
           --output text --region eu-west-1) ; do

  aws ec2 describe-instances --region "$reg" | grep InstanceId | cut -d'"' -f4 \
      > $TEMPDIR/instances

  echo 1>&2
  echo Working on region $reg 1>&2
  echo 1>&2

  for inst_id in $(cat $TEMPDIR/instances) ; do

    echo 1>&2
    echo "InstanceId: $inst_id" 1>&2

    echo -n "$inst_id" >> $TEMPDIR/output

    aws ec2 describe-instances --region "$reg" --instance-id "$inst_id" \
        | egrep 'InstanceType|AvailabilityZone|"Name": "|PublicDnsName
                 |PublicIpAddress|LaunchTime' \
        | tr -d ' ' | tr -d '"' | tr -d ',' | sort -u >> $TEMPDIR/$inst_id

    for stat in AvailabilityZone InstanceType LaunchTime Name PublicDnsName \
                PublicIpAddress ; do

      act=$(cat $TEMPDIR/$inst_id | grep '^'"$stat"":")

      echo -n ';' >> $TEMPDIR/output

      if [ $act ] ; then

        echo -n $act | cut -d: -f2 | xargs echo -n >> $TEMPDIR/output

      fi

    done

    echo >> $TEMPDIR/output

  done

done

cat $TEMPDIR/output

rm -Rf $TEMPDIR

