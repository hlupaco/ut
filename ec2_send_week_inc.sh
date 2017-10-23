#example: $ aws s3 cp s3://week-inc/week-inc/AWSLogs/725043218116/CloudTrail/eu-central-1/2017/10/04/725043218116_CloudTrail_eu-central-1_20171004T0500Z_vkAms7XIO8hw2NaJ.json.gz /tmp/log.json.gz
#ls: aws s3 ls s3://week-inc/week-inc/AWSLogs/

#current month = $(date --rfc-3339=date | cut -d'-' -f2)
#current year = $(date --rfc-3339=date | cut -d'-' -f1)

###############
## FUNCTIONS ##
###############

#tested
correct_date() {

  #solve negative day problem

  #return format:
    #year/month/day year/month/day year/month/day ...

  daycount=7 #parameter?

  year=$(date --rfc-3339=date | cut -d'-' -f1)
  month=$(date --rfc-3339=date | cut -d'-' -f2)
  day=$(date --rfc-3339=date | cut -d'-' -f3)

  startday=$(( day - daycount ))

#solve whole previous month
  if [ $startday -le 0 ] ; then
  #number of days in previous month
  #https://blog.sleeplessbeastie.eu/2013/03/24/how-to-get-number-of-days-in-a-month-using-shell-commands/
    prevmonth_maxdays=$(cal $(date +"%m %Y" --date "last month") | awk 'NF {DAYS = $NF}; END {print DAYS}')
    prevmonth_daycount=$(expr $(echo $startday | tr -d '-') + 1)

    prevmonth_startday=$(expr $prevmonth_maxdays - $prevmonth_daycount + 1)

    prevmonth=$(expr $month - 1)

    if [ "$prevmonth" -eq 0 ] ; then
      prevyear=$(expr $year - 1)
      prevmonth=12
    else
      prevyear="$year"
    fi

#napr od 28 do 31
    for actday in $(seq $prevmonth_startday $prevmonth_maxdays) ; do
      printf "$prevyear/$prevmonth/$actday "

    done

    startday=1

  fi

#solve current month
  for actday in $(seq $startday $(expr $day - 1)) ; do
    printf "$year/$month/$actday "

  done

}

##
##########
## MAIN ##
##########
##

cd /tmp
tmpdir=$RANDOM
while [ -d $tmpdir ] ; do
  tmpdir=$RANDOM
done
tmpdir="/tmp/$tmpdir"

date_string=$(correct_date)

AWSLogsDir=$(aws s3 ls "s3://week-inc/week-inc/AWSLogs/" | cut -d'/' -f1 | rev | cut -d' ' -f1 | rev)

#AWSLogsDir can have multiple rows if ls returns more of them - unless its sure I expect to have more rows, I will now expect to work always with just one
AWSLogsDir=$(echo $AWSLogsDir | head -n1)

actindex=1

for reg in $(aws s3 ls "s3://week-inc/week-inc/AWSLogs/$AWSLogsDir/CloudTrail/" | cut -d'/' -f1 | rev | cut -d' ' -f1 | rev) ; do

  for date in $date_string ; do

    onedayfiles=$(aws s3 ls "s3://week-inc/week-inc/AWSLogs/${AWSLogsDir}/CloudTrail/${reg}/${date}/" | cut -d'/' -f1 | rev | cut -d' ' -f1 | rev)

    for filename in $onedayfiles ; do

      aws s3 cp \
        "s3://week-inc/week-inc/AWSLogs/${AWSLogsDir}/CloudTrail/${reg}/${date}/${filename}" \
        "${tmpdir}/${actindex}.json.gz" &

      pids="$pids $!"

      actindex=$(expr $actindex + 1)

    done

    wait $pids

  done

  #cat files and parse them here - per region...
  echo "Working on region $reg"

done

exit
rm -Rf "$tmpdir"
