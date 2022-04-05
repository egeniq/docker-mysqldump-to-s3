#!/bin/sh
# This will dump a database and upload to s3

if [[ -z $DBHOST ]] ; then
    echo "DBHOST is not set. You must specify DB Host via ENV."
    exit 1
fi
if [[ -z $DBUSER ]] ; then
    echo "DBUSER is not set. You must specify DB User via ENV."
    exit 1
fi
if [[ -z $DBPASS ]] ; then
    echo "DBPASS is not set. You must specify DB Password via ENV."
    exit 1
fi
if [[ -z $DBNAME ]] ; then
    echo "DBNAME is not set. You must specify DB Name via ENV."
    exit 1
fi
if [[ -z $S3_BUCKET ]] ; then
    echo "S3_BUCKET is not set. You must specify S3 Bucket via ENV."
    exit 1
fi
if [[ -z $S3_PREFIX ]] ; then
    echo "S3_PREFIX is not set. You must specify S3 Prefix via ENV."
    exit 1
fi

# Enable Slack WebHook Notification if ENVs are set
SLACK_NOTIFY=false
if ! [[ -z $SLACK_WEBHOOK ]] ; then
    SLACK_NOTIFY=true
    if [[ -z $SLACK_CHANNEL ]] ; then SLACK_NOTIFY=false ; fi
    if [[ -z $SLACK_BOTNAME ]] ; then SLACK_BOTNAME="mysqldump-to-s3" ; fi
fi

# Make string of dump parameters (for adding to log msg)
if ! [[ -z $PARAMS ]] ; then
    PARAMS_MSG="(params: $PARAMS)"
fi

# Failure function
failure () {
    ERROR_MGS="$1"
    echo "ERROR: ${ERROR_MGS}"
    if [[ $SLACK_NOTIFY == "true" ]] ; then
        SLACK_PRETEXT="MySQLdump Failure:"
        SLACK_MESSAGE="${ERROR_MGS}!"
        SLACK_COLOR="#FF0000"
        echo "Posting Slack Notification to WebHook: $SLACK_WEBHOOK";
        PAYLOAD="payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_BOTNAME}\", \"attachments\":[{\"fallback\":\"${SLACK_PRETEXT} ${SLACK_MESSAGE}\", \"pretext\":\":fire::fire:*${SLACK_PRETEXT} ${SLACK_MESSAGE}*:fire::fire:\", \"color\":\"${SLACK_COLOR}\", \"mrkdwn_in\":[\"text\", \"pretext\"], \"fields\":[{\"title\":\"Error Mesage\", \"value\":\"${ERROR_MGS}\", \"short\":false}]}] }"
        CURL_RESULT=`curl -s -S -X POST --data-urlencode "$PAYLOAD" $SLACK_WEBHOOK`
    fi
    return 0
}

DATE=$(date +%Y%m%d_%H%M)
DUMPDIR=/dumps
DUMPFILE=${DBHOST}_${DBNAME}_${DATE}.sql

# dump database
echo "Dumping ${DBNAME} from ${DBHOST} ${PARAMS_MSG}"
mysqldump -h ${DBHOST} -u${DBUSER} -p${DBPASS} ${PARAMS} ${DBNAME} > ${DUMPDIR}/${DUMPFILE}

# test dump file
if [[ ! -f ${DUMPDIR}/${DUMPFILE} ]]; then
    failure "Dump file ${DUMPDIR}/${DUMPFILE} does not exist (dump upload cancelled).";
    exit 1;
fi
if [[ ! -s ${DUMPDIR}/${DUMPFILE} ]]; then
    failure "Dump file ${DUMPDIR}/${DUMPFILE} is empty (dump upload cancelled).";
    exit 1;
fi
FIRSTLINE=$(head -n1 ${DUMPDIR}/${DUMPFILE})
if [[ ! $FIRSTLINE == *"MySQL dump"* ]]; then
    failure "First line of dump file ${DUMPDIR}/${DUMPFILE} does not pass test (dump upload cancelled).";
    exit 1;
fi
LASTLINE=$(tail -n1 ${DUMPDIR}/${DUMPFILE})
if [[ ! $LASTLINE == *"Dump completed"* ]]; then
    failure "First line of dump file ${DUMPDIR}/${DUMPFILE} does not pass test (dump upload cancelled).";
    exit 1;
fi

# compress dump file
echo "XZ Compressing dump file ..."
xz --fast -v ${DUMPDIR}/${DUMPFILE}

# upload dump to s3 (and copy it to "latest" file)
echo "Uploading ${DUMPFILE}.xz to ${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE}.xz"
aws s3 cp ${DUMPDIR}/${DUMPFILE}.xz s3://${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE}.xz

# clean exit
echo "Dump and upload completed"
exit 0
