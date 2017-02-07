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

DATE=$(date +%Y%m%d%H%M)
DUMPDIR=/dumps
DUMPFILE=${DBHOST}_${DBNAME}_${DATE}.sql
DUMPFILE2=${DBHOST}_${DBNAME}_latest.sql

# dump database
echo "Dumping ${DBNAME} from ${DBHOST}"
mysqldump -h ${DBHOST} -u${DBUSER} -p${DBPASS} ${DBNAME} > ${DUMPDIR}/${DUMPFILE}

# upload dump to s3 (and copy it to "latest" file)
echo "Uploading ${DUMPFILE} to ${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE}"
aws s3 cp ${DUMPDIR}/${DUMPFILE} s3://${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE}
echo "Copying s3://${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE} to ${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE2}"
aws s3 cp s3://${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE} s3://${S3_BUCKET}/${S3_PREFIX}/${DUMPFILE2}
