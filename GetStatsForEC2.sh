#!/bin/sh
#Usage: sh $0 2>/dev/null

rand=10
TEMPDIR="/tmp/MM/$rand"
CONFDIR="/home/ubuntu/Task_cron_ec_stats"

#region_list="$CONFDIR/regions"

while [ -d $TEMPDIR ] ; do
  rand=$(echo "$rand * $$" | bc)
  TEMPDIR="/tmp/MM/$rand"
done
mkdir /tmp/MM 2>/dev/null
mkdir "$TEMPDIR"

echo Using $TEMPDIR 1>&2

#for reg in $(cat $region_list) ; do
for reg in us-east-1 us-east-2 us-west-1 us-west-2 ca-central-1 eu-west-1 \
           eu-central-1 eu-west-2 ap-northeast-1 ap-northeast-2 ap-southeast-1 \
           ap-southeast-2 ap-south-1 sa-east-1 ; do

  aws ec2 describe-instances --region "$reg" | grep InstanceId | cut -d'"' -f4 \
      > $TEMPDIR/instances

  echo 1>&2
  echo Working on region $reg 1>&2
  echo 1>&2

  for inst_id in $(cat $TEMPDIR/instances) ; do

    echo 1>&2
    echo "InstanceId: $inst_id" 1>&2

    aws ec2 describe-instances --region "$reg" --instance-id "$inst_id" \
        | egrep 'InstanceType|AvailabilityZone|"Name": "|PublicDnsName
                 |PublicIpAddress|LaunchTime' \
        | tr -d ' ' | tr -d '"' | tr -d ',' | sort -u >> $TEMPDIR/$inst_id

    echo -n "$inst_id" >> $TEMPDIR/output

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

