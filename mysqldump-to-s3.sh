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

DATE=$(date +%Y%m%d)
DUMPDIR=/dumps
DUMPFILE=${DBHOST}_${DBNAME}_${DATE}.sql

# dump database
echo "Dumping ${DBNAME} from ${DBHOST}"
mysqldump -h ${DBHOST} -u${DBUSER} -p${DBPASS} ${DBNAME} > ${DUMPDIR}/${DUMPFILE}

# test dump file
if [[ ! -f ${DUMPDIR}/${DUMPFILE} ]]; then
    echo "ERROR: Dump file ${DUMPDIR}/${DUMPFILE} does not exist (dump upload cancelled).";
    exit 1;
fi
if [[ ! -s ${DUMPDIR}/${DUMPFILE} ]]; then
    echo "ERROR: Dump file ${DUMPDIR}/${DUMPFILE} is empty (dump upload cancelled).";
    exit 1;
fi
FIRSTLINE=$(head -n1 ${DUMPDIR}/${DUMPFILE})
if [[ ! $FIRSTLINE == *"MySQL dump"* ]]; then 
    echo "ERROR: First line of dump file ${DUMPDIR}/${DUMPFILE} does not pass test (dump upload cancelled).";
    exit 1;
fi
LASTLINE=$(tail -n1 ${DUMPDIR}/${DUMPFILE})
if [[ ! $LASTLINE == *"Dump completed"* ]]; then 
    echo "ERROR: First line of dump file ${DUMPDIR}/${DUMPFILE} does not pass test (dump upload cancelled).";
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
